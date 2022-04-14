USE Imdb
G0

SELECT *
FROM  Imdb.Person
WHERE Person.PrimaryName = 'Frank Sinatra'

--get first level relations to 'Frank cardillo' using contributions link

DECLARE @personTag VARCHAR(10) = 'nm3901849' --Frank Cardillo with 10 1st level connections
SET  @personTag = 'nm0000069' -- 'Frank Sinatra' --2393 connections
DECLARE @PersonId INT = (SELECT Person.PersonId FROM Imdb.Person WHERE personTag = @PersonTag)

SELECT Person.PrimaryName, Person.PersonId, TitleType, Title.Name, Person2.PrimaryName, Person2.PersonId
FROM  Imdb.Person, 
	  Imdb.ContributedTo AS ContributedTo, Imdb.Title AS Title, 
	  Imdb.ContributedTo AS ContributedTo2, Imdb.Person AS Person2
WHERE MATCH(Person-(ContributedTo)->Title<-(ContributedTo2)-Person2)
  AND Person.PersonId = @PersonId
GO


DECLARE @personTag VARCHAR(10) = 'nm3901849' --Frank Cardillo with 10 1st level connections
SET  @personTag = 'nm0000069' -- 'Frank Sinatra' --2393 connections
DECLARE @PersonId INT = (SELECT Person.PersonId FROM Imdb.Person WHERE personTag = @PersonTag)

SELECT Person.PrimaryName, WorkedWith.TitleId,  Person2.PrimaryName
FROM  Imdb.Person AS Person, 
	  Imdb.WorkedWith AS WorkedWith, 
	  Imdb.Person AS Person2,
	  Imdb.Title AS Title
WHERE MATCH(Person-(WorkedWith)->Person2)
  AND WorkedWith.TitleId = Title.TitleId
  AND Person.PersonId = @PersonId

GO

--second level connections:

DECLARE @personTag VARCHAR(10) = 'nm3901849' --Frank Cardillo with 10 1st level connections

--SET  @personTag = 'nm0000069' -- 'Frank Sinatra' --2393 connections
DECLARE @PersonId INT = (SELECT Person.PersonId FROM Imdb.Person WHERE personTag = @PersonTag)

SELECT Person.PrimaryName,Title.Name,  Person2.PrimaryName,Title2.Name, Person3.PrimaryName
FROM  Imdb.Person AS Person, 
	  Imdb.WorkedWith AS WorkedWith, 
	  Imdb.Person AS Person2,
	  Imdb.Title AS Title,
	  Imdb.WorkedWith AS WorkedWIth2,
	  Imdb.Person AS Person3,
	  Imdb.title AS Title2
WHERE MATCH(Person-(WorkedWith)->Person2-(WorkedWIth2)->Person3)
  AND WorkedWith.TitleId = Title.TitleId
  AND WorkedWith2.TitleId = Title2.TitleId
  AND Person.PersonId = @PersonId
  AND person.personId <> Person2.personId
ORDER BY 1,2,3,4,5
GO


--get second level relations to 'Frank cardillo' using contributions link
DECLARE @personTag VARCHAR(10) = 'nm3901849' --Frank Cardillo with 10 1st level connections
--SET  @personTag = 'nm0000069' -- 'Frank Sinatra' --2393 connections
DECLARE @PersonId INT = (SELECT Person.PersonId FROM Imdb.Person WHERE personTag = @PersonTag)

SELECT Person.PrimaryName, Person.PersonId, Title.TitleType, Title.Name, Person2.PrimaryName, Person2.PersonId, Title2.Name, Person3.PrimaryName
FROM  Imdb.Person, 
	  Imdb.ContributedTo AS ContributedTo, Imdb.Title AS Title, 
	  Imdb.ContributedTo AS ContributedTo2, Imdb.Person AS Person2,
	  Imdb.ContributedTo AS ContributedTo3, Imdb.Person AS Person3,
	  Imdb.ContributedTo AS ContributedTo4, Imdb.Title AS TItle2
