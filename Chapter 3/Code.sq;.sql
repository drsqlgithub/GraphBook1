alter database TestGraph set single_user with rollback immediate
GO
use master
GO
drop database TestGraph
GO
create database TestGraph
GO
use TestGraph
GO

--Figure 1 before this

--start out creating a single node table and one edge
if schema_id('Network') is null
	exec ('CREATE SCHEMA Network');
GO
create table Network.Person
(
	PersonId int identity CONSTRAINT PKPerson PRIMARY KEY,
	FirstName nvarchar(100) NULL,
	LastName  nvarchar(100) NOT NULL,
	Name as (CONCAT(FirstName+' ',LastName)) PERSISTED,
	Value int NOT NULL CONSTRAINT DFLTPerson_Value DEFAULT(1),
	CONSTRAINT AKPerson UNIQUE (FirstName,LastName)
) as NODE;
GO
create table Network.Follows
(Value int NOT NULL 
	CONSTRAINT DFLTFollows_Value DEFAULT(1))
AS EDGE;

--listing nodes and edges
select object_schema_name(object_id) as schema_name,
       name as table_name,
	   is_edge,
	   is_node
from  sys.tables
where is_edge = 1
 or   is_node = 1;
GO

--adding node rows is exactly like adding rows to any table
Insert into Network.Person(FirstName, LastName)
Values ('Fred','Rick'),('Lou','Iss'),('Val','Erry')
,('Lee','Roy'),('Will','Iam'),('Joe','Seph'),
('Day','Vid');

--then select some data from the table:
select *
from   Network.Person
where  FirstName = 'Fred'
and    LastName = 'Rick'
GO

/*
You will notice that the first column outputted looks like this

$node_id_3949CAAFE93D496C9A4CF1F33767B666                      
---------------------------------------------------------------
{"type":"node","schema":"Network","table":"Person","id":0}   


The rest of the table is what you expect it do be:
PersonId    FirstName    LastName       Name             Value         
----------- ------------ -------------- ---------------- -----------
1           Fred         Rick           Fred Rick        1         
*/

--#You can use the column name in a query:
select [$node_id_3949CAAFE93D496C9A4CF1F33767B666] 
from   Network.Person
where [$node_id_3949CAAFE93D496C9A4CF1F33767B666]  = 
'{"type":"node","schema":"Network","table":"Person","id":0}'

/*
returns the same thing. Leave off the square brackets and you will get

Msg 126, Level 15, State 2, Line 69
Invalid pseudocolumn "$node_id_3949CAAFE93D496C9A4CF1F33767B666".
*/

--A pseudocolumn is a SQL Server construct that lets you use a value without knowing its exact name. There are others, particularly in partitioning. Here, you use $node_id instead of this value (which will change when you create this table on your maching in all probability)
select $node_id --not in square brackets, because this is not a column name
from   Network.Person
where $node_id  = '{"type":"node","schema":"Network","table":"Person","id":0}'

--briefly describe how that node id works.. Will show more examples later.

--for the edge we created, we have several more pseudocolumns to work with:
select *
from   Network.Follows

/*
$edge_id_3E64B3D47C09432595C25D1FB2146A35 
------------------------------------------

$from_id_AA09B7FBEA714F918B3C0D19A8B24A0A
-----------------------------------------

$to_id_4E49D534C24E4F4D8E0E0D207237A425
---------------------------------------

and a value column again for later usage.

These are all abbreviated as $edge_id, $from_id, $to_id. The latter two take as input a $node_id from a node. When doing the input of data, the basic pattern is something like this:

*/
insert into Network.Follows($From_id, $To_id)
select (select $node_id 
        from Network.Person 
        where FirstName = 'fred' 
		  and LastName = 'Rick') as from_id, --just a name to make it easier to see when debugging
	   (select $node_id 
	    from Network.Person 
		where FirstName = 'Joe' 
		 and LastName = 'Seph') as to_id

