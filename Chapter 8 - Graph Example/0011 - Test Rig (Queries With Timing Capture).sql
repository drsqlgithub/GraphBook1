----------------------------------------------------------------------------------------------------------
--*****
--use to capture timing
--*****
----------------------------------------------------------------------------------------------------------
:setvar Account1 @Bryant_Huber
:setvar Account1ConnectedTo @Keisha_Perkins
:setvar Account1Interest1 Glassblowing
:setvar Account1Interest2 Relaxing
:setvar Account1ConnectedToInTwo @Brady_Lester
:setvar MaxLevelForFullQuery 10

:setvar Account1ConnectedToViaInterest @Gene_Brennan

:setvar Account2 @Toby_Higgins
:setvar Account2ConnectedTo @Jamie_Hawkins

:Setvar Account3 @Darren_Sellers

--change to -- if you want to see query results
:Setvar OutputResults ""


USE SocialGraph;
--GO
--SELECT COUNT(*) AS AccountCount
--FROM   SocialGraph.Account;
--SELECT COUNT(*) AS FollowsCount
--FROM   SocialGraph.Follows;
--SELECT COUNT(*) AS InterestCount
--FROM   SocialGraph.Interest;
--SELECT COUNT(*) AS InterestedInCount
--FROM   SocialGraph.InterestedIn;



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

DROP TABLE IF EXISTS #HoldResults;

--1
SELECT LAST_VALUE(Account2.AccountHandle) 
	           WITHIN GROUP (GRAPH PATH) AS ConnectedToAccountHandle,
	   COUNT(Account2.AccountHandle) 
	           WITHIN GROUP (GRAPH PATH) AS LEVEL,
       STRING_AGG(Account2.AccountHandle, '->') 
               WITHIN GROUP (GRAPH PATH) AS ConnectedPath
$(OutputResults)INTO #HoldResults
FROM   SocialGraph.Account AS Account1
                   ,SocialGraph.Account FOR PATH AS Account2
                   ,SocialGraph.Follows FOR PATH AS Follows
WHERE  MATCH(SHORTEST_PATH(Account1(-(Follows)->Account2)+))
  AND  Account1.AccountHandle = '$(Account1)'
ORDER BY ConnectedPath;

DECLARE @RowsAffectedCount INT = @@ROWCOUNT
EXEC dbo.#CaptureTime$set @ProcessPart = 'End', -- varchar(10)
                            @TestSetName = 'Simple find all decendents',
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

DROP TABLE IF EXISTS #HoldResults;

