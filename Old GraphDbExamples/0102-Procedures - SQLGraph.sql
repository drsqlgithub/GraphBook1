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

					INSERT INTO SqlGraph.ReportsTo ($from_id, $to_id) 
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
SELECT CAST($node_id AS VARCHAR(64)) AS [$node_id],
       CompanyId,
       Name 
FROM SqlGraph.Company;

SELECT CAST($edge_id as varchar(64)) as [$edge_id],
       CAST($from_id as varchar(64)) as [$from_id],
       CAST($to_id as varchar(64)) as [$to_id]
FROM   SqlGraph.ReportsTo

/*
$node_id                                                         CompanyId   Name
---------------------------------------------------------------- ----------- --------------------
{"type":"node","schema":"SqlGraph","table":"Company","id":0}     1           Company HQ
{"type":"node","schema":"SqlGraph","table":"Company","id":1}     2           Maine HQ
{"type":"node","schema":"SqlGraph","table":"Company","id":2}     3           Tennessee HQ
{"type":"node","schema":"SqlGraph","table":"Company","id":3}     4           Nashville Branch

$edge_id                                                         $from_id                                                         $to_id
---------------------------------------------------------------- ---------------------------------------------------------------- ----------------------------------------------------------------
{"type":"edge","schema":"SqlGraph","table":"ReportsTo","id":0}   {"type":"node","schema":"SqlGraph","table":"Company","id":0}     {"type":"node","schema":"SqlGraph","table":"Company","id":1}
{"type":"edge","schema":"SqlGraph","table":"ReportsTo","id":1}   {"type":"node","schema":"SqlGraph","table":"Company","id":0}     {"type":"node","schema":"SqlGraph","table":"Company","id":2}
{"type":"edge","schema":"SqlGraph","table":"ReportsTo","id":2}   {"type":"node","schema":"SqlGraph","table":"Company","id":2}     {"type":"node","schema":"SqlGraph","table":"Company","id":3}

*/
 --for most of the book, when I need to show the internals, I will use the following functions that were introduced back in chapter 4.

SELECT  Tools.Graph$NodeIdFormat($node_id) AS [$node_id],
       CompanyId,
       Name 
FROM SqlGraph.Company;

SELECT Tools.Graph$EdgeIdFormat($edge_id) AS [$edge_id],
       Tools.Graph$NodeIdFormat($from_id) AS [$from_id],
       Tools.Graph$NodeIdFormat($to_id) AS [$to_id] 
FROM SqlGraph.ReportsTo;

/*
This returns the same details in a more compact manner, due ot the limited real estate in the book.

$node_id                       CompanyId   Name
------------------------------ ----------- --------------------
SqlGraph.Company id:0          1           Company HQ
SqlGraph.Company id:1          2           Maine HQ
SqlGraph.Company id:2          3           Tennessee HQ
SqlGraph.Company id:3          4           Nashville Branch

$edge_id                       $from_id                       $to_id
------------------------------ ------------------------------ ------------------------------
SqlGraph.ReportsTo id:0      SqlGraph.Company id:0          SqlGraph.Company id:1
SqlGraph.ReportsTo id:1      SqlGraph.Company id:0          SqlGraph.Company id:2
SqlGraph.ReportsTo id:2      SqlGraph.Company id:2          SqlGraph.Company id:3
*/

--You will see that you have 4 nodes and 3 edges. CompanyHQ's internal id value is 0 (assuming you don't have any errors, which I have had many times and regenerated so I can get the ideal output.

--Now I am going to add my first root node. To make the whole example clearer for doing the math, I only put sale data on root nodes. This is also a very reasonable expectation to have in the real world for many situations. It does not really affect the outcome if sale data was appended to the non-root nodes either, but it would be very typcical for the stores or salespersons to have sales, but the region to only have sales based on the stores or salespersons.
EXEC SqlGraph.Sale$InsertTestData @Name = 'Nashville Branch';

--You can see the sale data inserted here:

SELECT *
FROM   SqlGraph.Sale;

