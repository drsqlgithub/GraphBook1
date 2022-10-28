USE ImagesDirectory
GO
WITH BaseRows AS (
SELECT LAST_VALUE(FollowedItem.ItemName) WITHIN GROUP (GRAPH PATH)
                                                AS ConnectedItem,
	   STRING_AGG(FollowedItem.ItemName, '->') WITHIN GROUP 
                                            (GRAPH PATH) AS Path
FROM   Locations.Item AS Item,
       Locations.Includes FOR PATH AS Includes,
       Locations.Item FOR PATH AS FollowedItem
WHERE  Item.ItemName = 'Fun Kingdom'
    AND MATCH(SHORTEST_PATH(Item(-(Includes)->FollowedItem)+))
)
SELECT *
FROM BaseRows
WHERE connectedItem = 'Funville Trolley Station'
GO


USE ImagesDirectory
GO
WITH BaseRows AS (
SELECT LAST_VALUE(FollowedItem.ItemName) WITHIN GROUP (GRAPH PATH)
                                                AS ConnectedItem,
	   STRING_AGG(FollowedItem.ItemName, '->') WITHIN GROUP 
                                            (GRAPH PATH) AS PATH
FROM   Locations.Item AS Item,
       Locations.Includes FOR PATH AS Includes,
       Locations.Item FOR PATH AS FollowedItem
WHERE  Item.ItemName = 'Happy Fun Resort'
    AND MATCH(SHORTEST_PATH(Item(-(Includes)->FollowedItem)+))
)
SELECT *
FROM BaseRows
WHERE connectedItem = 'Happy Fun Resort Trolley'
GO

DECLARE @IncludeTypeId INT = (SELECT IncludeTypeId FROM Locations.IncludeType WHERE IncludeType = 'Contains');

--only include containership
WITH BaseRows AS (
SELECT LAST_VALUE(FollowedItem.ItemName) WITHIN GROUP (GRAPH PATH)
                                                AS ConnectedItem,
	   STRING_AGG(FollowedItem.ItemName, '->') WITHIN GROUP 
                                            (GRAPH PATH) AS PATH
FROM   Locations.Item AS Item,
       (SELECT * FROM Locations.Includes WHERE IncludeTypeId = @IncludeTypeId) FOR PATH AS Includes,
       Locations.Item FOR PATH AS FollowedItem
WHERE  Item.ItemName = 'Fun Kingdom'
    AND MATCH(SHORTEST_PATH(Item(-(Includes)->FollowedItem)+))
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
           Item.$node_id  AS IncludesItemNodeId,
           Item.ItemName, 
		   --the path that contains the readable path we have built in all examples
           CAST(Item.ItemName AS NVARCHAR(4000)) AS Path, 
           0 AS level --the level
    FROM Locations.Item
    WHERE Item.ItemName = 'Happy Fun Resort'
    UNION ALL
	--pretty typical 1 level graph query:
    SELECT Item.$node_id AS ItemId,
           FollowedItem.$node_id AS IncludesItemId,
           FollowedItem.ItemName,
           BaseRows.Path + '> (' + IncludeType + ') ' + FollowedItem.ItemName,
           BaseRows.level + 1
    FROM Locations.Item,
         Locations.Includes,
         Locations.Item AS FollowedItem,
         BaseRows,
		 Locations.IncludeType
    WHERE MATCH(Item-(Includes)->FollowedItem)
				--this joins the anchor to the recursive part of the query
                AND BaseRows.IncludesItemNodeId = Item.$node_id
				AND Includes.IncludeTypeId = IncludeType.IncludeTypeId
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
           Item.$node_id  AS IncludesItemNodeId,
           Item.ItemName, 
		   --the path that contains the readable path we have built in all examples
           CAST(Item.ItemName AS NVARCHAR(4000)) AS Path, 
           0 AS level --the level
    FROM Locations.Item
    WHERE Item.ItemName = 'Happy Fun Resort'
    UNION ALL
	--pretty typical 1 level graph query:
    SELECT Item.$node_id AS ItemId,
           FollowedItem.$node_id AS IncludesItemId,
           FollowedItem.ItemName,
           BaseRows.Path + '> (' + IncludeType + ') ' + FollowedItem.ItemName,
           BaseRows.level + 1
    FROM Locations.Item,
         Locations.Includes,
         Locations.Item AS FollowedItem,
         BaseRows,
		 Locations.IncludeType
    WHERE MATCH(Item-(Includes)->FollowedItem)
				--this joins the anchor to the recursive part of the query
                AND BaseRows.IncludesItemNodeId = Item.$node_id
				AND Includes.IncludeTypeId = IncludeType.IncludeTypeId
                AND BaseRows.level <= @MaxLevel
				AND IncludeType.IncludeType IN ('Contains')
				)
SELECT BaseRows.Path, itemName
FROM BaseRows
WHERE BaseRows.ItemName = 'Happy Fun Resort Trolley'
GO