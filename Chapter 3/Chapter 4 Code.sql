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

--
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

--Heterogenous queries. 

--So far in the book, we have only kept the only pattern of usage for our designs to be one many to many relationship between just two nodes. Either the table was the same (Person Follows Person) or different (Person ProgramsWith ProgrammingLanguage). In this section I want to highlight the idea that you can have multiple relationships through one edge, and how you can query the nodes.

--As an example, I am going to add another set of nodes to the sample graph. Going to call it Location. Then I will create edge values in the Follows edge. (Not that this makes sense, which is part of the point).

--Figure 4 or whatever :)


create table Network.Location
(
	LocationId int NOT NULL IDENTITY,
	Name nvarchar(20) NOT NULL CONSTRAINT AKLocation UNIQUE 
) as Node
INSERT INTO Network.Location (Name)
VALUES ('Here'),('There')
GO

--Now I am going to 


WITH Here AS (
select $node_id as node_id
from   Network.Person 
where  name IN ('Fred Rick','Lou Iss','Joe Seph')
)
insert into Network.Follows(
		$from_id, $to_id, Value)
select Here.node_id, Location.$node_id, 1
from   Here
		cross join Network.Location
where  Location.Name = 'Here'

WITH Here AS (
select $node_id as node_id
from   Network.Person 
where  name IN ('Will Iam','Lee Roy','Day Vid')
)
insert into Network.Follows(
		$from_id, $to_id, Value)
select Here.node_id, Location.$node_id, 1
from   Here
		cross join Network.Location
where  Location.Name = 'There'

--now you can see the rows we created like this:

SELECT Person.Name, Location.Name
from   Network.Person, Network.Follows, Network.Location
where  Match(Person-(Follows)->Location)



select Person.Name, Nodes.ObjectName, Nodes.Name
from   Network.Person, Network.Follows, 
       (SELECT 'Location' as ObjectName,Name
	   FROM   Network.Location
	   union all
	   Select 'Person',Name
	   FROM   Network.Person) as Nodes
WHERE MATCH(Person-(Follows)->Nodes)
  and Person.Name = 'Lou Iss'

--This returns 
/*
Name		ObjectName	Name
----------- ----------- ------------
Lou Iss		Person		Will Iam
Lou Iss		Person		Val Erry
Lou Iss		Location	Here

What is interesting in this model is that the graph objects carry along their graph identifiers whether you put them out there or not, and will generally be available for uses in graph queries, but if you want them to be accessible in other uses (like to use in an IN expression.)

However, once you fetch the rows they go back to being strongly typed and shaped relational tables. And since the method we are discussing requires a derived table,CTE, or view object, you will need to shape the different sets of data to all be the same. 

For the most part, I see this as useful for either one table being linked to another through an edge table, or for cases where the tables that are being linked through the same edge are very much similar in meaning (and it hopefully follows, shape)

However, there are definitely uses for hetrogenous queries. For example, thinking of the Network schema as if it was a Customer Relationship Management (CRM) system, how could you see everything that they are connected to? Make a derived table of all the edges and all the nodes and match on that.
*/

select Person.Name, OtherThing.ObjectType, OtherThing.Name
from   Network.Person, 
		--the graph columns are exposed automatically, and no 
		--columns do we need, so just returning nothing
		--though this is clearly not a subquery about nothing
	   (select 1 as nothing from network.Follows
	    UNION ALL
		Select 1 from network.ProgramsWith) as LinksTo,
	   (SELECT 'Person' as ObjectType,
			   Name from Network.Person
	    UNION ALL
		SELECT 'ProgrammingLanguage',
				Name from Network.ProgrammingLanguage
		UNION ALL
		SELECT 'Location',
		        Name from Network.Location) as OtherThing
where  MATCH(Person-(LinksTo)->OtherThing)
  and Person.Name = 'Lou Iss'

/*
Name	ObjectType	Name
Lou Iss	Person	Will Iam
Lou Iss	Person	Val Erry
Lou Iss	Location	Here
Lou Iss	ProgrammingLanguage	T-SQL

Next I will make a few simple views to demonstrate how that works:
*/
CREATE VIEW Network.LinksTo
AS
  select 1 as nothing from network.Follows
  UNION ALL
  Select 1 from network.ProgramsWith
GO
CREATE VIEW Network.Anything
as 
  SELECT 'Person' as ObjectType,
          Name from Network.Person
  UNION ALL
  SELECT 'ProgrammingLanguage',
			Name from Network.ProgrammingLanguage
  UNION ALL
  SELECT 'Location',
		  Name from Network.Location
GO
--Excute the query to get the same example as the one with derived tables.

select Person.Name, AnyThing.ObjectType, AnyThing.Name
from   Network.Person, Network.LinksTo, Network.Anything
where  MATCH(Person-(LinksTo)->AnyThing)
  and Person.Name = 'Lou Iss'
/* What is interesting though is what happens if you add ,* to the SELECT clause. This should return all the columns right? And since we were clearly able to join on the graph key values through the MATCH expression, you would expect to see the values, right?

Turns out not. When your objects are encapsulated into derived tables or view objects, you will only get access to the columns you output, even though the columns are in fact in use.

However, the graph identifiers may not be exposed in the same manner in all uses like this. For example:
*/
select Person.Name, Nodes.ObjectName, Nodes.Name,
		Nodes.$node_id
from   Network.Person, Network.Follows, 
       (SELECT 'Location' as ObjectName, Name, $node_id
	   FROM   Network.Person) as Nodes
WHERE MATCH(Person-(Follows)->Nodes)
  and Person.Name = 'Lou Iss'
/*
Will throw this error:

Msg 207, Level 16, State 1, Line 243
Invalid column name '$node_id'.

If you want the graph id value to be part of the output, you have to name them and use the name:
*/
select Person.Name, Nodes.ObjectName, Nodes.Name,
		Nodes.NodeId
from   Network.Person, Network.Follows, 
       (SELECT 'Location' as ObjectName, Name, 
			   $node_id as NodeId
	   FROM   Network.Person) as Nodes
WHERE MATCH(Person-(Follows)->Nodes)
  and Person.Name = 'Lou Iss'
 
/*
Lou Iss	Location	Will Iam	{"type":"node","schema":"Network","table":"Person","id":4}
Lou Iss	Location	Val Erry	{"type":"node","schema":"Network","table":"Person","id":2}

You will need to include the implementation columns you need in your view definition if you ned it for some reason.
*/

--Constraints and indexes 

--So far, we have been really careful with the data we have put into the edge tables, but as demonstrated in the past section, part of the value of edge tables are that they are very flexible. As any software developer knows though, flexiblity is a pro and a con, because sometimes as a designer you don't realize there is flexibility when there is.





--Power loading data using composible JSON tags
