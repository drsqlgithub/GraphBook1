
USE HowToOptimizeAHierarchyInSQLServer;
GO

CREATE SCHEMA corporate;
GO
/*****************************************************
------------------------------------------------------
For all of the examples, I include the table, create 
based on the presentation example, and stored procedures
to insert a row, and reparent a row. All other operations
are generally just slight modification on thes operation
------------------------------------------------------
*****************************************************/

/********************
path method
********************/

CREATE SEQUENCE Company.CompanyPathMethod_SEQUENCE
AS int
START WITH 1
GO
CREATE TABLE Company.CompanyPathMethod
(
    companyId   int not null CONSTRAINT PKcompany3 primary key,
    name        varchar(20) not null CONSTRAINT AKcompany3_name UNIQUE,
    path		varchar(900) not null --allows 
);
create index Xpath on Company.CompanyPathMethod (path)
GO

CREATE PROCEDURE Company.CompanyPathMethod$insert(@name varchar(20), @parentCompanyName  varchar(20)) 
as --always inserts a root node
BEGIN
	--gets path, which looks like \key\key\...
	declare @parentPath varchar(900) = coalesce ((	select path
													from   Company.CompanyPathMethod
													where  name = @parentCompanyName),'\');
	--needn't use a sequence, but it made it easier to be able to do the next step 
	--in a single statement
	declare @newCompanyId int = NEXT VALUE FOR Company.CompanyPathMethod_SEQUENCE;

	--appends the new id to the parents path 
	INSERT INTO Company.CompanyPathMethod (companyId, name, path)
	SELECT @newCompanyId, @name, @parentPath + cast(@newCompanyId as varchar(10)) + '\'
END
GO
EXEC Company.CompanyPathMethod$insert @name = 'Company HQ', @parentCompanyName = NULL;
EXEC Company.CompanyPathMethod$insert @name = 'Maine HQ', @parentCompanyName = 'Company HQ';
EXEC Company.CompanyPathMethod$insert @name = 'Tennessee HQ', @parentCompanyName = 'Company HQ';
EXEC Company.CompanyPathMethod$insert @name = 'Nashville Branch', @parentCompanyName = 'Tennessee HQ';
EXEC Company.CompanyPathMethod$insert @name = 'Knoxville Branch', @parentCompanyName = 'Tennessee HQ';
EXEC Company.CompanyPathMethod$insert @name = 'Memphis Branch', @parentCompanyName = 'Tennessee HQ';
EXEC Company.CompanyPathMethod$insert @name = 'Portland Branch', @parentCompanyName = 'Maine HQ';
EXEC Company.CompanyPathMethod$insert @name = 'Camden Branch', @parentCompanyName = 'Maine HQ';

--GO

--you can see that the path uses the surrogate keys (which have little if any reason to change)
select *
from   Company.CompanyPathMethod
order by path


--get all nodes in the Tennessee Hierarchy, we use the path in a like comparison 
--(hence the index)
select *
from   Company.CompanyPathMethod
where  path like '\1\3\%'

--get all nodes under the Tennessee Hierarchy
select *
from   Company.CompanyPathMethod
where  path like '\1\3\_%' --the _ make sure that it isn't just the path of the 
                           --object

GO

--getting parents is a bit more difficult

--CREATE SCHEMA Tools;
--adapted from http://www.sommarskog.se/arrays-in-sql-2005.html - iter$simple_intlist_to_tbl
--and adapted from SQL Server 2008 Bible by Paul Nielsen et al
go
CREATE FUNCTION Tools.String$Parse (@list VARCHAR(200),@delimiter char(1) ='/') 
RETURNS @tbl TABLE ( id INT) 
AS 
  BEGIN 
      DECLARE @valuelen INT, 
              @pos      INT, 
              @nextpos  INT 

      SELECT @pos = 0, 
             @nextpos = 1 
	  
	  if left(@list,1) = @delimiter set @list = substring(@list,2,2000)
	  if left(reverse(@list),1) = @delimiter set @list = reverse(substring(reverse(@list),2,2000))

      WHILE @nextpos > 0 
        BEGIN 
            SELECT @nextpos = Charindex(@delimiter, @list, @pos + 1) 

            SELECT @valuelen = CASE 
                                 WHEN @nextpos > 0 THEN @nextpos 
                                 ELSE Len(@list) + 1 
                               END - @pos - 1 

            INSERT @tbl (id) 
            VALUES (Substring(@list, @pos + 1, @valuelen)) 

            SELECT @pos = @nextpos 
        END 

      RETURN 
  END  
go 

--parse based on the \ delimiter
select *
from   Tools.String$Parse('\1\2\3\4\','\')
GO


--get the parents of 1\3\4 (which will be id's, 1, 3, and 4, which is why
--the path uses the surrogate keys in the first place)
select *
from   Tools.String$Parse('\1\3\4\','\') as Ids
		  join Company.CompanyPathMethod
			on companyPathMethod.CompanyId = Ids.id
GO

--reparent Maine HQ to Child of Nashville

create procedure Company.CompanyPathMethod$reparent
    (
      @Location VARCHAR(20) ,
      @newParentLocation VARCHAR(20)
    )
as 
--reparenting is more or less just stuffing the new parent's path where the old parent's
--path was.. Stuff is used so you can don't have to worry with any issues with replace
declare @lenOldPath int = (	select len(path) --length of path to allow stuff to work
							from   Company.CompanyPathMethod
							where  name = @location),
		@newPath varchar(2000) = (  select path --path of new location 
									from   Company.CompanyPathMethod
									where  name = @newParentLocation),
		@newPathEnd varchar(10) = (	select cast(companyId as varchar(10))  --companyId and \ for end of new home path
							from   Company.CompanyPathMethod
							where  name = @location) + '\'

update Company.CompanyPathMethod 
	   --stuff new parent address into existing address, replacing old root path
set    path = stuff(path,1,@lenoldPath,@newPath + @newPathEnd) 
where  path like (	select path + '%' 
					from   Company.CompanyPathMethod
					where  name = @Location)
GO

select *
from   Company.CompanyPathMethod
order by path
GO

EXEC Company.CompanyPathMethod$reparent @Location = 'Maine HQ', @NewParentLocation = 'Nashville Branch'

select *
from   Company.CompanyPathMethod
order by path
GO


/********************
nested sets
********************/

CREATE TABLE Company.CompanyNestedSets
(
    companyId   int identity CONSTRAINT PKcompany4 primary key,
    name        varchar(20) CONSTRAINT AKcompany4_name UNIQUE,
	hierarchyLeft int,
	hierarchyRight int,
	unique (hierarchyLeft,hierarchyRight)
);  
GO


CREATE PROCEDURE Company.CompanyNestedSets$insert(@name varchar(20), @parentCompanyName  varchar(20)) 
as 
BEGIN
	SET NOCOUNT ON;
	BEGIN TRANSACTION

	if @parentCompanyName is NULL
	 begin
		if exists (select * from Company.CompanyNestedSets)
			THROW 50000,'More than one root node is not supported in this code',1;
		else
			insert into Company.CompanyNestedSets (name, hierarchyLeft, hierarchyRight)
			values (@name, 1,2)
	 end 
	 ELSE
	 BEGIN
		if not exists (select * from Company.CompanyNestedSets)
			THROW 50000,'You must start with a root node',1;

		--find the place in the hierarchy where you will add a node
		DECLARE @parentRight int = (select hierarchyRight from Company.CompanyNestedSets where name = @parentCompanyName)
	
		--make room for the nodes you are moving by moving left and right over by 2
		UPDATE Company.CompanyNestedSets 
		SET	   hierarchyLeft = companyNestedSets.hierarchyLeft + 2
		WHERE  hierarchyLeft > @parentRight

		UPDATE Company.CompanyNestedSets 
		SET	   hierarchyRight = companyNestedSets.hierarchyRight + 2
		WHERE  hierarchyRight >= @parentRight

		--insert the 
		INSERT Company.CompanyNestedSets (name, hierarchyLeft, hierarchyRight)
		SELECT @name, @parentRight, @parentRight + 1
	END

	commit transaction
END
GO

EXEC Company.CompanyNestedSets$insert @name = 'Company HQ', @parentCompanyName = NULL;
EXEC Company.CompanyNestedSets$insert @name = 'Maine HQ', @parentCompanyName = 'Company HQ';
EXEC Company.CompanyNestedSets$insert @name = 'Tennessee HQ', @parentCompanyName = 'Company HQ';
EXEC Company.CompanyNestedSets$insert @name = 'Nashville Branch', @parentCompanyName = 'Tennessee HQ';
EXEC Company.CompanyNestedSets$insert @name = 'Knoxville Branch', @parentCompanyName = 'Tennessee HQ';
EXEC Company.CompanyNestedSets$insert @name = 'Memphis Branch', @parentCompanyName = 'Tennessee HQ';
EXEC Company.CompanyNestedSets$insert @name = 'Portland Branch', @parentCompanyName = 'Maine HQ';
EXEC Company.CompanyNestedSets$insert @name = 'Camden Branch', @parentCompanyName = 'Maine HQ';

GO


select *, case when hierarchyLeft = hierarchyRight -1 then 1 else 0 end as leafNodeFlag
from   Company.CompanyNestedSets
order by hierarchyLeft
GO

--tennessee children, including parent (tenn hq is 8 and 15)
select *, case when hierarchyLeft = hierarchyRight -1 then 1 else 0 end as leafNodeFlag
from   Company.CompanyNestedSets
where  hierarchyLeft >= 8 and hierarchyRight <= 15
GO

--a bit more elequantly 
select *, case when hierarchyLeft = hierarchyRight -1 then 1 else 0 end as leafNodeFlag
from   Company.CompanyNestedSets
where  exists (select *
				from Company.CompanyNestedSets as startingPoint
				where companyNestedSets.hierarchyLeft >= startingPoint.hierarchyLeft
				  and companyNestedSets.hierarchyRight <= startingPoint.hierarchyRight
				  and startingPoint.name = 'Tennessee HQ')
GO

--a bit more elequantly 
select *, case when hierarchyLeft = hierarchyRight -1 then 1 else 0 end as leafNodeFlag
from   Company.CompanyNestedSets
where  exists (select *
				from Company.CompanyNestedSets as startingPoint
				where companyNestedSets.hierarchyLeft > startingPoint.hierarchyLeft
				  and companyNestedSets.hierarchyRight < startingPoint.hierarchyRight
				  and startingPoint.name = 'Tennessee HQ')
GO

--for parents, just reverse the GT and LT symbols
select *, case when hierarchyLeft = hierarchyRight -1 then 1 else 0 end as leafNodeFlag
from   Company.CompanyNestedSets
where  exists (select *
				from Company.CompanyNestedSets as startingPoint
				where companyNestedSets.hierarchyLeft <= startingPoint.hierarchyLeft
				  and companyNestedSets.hierarchyRight >= startingPoint.hierarchyRight
				  and startingPoint.name = 'Nashville Branch')
GO

--for parents only
select *, case when hierarchyLeft = hierarchyRight -1 then 1 else 0 end as leafNodeFlag
from   Company.CompanyNestedSets
where  exists (select *
				from Company.CompanyNestedSets as startingPoint
				where companyNestedSets.hierarchyLeft < startingPoint.hierarchyLeft
				  and companyNestedSets.hierarchyRight > startingPoint.hierarchyRight
				  and startingPoint.name = 'Nashville Branch')
GO

--get parents of camden branch
select *
from   Company.CompanyNestedSets as companyParent
		 join Company.CompanyNestedSets as companyChild
				on companyChild.hierarchyLeft between companyParent.hierarchyLeft and companyParent.hierarchyRight
where  companyChild.name = 'Camden Branch'
GO

--And for camden branch
select *, case when hierarchyLeft = hierarchyRight -1 then 1 else 0 end as leafNodeFlag
from   Company.CompanyNestedSets
where  exists (select *
				from Company.CompanyNestedSets as startingPoint
				where companyNestedSets.hierarchyLeft <= startingPoint.hierarchyLeft
				  and companyNestedSets.hierarchyRight >= startingPoint.hierarchyRight
				  and startingPoint.name = 'Camden Branch')
GO


create procedure Company.CompanyNestedSets$reparent
(
    @Location VARCHAR(20) ,
    @newParentLocation VARCHAR(20) 
) as
--freaky messy, may be an easier way, but I didn't see any examples online that were better!
if exists (select *
			from   Company.CompanyNestedSets
						join Company.CompanyNestedSets as searchFor
							on companyNestedSets.hierarchyLeft >= searchFor.hierarchyLeft 
							   and companyNestedSets.hierarchyRight <= searchFor.hierarchyRight
			where  searchFor.Name = @Location
			  and  companyNestedSets.name = @newParentLocation)
   BEGIN 
	     THROW 50000,'Cannot make a child node a node''s parent in a single pass. Move child node first',1;
	     Return 
   END

--do this work in a transaction. Lots of modifications
begin transaction

--get the information about the the nodes we are going to move, 
declare @numNodesToMove int, @startNode int 
SELECT @numNodesToMove = count(*),@startNode = min(searchFor.hierarchyLeft)  
from   Company.CompanyNestedSets
			join Company.CompanyNestedSets as searchFor
				on companyNestedSets.hierarchyLeft >= searchFor.hierarchyLeft 
					and companyNestedSets.hierarchyRight <= searchFor.hierarchyRight
where  searchFor.Name = @Location

--set the hierarchy values to -1 to remove them from the hierarchy. We'll put them back later
--in the process
UPDATE companyNestedSets
set    hierarchyLeft = -1 * companyNestedSets.hierarchyLeft,
	   hierarchyRight = -1 * companyNestedSets.hierarchyRight
from   Company.CompanyNestedSets
			join Company.CompanyNestedSets as searchFor
				on companyNestedSets.hierarchyLeft >= searchFor.hierarchyLeft 
				   and companyNestedSets.hierarchyRight <= searchFor.hierarchyRight
where  searchFor.Name = @Location

--refit the nodes to deal with the missing items. Now the positive values form a proper tree
UPDATE Company.CompanyNestedSets 
SET	   hierarchyLeft = companyNestedSets.hierarchyLeft - (@numNodesToMove * 2)
WHERE  hierarchyLeft >= @startNode

--done in seperate statements because of the largest hierarchyRight value
UPDATE Company.CompanyNestedSets 
SET	   hierarchyRight = companyNestedSets.hierarchyRight - (@numNodesToMove * 2)
WHERE  hierarchyRight >= @startNode


--get the position of the location where we are going to put the nodes we removed.
declare @targetLeft int, @targetRight int
select @targetLeft = hierarchyLeft, @targetRight = hierarchyRight
from   Company.CompanyNestedSets
where  name =  @newParentLocation

--make room for the nodes you are moving
UPDATE Company.CompanyNestedSets 
SET	   hierarchyLeft = companyNestedSets.hierarchyLeft + (@numNodesToMove * 2)
WHERE  hierarchyLeft > @targetLeft

UPDATE Company.CompanyNestedSets 
SET	   hierarchyRight = companyNestedSets.hierarchyRight + (@numNodesToMove * 2)
WHERE  hierarchyRight > @targetLeft

--get the offset that we will use to make the negative rows look like a proper negative hierarchy
declare @moveFactor int
select @moveFactor = abs(max(hierarchyLeft) + 1)
from   Company.CompanyNestedSets
where  hierarchyLeft < 0

--fix the negative rows to look like a proper hierarchy, 
update Company.CompanyNestedSets
set    hierarchyLeft = (hierarchyLeft + @moveFactor) , 
		hierarchyRight = (hierarchyRight + @moveFactor) 
where  hierarchyLeft < 0

--then place rows into hierarchy
update Company.CompanyNestedSets
set    hierarchyLeft = (abs(hierarchyLeft) + @targetLeft)
	   ,hierarchyRight = abs(hierarchyRight) + @targetLeft
where  hierarchyRight < 0

commit
go

select *, case when hierarchyLeft = hierarchyRight -1 then 1 else 0 end as leafNodeFlag
from   Company.CompanyNestedSets
order by hierarchyLeft
go

Company.CompanyNestedSets$reparent 'Maine HQ','Nashville Branch'
go
select *
from   Company.CompanyNestedSets
order by hierarchyLeft
go


/********************
kimball helper table
********************/


--reset the tree to original state
truncate table  Company.Company 
EXEC Company.Company$insert @name = 'Company HQ', @parentCompanyName = NULL;
EXEC Company.Company$insert @name = 'Maine HQ', @parentCompanyName = 'Company HQ';
EXEC Company.Company$insert @name = 'Tennessee HQ', @parentCompanyName = 'Company HQ';
EXEC Company.Company$insert @name = 'Nashville Branch', @parentCompanyName = 'Tennessee HQ';
EXEC Company.Company$insert @name = 'Knoxville Branch', @parentCompanyName = 'Tennessee HQ';
EXEC Company.Company$insert @name = 'Memphis Branch', @parentCompanyName = 'Tennessee HQ';
EXEC Company.Company$insert @name = 'Portland Branch', @parentCompanyName = 'Maine HQ';
EXEC Company.Company$insert @name = 'Camden Branch', @parentCompanyName = 'Maine HQ';
GO

create table Company.CompanyHiererarchyHelper
(
	ParentCompanyId	int, 
	ChildCompanyId  int, 
	Distance        int, 
	ParentRootNodeFlag bit, 
	ChildLeafNodeFlag  bit,
	CONSTRAINT PKcompanyHiererarchyHelper PRIMARY KEY (ParentCompanyId, ChildCompanyId)
)
GO
select *
from   Company.Company
GO

--returns all of the children for a given row, using the same algorithm as previously, with a few mods to 
--include the additional metadata
CREATE function Company.Company$returnHierarchyHelper
(@companyId int)
RETURNS @Output TABLE (ParentCompanyId int, ChildCompanyId int, Distance int, ParentRootNodeFlag bit, ChildLeafNodeFlag bit)
as
BEGIN
	;WITH companyHierarchy(companyId, parentCompanyId, treelevel, hierarchy)
	AS
	(
		 --gets the top level in hierarchy we want. The hierarchy column
		 --will show the row's place in the hierarchy from this query only
		 --not in the overall reality of the row's place in the table
		 SELECT companyID, parentCompanyId,
				1 as treelevel, CAST(companyId as varchar(max)) as hierarchy
		 FROM   Company.Company
		 WHERE companyId=@CompanyId

		 UNION ALL

		 --joins back to the CTE to recursively retrieve the rows 
		 --note that treelevel is incremented on each iteration
		 SELECT company.CompanyID, company.parentCompanyId,
				treelevel + 1 as treelevel,
				hierarchy + '\' +cast(company.CompanyId as varchar(20)) as hierarchy
		 FROM   Company.Company
				  INNER JOIN companyHierarchy
					--use to get children
					on company.parentCompanyId= companyHierarchy.CompanyID

	)
	--added to original tree example with distance, root and leaf node indicators
	insert into @Output (ParentCompanyId, ChildCompanyId, Distance, ParentRootNodeFlag, ChildLeafNodeFlag)
	select  @companyId as ParentCompanyId, companyHierarchy.CompanyId as ChildCompanyId, treeLevel - 1 as Distance,
										   case when exists(select *	
															from   Company.Company
															where  companyId = @companyId
															  and  parentCompanyId is null) then 1 else 0 end as ParentRootNodeFlag,
										   case when exists(select *	
															from   Company.Company
															where  company.ParentCompanyId = companyHierarchy.CompanyId
															  and  parentCompanyId is not null) then 0 else 1 end as ChildRootNodeFlag
	from   companyHierarchy

Return

END
GO
select * from Company.Company$returnHierarchyHelper (1)
--parent root node is about the parent, which for that call is always 1

select hierarchyHelper.ParentCompanyId, hierarchyHelper.ChildCompanyId, hierarchyHelper.Distance, 
	   hierarchyHelper.ParentRootNodeFlag, hierarchyHelper.ChildLeafNodeFlag
from   Company.Company
		cross apply Company.Company$returnHierarchyHelper(company.CompanyId) as hierarchyHelper
order by hierarchyHelper.ParentCompanyId


--save off the rows in the hierarchy helper table
insert into Company.CompanyHiererarchyHelper(
	ParentCompanyId, ChildCompanyId, Distance, ParentRootNodeFlag, ChildLeafNodeFlag
	)
select hierarchyHelper.ParentCompanyId, hierarchyHelper.ChildCompanyId, hierarchyHelper.Distance, 
	   hierarchyHelper.ParentRootNodeFlag, hierarchyHelper.ChildLeafNodeFlag
from   Company.Company
		cross apply Company.Company$returnHierarchyHelper(company.CompanyId) as hierarchyHelper

GO


--Children of Tennessee

select company.*, companyHiererarchyHelper.*
from   Company.CompanyHiererarchyHelper 
		 join Company.Company
			on company.CompanyId = companyHiererarchyHelper.ChildCompanyId
where  companyHiererarchyHelper.parentCompanyId = 
		(select companyId from Company.Company where name = 'Tennessee HQ')

--this works because the query of the hierarchy helper gives us a slice of the data.

select *
from   Company.CompanyHiererarchyHelper 
order by parentCompanyId


--get children of Tennessee HQ including HQ
select getNodes.*
from  Company.CompanyHiererarchyHelper --gets the hierarchy helper rows that are for the companyId that we searched for
		  join Company.Company as getNodes --the tree data as it relates to the node
			on getNodes.CompanyId = companyHiererarchyHelper.childCompanyId
where  exists ( select *
				from   Company.Company 
				where company.name = 'Tennessee HQ'
				  and companyHiererarchyHelper.parentCompanyId  = company.CompanyId)


--get children of Tennessee HQ not including HQ
select getNodes.*
from  Company.CompanyHiererarchyHelper --gets the hierarchy helper rows that are for the companyId that we searched for
		  join Company.Company as getNodes --the tree data as it relates to the node
			on getNodes.CompanyId = companyHiererarchyHelper.childCompanyId
where  exists ( select *
				from   Company.Company 
				where company.name = 'Tennessee HQ'
				  and companyHiererarchyHelper.parentCompanyId  = company.CompanyId
				  and companyHiererarchyHelper.childCompanyId  <> company.CompanyId)

--get children of Company HQ 
select getNodes.*
from  Company.CompanyHiererarchyHelper --gets the hierarchy helper rows that are for the companyId that we searched for
		  join Company.Company as getNodes --the tree data as it relates to the node
			on getNodes.CompanyId = companyHiererarchyHelper.childCompanyId
where  exists ( select *
				from   Company.Company 
				where company.name = 'Company HQ'
				  and companyHiererarchyHelper.parentCompanyId  = company.CompanyId)

--get children of Company HQ 
select getNodes.*
from  Company.CompanyHiererarchyHelper --gets the hierarchy helper rows that are for the companyId that we searched for
		  join Company.Company as getNodes --the tree data as it relates to the node
			on getNodes.CompanyId = companyHiererarchyHelper.childCompanyId
where  exists ( select *
				from   Company.Company 
				where company.name = 'Company HQ'
				  and companyHiererarchyHelper.parentCompanyId  = company.CompanyId)
   and  companyHiererarchyHelper.ChildLeafNodeFlag = 1

GO

--non leaf nodes
select getNodes.*
from  Company.CompanyHiererarchyHelper --gets the hierarchy helper rows that are for the companyId that we searched for
		  join Company.Company as getNodes --the tree data as it relates to the node
			on getNodes.CompanyId = companyHiererarchyHelper.childCompanyId
where  exists ( select *
				from   Company.Company 
				where company.name = 'Company HQ'
				  and companyHiererarchyHelper.parentCompanyId  = company.CompanyId)
   and  companyHiererarchyHelper.ChildLeafNodeFlag = 0


--No need for reparent, as the helper table represents a view of the data, not the actual structure in use.
--Reparent = complete rebuilt (at least of affected rows, but unless the structure is humongous,
--complete rebuild is perhpas easiest)