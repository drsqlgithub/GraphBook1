USE Imdb
GO
--DROP TABLE IF EXISTS imdb.WorkedWith
GO

/****** Object:  Table [Imdb].[WorkedWith]    Script Date: 3/3/2021 6:25:30 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Imdb].[WorkedWith](
	[TitleId] INT NOT NULL CONSTRAINT FKWorkedWith$Ref$Imdb_Title$ForTitleId REFERENCES Imdb.Title (TitleId)
	,CONSTRAINT EC_WorkedWith CONNECTION (Imdb.Person TO Imdb.Person) ON DELETE NO ACTION
 ,CONSTRAINT [AKWorkedWith] UNIQUE NONCLUSTERED 
(
	$from_id,
	$to_id,
	[TitleId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
)
AS EDGE  WITH (DATA_COMPRESSION = PAGE)
GO

CREATE  INDEX toFrom ON imdb.workedWith ($to_id, $from_id);
GO

/****** Object:  Index [FromTo]    Script Date: 4/11/2022 8:39:31 PM ******/
CREATE NONCLUSTERED INDEX [FromTo] ON [Imdb].[WorkedWith]
(
	$from_id,
	$to_id
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO



CREATE OR ALTER VIEW IMDBInterface.WorkedWith_Person_to_Person
AS
SELECT Person.PersonTag AS PersonTag, 
       WorkedWithPerson.PersonTag AS WorkedWithPersonTag,
	   Title.TitleTag
FROM Imdb.Person,
     Imdb.WorkedWith,
     Imdb.Person AS WorkedWithPerson,
	 Imdb.Title
WHERE MATCH(Person-(WorkedWith)->WorkedWithPerson)
  AND Title.TitleId = Workedwith.TitleId;
GO

CREATE OR ALTER TRIGGER IMDBInterface.WorkedWith_Person_to_Person$InsertTrigger
ON IMDBInterface.WorkedWith_Person_to_Person
INSTEAD OF INSERT
AS
SET NOCOUNT ON;
--note, to keep it simple, only including the insert statement. Could 
--use more error handling for a production version of the trigger
 BEGIN 
  INSERT INTO Imdb.WorkedWith($From_id, $To_id, TitleId)
  SELECT Person.$node_id, WorkedWithPerson.$node_id,Title.TitleId
  FROM Inserted
       JOIN Imdb.Person
           ON Person.PersonTag = inserted.PersonTag
       JOIN Imdb.Person AS WorkedWithPerson 
           ON WorkedWithPerson.PersonTag = inserted.WorkedWithPersonTag
		JOIN Imdb.Title
			ON Title.TitleTag = Inserted.TitleTag
 END;

