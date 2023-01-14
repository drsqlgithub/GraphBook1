USE GraphDBTests
GO
/********************
Simple adjacency list
********************/

DROP PROCEDURE IF EXISTS SqlGraph.Sale$InsertTestData;
DROP PROCEDURE IF EXISTS SqlGraph.Company$Reparent;
DROP PROCEDURE IF EXISTS SqlGraph.Company$Delete;
DROP PROCEDURE IF EXISTS SqlGraph.Company$Insert;
DROP PROCEDURE IF EXISTS SqlGraph.Company$ReportSales
DROP FUNCTION IF EXISTS SqlGraph.Company$returnHierarchyHelper;
DROP FUNCTION IF EXISTS SqlGraph.Company$ReturnHierarchy;
DROP PROCEDURE IF EXISTS SqlGraph.Sale$InsertTestData;
DROP VIEW IF EXISTS SqlGraph.CompanyClean;
DROP VIEW IF EXISTS SqlGraph.CompanyHierarchyDisplay;
DROP FUNCTION IF EXISTS SqlGraph.Company$CheckForChild
DROP TABLE IF EXISTS SqlGraph.Sale;
DROP TABLE IF EXISTS SqlGraph.DataSetStats;
DROP TABLE IF EXISTS SqlGraph.ReportsTo;
DROP TABLE IF EXISTS SqlGraph.Company;
DROP SEQUENCE IF EXISTS SqlGraph.CompanyDataGenerator_SEQUENCE;

/*
In this chapter we are going to implement a tree using SQL Server graph tables using a very simple structure. Using this same basic structure, I will implement several different methods of implementing a graph using SQL Server tables, starting with the one that fits the main theme of this book, node and edge tables in SQL Server. In this chapter we will do a variety of tasks, starting with maintaining the structure, then doing some text operations with the structure. 
*/

----------------------------------------------------------------------------------------------------------
--*****
--Creating the structure
--*****
----------------------------------------------------------------------------------------------------------

