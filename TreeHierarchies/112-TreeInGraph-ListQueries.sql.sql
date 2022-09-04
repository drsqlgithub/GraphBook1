USE HowToOptimizeAHierarchyInSQLServer;
GO

--===============================================================================
--getting all of the children of a  node (I am assuming just one (another decent thing to require in your
--hierarchies, could call it "root" or "all), but it could be > 1 and it would require revising the query a bit

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

--===============================================================================
--getting the children of a non-root row 
DECLARE @CompanyId int = (   SELECT Company.CompanyId
                             FROM   TreeInGraph.Company
                             WHERE  Name = 'Tennessee HQ');

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

--===============================================================================
--getting the children of a two non-root rows 

DECLARE @ids table (CompanyId int PRIMARY KEY)

INSERT INTO @ids (CompanyId) 
SELECT Company.CompanyId
FROM   TreeInGraph.Company
WHERE Name IN ('Tennessee HQ','Maine HQ');

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
   WHERE  Company.CompanyId IN (SELECT CompanyId FROM @ids)

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

-------------------------------------
--getting the children of two rows that are not the same level

DECLARE @ids table (CompanyId int PRIMARY KEY)

INSERT INTO @ids (CompanyId) 
SELECT Company.CompanyId
FROM   TreeInGraph.Company
WHERE Name IN ('Tennessee HQ','Company HQ');

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
   WHERE  Company.CompanyId IN (SELECT CompanyId FROM @ids)

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



--===============================================================================
--getting the parents of CompanyId for Memphis (pretty much the same query with a small revision,
--which is included in all of these queries to be uncommented)

DECLARE @ids table (CompanyId int PRIMARY KEY)

INSERT INTO @ids (CompanyId) 
SELECT Company.CompanyId
FROM   TreeInGraph.Company
WHERE Name IN ('Memphis Branch');

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
   WHERE  Company.CompanyId IN (SELECT CompanyId FROM @ids)

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
				--reversed for child to parent
	   AND MATCH(FromCompany-(CompanyEdge)->ToCompany)

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



SELECT *
FROM   TreeInGraph.Company
WHERE  name = 'Maine HQ'

SELECT *
FROM   TreeInGraph.CompanyEdge

--===============================================================================
--just like insert, the MOST simple method of reparenting by far!
CREATE OR ALTER PROCEDURE TreeInGraph.Company$Reparent
(
    @Name                 varchar(20),
    @NewParentCompanyName varchar(20)
)
AS
BEGIN
	SET XACT_ABORT ON --simple way to stop tran on failure
	BEGIN TRANSACTION

	DECLARE @FromId nvarchar(1000),
			@ToId nvarchar(1000)
	
	SELECT @FromId = $node_id
	FROM   TreeinGraph.Company
	WHERE  name = @Name

	SELECT @ToId = $node_id
	FROM   TreeinGraph.Company
	WHERE  name = @NewParentCompanyName

	DELETE TreeInGraph.CompanyEdge
	WHERE  $from_id = @FromId

	INSERT INTO TreeInGraph.CompanyEdge($From_id, $to_id)
	VALUES (@FromId, @ToId)
	

    ----move the Company to a new parent. Very simple with adjacency list
    --UPDATE TreeInGraph.Company
    --SET    ParentCompanyId = (   SELECT CompanyId AS ParentCompanyId
    --                             FROM   TreeInGraph.Company
    --                             WHERE  Company.Name = @NewParentCompanyName)
    --WHERE  Name = @Name;

	COMMIT TRANSACTION;
END;
GO

EXEC TreeInGraph.Company$Reparent @Name = 'Maine HQ', @NewParentCompanyName = 'Tennessee HQ';
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

--put things back
EXEC TreeInGraph.Company$Reparent @Name = 'Maine HQ', @NewParentCompanyName = 'Company HQ'
GO

--===============================================================================
--Deleting a node

--our delete either delete a leaf node, or deletes everything along with the 
--node... --a bit more error handling here because it is a bit more complex in nature

CREATE OR ALTER PROCEDURE TreeInGraph.Company$Delete
    @Name                varchar(20),
    @DeleteChildRowsFlag bit = 0
AS

BEGIN

	SET XACT_ABORT ON

    IF @DeleteChildRowsFlag = 0 --don't delete children
    BEGIN
        --we are trusting the foreign key constraint to make sure that there     
        --are no orphaned rows
        
		DECLARE @CompanyId nvarchar(1000)
	
		SELECT @CompanyId = $node_id
		FROM   TreeinGraph.Company
		WHERE  name = @Name

		BEGIN TRANSACTION

		DELETE TreeInGraph.CompanyEdge
        WHERE  $from_id = @CompanyId;

		DELETE TreeInGraph.Company
        WHERE $node_id = @CompanyId;

		COMMIT TRANSACTION

    END;
    ELSE
    BEGIN
        --deleting all of the child rows, just uses the recursive CTE with a DELETE rather than a 
        --SELECT

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
		   WHERE Company.Name = @Name

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
		SELECT  Company.$node_id AS CompanyNodeId
		INTO    #deleteThese
		FROM     TreeInGraph.Company
				 INNER JOIN CompanyHierarchy
					 ON Company.CompanyId = CompanyHierarchy.CompanyId
		ORDER BY Hierarchy;

		BEGIN TRANSACTION

		DELETE TreeInGraph.CompanyEdge
        WHERE  $from_id IN (SELECT CompanyNodeId FROM #deleteThese)
		  
		DELETE TreeInGraph.CompanyEdge
        WHERE  $to_id IN (SELECT CompanyNodeId FROM #deleteThese)
		  
		DELETE TreeInGraph.Company
        WHERE $node_id IN (SELECT CompanyNodeId FROM #deleteThese)

		COMMIT TRANSACTION

    END;


END;
GO

--add a few rows to test the delete. No activity rows because that would limit deletes
EXEC TreeInGraph.Company$Insert @Name = 'Georgia HQ', @ParentCompanyName = 'Company HQ';

EXEC TreeInGraph.Company$Insert @Name = 'Atlanta Branch', @ParentCompanyName = 'Georgia HQ';

EXEC TreeInGraph.Company$Insert @Name = 'Dalton Branch', @ParentCompanyName = 'Georgia HQ';

EXEC TreeInGraph.Company$Insert @Name = 'Texas HQ', @ParentCompanyName = 'Company HQ';

EXEC TreeInGraph.Company$Insert @Name = 'Dallas Branch', @ParentCompanyName = 'Texas HQ';

EXEC TreeInGraph.Company$Insert @Name = 'Houston Branch', @ParentCompanyName = 'Texas HQ';
GO


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
   --WHERE  Company.Name = 'Company HQ'

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
--===============================================================================

--try to delete Georgia
EXEC TreeInGraph.Company$Delete @Name = 'Georgia HQ';
GO

--delete Atlanta
EXEC TreeInGraph.Company$Delete @Name = 'Atlanta Branch';
GO 

SELECT *
FROM   TreeInGraph.Company;
GO

EXEC TreeInGraph.Company$Delete @Name = 'Georgia HQ', @DeleteChildRowsFlag = 1;

SELECT *
FROM   TreeInGraph.Company;

EXEC TreeInGraph.Company$Delete @Name = 'Texas HQ', @DeleteChildRowsFlag = 1;

SELECT *
FROM   TreeInGraph.Company;

-----------------------------------
--Aggregating along a Hierarchy

--Inspired by:
--http://go4answers.webhost4life.com/Example/Hierarchy-aggregation-41974.aspx
--Thanks to Alejandro Mesa (Hunchback)

--get an expanded Hierarchy view.
-- bascially for each parent, a list of all children (will look familiar later as this is the basis of another method)

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

)
--return results from the CTE, joining to the Company data to get the 
--Company Name
SELECT  ExpandedHierarchy.ParentCompanyId,
        ExpandedHierarchy.ChildCompanyId
FROM    ExpandedHierarchy
ORDER BY ParentCompanyId         

GO




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
