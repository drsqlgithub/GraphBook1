use GraphDBTests
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
GO
CREATE INDEX FromId ON TreeInGraph.CompanyEdge($from_id);
CREATE UNIQUE INDEX ToId ON TreeInGraph.CompanyEdge($to_id);

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
