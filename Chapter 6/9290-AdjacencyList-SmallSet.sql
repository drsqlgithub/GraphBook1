
--------------------
USE GraphDBTests
GO


------------------
SET NOCOUNT ON
GO
IF OBJECT_ID('AdjacencyList.DataSetStats','U') is null
 CREATE TABLE AdjacencyList.DataSetStats(
	TestSetName nvarchar(20) NOT NULL,
	CompanyCount Int
);
TRUNCATE TABLE AdjacencyList.DataSetStats;
GO

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


DELETE AdjacencyList.Sale
DELETE AdjacencyList.Company 
DBCC CHECKIDENT ('AdjacencyList.Sale',RESEED,0)
DBCC CHECKIDENT ('AdjacencyList.Company',RESEED,0)
ALTER SEQUENCE AdjacencyList.CompanyDataGenerator_SEQUENCE RESTART
GO

DROP TABLE IF EXISTS #holdTiming;
SELECT GETDATE() AS CheckInTime
INTO  #holdTiming;

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
EXEC AdjacencyList.Company$Insert @Name = 'Company HQ', @ParentCompanyName = NULL;

EXEC AdjacencyList.Company$Insert @Name = 'Maine HQ', @ParentCompanyName = 'Company HQ';

EXEC AdjacencyList.Company$Insert @Name = 'Tennessee HQ', @ParentCompanyName = 'Company HQ';

EXEC AdjacencyList.Company$Insert @Name = 'Nashville Branch', @ParentCompanyName = 'Tennessee HQ';
GO
EXEC AdjacencyList.Sale$InsertTestData @Name = 'Nashville Branch';
GO
EXEC AdjacencyList.Company$Insert @Name = 'Knoxville Branch', @ParentCompanyName = 'Tennessee HQ';

EXEC AdjacencyList.Sale$InsertTestData @Name = 'Knoxville Branch';

EXEC AdjacencyList.Company$Insert @Name = 'Memphis Branch', @ParentCompanyName = 'Tennessee HQ';

EXEC AdjacencyList.Sale$InsertTestData @Name = 'Memphis Branch';

EXEC AdjacencyList.Company$Insert @Name = 'Portland Branch', @ParentCompanyName = 'Maine HQ';

EXEC AdjacencyList.Sale$InsertTestData @Name = 'Portland Branch';

EXEC AdjacencyList.Company$Insert @Name = 'Camden Branch', @ParentCompanyName = 'Maine HQ';

EXEC AdjacencyList.Sale$InsertTestData @Name = 'Camden Branch';
GO

INSERT INTO #holdTiming (CheckInTime)
SELECT GETDATE() AS CheckInTime
GO
SELECT CONCAT(DATEDIFF(millisecond,MIN(CheckInTime), MAX(CheckInTime)) / 1000.0,' Seconds')
from #holdTiming
GO
INSERT INTO AdjacencyList.DataSetStats(TestSetName, CompanyCount)
SELECT 'SmallSet',COUNT(*)
FROM   AdjacencyList.Company;
GO
SELECT *
from   AdjacencyList.DataSetStats;