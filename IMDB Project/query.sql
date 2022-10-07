SELECT Person.PrimaryName, TitleType, Title.Name, Person2.PrimaryName
FROM  Imdb.Person, 
	  Imdb.ContributedTo AS ContributedTo, Imdb.Title AS Title, 
	  Imdb.ContributedTo AS ContributedTo2, Imdb.Person AS Person2
WHERE MATCH(Person-(ContributedTo)->Title<-(ContributedTo2)-Person2)
  AND Person.PrimaryName = 'Frank Cardillo'

WITH baseRows AS (
SELECT Person.PrimaryName + '->' + 
       STRING_AGG(CONCAT(Title.Name,'->',Person2.PrimaryName), '->') WITHIN GROUP (GRAPH PATH) AS ConnectedPath, 
       LAST_VALUE(Person2.PrimaryName) WITHIN GROUP (GRAPH PATH) AS ConnectedToAccountHandle
FROM  Imdb.Person AS Person, 
	  Imdb.Person FOR PATH AS Person2,
	  Imdb.Title FOR PATH AS Title, 
	  Imdb.ContributedTo FOR PATH AS ContributedTo, 
	  Imdb.ContributedTo FOR PATH AS ContributedTo2
WHERE MATCH(SHORTEST_PATH(Person(-(ContributedTo)->Title<-(ContributedTo2)-Person2)+))
  AND Person.PrimaryName = 'Kevin Bacon'
)
SELECT *
FROM   BaseRows
WHERE  ConnectedToAccountHandle = 'Frank Cardillo'

SELECT Person.PrimaryName, WorkedWith.TitleId,  Person2.PrimaryName
FROM  Imdb.Person AS Person, 
	  Imdb.WorkedWith AS WorkedWith, 
	  Imdb.Person AS Person2
WHERE MATCH(Person-(WorkedWith)->Person2)
  AND Person.PrimaryName = 'Frank Cardillo'


WITH baseRows AS (
SELECT Person.PrimaryName + '->' + 
       STRING_AGG(CONCAT(WorkedWith.TitleId,'->',Person2.PrimaryName), '->') WITHIN GROUP (GRAPH PATH) AS ConnectedPath, 
       LAST_VALUE(Person2.PrimaryName) WITHIN GROUP (GRAPH PATH) AS ConnectedToAccountHandle
FROM  Imdb.Person AS Person, 
	  Imdb.Person FOR PATH AS Person2,
	  Imdb.WorkedWith FOR PATH AS WorkedWith
WHERE MATCH(SHORTEST_PATH(Person(-(WorkedWith)->Person2)+))
  --AND Person.PrimaryName = 'Frank Cardillo'
  AND Person.PrimaryName = 'Frank Sinatra'
)
SELECT *
FROM   BaseRows
WHERE  ConnectedToAccountHandle = 'Kevin Bacon'

Msg 1105, LEVEL 17, STATE 2, Line 32
Could NOT ALLOCATE SPACE FOR OBJECT 'dbo.SORT temporary run storage:  140739787161600' IN DATABASE 'tempdb' because the 'PRIMARY' FILEGROUP IS FULL. CREATE DISK SPACE BY deleting unneeded files, dropping objects IN the FILEGROUP, adding additional files TO the FILEGROUP, OR setting autogrowth ON FOR existing files IN the FILEGROUP.


/*
4 hours
Frank Cardillo->tt1647366->Dakota Star Granados->tt1589710->Armen Chakmakian->tt2222434->Bec Fordyce->tt5492868->Judy Artime->tt9164372->Kevin Bacon	Kevin Bacon
Frank Cardillo->tt1647366->Dakota Star Granados->tt1589710->Armen Chakmakian->tt1605491->Kristos Andrews->tt2088976->Michael Sassano->tt1974360->Kevin Bacon	Kevin Bacon
Frank Cardillo->tt1647366->Dakota Star Granados->tt1589710->Dean Landon->tt6905430->Cheryl Arutt->tt7944658->Scott Carnegie->tt6293610->Kevin Bacon	Kevin Bacon
Frank Cardillo->tt1647366->Dakota Star Granados->tt1589710->Kevin A. Leman II->tt0570232->Elton John->tt12094822->Anne Nightingale->tt0792626->Kevin Bacon	Kevin Bacon
Frank Cardillo->tt1647366->Dakota Star Granados->tt1589710->Beth Sherman->tt2136462->Kevin Bacon	Kevin Bacon
*/

SELECT Account1.AccountHandle + '->' + 
       STRING_AGG(CONCAT(Interest.InterestName,'->',Account2.AccountHandle), '->') WITHIN GROUP (GRAPH PATH) AS ConnectedPath, 
       LAST_VALUE(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS ConnectedToAccountHandle
FROM   SocialGraph.Account AS Account1
                   ,SocialGraph.Account FOR PATH AS Account2
                   ,SocialGraph.Interest FOR PATH AS Interest
                   ,SocialGraph.InterestedIn FOR PATH AS InterestedIn
                   ,SocialGraph.InterestedIn FOR PATH AS InterestedIn2
                   --Account1 is interested in an interest, and Account2 is also
WHERE  MATCH(SHORTEST_PATH(Account1(-(InterestedIn)->Interest<-(InterestedIn2)-Account2)+)) -- The interesting part
  AND  Account1.AccountHandle = '@Joe'


SELECT @@VERSION

USE IMDB
GO
SELECT Person.PrimaryName, Person2.PrimaryName, Title.Name
FROM  Imdb.Person, Imdb.ContributedTo AS ContributedTo, Imdb.Title AS Title, 
	  Imdb.ContributedTo AS ContributedTo2, Imdb.Person AS Person2
  WHERE MATCH(Person-(ContributedTo)->Title<-(ContributedTo2)-Person2)
AND Person.PrimaryName = 'Fred Astaire';

SELECT TOP 10 LAST_VALUE(Person2.PrimaryName) WITHIN GROUP (GRAPH PATH) AS ConnectedToAccountHandle
FROM  Imdb.Person AS Person, Imdb.ContributedTo FOR PATH AS ContributedTo, Imdb.Title FOR PATH AS Title, 
	  Imdb.ContributedTo FOR PATH AS ContributedTo2, Imdb.Person FOR PATH AS Person2
  WHERE MATCH(SHORTEST_PATH(Person(-(ContributedTo)->Title<-(ContributedTo2)-Person2)+))
AND Person.PrimaryName = 'Fred Astaire'
OPTION (MAXDOP 1)

SELECT *
FROM   Imdb.Person

USE GraphExample
GO

SELECT LAST_VALUE(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS ConnectedToAccountHandle
FROM   SocialGraph.Account AS Account1
                   ,SocialGraph.Account FOR PATH AS Account2
                   ,SocialGraph.Interest FOR PATH AS Interest
                   ,SocialGraph.InterestedIn FOR PATH AS InterestedIn
                   ,SocialGraph.InterestedIn FOR PATH AS InterestedIn2
                   --Account1 is interested in an interest, and Account2 is also
WHERE  MATCH(SHORTEST_PATH(Account1(-(InterestedIn)->Interest<-(InterestedIn2)-Account2)+)) -- The interesting part
  AND  Account1.AccountHandle = '@Joe'

SELECT COUNT(*) 
FROM   Imdb.Person

SELECT COUNT(*) 
FROM   Imdb.ContributedTo

SELECT COUNT(*) 
FROM   Imdb.Title


-----------
10756900

-----------
43312922

-----------
7668281

shutdown