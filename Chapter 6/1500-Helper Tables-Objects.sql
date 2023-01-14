USE GraphDBTests
GO

DROP PROCEDURE IF EXISTS Helper.CompanyHierarchyHelper$Rebuild;
DROP PROCEDURE IF EXISTS Helper.Company$ReportSales
DROP PROCEDURE IF EXISTS Helper.HierarchyDisplayHelper$Rebuild
DROP FUNCTION IF EXISTS Helper.Company$CheckForChild
DROP TABLE IF EXISTS Helper.CompanyHierarchyHelper;
DROP TABLE IF EXISTS [Helper].[HierarchyDisplayHelper]

DROP SCHEMA IF EXISTS Helper;
GO

CREATE SCHEMA Helper;
GO

--this table gives us the expanded hierarchy we used earlier to make 
--aggregation and lookup easier
CREATE TABLE Helper.CompanyHierarchyHelper
(
    ParentCompanyId    int,
    ChildCompanyId     int,
    Distance           int,
    ParentRootNodeFlag bit 
	   CONSTRAINT DFLTCompanyHierarchyHelper_ParentRootNodeFlag DEFAULT 0,
    ChildLeafNodeFlag  bit 
	   CONSTRAINT DFLTCompanyHierarchyHelper_ChildLeafNodeFlag DEFAULT 0,

    CONSTRAINT PKCompanyHierarchyHelper PRIMARY KEY(
        ParentCompanyId,
        ChildCompanyId),
	INDEX ChlldToParent UNIQUE (
	    ChildCompanyId,
		ParentCompanyId
        ),
);
GO


CREATE OR ALTER PROCEDURE Helper.CompanyHierarchyHelper$Rebuild
AS
 BEGIN
  SET NOCOUNT ON;
  TRUNCATE TABLE Helper.CompanyHierarchyHelper;
WITH ExpandedHierarchy (ParentCompanyId, ChildCompanyId, Distance)
AS (
   --gets all of the nodes of the hierarchy because the MATCH doesnt include
   --the self relationship
   SELECT Company.CompanyId AS ParentCompanyId,
          Company.CompanyId AS ChildCompanyId,
		  0 as Distance
   FROM SqlGraph.Company
   
   UNION ALL
   
   --get the parent and child rows, along with the distance from the 
   --root
   SELECT FromCompany.CompanyId as ParentCompanyId,
          LAST_VALUE(ToCompany.CompanyId) 
                         WITHIN GROUP (GRAPH PATH) , 
		  COUNT(ToCompany.Name) 
                         WITHIN GROUP (GRAPH PATH) AS Distance
   FROM SqlGraph.Company AS FromCompany,
        SqlGraph.ReportsTo FOR PATH as ReportsTo,
        SqlGraph.Company FOR PATH AS ToCompany
  WHERE MATCH(SHORTEST_PATH(FromCompany(-(ReportsTo)
                                                 ->ToCompany)+))

)
INSERT INTO  Helper.CompanyHierarchyHelper(ParentCompanyId, ChildCompanyId, Distance)
SELECT ParentCompanyId, ChildCompanyId, Distance
FROM   ExpandedHierarchy

--set the special flags

--root nodes are never children
update  Helper.CompanyHierarchyHelper
set    ParentRootNodeFlag = 1
where  ParentCompanyId not in (select childCompanyId
                               from   Helper.CompanyHierarchyHelper
							   where  parentCompanyId <> ChildCompanyId)

--leaf nodes are never parents
update  Helper.CompanyHierarchyHelper
set    ChildLeafNodeFlag = 1
where  ChildCompanyId not in (select ParentCompanyId
                               from   Helper.CompanyHierarchyHelper
							   where  parentCompanyId <> ChildCompanyId)

END;
GO

CREATE OR ALTER FUNCTION Helper.Company$CheckForChild
(
	@CompanyName varchar(20),
	@CheckForChildOfCompanyName VARCHAR(20)
) 
RETURNS Bit
AS 
BEGIN
	DECLARE @output BIT = 0;

	DECLARE @CompanyId INT, @CheckForChildOfCompanyId INT

	--translate the child companyId from parameter
	SELECT  @CompanyId = CompanyId
	FROM  SQLGraph.Company
	WHERE  Company.Name = @CompanyName;

	SELECT  @CheckForChildOfCompanyId = CompanyId
	FROM  SQLGraph.Company
	WHERE  Company.Name = @CheckForChildOfCompanyName;

	select @Output = 1
	from   Helper.CompanyHierarchyHelper
	WHERE  ParentCompanyId = @CheckForChildOfCompanyId 
	  and  ChildCompanyId = @CompanyId


	RETURN @OutPut

