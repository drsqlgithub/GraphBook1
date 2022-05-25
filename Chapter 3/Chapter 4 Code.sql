--In this chapter I will be expanding on chapter 3 code, altering the database we created. 
--

USE TestGraph
GO

--Making data entry more natural

--interface to make the view easier to view

IF SCHEMA_ID('Network_UI') IS NULL 
	EXEC ('CREATE SCHEMA Network_UI')
GO

CREATE OR ALTER VIEW Network_UI.Person_Follows_Person
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
FROM  Network_UI.Person_Follows_Person
GO

--now I am going to create an instead of trigger to make an object that looks like a tabl that uses "normal" columns, which will make it a lot easier later in the book to load lots of data into a table without dealing with all of the translation to graph key values.

--Some of the examples in this section don't look like we are saving anything (because I am going to have to lookup the regular key just like the graph values, but later when loading data from existing many-to-many relationships. It will turn out to be kind of remarkably fast, as I will demonstrate in the large network chapter (#?).

CREATE OR ALTER TRIGGER Network_UI.Person_FollowsPerson_$InsteadOfInsertTrigger
ON Network_UI.Person_Follows_Person
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

--now I can insert new data, and write quick queries using regular joins.

SELECT Person.Name, FollowedPerson.Name AS FollowedPerson
FROM   Network_UI.Person_Follows_Person as Follows
		JOIN Network.Person
			ON Person.PersonId = Follows.PersonId
		JOIN Network.Person AS FollowedPerson
			ON FollowedPerson.PersonId = Follows.FollowsPersonId
WHERE  Person.Name = 'Lou Iss'

--Take care becaus while this will be pretty fast on your small data set, there are a few extra hops involved in the interals of this query. Use the MATCH and the proper table as often as possible.

--Looking at the query plan too, you will notice a HASH JOIN operator. Later in the chapter we will look at adding indexes to your node and edge objects. While there is a lot different about the node and edge objects, there are a lot of similarities too, and you will need to take some control over performance tuning based on how you use your objects.


--As noted, this isn't a big value, but if I had a table of the id values to turn into a graph it would rock.
INSERT INTO Network_UI.Person_Follows_Person(PersonId,FollowsPersonId,Value)
SELECT (SELECT PersonId FROM Network.Person WHERE name = 'Lou iss'),
	   (SELECT PersonId FROM Network.Person WHERE name = 'Joe Seph'),
	   10
GO
--run the query again, and you will see the new row.

--delete and update next **
--As I should have said earlier (and will), edge objects cannot have their $from_id or $to_id values updated. And this makes good sense. but let's say you want to update the value to be 1, to match all of our other data.

UPDATE Network_UI.Person_Follows_Person
set Value = 1
where PersonId = (SELECT PersonId FROM Network.Person WHERE name = 'Lou iss')
and FollowsPersonId = (SELECT PersonId FROM Network.Person WHERE name = 'Joe Seph')
GO

--this works great because you are only updating data from one table in your update. Any attempt to change the key values will fail as:
UPDATE Network_UI.Person_Follows_Person
set Value = 1,
    PersonId = 0

/*
Returns:

Msg 4405, Level 16, State 1, Line 85
View or function 'Network_UI.Person_Follows_Person' is not updatable because the modification affects multiple base tables.

*/

--If you desire to update the values, it is definitely doable in an instead of trigger (requiring a delete and an insert, which should definitely have more involved error handling), but I would not suggest it personally. 

--Deletes however, make perfect sense, but definitely need a trigger because it will appear as if you want to delete rows from multiple tables.

DELETE FROM Network_UI.Person_Follows_Person
where PersonId = (SELECT PersonId FROM Network.Person WHERE name = 'Lou iss')
and FollowsPersonId = (SELECT PersonId FROM Network.Person WHERE name = 'Joe Seph');

--Just as before, same error 4405.  So let's build a simple instead of delete trigger object. The weird question here is "what will deleted contain?". Let's see

CREATE OR ALTER TRIGGER Network_UI.Person_Follows_Person$InsteadOfDeleteTrigger
ON Network_UI.Person_Follows_Person
INSTEAD OF DELETE
AS
SET NOCOUNT ON;
 --If you add more code, you should add error handling code.
 BEGIN 
  select *
  from   Deleted
 END;
GO

--Note, if this doesn't work for you, check the settings noted in this article: https://docs.microsoft.com/en-us/sql/database-engine/configure-windows/disallow-results-from-triggers-server-configuration-option?view=sql-server-ver16. Worst case you might have to let the trigger create a table with the results. It is clearly best to not have results from normal triggers, but it is very useful in a development case to be able to see what is being output.

