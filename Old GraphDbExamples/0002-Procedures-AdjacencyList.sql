Use GraphDBTests
GO
--the interesting for reuse stuff starts here!

--note that I have omitted error handling for clarity of the demos. The code included is almost always strictly
--limited to the meaty bits

CREATE OR ALTER PROCEDURE AdjacencyList.Company$Insert
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

CREATE OR ALTER PROCEDURE AdjacencyList.Company$Delete
    @Name                varchar(20),
    @DeleteChildRowsFlag bit = 0
AS

BEGIN
    DECLARE @CompanyId int = (   SELECT CompanyId
                                 FROM   AdjacencyList.Company
                                 WHERE  Name = @Name);

    IF @CompanyId IS NULL
    BEGIN
        THROW 50000, 'Invalid Company Name passed in', 1;
        RETURN -100;
    END;

    IF @DeleteChildRowsFlag = 0 --don't delete children
    BEGIN
        --we are trusting the foreign key constraint to make sure that there     
        --are no orphaned rows
        DELETE AdjacencyList.Company
        WHERE CompanyId = @CompanyId;
    END;
    ELSE
    BEGIN
        --deleting all of the child rows, just uses the recursive CTE with a DELETE rather than a 
        --SELECT
        ;WITH CompanyHierarchy(CompanyId, ParentCompanyId, TreeLevel, Hierarchy)
         AS (
            --gets the top level in Hierarchy we want. The Hierarchy column
            --will show the row's place in the Hierarchy from this query only
            --not in the overall reality of the row's place in the table
            SELECT CompanyId,
                   ParentCompanyId,
                   1 AS TreeLevel,
                   CAST(CompanyId AS varchar(MAX)) AS Hierarchy
            FROM   AdjacencyList.Company
            WHERE  CompanyId = @CompanyId

            UNION ALL

            --joins back to the CTE to recursively retrieve the rows 
            --note that TreeLevel is incremented on each iteration
            SELECT Company.CompanyId,
                   Company.ParentCompanyId,
                   TreeLevel + 1 AS TreeLevel,
                   Hierarchy + '\' + CAST(Company.CompanyId AS varchar(20)) AS Hierarchy
            FROM   AdjacencyList.Company
                   INNER JOIN CompanyHierarchy
                       --use to get children, since the ParentCompanyId of the child will be set the value
                       --of the current row
                       ON Company.ParentCompanyId = CompanyHierarchy.CompanyId
         --use to get parents, since the parent of the CompanyHierarchy row will be the Company, 
         --not the parent.
         --on Company.CompanyId= CompanyHierarchy.ParentCompanyId
         )
        --return results from the CTE, joining to the Company data to get the 
        --Company Name
        DELETE AdjacencyList.Company
        FROM AdjacencyList.Company
             INNER JOIN CompanyHierarchy
                 ON Company.CompanyId = CompanyHierarchy.CompanyId;

    END;


END;
GO

CREATE OR ALTER PROCEDURE AdjacencyList.Company$Reparent
(
    @Name                 varchar(20),
    @NewParentCompanyName varchar(20)
)
AS
BEGIN
    --move the Company to a new parent. Very simple with adjacency list
    UPDATE AdjacencyList.Company
    SET    ParentCompanyId = (   SELECT CompanyId AS ParentCompanyId
                                 FROM   AdjacencyList.Company
                                 WHERE  Company.Name = @NewParentCompanyName)
    WHERE  Name = @Name;
END;
GO


CREATE OR ALTER PROCEDURE AdjacencyList.Company$ReturnHierarchy_CTE
(
	@CompanyName varchar(20)
)  AS 
BEGIN
DECLARE @CompanyId int = (   SELECT CompanyId
                             FROM   AdjacencyList.Company
                             WHERE  Name = @CompanyName);

--this is the MOST complex method of querying the Hierarchy, by far...
--algorithm is relational recursion

WITH CompanyHierarchy(CompanyId, ParentCompanyId, TreeLevel, Hierarchy)
AS (
   --gets the top level in Hierarchy we want. The Hierarchy column
   --will show the row's place in the Hierarchy from this query only
   --not in the overall reality of the row's place in the table
   SELECT CompanyId,
          ParentCompanyId,
          1 AS TreeLevel,
          CASE WHEN Company.ParentCompanyId IS NOT NULL THEN '..' ELSE '' END + '\' + CAST(CompanyId AS varchar(MAX)) + '\' AS Hierarchy
   FROM   AdjacencyList.Company
   WHERE  CompanyId = @CompanyId

   UNION ALL

   --joins back to the CTE to recursively retrieve the rows 
   --note that TreeLevel is incremented on each iteration
   SELECT Company.CompanyId,
          Company.ParentCompanyId,
          TreeLevel + 1 AS TreeLevel,
          Hierarchy  + CAST(Company.CompanyId AS varchar(20)) + '\' AS Hierarchy
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
SELECT   Company.CompanyId,
         Company.Name,
         CompanyHierarchy.TreeLevel,
         CompanyHierarchy.Hierarchy
FROM     AdjacencyList.Company
         INNER JOIN CompanyHierarchy
             ON Company.CompanyId = CompanyHierarchy.CompanyId
ORDER BY Hierarchy;
END
GO

CREATE OR ALTER PROCEDURE AdjacencyList.Company$ReturnHierarchy_WHILELOOP
(
	@CompanyName varchar(20)
)  AS 
BEGIN
DECLARE @CompanyId int = (   SELECT CompanyId
                             FROM   AdjacencyList.Company
                             WHERE  Name = @CompanyName);
set nocount on 
--this is the MOST complex method of querying the Hierarchy, by far...
--algorithm is relational recursion

create table #HoldLevels(
CompanyId int PRIMARY KEY,
ParentCompanyId int NULL ,
TreeLevel int not null ,
Hierarchy nvarchar(max),
index  viewer (companyId) include (Hierarchy, treelevel),
index  joiner clustered (treeLevel, parentCompanyId)

)

