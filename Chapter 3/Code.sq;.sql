alter database TestGraph set single_user with rollback immediate
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

$edge_id_3E64B3D47C09432595C25D1FB2146A35                  
-----------------------------------------------------------
{"type":"edge","schema":"Network","table":"Follows","id":0}

 $from_id_AA09B7FBEA714F918B3C0D19A8B24A0A                 
 ----------------------------------------------------------
 {"type":"node","schema":"Network","table":"Person","id":0}

 $to_id_4E49D534C24E4F4D8E0E0D207237A425                   
 ----------------------------------------------------------
 {"type":"node","schema":"Network","table":"Person","id":5}



--then the rest of the rows
insert into Network.Follows($From_id, $To_id)
select (select $node_id from Network.Person where FirstName = 'fred' and LastName = 'Rick'),
	   (select $node_id from Network.Person where FirstName = 'Lou' and LastName = 'Iss')
union all
select (select $node_id from Network.Person where FirstName = 'Joe' and LastName = 'Seph'),
	   (select $node_id from Network.Person where FirstName = 'Will' and LastName = 'Iam')
union all
select (select $node_id from Network.Person where FirstName = 'Lee' and LastName = 'Roy'),
	   (select $node_id from Network.Person where FirstName = 'Will' and LastName = 'Iam')
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

SELECT Person.Name as PersonName, 
	   FollowedPerson.Name as FollowedPersonName
from   Network.Person
	    join Network.Follows
			on Person.$node_id = Follows.$from_id
		join Network.Person as FollowedPerson
			on FollowedPerson.$node_id = Follows.$to_id
/*
PersonName           FollowedPersonName
-------------------- -------------------
Fred Rick            Joe Seph
Fred Rick            Lou Iss
Joe Seph             Will Iam
Lee Roy              Will Iam
Val Erry             Joe Seph
Val Erry             Lee Roy
Lou Iss              Will Iam
Lou Iss              Val Erry
Will Iam             Fred Rick
Fred Rick            Val Erry
Day Vid              Will Iam

This will match all the lines in Figure 1

--briefly explaing the basic MATCH operator
*/
select cast(Person.Name as nvarchar(20)) as PersonName, 
	   FollowedPerson.Name as FollowedPersonName
from   Network.Person, Network.Follows, Network.Person as FollowedPerson
where  MATCH(Person-(Follows)->FollowedPerson)
--same output, probably sorted differentl

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