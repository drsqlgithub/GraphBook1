USE ImdbRelational
GO
DROP TABLE IF EXISTS Imdb.Person;
GO
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
DROP TABLE IF EXISTS Imdb.Person
GO
CREATE TABLE [Imdb].[Person](
	PersonId INT IDENTITY CONSTRAINT PKPerson PRIMARY KEY,
	[PersonNumber] [VARCHAR](10) NOT NULL ,
	[PrimaryName] [nvarchar](150) NOT NULL,
	[Birthyear] [nvarchar](500) NULL,
 CONSTRAINT [AKPerson] UNIQUE
(
	[PersonNumber] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
)
  WITH (DATA_COMPRESSION = PAGE)
GO
CREATE NONCLUSTERED INDEX PrimaryName ON [Imdb].[Person] ([PrimaryName])
