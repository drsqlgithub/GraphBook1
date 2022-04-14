--SELECT TOP 100 * FROM Imdb.Person
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
SET  @TopersonTag = 'nm0000069' -- 'Frank Sinatra' --2393 connections
SET @TopersonTag = 'nm4203747'


DECLARE @MaxLevel INT = 2
DECLARE @msg NVARCHAR(2000)


DECLARE @FromPersonNodeId NVARCHAR(2000) = (SELECT $node_id FROM Imdb.Person WHERE Person.PersonTag = @FromPersonTag);
DECLARE @ToPersonNodeId nvarchar(2000) = (SELECT $node_id FROM Imdb.Person WHERE Person.PersonTag = @ToPersonTag);

--SELECT @FromPersonNodeId, @ToPersonNodeId

CREATE TABLE #Fetch
(
	FromNodeId NVARCHAR(2000) NOT NULL,
	ToNodeId NVARCHAR(2000) NOT NULL,
	level INT NOT NULL,
	HierarchyPath NVARCHAR(4000) NOT NULL,
	IdHierarchyPath VARCHAR(2000) NOT NULL,
	PersonName NVARCHAR(200) NOT NULL,
--	PRIMARY key (level, FromNodeId, ToNodeId) WITH (IGNORE_DUP_KEY = ON),
	PRIMARY key (ToNodeId) WITH (IGNORE_DUP_KEY = ON) --since shortest path, we only want one item per node Id
)
DECLARE @level INT = 0

INSERT INTO #Fetch
(
    FromNodeId,
    ToNodeId,
    level,
    HierarchyPath,
	IdHierarchyPath,
	PersonName
)
SELECT Person.$node_id, Person.$node_id, 0, CONCAT('(',Person.PrimaryName, ')'),CONCAT('/',PersonTag,'/'), Person.PrimaryName
FROM   imdb.Person
WHERE Person.$node_id = @FromPersonNodeId

WHILE @level <= @MaxLevel - 1
 BEGIN

WITH FromTo AS 
(
SELECT ContributedTo.$from_id AS FromNodeId, ContributedTo2.$from_id AS ToNodeId, Title.Name AS TitleName
FROM  Imdb.ContributedTo
		JOIN Imdb.ContributedTo AS ContributedTo2
			ON ContributedTo.$to_id = ContributedTo2.$to_id --Contributed TO the same title
		JOIN Imdb.Title
			ON Title.$node_id = ContributedTo.$to_id
WHERE ContributedTo.$from_id <>  ContributedTo2.$From_Id			
)

INSERT INTO #Fetch
(
    FromNodeId,
    ToNodeId,
    level,
    HierarchyPath,
	IdHierarchyPath,
	PersonName
)
SELECT FromTo.ToNodeId AS FromNodeId, fromTo.FromNodeId AS ToId, @level + 1,CONCAT(#Fetch.HierarchyPath,' <',FromTo.TitleName, '> (',Pname.PrimaryName,')'), CONCAT(#Fetch.IdHierarchyPath,Pname.PersonTag,'/'), PName.PrimaryName
FROM  #Fetch 
		JOIN FromTo
			ON FromTo.ToNodeId = #Fetch.ToNodeId
		JOIN Imdb.Person AS PName
			ON PName.$node_id = FromTo.FromNodeId
			  
WHERE #Fetch.level=@level
  ----eliminate persons you have already seen
  --AND  Pname.$node_id NOT IN (SELECT ToNodeId
		--					   FROM #Fetch
		--					   WHERE  level <= @level) 
;
IF EXISTS (SELECT *
		   FROM   #Fetch
		   WHERE #Fetch.ToNodeId = @ToPersonNodeId)
 BEGIN
 

	 BREAK
	END;



SET @msg = CONCAT('Processing level ',@level,' Complete')
RAISERROR (@msg,10,1) WITH NOWAIT;

SET @level = @level + 1

END

SELECT #Fetch.level,
       #Fetch.HierarchyPath,
       #Fetch.IdHierarchyPath,
       #Fetch.PersonName
FROM   #Fetch
WHERE #Fetch.ToNodeId = @ToPersonNodeId
ORDER BY #Fetch.HierarchyPath

	--SELECT *
	--FROM   #Fetch
	--ORDER BY #Fetch.HierarchyPath