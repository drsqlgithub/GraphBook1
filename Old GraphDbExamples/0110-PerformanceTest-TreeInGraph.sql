set statistics time, io on

GO
use GraphDBTests
GO
set nocount on;
declare @startTime datetime2 = sysdatetime()

drop table if exists #holdResults1
create table #holdResults1
(
	CompanyId int,
	Name      varchar(20),
	TreeLevel Int,
	Hierarchy nvarchar(max)
)

declare @CompanyName varchar(20) = (select name from TreeInGraph.Company where Name = 'Node1')

insert into #holdResults1(CompanyId,Name, TreeLevel,Hierarchy)
exec TreeInGraph.Company$ReturnHierarchy_WHILELOOP @CompanyName

select @@rowCount, DATEDIFF(millisecond,@startTime, sysdatetime()) as Hierarchy_WHILELOOP_ExecutionMilliseconds
GO

select top 1 *
from   sys.objects
GO
set nocount on;
declare @startTime datetime2 = sysdatetime()

drop table if exists #holdResults2
create table #holdResults2
(
	CompanyId int,
	Name      varchar(20),
	TreeLevel Int,
	Hierarchy nvarchar(max)
)

declare @CompanyName varchar(20) = (select name from TreeInGraph.Company where Name = 'Node1')

insert into #holdResults2(CompanyId,Name, TreeLevel,Hierarchy)
exec TreeInGraph.Company$ReturnHierarchy_CTE @CompanyName

select @@rowCount, DATEDIFF(millisecond,@startTime, sysdatetime()) as Hierarchy_CTE_ExecutionMilliseconds
GO


select top 1 *
from   sys.objects
GO
set nocount on;
declare @startTime datetime2 = sysdatetime()

drop table if exists #holdResults3
create table #holdResults3
(
	CompanyId int,
	Name      varchar(20),
	TreeLevel Int,
	Hierarchy nvarchar(max)
)

declare @CompanyName varchar(20) = (select name from TreeInGraph.Company where Name = 'Node1')

insert into #holdResults3(CompanyId,Name, TreeLevel,Hierarchy)
exec TreeInGraph.Company$ReturnHierarchy_SHORTESTPATH @CompanyName

select @@rowCount, DATEDIFF(millisecond,@startTime, sysdatetime()) as Hierarchy_ShortestPath_ExecutionMilliseconds
GO
--Test The results
select *
from   #holdResults2
		 full outer join #holdResults3
			on #holdResults2.CompanyId = #holdResults3.CompanyId
			   and #holdResults2.Name = #holdResults3.Name
			   and #holdResults2.TreeLevel = #holdResults3.TreeLevel
			   and #holdResults2.Hierarchy= #holdResults3.Hierarchy
where #holdResults2.CompanyId is null or #holdResults3.CompanyId is null


select *
from   #holdResults1 
		 full outer join #holdResults3
			on #holdResults1.CompanyId = #holdResults3.CompanyId
			   and #holdResults1.Name = #holdResults3.Name
			   and #holdResults1.TreeLevel = #holdResults3.TreeLevel
			   and #holdResults1.Hierarchy= #holdResults3.Hierarchy
where #holdResults1.CompanyId is null or #holdResults3.CompanyId is null










--declare @startTime datetime2 = sysdatetime()

--drop table if exists #holdResults2
--create table #holdResults2
--(
--	CompanyId int,
--	ParentCompanyId int,
--	TotalSalesAmount numeric(38,2)
--)
--insert into #holdResults2(CompanyId, ParentCompanyId, TotalSalesAmount)
--exec TreeInGraph.Company$AggregateHierarchy_CTE 

--select @@rowCount, DATEDIFF(millisecond,@startTime, sysdatetime()) as Aggregate_CTE_ExecutionMilliseconds
--GO







