
use GraphDBTests
GO
set nocount on;
declare @startTime datetime2 = sysdatetime()

drop table if exists #holdResults
create table #holdResults
(
	CompanyId int,
	Name      varchar(20),
	TreeLevel Int,
	Hierarchy nvarchar(max)
)

declare @CompanyName varchar(20) = (select name from AdjacencyList.Company where parentCompanyId is null)

insert into #holdResults(CompanyId,Name, TreeLevel,Hierarchy)
exec AdjacencyList.Company$ReturnHierarchy_WHILELOOP @CompanyName

select @@rowCount, DATEDIFF(millisecond,@startTime, sysdatetime()) as Hierarchy_WHILELOOP_ExecutionMilliseconds
GO




set nocount on;
declare @startTime datetime2 = sysdatetime()

drop table if exists #holdResults
create table #holdResults
(
	CompanyId int,
	Name      varchar(20),
	TreeLevel Int,
	Hierarchy nvarchar(max)
)

declare @CompanyName varchar(20) = (select name from AdjacencyList.Company where parentCompanyId is null)

insert into #holdResults(CompanyId,Name, TreeLevel,Hierarchy)
exec AdjacencyList.Company$ReturnHierarchy_CTE @CompanyName

select @@rowCount, DATEDIFF(millisecond,@startTime, sysdatetime()) as Hierarchy_CTE_ExecutionMilliseconds
GO







--declare @startTime datetime2 = sysdatetime()

--drop table if exists #holdResults2
--create table #holdResults2
--(
--	CompanyId int,
--	ParentCompanyId int,
--	TotalSalesAmount numeric(38,2)
--)
--insert into #holdResults2(CompanyId, ParentCompanyId, TotalSalesAmount)
--exec AdjacencyList.Company$AggregateHierarchy_CTE 

--select @@rowCount, DATEDIFF(millisecond,@startTime, sysdatetime()) as Aggregate_CTE_ExecutionMilliseconds
--GO







