DROP TABLE IF EXISTS imdb.ContributedTo
GO
/****** Object:  Table [Imdb].[ContributedTo]    Script Date: 3/3/2021 6:25:30 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Imdb].[ContributedTo](
	FromId INT NOT null,
	ToId INT NOT null,
	[ContributionType] [NVARCHAR](100) NOT NULL,
	
 CONSTRAINT [PKContributedTo] PRIMARY KEY
(
	FromId ,
	ToId,
	[ContributionType] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
)
WITH (DATA_COMPRESSION = PAGE)
GO

CREATE INDEX ToFrom ON Imdb.ContributedTo (ToId, FromId) include (ContributionType)
GO

CREATE OR ALTER VIEW IMDBInterface.ContributedTo_Person_to_Title
AS
SELECT Person.PersonNumber, Title.TitleNumber, ContributedTo.ContributionType
FROM   imdb.Person
		JOIN imdb.ContributedTo
			ON ContributedTo.FromId = ContributedTo.FromId
		JOIN Imdb.Title
			ON ContributedTo.ToId = Title.TitleId
GO

CREATE OR ALTER TRIGGER IMDBInterface.ContributedTo_Person_to_Title$InsertTrigger
ON IMDBInterface.ContributedTo_Person_to_Title
INSTEAD OF INSERT
AS
SET NOCOUNT ON;
--note, to keep it simple, only including the insert statement. Could 
--use more error handling for a production version of the trigger
 BEGIN 
  INSERT INTO Imdb.ContributedTo(FromId, ToId,ContributionType)
  SELECT Person.PersonId, Title.TitleId, Inserted.ContributionType
  FROM Inserted
       JOIN Imdb.Person
           ON Person.PersonNumber = inserted.PersonNumber
       JOIN Imdb.Title
           ON Title.TitleNumber = inserted.TitleNumber
 END;
GO