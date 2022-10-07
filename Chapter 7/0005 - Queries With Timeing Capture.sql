----------------------------------------------------------------------------------------------------------
--*****
--use to capture timing
--*****
----------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS Tempdb.dbo.CaptureTime ;
DROP PROCEDURE IF EXISTS #CaptureTime$Set;
GO


CREATE TABLE Tempdb.dbo.CaptureTime (CaptureId INT IDENTITY,
						   ProcessPart VARCHAR(10),
						   CaptureTime DATETIME2(0) DEFAULT (SYSDATETIME()),
						   TestSetName VARCHAR(1000),
						   RowsAffectedCount int)
GO
CREATE PROCEDURE #CaptureTime$set (@ProcessPart VARCHAR(10),
									@TestSetName VARCHAR(1000),
									@RowsAffectedCount INT = NULL)
AS
  SET NOCOUNT ON;
  PRINT '--------------------------------------------------'
  PRINT @TestSetName
  PRINT @ProcessPart
  INSERT INTO Tempdb.dbo.CaptureTime
  (
      ProcessPart,
      TestSetName,
	  RowsAffectedCount
  )
  VALUES
  (   @ProcessPart, @TestSetName, @RowsAffectedCount)
GO


----------------------------------------------------------------------------------------------------------
--*****
--Simple find all decendents using Follows
--*****
----------------------------------------------------------------------------------------------------------


EXEC dbo.#CaptureTime$set @ProcessPart = 'Start', -- varchar(10)
                            @TestSetName = 'Simple find all decendents'  -- varchar(1000)