--looking at that data, you can see:
select *
from   Network.Follows
/*
$edge_id_3E64B3D47C09432595C25D1FB2146A35                  
-----------------------------------------------------------
{"type":"edge","schema":"Network","table":"Follows","id":0}

 $from_id_AA09B7FBEA714F918B3C0D19A8B24A0A                 
 ----------------------------------------------------------
 {"type":"node","schema":"Network","table":"Person","id":0}

 $to_id_4E49D534C24E4F4D8E0E0D207237A425                   
 ----------------------------------------------------------
 {"type":"node","schema":"Network","table":"Person","id":5}
 */
 --you also can do this (first clear the table, as we have not protected
 --against duplication yet, which I will show later)
 truncate table Network.Follows --using truncate so the id values are
								--reset, just for clarity in writing
								--no need to do this in real use

 insert into Network.Follows($from_id, $to_id)
 values ('{"type":"node","schema":"Network","table":"Person","id":0}',
         '{"type":"node","schema":"Network","table":"Person","id":5}')

--note that these items are values you can directly enter, but they are not the actual values that are stored.

--later in this (or next, depending on how large this chapter is) chapter, I will show you how you can use this format to your advantage when loading data from an outside source.
--i will also demonstrate how things are implemented internally, which is really useful especially when dealing with errors

--then the rest of the rows
insert into Network.Follows($From_id, $To_id)
select (select $node_id from Network.Person where FirstName = 'fred' and LastName = 'Rick'),
	   (select $node_id from Network.Person where FirstName = 'Lou' and LastName = 'Iss')
union all
select (select $node_id from Network.Person where FirstName = 'Joe' and LastName = 'Seph'),
	   (select $node_id from Network.Person where FirstName = 'Will' and LastName = 'Iam')
union all
select (select $node_id from Network.Person where FirstName = 'Will' and LastName = 'Iam'),
		(select $node_id from Network.Person where FirstName = 'Lee' and LastName = 'Roy')
union all
select (select $node_id from Network.Person where FirstName = 'Val' and LastName = 'Erry'),
	   (select $node_id from Network.Person where FirstName = 'Joe' and LastName = 'Seph')
union all
select (select $node_id from Network.Person where FirstName = 'Val' and LastName = 'Erry'),
	   (select $node_id from Network.Person where FirstName = 'Lee' and LastName = 'Roy')
union all
select (select $node_id from Network.Person where FirstName = 'Lou' and LastName = 'Iss'),
	   (select $node_id from Network.Person where FirstName = 'Will' and LastName = 'Iam')

union all
select (select $node_id from Network.Person where FirstName = 'Lou' and LastName = 'Iss'),
	   (select $node_id from Network.Person where FirstName = 'Val' and LastName = 'Erry')
union all
select (select $node_id from Network.Person where FirstName = 'Will' and LastName = 'Iam'),
	   (select $node_id from Network.Person where FirstName = 'Fred' and LastName = 'Rick')
union all
select (select $node_id from Network.Person where FirstName = 'Fred' and LastName = 'Rick'),
	   (select $node_id from Network.Person where FirstName = 'Val' and LastName = 'Erry')
union all
select (select $node_id from Network.Person where FirstName = 'Day' and LastName = 'Vid'),
	   (select $node_id from Network.Person where FirstName = 'WIll' and LastName = 'Iam')

--the following query is something you rarely want to do (joining on the internal values directly). But this query is directly analagous to what our simplest graph query will do.

SELECT Person.Name as PersonName, 
	   FollowedPerson.Name as FollowedPersonName
from   Network.Person
	    join Network.Follows
			on Person.$node_id = Follows.$from_id
		join Network.Person as FollowedPerson
			on FollowedPerson.$node_id = Follows.$to_id
