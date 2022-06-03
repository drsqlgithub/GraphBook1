DROP TABLE IF EXISTS imdb.ContributedTo
GO
/****** Object:  Table [Imdb].[ContributedTo]    Script Date: 3/3/2021 6:25:30 PM ******/
SET ANSI_NULLS ON
GO
USE Imdb
go
SET QUOTED_IDENTIFIER ON
GO
--DROP TABLE [RelationalEdge].[ContributedTo]
CREATE TABLE [RelationalEdge].[ContributedTo](
	FromPersonId INT NOT NULL CONSTRAINT FKConstributedTo$Ref$Imdb_Person REFERENCES Imdb.Person (PersonId),
	ToTitleId INT NOT NULL CONSTRAINT FKConstributedTo$Ref$Imdb_Title REFERENCES Imdb.Title (TitleId),
	[ContributionType] [NVARCHAR](100) NULL,
 CONSTRAINT [AKContributedTo] UNIQUE NONCLUSTERED 
(
	FromPersonId,
	ToTitleId,
	ContributionType ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
)
WITH (DATA_COMPRESSION = PAGE)
GO

CREATE INDEX ToFrom ON RelationalEdge.ContributedTo (ToTitleId, FromPersonId) include (ContributionType)
GO

--CREATE OR ALTER VIEW IMDBInterface.ContributedTo_Person_to_Title
--AS
--SELECT Person.PersonId AS PersonId, 
--	   TitleId,
--	   ContributionType
--FROM Imdb.Person,
--     Imdb.ContributedTo,
--     Imdb.Title 
--WHERE MATCH(Person-(ContributedTo)->Title);
--GO

--CREATE OR ALTER TRIGGER IMDBInterface.ContributedTo_Person_to_Title$InsertTrigger
--ON IMDBInterface.ContributedTo_Person_to_Title
--INSTEAD OF INSERT
--AS
--SET NOCOUNT ON;
----note, to keep it simple, only including the insert statement. Could 
----use more error handling for a production version of the trigger
-- BEGIN 
--  INSERT INTO Imdb.ContributedTo($From_id, $To_id,ContributionType)
--  SELECT Person.$node_id, Title.$node_id, Inserted.ContributionType
--  FROM Inserted
--       JOIN Imdb.Person
--           ON Person.PersonId = inserted.PersonId
--       JOIN Imdb.Title
--           ON Title.TitleId = inserted.TitleId
-- END;
--GO

