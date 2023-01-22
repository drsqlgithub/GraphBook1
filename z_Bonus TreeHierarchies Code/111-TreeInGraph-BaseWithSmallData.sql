USE HowToOptimizeAHierarchyInSQLServer;
GO

/********************
Simple adjacency list
********************/

DROP PROCEDURE IF EXISTS TreeInGraph.Company$Reparent;
DROP PROCEDURE IF EXISTS TreeInGraph.Company$Delete;
DROP PROCEDURE IF EXISTS TreeInGraph.Company$Insert;
DROP FUNCTION IF EXISTS TreeInGraph.Company$returnHierarchyHelper;
DROP PROCEDURE IF EXISTS TreeInGraph.Sale$InsertTestData;
DROP TABLE IF EXISTS TreeInGraph.Sale;
DROP TABLE IF EXISTS TreeInGraph.CompanyEdge;
DROP TABLE IF EXISTS TreeInGraph.Company;
DROP SEQUENCE IF EXISTS TreeInGraph.CompanyDataGenerator_SEQUENCE;

DROP SCHEMA IF EXISTS TreeInGraph;
GO

CREATE SCHEMA TreeInGraph;
GO

CREATE TABLE TreeInGraph.Company
(
    CompanyId       int         IDENTITY(1, 1) CONSTRAINT PKCompany PRIMARY KEY,
    Name            varchar(20) NOT NULL CONSTRAINT AKCompany_Name UNIQUE,
) AS NODE;

CREATE TABLE TreeInGraph.CompanyEdge
(
	CONSTRAINT EC_CompanyEdge$DefinesParentOf CONNECTION (TreeInGraph.Company TO TreeInGraph.Company) ON DELETE NO ACTION
)
AS EDGE;

CREATE UNIQUE INDEX FromId ON TreeInGraph.CompanyEdge($from_id);
CREATE INDEX ToId ON TreeInGraph.CompanyEdge($to_id);

--this object is simply used to generate a Company Name to make the demo a bit more textual.
--it would not be used for a "real" build

CREATE SEQUENCE TreeInGraph.CompanyDataGenerator_SEQUENCE
AS int
START WITH 1;
GO

CREATE TABLE TreeInGraph.Sale
(
    SalesId           int            NOT NULL IDENTITY(1, 1) CONSTRAINT PKSale PRIMARY KEY,
    TransactionNumber varchar(10)    NOT NULL CONSTRAINT AKSale UNIQUE,
    Amount            numeric(12, 2) NOT NULL,
    CompanyId         int            NOT NULL REFERENCES TreeInGraph.Company(CompanyId),
	INDEX XCompanyId (CompanyId, Amount)
);
GO

--the sale table is here for when we do aggregations to make the situation more "real".
--note that I just use a sequential number for the Amount. This makes sure that when we do aggregations
--on each type that the value is the exact same.

CREATE PROCEDURE TreeInGraph.Sale$InsertTestData
    @Name     varchar(20), --Note that all procs use natural keys to make it easier for you to work with manually.
                           --If you are implementing this for a tool to manipulate, use the surrogate keys
    @RowCount int = 5
AS
BEGIN
	SET NOCOUNT ON;

	WHILE @RowCount > 0
	BEGIN
		INSERT INTO TreeInGraph.Sale(TransactionNumber, Amount, CompanyId)
		SELECT CAST(NEXT VALUE FOR TreeInGraph.CompanyDataGenerator_SEQUENCE AS varchar(10)),
			   CAST(NEXT VALUE FOR TreeInGraph.CompanyDataGenerator_SEQUENCE AS numeric(12, 2)),
			   (   SELECT Company.CompanyId
				   FROM   TreeInGraph.Company
				   WHERE  Company.Name = @Name);

		SET @RowCount = @RowCount - 1;
	END;
 END;
GO


--the interesting for reuse stuff starts here!

--note that I have omitted error handling for clarity of the demos. The code included is almost always strictly
--limited to the meaty bits

