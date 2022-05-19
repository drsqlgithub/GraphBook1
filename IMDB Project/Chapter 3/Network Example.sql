--CREATE DATABASE TestGraph;
--GO
USE TestGraph;
GO


/* Network */
if schema_id('Network') is null
	exec ('CREATE SCHEMA Network');
GO
--drop table Network.Person
--drop table network.Follows
create table Network.Person
(
	PersonId int identity,
	FirstName nvarchar(100) NULL,
	LastName  nvarchar(100) NOT NULL,
	Value int NOT NULL CONSTRAINT DFLTPerson_Value DEFAULT(1),
	CONSTRAINT AKPerson UNIQUE (FirstName,LastName)
) as NODE;

create table Network.Follows
(Value int NOT NULL CONSTRAINT DFLTFollows_Value DEFAULT(1))
AS EDGE;



truncate table Network.Person
truncate table Network.Follows;
Insert into Network.Person(FirstName, LastName)
Values ('Fred','Rick'),('Lou','Iss'),('Val','Erry'),('Lee','Roy'),('Will','Iam'),('Joe','Seph');

insert into Network.Follows($From_id, $To_id)
select (select $node_id from Network.Person where FirstName = 'fred' and LastName = 'Rick'),
	   (select $node_id from Network.Person where FirstName = 'Joe' and LastName = 'Seph')
union all
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

select CONCAT(Person.FirstName,' ', Person.LastName) as Person, 
		CONCAT(FollowedPerson.FirstName,' ',FollowedPerson.LastName) as Follows
from   Network.Person, Network.Follows, Network.Person as FollowedPerson
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(Person-(Follows)->FollowedPerson)

 select CONCAT(Person.FirstName,' ', Person.LastName) as Person, 
		CONCAT(FollowedPerson.FirstName,' ',FollowedPerson.LastName) as FollowedBy
from   Network.Person, Network.Follows, Network.Person as FollowedPerson
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(Person<-(Follows)-FollowedPerson)





 select CONCAT(Person.FirstName,' ', Person.LastName) as Person,
		--can't just do this
		CONCAT(FollowedPerson.FirstName,' ',FollowedPerson.LastName) as Follows
from   Network.Person as Person, Network.Follows for path as Follows, Network.Person for path as FollowedPerson 
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(SHORTEST_PATH(Person(-(Follows)->FollowedPerson)+))

 /*
 Msg 13961, Level 16, State 1, Line 3
The alias or identifier 'FollowedPerson.FirstName' cannot be used in the select list, order by, group by, or having context.
Msg 13961, Level 16, State 1, Line 3
The alias or identifier 'FollowedPerson.LastName' cannot be used in the select list, order by, group by, or having context.
*/
 select CONCAT(Person.FirstName,' ', Person.LastName) as Person,
		LAST_VALUE(FollowedPerson.Firstname) WITHIN GROUP (GRAPH PATH),
		LAST_VALUE(FollowedPerson.LastName) WITHIN GROUP (GRAPH PATH)
from   Network.Person as Person, Network.Follows for path as Follows, Network.Person for path as FollowedPerson 
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(SHORTEST_PATH(Person(-(Follows)->FollowedPerson)+))


 select CONCAT(Person.FirstName,' ', Person.LastName) as Person,
		CONCAT(
		LAST_VALUE(FollowedPerson.Firstname) WITHIN GROUP (GRAPH PATH),' ',
		LAST_VALUE(FollowedPerson.LastName) WITHIN GROUP (GRAPH PATH)) as ConnectedPerson
from   Network.Person as Person, Network.Follows for path as Follows, Network.Person for path as FollowedPerson 
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(SHORTEST_PATH(Person(-(Follows)->FollowedPerson)+))

  select CONCAT(Person.FirstName,' ', Person.LastName) as Person,
		CONCAT(
		LAST_VALUE(FollowedPerson.Firstname) WITHIN GROUP (GRAPH PATH),' ',
		LAST_VALUE(FollowedPerson.LastName) WITHIN GROUP (GRAPH PATH)) as ConnectedPerson,
		COUNT(FollowedPerson.PersonId) WITHIN GROUP (GRAPH PATH) as Level