/*
This returns:

SalesId     TransactionNumber Amount                                  CompanyId
----------- ----------------- --------------------------------------- -----------
1           1                 0.25                                    4
2           2                 0.50                                    4
3           3                 0.75                                    4
4           4                 1.00                                    4
5           5                 1.25                                    4
*/

--The goal being, in every example, Nashville Branch will have the same $3.75 worth of sales. (obviously not a very real amount of money, but keeping values and rowcounts the same is essential for a performance and correctness test. The fact that values match in examples has saved me many times with these algorithms. I use this set of data as my unit test for all of these algorthms. Using this query, you can see the values in the table:

SELECT Name, SUM(amount)
FROM   SqlGraph.Sale
		JOIN SqlGraph.Company
			ON Company.CompanyId = Sale.CompanyId
GROUP BY Name;

/*
Name                 
-------------------- ---------------------------------------
Nashville Branch     3.75

Now insert the rest of the data for the graph.
*/


EXEC SqlGraph.Company$Insert @Name = 'Knoxville Branch', @ParentCompanyName = 'Tennessee HQ';

EXEC SqlGraph.Sale$InsertTestData @Name = 'Knoxville Branch';

EXEC SqlGraph.Company$Insert @Name = 'Memphis Branch', @ParentCompanyName = 'Tennessee HQ';

EXEC SqlGraph.Sale$InsertTestData @Name = 'Memphis Branch';

EXEC SqlGraph.Company$Insert @Name = 'Portland Branch', @ParentCompanyName = 'Maine HQ';

EXEC SqlGraph.Sale$InsertTestData @Name = 'Portland Branch';

EXEC SqlGraph.Company$Insert @Name = 'Camden Branch', @ParentCompanyName = 'Maine HQ';

EXEC SqlGraph.Sale$InsertTestData @Name = 'Camden Branch';
GO

--Now let's look at the data, in a very human readable form. One of the interesting thing about SQLGraph queries is that there is no easy way to do an OUTER style connection in the data. So if you want to list all the data in the tree, you will need to do a litle bit mor than just the MATCH query to get the root node in the output. The root node(s) in the table will turn out to be the ones where the $node_id doesn't appear as a $to_id in an edge. (It is something you will also need to do in any graph, but it is very much a part of the process when building a tree.

--The following query will give us the nodes in the tree including the root:

--get the root
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

--This returns:
/*
CompanyId   Name                 ParentCompanyId
----------- -------------------- ---------------
1           Company HQ           NULL
2           Maine HQ             1
3           Tennessee HQ         1
4           Nashville Branch     3
5           Knoxville Branch     3
6           Memphis Branch       3
7           Portland Branch      2
8           Camden Branch        2

--In the downloads, I will compile this to a vew named: SqlGraph.CompanyClean
*/

CREATE OR ALTER VIEW SqlGraph.CompanyClean
AS
--get the root
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
WHERE MATCH(Company<-(ReportsTo)-ParentCompany)

/*
Before we move forward, there are a few operations that I need to demonstrate how we look at the data in a semi graphical manner. In the following query, I 
*/
SELECT 0 AS Level, Company.Name AS Hierarchy, Company.Name
FROM  SqlGraph.Company
WHERE  $node_id NOT IN (SELECT  $to_id
						FROM    SqlGraph.ReportsTo)
UNION ALL
SELECT	COUNT(ReportsToCompany.CompanyId) WITHIN GROUP (GRAPH PATH) ,
		Company.NAME + '->' + STRING_AGG(ReportsToCompany.name, '->') WITHIN GROUP (GRAPH PATH) AS Friends
		,LAST_VALUE(ReportsToCompany.name) WITHIN GROUP (GRAPH PATH) AS LastNode
FROM    SqlGraph.Company AS Company, 
		SqlGraph.ReportsTo FOR PATH AS ReportsTo,
		SqlGraph.Company FOR PATH AS ReportsToCompany
WHERE MATCH(SHORTEST_PATH(Company(-(ReportsTo)->ReportsToCompany)+))
  AND Company.Name = 'Company HQ';

/*
The output of this query gives the following:

Level       Hierarchy                                       Name
----------- ----------------------------------------------- --------------------
0           Company HQ                                      Company HQ
1           Company HQ->Maine HQ                            Maine HQ
1           Company HQ->Tennessee HQ                        Tennessee HQ
2           Company HQ->Tennessee HQ->Nashville Branch      Nashville Branch
2           Company HQ->Tennessee HQ->Knoxville Branch      Knoxville Branch
2           Company HQ->Tennessee HQ->Memphis Branch        Memphis Branch
2           Company HQ->Maine HQ->Portland Branch           Portland Branch
2           Company HQ->Maine HQ->Camden Branch             Camden Branch

Using this output, I will make that a CTE and then use the level column to indent each item, and the Hierarchy column to sort by:

*/

WITH BaseRows AS
(
SELECT 0 AS Level, Company.Name AS Hierarchy, Company.Name
FROM  SqlGraph.Company
WHERE  $node_id NOT IN (SELECT  $to_id
						FROM    SqlGraph.ReportsTo)
UNION ALL
SELECT	COUNT(ReportsToCompany.CompanyId) WITHIN GROUP (GRAPH PATH) ,
		Company.NAME + '->' + STRING_AGG(ReportsToCompany.name, '->') WITHIN GROUP (GRAPH PATH) AS Friends
		,LAST_VALUE(ReportsToCompany.name) WITHIN GROUP (GRAPH PATH) AS LastNode
FROM    SqlGraph.Company AS Company, 
		SqlGraph.ReportsTo FOR PATH AS ReportsTo,
		SqlGraph.Company FOR PATH AS ReportsToCompany
WHERE MATCH(SHORTEST_PATH(Company(-(ReportsTo)->ReportsToCompany)+))
  AND Company.Name = 'Company HQ'
)
SELECT REPLICATE('--> ',Level) + Name AS HierarchyDisplay
FROM   BaseRows
ORDER BY Hierarchy

/*
This returns the following output:

HierarchyDisplay
---------------------------------------
Company HQ
--> Maine HQ
--> --> Camden Branch
--> --> Portland Branch
--> Tennessee HQ
--> --> Knoxville Branch
--> --> Memphis Branch
--> --> Nashville Branch

In the downloads, I will make this into a view named:

SqlGraph.CompanyHierarchyDisplay, which I will use to output the examples in the rest of the chapter. In it I will include the Level and Name of the Last Node just to give a bit more information.
*/

CREATE OR ALTER VIEW SqlGraph.CompanyHierarchyDisplay
AS 
WITH BaseRows AS
(
SELECT 0 AS Level, Company.Name AS Hierarchy, Company.Name
FROM  SqlGraph.Company
WHERE  $node_id NOT IN (SELECT  $to_id
						FROM    SqlGraph.ReportsTo)
UNION ALL
SELECT	COUNT(ReportsToCompany.CompanyId) WITHIN GROUP (GRAPH PATH) ,
		Company.NAME + '->' + STRING_AGG(ReportsToCompany.name, '->') WITHIN GROUP (GRAPH PATH) AS Friends
		,LAST_VALUE(ReportsToCompany.name) WITHIN GROUP (GRAPH PATH) AS LastNode
FROM    SqlGraph.Company AS Company, 
		SqlGraph.ReportsTo FOR PATH AS ReportsTo,
		SqlGraph.Company FOR PATH AS ReportsToCompany
WHERE MATCH(SHORTEST_PATH(Company(-(ReportsTo)->ReportsToCompany)+))
  AND Company.Name = 'Company HQ'
)
SELECT REPLICATE('--> ',Level) + Name AS HierarchyDisplay, Level,  Name, Hierarchy
FROM   BaseRows;
GO
/*
Reparenting Nodes

A common operation you might need to do a tree is to move one node to be a child of a different node. Reparenting a node in a tree using an adjaency list sort of structure (storing the edges in a simple from-to object like SQL Graph does) is generally simple. Just modify the $from_id value from one parent to another. In SQL Graph edges, you cannot modify the edge's $from_id or $to_id values, so you need to delete the original edge and create a new one. If you have data stored in the edge object, you will need to handle that in your code.

For multi-step processes in T-SQL code, it is always good to use a stored procedure object, which makes it a lot easier to use a transaction in a safe manner.  In the next bit of code, I will implement the reparent code for our Company object. Reparenting can be thought of as an edge update operation, but I generally would implement seperately from a general update procedure because you would typically want to update something like the notes about the connection of two nodes indepently from moving them to a different location in the tree. Hence the security n the reparently operation is likely to be a lot different than the normal update.
*/
CREATE OR ALTER PROCEDURE SqlGraph.Company$Reparent
(
    @Name                 varchar(20), --again using natural key values
    @NewParentCompanyName varchar(20)
)
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY;
	BEGIN TRANSACTION;

	--get the new location you wish to change to
	DECLARE @FromId nvarchar(1000), --the from is what is changing
			@ToId nvarchar(1000) -- the to will be the same
	
	--use the natural key values to fetch the $from_id and $to_id
	SELECT @FromId = $node_id
	FROM   SqlGraph.Company
	WHERE  name = @NewParentCompanyName;

	SELECT @ToId = $node_id
	FROM   SqlGraph.Company
	WHERE  name = @Name;
	
	--Delete the old edge, and since this isn't changin
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

--Now, let's look at the tree structure as is:

SELECT HierarchyDisplay
FROM   SqlGraph.CompanyHierarchyDisplay
ORDER BY Hierarchy;
/*
This returns:

HierarchyDisplay
-------------------------------
Company HQ
--> Maine HQ
--> --> Camden Branch
--> --> Portland Branch
--> Tennessee HQ
--> --> Knoxville Branch
--> --> Memphis Branch
--> --> Nashville Branch
*/

--Now let's reparent 'Maine HQ' to be under 'Tennessee HQ'
EXEC SqlGraph.Company$Reparent @Name = 'Maine HQ', @NewParentCompanyName = 'Tennessee HQ';
GO

--After execution, looking at the code, you can now see that 'Maine HQ' is a child of 'Tennessee HQ'.

SELECT HierarchyDisplay
FROM   SqlGraph.CompanyHierarchyDisplay
ORDER BY Hierarchy

/*
HierarchyDisplay
----------------------------------------
Company HQ
--> Tennessee HQ
--> --> Knoxville Branch
--> --> Maine HQ
--> --> --> Camden Branch
--> --> --> Portland Branch
--> --> Memphis Branch
--> --> Nashville Branch

Note also that all of the child rows of Maine HQ come along for the ride. I won't implement it here, but you could "somewhat less easily" just remove the node from the tree and insert it into the structure. Now put 'Maine HQ' back where it belongs using the following code.
*/
EXEC SQLGraph.Company$Reparent @Name = 'Maine HQ', @NewParentCompanyName = 'Company HQ'
GO
/*
Then check for yourself that it is back into the right location.

Next up, I will implement deletes. Deletes are somewhat more interesting than reparenting, because if you delete a row that has child rows in the structure, what do you do? Do you just try to delete that node? Or delete the child rows? Would it be better 
*/


CREATE OR ALTER PROCEDURE SqlGraph.Company$Delete
    @Name                varchar(20),
    @DeleteChildNodesFlag bit = 0,
	@ReparentChildNodesToParentFlag BIT = 0
AS

BEGIN
	SET NOCOUNT ON;
	BEGIN TRY;

	IF @DeleteChildNodesFlag = 1 AND @ReparentChildNodesToParentFlag = 1
		THROW 50000,'Both @DeleteChildNodesFlag and @ReparentChildNodesToParentFlag cannot be set to 1', 1;


    IF @DeleteChildNodesFlag = 1
    BEGIN

		--use this to get all the children of node to be deleted
		--we need not only the direct decendents (which we will use for reparenting the 
		--child rows), but their decendents too so we can delete everything.
		SELECT  LAST_VALUE(ReportsTo.$to_id) WITHIN GROUP (GRAPH PATH) AS  CompanyNodeId
		INTO	#deleteThese
		FROM    SqlGraph.Company AS Company, 
				SqlGraph.ReportsTo FOR PATH AS ReportsTo,
				SqlGraph.Company FOR PATH AS ReportsToCompany
		WHERE MATCH(SHORTEST_PATH(Company(-(ReportsTo)->ReportsToCompany)+))
		  AND Company.Name = 'Georgia HQ'; --@name

		--this is the node that was originally requested to be deleted
		INSERT INTO #deleteThese
		SELECT $node_id FROM SqlGraph.Company WHERE name = @Name;

		--Now remove all traces of the parent and children 
		--as a from or a to in a relationship, then remove the 
		--company rows.
		BEGIN TRANSACTION;

		DELETE SqlGraph.ReportsTo
        WHERE  $from_id IN (SELECT CompanyNodeId FROM #deleteThese);
		  
		DELETE SqlGraph.ReportsTo
        WHERE  $to_id IN (SELECT CompanyNodeId FROM #deleteThese);

		DELETE SqlGraph.Company
        WHERE  $Node_id IN (SELECT CompanyNodeId FROM #deleteThese);

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
		DECLARE @NewFromId NVARCHAR(1000) = (SELECT $from_id
											FROM   SqlGraph.ReportsTo
											WHERE  $to_id= (SELECT $node_Id
															FROM  SqlGraph.Company
															WHERE  Name = @Name));

		--delete the reporting rows for the rows to be reparented
		DELETE FROM SqlGraph.ReportsTo
		WHERE  $to_id IN (SELECT ToId FROM #reparentThese)

		--delete reporiting rows for the row to be deleted
		DELETE FROM SqlGraph.ReportsTo
		WHERE  $to_id IN (SELECT $node_Id
							FROM  SqlGraph.Company
							WHERE  Name = @Name)

		--if the parent is not null, create new rows
		IF @NewFromId IS NOT NULL
           INSERT INTO SqlGraph.ReportsTo
           (
               $from_id,
               $to_id
           )
			SELECT @NewFromId, ToId
			FROM   #reparentThese
		ELSE
			THROW 50000,'The parent row did not exist, operation fails',1;

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

--To test this, I will create the following data (include graph)

--add a few rows to test the delete. No activity rows because that would limit deletes
EXEC SqlGraph.Company$Insert @Name = 'Georgia HQ', @ParentCompanyName = 'Company HQ';
EXEC SqlGraph.Company$Insert @Name = 'Atlanta Branch', @ParentCompanyName = 'Georgia HQ';
EXEC SqlGraph.Company$Insert @Name = 'Dalton Branch', @ParentCompanyName = 'Georgia HQ';
EXEC SqlGraph.Company$Insert @Name = 'Texas HQ', @ParentCompanyName = 'Company HQ';
EXEC SqlGraph.Company$Insert @Name = 'Dallas Branch', @ParentCompanyName = 'Texas HQ';
EXEC SqlGraph.Company$Insert @Name = 'Houston Branch', @ParentCompanyName = 'Texas HQ';
GO


SELECT HierarchyDisplay
FROM   SqlGraph.CompanyHierarchyDisplay
ORDER BY Hierarchy


/*
The Hierarchy now looks like this:

HierarchyDisplay
-----------------------------------------
Company HQ
--> Georgia HQ
--> --> Atlanta Branch
--> --> Dalton Branch
--> Maine HQ
--> --> Camden Branch
--> --> Portland Branch
--> Tennessee HQ
--> --> Knoxville Branch
--> --> Memphis Branch
--> --> Nashville Branch
--> Texas HQ
--> --> Dallas Branch
--> --> Houston Branch
*/



--try to delete Georgia, using only the default parameters (leaving children rows alone)
EXEC SqlGraph.Company$Delete @Name = 'Georgia HQ';
GO

/* 
Because we created the edge constraint as NO ACTION, this fails:

Msg 547, Level 16, State 0, Procedure SqlGraph.Company$Delete, Line 60 [Batch Start Line 502]
The DELETE statement conflicted with the EDGE REFERENCE constraint "EC_ReportsTo$DefinesParentOf". The conflict occurred in database "GraphDBTests", table "SqlGraph.ReportsTo".

If I try to delete a leaf node, it works
*/
--delete Atlanta
EXEC SqlGraph.Company$Delete @Name = 'Atlanta Branch';
GO 

--Check the structure and you will see the 'Atlanta Branch' row is gone. Next, try the deleting ChildRows:

EXEC SqlGraph.Company$Delete @Name = 'Georgia HQ', @DeleteChildNodesFlag = 1;
GO

SELECT HierarchyDisplay
FROM   SqlGraph.CompanyHierarchyDisplay
ORDER BY Hierarchy

/*
Now you will see that the 'Georgia HQ' and 'Atlanta HQ' rows are gone.

HierarchyDisplay
---------------------------------------
Company HQ
--> Maine HQ
--> --> Camden Branch
--> --> Portland Branch
--> Tennessee HQ
--> --> Knoxville Branch
--> --> Memphis Branch
--> --> Nashville Branch
--> Texas HQ
--> --> Dallas Branch
--> --> Houston Branch

Next lets see what the @ReparentChildNodesToParentFlag does. Excuting the following code removes the 'Texas HQ' row, but now the Dallas and Houston Branch nodes will be moved up as child nodes of the 'Company HQ' node.
*/
EXEC SqlGraph.Company$Delete @Name = 'Texas HQ', @ReparentChildNodesToParentFlag = 1;


HierarchyDisplay
---------------------------------------------
Company HQ
--> Dallas Branch
--> Houston Branch
--> Maine HQ
--> --> Camden Branch
--> --> Portland Branch
--> Tennessee HQ
--> --> Knoxville Branch
--> --> Memphis Branch
--> --> Nashville Branch

--Finally, clean up the nodes that are left over from this example:

EXEC SqlGraph.Company$Delete @Name = 'Dallas Branch'
EXEC SqlGraph.Company$Delete @Name = 'Houston Branch'
GO
/*
The next two statments object I will create will be to create two fairly normal procedures that replicate typical operations you might do with a tree. First, I will create a function that will let you ask "giving one company, see if it is a child of the other in the hierarchy. Basically you just take the hierarchy query, starting at one node, then filter the output. Here is that code.
*/

CREATE OR ALTER FUNCTION SqlGraph.Company$CheckForChild
(
	@CompanyName varchar(20),
	@CheckForChildOfCompanyName varchar(20)
) 
RETURNS BIT
AS 
BEGIN

	DECLARE @CompanyId INT, @ChildFlag BIT = 0;
	SELECT  @CompanyId = CompanyId
	FROM   SqlGraph.Company
	WHERE  Name = @CompanyName;

	DECLARE @CheckForChildOfCompanyId int
	SELECT  @CheckForChildOfCompanyId = CompanyId
	FROM   SqlGraph.Company
	WHERE  Name = @CheckForChildOfCompanyName;

	;WITH baseRows as
	(
	SELECT LAST_VALUE(ToCompany.CompanyId) WITHIN GROUP (GRAPH PATH) AS ChildCompanyId
	FROM 
		   SqlGraph.Company AS FromCompany,	
		   SqlGraph.ReportsTo FOR PATH AS ReportsTo,
		   SqlGraph.Company FOR PATH AS ToCompany
	WHERE 
		   MATCH(SHORTEST_PATH(FromCompany(-(ReportsTo)->ToCompany)+))
		   AND FromCompany.CompanyId = @CheckForChildOfCompanyId
	)	
	SELECT @ChildFlag = 1
	FROM  BaseRows
	WHERE childCompanyId = @CompanyId

RETURN @ChildFlag

END;
GO