CREATE OR ALTER PROCEDURE TreeInGraph.Company$Insert
(
    @Name              varchar(20),
    @ParentCompanyName varchar(20)
)
AS
BEGIN
    SET NOCOUNT ON;

    --Sparse error handling for readability, implement error handling if done for real

	DECLARE @ParentNode nvarchar(1000) = (SELECT $node_id FROM TreeInGraph.Company WHERE name = @ParentCompanyName);     

    IF @ParentCompanyName IS NOT NULL
        AND @ParentNode IS NULL
        THROW 50000, 'Invalid parentCompanyName', 1;
    ELSE
		BEGIN
			--insert done by simply using the Name of the parent to get the key of 
			--the parent...
			INSERT INTO TreeInGraph.Company(Name)
			SELECT @Name;
			
			IF @ParentNode IS NOT NULL
             BEGIN
				DECLARE @ChildNode nvarchar(1000) = (SELECT $node_id FROM TreeInGraph.Company WHERE name = @Name);

				INSERT INTO TreeInGraph.CompanyEdge ($from_id, $to_id) VALUES (@ChildNode,@ParentNode);
			 END;
		END

END;
GO

--this is the exact same script as I will use for every type, with the only difference being the
--schema is Named for the technique. 

EXEC TreeInGraph.Company$Insert @Name = 'Company HQ', @ParentCompanyName = NULL;

EXEC TreeInGraph.Company$Insert @Name = 'Maine HQ', @ParentCompanyName = 'Company HQ';

EXEC TreeInGraph.Company$Insert @Name = 'Tennessee HQ', @ParentCompanyName = 'Company HQ';

EXEC TreeInGraph.Company$Insert @Name = 'Nashville Branch', @ParentCompanyName = 'Tennessee HQ';


--To make it clearer for doing the math, I only put sale data on root nodes. This is also a very 
--reasonable expectation to have in the real world for many situations. It does not really affect the
--outcome if sale data was appended to the non-root nodes.
EXEC TreeInGraph.Sale$InsertTestData @Name = 'Nashville Branch';


EXEC TreeInGraph.Company$Insert @Name = 'Knoxville Branch', @ParentCompanyName = 'Tennessee HQ';

EXEC TreeInGraph.Sale$InsertTestData @Name = 'Knoxville Branch';

SELECT * FROM TreeInGraph.Sale;

EXEC TreeInGraph.Company$Insert @Name = 'Memphis Branch', @ParentCompanyName = 'Tennessee HQ';

EXEC TreeInGraph.Sale$InsertTestData @Name = 'Memphis Branch';

EXEC TreeInGraph.Company$Insert @Name = 'Portland Branch', @ParentCompanyName = 'Maine HQ';

EXEC TreeInGraph.Sale$InsertTestData @Name = 'Portland Branch';

EXEC TreeInGraph.Company$Insert @Name = 'Camden Branch', @ParentCompanyName = 'Maine HQ';

EXEC TreeInGraph.Sale$InsertTestData @Name = 'Camden Branch';
GO

SELECT Company.CompanyId, Company.Name,ParentCompany.Name AS ParentCompanyName
FROM   TreeInGraph.Company
		 LEFT JOIN TreeInGraph.CompanyEdge
			JOIN TreeInGraph.Company AS ParentCompany
				ON ParentCompany.$node_id = CompanyEdge.$to_id
			ON Company.$node_id = CompanyEdge.$from_id

GO

SELECT FromCompany.CompanyId, FromCompany.Name, ToCompany.Name AS ParentCompanyName
FROM   TreeInGraph.Company AS FromCompany, TreeInGraph.CompanyEdge, TreeInGraph.Company AS ToCompany
WHERE   MATCH(FromCompany-(CompanyEdge)->ToCompany)				
			

GO


SELECT Sale.SalesId, Sale.TransactionNumber, Sale.Amount, Sale.CompanyId
FROM   TreeInGraph.Sale;
GO