from   Network.Person as Person, Network.Follows for path as Follows, Network.Person for path as FollowedPerson 
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(SHORTEST_PATH(Person(-(Follows)->FollowedPerson)+))

  select CONCAT(Person.FirstName,' ', Person.LastName) as Person,
		CONCAT(
		LAST_VALUE(FollowedPerson.Firstname) WITHIN GROUP (GRAPH PATH),' ',
		LAST_VALUE(FollowedPerson.LastName) WITHIN GROUP (GRAPH PATH)) as ConnectedPerson,
		COUNT(FollowedPerson.PersonId) WITHIN GROUP (GRAPH PATH) as Level,
		STRING_AGG(CONCAT(FollowedPerson.FirstName,' ',FollowedPerson.LastName), '->') WITHIN GROUP (GRAPH PATH)
from   Network.Person as Person, Network.Follows for path as Follows, Network.Person for path as FollowedPerson 
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(SHORTEST_PATH(Person(-(Follows)->FollowedPerson)+))



select CONCAT(Person.FirstName,' ', Person.LastName) as Person,
		CONCAT(
		LAST_VALUE(FollowedPerson.Firstname) WITHIN GROUP (GRAPH PATH),' ',
		LAST_VALUE(FollowedPerson.LastName) WITHIN GROUP (GRAPH PATH)) as ConnectedPerson,
		COUNT(FollowedPerson.PersonId) WITHIN GROUP (GRAPH PATH) as Level,
		STRING_AGG(CONCAT(FollowedPerson.FirstName,' ',FollowedPerson.LastName), '->') WITHIN GROUP (GRAPH PATH),
		SUM(FollowedPerson.Value) WITHIN GROUP (GRAPH PATH) as SumNodeValues,
		--NOTE: Figure out why this is equal. More are being included or not enoiugh
		SUM(Follows.Value) WITHIN GROUP (GRAPH PATH) as SumEdgeValues
from   Network.Person as Person, Network.Follows for path as Follows, Network.Person for path as FollowedPerson 
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(SHORTEST_PATH(Person(-(Follows)->FollowedPerson)+))

 select CONCAT(Person.FirstName,' ', Person.LastName) as Person,
		CONCAT(
		LAST_VALUE(FollowedPerson.Firstname) WITHIN GROUP (GRAPH PATH),' ',
		LAST_VALUE(FollowedPerson.LastName) WITHIN GROUP (GRAPH PATH)) as ConnectedPerson,
		COUNT(FollowedPerson.PersonId) WITHIN GROUP (GRAPH PATH) as Level,
		STRING_AGG(CONCAT(FollowedPerson.FirstName,' ',FollowedPerson.LastName), '->') WITHIN GROUP (GRAPH PATH),
		SUM(FollowedPerson.Value) WITHIN GROUP (GRAPH PATH) as SumNodeValues,
		--NOTE: Figure out why this is equal. More are being included or not enoiugh
		SUM(Follows.Value) WITHIN GROUP (GRAPH PATH) as SumEdgeValues,
		STRING_AGG(CONCAT(FollowedPerson.FirstName,' ',FollowedPerson.LastName, ' Node:',FollowedPerson.Value), '->') WITHIN GROUP (GRAPH PATH),
		STRING_AGG(CONCAT(FollowedPerson.FirstName,' ',FollowedPerson.LastName, ' EdgeValue:',Follows.Value), '->') WITHIN GROUP (GRAPH PATH)
from   Network.Person as Person, Network.Follows for path as Follows, Network.Person for path as FollowedPerson 
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(SHORTEST_PATH(Person(-(Follows)->FollowedPerson)+))

 --the point here is that the aggregate aggregates this way

 --fetch the edge and the next node. So aggregates do not include the starting point

