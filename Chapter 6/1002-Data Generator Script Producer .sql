/*
This file is used to generate a script that we will use in the 02 files to performance test 
the algorithms. This way we get the exact same "random" data to build our demo cases with so 
we are comparing oranges to oranges
*/
--:SETVAR TargetSchema SqlGraph
--:SETVAR TargetSchema AdjacencyList
--:SETVAR TargetSchema PathMethod
:SETVAR TargetSchema GappedNestedSets

--:setvar DataSetName LargeSet
--:setvar DataSetName WideSet
--:setvar DataSetName DeepSet
:setvar DataSetName HugeSet
--:setvar DataSetName SuperHugeSet

USE GraphDBTests_DataGenerator
GO
SET NOCOUNT ON 

SELECT 'USE GraphDBTests
GO'


SELECT 'SET NOCOUNT ON
GO'

SELECT '
IF OBJECT_ID(''$(TargetSchema).DataSetStats'',''U'') is null
 CREATE TABLE $(TargetSchema).DataSetStats(
	TestSetName nvarchar(20) NOT NULL,
	CompanyCount Int
);
TRUNCATE TABLE $(TargetSchema).DataSetStats;
GO
'

DECLARE @query VARCHAR(MAX);
DECLARE @schemaName sysName = '$(TargetSchema)';

SELECT @query = 
CASE WHEN '$(TargetSchema)' = 'SQLGraph' THEN '
DELETE FROM SQLGraph.ReportsTo' ELSE '' END + 
'
DELETE ' + @schemaName + '.Sale
DELETE ' + @schemaName + '.Company 
DBCC CHECKIDENT (' + QUOTEName(@schemaName + '.Sale','''') + ',RESEED,0)' + 
CASE WHEN @SchemaName <> 'PathMethod' then '
DBCC CHECKIDENT (' + QUOTEName(@schemaName + '.Company','''') + ',RESEED,0)
' ELSE '' END + '
ALTER SEQUENCE ' + @schemaName + '.CompanyDataGenerator_SEQUENCE RESTART
GO
'
SELECT @query

IF @schemaName = 'PathMethod'
  SELECT 'ALTER SEQUENCE PathMethod.Company_SEQUENCE RESTART
GO'

SELECT '
DROP TABLE IF EXISTS #holdTiming;
SELECT GETDATE() AS CheckInTime
INTO  #holdTiming;
'

SELECT 'EXEC ' + @schemaName + '.Company$Insert @Name = ' + QUOTEName(childName,'''') 
								+ ', @ParentCompanyName = ' + CASE WHEN ParentName IS NULL THEN 'NULL' ELSE QUOTEName(ParentName,'''') END + '
GO
' + CASE WHEN Hierarchy_$(DataSetName).LeafNodeFlag = 1 THEN 'EXEC ' + @schemaName + '.Sale$InsertTestData @Name = ' + + QUOTEName(childName,'''') + CHAR(13) + CHAR(10) + 'GO' ELSE '' END 
FROM   DemoCreator.Hierarchy_$(DataSetName)
ORDER BY Level,parentName, ChildName

SELECT '
INSERT INTO $(TargetSchema).DataSetStats(TestSetName, CompanyCount)
SELECT ''$(TargetSchema)'',COUNT(*)
FROM   $(TargetSchema).Company;
GO'

SELECT '
INSERT INTO #holdTiming (CheckInTime)
SELECT GETDATE() AS CheckInTime
GO
SELECT CONCAT(DATEDIFF(millisecond,MIN(CheckInTime), MAX(CheckInTime)) / 1000.0,'' Seconds'')
from #holdTiming
GO
SELECT *
from   $(TargetSchema).DataSetStats;
'



