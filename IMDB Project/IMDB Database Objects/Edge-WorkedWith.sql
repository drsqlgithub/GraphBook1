DROP TABLE IF EXISTS imdb.WorkedWith
GO

/****** Object:  Table [Imdb].[WorkedWith]    Script Date: 3/3/2021 6:25:30 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Imdb].[WorkedWith](
	[TitleId] [varchar](10) NOT NULL
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


CREATE OR ALTER VIEW IMDBInterface.WorkedWith_Person_to_Person
AS
SELECT Person.PersonId AS PersonId, 
       WorkedWithPerson.PersonId AS WorkedWithPersonId,
	   TitleId
FROM Imdb.Person,
     Imdb.WorkedWith,
     Imdb.Person AS WorkedWithPerson
WHERE MATCH(Person-(WorkedWith)->WorkedWithPerson);
GO

CREATE OR ALTER TRIGGER IMDBInterface.WorkedWith_Person_to_Person$InsertTrigger
ON IMDBInterface.WorkedWith_Person_to_Person
INSTEAD OF INSERT
AS
SET NOCOUNT ON;
--note, to keep it simple, only including the insert statement. Could 
--use more error handling for a production version of the trigger
 BEGIN 
  INSERT INTO Imdb.WorkedWith($From_id, $To_id)
  SELECT Person.$node_id, WorkedWithPerson.$node_id
  FROM Inserted
       JOIN Imdb.Person
           ON Person.PersonId = inserted.PersonId
       JOIN Imdb.Person AS WorkedWithPerson 
           ON WorkedWithPerson.PersonId = inserted.WorkedWithPersonId
 END;

