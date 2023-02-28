
CREATE TABLE AdjacencyList.Company
(
    CompanyId       int         IDENTITY(1, 1) CONSTRAINT PKCompany PRIMARY KEY,
    Name            varchar(20) NOT NULL CONSTRAINT AKCompany_Name UNIQUE,
    ParentCompanyId int         NULL 
	CONSTRAINT FKCompany$isParentOf$AdjacencyListCompany 
									REFERENCES AdjacencyList.Company( CompanyId),
     --used when fetching rows by their parentCompanyId
	INDEX XCorporate_Company_ParentCompanyId (ParentCompanyId)
);


--this object is simply used to generate a Company Name to make the demo a bit more textual.
--it would not be used for a "real" build

CREATE SEQUENCE AdjacencyList.CompanyDataGenerator_SEQUENCE
AS int
START WITH 1;
GO

CREATE TABLE AdjacencyList.Sale
(
    SalesId           int            NOT NULL IDENTITY(1, 1) CONSTRAINT PKSale PRIMARY KEY,
    TransactionNumber varchar(10)    NOT NULL CONSTRAINT AKSale UNIQUE,
    Amount            numeric(12, 2) NOT NULL,
    CompanyId         int            NOT NULL REFERENCES AdjacencyList.Company(CompanyId),
	INDEX XCompanyId (CompanyId, Amount)
);
GO

CREATE OR ALTER PROCEDURE AdjacencyList.Sale$InsertTestData
    @Name     varchar(20), --Note that all procs use natural keys to make it easier for you to work with manually.
                           --If you are implementing this for a tool to manipulate, use the surrogate keys
    @RowCount int = 5
AS
SET NOCOUNT ON;

WHILE @RowCount > 0
BEGIN
    INSERT INTO AdjacencyList.Sale(TransactionNumber, Amount, CompanyId)
    SELECT CAST(NEXT VALUE FOR AdjacencyList.CompanyDataGenerator_SEQUENCE AS varchar(10)),
          .25 * CAST(NEXT VALUE FOR AdjacencyList.CompanyDataGenerator_SEQUENCE AS numeric(12, 2)),
           (   SELECT Company.CompanyId
               FROM   AdjacencyList.Company
               WHERE  Company.Name = @Name);

    SET @RowCount = @RowCount - 1;
END;
GO


--note that I have omitted error handling for clarity of the demos. The code included is almost always strictly
--limited to the meaty bits

CREATE PROCEDURE AdjacencyList.Company$Insert
(
    @Name              varchar(20),
    @ParentCompanyName varchar(20)
)
AS
BEGIN
    SET NOCOUNT ON;

    --Sparse error handling for readability, implement error handling if done for real

    DECLARE @ParentCompanyId int = (   SELECT Company.CompanyId AS ParentCompanyId
                                       FROM   AdjacencyList.Company
                                       WHERE  Company.Name = @ParentCompanyName);

    IF @ParentCompanyName IS NOT NULL
        AND @ParentCompanyId IS NULL
        THROW 50000, 'Invalid parentCompanyName', 1;
    ELSE
        --insert done by simply using the Name of the parent to get the key of 
        --the parent...
        INSERT INTO AdjacencyList.Company(Name, ParentCompanyId)
        SELECT @Name, @ParentCompanyId;
END;
GO






CREATE OR ALTER FUNCTION AdjacencyList.Company$ReturnHierarchy 
(
	@CompanyName varchar(20)
) 
RETURNS @Output TABLE (CompanyId INT, Name VARCHAR(20), Level INT, Hierarchy NVARCHAR(4000), IdHierarchy NVARCHAR(4000), hierarchyDisplay NVARCHAR(4000))
AS 
BEGIN
DECLARE @CompanyId INT = (   SELECT CompanyId
                             FROM   AdjacencyList.Company
                             WHERE  Name = @CompanyName);

--this is the MOST complex method of querying the Hierarchy, by far...
--algorithm is relational recursion

WITH CompanyHierarchy(CompanyId, ParentCompanyId, TreeLevel, IdHierarchy, Hierarchy)
AS (
   --gets the top level in Hierarchy we want. The Hierarchy column
   --will show the row's place in the Hierarchy from this query only
   --not in the overall reality of the row's place in the table
   SELECT CompanyId,
          ParentCompanyId,
          1 AS TreeLevel,
          CASE WHEN Company.ParentCompanyId IS NOT NULL THEN '..' ELSE '' END + '\' + CAST(CompanyId AS VARCHAR(MAX)) + '\' AS IdHierarchy,
          CASE WHEN Company.Name IS NOT NULL THEN '..' ELSE '' END + '\' + CAST(Company.Name AS VARCHAR(MAX)) + '\' AS Hierarchy
   FROM   AdjacencyList.Company
   WHERE  CompanyId = @CompanyId

   UNION ALL

   --joins back to the CTE to recursively retrieve the rows 
   --note that TreeLevel is incremented on each iteration
   SELECT Company.CompanyId,
          Company.ParentCompanyId,
          TreeLevel + 1 AS TreeLevel,
          IdHierarchy  + CAST(Company.CompanyId AS VARCHAR(20)) + '\' AS IdHierarchy,
		  Hierarchy  + CAST(Company.Name AS VARCHAR(20)) + '\' AS Hierarchy
   FROM   AdjacencyList.Company
          INNER JOIN CompanyHierarchy
              --use to get children, since the ParentCompanyId of the child will be set the value
              --of the current row (always confuses me a bit :)
              ON Company.ParentCompanyId = CompanyHierarchy.CompanyId
			--use to get parents, since the parent of the CompanyHierarchy row will be the Company, 
			--not the parent.
			--on Company.CompanyId= CompanyHierarchy.ParentCompanyId
)
--return results from the CTE, joining to the Company data to get the 
--Company Name
INSERT INTO @Output
(
    CompanyId,
    Name,
    Level,
    IdHierarchy,
	Hierarchy,
    HierarchyDisplay
)
SELECT   Company.CompanyId,
         Company.Name,
         CompanyHierarchy.TreeLevel,
         CompanyHierarchy.IdHierarchy,
         CompanyHierarchy.Hierarchy,
		 REPLICATE('--> ',TreeLevel - 1) + Name AS HierarchyDisplay
