use GraphDBTests
GO

--The following code is interesting for reuse if you are building a system. Note that I have omitted some error handling for clarity of the demos, but I have tried to always include transactions and a TRY CATCH block so the code is minimally acceptable for even production systems. 

--To start out, we need to be able to insert nodes. Some of the techniques we looked at in Chapter 4 will not be used in this section because this code is going to simulate a more natural process of creating rows as the customer might do it in reality. Fetching the node structures in each call in a procedure is perfectly adequate.

CREATE OR ALTER PROCEDURE SqlGraph.Company$Insert
(
    @Name              varchar(20), --using natural key values to be a bit more natural
    @ParentCompanyName varchar(20)  --and to make sure surrogate values needn't always be the same
)
AS
BEGIN
    SET NOCOUNT ON;

	BEGIN TRY
		BEGIN TRANSACTION

		--fetch the parent of the node
		DECLARE @ParentNode nvarchar(1000) = (SELECT $node_id FROM SqlGraph.Company WHERE name = @ParentCompanyName);     

		IF @ParentCompanyName IS NOT NULL AND @ParentNode IS NULL
			THROW 50000, 'Invalid parentCompanyName', 1;
		ELSE
			BEGIN
				--insert done by simply using the Name of the parent to get the key of 
				--the parent...
				INSERT INTO SqlGraph.Company(Name)
				SELECT @Name;
			
				IF @ParentNode IS NOT NULL
				 BEGIN
					DECLARE @ChildNode nvarchar(1000) = (SELECT $node_id 
														 FROM SqlGraph.Company 
														 WHERE name = @Name);

					INSERT INTO SqlGraph.CompanyEdge ($from_id, $to_id) 
					VALUES (@ParentNode, @ChildNode);
				 END;
			END
			COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
			IF XACT_STATE() <> 0
				ROLLBACK TRANSACTION;
			THROW; --just rethrow the error
	END CATCH;

END;
GO