--to get started, I am going to create a schema with a few tables. The schema is named for the algorithm/pattern we are using, because it will let me vary the pattern in multiple ways for different methods of implementing a tree. As mentioned back in Chapter 2, thee are a number of method that I wil cover in varying levels of detail. I will spend this chapter on the SQL graph method, then cover the other methods in the next chapter in brief (While the exact same stored procedures for loading the structures will be in the downloads, including all of the test scripts, I will only discuss them at a hight level.

DROP SCHEMA IF EXISTS SqlGraph;
GO

CREATE SCHEMA SqlGraph;
GO


--The Company table is going to be the simplest possible. However, consider this object to be analagous to your typical customer table in your database. All the other attributes you might want in your table you should add. Headquarter addresse, nickname, whatever has a 1-1 cardinality with the concept of a company you might be modeling. This could really be anything too. A person, a management hierarchy, whatever you might build a tree to implement. My object will strictly have a unique, autogenerated integer, and a name. Both of these will have uniqueness constraints, and the surrogate integer key (CompanyId) will be the clustering key. Unlike a simple adjacency list, which might contain a column named like "ParentCompanyId" to indicate the hierarchy, as we have seen using SQL Graph objects in the previous chapters, the graph structures will be in a seperate, edge, table.
CREATE TABLE SqlGraph.Company
(
    CompanyId INT IDENTITY(1, 1) 
         CONSTRAINT PKCompany PRIMARY KEY,
    Name VARCHAR(20) NOT NULL 
         CONSTRAINT AKCompany_Name UNIQUE,
	RootNodeFlag bit NOT NULL CONSTRAINT DFLTCompany_RootNodeFlag DEFAULT(0)
) AS NODE;

create unique index rootNode on SqlGraph.Company (RootNodeFlag) where RootNodeFlag = 1;

--Creating the edge for a tree (as it will for a bill of materials directed acyclic graph) will all be links from a node to a node. In the edge, I will not include any columns in the edge, but you might in a real table want to include at least the time when the row was created, and maybe a time when the relationship was established (which might be the same time, but likely should not be the same column (since the relationship might have been established earlier than the row was actually created. Even on the web you might want data to go through some workflow before being inserted into your main database. Keeping this simple will just simply keep the example simple.
CREATE TABLE SqlGraph.ReportsTo
(
	CONSTRAINT EC_ReportsTo$DefinesParentOf CONNECTION (SqlGraph.Company TO SqlGraph.Company) ON DELETE NO ACTION
)
AS EDGE;


--Next, I am going to add a few indexes to support queries. The first is the clustered index, and for this structure I am going to cluster the table on the $to_id value. This is because the most expensive queries will be fetching rows based on the $to_id when doing breadth first queries. I am going to make it a UNIQUE constraint because for this object to be a strict tree, each $to_id should only show up once in the structure. (Note that you could implement multiple trees by adding a name for the specific structures in the object and including it in the index. I won't do that as any specific example because the code is very much the same, except for filtering on the tree you are working with. Using column values to add structures like that is less efficient, but definitely more flexible than needing a new edge object for each individual strucuture.

ALTER TABLE SqlGraph.ReportsTo 
   ADD CONSTRAINT AKReportsTo UNIQUE CLUSTERED ($to_id);
CREATE INDEX FromId ON SqlGraph.ReportsTo($from_id);


--There will be two specific demonstrations of performance I wil be showing that you will likely need for many of your tree objects. The first is summing activity of child objects. This is analagous to a company that has sales in multiple regions. And each regions have subregions and so on down to different locations. The second scenario is finding out if you have a child in the hierarchy, and who your predecessors are in the structure. I will use my simulated data structure to demonstrate each of these scenarios. (Not only with SQL Graph, but the exact same scenarios with each algorithm with varying amounts of data)

--The following object is simply used to generate a Company some sales that are the same in every case to make the demo a bit complicated. There will be a stored procedure to create each node, and to add sales to certain nodes (in my demonstration code, it is all of the leaf nodes). Because I assign sales sequentially, and in the same number each time, all of the example output is the same.


CREATE SEQUENCE SqlGraph.CompanyDataGenerator_SEQUENCE
AS INT
START WITH 1;
GO

CREATE TABLE SqlGraph.Sale
(
    SalesId int NOT NULL IDENTITY(1, 1) 
               CONSTRAINT PKSale PRIMARY KEY,
    TransactionNumber varchar(10) NOT NULL 
               CONSTRAINT AKSale UNIQUE,
    Amount            numeric(12, 2) NOT NULL,
    CompanyId         int            NOT NULL 
               CONSTRAINT FKSale$Ref$Company 
                      REFERENCES SqlGraph.Company(CompanyId),
    INDEX XCompanyId (CompanyId, Amount)
);
GO


--The SqlGraph.Sale table is here for when we do aggregations to make the situation more "real". Note that I just use a sequential number for the Amount multiplied by .25. 
--This is the stored procedure for creating the test sales data.


CREATE  PROCEDURE SqlGraph.Sale$InsertTestData
    @Name     varchar(20), 
        --Note that all procs use natural keys to make it easier 
        --for you to work with manually.
        --If you are implementing this for a tool to manipulate, 
        --use surrogate keys where possible
    @RowCount int = 5 
       --you can vary the number of sales, if you want
AS
BEGIN
	SET NOCOUNT ON;

	WHILE @RowCount > 0
	BEGIN
		INSERT INTO SqlGraph.Sale(TransactionNumber, Amount, 
                        CompanyId)
		SELECT CAST(NEXT VALUE FOR 
                          SqlGraph.CompanyDataGenerator_SEQUENCE 
                        AS varchar(10)),
			 .25 * CAST(NEXT VALUE FOR 
                          SqlGraph.CompanyDataGenerator_SEQUENCE 
                         AS numeric(12, 2)),
                     --fetch the surrogate key
			   (   SELECT Company.CompanyId
				   FROM   SqlGraph.Company
				   WHERE  Company.Name = @Name);

		SET @RowCount = @RowCount - 1;
	END;
 END;
GO

-- In all of the code presented, I will use natural key values so the scripts don�t have to care what the internal implementation is. If building a stored procedure interface for an application, you might let it look up the surrogate keys, but when building an interface where you work WITH it in an ad-hoc manner, natural keys are far easier to code with.
CREATE OR ALTER PROCEDURE SqlGraph.Company$Insert
(
    @Name VARCHAR(20), 
          --using natural key values to be a bit more natural
    @ParentCompanyName VARCHAR(20)  
          --and to make sure surrogate values needn't always 
          --be the same
)
AS
BEGIN
    SET NOCOUNT ON;
     BEGIN TRY
        BEGIN TRANSACTION
          --fetch the parent of the node
          DECLARE @ParentNode NVARCHAR(1000) = 
                        (SELECT $node_id 
                         FROM SqlGraph.Company 
                         WHERE name = @ParentCompanyName);     

          IF @ParentCompanyName IS NOT NULL 
                             AND @ParentNode IS NULL
               THROW 50000, 'Invalid parentCompanyName', 1;
          ELSE
               BEGIN
                    --insert done by simply using the Name of the 
                    --parent to get the key of 
                    --the parent...

					IF @ParentNode IS NULL
					 BEGIN 
						--there are places where it is advantagous to know what node is the root node
						--especially since we will generally just want one.
						INSERT INTO SqlGraph.Company(Name, RootNodeFlag)
						SELECT @Name,1;
					 END
					ELSE              
                     BEGIN
						INSERT INTO SqlGraph.Company(Name)
						SELECT @Name;

                        DECLARE @ChildNode nvarchar(1000) = 
                                         (SELECT $node_id 
                                          FROM SqlGraph.Company 
                                          WHERE name = @Name);

                         INSERT INTO SqlGraph.ReportsTo 
                                             ($from_id, $to_id) 
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

EXEC SqlGraph.Company$Insert @Name = 'Company HQ', @ParentCompanyName = NULL;

EXEC SqlGraph.Company$Insert @Name = 'Maine HQ', @ParentCompanyName = 'Company HQ';

EXEC SqlGraph.Company$Insert @Name = 'Tennessee HQ', @ParentCompanyName = 'Company HQ';

--Looking at the data that was just inserted:

SELECT CAST($node_id AS VARCHAR(64)) AS [$node_id],
       CompanyId,
       Name 
FROM SqlGraph.Company;

SELECT CAST($edge_id as varchar(64)) as [$edge_id],
       CAST($from_id as varchar(64)) as [$from_id],
       CAST($to_id as varchar(64)) as [$to_id]
FROM   SqlGraph.ReportsTo;
GO

--execute the code in 0001-Tools.sql before continuing

SELECT  Tools.Graph$NodeIdFormat($node_id,0) AS [$node_id],
       CompanyId,
       Name 
FROM SqlGraph.Company;

SELECT Tools.Graph$EdgeIdFormat($edge_id,0) AS [$edge_id],
       Tools.Graph$NodeIdFormat($from_id,0) AS [$from_id],
       Tools.Graph$NodeIdFormat($to_id,0) AS [$to_id] 
FROM SqlGraph.ReportsTo;
GO

--Next, I am going to add my first leaf node. To make the whole example clearer for doing the math, I only put sale data on root nodes. This is also a very reasonable expectation to have in the real world for many situations. It does not really affect the outcome if sale data was appended to the non-root nodes either, but it would be very typical for the stores or salespersons to have sales, but the region to only have sales based on the stores or salespersons.
EXEC SqlGraph.Company$Insert @Name = 'Nashville Branch', 
                       @ParentCompanyName = 'Tennessee HQ';
EXEC SqlGraph.Sale$InsertTestData @Name = 'Nashville Branch';
GO

--After executing that code, you can see the sale data inserted here:
SELECT *
FROM   SqlGraph.Sale;
GO

--I use this set of data as my unit test for all these algorithms. Using this query, you can see the values in the table:
SELECT Name, SUM(amount)
FROM   SqlGraph.Sale
		JOIN SqlGraph.Company
			ON Company.CompanyId = Sale.CompanyId
GROUP BY Name;

--Now insert the rest of the data for the graph, adding sales for all of the leaf nodes.
EXEC SqlGraph.Company$Insert @Name = 'Knoxville Branch', @ParentCompanyName = 'Tennessee HQ';

EXEC SqlGraph.Sale$InsertTestData @Name = 'Knoxville Branch';

EXEC SqlGraph.Company$Insert @Name = 'Memphis Branch', @ParentCompanyName = 'Tennessee HQ';

EXEC SqlGraph.Sale$InsertTestData @Name = 'Memphis Branch';

EXEC SqlGraph.Company$Insert @Name = 'Portland Branch', @ParentCompanyName = 'Maine HQ';

EXEC SqlGraph.Sale$InsertTestData @Name = 'Portland Branch';

EXEC SqlGraph.Company$Insert @Name = 'Camden Branch', @ParentCompanyName = 'Maine HQ';

EXEC SqlGraph.Sale$InsertTestData @Name = 'Camden Branch';
GO

--The following query will give us the nodes in the tree including the root:

--get the root
SELECT Company.CompanyId, Company.Name, NULL AS ParentCompanyId
FROM  SqlGraph.Company
WHERE  RootNodeFlag = 1
UNION ALL						
--get all the children of the root. Our tree can only have the one root since we have a UNIQUE constraint on the $to_id column
SELECT Company.CompanyId, Company.Name, ParentCompany.CompanyId AS ParentCompanyId
FROM   SqlGraph.Company,
	   SqlGraph.ReportsTo,
	   SqlGraph.Company AS ParentCompany
WHERE MATCH(Company<-(ReportsTo)-ParentCompany);
GO

--view for easy retrieval of rows in the node table:

CREATE VIEW SqlGraph.CompanyClean 
AS 
SELECT Company.CompanyId, Company.Name, NULL AS ParentCompanyId
FROM  SqlGraph.Company
WHERE  $node_id NOT IN (SELECT  $to_id
						FROM    SqlGraph.ReportsTo)
UNION ALL						
--get all the children of the root. Our tree can only have the one root since we have a UNIQUE constraint on the $to_id column
SELECT Company.CompanyId, Company.Name, ParentCompany.CompanyId AS ParentCompanyId
FROM   SqlGraph.Company,
	   SqlGraph.ReportsTo,
	   SqlGraph.Company AS ParentCompany
WHERE MATCH(Company<-(ReportsTo)-ParentCompany);
GO

--Next up, there are few operations that I need to demonstrate how we look at the data in a semi graphical manner. In the following query, I will output the data as a hierarchy, showing the path through the tree (I commented out the Name column, as it is also represented at the last value in the hierarchy:
SELECT 0 AS Level, Company.Name AS Hierarchy --,Company.Name
FROM  SqlGraph.Company
WHERE  $node_id NOT IN (SELECT  $to_id
                        FROM    SqlGraph.ReportsTo)
UNION ALL
SELECT    COUNT(ReportsToCompany.CompanyId) 
                          WITHIN GROUP (GRAPH PATH) ,
          Company.NAME + '->' + 
          STRING_AGG(ReportsToCompany.name, '->') 
                       WITHIN GROUP (GRAPH PATH) AS Friends
          --,LAST_VALUE(ReportsToCompany.name) 
            --       WITHIN GROUP (GRAPH PATH) AS LastNode
FROM    SqlGraph.Company AS Company, 
        SqlGraph.ReportsTo FOR PATH AS ReportsTo,
        SqlGraph.Company FOR PATH AS ReportsToCompany
WHERE MATCH(SHORTEST_PATH(Company(-(ReportsTo)->ReportsToCompany)+))
  AND Company.RootNodeFlag = 1
GO

--Using this output (plus including the Name column), I will make that a CTE and then use the level column to indent each item, and the Hierarchy column to sort by:
WITH BaseRows AS
(
SELECT 0 AS Level, Company.Name AS Hierarchy ,Company.Name
FROM  SqlGraph.Company
WHERE  $node_id NOT IN (SELECT  $to_id
                        FROM    SqlGraph.ReportsTo)
UNION ALL
SELECT    COUNT(ReportsToCompany.CompanyId) 
                          WITHIN GROUP (GRAPH PATH) ,
          Company.NAME + '->' + 
          STRING_AGG(ReportsToCompany.name, '->') 
                       WITHIN GROUP (GRAPH PATH) AS Friends
          ,LAST_VALUE(ReportsToCompany.name) 
                   WITHIN GROUP (GRAPH PATH) AS LastNode
FROM    SqlGraph.Company AS Company, 
        SqlGraph.ReportsTo FOR PATH AS ReportsTo,
        SqlGraph.Company FOR PATH AS ReportsToCompany
WHERE MATCH(SHORTEST_PATH(Company(-(ReportsTo)->ReportsToCompany)+))
  AND Company.RootNodeFlag = 1
)
SELECT REPLICATE('--> ',Level) + Name AS HierarchyDisplay
FROM   BaseRows
ORDER BY Hierarchy;
GO


CREATE OR ALTER VIEW SqlGraph.CompanyHierarchyDisplay
AS 
WITH BaseRows AS
(
SELECT  CompanyId, 0 AS Level, Company.Name AS Hierarchy ,Company.Name
FROM  SqlGraph.Company
WHERE  $node_id NOT IN (SELECT  $to_id
                        FROM    SqlGraph.ReportsTo)
UNION ALL
SELECT    LAST_VALUE(ReportsToCompany.CompanyId) 
                   WITHIN GROUP (GRAPH PATH) AS CompanyId,
		  COUNT(ReportsToCompany.CompanyId) 
                          WITHIN GROUP (GRAPH PATH) as Level,
          Company.NAME + '->' + 
          STRING_AGG(ReportsToCompany.name, '->') 
                       WITHIN GROUP (GRAPH PATH) AS Hierarchy
          ,LAST_VALUE(ReportsToCompany.name) 
                   WITHIN GROUP (GRAPH PATH) AS Name
FROM    SqlGraph.Company AS Company, 
        SqlGraph.ReportsTo FOR PATH AS ReportsTo,
        SqlGraph.Company FOR PATH AS ReportsToCompany
WHERE MATCH(SHORTEST_PATH(Company(-(ReportsTo)->ReportsToCompany)+))
  and Company.RootNodeFlag = 1
  
)
SELECT CompanyId, REPLICATE('--> ',Level) + Name AS HierarchyDisplay, Level, Name,Hierarchy
FROM   BaseRows;
GO


--The following code implements the reparent operation (You would need to make sure and copy any attribute values if you have attributes in your edge object.):
CREATE OR ALTER PROCEDURE SqlGraph.Company$Reparent
(
    @Name varchar(20), --again using natural key values
    @NewParentCompanyName varchar(20)
)
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY;
	BEGIN TRANSACTION;

	--get the new location you wish to change to
                   --the from is what is changing
	DECLARE @FromId nvarchar(1000), 
			@ToId nvarchar(1000) -- to id will not change
	
	--use the natural key values to fetch the $from_id/$to_id
	SELECT @FromId = $node_id
	FROM   SqlGraph.Company
	WHERE  name = @NewParentCompanyName;

	SELECT @ToId = $node_id
	FROM   SqlGraph.Company
	WHERE  name = @Name;
	
	--Delete the old edge, and since this isn't changing
	--it will remain the same
	DELETE SqlGraph.ReportsTo
	WHERE  $to_id = @ToId;

	--create a new edge
	INSERT INTO SqlGraph.ReportsTo($From_id, $to_id)
	VALUES (@FromId, @ToId);
	
	--finish up
	COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
			IF XACT_STATE() <> 0
				ROLLBACK TRANSACTION;
			THROW; --just rethrow the error
	END CATCH;

END;
GO

--Now let's reparent 'Maine HQ' to be under 'Tennessee HQ'
SELECT HierarchyDisplay
FROM SqlGraph.CompanyHierarchyDisplay
ORDER BY hierarchy
GO

--Now let's reparent 'Maine HQ' to be under 'Tennessee HQ'
EXEC SqlGraph.Company$Reparent @Name = 'Maine HQ',  
                     @NewParentCompanyName = 'Tennessee HQ';
GO

SELECT HierarchyDisplay
FROM SqlGraph.CompanyHierarchyDisplay
ORDER BY hierarchy
GO

--Now put 'Maine HQ' back where it belongs using the following code.
EXEC SQLGraph.Company$Reparent @Name = 'Maine HQ', @NewParentCompanyName = 'Company HQ';

SELECT HierarchyDisplay
FROM SqlGraph.CompanyHierarchyDisplay
ORDER BY hierarchy
GO

--deletes
--These possibilities are implemented with three parameters. The name of the node to delete, one to say if you should attempt to delete the child nodes, and one to reparent any child nodes that exist. This code is very long, but it is commented to explain how the delete operations are being done.
CREATE OR ALTER PROCEDURE SqlGraph.Company$Delete
    @Name   varchar(20),
    @DeleteChildNodesFlag bit = 0,
    @ReparentChildNodesToParentFlag BIT = 0
AS

BEGIN
    SET NOCOUNT ON;
    BEGIN TRY;

    IF @DeleteChildNodesFlag = 1 AND 
                         @ReparentChildNodesToParentFlag = 1
        THROW 50000,'Both @DeleteChildNodesFlag and (wrap) 
         @ReparentChildNodesToParentFlag cannot be set to 1', 1;


    IF @DeleteChildNodesFlag = 1
    BEGIN

            --use this to get all the children of 
            --node to be deleted
            --we need not only the direct descendants (which we 
            --will use for reparenting the 
            --child rows), but their decendents too so we can
            --delete everything.
            SELECT  LAST_VALUE(ReportsTo.$to_id) 
                  WITHIN GROUP (GRAPH PATH) AS  CompanyNodeId
            INTO	#deleteThese
            FROM    SqlGraph.Company AS Company, 
                        SqlGraph.ReportsTo FOR PATH AS ReportsTo,
                        SqlGraph.Company FOR PATH 
                                             AS ReportsToCompany
            WHERE MATCH(SHORTEST_PATH(Company(-(ReportsTo)-
                                            >ReportsToCompany)+))
              AND Company.Name =@name

            --this is the node that was originally requested to 
            --be deleted
            INSERT INTO #deleteThese
            SELECT $node_id 
            FROM SqlGraph.Company 
            WHERE name = @Name;

          --Now remove all traces of the parent and children 
          --as a from or a to in a relationship, then remove the 
          --company rows.
         BEGIN TRANSACTION;

        DELETE SqlGraph.ReportsTo
        WHERE  $from_id IN (SELECT CompanyNodeId 
                            FROM #deleteThese);

        DELETE SqlGraph.ReportsTo
        WHERE  $to_id IN (SELECT CompanyNodeId 
                          FROM #deleteThese);

        DELETE SqlGraph.Company
        WHERE  $Node_id IN (SELECT CompanyNodeId 
                            FROM  #deleteThese);

        COMMIT TRANSACTION;

    END;
    ELSE IF @ReparentChildNodesToParentFlag = 1
    BEGIN

        --fetch the direct decendents of the row to reparent
        SELECT $to_id AS ToId
        INTO   #reparentThese
        FROM   SqlGraph.ReportsTo

    WHERE  $from_id = (SELECT $node_Id
                       FROM  SqlGraph.Company
                       WHERE  Name = @Name)

    --this gets the parent row where you will move the child rows
        --to. Would not work to remove the root
        DECLARE @NewFromId NVARCHAR(1000) = (
                        SELECT $from_id
                        FROM   SqlGraph.ReportsTo
                        WHERE  $to_id= (SELECT $node_Id
                                        FROM  SqlGraph.Company
                                        WHERE  Name = @Name));

        --delete the reporting rows for the rows to be
            -- reparented
        DELETE FROM SqlGraph.ReportsTo
        WHERE  $to_id IN (SELECT ToId FROM #reparentThese)

        --delete reporting rows for the row to be deleted
        DELETE FROM SqlGraph.ReportsTo
        WHERE  $to_id IN (SELECT $node_Id
                              FROM  SqlGraph.Company
                              WHERE  Name = @Name)

        --if the parent is not null, create new rows
         IF @NewFromId IS NOT NULL
                 INSERT INTO SqlGraph.ReportsTo
                 (
                   $from_id, $to_id
                  )
                  SELECT @NewFromId, ToId
                  FROM   #reparentThese
          ELSE
             THROW 50000,
                 'The parent row did not exist, operation fails'
                            ,1;

        --delete the company
        DELETE FROM SqlGraph.Company
        WHERE  $node_id = (SELECT $node_Id
                           FROM  SqlGraph.Company
                           WHERE  Name = @Name)

        END
    ELSE
        BEGIN
        --we are trusting the edge and foreign key constraint 
        --to make sure that there are no orphaned rows
        DECLARE @CompanyNodeId nvarchar(1000)

        --fetch the node id of the company
        SELECT @CompanyNodeId = $node_id
        FROM   SqlGraph.Company
        WHERE  name = @Name

        --try to delete it
        BEGIN TRANSACTION

        DELETE SqlGraph.ReportsTo
        WHERE  $to_id = @CompanyNodeId;

        DELETE SqlGraph.Company
        WHERE $node_id = @CompanyNodeId;

        COMMIT TRANSACTION

    END;

  END TRY
  BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW; --just rethrow the error
  END CATCH;
END;
GO

--add a few rows to test the delete. No activity rows because that would 
--limit deletes in a way that is immaterial to the example
EXEC SqlGraph.Company$Insert @Name = 'Georgia HQ', @ParentCompanyName = 'Company HQ';
EXEC SqlGraph.Company$Insert @Name = 'Atlanta Branch', @ParentCompanyName = 'Georgia HQ';
EXEC SqlGraph.Company$Insert @Name = 'Dalton Branch', @ParentCompanyName = 'Georgia HQ';
EXEC SqlGraph.Company$Insert @Name = 'Texas HQ', @ParentCompanyName = 'Company HQ';
EXEC SqlGraph.Company$Insert @Name = 'Dallas Branch', @ParentCompanyName = 'Texas HQ';
EXEC SqlGraph.Company$Insert @Name = 'Houston Branch', @ParentCompanyName = 'Texas HQ';
GO

--Now, look at the nodes in the tree:
SELECT HierarchyDisplay
FROM SqlGraph.CompanyHierarchyDisplay
ORDER BY hierarchy;

--Try to delete Georgia, using only the default parameters (leaving children rows alone)
EXEC SqlGraph.Company$Delete @Name = 'Georgia HQ'; --will cause an error
GO

--delete Atlanta
EXEC SqlGraph.Company$Delete @Name = 'Atlanta Branch';
GO

--Now, look at the nodes in the tree:
SELECT HierarchyDisplay
FROM SqlGraph.CompanyHierarchyDisplay
ORDER BY hierarchy;
GO

--Check the structure and you will see the 'Atlanta Branch' row is gone. Next, try the deleting ChildRows:
EXEC SqlGraph.Company$Delete @Name = 'Georgia HQ', @DeleteChildNodesFlag = 1;
GO

--Now, look at the nodes in the tree:
SELECT HierarchyDisplay
FROM SqlGraph.CompanyHierarchyDisplay
ORDER BY hierarchy;
GO

EXEC SqlGraph.Company$Delete @Name = 'Texas HQ', @ReparentChildNodesToParentFlag = 1;
GO

--Finally, clean up the nodes that are left over from this example:

EXEC SqlGraph.Company$Delete @Name = 'Dallas Branch'
EXEC SqlGraph.Company$Delete @Name = 'Houston Branch'
GO

--Now, look at the nodes in the tree:
SELECT HierarchyDisplay
FROM SqlGraph.CompanyHierarchyDisplay
ORDER BY hierarchy;
GO


CREATE OR ALTER FUNCTION SqlGraph.Company$ReturnHierarchy
(
	@CompanyName varchar(20)
) 
RETURNS @Output TABLE (CompanyId INT, Name VARCHAR(20), 
                       Level INT, Hierarchy NVARCHAR(4000), 
                      IdHierarchy NVARCHAR(4000), 
                      hierarchyDisplay NVARCHAR(4000))
AS 
BEGIN
      --get the identifier for the node you want to start with
      DECLARE @CompanyId int, @NodeName nvarchar(max)
      SELECT  @CompanyId = CompanyId,
                  @Nodename = Name
      FROM   SqlGraph.Company
      WHERE  Name = @CompanyName;

      ;WITH baseRows as
       (
      --include node that you are looking for
      SELECT @companyId as CompanyId, @NodeName as Name, 
              1 as Level, 
             '\' + Cast(@companyId as nvarchar(10)) + '\' as 
                       IdHierarchy, --\ delimited but with id num
               '\' + @NodeName AS Hieararchy
      UNION ALL
      SELECT 
               LAST_VALUE(ToCompany.CompanyId) 
                         WITHIN GROUP (GRAPH PATH) AS CompanyId,
               LAST_VALUE(ToCompany.Name) 
                         WITHIN GROUP (GRAPH PATH) AS NodeName,
               1+COUNT(ToCompany.Name) 
                         WITHIN GROUP (GRAPH PATH) AS levels,
               '\' +  CAST(FromCompany.CompanyId as NVARCHAR(10)) +
               '\' + STRING_AGG(cast(ToCompany.CompanyId as 
                                            nvarchar(10)), '\')  
                  WITHIN GROUP (GRAPH PATH) + '\' AS Idhierarchy,

               '\' +  FromCompany.NAME + '\' + 
               STRING_AGG(ToCompany.Name, '\')  
                    WITHIN GROUP (GRAPH PATH) + '\' AS hierarchy

      FROM 
               SqlGraph.Company AS FromCompany,	
               SqlGraph.ReportsTo FOR PATH AS ReportsTo,
               SqlGraph.Company FOR PATH AS ToCompany
      WHERE 
            MATCH(SHORTEST_PATH(FromCompany(-(ReportsTo)
                                                 ->ToCompany)+))
          --start the processing from the parameter's companyId
               AND FromCompany.CompanyId = @companyId
      )
      INSERT INTO @Output
      SELECT *, REPLICATE('--> ',LEVEL - 1) + Name 
                                         AS HierarchyDisplay
      FROM  BaseRows
RETURN;

END;
GO

SELECT *
FROM   SqlGraph.Company$ReturnHierarchy('Tennessee HQ' )
GO


CREATE OR ALTER FUNCTION SqlGraph.Company$CheckForChild
(
      @CompanyName varchar(20),
      @CheckForChildOfCompanyName varchar(20)
) 
RETURNS BIT
AS 
BEGIN
      --get the id value of the company to check for
      DECLARE @CompanyId INT, @ChildFlag BIT = 0;
      SELECT @CompanyId = CompanyId
      FROM   SqlGraph.Company
      WHERE  Name = @CompanyName;

      --get the id of the company to see if it is a child of
      DECLARE @CheckForChildOfCompanyId int;
      SELECT  @CheckForChildOfCompanyId = CompanyId
      FROM   SqlGraph.Company
      WHERE  Name = @CheckForChildOfCompanyName;

      --query the structure
      ;WITH baseRows as
       (
      --gets the relations to @checkForChildOfCompanyId
      SELECT LAST_VALUE(ToCompany.CompanyId) WITHIN GROUP 
                                (GRAPH PATH) AS ChildCompanyId
      FROM 
               SqlGraph.Company AS FromCompany,	
               SqlGraph.ReportsTo FOR PATH AS ReportsTo,
               SqlGraph.Company FOR PATH AS ToCompany
      WHERE 
               MATCH(SHORTEST_PATH(FromCompany(-(ReportsTo)
                                                  ->ToCompany)+))
        AND FromCompany.CompanyId = @CheckForChildOfCompanyId
	)	
      --then filter to see if the passed in row matches
      SELECT @ChildFlag = 1
      FROM  BaseRows
      WHERE childCompanyId = @CompanyId

RETURN @ChildFlag

END;
GO


SELECT HierarchyDisplay
FROM   SqlGraph.Company$ReturnHierarchy('Company HQ' )
ORDER BY Hierarchy;
GO


--We can test out the procedure this way:
SELECT (CASE SqlGraph.Company$CheckForChild('Camden Branch','Company HQ') 
		WHEN 1 THEN 'Yes' ELSE 'No' END) AS Camden_to_Company,
		(CASE SqlGraph.Company$CheckForChild('Camden Branch','Maine HQ') 
		WHEN 1 THEN 'Yes' ELSE 'No' END) AS Camden_to_Maine,
		(CASE SqlGraph.Company$CheckForChild('Camden Branch','Tennessee HQ') 
		WHEN 1 THEN 'Yes' ELSE 'No' END) AS Camden_to_Tennessee
GO




CREATE OR ALTER PROCEDURE SqlGraph.Company$ReportSales
(
	@DisplayFromNodeName VARCHAR(20) 
)
AS
BEGIN

--output the Expanded Hierarchy...
WITH ExpandedHierarchy (ParentCompanyId, ChildCompanyId)
AS (
   --gets all of the nodes of the hierarchy
   SELECT Company.CompanyId AS ParentCompanyId,
          Company.CompanyId AS ChildCompanyId
   FROM SqlGraph.Company

UNION ALL

   --joins back to the CTE to recursively retrieve the rows 
   --note that TreeLevel is incremented on each iteration

   SELECT ExpandedHierarchy.ParentCompanyId,
          ToCompany.CompanyId
   FROM ExpandedHierarchy,
        SqlGraph.Company AS FromCompany,
        SqlGraph.ReportsTo,
        SqlGraph.Company AS ToCompany
   WHERE ExpandedHierarchy.ChildCompanyId = FromCompany.CompanyId
         AND MATCH(FromCompany-(ReportsTo)->ToCompany)
		 
),
--using the hierarchy returning function, get only the nodes
--that you desir
FilterAndSweeten AS 
(
	SELECT ExpandedHierarchy.*, 
             CompanyHierarchyDisplay.Hierarchy,
			CompanyHierarchyDisplay.HierarchyDisplay

	from   ExpandedHierarchy
	JOIN [SqlGraph].[Company$ReturnHierarchy]
             (@DisplayFromNodeName) AS CompanyHierarchyDisplay
		ON CompanyHierarchyDisplay.CompanyId = 
                         ExpandedHierarchy.ParentCompanyId
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
       Aggregations.TotalSalesAmount
FROM Aggregations
ORDER BY Aggregations.hierarchy
END;
GO

EXECUTE SqlGraph.Company$ReportSales 'Company HQ'
GO


--First we have the expanded hierarchy. The first part of this is every node in the tree, related to itself:
--output the Expanded Hierarchy...
WITH ExpandedHierarchy (ParentCompanyId, ChildCompanyId)
AS (
   --gets all of the nodes of the hierarchy
   SELECT Company.CompanyId AS ParentCompanyId,
          Company.CompanyId AS ChildCompanyId
   FROM SqlGraph.Company
  )
SELECT *
FROM  ExpandedHierarchy
ORDER BY ExpandedHierarchy.ParentCompanyId;

/*
This returns:

ParentCompanyId ChildCompanyId
--------------- --------------
1               1
2               2
3               3
4               4
5               5
6               6
7               7
8               8

It is needed because for the MATCH clause to return these rows, there would need to be a cyclic relationship to the same node.

Next, the second half of the expanded hierarchy query uses a recursive relationship, though it only really does one iteration. Every node in the ExpandedHierarchy is expanded in the second half of the query:
*/
WITH ExpandedHierarchy (ParentCompanyId, ChildCompanyId)
AS (
   --gets all of the nodes of the hierarchy
   SELECT Company.CompanyId AS ParentCompanyId,
          Company.CompanyId AS ChildCompanyId
   FROM SqlGraph.Company

   UNION ALL
   
   SELECT ExpandedHierarchy.ParentCompanyId,
          ToCompany.CompanyId
   FROM ExpandedHierarchy,
        SqlGraph.Company AS FromCompany,
        SqlGraph.ReportsTo,
        SqlGraph.Company AS ToCompany
   WHERE ExpandedHierarchy.ChildCompanyId = FromCompany.CompanyId
         AND MATCH(FromCompany-(ReportsTo)->ToCompany)
		 
)
SELECT *
FROM   ExpandedHierarchy
--don't return the rows from the first query
WHERE ExpandedHierarchy.ParentCompanyId <> ExpandedHierarchy.ChildCompanyId
ORDER BY ParentCompanyId;
/*
This returns:
ParentCompanyId ChildCompanyId
--------------- --------------
1               2
1               3
1               4
1               5
1               6
1               7
1               8
2               7
2               8
3               4
3               5
3               6

You can see that 1 relates to every other node, then 2 and 3 (Tennessee and Maine) relate to their child rows. So now every row is related to iteslf and its child rows. The rest of the query is fairly straightforward. The Filter and Sweeten section just joins the Expanded hierarchy and filters only on parent rows that are output from the company name you passed in to Company$ReturnHierarchy. It handles filtering along with adding the data that will be output.
*/
FilterAndSweeten AS 
(
	SELECT ExpandedHierarchy.*, 
             CompanyHierarchyDisplay.Hierarchy,
			CompanyHierarchyDisplay.HierarchyDisplay

	from   ExpandedHierarchy
	JOIN [SqlGraph].[Company$ReturnHierarchy]
             (@DisplayFromNodeName) AS CompanyHierarchyDisplay
		ON CompanyHierarchyDisplay.CompanyId = 
                         ExpandedHierarchy.ParentCompanyId
)
/*
The CompanyTotals CTE just takes the sales data for each indivitual company and sums it.
*/
,--get totals for each Company for the aggregate
     CompanyTotals
AS (SELECT CompanyId,
           SUM(cast(Amount as decimal(20,2))) AS TotalAmount
    FROM SqlGraph.Sale
    GROUP BY CompanyId),
--aggregate each Company for the Company
 /*
 Then you aggegate the data to the ParentCompany values, including the stuff you need for the final display
  */  

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
/*
Finally the data is displayed (in this extra step to just to make the sorting easier.
*/
--display the data...
SELECT Aggregations.ParentCompanyId,
	   Aggregations.hierarchyDisplay,
       Aggregations.TotalSalesAmount
FROM Aggregations
ORDER BY Aggregations.hierarchy
END;
GO
