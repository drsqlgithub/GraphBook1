--DROP TABLE IF EXISTS imdb.ContributedTo
GO
/****** Object:  Table [Imdb].[ContributedTo]    Script Date: 3/3/2021 6:25:30 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Imdb].[ContributedTo](
	[ContributionType] [nvarchar](100) NULL,
	CONSTRAINT EC_ContributedTo CONNECTION (imdb.Person TO Imdb.Title) ON DELETE NO ACTION,
 CONSTRAINT [AKContributedTo] UNIQUE NONCLUSTERED 
(
	$from_id,
	$to_id,
	[ContributionType] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
)
AS EDGE  WITH (DATA_COMPRESSION = PAGE)
GO

CREATE INDEX ToFrom ON Imdb.ContributedTo ($to_id, $from_id) include (ContributionType)
GO

CREATE OR ALTER VIEW IMDBInterface.ContributedTo_Person_to_Title
AS
SELECT Person.PersonTag AS PersonTag, 
	   TitleTag,
	   ContributionType
FROM Imdb.Person,
     Imdb.ContributedTo,
     Imdb.Title 
WHERE MATCH(Person-(ContributedTo)->Title);
GO

CREATE OR ALTER TRIGGER IMDBInterface.ContributedTo_Person_to_Title$InsertTrigger
ON IMDBInterface.ContributedTo_Person_to_Title
INSTEAD OF INSERT
AS
SET NOCOUNT ON;
--note, to keep it simple, only including the insert statement. Could 
--use more error handling for a production version of the trigger
 BEGIN 
  INSERT INTO Imdb.ContributedTo($From_id, $To_id,ContributionType)
  SELECT Person.$node_id, Title.$node_id, Inserted.ContributionType
  FROM Inserted
       JOIN Imdb.Person
           ON Person.PersonTag = inserted.PersonTag
       JOIN Imdb.Title
           ON Title.TitleTag = inserted.TitleTag
 END;
GO

