--CREATE DATABASE TestGraph;
--GO
USE TestGraph;
GO


--/* Network */
--if schema_id('Network') is null
--	exec ('CREATE SCHEMA Network');
--GO
----drop table Network.Person
----drop table network.Follows
--create table Network.Person
--(
--	PersonId int identity,
--	FirstName nvarchar(100) NULL,
--	LastName  nvarchar(100) NOT NULL,
--	Name as (CONCAT(FirstName+' ',LastName)),
--	Value int NOT NULL CONSTRAINT DFLTPerson_Value DEFAULT(1),
--	CONSTRAINT AKPerson UNIQUE (FirstName,LastName)
--) as NODE;

--create table Network.Follows
--(Value int NOT NULL CONSTRAINT DFLTFollows_Value DEFAULT(1))
--AS EDGE;

--CREATE  table Network.ProgrammingLanguage
--(
--	Name nvarchar(30) NOT NULL
--) as NODE;

--create table Network.ProgramsWith
--AS EDGE;




truncate table Network.Follows;
truncate table Network.ProgrammingLanguage
truncate table Network.ProgramsWith
truncate table Network.Person
GO
Insert into Network.Person(FirstName, LastName)
Values ('Fred','Rick'),('Lou','Iss'),('Val','Erry')
,('Lee','Roy'),('Will','Iam'),('Joe','Seph'),
('Day','Vid');

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
union all
select (select $node_id from Network.Person where FirstName = 'Fred' and LastName = 'Rick'),
	   (select $node_id from Network.Person where FirstName = 'Val' and LastName = 'Erry')
union all
select (select $node_id from Network.Person where FirstName = 'Day' and LastName = 'Vid'),
	   (select $node_id from Network.Person where FirstName = 'WIll' and LastName = 'Iam')

Insert Into Network.ProgrammingLanguage (Name)
VALUES ('C++'),('T-SQL'),('Fortran')

/*
Fred Rick C++
Lou Iss T-SQL
Val Erry Fortran, T-SQL
Lee Roy C++, Fortran
Will Iam Fortran
Joe Seph C++
*/

Insert into Network.ProgramsWith($from_id, $to_id)
select (select $node_id from Network.Person where FirstName = 'Lou' and LastName = 'Iss'),
	   (select $node_id from Network.ProgrammingLanguage where Name = 'T-SQL')
UNION ALL
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

select *
from   Network.ProgramsWith

select Person.Name as PersonName, 
	   FollowedPerson.Name as FollowedPersonName
from   Network.Person, Network.Follows, Network.Person as FollowedPerson
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(Person-(Follows)->FollowedPerson)

 select Person.Name as Person, 
		FollowedPerson.Name as FollowedBy
from   Network.Person, Network.Follows, Network.Person as FollowedPerson
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(Person<-(Follows)-FollowedPerson)
go




 select Person.Name as Person,
		--can't just do this
		FollowedPerson.Name as Follows
from   Network.Person as Person, Network.Follows for path as Follows, Network.Person for path as FollowedPerson 
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(SHORTEST_PATH(Person(-(Follows)->FollowedPerson)+))

 /*
 Msg 13961, Level 16, State 1, Line 3
The alias or identifier 'FollowedPerson.Name' cannot be used in the select list, order by, group by, or having context.
*/
go
--showing how you can do LAST_VALUE to multiple columns
 select Person.Name as Person,
		LAST_VALUE(FollowedPerson.Firstname) WITHIN GROUP (GRAPH PATH),
		LAST_VALUE(FollowedPerson.LastName) WITHIN GROUP (GRAPH PATH)
from   Network.Person as Person, Network.Follows for path as Follows, Network.Person for path as FollowedPerson 
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(SHORTEST_PATH(Person(-(Follows)->FollowedPerson)+))


 select Person.Name as Person,
		CONCAT(
		LAST_VALUE(FollowedPerson.Firstname) WITHIN GROUP (GRAPH PATH),' ',
		LAST_VALUE(FollowedPerson.LastName) WITHIN GROUP (GRAPH PATH)) as ConnectedPerson,
		LAST_VALUE(FollowedPerson.Name) WITHIN GROUP (GRAPH PATH) as ConnectedPerson2