GO
SELECT Account1.AccountHandle + '->' + 
       STRING_AGG(Account2.AccountHandle, '->') WITHIN GROUP (GRAPH PATH) AS ConnectedPath, 
       LAST_VALUE(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS ConnectedToAccountHandle,
	   COUNT(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS LEVEL
FROM   SocialGraph.Account AS Account1
                   ,SocialGraph.Account FOR PATH AS Account2
                   ,SocialGraph.Follows FOR PATH AS Follows
WHERE  MATCH(SHORTEST_PATH(Account1(-(Follows)->Account2)+))
  AND  Account1.AccountHandle = '@Bryant_Huber'
ORDER BY ConnectedPath;

DECLARE @RowsAffectedCount INT = @@ROWCOUNT
EXEC dbo.#CaptureTime$set @ProcessPart = 'End', -- varchar(10)
                            @TestSetName = 'Simple find all decendents',
							@RowsAffectedCount = @RowsAffectedCount
GO


----------------------------------------------------------------------------------------------------------
--*****
--Finding a specific decendent by saving off ALL decendents, then filtering in temp table
--*****
----------------------------------------------------------------------------------------------------------



--find the path to a given node using temp table, very fast
EXEC dbo.#CaptureTime$set @ProcessPart = 'Start', -- varchar(10)
                            @TestSetName = 'Simple find specific decendent, using temptable'  -- varchar(1000)

DROP TABLE IF EXISTS #hold;

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
  AND  Account1.AccountHandle = '@Bryant_Huber'
ORDER BY ConnectedPath;

SELECT *
FROM   #hold
WHERE  ConnectedToAccountHandle = '@Keisha_Perkins';

DECLARE @RowsAffectedCount INT = @@ROWCOUNT
EXEC dbo.#CaptureTime$set @ProcessPart = 'End', -- varchar(10)
                            @TestSetName = 'Simple find specific decendent, using temptable',
							@RowsAffectedCount = @RowsAffectedCount

GO

----------------------------------------------------------------------------------------------------------
--*****
--Finding a specific decendent by saving off ALL decendents, filtering rows using a CTE
--*****
----------------------------------------------------------------------------------------------------------

--find the path to a given node using temp table, very fast
EXEC dbo.#CaptureTime$set @ProcessPart = 'Start', -- varchar(10)
                            @TestSetName = 'Simple find specific decendent, using where clause'  -- varchar(1000)
GO
WITH BaseRows AS (
SELECT Account1.AccountHandle + '->' + 
       STRING_AGG(Account2.AccountHandle, '->') WITHIN GROUP (GRAPH PATH) AS ConnectedPath, 
       LAST_VALUE(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS ConnectedToAccountHandle,
	   COUNT(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS LEVEL
FROM   SocialGraph.Account AS Account1
                   ,SocialGraph.Account FOR PATH AS Account2
                   ,SocialGraph.Follows FOR PATH AS Follows
WHERE  MATCH(SHORTEST_PATH(Account1(-(Follows)->Account2)+))
  AND  Account1.AccountHandle = '@Bryant_Huber'
)
SELECT *
FROM   BaseRows
WHERE  ConnectedToAccountHandle = '@Keisha_Perkins'

DECLARE @RowsAffectedCount INT = @@ROWCOUNT
--find the path to a given node using temp table, very fast
EXEC dbo.#CaptureTime$set @ProcessPart = 'End', -- varchar(10)
                            @TestSetName = 'Simple find specific decendent, using where clause',
							@RowsAffectedCount = @RowsAffectedCount
GO



----------------------------------------------------------------------------------------------------------
--*****
--Finding all people that a user follows at any level, where they share a interest.
--*****
----------------------------------------------------------------------------------------------------------

--find the path to a given node using temp table, very fast
EXEC dbo.#CaptureTime$set @ProcessPart = 'Start', -- varchar(10)
                            @TestSetName = 'Any level follow and shared interest'  -- varchar(1000)
GO

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
  AND  Account1.AccountHandle = '@Bryant_Huber'
ORDER BY ConnectedPath

DECLARE @RowsAffectedCount INT = @@ROWCOUNT;
EXEC dbo.#CaptureTime$set @ProcessPart = 'End', -- varchar(10)
                            @TestSetName = 'Any level follow and shared interest',
							@RowsAffectedCount = @RowsAffectedCount;
GO

----------------------------------------------------------------------------------------------------------
--*****
--Finding all people that a user follows at any level, where they share a specific interest. Filtered by
--temp table.
--*****
----------------------------------------------------------------------------------------------------------


EXEC dbo.#CaptureTime$set @ProcessPart = 'Start', -- varchar(10)
                            @TestSetName = 'Any level follow and shared specific interest, using temptable'  -- varchar(1000)

--any level connection and shared specific interest
DROP TABLE #BaseRows
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
  AND  Account1.AccountHandle = '@Bryant_Huber'

SELECT *
FROM   #BaseRows
WHERE  InterestName = 'Glassblowing'
ORDER BY ConnectedPath

DECLARE @RowsAffectedCount INT = @@ROWCOUNT
EXEC dbo.#CaptureTime$set @ProcessPart = 'End', -- varchar(10)
                            @TestSetName = 'Any level follow and shared specific interest, using temptable',
							@RowsAffectedCount = @RowsAffectedCount

GO

----------------------------------------------------------------------------------------------------------
--*****
--Finding all people that a user follows at any level, where they share a specific interest. Filtered by
--WHERE clause.
--*****
----------------------------------------------------------------------------------------------------------

EXEC dbo.#CaptureTime$set @ProcessPart = 'Start', -- varchar(10)
                            @TestSetName = 'Any level follow and shared specific interest, using WHERE'  -- varchar(1000)

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
  AND  Account1.AccountHandle = '@Bryant_Huber'  
  ANd  Interest.InterestName =  'Glassblowing'

DECLARE @RowsAffectedCount INT = @@ROWCOUNT
EXEC dbo.#CaptureTime$set @ProcessPart = 'End', -- varchar(10)
                            @TestSetName = 'Any level follow and shared specific interest, using WHERE',
							@RowsAffectedCount = @RowsAffectedCount
GO


----------------------------------------------------------------------------------------------------------
--*****
--Finding a specific user that a user follows at any level, where they share a specific interest. Filtered by
--temp table.
--*****
----------------------------------------------------------------------------------------------------------

EXEC dbo.#CaptureTime$set @ProcessPart = 'Start', -- varchar(10)
                            @TestSetName = 'Connection path and shared interests between accounts, using Temptable'  -- varchar(1000)

--any level connection and shared specific interest
DROP TABLE #BaseRows
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
  AND  Account1.AccountHandle = '@Toby_Higgins'  

SELECT *
FROM   #BaseRows
WHERE  ConnectedToAccountHandle = '@Jamie_Hawkins'
ORDER BY ConnectedPath


DECLARE @RowsAffectedCount INT = @@ROWCOUNT;
EXEC dbo.#CaptureTime$set @ProcessPart = 'End', -- varchar(10)
                            @TestSetName = 'Connection path and shared interests between accounts, using Temptable',
							@RowsAffectedCount = @RowsAffectedCount
GO


----------------------------------------------------------------------------------------------------------
--*****
--Finding a specific user that a user follows at any level, where they share a specific interest. Filtered 
--in CTE
--*****
----------------------------------------------------------------------------------------------------------

EXEC dbo.#CaptureTime$set @ProcessPart = 'Start', -- varchar(10)
                            @TestSetName = 'Connection path and shared interests between accounts, using CTE'  -- varchar(1000)
GO
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
  AND  Account1.AccountHandle = '@Toby_Higgins'  
)
SELECT *
FROM   BaseRows
WHERE  ConnectedToAccountHandle = '@Jamie_Hawkins'
ORDER BY ConnectedPath


DECLARE @RowsAffectedCount INT = @@ROWCOUNT
EXEC dbo.#CaptureTime$set @ProcessPart = 'End', -- varchar(10)
                            @TestSetName = 'Connection path and shared interests between accounts, using CTE',
							@RowsAffectedCount = @RowsAffectedCount
GO


----------------------------------------------------------------------------------------------------------
--*****
--Finding users that a person is connected through interest, two levels, initial person is not connected to many people
--*****
----------------------------------------------------------------------------------------------------------


EXEC dbo.#CaptureTime$set @ProcessPart = 'Start', -- varchar(10)
                            @TestSetName = 'Connection path through interest, starting with low cardinality, two levels'

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
  AND  Account1.AccountHandle = '@Darren_Sellers'
--OPTION(MAXDOP 1, RECOMPILE)


DECLARE @RowsAffectedCount INT = @@ROWCOUNT
EXEC dbo.#CaptureTime$set @ProcessPart = 'End', -- varchar(10)
                            @TestSetName = 'Connection path through interest, starting with low cardinality, two levels',
							@RowsAffectedCount = @RowsAffectedCount

GO

----------------------------------------------------------------------------------------------------------
--*****
--Finding users that a person is connected through interest, two levels, initial person is connected to the most people
--*****
----------------------------------------------------------------------------------------------------------


EXEC dbo.#CaptureTime$set @ProcessPart = 'Start', -- varchar(10)
                            @TestSetName = 'Connection path through interest,  with high cardinality',

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
  AND  Account1.AccountHandle = '@Bryant_Huber'
OPTION(MAXDOP 1, RECOMPILE)


DECLARE @RowsAffectedCount INT = @@ROWCOUNT
EXEC dbo.#CaptureTime$set @ProcessPart = 'End', -- varchar(10)
                            @TestSetName = 'Connection path through interest, with high cardinality',
							@RowsAffectedCount = @RowsAffectedCount

GO
----------------------------------------------------------------------------------------------------------
--*****
--Output timing details
--*****
----------------------------------------------------------------------------------------------------------


--Note, can be executed in a different window to monitor process

SELECT CAST(c2.TestSetname AS NVARCHAR(80)) AS TestSetName, DATEDIFF(SECOND,c1.CaptureTime, c2.CaptureTime) AS TimeDifferenceSeconds, C2.RowsAffectedCount,C2.CaptureTime
FROM   Tempdb.dbo.CaptureTime AS C1
		JOIN  Tempdb.dbo.CaptureTime AS C2
			ON c2.TestSetName = C1.TestSetname
			   AND c1.CaptureId = c2.CaptureId - 1
WHERE c2.ProcessPart = 'End'
  AND c1.ProcessPart = 'Start'
ORDER BY c2.CaptureTime

SELECT c1.TestSetname , DATEDIFF(SECOND,c1.CaptureTime,SYSDATETIME()) AS TimeDifferenceSeconds,C1.CaptureTime, 'Not Completed'
FROM   Tempdb.dbo.CaptureTime AS C1
WHERE c1.ProcessPart = 'Start'
  AND  NOT EXISTS (SELECT *
					FROM tempdb.dbo.CaptureTime
					WHERE CaptureTime.TestSetName = C1.TestSetname
					   AND  CaptureTime.CaptureId -1 = C1.CaptureId)
