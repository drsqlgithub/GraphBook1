--/*
--Now that the code to create and manage the tree has been created, let's try out this structure using the two methods discussed earlier. checking child rows for the existence of a member and aggregating the sales for all of the child nodes. Will do it first with the smaller table
--*/
--USE GraphDBTests
--GO

--WITH BaseRows AS (

--SELECT Company.CompanyId,
--            LAST_VALUE(REportingCompany.CompanyId) Within GROUP (graph PATH) AS ReportingCompanyId
--FROM   SqlGraph.Company AS Company,
--            SqlGraph.ReportsTo FOR PATH AS ReportsTo,
--            SqlGraph.Company FOR PATH AS ReportingCompany
--WHERE MATCH(SHORTEST_PATH(Company(-(ReportsTo)->ReportingCompany)+))
--UNION --ALL
--SELECT Company.CompanyId, CompanyId
--FROM   SqlGraph.Company
--),
--Calculation AS (
--SELECT BaseRows.CompanyId, SUM(Amount) AS AmountTotal
--FROM   BaseRows
--            JOIN SqlGraph.Sale
--                  ON BaseRows.ReportingCompanyId = Sale.CompanyId
--GROUP BY BaseRows.CompanyId
--)
--SELECT HierarchyDisplay, AmountTotal
--FROM   Calculation
--		--JOIN SqlGraph.CompanyHierarchyDisplay 
--		--	ON CompanyHierarchyDisplay.CompanyId = Calculation.CompanyId
--ORDER BY Hierarchy;

--GO

/*
Now that the code to create and manage the tree has been created, let's try out this structure using the two methods discussed earlier. checking child rows for the existence of a member and aggregating the sales for all of the child nodes. Will do it first with the smaller table
*/
USE GraphDBTests
GO
DROP TABLE IF EXISTS #ExpandedHierarchy;

WITH ExpandedHierarchy AS (

SELECT Company.CompanyId AS ParentCompanyId,
            LAST_VALUE(REportingCompany.CompanyId) Within GROUP (graph PATH) AS ChildCompanyId
FROM   SqlGraph.Company AS Company,
            SqlGraph.ReportsTo FOR PATH AS ReportsTo,
            SqlGraph.Company FOR PATH AS ReportingCompany
WHERE MATCH(SHORTEST_PATH(Company(-(ReportsTo)->ReportingCompany)+))
UNION ALL
SELECT Company.CompanyId, CompanyId
FROM   SqlGraph.Company
)
SELECT *
INTO #ExpandedHierarchy
FROM  ExpandedHierarchy;

     --get totals for each Company for the aggregate
WITH     CompanyTotals
AS (SELECT   CompanyId, SUM(Amount) AS TotalAmount
    FROM     SqlGraph.Sale
    GROUP BY CompanyId),

     --aggregate each Company for the Company
     Aggregations
AS (SELECT   ExpandedHierarchy.ParentCompanyId, SUM(CompanyTotals.TotalAmount) AS TotalSalesAmount
    FROM     #ExpandedHierarchy AS ExpandedHierarchy
             LEFT JOIN CompanyTotals
                 ON CompanyTotals.CompanyId = ExpandedHierarchy.ChildCompanyId
    GROUP BY ExpandedHierarchy.ParentCompanyId)

--display the data...
SELECT   Company.CompanyId, Aggregations.TotalSalesAmount
FROM     SqlGraph.Company
         JOIN Aggregations
             ON Company.CompanyId = Aggregations.ParentCompanyId
ORDER BY Company.CompanyId