declare @treeLevel int = 1;
   --gets the top level in Hierarchy we want. The Hierarchy column
   --will show the row's place in the Hierarchy from this query only
   --not in the overall reality of the row's place in the table
   insert into #HoldLevels (CompanyId, ParentCompanyId, TreeLevel, Hierarchy)
   SELECT CompanyId,
	      ParentCompanyId,
          @TreeLevel AS TreeLevel,
          CASE WHEN Company.ParentCompanyId IS NOT NULL THEN '..' ELSE '' END + '\' + CAST(CompanyId AS varchar(MAX)) + '\' AS Hierarchy
   FROM   AdjacencyList.Company
   WHERE  CompanyId = @CompanyId


WHILE 1=1 
BEGIN

   --joins back to the CTE to recursively retrieve the rows 
   --note that TreeLevel is incremented on each iteration
   insert into #HoldLevels (CompanyId, ParentCompanyId, TreeLevel, Hierarchy)
   SELECT Company.CompanyId,
          Company.ParentCompanyId,
          @TreeLevel + 1 AS TreeLevel,
          Hierarchy  + CAST(Company.CompanyId AS varchar(20)) + '\' AS Hierarchy
   FROM   AdjacencyList.Company
          INNER JOIN #HoldLevels as CompanyHierarchy
              --use to get children, since the ParentCompanyId of the child will be set the value
              --of the current row (always confuses me a bit :)
              ON Company.ParentCompanyId = CompanyHierarchy.CompanyId
			     and CompanyHierarchy.TreeLevel = @TreeLevel
			--use to get parents, since the parent of the CompanyHierarchy row will be the Company, 
			--not the parent.
			--on Company.CompanyId= CompanyHierarchy.ParentCompanyId

	if @@ROWCOUNT = 0
		BREAK
	else
		set @treeLevel = @treeLevel + 1

END


--return results from the CTE, joining to the Company data to get the 
--Company Name
SELECT   Company.CompanyId,
         Company.Name,
         CompanyHierarchy.TreeLevel,
         CompanyHierarchy.Hierarchy
FROM     AdjacencyList.Company
         INNER JOIN #HoldLevels as CompanyHierarchy
             ON Company.CompanyId = CompanyHierarchy.CompanyId
ORDER BY Hierarchy;
END
GO

CREATE OR ALTER PROCEDURE AdjacencyList.Company$AggregateHierarchy_CTE
AS
BEGIN
--take the expanded Hierarchy...
WITH ExpandedHierarchy
AS (
   --just get all of the nodes of the Hierarchy
   SELECT ISNULL(CompanyId, ParentCompanyId) AS ParentCompanyId,
          ISNULL(CompanyId, ParentCompanyId) AS ChildCompanyId
   FROM   AdjacencyList.Company

   UNION ALL

   --get all of the children of each node for aggregating  

   SELECT Parent.ParentCompanyId, Child.CompanyId AS ChildCompanyId
   FROM   ExpandedHierarchy AS Parent
          JOIN AdjacencyList.Company AS Child
              ON Parent.ChildCompanyId = Child.ParentCompanyId
   WHERE  Child.CompanyId IS NOT NULL

),
     --get totals for each Company for the aggregate
     CompanyTotals
AS (SELECT   CompanyId, SUM(Amount) AS TotalAmount
    FROM     AdjacencyList.Sale
    GROUP BY CompanyId),

     --aggregate each Company for the Company
     Aggregations
AS (SELECT   ExpandedHierarchy.ParentCompanyId, SUM(CompanyTotals.TotalAmount) AS TotalSalesAmount
    FROM     ExpandedHierarchy
             LEFT JOIN CompanyTotals
                 ON CompanyTotals.CompanyId = ExpandedHierarchy.ChildCompanyId
    GROUP BY ExpandedHierarchy.ParentCompanyId)

--display the data...
SELECT   Company.CompanyId, Company.ParentCompanyId, Aggregations.TotalSalesAmount
FROM     AdjacencyList.Company
         JOIN Aggregations
             ON Company.CompanyId = Aggregations.ParentCompanyId
ORDER BY Company.CompanyId, Company.ParentCompanyId;
END
GO



--AdjacencyList.Company$AggregateHierarchy_CTE

--AdjacencyList.Company$CheckConnectionTo_CTE @AsParentFlag, @AsChildFlag
--AdjacencyList.Company$CheckConnectionTo_WHILELOOP