/*
PersonName     FollowedPersonName
-------------- ----------------------
Fred Rick      Joe Seph
Fred Rick      Lou Iss
Joe Seph       Will Iam
Will Iam       Lee Roy
Val Erry       Joe Seph
Val Erry       Lee Roy
Lou Iss        Will Iam
Lou Iss        Val Erry
Will Iam       Fred Rick
Fred Rick      Val Erry
Day Vid        Will Iam

This will match all the directed edge lines in Figure 1

--briefly explaing the basic MATCH operator, and how this query is the way it works

*/
select cast(Person.Name as nvarchar(20)) as PersonName, 
	   FollowedPerson.Name as FollowedPersonName
from   Network.Person, Network.Follows, Network.Person as FollowedPerson
where  MATCH(Person-(Follows)->FollowedPerson)
--same output, probably sorted differentl

--note too that you can't use ANY ANSI style joins in the query... Not even the equivalent CROSS JOIN for the commas.

select cast(Person.Name as nvarchar(20)) as PersonName, 
	   FollowedPerson.Name as FollowedPersonName
from   Network.Person CROSS JOIN Network.Follows CROSS JOIN Network.Person as FollowedPerson
where  MATCH(Person-(Follows)->FollowedPerson)

/*
Msg 13920, Level 16, State 1, Line 221
Identifier 'Follows' in a MATCH clause is used with a JOIN clause or APPLY operator. JOIN and APPLY are not supported with MATCH clauses.
Msg 13920, Level 16, State 1, Line 221
Identifier 'Person' in a MATCH clause is used with a JOIN clause or APPLY operator. JOIN and APPLY are not supported with MATCH clauses.
Msg 13920, Level 16, State 1, Line 221
Identifier 'FollowedPerson' in a MATCH clause is used with a JOIN clause or APPLY operator. JOIN and APPLY are not supported with MATCH clauses.
*/
select cast(Person.Name as nvarchar(20)) as PersonName, 
	   FollowedPerson.Name as FollowedPersonName
from   Network.Person, Network.Follows, Network.Person as FollowedPerson
where  MATCH(Person-(Follows)->FollowedPerson)

--All joins to fetch extra information will need to be done like this

select cast(Person.Name as nvarchar(20)) as PersonName, 
	   FollowedPerson.Name as FollowedPersonName,
	   ColorName
from   Network.Person, Network.Follows, Network.Person as FollowedPerson,
       (select 'blue' as ColorName
	    union all 
		select 'red') as Colors
where  MATCH(Person-(Follows)->FollowedPerson)
  AND  CASE WHEN Person.FirstName = 'Fred' THEN 'blue' ELSE 'red' END =
		colors.ColorName

--and there is no way to do an outer join, so you will need to take care to write your joins safely to not lose data accidentally


--you filter the output the same as in any query. Like to just see the people that Lou Iss follows:

select cast(Person.Name as nvarchar(20)) as PersonName, 
	   FollowedPerson.Name as FollowedPersonName
from   Network.Person, Network.Follows, Network.Person as FollowedPerson
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss' --added
 and   MATCH(Person-(Follows)->FollowedPerson)

 /*
 PersonName           FollowedPersonName
 -------------------- ---------------------
 Lou Iss              Will Iam
 Lou Iss              Val Erry
 */

 --to find the parents of a row,  just reverse the arrow in the MATCH operator:

select FollowedPerson.Name as Person
       Person.Name as Follows, 
from   Network.Person, Network.Follows, Network.Person as FollowedPerson
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(Person<-(Follows)-FollowedPerson)

 /*
Person    Follows	  
--------- ---------- 
Fred Rick Lou Iss	  
*/
 --starting at any given point of the graph is something that will be used very frequently in the example code, particularly to find the child rows of a node, often to count or sum their data.



--you can do more than one match statement together. To make this easier, I am going to add a new node and edge to the graph for programming language like seen in Figure 2

 --add figure 2

 CREATE  table Network.ProgrammingLanguage
(
	Name nvarchar(30) NOT NULL
) as NODE;

create table Network.ProgramsWith
AS EDGE;

--load the nodes
Insert Into Network.ProgrammingLanguage (Name)
VALUES ('C++'),('T-SQL'),('Fortran');

--then load some data

