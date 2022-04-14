USE Imdb
Go
DROP TABLE IF EXISTS #Fetch
GO
/*
SELECT *
FROM  Imdb.Person
WHERE Person.PrimaryName LIKE 'Zsa Zsa Gabor'
*/
 --get second level relations to 'Frank cardillo' using contributions link and shortest path
DECLARE @FromPersonTag VARCHAR(10) = 'nm3901849' --Frank Cardillo with 10 1st level connections
--SET  @FrompersonTag = 'nm0000069' -- 'Frank Sinatra' --2393 connections

--get second level relations to 'Frank cardillo' using contributions link and shortest path
DECLARE @ToPersonTag VARCHAR(10) = 'nm3901849' --Frank Cardillo with 10 1st level connections
SET @ToPersonTag = 'nm3901403' -- 1 hop
SET @TopersonTag = 'nm4203747' -- 2 hops
SET @ToPersonTag = 'nm0000756' -- 3 hops
SET @ToPersonTag = 'nm0000002' -- 4 hops


DECLARE @MaxLevel INT = 4
DECLARE @msg NVARCHAR(2000)


DECLARE @FromPersonId INT = (SELECT PersonId FROM Imdb.Person WHERE Person.personTag = @FromPersonTag);
DECLARE @ToPersonId INT = (SELECT PersonId FROM Imdb.Person WHERE Person.PersonTag = @ToPersonTag);

CREATE TABLE #Fetch
(
	FromPersonId INT NOT NULL,
	TopersonId INT NOT NULL,
	level INT NOT NULL,
	HierarchyPath NVARCHAR(4000) NOT NULL,
	IdHierarchyPath VARCHAR(2000) NOT NULL,
	PersonName NVARCHAR(200) NOT NULL,
	PRIMARY key (toPersonId) WITH (IGNORE_DUP_KEY = ON) --shortest path, only need one
)
DECLARE @level INT = 0

INSERT INTO #Fetch
(
    FromPersonId,
    ToPersonId,
    level,
    HierarchyPath,
	IdHierarchyPath,
	PersonName
)
SELECT Person.PersonId,Person.PersonId, 0, CONCAT('(',Person.PrimaryName, ')'),CONCAT('/',PersonTag,'/'), Person.PrimaryName
FROM   imdb.Person
WHERE Person.PersonId = @FromPersonId

WHILE @level <= @MaxLevel - 1
 BEGIN

WITH FromTo AS 
(

SELECT Person.PersonId AS FromPersonId, Person2.PersonId AS ToPersonId, Title.Name AS TitleName
FROM  Imdb.Person, 
	  Imdb.ContributedTo AS ContributedTo, Imdb.Title AS Title, 
	  Imdb.ContributedTo AS ContributedTo2, Imdb.Person AS Person2
WHERE MATCH(Person-(ContributedTo)->Title<-(ContributedTo2)-Person2)
  AND Person.PersonId <> Person2.personId)

INSERT INTO #Fetch
(
    FromPersonId,
    ToPersonId,
    level,
    HierarchyPath,
	IdHierarchyPath,
	PersonName
)
SELECT FromTo.ToPersonId AS FrompersonId, fromTo.FromPersonId AS ToPersonId, @level + 1, CONCAT(#Fetch.HierarchyPath,' <',FromTo.TitleName, '> (',Pname.PrimaryName,')'), CONCAT(#Fetch.IdHierarchyPath,Pname.PersonTag,'/'), PName.PrimaryName
FROM  #Fetch 
		JOIN FromTo
			ON FromTo.ToPersonId = #Fetch.ToPersonId
		JOIN Imdb.Person AS PName
			ON PName.PersonId = FromTo.FromPersonId
			  --AND Person.IdHierarchyPath NOT LIKE CONCAT('%/',PName.PersonId,'/%')
WHERE #Fetch.level=@level
  --eliminate persons you have already seen
  --AND  Pname.personId NOT IN (SELECT TopersonId
		--					   FROM #Fetch
		--					   WHERE  level <= @level) 
;
IF EXISTS (SELECT *
		   FROM   #Fetch
		   WHERE #Fetch.ToPersonId = @ToPersonId)
	 BREAK

SET @msg = CONCAT('Processing level ',@level,' Complete')
RAISERROR (@msg,10,1) WITH NOWAIT;

SET @level = @level + 1

END

SELECT  #Fetch.level,
       #Fetch.HierarchyPath,
       #Fetch.IdHierarchyPath,
       #Fetch.PersonName
FROM   #Fetch
WHERE #Fetch.ToPersonId = @ToPersonId
ORDER BY #Fetch.HierarchyPath

--SELECT *
--FROM   #Fetch
--ORDER BY #Fetch.HierarchyPath