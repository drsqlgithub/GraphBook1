----------------------------------------------------------------------------------------------------------
--*****
--use to capture timing
--*****
----------------------------------------------------------------------------------------------------------
USE SocialGraph;
GO

----------------------------------------------------------------------------------------------------------
--*****
--Simple find all decendents using Follows
--*****
----------------------------------------------------------------------------------------------------------



SELECT Account1.AccountHandle + '->' + 
       STRING_AGG(Account2.AccountHandle, '->') WITHIN GROUP (GRAPH PATH) AS ConnectedPath, 
       LAST_VALUE(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS ConnectedToAccountHandle,
	   COUNT(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS LEVEL
FROM   SocialGraph.Account AS Account1
                   ,SocialGraph.Account FOR PATH AS Account2
                   ,SocialGraph.Follows FOR PATH AS Follows
WHERE  MATCH(SHORTEST_PATH(Account1(-(Follows)->Account2)+))
  AND  Account1.AccountHandle = '@Tom_Sutton'
ORDER BY ConnectedPath;




----------------------------------------------------------------------------------------------------------
--*****
--Finding a specific decendent by saving off ALL decendents, then filtering in temp table
--*****
----------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS #Hold

--Works really fast
SELECT Account1.AccountHandle + '->' + 
       STRING_AGG(Account2.AccountHandle, '->') WITHIN GROUP (GRAPH PATH) AS ConnectedPath, 
       LAST_VALUE(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS ConnectedToAccountHandle,
	   COUNT(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS LEVEL
INTO #hold
FROM   SocialGraph.Account AS Account1
                   ,SocialGraph.Account FOR PATH AS Account2
                   ,SocialGraph.Follows FOR PATH AS Follows
WHERE  MATCH(SHORTEST_PATH(Account1(-(Follows)->Account2)+))
  AND  Account1.AccountHandle = '@Tom_Sutton'
ORDER BY ConnectedPath;

SELECT *
FROM   #hold
WHERE  ConnectedToAccountHandle = '@Regina_Ochoa';

GO

----------------------------------------------------------------------------------------------------------
--*****
--Finding a specific decendent by saving off ALL decendents, filtering rows using a CTE
--*****
----------------------------------------------------------------------------------------------------------

WITH BaseRows AS (
SELECT Account1.AccountHandle + '->' + 
       STRING_AGG(Account2.AccountHandle, '->') WITHIN GROUP (GRAPH PATH) AS ConnectedPath, 
       LAST_VALUE(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS ConnectedToAccountHandle,
	   COUNT(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS LEVEL
FROM   SocialGraph.Account AS Account1
                   ,SocialGraph.Account FOR PATH AS Account2
                   ,SocialGraph.Follows FOR PATH AS Follows
WHERE  MATCH(SHORTEST_PATH(Account1(-(Follows)->Account2)+))
  AND  Account1.AccountHandle = '@Tom_Sutton'
)
SELECT *
FROM   BaseRows
WHERE  ConnectedToAccountHandle = '@Regina_Ochoa'
OPTION (MAXDOP 1);





----------------------------------------------------------------------------------------------------------
--*****
--Finding all people that a user follows at any level, where they share a interest.
--*****
----------------------------------------------------------------------------------------------------------


----any level connection and shared specific interest
SELECT Account1.AccountHandle + '->' + 
       STRING_AGG(Account2.AccountHandle, '->') WITHIN GROUP (GRAPH PATH) AS ConnectedPath, 
       LAST_VALUE(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS ConnectedToAccountHandle,
	   COUNT(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS LEVEL,
	   Interest.InterestName
FROM   SocialGraph.Account AS Account1
                   ,SocialGraph.Account FOR PATH AS Account2
                   ,SocialGraph.Follows FOR PATH AS Follows
				   ,SocialGraph.InterestedIn
				   ,SocialGraph.Interest
WHERE  MATCH(SHORTEST_PATH(Account1(-(Follows)->Account2)+) AND LAST_NODE(Account2)-(InterestedIn)->Interest)
  AND  Account1.AccountHandle = '@Tom_Sutton'
ORDER BY ConnectedPath
OPTION (MAXDOP 1);


----------------------------------------------------------------------------------------------------------
--*****
--Finding all people that a user follows at any level, where they share a specific interest. Filtered by
--temp table.
--*****
----------------------------------------------------------------------------------------------------------


--any level connection and shared specific interest
DROP TABLE IF EXISTS #BaseRows
SELECT Account1.AccountHandle + '->' + 
       STRING_AGG(Account2.AccountHandle, '->') WITHIN GROUP (GRAPH PATH) AS ConnectedPath, 
       LAST_VALUE(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS ConnectedToAccountHandle,
	   COUNT(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS LEVEL,
	   Interest.InterestName AS InterestName
INTO #BaseRows
FROM   SocialGraph.Account AS Account1
                   ,SocialGraph.Account FOR PATH AS Account2
                   ,SocialGraph.Follows FOR PATH AS Follows
				   ,SocialGraph.InterestedIn
				   ,SocialGraph.Interest
WHERE  MATCH(SHORTEST_PATH(Account1(-(Follows)->Account2)+) AND LAST_NODE(Account2)-(InterestedIn)->Interest)
  AND  Account1.AccountHandle = '@Tom_Sutton'

SELECT *
FROM   #BaseRows
WHERE  InterestName = 'Aqua-lung' --my friend
ORDER BY ConnectedPath
OPTION (MAXDOP 1);

----------------------------------------------------------------------------------------------------------
--*****
--Finding all people that a user follows at any level, where they share a specific interest. Filtered by
--WHERE clause.
--*****
----------------------------------------------------------------------------------------------------------

SELECT Account1.AccountHandle + '->' + 
       STRING_AGG(Account2.AccountHandle, '->') WITHIN GROUP (GRAPH PATH) AS ConnectedPath, 
       LAST_VALUE(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS ConnectedToAccountHandle,
	   COUNT(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS LEVEL,
	   Interest.InterestName AS InterestName
FROM   SocialGraph.Account AS Account1
                   ,SocialGraph.Account FOR PATH AS Account2
                   ,SocialGraph.Follows FOR PATH AS Follows
				   ,SocialGraph.InterestedIn
				   ,SocialGraph.Interest
WHERE  MATCH(SHORTEST_PATH(Account1(-(Follows)->Account2)+) AND LAST_NODE(Account2)-(InterestedIn)->Interest)
  AND  Account1.AccountHandle = '@Tom_Sutton'  
  ANd  Interest.InterestName =  'Aqua-lung'
 OPTION (MAXDOP 1);
GO

----------------------------------------------------------------------------------------------------------
--*****
--Finding a specific user that a user follows at any level, where they share a specific interest. Filtered by
--temp table.
--*****
----------------------------------------------------------------------------------------------------------


--any level connection and shared specific interest
DROP TABLE IF EXISTS #BaseRows
SELECT Account1.AccountHandle + '->' + 
       STRING_AGG(Account2.AccountHandle, '->') WITHIN GROUP (GRAPH PATH) AS ConnectedPath, 
       LAST_VALUE(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS ConnectedToAccountHandle,
	   COUNT(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS LEVEL,
	   Interest.InterestName AS InterestName
INTO #BaseRows
FROM   SocialGraph.Account AS Account1
                   ,SocialGraph.Account FOR PATH AS Account2
                   ,SocialGraph.Follows FOR PATH AS Follows
				   ,SocialGraph.InterestedIn
				   ,SocialGraph.Interest
WHERE  MATCH(SHORTEST_PATH(Account1(-(Follows)->Account2)+) AND LAST_NODE(Account2)-(InterestedIn)->Interest)
  AND  Account1.AccountHandle = '@Tom_Sutton'  
  OPTION (MAXDOP 1);

SELECT *
FROM   #BaseRows
WHERE  ConnectedToAccountHandle = '@Tonia_Mueller'
ORDER BY ConnectedPath;
Go


----------------------------------------------------------------------------------------------------------
--*****
--Finding a specific user that a user follows at any level, where they share a specific interest. Filtered 
--in CTE
--*****
----------------------------------------------------------------------------------------------------------


--any level connection and shared specific interest
WITH BaseRows AS (
SELECT Account1.AccountHandle + '->' + 
       STRING_AGG(Account2.AccountHandle, '->') WITHIN GROUP (GRAPH PATH) AS ConnectedPath, 
       LAST_VALUE(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS ConnectedToAccountHandle,
	   COUNT(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS LEVEL,
	   Interest.InterestName AS InterestName
FROM   SocialGraph.Account AS Account1
                   ,SocialGraph.Account FOR PATH AS Account2
                   ,SocialGraph.Follows FOR PATH AS Follows
				   ,SocialGraph.InterestedIn
				   ,SocialGraph.Interest
WHERE  MATCH(SHORTEST_PATH(Account1(-(Follows)->Account2)+) AND LAST_NODE(Account2)-(InterestedIn)->Interest)
  AND  Account1.AccountHandle = '@Tom_Sutton'  
)
SELECT *
FROM   BaseRows
WHERE  ConnectedToAccountHandle = '@Tonia_Mueller'
ORDER BY ConnectedPath
OPTION (MAXDOP 1);



----------------------------------------------------------------------------------------------------------
--*****
--Finding users that a person is connected to directly through interest
--******
----------------------------------------------------------------------------------------------------------


SELECT Account1.AccountHandle,
		Interest.InterestName,
		Account2.AccountHandle

FROM   SocialGraph.Account AS Account1
                   ,SocialGraph.Account AS Account2
				   ,SocialGraph.InterestedIn AS InterestedIn1
				   ,SocialGraph.InterestedIn  AS InterestedIn2
				   ,SocialGraph.Interest AS Interest
WHERE  MATCH(Account1-(InterestedIn1)->Interest<-(InterestedIn2)-Account2)
  AND  Account1.AccountHandle = '@Bryant_Huber'
OPTION (MAXDOP 1);




----------------------------------------------------------------------------------------------------------
--*****
--Finding users that a person is connected to directly through interest
--******
----------------------------------------------------------------------------------------------------------


SELECT Account1.AccountHandle,
		Interest.InterestName,
		Account2.AccountHandle

FROM   SocialGraph.Account AS Account1
                   ,SocialGraph.Account AS Account2
				   ,SocialGraph.InterestedIn AS InterestedIn1
				   ,SocialGraph.InterestedIn  AS InterestedIn2
				   ,SocialGraph.Interest AS Interest
WHERE  MATCH(Account1-(InterestedIn1)->Interest<-(InterestedIn2)-Account2)
  AND  Account1.AccountHandle = '@Tom_Sutton'
  AND  Interest.InterestName = 'Airsoft'
OPTION (MAXDOP 1);

----------------------------------------------------------------------------------------------------------
--*****
--Finding users that a person is connected through interest, two levels, initial person is not connected to many people
--*****
----------------------------------------------------------------------------------------------------------


SELECT Account1.AccountHandle 
+ '->' + 
       STRING_AGG(Account2.AccountHandle, '->') WITHIN GROUP (GRAPH PATH) AS ConnectedPath, 
       LAST_VALUE(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS ConnectedToAccountHandle,
	   COUNT(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS Level
FROM   SocialGraph.Account AS Account1
                   ,SocialGraph.Account FOR PATH AS Account2
				   ,SocialGraph.InterestedIn FOR PATH AS InterestedIn1
				   ,SocialGraph.InterestedIn FOR PATH AS InterestedIn2
				   ,SocialGraph.Interest FOR PATH AS Interest
WHERE  MATCH(SHORTEST_PATH(Account1(-(InterestedIn1)->Interest<-(InterestedIn2)-Account2){1,2}))
  AND  Account1.AccountHandle = '@Phillip_Moore'
OPTION (MAXDOP 1);
--OPTION(MAXDOP 1, RECOMPILE)

GO

----------------------------------------------------------------------------------------------------------
--*****
--Finding users that a person is connected through interest, two levels, initial person is connected to the most people
--*****
----------------------------------------------------------------------------------------------------------


SELECT Account1.AccountHandle 
+ '->' + 
       STRING_AGG(Account2.AccountHandle, '->') WITHIN GROUP (GRAPH PATH) AS ConnectedPath, 
       LAST_VALUE(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS ConnectedToAccountHandle,
	   COUNT(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS Level
FROM   SocialGraph.Account AS Account1
                   ,SocialGraph.Account FOR PATH AS Account2
				   ,SocialGraph.InterestedIn FOR PATH AS InterestedIn1
				   ,SocialGraph.InterestedIn FOR PATH AS InterestedIn2
				   ,SocialGraph.Interest FOR PATH AS Interest
WHERE  MATCH(SHORTEST_PATH(Account1(-(InterestedIn1)->Interest<-(InterestedIn2)-Account2){1,2}))
  AND  Account1.AccountHandle = '@Tom_Sutton'
--OPTION (MAXDOP 1);
OPTION(MAXDOP 1, RECOMPILE);



----------------------------------------------------------------------------------------------------------
--*****
--Output timing details
--*****
----------------------------------------------------------------------------------------------------------

