CREATE OR ALTER  PROCEDURE Imdb.Database$LoadFromStaging
AS
--Needs commenting
SET NOCOUNT ON;

ALTER TABLE Imdb.ContributedTo DROP CONSTRAINT IF EXISTS EC_ContributedTo;

ALTER TABLE [Imdb].[WorkedWith] DROP CONSTRAINT IF EXISTS EC_WorkedWith;
ALTER TABLE [Imdb].[WorkedWith] DROP CONSTRAINT IF EXISTS FKWorkedWith$Ref$Imdb_Title$ForTitleId

ALTER TABLE Imdb.TitleEpisode DROP CONSTRAINT IF EXISTS FKTitleEpisode$Ref$Title
ALTER TABLE RelationalEdge.ContributedTo DROP CONSTRAINT IF EXISTS FKConstributedTo$Ref$Imdb_Person;
ALTER TABLE RelationalEdge.ContributedTo DROP CONSTRAINT IF EXISTS FKConstributedTo$Ref$Imdb_Title

ALTER TABLE RelationalEdge.WorkedWith  DROP CONSTRAINT IF EXISTS FKWorkedWith$Ref$Imdb_Person$ForFromPersonId
ALTER TABLE RelationalEdge.WorkedWith  DROP CONSTRAINT IF EXISTS FKWorkedWith$Ref$Imdb_Person$ForToPersonId
ALTER TABLE RelationalEdge.WorkedWith  DROP CONSTRAINT IF EXISTS FKWorkedWith$Ref$Imdb_Title$ForTitleId



TRUNCATE TABLE imdb.Title;
TRUNCATE TABLE imdb.Person;
TRUNCATE TABLE imdb.ContributedTo;
TRUNCATE TABLE imdb.WorkedWith;
TRUNCATE TABLE RelationalEdge.WorkedWith;
TRUNCATE TABLE RelationalEdge.ContributedTo;


DECLARE @TitleMask  varchar(100) = '%'
DECLARE @peopleMask varchar(100) = '%'

INSERT INTO IMDB.person WITH (TABLOCKX) (PersonTag, Primaryname,Birthyear) 
SELECT Name.Nconst, Name.PrimaryName, Name.BirthYear
FROM   IMDBStaging.Staging.Name
--WHERE  Name.Nconst LIKE @peopleMask;

INSERT INTO Imdb.Title WITH (TABLOCKX) (TitleTag, TitleType, Name, StartYear)
SELECT TConst, TitleType, PrimaryTitle AS Name, TRY_CAST(StartYear AS int)
FROM   IMDBStaging.Staging.BasicDetail

INSERT INTO IMDBInterface.ContributedTo_Person_to_Title WITH (TABLOCKX) (PersonTag, TitleTag, ContributionType)
SELECT Tconst AS TitleTag, CAST(value AS varchar(10)) AS personTag, 'Director' AS ContributionType
FROM   IMDBStaging.Staging.Crew
		CROSS APPLY STRING_SPLIT(Directors,',')
WHERE value <> '\N'
  AND  EXISTS (SELECT *
			  FROM   Imdb.Title
			  WHERE  Crew.Tconst = Title.TitleTag)
  --AND Crew.Tconst LIKE @TitleMask
  --AND Value LIKE @peopleMask

INSERT INTO IMDBInterface.ContributedTo_Person_to_Title WITH (TABLOCKX) (PersonTag, TitleTag, ContributionType)
SELECT Tconst AS TitleTag, CAST(value AS varchar(10)) AS personTag, 'Writer' AS ContributionType
FROM   IMDBStaging.Staging.Crew
		CROSS APPLY STRING_SPLIT(Crew.Writers,',')
WHERE value <> '\N'
  AND  EXISTS (SELECT *
			  FROM   Imdb.Title
			  WHERE  Crew.Tconst = Title.TitleTag)
  --AND Crew.Tconst LIKE @TitleMask
  --AND Value LIKE @peopleMask

INSERT INTO IMDBInterface.ContributedTo_Person_to_Title WITH (TABLOCKX) (PersonTag, TitleTag, ContributionType)
SELECT DISTINCT Principal.Nconst AS PersonTag,Principal.Tconst AS TitleTag, Principal.Category AS ContributionType
FROM   IMDBStaging.Staging.Principal
WHERE  EXISTS (SELECT *
			  FROM   Imdb.Title
			  WHERE  Principal.Tconst = Title.TitleTag)
  --AND Principal.Tconst LIKE @TitleMask
  --AND Principal.Nconst LIKE @peopleMask

