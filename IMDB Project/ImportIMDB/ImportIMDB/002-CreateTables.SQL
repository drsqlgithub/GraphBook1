USE [IMDBStaging]
GO

/****** Object:  Table [dbo].[OLE DB Destination]    Script Date: 7/19/2020 11:23:44 PM ******/
SET ANSI_NULLS ON
GO

DROP TABLE IF EXISTS Staging.Name, Staging.Principal, Staging.Episode, Staging.Crew, Staging.BasicDetail,Staging.AlsoKnownAs,Staging.Rating;
DROP SCHEMA IF EXISTS Staging;
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE SCHEMA Staging;
GO
CREATE TABLE [Staging].[Name](
	[Nconst] nvarchar(10) NOT NULL PRIMARY KEY,
	[PrimaryName] [nvarchar](1000) NULL,
	[BirthYear] [nvarchar](1000) NULL,
	[DeathYear] [nvarchar](1000) NULL,
	[PrimaryProfession] [nvarchar](1000) NULL,
	[KnownForTitles] [nvarchar](1000) NULL
) WITH (DATA_COMPRESSION = PAGE)
GO

CREATE TABLE [Staging].Principal (
    [Nconst] nvarchar(10),
    [Tconst] nvarchar(10),
    [Ordering] nvarchar(10),
    [Category] nvarchar(1000),
    [Job] nvarchar(1000),
    [Characters] nvarchar(1000),
	PRIMARY KEY (Nconst, Tconst, Ordering)
)WITH (DATA_COMPRESSION = PAGE)

CREATE TABLE [Staging].Episode (
    [Tconst] nvarchar(10)  PRIMARY KEY,
    [ParentTconst] nvarchar(10),
    [SeasonNumber] nvarchar(50),
    [EpisodeNumber] nvarchar(50)
)WITH (DATA_COMPRESSION = PAGE)

CREATE TABLE [Staging].Crew (
    [Tconst] nvarchar(10)  PRIMARY KEY,
    [Directors] nvarchar(max),
    [Writers] nvarchar(max)
) WITH (DATA_COMPRESSION = PAGE)

CREATE TABLE Staging.BasicDetail (
    [Tconst] nvarchar(10)  PRIMARY KEY,
    [TitleType] nvarchar(1000),
    [PrimaryTitle] nvarchar(1000),
    [OriginalTitle] nvarchar(1000),
    [IsAdult] nvarchar(1000),
    [StartYear] nvarchar(1000),
    [EndYear] nvarchar(1000),
    [RuntimeMinutes] nvarchar(1000),
    [Genres] nvarchar(1000)
)WITH (DATA_COMPRESSION = PAGE)

CREATE TABLE Staging.AlsoKnownAs (
    [TitleId] nvarchar(10)  ,
    [Ordering] nvarchar(10),
    [Title] nvarchar(1000),
    [Region] nvarchar(1000),
    [Language] nvarchar(1000),
    [Types] nvarchar(1000),
    [Attributes] nvarchar(1000),
    [IsOriginalTitle] nvarchar(1000),
	PRIMARY KEY (TitleId, Ordering)
)WITH (DATA_COMPRESSION = PAGE)

CREATE TABLE Staging.Rating(
    [Tconst] nvarchar(10)  PRIMARY KEY,
    [AverageRating] nvarchar(10),
    [NumVotes] nvarchar(50)
)WITH (DATA_COMPRESSION = PAGE)