--just like before I will add rows like this:
Insert into Network.ProgramsWith($from_id, $to_id)
select (select $node_id 
		from Network.Person 
		where FirstName = 'Lou' 
		  and LastName = 'Iss') as from_id,
	   (select $node_id 
	   from Network.ProgrammingLanguage 
	   where Name = 'T-SQL') as to_id;

--the rest is avaiable in the download
Insert into Network.ProgramsWith($from_id, $to_id)
select (select $node_id from Network.Person where FirstName = 'Val' and LastName = 'Erry'),
	   (select $node_id from Network.ProgrammingLanguage where Name = 'T-SQL')
UNION ALL
select (select $node_id from Network.Person where FirstName = 'Val' and LastName = 'Erry'),
	   (select $node_id from Network.ProgrammingLanguage where Name = 'Fortran')
UNION ALL
select (select $node_id from Network.Person where FirstName = 'Lee' and LastName = 'Roy'),
	   (select $node_id from Network.ProgrammingLanguage where Name = 'T-SQL')
UNION ALL
select (select $node_id from Network.Person where FirstName = 'Lee' and LastName = 'Roy'),
	   (select $node_id from Network.ProgrammingLanguage where Name = 'Fortran')
UNION ALL
select (select $node_id from Network.Person where FirstName = 'WIll' and LastName = 'Iam'),
	   (select $node_id from Network.ProgrammingLanguage where Name = 'Fortran')
UNION ALL
select (select $node_id from Network.Person where FirstName = 'Joe' and LastName = 'Seph'),
	   (select $node_id from Network.ProgrammingLanguage where Name = 'C++')
UNION ALL
select (select $node_id from Network.Person where FirstName = 'Day' and LastName = 'Vid'),
	   (select $node_id from Network.ProgrammingLanguage where Name = 'T-SQL')
GO
--now, lets see people that program with a programming language

  select Person.Name as Person,
	   ProgrammingLanguage.Name
from   Network.Person as Person,
		Network.ProgramsWith as ProgramsWith, 
		Network.ProgrammingLanguage as ProgrammingLanguage
where  Match(Person-(ProgramsWith)->ProgrammingLanguage)
ORDER BY Person, Name

-- you can see Val and Lee both have multiples, so they have multiple rows
-- Fred does not have any languages, so doesn't show up in the list. There
--is not a way to make Fred show up in this list without adding a "not a 
--programmr" node

--now we can find the people who share a programming language ability by
--making 2 virtual copies of Person, and the edge (edges cannot be used more than one time in a query, but tables can depending on the meaning)

--in the following query we are looking for 2 different people sharing one language

select Person.Name as Person, Person2.Name as Person2,
	   ProgrammingLanguage.Name
from   Network.Person as Person, 
       Network.Person as Person2,
		Network.ProgramsWith as ProgramsWith, 
		Network.ProgrammingLanguage as ProgrammingLanguage,
		Network.ProgramsWith as ProgramsWith2 
where  Match(Person-(ProgramsWith)->ProgrammingLanguage)
  and  Match(Person2-(ProgramsWith2)->ProgrammingLanguage)
  and person2.personId <> Person.personId
ORDER BY Person, Person2, Name

--note that the person2 <> person line is due to the fact that person and Person2 are the same table, and we know that the same person has the same skill as themself.

--You can do multiple match statements like that, but most of the time you can tie things together using the ASCII art version of the query, like this:

  select Person.Name as Person, Person2.Name as Person2,
	   ProgrammingLanguage.Name
from   Network.Person as Person, 
       Network.Person as Person2,
		Network.ProgramsWith as ProgramsWith, 
		Network.ProgrammingLanguage as ProgrammingLanguage,
		Network.ProgramsWith as ProgramsWith2 
--change here
where Match(Person-(ProgramsWith)->ProgrammingLanguage<-(ProgramsWith2)-Person2)
 and person2.personId <> Person.personId
ORDER BY Person, Person2, Name

