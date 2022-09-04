use GraphDBTests
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




CREATE OR ALTER PROCEDURE TreeInGraph.Company$ReturnHierarchy_CTE
(
	@CompanyName varchar(20)
)
AS 

DECLARE @CompanyId int = (   SELECT Company.CompanyId
                             FROM   TreeInGraph.Company
                             WHERE  Name = @CompanyName);

--this is the MOST complex method of querying the Hierarchy, by far...
--algorithm is relational recursion

WITH CompanyHierarchy(CompanyId, ParentCompanyId, TreeLevel, Hierarchy)
AS (
   --gets the top level in Hierarchy we want. The Hierarchy column
   --will show the row's place in the Hierarchy from this query only
   --not in the overall reality of the row's place in the table
   SELECT Company.CompanyId,
         NULL AS ParentCompanyId,
          1 AS TreeLevel,
           '\' + CAST(Company.CompanyId AS varchar(MAX)) + '\' AS Hierarchy
   FROM   TreeInGraph.Company
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


CREATE OR ALTER PROCEDURE TreeInGraph.Company$ReturnHierarchy_WHILELOOP
(
	@CompanyName varchar(20)
)  AS 

BEGIN

DECLARE @CompanyId int = (   SELECT Company.CompanyId
                             FROM   TreeInGraph.Company
                             WHERE  Name = @CompanyName);

set nocount on 
--this is the MOST complex method of querying the Hierarchy, by far...
--algorithm is relational recursion

create table #HoldLevels(
CompanyId int PRIMARY KEY,
ParentCompanyId int NULL,
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
   SELECT Company.CompanyId,
         NULL AS ParentCompanyId,
          1 AS TreeLevel,
           '\' + CAST(Company.CompanyId AS varchar(MAX)) + '\' AS Hierarchy
   FROM   TreeInGraph.Company
   WHERE  Company.CompanyId = @CompanyId


WHILE 1=1 
BEGIN

   --joins back to the CTE to recursively retrieve the rows 
   --note that TreeLevel is incremented on each iteration
   insert into #HoldLevels (CompanyId, ParentCompanyId, TreeLevel, Hierarchy)
        SELECT ToCompany.CompanyId, 
			FromCompany.CompanyId,
            @TreeLevel + 1 as TreeLevel,
            Hierarchy + cast(ToCompany.CompanyId AS varchar(20)) + '\'  as Hierarchy
     FROM   #HoldLevels as CompanyHierarchy, TreeInGraph.Company	AS FromCompany,
			 --Cannot mix joins
			 --JOIN SocialGraph.Person	AS FromPerson
				--ON FromPerson.UserName = PersonHierarchy.UserName,
			TreeInGraph.CompanyEdge,TreeInGraph.Company	AS ToCompany
     WHERE  CompanyHierarchy.CompanyId = FromCompany.CompanyId
	   AND MATCH(FromCompany-(CompanyEdge)->ToCompany)
	   and  CompanyHierarchy.TreeLevel = @TreeLevel


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
FROM     TreeInGraph.Company
         INNER JOIN #HoldLevels as CompanyHierarchy
             ON Company.CompanyId = CompanyHierarchy.CompanyId
ORDER BY Hierarchy;

END
GO


CREATE OR ALTER PROCEDURE TreeInGraph.Company$ReturnHierarchy_SHORTESTPATH
(
	@CompanyName varchar(20)
)  AS 
BEGIN

	DECLARE @CompanyId int, @NodeName nvarchar(max)
	SELECT  @CompanyId = CompanyId,
			@Nodename = Name
	FROM   TreeInGraph.Company
	WHERE  Name = @CompanyName;

	;WITH baseRows as
	(
	SELECT @companyId as CompanyId, @NodeName as Name, 1 as TreeLevel, '\' + Cast(@companyId as nvarchar(10)) + '\' as hierarchy
	UNION ALL
	SELECT 
		   LAST_VALUE(ToCompany.CompanyId) WITHIN GROUP (GRAPH PATH) AS CompanyId,
		   LAST_VALUE(ToCompany.Name) WITHIN GROUP (GRAPH PATH) AS NodeName,
		   1+COUNT(ToCompany.Name) WITHIN GROUP (GRAPH PATH) AS levels,
		   '\' +  CAST(FromCompany.CompanyId as NVARCHAR(10)) + '\' + STRING_AGG(cast(ToCompany.CompanyId as nvarchar(10)), '\')  WITHIN GROUP (GRAPH PATH) + '\' AS hierarchy
	FROM 
		   TreeInGraph.Company AS FromCompany,	
		   TreeInGraph.CompanyEdge FOR PATH AS CompanyEdge,
		   TreeInGraph.Company FOR PATH AS ToCompany
	WHERE 
		   MATCH(SHORTEST_PATH(FromCompany(-(CompanyEdge)->ToCompany)+))
		   AND FromCompany.CompanyId = @companyId
	)
	SELECT * I will 
	FROM  BaseRows
	ORDER BY hierarchy;

END;
GO