--execute the following statement, and you will see that the deleted table contains the data from the view.

DELETE FROM Network_UI.Person_Follows_Person
where PersonId = (SELECT PersonId FROM Network.Person WHERE name = 'Lou iss')
and FollowsPersonId = (SELECT PersonId FROM Network.Person WHERE name = 'Joe Seph');
/*
PersonId    FollowsPersonId Value
----------- --------------- -----------
2           6               1

So we can write the trigger just like this:
*/

CREATE OR ALTER TRIGGER Network_UI.Person_Follows_Person$InsteadOfDeleteTrigger
ON Network_UI.Person_Follows_Person
INSTEAD OF DELETE
AS
SET NOCOUNT ON;
 --If you add more code, you should add error handling code.
 BEGIN 
  DELETE FROM Network.Follows --<The real table
  FROM Network.Person, Network.Follows,
       Network.Person AS FollowedPerson,
	   deleted
  WHERE MATCH(Person-(Follows)->FollowedPerson)
    and  deleted.PersonId = Person.PersonId
	and  deleted.FollowsPersonId = FollowedPerson.PersonId
 END;
GO

--Now you can delete the data in a straightforward manner (I will use the Id values we got from the query earlier)

DELETE FROM Network_UI.Person_Follows_Person
where PersonId = 2
and FollowsPersonId = 6;

--after deleting in the rows, you can see the row is gone. Be sure and test with creating and deleting multiple rows when you build triggers.

SELECT Person.Name AS PersonName,
		FollowedPerson.Name AS FollowsPersonName
FROM Network.Person,
     Network.Follows,
     Network.Person AS FollowedPerson
WHERE MATCH(Person-(Follows)->FollowedPerson)
  and Person.Name = 'Lou Iss';

--Constraints and Indexes

--So far, we have been really careful with the data we have put into the edge tables, but as noted earlier, part of the value of edge tables are that they are very flexible. As any software developer knows though, flexiblity is dangerous when you don't expect it.

--As an example, I am going to add another set of nodes to the sample graph. Going to call it Location. Then I will create edge values in the Follows edge. (Not that this makes sense, which is part of the point).

create table Network.Location
(
	LocationId int NOT NULL IDENTITY,
	Name nvarchar(20) NOT NULL CONSTRAINT AKLocation UNIQUE 
) as Node
INSERT INTO Network.Location (Name)
VALUES ('Here'),('There')
GO


--CREATE OR ALTER VIEW Network_UI.Person_Follows_Location
--AS
--SELECT Person.PersonId AS PersonId,
--		FollowedLocation.LocationId AS FollowsLocationId,
--		Follows.Value
--FROM Network.Person,
--     Network.Follows,
--     Network.Location AS FollowedLocation
--WHERE MATCH(Person-(Follows)->FollowedLocation);
--GO
--SELECT *
--FROM  Network_UI.Person_Follows_Location
--GO

--CREATE OR ALTER TRIGGER Network_UI.Person_Follows_Location$InsteadOfInsertTrigger
--ON Network_UI.Person_Follows_Location
--INSTEAD OF INSERT
--AS
--SET NOCOUNT ON;
-- --If you add more code, you should add error handling code.
-- BEGIN 
--  INSERT INTO Network.Follows($from_id, $to_id, Value)
--  SELECT Person.$node_id, FollowedLocation.$node_id, 
--		inserted.Value
--  FROM Inserted
--       JOIN Network.Person
--           ON Person.PersonId = Inserted.PersonId
--       JOIN Network.Location AS FollowedLocation
--           ON FollowedLocation.LocationId = Inserted.FollowsLocationId
-- END;
--GO
**
WITH Here AS (
select $edge_id as edge_id
from   Network.Person 
where  name IN ('Fred Rick','Lou Iss','Joe Seph')
)
insert into Network_UI.Person_Follows_Location(
		$from_id, $to_id, Value)
select Here.PersonId, Location.LocationId, 1
from   Here
		cross join Network.Location
where  Location.Name = 'Here'

WITH Here AS (
select *
from   Network.Person 
where  name IN ('Will Iam','Lee Roy','Day Vid')
)
insert into Network_UI.Person_Follows_Location(
		PersonId, FollowsLocationId, Value)
select Here.PersonId, Location.LocationId, 1
from   Here
		cross join Network.Location
where  Location.Name = 'There';

--And I do think that was easier to code than the alternative, 


--Power loading data using composible JSON tags

--Heterogenous objects and queries