--2
WITH BaseRows AS (
SELECT Account1.AccountHandle + '->' + 
       STRING_AGG(Account2.AccountHandle, '->') WITHIN GROUP (GRAPH PATH) AS ConnectedPath, 
       LAST_VALUE(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS ConnectedToAccountHandle,
	   COUNT(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS LEVEL
FROM   SocialGraph.Account AS Account1
                   ,SocialGraph.Account FOR PATH AS Account2
                   ,SocialGraph.Follows FOR PATH AS Follows
WHERE  MATCH(SHORTEST_PATH(Account1(-(Follows)->Account2)+))
  AND  Account1.AccountHandle = '$(Account1)'
)
SELECT *
$(OutputResults)INTO #HoldResults
FROM   BaseRows
WHERE  ConnectedToAccountHandle = '$(Account1ConnectedTo)'
OPTION (MAXDOP 1);

DECLARE @RowsAffectedCount INT = @@ROWCOUNT
EXEC dbo.#CaptureTime$set @ProcessPart = 'End', -- varchar(10)
                            @TestSetName = 'Simple find specific decendent, using where clause',
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

DROP TABLE IF EXISTS #HoldResults;
DROP TABLE IF EXISTS #Hold;

--3
SELECT Account1.AccountHandle + '->' + 
       STRING_AGG(Account2.AccountHandle, '->') WITHIN GROUP (GRAPH PATH) AS ConnectedPath, 
       LAST_VALUE(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS ConnectedToAccountHandle,
	   COUNT(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS LEVEL
INTO #Hold
FROM   SocialGraph.Account AS Account1
                   ,SocialGraph.Account FOR PATH AS Account2
                   ,SocialGraph.Follows FOR PATH AS Follows
WHERE  MATCH(SHORTEST_PATH(Account1(-(Follows)->Account2)+))
  AND  Account1.AccountHandle = '$(Account1)'
ORDER BY ConnectedPath;

SELECT *
$(OutputResults)INTO #HoldResults
FROM   #hold
WHERE  ConnectedToAccountHandle = '$(Account1ConnectedTo)';

DECLARE @RowsAffectedCount INT = @@ROWCOUNT
EXEC dbo.#CaptureTime$set @ProcessPart = 'End', -- varchar(10)
                            @TestSetName = 'Simple find specific decendent, using temptable',
							@RowsAffectedCount = @RowsAffectedCount

GO

----------------------------------------------------------------------------------------------------------
--*****
--Find two level connections just using MATCH
--*****
----------------------------------------------------------------------------------------------------------

--find the path to a given node using temp table, very fast
EXEC dbo.#CaptureTime$set @ProcessPart = 'Start', -- varchar(10)
                            @TestSetName = 'Find two level connections just using MATCH'  -- varchar(1000)
GO

DROP TABLE IF EXISTS #HoldResults;

--4
SELECT  1 AS Level, '' AS ConnectedThrough, Account2.AccountHandle
$(OutputResults)INTO #holdResults
FROM    SocialGraph.Account AS Account1,
        SocialGraph.Follows,
		SocialGraph.Account AS Account2
WHERE   MATCH(Account1-(Follows)->Account2)
  AND   Account1.AccountHandle = '$(Account1)'
  AND   Account2.AccountHandle = '$(Account1ConnectedToInTwo)'
UNION ALL
SELECT  2 AS Level, Account2.AccountHandle AS ConnectedThrough, Account3.AccountHandle
FROM    SocialGraph.Account AS Account1,
        SocialGraph.Follows,
		SocialGraph.Account AS Account2,
        SocialGraph.Follows AS Follows2,
		SocialGraph.Account AS Account3
WHERE   MATCH(Account1-(Follows)->Account2-(Follows2)->Account3)
  AND   Account1.AccountHandle = '$(Account1)'
  AND   Account3.AccountHandle = '$(Account1ConnectedToInTwo)'
ORDER BY AccountHandle


DECLARE @RowsAffectedCount INT = @@ROWCOUNT
--find the path to a given node using temp table, very fast
EXEC dbo.#CaptureTime$set @ProcessPart = 'End', -- varchar(10)
                            @TestSetName = 'Find two level connections just using MATCH',
							@RowsAffectedCount = @RowsAffectedCount

----------------------------------------------------------------------------------------------------------
--*****
--Find all paths between decendents using Follows, recursive
--*****
----------------------------------------------------------------------------------------------------------

--find the path to a given node using temp table, very fast
EXEC dbo.#CaptureTime$set @ProcessPart = 'Start', -- varchar(10)
                            @TestSetName = 'Find all paths between decendents using Follows, recursive'  -- varchar(1000)
GO

DROP TABLE IF EXISTS #HoldResults;

--Getting the same results as the last example
--5
DECLARE @MaxLevel INT = $(MaxLevelForFullQuery),
		@AccountHandle NVARCHAR(30) = '$(Account1)',
		@DetermineHowConnected NVARCHAR(30) = '$(Account1ConnectedTo)';


WITH BaseRows
AS (
    --the CTE anchor is just the starting node
    SELECT Account.AccountHandle AS AccountHandle,
           Account.AccountHandle AS FollowsAccountHandle,

	   --the path that contains the readable path we have 
         --built in all examples with the anchor included
           CAST('\' + Account.AccountHandle + '\' AS NVARCHAR(4000)) AS Path, 
           0 AS level --the level
    FROM SocialGraph.Account
    WHERE Account.AccountHandle = @AccountHandle
	UNION ALL
	--pretty typical 1 level graph query:
	SELECT  Account.AccountHandle,
	        FollowedAccount.AccountHandle AS FollowsAccountHandle,
	        BaseRows.Path + FollowedAccount.AccountHandle + '\',
	        BaseRows.level + 1
	FROM SocialGraph.Account,
	        SocialGraph.Follows,
	        SocialGraph.Account AS FollowedAccount,
	        BaseRows
	WHERE MATCH(Account-(Follows)->FollowedAccount)
	    --this joins the anchor to the recursive part of the query
	    AND BaseRows.FollowsAccountHandle = Account.AccountHandle
	--this is the part that stops recursion, treating the
	    --string value like an array
	    AND NOT BaseRows.Path LIKE CONCAT('%\', 
	                                 FollowedAccount.AccountHandle, '\%')
	            AND BaseRows.level < @MaxLevel
	)

SELECT Path --for space reasons only
$(OutputResults)INTO #holdResults
FROM BaseRows
WHERE FollowsAccountHandle = @DetermineHowConnected
ORDER BY Path;

DECLARE @RowsAffectedCount INT = @@ROWCOUNT
--find the path to a given node using temp table, very fast
EXEC dbo.#CaptureTime$set @ProcessPart = 'End', -- varchar(10)
                            @TestSetName = 'Find all paths between decendents using Follows, recursive',
							@RowsAffectedCount = @RowsAffectedCount
GO


----------------------------------------------------------------------------------------------------------
--*****
--Finding all people that a user follows at any level, where the follower has a specific interest
--*****
----------------------------------------------------------------------------------------------------------

--find the path to a given node using temp table, very fast
EXEC dbo.#CaptureTime$set @ProcessPart = 'Start', -- varchar(10)
                            @TestSetName = 'Any level follow and followers have specific interest'  -- varchar(1000)
GO

DROP TABLE IF EXISTS #HoldResults;
--6
----any level connection and connections have a specific interest
SELECT Account1.AccountHandle + '->' + 
       STRING_AGG(Account2.AccountHandle, '->') WITHIN GROUP (GRAPH PATH) AS ConnectedPath, 
       LAST_VALUE(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS ConnectedToAccountHandle,
	   COUNT(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS LEVEL,
	   Interest.InterestName
$(OutputResults)INTO #HoldResults
FROM   SocialGraph.Account AS Account1
                   ,SocialGraph.Account FOR PATH AS Account2
                   ,SocialGraph.Follows FOR PATH AS Follows
				   ,SocialGraph.InterestedIn
				   ,SocialGraph.Interest
WHERE  MATCH(SHORTEST_PATH(Account1(-(Follows)->Account2)+) 
  AND LAST_NODE(Account2)-(InterestedIn)->Interest)
  AND  Account1.AccountHandle = '$(Account1)'
  AND  Interest.InterestName = '$(Account1Interest1)'
ORDER BY ConnectedPath
OPTION (MAXDOP 1);

DECLARE @RowsAffectedCount INT = @@ROWCOUNT;
EXEC dbo.#CaptureTime$set @ProcessPart = 'End', -- varchar(10)
                            @TestSetName = 'Any level follow and followers have specific interest',
							@RowsAffectedCount = @RowsAffectedCount;
GO

----------------------------------------------------------------------------------------------------------
--*****
--Finding all people that a user follows at any level, where the follower has a specific interest
--*****
----------------------------------------------------------------------------------------------------------

--find the path to a given node using temp table, very fast
EXEC dbo.#CaptureTime$set @ProcessPart = 'Start', -- varchar(10)
                            @TestSetName = 'Any level follow and followers have specific interest, temptable'  -- varchar(1000)
GO

DROP TABLE IF EXISTS #HoldResults;

--7
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
WHERE  MATCH(SHORTEST_PATH(Account1(-(Follows)->Account2)+) 
  AND LAST_NODE(Account2)-(InterestedIn)->Interest)
  AND  Account1.AccountHandle = '$(Account1)'
OPTION (MAXDOP 1);

SELECT *
$(OutputResults)INTO #HoldResults
FROM   #BaseRows
WHERE  InterestName = '$(Account1Interest1)'
ORDER BY ConnectedPath


DECLARE @RowsAffectedCount INT = @@ROWCOUNT;
EXEC dbo.#CaptureTime$set @ProcessPart = 'End', -- varchar(10)
                            @TestSetName = 'Any level follow and followers have specific interest, temptable',
							@RowsAffectedCount = @RowsAffectedCount;
GO





----------------------------------------------------------------------------------------------------------
--*****
--Finding all people that a user follows at any level, where they share a interest.
--*****
----------------------------------------------------------------------------------------------------------

--find the path to a given node using temp table, very fast
EXEC dbo.#CaptureTime$set @ProcessPart = 'Start', -- varchar(10)
                            @TestSetName = 'Any level follow and shared interest, CTE'  -- varchar(1000)
GO

DROP TABLE IF EXISTS #HoldResults;

--8
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
				   ,SocialGraph.InterestedIn AS InterestedIn2
				   ,SocialGraph.Interest
WHERE  MATCH(SHORTEST_PATH(Account1(-(Follows)->Account2)+) 
  --Both Accounts interested in the same thing
  AND LAST_NODE(Account2)-(InterestedIn)->Interest<-(InterestedIn2)-Account1)
  AND  Account1.AccountHandle = '$(Account1)'

)
SELECT InterestName, ConnectedPath
$(OutputResults)INTO #HoldResults
FROM   BaseRows
WHERE  ConnectedToAccountHandle = '$(Account1ConnectedToViaInterest)'
ORDER BY ConnectedPath
OPTION (MAXDOP 1);

DECLARE @RowsAffectedCount INT = @@ROWCOUNT;
EXEC dbo.#CaptureTime$set @ProcessPart = 'End', -- varchar(10)
                            @TestSetName = 'Any level follow and shared interest, CTE',
							@RowsAffectedCount = @RowsAffectedCount;
GO


----------------------------------------------------------------------------------------------------------
--*****
--Finding all people that a user follows at any level, where they share a interest.
--*****
----------------------------------------------------------------------------------------------------------

--find the path to a given node using temp table, very fast
EXEC dbo.#CaptureTime$set @ProcessPart = 'Start', -- varchar(10)
                            @TestSetName = 'any level connection and shared specific interest'  -- varchar(1000)
GO

DROP TABLE IF EXISTS #HoldResults;

--any level connection and shared specific interest
--9 Query to get only 
SELECT Account1.AccountHandle + '->' + 
       STRING_AGG(Account2.AccountHandle, '->') WITHIN GROUP (GRAPH PATH) AS ConnectedPath, 
       LAST_VALUE(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS ConnectedToAccountHandle,
	   COUNT(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS LEVEL,
	   Interest.InterestName AS InterestName
$(OutputResults)INTO #HoldResults
FROM   SocialGraph.Account AS Account1
                   ,SocialGraph.Account FOR PATH AS Account2
                   ,SocialGraph.Follows FOR PATH AS Follows
				   ,SocialGraph.InterestedIn
				   ,SocialGraph.InterestedIn AS InterestedIn2
				   ,SocialGraph.Interest
WHERE  MATCH(SHORTEST_PATH(Account1(-(Follows)->Account2)+) 
  AND LAST_NODE(Account2)-(InterestedIn)->Interest<-(InterestedIn2)-Account1)
  AND  Account1.AccountHandle = '$(Account1)'  
  AND  Interest.InterestName =  '$(Account1Interest1)'
 OPTION (MAXDOP 1);


DECLARE @RowsAffectedCount INT = @@ROWCOUNT;
EXEC dbo.#CaptureTime$set @ProcessPart = 'End', -- varchar(10)
                            @TestSetName = 'any level connection and shared specific interest',
							@RowsAffectedCount = @RowsAffectedCount;
GO






----------------------------------------------------------------------------------------------------------
--*****
--Finding users that a person is connected to directly through interest
--******
----------------------------------------------------------------------------------------------------------


EXEC dbo.#CaptureTime$set @ProcessPart = 'Start', -- varchar(10)
                            @TestSetName = 'Finding users that a person is connected to directly through specific interest'

DROP TABLE IF EXISTS #HoldResults;
--10
SELECT Account1.AccountHandle,
		Interest.InterestName,
		Account2.AccountHandle AS ToAccountHandle
$(OutputResults)INTO #HoldResults
FROM   SocialGraph.Account AS Account1
                   ,SocialGraph.Account AS Account2
				   ,SocialGraph.InterestedIn AS InterestedIn1
				   ,SocialGraph.InterestedIn  AS InterestedIn2
				   ,SocialGraph.Interest AS Interest
WHERE  MATCH(Account1-(InterestedIn1)->Interest<-(InterestedIn2)-Account2)
  AND  Account1.AccountHandle = '$(Account1)'
  AND  Account1.AccountHandle <> Account2.AccountHandle 
  AND  Interest.InterestName = '$(Account1Interest2)'
OPTION (MAXDOP 1);

DECLARE @RowsAffectedCount INT = @@ROWCOUNT
EXEC dbo.#CaptureTime$set @ProcessPart = 'End', -- varchar(10)
                            @TestSetName = 'Finding users that a person is connected to directly through specific interest',
							@RowsAffectedCount = @RowsAffectedCount

GO

----------------------------------------------------------------------------------------------------------
--*****
--Finding users that a person is connected through interest, two levels, initial person is not connected to many people
--*****
----------------------------------------------------------------------------------------------------------


EXEC dbo.#CaptureTime$set @ProcessPart = 'Start', -- varchar(10)
                            @TestSetName = 'Connection path through interest, starting with low cardinality, two levels'

DROP TABLE IF EXISTS #HoldResults;

--11
SELECT Account1.AccountHandle 
+ '->' + 
       STRING_AGG(Account2.AccountHandle, '->') WITHIN GROUP (GRAPH PATH) AS ConnectedPath, 
       LAST_VALUE(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS ConnectedToAccountHandle,
	   COUNT(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS LEVEL
$(OutputResults)INTO #HoldResults       
FROM   SocialGraph.Account AS Account1
                   ,SocialGraph.Account FOR PATH AS Account2
				   ,SocialGraph.InterestedIn FOR PATH AS InterestedIn1
				   ,SocialGraph.InterestedIn FOR PATH AS InterestedIn2
				   ,SocialGraph.Interest FOR PATH AS Interest
WHERE  MATCH(SHORTEST_PATH(Account1(-(InterestedIn1)->Interest<-(InterestedIn2)-Account2){1,2}))
  AND  Account1.AccountHandle = '$(Account3)'
OPTION (MAXDOP 1);


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

DROP TABLE IF EXISTS #HoldResults;

EXEC dbo.#CaptureTime$set @ProcessPart = 'Start', -- varchar(10)
                            @TestSetName = 'Connection path through interest, starting with low cardinality, 10 levels'

SELECT Account1.AccountHandle 
+ '->' + 
       STRING_AGG(Account2.AccountHandle, '->') WITHIN GROUP (GRAPH PATH) AS ConnectedPath, 
       LAST_VALUE(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS ConnectedToAccountHandle,
	   COUNT(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS LEVEL
$(OutputResults)INTO #HoldResults  
FROM   SocialGraph.Account AS Account1
                   ,SocialGraph.Account FOR PATH AS Account2
				   ,SocialGraph.InterestedIn FOR PATH AS InterestedIn1
				   ,SocialGraph.InterestedIn FOR PATH AS InterestedIn2
				   ,SocialGraph.Interest FOR PATH AS Interest
WHERE  MATCH(SHORTEST_PATH(Account1(-(InterestedIn1)->Interest<-(InterestedIn2)-Account2){1,10}))
  AND  Account1.AccountHandle = '$(Account3)'
OPTION (MAXDOP 1);



DECLARE @RowsAffectedCount INT = @@ROWCOUNT
EXEC dbo.#CaptureTime$set @ProcessPart = 'End', -- varchar(10)
                            @TestSetName = 'Connection path through interest, starting with low cardinality, 10 levels',
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