--Now in the one MATCH expression, it expresses both sides of the equation.  Finally, since you may not be able to combine everything into one MATCH expression you can AND right in the MATCH expression:

 select Person.Name as Person, Person2.Name as Person2,
	   ProgrammingLanguage.Name
from   Network.Person as Person, 
       Network.Person as Person2,
		Network.ProgramsWith as ProgramsWith, 
		Network.ProgrammingLanguage as ProgrammingLanguage,
		Network.ProgramsWith as ProgramsWith2 
where  Match(Person-(ProgramsWith)->ProgrammingLanguage
             AND Person2-(ProgramsWith2)->ProgrammingLanguage)
   and person2.personId <> Person.personId
ORDER BY 1

--In this next query, I will look for people who follow each other and share a programming language. These types of queries, with the generic many-to-many tables are part of the great power with the sql graph objects.

select Person.Name as Person, Person2.Name as Person2,
	   ProgrammingLanguage.Name
from   Network.Person as Person, 
       Network.Person as Person2,
		Network.ProgramsWith as ProgramsWith, 
		Network.ProgrammingLanguage as ProgrammingLanguage,
		Network.ProgramsWith as ProgramsWith2,
		Network.Follows as Follows
where  Match(Person-(ProgramsWith)->ProgrammingLanguage)
  and  Match(Person2-(ProgramsWith2)->ProgrammingLanguage)
  and  Match(Person-(follows)->Person2)
  and person2.personId <> Person.personId
ORDER BY Person, Person2, Name

/*
Person       Person2       Name
------------ ------------- ------------------------------
Lou Iss      Val Erry      T-SQL
Val Erry     Lee Roy       Fortran
Val Erry     Lee Roy       T-SQL
Will Iam     Lee Roy       Fortran
*/

--traversing paths, using shortest path

--so far, most of what we have done can be done with simple joins (and some less simply hoops to jump through to intersect sets)
--now to move to finding paths between two nodes in a graph. 
--SQL Server implements a function SHORTEST_PATH which is used to find (not surprisingly) a path from two nodes that is the shortest possible. It is a random path because if there are multiple paths through the tree, it will pick just the one. 
--The syntax gets quite gnarly here, and some parts of this were not at all easy for me to learn! 

--In this next query, I will do a minimal query to get the shortest path between the Lou Iss node to any other nodes that connect.
 select Person.Name as Person,
		LAST_VALUE(FollowedPerson.Name) WITHIN GROUP (GRAPH PATH)
from   Network.Person as Person, Network.Follows for path as Follows, Network.Person for path as FollowedPerson 
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(SHORTEST_PATH(Person(-(Follows)->FollowedPerson)+))

 --let's break this down to the base parts as several things change
 --


 --showing how you can do LAST_VALUE to multiple columns
 select Person.Name as Person,
		CONCAT(
		LAST_VALUE(FollowedPerson.Firstname) WITHIN GROUP (GRAPH PATH),
		' ',
		LAST_VALUE(FollowedPerson.LastName) WITHIN GROUP (GRAPH PATH)) as Name
from   Network.Person as Person, Network.Follows for path as Follows, Network.Person for path as FollowedPerson 
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(SHORTEST_PATH(Person(-(Follows)->FollowedPerson)+))

 --now lets add a bit to the output. You can do aggregates such as count. Count is the standard way to get the number of hops between nodes. For example:

   select Person.Name as Person,
		LAST_VALUE(FollowedPerson.Name) WITHIN GROUP (GRAPH PATH) as ConnectedPerson,
		COUNT(FollowedPerson.PersonId) WITHIN GROUP (GRAPH PATH) as Level
from   Network.Person as Person, Network.Follows for path as Follows, Network.Person for path as FollowedPerson 
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(SHORTEST_PATH(Person(-(Follows)->FollowedPerson)+))

 /*
 In the output you can see that Val and Will are directly connected to Lou, so 1 hop
 Fred, Joe, and Lee are 2. And it is 3 hops to get back to Lou (showing the graph is cyclic back to Lou, something I will use when protecting against cyclic graphs later)

Person        ConnectedPerson   Level
------------- ----------------- -----------
Lou Iss       Val Erry          1
Lou Iss       Will Iam          1
Lou Iss       Fred Rick         2
Lou Iss       Lee Roy           2
Lou Iss       Joe Seph          2
Lou Iss       Lou Iss           3

*/