--Recall from chapter ?, where I introduced tree structures, I started out with this structure (that I will repeat here as Figure 5-1. This is the exact same base script as I will use for every structure, with the only difference being the schema being named for the technique. So let me load the first set of nodes that are not leaf nodes.

EXEC SqlGraph.Company$Insert @Name = 'Company HQ', @ParentCompanyName = NULL;

EXEC SqlGraph.Company$Insert @Name = 'Maine HQ', @ParentCompanyName = 'Company HQ';

EXEC SqlGraph.Company$Insert @Name = 'Tennessee HQ', @ParentCompanyName = 'Company HQ';

EXEC SqlGraph.Company$Insert @Name = 'Nashville Branch', @ParentCompanyName = 'Tennessee HQ';
GO
--Looking at the data:
SELECT * FROM SqlGraph.Company;
SELECT * FROM SqlGraph.CompanyEdge;

--You will see that you have 4 nodes and 3 edges. CompanyHQ's internal id value is 0 (assuming you don't have any errors, which I have had many times and regenerated so I can get the ideal output.


CREATE OR ALTER PROCEDURE SqlGraph.Company$Reparent
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
	FROM   SqlGraph.Company
	WHERE  name = @Name

	SELECT @ToId = $node_id
	FROM   SqlGraph.Company
	WHERE  name = @NewParentCompanyName

	DELETE SqlGraph.CompanyEdge
	WHERE  $from_id = @FromId

	INSERT INTO SqlGraph.CompanyEdge($From_id, $to_id)
	VALUES (@FromId, @ToId)
	

    ----move the Company to a new parent. Very simple with adjacency list
    --UPDATE SqlGraph.Company
    --SET    ParentCompanyId = (   SELECT CompanyId AS ParentCompanyId
    --                             FROM   SqlGraph.Company
    --                             WHERE  Company.Name = @NewParentCompanyName)
    --WHERE  Name = @Name;

	COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE SqlGraph.Company$Delete
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
		FROM   SqlGraph.Company
		WHERE  name = @Name

		BEGIN TRANSACTION

		DELETE SqlGraph.CompanyEdge
        WHERE  $from_id = @CompanyId;

		DELETE SqlGraph.Company
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
		   FROM   SqlGraph.Company
					LEFT OUTER JOIN SqlGraph.CompanyEdge
						JOIN SqlGraph.Company AS ParentCompany
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
			 FROM   CompanyHierarchy, SqlGraph.Company	AS FromCompany,
					 --Cannot mix joins
					 --JOIN SocialGraph.Person	AS FromPerson
						--ON FromPerson.UserName = PersonHierarchy.UserName,
					SqlGraph.CompanyEdge,SqlGraph.Company	AS ToCompany
			 WHERE  CompanyHierarchy.CompanyId = FromCompany.CompanyId
			   AND MATCH(ToCompany-(CompanyEdge)->FromCompany)

		)
		--return results from the CTE, joining to the Company data to get the 
		--Company Name
		SELECT  Company.$node_id AS CompanyNodeId
		INTO    #deleteThese
		FROM     SqlGraph.Company
				 INNER JOIN CompanyHierarchy
					 ON Company.CompanyId = CompanyHierarchy.CompanyId
		ORDER BY Hierarchy;

		BEGIN TRANSACTION

		DELETE SqlGraph.CompanyEdge
        WHERE  $from_id IN (SELECT CompanyNodeId FROM #deleteThese)
		  
		DELETE SqlGraph.CompanyEdge
        WHERE  $to_id IN (SELECT CompanyNodeId FROM #deleteThese)
		  
		DELETE SqlGraph.Company
        WHERE $node_id IN (SELECT CompanyNodeId FROM #deleteThese)

		COMMIT TRANSACTION

    END;


END;
GO




CREATE OR ALTER PROCEDURE SqlGraph.Company$ReturnHierarchy_CTE
(
	@CompanyName varchar(20)
)
AS 

DECLARE @CompanyId int = (   SELECT Company.CompanyId
                             FROM   SqlGraph.Company
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
   FROM   SqlGraph.Company
   WHERE  Company.CompanyId = @CompanyId

   UNION ALL

     --joins back to the CTE to recursively retrieve the rows 
     --note that TreeLevel is incremented on each iteration
     SELECT ToCompany.CompanyId, 
			FromCompany.CompanyId,
            TreeLevel + 1 as TreeLevel,
            Hierarchy + cast(ToCompany.CompanyId AS varchar(20)) + '\'  as Hierarchy
     FROM   CompanyHierarchy, SqlGraph.Company	AS FromCompany,
			 --Cannot mix joins
			 --JOIN SocialGraph.Person	AS FromPerson
				--ON FromPerson.UserName = PersonHierarchy.UserName,
			SqlGraph.CompanyEdge,SqlGraph.Company	AS ToCompany
     WHERE  CompanyHierarchy.CompanyId = FromCompany.CompanyId
	   AND MATCH(FromCompany-(CompanyEdge)->ToCompany)

)
--return results from the CTE, joining to the Company data to get the 
--Company Name
SELECT   Company.CompanyId,
         Company.Name,
         CompanyHierarchy.TreeLevel,
         CompanyHierarchy.Hierarchy
FROM     SqlGraph.Company
         INNER JOIN CompanyHierarchy
             ON Company.CompanyId = CompanyHierarchy.CompanyId
ORDER BY Hierarchy;
GO


CREATE OR ALTER PROCEDURE SqlGraph.Company$ReturnHierarchy_WHILELOOP
(
	@CompanyName varchar(20)
)  AS 

BEGIN

DECLARE @CompanyId int = (   SELECT Company.CompanyId
                             FROM   SqlGraph.Company
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
   FROM   SqlGraph.Company
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
     FROM   #HoldLevels as CompanyHierarchy, SqlGraph.Company	AS FromCompany,
			 --Cannot mix joins
			 --JOIN SocialGraph.Person	AS FromPerson
				--ON FromPerson.UserName = PersonHierarchy.UserName,
			SqlGraph.CompanyEdge,SqlGraph.Company	AS ToCompany
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
FROM     SqlGraph.Company
         INNER JOIN #HoldLevels as CompanyHierarchy
             ON Company.CompanyId = CompanyHierarchy.CompanyId
ORDER BY Hierarchy;

END
GO


CREATE OR ALTER PROCEDURE SqlGraph.Company$ReturnHierarchy_SHORTESTPATH
(
	@CompanyName varchar(20)
)  AS 
BEGIN

	DECLARE @CompanyId int, @NodeName nvarchar(max)
	SELECT  @CompanyId = CompanyId,
			@Nodename = Name
	FROM   SqlGraph.Company
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
		   SqlGraph.Company AS FromCompany,	
		   SqlGraph.CompanyEdge FOR PATH AS CompanyEdge,
		   SqlGraph.Company FOR PATH AS ToCompany
	WHERE 
		   MATCH(SHORTEST_PATH(FromCompany(-(CompanyEdge)->ToCompany)+))
		   AND FromCompany.CompanyId = @companyId
	)
	SELECT * I will 
	FROM  BaseRows
	ORDER BY hierarchy;

END;
GO