from   Network.Person as Person, Network.Follows for path as Follows, Network.Person for path as FollowedPerson 
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(SHORTEST_PATH(Person(-(Follows)->FollowedPerson)+))

  select Person.Name as Person,
		LAST_VALUE(FollowedPerson.Name) WITHIN GROUP (GRAPH PATH) as ConnectedPerson,
		COUNT(FollowedPerson.PersonId) WITHIN GROUP (GRAPH PATH) as Level
from   Network.Person as Person, Network.Follows for path as Follows, Network.Person for path as FollowedPerson 
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(SHORTEST_PATH(Person(-(Follows)->FollowedPerson)+))

  select Person.Name as Person,
		LAST_VALUE(FollowedPerson.Name) WITHIN GROUP (GRAPH PATH) as ConnectedPerson,
		COUNT(FollowedPerson.PersonId) WITHIN GROUP (GRAPH PATH) as Level,
		STRING_AGG(FollowedPerson.Name, '->') WITHIN GROUP (GRAPH PATH)
from   Network.Person as Person, Network.Follows for path as Follows, Network.Person for path as FollowedPerson 
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(SHORTEST_PATH(Person(-(Follows)->FollowedPerson)+))



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

 --the point here is that the aggregate aggregates this way

 --fetch the edge and the next node. So aggregates do not include the starting point

  select Person.Name as Person,
		LAST_VALUE(FollowedPerson.Name) WITHIN GROUP (GRAPH PATH) as ConnectedPerson,
		STRING_AGG(FollowedPerson.Name, '->') WITHIN GROUP (GRAPH PATH)
from   Network.Person as Person, Network.Follows for path as Follows, Network.Person for path as FollowedPerson
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(SHORTEST_PATH(Person(-(Follows)->FollowedPerson)+))
 go

 

--show everyone linked at any level, along with their path
  select Person.Name as Person,
		LAST_VALUE(FollowedPerson.Name) WITHIN GROUP (GRAPH PATH) as ConnectedPerson,
		STRING_AGG(FollowedPerson.Name, '->') WITHIN GROUP (GRAPH PATH),
		count(FollowedPerson.PersonId) WITHIN GROUP (GRAPH PATH) as Level
from   Network.Person as Person, Network.Follows for path as Follows, Network.Person for path as FollowedPerson
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(SHORTEST_PATH(Person(-(Follows)->FollowedPerson)+))

 --show everyone linked at level 1 or 2, along with their path
  select Person.Name as Person,
		LAST_VALUE(FollowedPerson.Name) WITHIN GROUP (GRAPH PATH) as ConnectedPerson,
		STRING_AGG(FollowedPerson.Name, '->') WITHIN GROUP (GRAPH PATH),
		count(FollowedPerson.PersonId) WITHIN GROUP (GRAPH PATH) as Level
from   Network.Person as Person, Network.Follows for path as Follows, Network.Person for path as FollowedPerson
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(SHORTEST_PATH(Person(-(Follows)->FollowedPerson){1,2})) --here



 --show the people that have programming language connections
 select person.name as PersonName, programmingLanguage.name as ProgrammingLanguage
 from   Network.Person, Network.ProgramsWIth, Network.ProgrammingLanguage
 where match(person-(ProgramsWith)->ProgrammingLanguage)


 --fred rick drops out because he does not have a programming language link
  select Person.Name as Person,
		LAST_VALUE(FollowedPerson.Name) WITHIN GROUP (GRAPH PATH) as ConnectedPerson,
		ProgrammingLanguage.Name,
		CONCAT(Person.FirstName,' ', Person.LastName) + '->' +  STRING_AGG(FollowedPerson.Name, '->') WITHIN GROUP (GRAPH PATH)
