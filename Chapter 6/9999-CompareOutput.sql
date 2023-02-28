--I left this in in case you are messing with your code and want to do comparisons (especially if you are trying out nested sets, for example). Having an example output that you know works is really useful.

EXECUTE Helper.Company$ReportSales 'Node1'
GO
EXECUTE PathMethod.Company$ReportSales 'Node1'
GO
EXECUTE SqlGraph.Company$ReportSales 'Node1'
GO

select *
from  helper.HierarchyDisplayHelper


	