WHERE MATCH(Person-(ContributedTo)->Title<-(ContributedTo2)-Person2-(ContributedTo3)->Title2<-(ContributedTo4)-Person3)
  AND Person.PersonId = @PersonId
   AND person.personId <> Person2.personId
ORDER BY 1,2,3,4,5
GO




--get second level relations to 'Frank cardillo' using contributions link and shortest path
DECLARE @personTag VARCHAR(10) = 'nm3901849' --Frank Cardillo with 10 1st level connections
--SET  @personTag = 'nm0000069' -- 'Frank Sinatra' --2393 connections
DECLARE @PersonId INT = (SELECT Person.PersonId FROM Imdb.Person WHERE personTag = @PersonTag)

  --ran 9 hours, killed it, it ended in seconds... but DID NOT fill up tempdb this time
SELECT Person.PrimaryName + '->' + 
       STRING_AGG(CONCAT(Title.Name,'->',Person2.PrimaryName), '->') WITHIN GROUP (GRAPH PATH) AS ConnectedPath, 
       LAST_VALUE(Person2.PrimaryName) WITHIN GROUP (GRAPH PATH) AS ConnectedToAccountHandle
INTO #hold
FROM  Imdb.Person AS Person, 
	  Imdb.Person FOR PATH AS Person2,
	  Imdb.Title FOR PATH AS Title, 
	  Imdb.ContributedTo FOR PATH AS ContributedTo, 
	  Imdb.ContributedTo FOR PATH AS ContributedTo2
WHERE MATCH(SHORTEST_PATH(Person(-(ContributedTo)->Title<-(ContributedTo2)-Person2){1,4}))
 AND Person.PersonId = @personId




 --get second level relations to 'Frank cardillo' using contributions link and shortest path
DECLARE @FromPersonTag VARCHAR(10) = 'nm3901849' --Frank Cardillo with 10 1st level connections
SET  @FrompersonTag = 'nm0000069' -- 'Frank Sinatra' --2393 connections

--get second level relations to 'Frank cardillo' using contributions link and shortest path
DECLARE @ToPersonTag VARCHAR(10) = 'nm3901849' --Frank Cardillo with 10 1st level connections
SET  @TopersonTag = 'nm0000069' -- 'Frank Sinatra' --2393 connections
--SET @TopersonTag = 'nm4203747'
SET @ToPersonTag = 'nm0000102'

DECLARE @FromPersonId INT = (SELECT Person.PersonId FROM Imdb.Person WHERE personTag = @FromPersonTag)
DECLARE @ToPersonId INT = (SELECT Person.PersonId FROM Imdb.Person WHERE personTag = @ToPersonTag);

WITH baseRows AS (
	  --ran 9 hours, killed it, it ended in seconds... but DID NOT fill up tempdb this time
	SELECT CONCAT('(',Person.PrimaryName,')') + 
		   STRING_AGG(CONCAT(Title.Name,'->',Person2.PrimaryName), '->') WITHIN GROUP (GRAPH PATH) AS ConnectedPath, 
		   LAST_VALUE(Person2.PrimaryName) WITHIN GROUP (GRAPH PATH) AS ConnectedToAccountHandle,
		   LAST_VALUE(Person2.personId) WITHIN GROUP (GRAPH PATH) AS ConnectedToPersonId
	FROM  Imdb.Person AS Person, 
		  Imdb.Person FOR PATH AS Person2,
		  Imdb.Title FOR PATH AS Title, 
		  Imdb.ContributedTo FOR PATH AS ContributedTo, 
		  Imdb.ContributedTo FOR PATH AS ContributedTo2
	WHERE MATCH(SHORTEST_PATH(Person(-(ContributedTo)->Title<-(ContributedTo2)-Person2){1,7}))
	 AND Person.PersonId = @FromPersonId)
SELECT *
FROM   BaseRows
WHERE  ConnectedTopersonId = @ToPersonId
OPTION (MAXDOP  1)
GO

