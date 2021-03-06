USE IMDB
GO
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'imdb')
	EXEC ('CREATE SCHEMA Imdb');
GO
--DROP TABLE IF EXISTS Imdb.Person;
GO
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Imdb].[Person](
	PersonId  int NOT NULL IDENTITY (1,1),
	[PersonTag] [varchar](10) NOT NULL,
	[PrimaryName] [nvarchar](150) NOT NULL,
	[Birthyear] [nvarchar](500) NULL,
 CONSTRAINT [PKPerson] PRIMARY KEY CLUSTERED 
(
	[PersonId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
)
AS NODE  WITH (DATA_COMPRESSION = PAGE)
GO
CREATE  NONCLUSTERED INDEX PrimaryName ON [Imdb].[Person] ([PrimaryName])
CREATE UNIQUE NONCLUSTERED INDEX PersonTag ON [Imdb].[Person] ([PersonTag])


