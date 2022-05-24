--In this chapter I will be expanding on chapter 3 code, altering the database we created. 
--

USE TestGraph
GO

--Making data entry more natural

--interface to make the view easier to view

IF SCHEMA_ID('Network_UI') IS NULL 
	EXEC ('CREATE SCHEMA Network_UI')
GO

CREATE OR ALTER VIEW Network_UI.Follows
AS
SELECT Person.PersonId AS PersonId,
		FollowedPerson.PersonId AS FollowsPersonId, 
       Follows.Value AS Value
FROM Network.Person,
     Network.Follows,
     Network.Person AS FollowedPerson
WHERE MATCH(Person-(Follows)->FollowedPerson);
GO
SELECT *
FROM  Network_UI.Follows
GO


CREATE OR ALTER TRIGGER Network_UI.Follows$InsteadOfInsertTrigger
ON Network_UI.Follows
INSTEAD OF INSERT
AS
SET NOCOUNT ON;
 --If you add more code, you should add error handling code.
 BEGIN 
  INSERT INTO Network.Follows($from_id, $to_id, Value)
  SELECT Person.$node_id, FollowedPerson.$node_id, 
		inserted.Value
  FROM Inserted
       JOIN Network.Person
           ON Person.PersonId = Inserted.PersonId
       JOIN Network.Person AS FollowedPerson
           ON FollowedPerson.PersonId = Inserted.FollowsPersonId
 END;
GO

SELECT Person.Name, FollowedPerson.Name AS FollowedPerson
FROM   Network_UI.Follows
		JOIN Network.Person
			ON Person.PersonId = Follows.PersonId
		JOIN Network.Person AS FollowedPerson
			ON FollowedPerson.PersonId = Follows.FollowsPersonId
WHERE  Person.Name = 'Lou Iss'

INSERT INTO Network_UI.Follows(PersonId,FollowsPersonId,Value)
SELECT (SELECT PersonId FROM Network.Person WHERE name = 'Lou iss'),
	   (SELECT PersonId FROM Network.Person WHERE name = 'Joe Seph'),
	   10
GO
--run the query again, and you will see the new row.

--delete and update next **




--Constraints and Indexes


--Power loading data using composible JSON tags