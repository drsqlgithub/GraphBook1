Use GraphDBTests;
GO
DROP TABLE IF EXISTS #holdTiming;
DROP TABLE IF EXISTS Helper.DataSetStats
SELECT GETDATE() AS CheckInTime
INTO  #holdTiming;

EXEC Helper.HierarchyDisplayHelper$Rebuild;
EXEC Helper.CompanyHierarchyHelper$Rebuild;

 SELECT 'Helper' as TestSetName,CompanyCount
 into   Helper.DataSetStats
 from  SQLGraph.DataSetStats

INSERT INTO #holdTiming (CheckInTime)
SELECT GETDATE() AS CheckInTime
GO
SELECT CONCAT(DATEDIFF(millisecond,MIN(CheckInTime), MAX(CheckInTime)) / 1000.0,' Seconds')
from #holdTiming
select *
from   Helper.DataSetStats