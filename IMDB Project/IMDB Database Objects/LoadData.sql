USE imdb
GO
IF EXISTS (SELECT *
			FROM  sys.objects
			WHERE name = 'EC_ContributedTo')

ALTER TABLE imdb.ContributedTo
	DROP CONSTRAINT EC_ContributedTo;
GO
IF EXISTS (SELECT *
			FROM  sys.objects
			WHERE name = 'EC_WorkedWith')

ALTER TABLE imdb.WorkedWith
	DROP CONSTRAINT EC_WorkedWith;
GO

TRUNCATE TABLE imdb.Title;
TRUNCATE TABLE imdb.Person;
TRUNCATE TABLE imdb.ContributedTo;
TRUNCATE TABLE imdb.WorkedWith;

ALTER TABLE imdb.ContributedTo
	ADD CONSTRAINT EC_ContributedTo CONNECTION (imdb.Person TO Imdb.Title) ON DELETE NO ACTION;
GO
ALTER TABLE imdb.WorkedWith
	ADD CONSTRAINT EC_WorkedWith CONNECTION (Imdb.Person TO Imdb.Person) ON DELETE NO ACTION
GO

DECLARE @TitleMask  varchar(100) = '%'
DECLARE @peopleMask varchar(100) = '%'

INSERT INTO IMDB.person WITH (TABLOCKX) (PersonId, Primaryname,Birthyear) 
SELECT Name.Nconst, Name.PrimaryName, Name.BirthYear
FROM   IMDBStaging.Staging.Name
--WHERE  Name.Nconst LIKE @peopleMask;

INSERT INTO Imdb.Title WITH (TABLOCKX) (TitleId, TitleType, Name, StartYear)
SELECT TConst, TitleType, PrimaryTitle AS Name, TRY_CAST(StartYear AS int)
FROM   IMDBStaging.Staging.BasicDetail

INSERT INTO IMDBInterface.ContributedTo_Person_to_Title WITH (TABLOCKX) (PersonId, TitleId, ContributionType)
SELECT Tconst AS TitleId, CAST(value AS varchar(10)) AS personId, 'Director' AS ContributionType
FROM   IMDBStaging.Staging.Crew
		CROSS APPLY STRING_SPLIT(Directors,',')
WHERE value <> '\N'
  AND  EXISTS (SELECT *
			  FROM   Imdb.Title
			  WHERE  Crew.Tconst = Title.TitleId)
  --AND Crew.Tconst LIKE @TitleMask
  --AND Value LIKE @peopleMask

INSERT INTO IMDBInterface.ContributedTo_Person_to_Title WITH (TABLOCKX) (PersonId, TitleId, ContributionType)
SELECT Tconst AS TitleId, CAST(value AS varchar(10)) AS personId, 'Writer' AS ContributionType
FROM   IMDBStaging.Staging.Crew
		CROSS APPLY STRING_SPLIT(Crew.Writers,',')
WHERE value <> '\N'
  AND  EXISTS (SELECT *
			  FROM   Imdb.Title
			  WHERE  Crew.Tconst = Title.TitleId)
  --AND Crew.Tconst LIKE @TitleMask
  --AND Value LIKE @peopleMask

INSERT INTO IMDBInterface.ContributedTo_Person_to_Title WITH (TABLOCKX) (PersonId, TitleId, ContributionType)
SELECT DISTINCT Principal.Nconst AS PersonId,Principal.Tconst AS TitleId, Principal.Category AS ContributionType
FROM   IMDBStaging.Staging.Principal
WHERE  EXISTS (SELECT *
			  FROM   Imdb.Title
			  WHERE  Principal.Tconst = Title.TitleId)
  --AND Principal.Tconst LIKE @TitleMask
  --AND Principal.Nconst LIKE @peopleMask

INSERT INTO Imdb.WorkedWith WITH (TABLOCKX) ($From_id, $To_id, TitleId)
SELECT Distinct Person.$node_id AS from_id, Person2.$node_id AS to_id, Title.TitleId
FROM  Imdb.Person, 
	  Imdb.ContributedTo AS ContributedTo, Imdb.Title AS Title, 
	  Imdb.ContributedTo AS ContributedTo2, Imdb.Person AS Person2
WHERE MATCH(Person-(ContributedTo)->Title<-(ContributedTo2)-Person2)

SELECT COUNT(*) FROM imdb.Title;
SELECT COUNT(*) FROM imdb.Person;
SELECT COUNT(*) FROM Imdb.ContributedTo;
SELECT COUNT(*) FROM Imdb.WorkedWith;