END;
GO

--We can test out the procedure this way:
SELECT (CASE Helper.Company$CheckForChild('Node181','Node1') 
		WHEN 1 THEN 'Yes' ELSE 'No' END) AS Camden_to_Company,
		(CASE Helper.Company$CheckForChild('Node181','Node84') 
		WHEN 1 THEN 'Yes' ELSE 'No' END) AS Camden_to_Maine,
		(CASE Helper.Company$CheckForChild('Node84','Node181') 
		WHEN 1 THEN 'Yes' ELSE 'No' END) AS Camden_to_Tennessee
GO



--Next I want to add another helper table, this time to take the hierarchy 
--view we implemented earlier and now store it in a table. If your data changes
--very infrequently, this can be a very good tool no matter which version
--of a tree you use.

CREATE TABLE [Helper].[HierarchyDisplayHelper](
	CompanyId int NOT NULL CONSTRAINT PKHerarchyDisplayHelper PRIMARY KEY,
	[HierarchyDisplay] [varchar](8000) NULL,
	[Level] [int] NOT NULL,
	[Name] [varchar](20) NOT NULL CONSTRAINT AKHierarchyDisplayHelper UNIQUE,
	[Hierarchy] [varchar](8000) NOT NULL
) ON [PRIMARY]
GO



CREATE PROCEDURE Helper.HierarchyDisplayHelper$Rebuild
AS 
BEGIN
	TRUNCATE TABLE [Helper].[HierarchyDisplayHelper];

	insert into Helper.HierarchyDisplayHelper(CompanyId, HierarchyDisplay, Level, Name, Hierarchy)
	select CompanyId, HierarchyDisplay, Level, Name, Hierarchy
	from   SqlGraph.CompanyHierarchyDisplay
	order by Hierarchy
END;

GO
CREATE OR ALTER PROCEDURE Helper.Company$ReportSales
(
	@DisplayFromNodeName VARCHAR(20) 
)
AS
BEGIN

--fetch the hierarchy for the node you are looking for by name
declare @NodeHierarchy varchar(8000) = (select hierarchy 
						  from Helper.HierarchyDisplayHelper
						  where Name = @DisplayFromNodeName);


--expanded hierarchy is now a table
--as is the display version. 
WITH FilterAndSweeten AS 
(
	SELECT ExpandedHierarchy.*, 
             HierarchyDisplayHelper.Hierarchy,
			HierarchyDisplayHelper.HierarchyDisplay
	from  Helper.CompanyHierarchyHelper AS ExpandedHierarchy
	JOIN Helper.HierarchyDisplayHelper
		on ExpandedHierarchy.ParentCompanyId = HierarchyDisplayHelper.CompanyId
	--filters the search to start iwth the path we sent in
	--the stuff after + makes sure the filter gets everything like the 
	--node we fetched, as long as it doesn't have a following digit. 
	WHERE  HierarchyDisplayHelper.Hierarchy like @NodeHierarchy + '[^0-9]%' 
	  --include the root of the query, not character.
	  or   HierarchyDisplayHelper.Hierarchy = @NodeHierarchy 
)
,--get totals for each Company for the aggregate
     CompanyTotals
AS (SELECT CompanyId,
           SUM(cast(Amount as decimal(20,2))) AS TotalAmount
    FROM SqlGraph.Sale
    GROUP BY CompanyId),

   --aggregate each Company for the Company
   Aggregations AS 
   (SELECT FilterAndSweeten.ParentCompanyId,
           SUM(CompanyTotals.TotalAmount) AS TotalSalesAmount,
           MAX(hierarchy) AS hierarchy,
		   MAX(hierarchyDisplay) AS hierarchyDisplay
    FROM FilterAndSweeten
        JOIN CompanyTotals
            ON CompanyTotals.CompanyId = 
                         FilterAndSweeten.ChildCompanyId
    GROUP BY FilterAndSweeten.ParentCompanyId)

--display the data...
SELECT Aggregations.ParentCompanyId,
	   Aggregations.hierarchyDisplay,
       Aggregations.TotalSalesAmount,
	   hierarchy + '>'
FROM Aggregations
ORDER BY Aggregations.hierarchy
END;
GO

EXEC Helper.HierarchyDisplayHelper$Rebuild
EXEC Helper.CompanyHierarchyHelper$Rebuild;

EXECUTE Helper.Company$ReportSales 'Node21'
GO

