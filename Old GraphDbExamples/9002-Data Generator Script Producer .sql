/*
This file is used to generate a script that we will use in the 02 files to performance test 
the algorithms. This way we get the exact same "random" data to build our demo cases with so 
we are comparing oranges to oranges
*/
:setvar DataSetName VeryWideSet
:setvar TargetSchema AdjacencyList

USE GraphDBTests_DataGenerator
GO
SET NOCOUNT ON 

SELECT 'USE GraphDBTests
GO'


SELECT 'SET NOCOUNT ON
GO'

DECLARE @query VARCHAR(MAX);
DECLARE @schemaName sysName = '$(TargetSchema)';




SELECT @query = 
CASE WHEN @schemaName = 'SqlGraph' THEN 'DELETE SQLGraph.ReportsTo' ELSE '' END + 

'
DELETE ' + @schemaName + '.Sale
DELETE ' + @schemaName + '.Company 
DBCC CHECKIDENT (' + QUOTEName(@schemaName + '.Sale','''') + ',RESEED,0)
DBCC CHECKIDENT (' + QUOTEName(@schemaName + '.Company','''') + ',RESEED,0)
ALTER SEQUENCE ' + @schemaName + '.CompanyDataGenerator_SEQUENCE RESTART
GO
'
SELECT @query

IF @schemaName = 'PathMethod'
  SELECT 'ALTER SEQUENCE PathMethod.Company_SEQUENCE RESTART
GO'


SELECT 'EXEC ' + @schemaName + '.Company$Insert @Name = ' + QUOTEName(childName,'''') 
								+ ', @ParentCompanyName = ' + CASE WHEN ParentName IS NULL THEN 'NULL' ELSE QUOTEName(ParentName,'''') END + '
GO
' + CASE WHEN Hierarchy_$(DataSetName).LeafNodeFlag = 1 THEN 'EXEC ' + @schemaName + '.Sale$InsertTestData @Name = ' + + QUOTEName(childName,'''') + CHAR(13) + CHAR(10) + 'GO' ELSE '' END 
FROM   DemoCreator.Hierarchy_$(DataSetName)
ORDER BY Level,parentName, ChildName