from   Network.Person as Person, Network.Follows for path as Follows, Network.Person for path as FollowedPerson,
		Network.ProgramsWith as ProgramsWith, Network.ProgrammingLanguage 
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(SHORTEST_PATH(Person(-(Follows)->FollowedPerson)+) 
 AND LAST_NODE(FollowedPerson)-(ProgramsWith)->ProgrammingLanguage)


 --Now we are finding someone that we are connected to at any level
 --that programs in C++
  select Person.Name as Person,
		LAST_VALUE(FollowedPerson.Name) WITHIN GROUP (GRAPH PATH) as ConnectedPerson,
		ProgrammingLanguage.Name,
		Person.Name, + '->' +  STRING_AGG(FollowedPerson.Name, '->') WITHIN GROUP (GRAPH PATH)
from   Network.Person as Person, Network.Follows for path as Follows, Network.Person for path as FollowedPerson,
		Network.ProgramsWith as ProgramsWith, Network.ProgrammingLanguage 
where  Person.FirstName = 'Lou' and Person.LastName = 'Iss'
 and   MATCH(SHORTEST_PATH(Person(-(Follows)->FollowedPerson)+) 
                    AND LAST_NODE(FollowedPerson)-(ProgramsWith)->ProgrammingLanguage)
 and  ProgrammingLanguage.Name  = 'C++'




-- SELECT
--	Person1.name AS PersonName,
--	STRING_AGG(Person2.name, '->') WITHIN GROUP (GRAPH PATH) AS Friends,
--	Restaurant.name
--FROM
--	Person AS Person1,
--	friendOf FOR PATH AS fo,
--	Person FOR PATH  AS Person2,
--	likes,
--	Restaurant
--WHERE MATCH(SHORTEST_PATH(Person1(-(fo)->Person2){1,3}) AND LAST_NODE(Person2)-(likes)->Restaurant )
--AND Person1.name = 'Jacob'


--multiple match conditions, done 3 different ways
  select Person.Name as Person, Person2.Name as Person2,
	   ProgrammingLanguage.Name
from   Network.Person as Person, 
       Network.Person as Person2,
		Network.ProgramsWith as ProgramsWith, 
		Network.ProgrammingLanguage as ProgrammingLanguage,
		Network.ProgramsWith as ProgramsWith2 

where Match(Person-(ProgramsWith)->ProgrammingLanguage<-(ProgramsWith2)-Person2)
 and person2.personId <> Person.personId
order by 1

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
ORDER BY 1

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


  select FromPerson.Name as FromPerson1,

		STRING_AGG(FollowedPerson.Name, '->') WITHIN GROUP (GRAPH PATH),


 LAST_VALUE(FollowedPerson.Name) WITHIN GROUP (GRAPH PATH) AS lastnode1,
	   
      FromPerson2.Name,
 		STRING_AGG(FollowedPerson2.Name, '->') WITHIN GROUP (GRAPH PATH),

 LAST_VALUE(FollowedPerson.Name)
      WITHIN GROUP (GRAPH PATH) AS lastnode1
	  ,*

from   Network.Person as FromPerson,
		Network.Person as FromPerson2,
       Network.Person FOR PATH as FollowedPerson,
	   Network.Person FOR PATH as FollowedPerson2,
	   Network.Follows FOR PATH AS Follows,
	   Network.Follows FOR PATH AS Follows2
WHERE MATCH(SHORTEST_PATH(FromPerson(-(Follows)->FollowedPerson)+)	
  AND SHORTEST_PATH(FromPerson2(-(Follows2)->FollowedPerson2)+)
  and last_node(FollowedPerson) = Last_node(FollowedPerson2)) --this joins mulitple paths
  and FromPerson.FirstName = 'Day' and FromPerson.LastName = 'Vid'
  and FromPerson2.FirstName = 'Lou' and FromPerson2.LastName = 'Iss'