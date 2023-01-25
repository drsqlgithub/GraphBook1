USE ImagesDirectory
GO
--In my first query, let's look at the subgraph that you can see in figure 7-4. We can see the following items that are connected to the Fun Kingdom node. 
WITH BaseRows AS (
SELECT LAST_VALUE(FollowedItem.ItemName) WITHIN GROUP (GRAPH PATH)
                                                AS ConnectedItem,
	   STRING_AGG(FollowedItem.ItemName, '->') WITHIN GROUP 
                                            (GRAPH PATH) AS Path
FROM   Locations.Item AS Item,
       Locations.RelatedTo FOR PATH AS RelatedTo,
       Locations.Item FOR PATH AS FollowedItem
WHERE  Item.ItemName = 'Fun Kingdom'
    AND MATCH(SHORTEST_PATH(Item(-(RelatedTo)->FollowedItem)+))
)
SELECT *
FROM BaseRows
GO

--This query returns the following. You can see that the the Fun Kingdom is connected to 5 nodes, including the Happy Fun Resort Trolley. We will get to the filtering part soon. 

ConnectedItem              Path
-------------------------- --------------------------------------------------------------
Funville                   Funville
Fun Homeland               Fun Homeland
Fun Vittles                Fun Vittles
Funville Trolley Station   Funville->Funville Trolley Station
Happy Fun Resort Trolley   Funville->Funville Trolley Station->Happy Fun Resort Trolley

--This is simple. But lets take a look at the structure this time, but starting at the root node. Note that we are including both contains and related to items at this point. When working with something like geography there may or may not be a physical overlap. In my model items can be related to other items if they aren't fully contained. In a real geography model there can be overlaps geographically. For example, in some states in the US, you can be in a county and a city at the same time. 
--However, geographies should be a DAG becuse while you can be in a city and county at the same time, it is not a reciprocal relationship. The county can't be in you, and you in the county. This is why I designed the trolley to be a related item. In my fully fleshed out model (which gets decidedly too complex to do in a chapter), 

USE ImagesDirectory
GO
WITH BaseRows AS (
SELECT LAST_VALUE(FollowedItem.ItemName) WITHIN GROUP (GRAPH PATH)
                                                AS ConnectedItem,
	   STRING_AGG(FollowedItem.ItemName, '->') WITHIN GROUP 
                                            (GRAPH PATH) AS PATH
FROM   Locations.Item AS Item,
       Locations.RelatedTo FOR PATH AS RelatedTo,
       Locations.Item FOR PATH AS FollowedItem
WHERE  Item.ItemName = 'Happy Fun Resort'
    AND MATCH(SHORTEST_PATH(Item(-(RelatedTo)->FollowedItem)+))
)
SELECT *
FROM BaseRows
WHERE connectedItem = 'Happy Fun Resort Trolley'
GO
/*
The only item you will see is this:

ConnectedItem                 PATH
----------------------------- ---------------------------------------
Happy Fun Resort Trolley      Happy Fun Resort Trolley
*/

DECLARE @RelationshipTypeId INT = (SELECT RelationshipTypeId FROM Locations.RelationshipType WHERE RelationshipType = 'Contains');

--only include containership
WITH BaseRows AS (
SELECT LAST_VALUE(FollowedItem.ItemName) WITHIN GROUP (GRAPH PATH)
                                                AS ConnectedItem,
	   STRING_AGG(FollowedItem.ItemName, '->') WITHIN GROUP 
                                            (GRAPH PATH) AS PATH
FROM   Locations.Item AS Item,
       (SELECT * FROM Locations.RelatedTo WHERE RelationshipTypeId = @RelationshipTypeId) FOR PATH AS RelatedTo,
       Locations.Item FOR PATH AS FollowedItem
WHERE  Item.ItemName = 'Fun Kingdom'
    AND MATCH(SHORTEST_PATH(Item(-(RelatedTo)->FollowedItem)+))
)
SELECT *
FROM BaseRows
--WHERE connectedItem = 'Happy Fun Resort Trolley'
GO






--for larger graphs, this may be needt to stop excessive recursion
DECLARE @MaxLevel INT =10;

WITH BaseRows
AS (
	--the CTE anchor is just the starting node
	SELECT Item.$node_id AS ItemNodeId,
           Item.$node_id  AS RelatedToItemNodeId,
           Item.ItemName, 
		   --the path that contains the readable path we have built in all examples
           CAST(Item.ItemName AS NVARCHAR(4000)) AS Path, 
           0 AS level --the level
    FROM Locations.Item
    WHERE Item.ItemName = 'Happy Fun Resort'
    UNION ALL
	--pretty typical 1 level graph query:
    SELECT Item.$node_id AS ItemId,
           FollowedItem.$node_id AS RelatedToItemId,
           FollowedItem.ItemName,
           BaseRows.Path + '> (' + RelationshipType + ') ' + FollowedItem.ItemName,
           BaseRows.level + 1
    FROM Locations.Item,
         Locations.RelatedTo,
         Locations.Item AS FollowedItem,
         BaseRows,
		 Locations.RelationshipType
    WHERE MATCH(Item-(RelatedTo)->FollowedItem)
				--this joins the anchor to the recursive part of the query
                AND BaseRows.RelatedToItemNodeId = Item.$node_id
				AND RelatedTo.RelationshipTypeId = RelationshipType.RelationshipTypeId
                AND BaseRows.level <= @MaxLevel
				)
SELECT BaseRows.Path, itemName
FROM BaseRows
WHERE BaseRows.ItemName = 'Happy Fun Resort Trolley'
GO


--for larger graphs, this may be needt to stop excessive recursion
DECLARE @MaxLevel INT =10;

WITH BaseRows
AS (
	--the CTE anchor is just the starting node
	SELECT Item.$node_id AS ItemNodeId,
           Item.$node_id  AS RelatedToItemNodeId,
           Item.ItemName, 
		   --the path that contains the readable path we have built in all examples
           CAST(Item.ItemName AS NVARCHAR(4000)) AS Path, 
           0 AS level --the level
    FROM Locations.Item
    WHERE Item.ItemName = 'Happy Fun Resort'
    UNION ALL
	--pretty typical 1 level graph query:
    SELECT Item.$node_id AS ItemId,
           FollowedItem.$node_id AS RelatedToItemId,
           FollowedItem.ItemName,
           BaseRows.Path + '> (' + RelationshipType + ') ' + FollowedItem.ItemName,
           BaseRows.level + 1
    FROM Locations.Item,
         Locations.RelatedTo,
         Locations.Item AS FollowedItem,
         BaseRows,
		 Locations.RelationshipType
    WHERE MATCH(Item-(RelatedTo)->FollowedItem)
				--this joins the anchor to the recursive part of the query
                AND BaseRows.RelatedToItemNodeId = Item.$node_id
				AND RelatedTo.RelationshipTypeId = RelationshipType.RelationshipTypeId
                AND BaseRows.level <= @MaxLevel
				AND RelationshipType.RelationshipType IN ('Contains')
				)
SELECT BaseRows.Path, itemName
FROM BaseRows
WHERE BaseRows.ItemName = 'Happy Fun Resort Trolley'
GO