--next I will add one of the most useful tools you have when debugging this code. The node labels of each node in the walk represented in the shortest path output.
--this is done using STRING_AGG, and it demonstrates in the clearest manner how this algorithm is recursive.

  select Person.Name as Person,
		LAST_VALUE(FollowedPerson.Name) WITHIN GROUP (GRAPH PATH) as ConnectedPerson,
		COUNT(FollowedPerson.PersonId) WITHIN GROUP (GRAPH PATH) as Level,
		STRING_AGG(FollowedPerson.Name, '->') WITHIN GROUP (GRAPH PATH) as Path
from   Network.Person as Person, Network.Follows for path as Follows, Network.Person for path as FollowedPerson 
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(SHORTEST_PATH(Person(-(Follows)->FollowedPerson)+))

 /*
 added to the output from the rep
 Person        ConnectedPerson   Level   Path
 ------------- ----------------- ------- ---------------------------------------
 Lou Iss       Val Erry          1       Val Erry
 Lou Iss       Will Iam          1       Will Iam
 Lou Iss       Fred Rick         2       Will Iam->Fred Rick
 Lou Iss       Lee Roy           2       Val Erry->Lee Roy
 Lou Iss       Joe Seph          2       Val Erry->Joe Seph
 Lou Iss       Lou Iss           3       Will Iam->Fred Rick->Lou Iss

 --Note that the walk from Lou to Lee goes through Val only. On the diagram it also goes through Will. Later in in the chapter I will demonstrate how to include all walks in your output (it will not be nearly as neat and tidy as these queries!)
 --generally speaking it shouldn't make much difference to your output what nodes are included... unless you start doing aggregates on the nodes in the path... 

--When I created the graph, I included value columns on each edge and node to let us see how they compare to the count(*) output since each value is 1. 
*/

  select Person.Name as Person,
		LAST_VALUE(FollowedPerson.Name) WITHIN GROUP (GRAPH PATH) as ConnectedPerson,
		COUNT(FollowedPerson.PersonId) WITHIN GROUP (GRAPH PATH) as Level,
		STRING_AGG(FollowedPerson.Name, '->') WITHIN GROUP (GRAPH PATH),
		SUM(FollowedPerson.Value) WITHIN GROUP (GRAPH PATH) as SumNodeValues,
		--NOTE: Figure out why this is equal. More are being included or not enoiugh
		SUM(Follows.Value) WITHIN GROUP (GRAPH PATH) as SumEdgeValues
from   Network.Person as Person, Network.Follows for path as Follows, Network.Person for path as FollowedPerson 
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(SHORTEST_PATH(Person(-(Follows)->FollowedPerson)+))

--the output of this query has 2 new columns that the same value as the level.. You can see in the following output, where I added the extra values, that the sum doesn't include the base node:

  select Person.Name as Person,
		CONCAT(
		LAST_VALUE(FollowedPerson.Firstname) WITHIN GROUP (GRAPH PATH),' ',
		LAST_VALUE(FollowedPerson.LastName) WITHIN GROUP (GRAPH PATH)) as ConnectedPerson,
		COUNT(FollowedPerson.PersonId) WITHIN GROUP (GRAPH PATH) as Level,
		STRING_AGG(FollowedPerson.Name, '->') WITHIN GROUP (GRAPH PATH),
		SUM(FollowedPerson.Value) WITHIN GROUP (GRAPH PATH) as SumNodeValues,
		--NOTE: Figure out why this is equal. More are being included or not enoiugh
		SUM(Follows.Value) WITHIN GROUP (GRAPH PATH) as SumEdgeValues,
		STRING_AGG(CONCAT(FollowedPerson.Name, ' Node:',FollowedPerson.Value), '->') WITHIN GROUP (GRAPH PATH),
		STRING_AGG(CONCAT(FollowedPerson.Name, ' EdgeValue:',Follows.Value), '->') WITHIN GROUP (GRAPH PATH)
