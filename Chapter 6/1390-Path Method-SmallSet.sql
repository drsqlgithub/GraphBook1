
--------------------
USE GraphDBTests
GO


------------------
SET NOCOUNT ON
GO


----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

IF OBJECT_ID('PathMethod.DataSetStats','U') is null
 CREATE TABLE PathMethod.DataSetStats(
	TestSetName nvarchar(20) NOT NULL,
	CompanyCount Int
);
TRUNCATE TABLE PathMethod.DataSetStats;
GO


DELETE PathMethod.Sale
DELETE PathMethod.Company 
DBCC CHECKIDENT ('PathMethod.Sale',RESEED,0)
--DBCC CHECKIDENT ('PathMethod.Company',RESEED,0)
ALTER SEQUENCE PathMethod.CompanyDataGenerator_SEQUENCE RESTART
ALTER SEQUENCE PathMethod.Company_SEQUENCE RESTART
GO

DROP TABLE IF EXISTS #holdTiming;
SELECT GETDATE() AS CheckInTime
INTO  #holdTiming;

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
EXEC PathMethod.Company$Insert @Name = 'Company HQ', @ParentCompanyName = NULL;

EXEC PathMethod.Company$Insert @Name = 'Maine HQ', @ParentCompanyName = 'Company HQ';

EXEC PathMethod.Company$Insert @Name = 'Tennessee HQ', @ParentCompanyName = 'Company HQ';

EXEC PathMethod.Company$Insert @Name = 'Nashville Branch', @ParentCompanyName = 'Tennessee HQ';
GO
EXEC PathMethod.Sale$InsertTestData @Name = 'Nashville Branch';
GO
EXEC PathMethod.Company$Insert @Name = 'Knoxville Branch', @ParentCompanyName = 'Tennessee HQ';

EXEC PathMethod.Sale$InsertTestData @Name = 'Knoxville Branch';

EXEC PathMethod.Company$Insert @Name = 'Memphis Branch', @ParentCompanyName = 'Tennessee HQ';

EXEC PathMethod.Sale$InsertTestData @Name = 'Memphis Branch';

EXEC PathMethod.Company$Insert @Name = 'Portland Branch', @ParentCompanyName = 'Maine HQ';

EXEC PathMethod.Sale$InsertTestData @Name = 'Portland Branch';

EXEC PathMethod.Company$Insert @Name = 'Camden Branch', @ParentCompanyName = 'Maine HQ';

EXEC PathMethod.Sale$InsertTestData @Name = 'Camden Branch';
GO

INSERT INTO PathMethod.DataSetStats(TestSetName, CompanyCount)
SELECT 'SmallSet',COUNT(*)
FROM   PathMethod.Company;
GO

INSERT INTO #holdTiming (CheckInTime)
SELECT GETDATE() AS CheckInTime
GO
SELECT CONCAT(DATEDIFF(millisecond,MIN(CheckInTime), MAX(CheckInTime)) / 1000.0,' Seconds')
from #holdTiming

SELECT *
FROM  PathMethod.DataSetStats