INSERT INTO Imdb.WorkedWith WITH (TABLOCKX) ($From_id, $To_id, TitleId)
SELECT Distinct  Person.$node_id AS from_id, Person2.$node_id AS to_id, Title.TitleId
FROM  Imdb.Person, 
	  Imdb.ContributedTo AS ContributedTo, Imdb.Title AS Title, 
	  Imdb.ContributedTo AS ContributedTo2, Imdb.Person AS Person2
WHERE MATCH(Person-(ContributedTo)->Title<-(ContributedTo2)-Person2)


INSERT INTO RelationalEdge.ContributedTo
(
    FromPersonId,
    ToTitleId,
    ContributionType
)
SELECT personId AS FromPersonId, Title.TitleId AS ToTitleId, ContributedTo.ContributionType
FROM   Imdb.ContributedTo
		JOIN Imdb.Person
			ON ContributedTo.$from_id = Person.$node_id
		JOIN Imdb.Title
			ON ContributedTo.$to_id = Title.$node_id


INSERT INTO RelationalEdge.WorkedWith
(
    FromPersonId,
    ToPersonId,
    TitleId
)
SELECT FromPerson.PersonId, ToPerson.PersonId, WorkedWith.TitleId
FROM   imdb.workedWith
		JOIN Imdb.Person AS FromPerson
			ON FromPerson.$node_id = WorkedWith.$from_id
		JOIN Imdb.Person AS ToPerson
			ON ToPerson.$node_id = WorkedWith.$To_id




ALTER TABLE Imdb.TitleEpisode ADD CONSTRAINT FKTitleEpisode$Ref$Title FOREIGN KEY (TitleId) REFERENCES Imdb.Title(TitleId);

ALTER TABLE [Imdb].[ContributedTo] ADD CONSTRAINT EC_ContributedTo CONNECTION (imdb.Person TO Imdb.Title) ON DELETE NO ACTION
ALTER TABLE [Imdb].[WorkedWith] ADD CONSTRAINT EC_WorkedWith CONNECTION (Imdb.Person TO Imdb.Person) ON DELETE NO ACTION

ALTER TABLE [Imdb].[WorkedWith] ADD CONSTRAINT FKWorkedWith$Ref$Imdb_Title$ForTitleId FOREIGN KEY (TitleId) REFERENCES Imdb.Title (TitleId)

ALTER TABLE RelationalEdge.ContributedTo ADD CONSTRAINT FKConstributedTo$Ref$Imdb_Person FOREIGN KEY (FromPersonId) REFERENCES Imdb.Person (PersonId)
ALTER TABLE RelationalEdge.ContributedTo ADD CONSTRAINT FKConstributedTo$Ref$Imdb_Title FOREIGN KEY (ToTitleId) REFERENCES Imdb.Title (TitleId)

ALTER TABLE RelationalEdge.WorkedWith  ADD CONSTRAINT FKWorkedWith$Ref$Imdb_Person$ForFromPersonId FOREIGN KEY(FromPersonId)  REFERENCES Imdb.Person (PersonId);
ALTER TABLE RelationalEdge.WorkedWith  ADD CONSTRAINT FKWorkedWith$Ref$Imdb_Person$ForToPersonId FOREIGN KEY(ToPersonId) REFERENCES Imdb.Person (PersonId);
ALTER TABLE RelationalEdge.WorkedWith  ADD CONSTRAINT FKWorkedWith$Ref$Imdb_Title$ForTitleId FOREIGN KEY(TitleId) REFERENCES Imdb.Title (TitleId);


SELECT COUNT(*) AS [Imdb.Title] FROM imdb.Title;
SELECT COUNT(*) AS [Imdb.Person] FROM imdb.Person;
SELECT COUNT(*) AS [Imdb.ContributedTo] FROM Imdb.ContributedTo;
SELECT COUNT(*) AS [Imdb.WorkedWith] FROM Imdb.WorkedWith;
SELECT COUNT(*) AS [RelationalEdge.ContributedTo] FROM RelationalEdge.ContributedTo;
SELECT COUNT(*) AS [RelationalEdge.WorkedWith] FROM RelationalEdge.WorkedWith;