FROM     AdjacencyList.Company
         INNER JOIN CompanyHierarchy
             ON Company.CompanyId = CompanyHierarchy.CompanyId
RETURN
END
GO



CREATE OR ALTER FUNCTION AdjacencyList.Company$CheckForChild
(
	@CompanyName varchar(20),
	@CheckForChildOfCompanyName VARCHAR(20)
) 
RETURNS Bit
AS 
BEGIN

	DECLARE @output BIT = 0;

	DECLARE @CompanyId INT, @ChildFlag BIT = 0;
	SELECT  @CompanyId = CompanyId
	FROM   AdjacencyList.Company
	WHERE  Name = @CompanyName;

	DECLARE @CheckForChildOfCompanyId int
	SELECT  @CheckForChildOfCompanyId = CompanyId
	FROM   AdjacencyList.Company
	WHERE  Name = @CheckForChildOfCompanyName;

--this is the MOST complex method of querying the Hierarchy, by far...
--algorithm is relational recursion

WITH CompanyHierarchy(CompanyId, ParentCompanyId)
AS (
   --gets the top level in Hierarchy we want. The Hierarchy column
   --will show the row's place in the Hierarchy from this query only
   --not in the overall reality of the row's place in the table
   SELECT CompanyId,
          ParentCompanyId
   FROM   AdjacencyList.Company
   WHERE  CompanyId = @CheckForChildOfCompanyId

   UNION ALL

   --joins back to the CTE to recursively retrieve the rows 
   --note that TreeLevel is incremented on each iteration
   SELECT Company.CompanyId,
          Company.ParentCompanyId
   FROM   AdjacencyList.Company
          INNER JOIN CompanyHierarchy
              --use to get children, since the ParentCompanyId of the child will be set the value
              --of the current row (always confuses me a bit :)
              ON Company.ParentCompanyId = CompanyHierarchy.CompanyId
			--use to get parents, since the parent of the CompanyHierarchy row will be the Company, 
			--not the parent.
			--on Company.CompanyId= CompanyHierarchy.ParentCompanyId
)
--return results from the CTE, joining to the Company data to get the 
--Company Name
	SELECT   @output = 1
	FROM     CompanyHierarchy
    WHERE    CompanyHierarchy.CompanyId = @CompanyId

	
RETURN @output
END
GO



CREATE OR ALTER PROCEDURE AdjacencyList.Company$ReportSales
(
	@DisplayFromNodeName VARCHAR(20) 
)
as
BEGIN

--take the expanded Hierarchy...
	WITH ExpandedHierarchy AS
	(
		--just get all of the nodes of the Hierarchy
		SELECT ISNULL(CompanyId, parentCompanyId) AS ParentCompanyId,
			ISNULL(CompanyId, parentCompanyId) AS ChildCompanyId
		FROM AdjacencyList.Company

		UNION ALL
  
		--get all of the children of each node for aggregating  

		SELECT Parent.ParentCompanyId, Child.CompanyId AS ChildCompanyId
		FROM  ExpandedHierarchy AS Parent
				JOIN AdjacencyList.Company AS Child
						ON Parent.ChildCompanyId = Child.ParentCompanyId
		WHERE  Child.CompanyId IS NOT NULL

	),
	FilterAndSweeten AS (

	SELECT ExpandedHierarchy.*, CompanyHierarchyDisplay.Hierarchy
	from   ExpandedHierarchy
	JOIN AdjacencyList.[Company$ReturnHierarchy](@DisplayFromNodeName) AS CompanyHierarchyDisplay
		ON CompanyHierarchyDisplay.CompanyId = ExpandedHierarchy.ParentCompanyId

	)
	,
	--get totals for each Company for the aggregate
	CompanyTotals AS
	(
		SELECT CompanyId, SUM(Amount) AS TotalAmount
		FROM   AdjacencyList.Sale
		GROUP BY CompanyId
	),

	--aggregate each Company for the Company
	Aggregations AS (
	SELECT FilterAndSweeten.ParentCompanyId,SUM(CompanyTotals.TotalAmount) AS TotalSalesAmount,MAX(FilterAndSweeten.Hierarchy) AS Hiearchy
	FROM   FilterAndSweeten
			 LEFT JOIN CompanyTotals
				ON CompanyTotals.CompanyId = FilterAndSweeten.ChildCompanyId
	GROUP  BY FilterAndSweeten.ParentCompanyId)

	--display the data...
	SELECT Company.CompanyId, Company.ParentCompanyId, Aggregations.TotalSalesAmount,Aggregations.Hiearchy
	FROM   AdjacencyList.Company 
			JOIN Aggregations
			ON Company.CompanyID = Aggregations.ParentCompanyID
	ORDER BY Company.CompanyId, Company.ParentCompanyId
		

END;
GO