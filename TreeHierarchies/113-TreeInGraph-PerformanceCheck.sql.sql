USE HowToOptimizeAHierarchyInSQLServer
go

SET STATISTICS TIME ON
SET STATISTICS IO ON 
GO

DECLARE @CompanyId int = (   SELECT Company.CompanyId
                             FROM   TreeInGraph.Company
										LEFT OUTER JOIN TreeInGraph.CompanyEdge
											JOIN TreeInGraph.Company AS ParentCompany
													ON ParentCompany.$node_id = CompanyEdge.$from_id
									ON CompanyEdge.$from_id = Company.$node_id
                             WHERE  ParentCompany.CompanyId IS NULL);

--this is the MOST complex method of querying the Hierarchy, by far...
--algorithm is relational recursion

WITH CompanyHierarchy(CompanyId, ParentCompanyId, TreeLevel, Hierarchy)
AS (
   --gets the top level in Hierarchy we want. The Hierarchy column
   --will show the row's place in the Hierarchy from this query only
   --not in the overall reality of the row's place in the table
   SELECT Company.CompanyId,
          ParentCompany.CompanyId AS ParentCompanyId,
          1 AS TreeLevel,
          CASE WHEN ParentCompany.CompanyId IS NOT NULL THEN '..' ELSE '' END + '\' + CAST(Company.CompanyId AS varchar(MAX)) + '\' AS Hierarchy
   FROM   TreeInGraph.Company
			LEFT OUTER JOIN TreeInGraph.CompanyEdge
				JOIN TreeInGraph.Company AS ParentCompany
					ON ParentCompany.$node_id = CompanyEdge.$from_id
				ON CompanyEdge.$from_id = Company.$node_id
   WHERE  Company.CompanyId = @CompanyId

   UNION ALL

     --joins back to the CTE to recursively retrieve the rows 
     --note that TreeLevel is incremented on each iteration
     SELECT ToCompany.CompanyId, 
			FromCompany.CompanyId,
            TreeLevel + 1 as TreeLevel,
            Hierarchy + cast(ToCompany.CompanyId AS varchar(20)) + '\'  as Hierarchy
     FROM   CompanyHierarchy, TreeInGraph.Company	AS FromCompany,
			 --Cannot mix joins
			 --JOIN SocialGraph.Person	AS FromPerson
				--ON FromPerson.UserName = PersonHierarchy.UserName,
			TreeInGraph.CompanyEdge,TreeInGraph.Company	AS ToCompany
     WHERE  CompanyHierarchy.CompanyId = FromCompany.CompanyId
	   AND MATCH(ToCompany-(CompanyEdge)->FromCompany)

)
--return results from the CTE, joining to the Company data to get the 
--Company Name
SELECT   Company.CompanyId,
         Company.Name,
         CompanyHierarchy.TreeLevel,
         CompanyHierarchy.Hierarchy
FROM     TreeInGraph.Company
         INNER JOIN CompanyHierarchy
             ON Company.CompanyId = CompanyHierarchy.CompanyId
ORDER BY Hierarchy;
GO
--shows the break between queries
SELECT TOP 1 *
FROM  sys.objects
go

	SET STATISTICS TIME ON
	SET STATISTICS IO ON 
go


--take the expanded Hierarchy...
WITH ExpandedHierarchy(ChildCompanyId, ParentCompanyId)
AS (
	--gets all of the nodes of the hierarchy
   SELECT Company.CompanyId AS ChildCompanyId,
          Company.CompanyId AS ParentCompanyId
   FROM   TreeInGraph.Company
			LEFT OUTER JOIN TreeInGraph.CompanyEdge
				JOIN TreeInGraph.Company AS ParentCompany
					ON ParentCompany.$node_id = CompanyEdge.$from_id
				ON CompanyEdge.$from_id = Company.$node_id
   UNION ALL

     --joins back to the CTE to recursively retrieve the rows 
     --note that TreeLevel is incremented on each iteration

     SELECT ToCompany.CompanyId, 
			ExpandedHierarchy.ParentCompanyId
     FROM  ExpandedHierarchy, TreeInGraph.Company	AS FromCompany,
			 --Cannot mix joins
			 --JOIN SocialGraph.Person	AS FromPerson
				--ON FromPerson.UserName = PersonHierarchy.UserName,
			TreeInGraph.CompanyEdge,TreeInGraph.Company	AS ToCompany
     WHERE ExpandedHierarchy.ChildCompanyId = FromCompany.CompanyId
	   AND MATCH(ToCompany-(CompanyEdge)->FromCompany)

),

     --get totals for each Company for the aggregate
     CompanyTotals
AS (SELECT   CompanyId, SUM(Amount) AS TotalAmount
    FROM     TreeInGraph.Sale
    GROUP BY CompanyId)
	,

     --aggregate each Company for the Company
     Aggregations
AS (SELECT   ExpandedHierarchy.ParentCompanyId, SUM(CompanyTotals.TotalAmount) AS TotalSalesAmount
    FROM     ExpandedHierarchy
             LEFT JOIN CompanyTotals
                 ON CompanyTotals.CompanyId = ExpandedHierarchy.ChildCompanyId
    GROUP BY ExpandedHierarchy.ParentCompanyId)

--display the data...
SELECT   Aggregations.ParentCompanyId, Aggregations.TotalSalesAmount
FROM     TreeInGraph.Company
         JOIN Aggregations
             ON Company.CompanyId = Aggregations.ParentCompanyId
ORDER BY Aggregations.ParentCompanyId;
GO
