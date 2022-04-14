DROP VIEW IF EXISTS Transformed.Person
DROP VIEW IF EXISTS PersonPrimaryProfession
DROP VIEW IF EXISTS Transformed.PersonKnownForTitle
DROP VIEW IF EXISTS Transformed.Title
DROP VIEW IF EXISTS Transformed.TitleGenre
DROP VIEW IF EXISTS Transformed.TitleAssociation
DROP VIEW IF EXISTS Transformed.Director
DROP VIEW IF EXISTS Transformed.Writer
DROP VIEW IF EXISTS Transformed.PersonPrimaryProfession
DROP VIEW IF EXISTS Transformed.Episode
GO
DROP SCHEMA IF EXISTS Transformed;
GO
CREATE SCHEMA Transformed;
GO
----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Person
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

CREATE VIEW Transformed.Person
AS
SELECT CAST(TRIM(nconst) AS varchar(10)) AS PersonId,
       CAST(TRIM(primaryName) AS nvarchar(150)) AS PrimaryName,
	   CASE WHEN BirthYear <> '\N' THEN CAST(BirthYear AS int) END AS BirthYear
FROM   Staging.Name
GO
CREATE VIEW Transformed.PersonPrimaryProfession
AS
SELECT CAST(TRIM(nconst) AS varchar(10)) AS PersonId,
	   CAST(PrimaryProfession.value AS varchar(100)) AS ProfessioinName
FROM   Staging.Name
		 CROSS APPLY STRING_SPLIT(PrimaryProfession,',') AS PrimaryProfession
GO
CREATE VIEW Transformed.PersonKnownForTitle
AS
SELECT CAST(TRIM(nconst) AS varchar(10)) AS PersonId,
	   CAST(KnownForTitle.value AS varchar(100)) AS TitleId
FROM   Staging.Name
		 CROSS APPLY STRING_SPLIT([KnownForTitles],',') AS KnownForTitle
GO

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Title
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

CREATE VIEW Transformed.Title
AS
SELECT CAST(TRIM(Tconst) AS varchar(10)) AS TitleId,
	   CAST(TitleType AS varchar(20)) AS TitleType,
	   CAST(PrimaryTitle AS nvarchar(500)) AS Name,
	   CAST(StartYear AS varchar(4)) AS StartYear
FROM   Staging.BasicDetail;
GO
CREATE VIEW Transformed.TitleGenre
AS
SELECT CAST(TRIM(Tconst) AS varchar(10)) AS TitleId,
	   CAST(Genres.value AS varchar(100)) AS Genre
FROM   Staging.BasicDetail
		 CROSS APPLY STRING_SPLIT([genres],',') AS Genres
WHERE  Genres.value <> '\N'
GO

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Actors
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

CREATE VIEW Transformed.TitleAssociation
AS
SELECT CAST(TRIM(nconst) AS varchar(10)) AS PersonId,
	   CAST(TRIM(Tconst) AS varchar(10)) AS TitleId,
	   Ordering,
	   Category AS AssociationRole
FROM   Staging.Principal
GO
----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Crew
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------
CREATE VIEW Transformed.Director
AS
SELECT CAST(TRIM(Directors.value) AS varchar(10)) AS PersonId,
	   CAST(TRIM(tconst) AS varchar(10)) AS TitleId,
	   N'Director' AS AssociationRole
FROM Staging.Crew
	 CROSS APPLY STRING_SPLIT([Directors],',') AS Directors
WHERE Directors.Value <> '\N'
GO
CREATE VIEW Transformed.Writer
AS
SELECT CAST(TRIM(Writers.value) AS varchar(10)) AS PersonId,
	   CAST(TRIM(tconst) AS varchar(10)) AS TitleId,
	   N'Writer' AS AssociationRole
FROM Staging.Crew
	 CROSS APPLY STRING_SPLIT(Writers,',') AS Writers
WHERE Writers.Value <> '\N'
GO

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Episode
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------
CREATE VIEW Transformed.Episode
AS
SELECT CAST(TRIM(tconst) AS varchar(10)) AS TitleId,
       CAST(TRIM(tconst) AS varchar(10)) AS PartOfTitleId,
	   CASE WHEN seasonNumber = '\N' THEN 1 ELSE
			CAST(SeasonNumber AS int) END AS SeasonNumber,
	   CASE WHEN EpisodeNumber = '\N' THEN 1 ELSE
			CAST(EpisodeNumber AS int) END AS EpisodeNumber
FROM Staging.Episode
GO