from   Network.Person as Person, Network.Follows for path as Follows, Network.Person for path as FollowedPerson 
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(SHORTEST_PATH(Person(-(Follows)->FollowedPerson)+))

--So while you CAN sum the node and edge values, it is important to remember that you can only do shortest path, not the cheapest or most expensive path.
--So as seen in currently Figure 3, the direct path has the highest magnitude, but it is the only path we can actually choose. 
--later in the chapter I will include how to get get the longest path in a different manner.

--You control the number of levels to search (which can be really important with some very large networks, in the SHORTEST_PATH syntax.

--show everyone linked at any level, along with their path
  select Person.Name as Person,
		LAST_VALUE(FollowedPerson.Name) WITHIN GROUP (GRAPH PATH) as ConnectedPerson,
		STRING_AGG(FollowedPerson.Name, '->') WITHIN GROUP (GRAPH PATH),
		count(FollowedPerson.PersonId) WITHIN GROUP (GRAPH PATH) as Level
from   Network.Person as Person, Network.Follows for path as Follows, Network.Person for path as FollowedPerson
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(SHORTEST_PATH(Person(-(Follows)->FollowedPerson)+)) --highlight

 --The plus goes all the way to the end of the structure, but if you want to limit the level to 2, you can use this syntax

  --show everyone linked at level 1 or 2, along with their path
  select Person.Name as Person,
		LAST_VALUE(FollowedPerson.Name) WITHIN GROUP (GRAPH PATH) as ConnectedPerson,
		STRING_AGG(FollowedPerson.Name, '->') WITHIN GROUP (GRAPH PATH),
		count(FollowedPerson.PersonId) WITHIN GROUP (GRAPH PATH) as Level
from   Network.Person as Person, Network.Follows for path as Follows, Network.Person for path as FollowedPerson
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(SHORTEST_PATH(Person(-(Follows)->FollowedPerson){1,2})) --here

 --note that you can't do: 2,3, or you get the following error
 /*
 Msg 13942, Level 15, State 2, Line 556
The initial recursive quantifier must be 1: {1, ... }.
*/

---if you want 2 or 3 you can't use a having clause, you have to use a CTE

WITH BaseRows AS (
  select Person.Name as Person,
		LAST_VALUE(FollowedPerson.Name) WITHIN GROUP (GRAPH PATH) as ConnectedPerson,
		STRING_AGG(FollowedPerson.Name, '->') WITHIN GROUP (GRAPH PATH) as Path,
		count(FollowedPerson.PersonId) WITHIN GROUP (GRAPH PATH) as Level
from   Network.Person as Person, Network.Follows for path as Follows, Network.Person for path as FollowedPerson
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(SHORTEST_PATH(Person(-(Follows)->FollowedPerson){1,3})) --here
 ) 
 select *
 from   BaseRows
 where  Level Between 2 and 3


 --several filters will need to be handled in a CTE Like if you just want to see links from Lou Iss to Lee Roy

 WITH BaseRows AS (
  select Person.Name as Person,
		LAST_VALUE(FollowedPerson.Name) WITHIN GROUP (GRAPH PATH) as ConnectedPerson,
		STRING_AGG(FollowedPerson.Name, '->') WITHIN GROUP (GRAPH PATH) as Path,
		count(FollowedPerson.PersonId) WITHIN GROUP (GRAPH PATH) as Level
from   Network.Person as Person, Network.Follows for path as Follows, Network.Person for path as FollowedPerson
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(SHORTEST_PATH(Person(-(Follows)->FollowedPerson){1,3})) --here
 ) 
 select *
 from   BaseRows
 where  Level Between 2 and 3
    and  ConnectedPerson = 'Lee Roy' --probably ought to use a surrogate or name parts
                                   --here in production code