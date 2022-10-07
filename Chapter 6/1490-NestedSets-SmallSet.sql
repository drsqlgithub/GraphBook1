
--------------------
USE GraphDBTests
GO


------------------
SET NOCOUNT ON
GO


----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

IF OBJECT_ID('GappedNestedSets.DataSetStats','U') is null
 CREATE TABLE GappedNestedSets.DataSetStats(
	TestSetName nvarchar(20) NOT NULL,
	CompanyCount Int
);
TRUNCATE TABLE GappedNestedSets.DataSetStats;
GO



DELETE GappedNestedSets.Sale
DELETE GappedNestedSets.Company 
DBCC CHECKIDENT ('GappedNestedSets.Sale',RESEED,0)
--DBCC CHECKIDENT ('GappedNestedSets.Company',RESEED,0)
ALTER SEQUENCE GappedNestedSets.CompanyDataGenerator_SEQUENCE RESTART
GO

DROP TABLE IF EXISTS #holdTiming;
SELECT GETDATE() AS CheckInTime
INTO  #holdTiming;

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
EXEC GappedNestedSets.Company$Insert @Name = 'Company HQ', @ParentCompanyName = NULL;

EXEC GappedNestedSets.Company$Insert @Name = 'Maine HQ', @ParentCompanyName = 'Company HQ';

EXEC GappedNestedSets.Company$Insert @Name = 'Tennessee HQ', @ParentCompanyName = 'Company HQ';

EXEC GappedNestedSets.Company$Insert @Name = 'Nashville Branch', @ParentCompanyName = 'Tennessee HQ';
GO
EXEC GappedNestedSets.Sale$InsertTestData @Name = 'Nashville Branch';
GO
EXEC GappedNestedSets.Company$Insert @Name = 'Knoxville Branch', @ParentCompanyName = 'Tennessee HQ';

EXEC GappedNestedSets.Sale$InsertTestData @Name = 'Knoxville Branch';

EXEC GappedNestedSets.Company$Insert @Name = 'Memphis Branch', @ParentCompanyName = 'Tennessee HQ';

EXEC GappedNestedSets.Sale$InsertTestData @Name = 'Memphis Branch';

EXEC GappedNestedSets.Company$Insert @Name = 'Portland Branch', @ParentCompanyName = 'Maine HQ';

EXEC GappedNestedSets.Sale$InsertTestData @Name = 'Portland Branch';

EXEC GappedNestedSets.Company$Insert @Name = 'Camden Branch', @ParentCompanyName = 'Maine HQ';

EXEC GappedNestedSets.Sale$InsertTestData @Name = 'Camden Branch';
GO


INSERT INTO GappedNestedSets.DataSetStats(TestSetName, CompanyCount)
SELECT 'SmallSet',COUNT(*)
FROM   GappedNestedSets.Company;
GO


--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

INSERT INTO #holdTiming (CheckInTime)
SELECT GETDATE() AS CheckInTime
GO
SELECT CONCAT(DATEDIFF(millisecond,MIN(CheckInTime), MAX(CheckInTime)) / 1000.0,' Seconds')
from #holdTiming
GO
SELECT *
from   GappedNestedSets.DataSetStats;

