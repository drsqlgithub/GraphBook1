USE ImdbRelational
Go
DROP TABLE IF EXISTS #Fetch
GO
/*
SELECT *
FROM  Imdb.Person
WHERE Person.PrimaryName LIKE 'Zsa Zsa Gabor'
*/
DECLARE @FromPersonNumber NVARCHAR(100) = 'nm3901849' --Frank Cardillo
SET @FromPersonNumber = 'nm0000069' --Frank Sinatra
--SET @FromPersonNumber = 'nm0001248'

DECLARE @ToPersonNumber NVARCHAR(100) = 'nm3901403' -- 'Matt Connolly'
SET @ToPersonNumber = 'nm0000102' --Kevin Bacon
SET @ToPersonNumber = 'nm3901849' --Frank Cardillo
DECLARE @MaxLevel INT = 4
DECLARE @msg NVARCHAR(2000)


DECLARE @FromPersonId INT = (SELECT PersonId FROM Imdb.Person WHERE Person.PersonNumber = @FromPersonNumber);
DECLARE @ToPersonId INT = (SELECT PersonId FROM Imdb.Person WHERE Person.PersonNumber = @ToPersonNumber);

CREATE TABLE #Fetch
(
	FromId INT NOT NULL,
	ToId INT NOT NULL,
	level INT NOT NULL,
	HierarchyPath NVARCHAR(4000) NOT NULL,
	IdHierarchyPath VARCHAR(2000) NOT NULL,
	PersonName NVARCHAR(200) NOT NULL,
	PRIMARY key (level, fromId, toId) WITH (IGNORE_DUP_KEY = ON)
)
DECLARE @level INT = 0

INSERT INTO #Fetch
(
    FromId,
    ToId,
    level,
    HierarchyPath,
	IdHierarchyPath,
	PersonName
)
SELECT Person.PersonId,-1, 0, CONCAT('/',Person.PrimaryName,'/'),CONCAT('/',PersonId,'/'), Person.PrimaryName
FROM   imdb.Person
WHERE Person.PersonId = @FromPersonId

WHILE @level <= @MaxLevel - 1
 BEGIN

WITH FromTo AS 
(
SELECT ContributedTo.FromId AS FromId, ContributedTo2.FromId AS ToId, Title.Name
FROM  Imdb.ContributedTo
		JOIN Imdb.ContributedTo AS ContributedTo2
			ON ContributedTo.ToId = ContributedTo2.ToId
		JOIN Imdb.Title
			ON Title.TitleId = ContributedTo.ToId
WHERE ContributedTo.FromId <>  ContributedTo2.FromId			)

INSERT INTO #Fetch
(
    FromId,
    ToId,
    level,
    HierarchyPath,
	IdHierarchyPath,
	PersonName
)
SELECT FromTo.FromId AS FromId, fromTo.FromId AS ToId, @level + 1, CONCAT(#Fetch.HierarchyPath,'-',FromTo.Name, '-',Pname.PrimaryName,'/'), CONCAT(#Fetch.IdHierarchyPath,Pname.PersonId,'/'), PName.PrimaryName
FROM  #Fetch 
		JOIN FromTo
			ON FromTo.ToId = #Fetch.FromId
		JOIN Imdb.Person as PName
			ON PName.PersonId = FromTo.FromId
			  --AND Person.IdHierarchyPath NOT LIKE CONCAT('%/',PName.PersonId,'/%')
WHERE #Fetch.level=@level
  --eliminate persons you have already seen
  AND  Pname.personId NOT IN (SELECT ToId
							   FROM #Fetch
							   WHERE  level <= @level) 
;
IF EXISTS (SELECT *
		   FROM   #Fetch
		   WHERE #Fetch.FromId = @ToPersonId)
	 BREAK

SET @msg = CONCAT('Processing level ',@level,' Complete')
RAISERROR (@msg,10,1) WITH NOWAIT;

SET @level = @level + 1

END

SELECT *
FROM   #Fetch
WHERE #Fetch.FromId = @ToPersonId
ORDER BY #Fetch.HierarchyPath

--SELECT *
--FROM   #Fetch
--ORDER BY #Fetch.HierarchyPath