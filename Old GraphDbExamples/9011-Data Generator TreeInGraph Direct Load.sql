USE GraphDBTests
go

:setvar DataSetName LargeSet
--:setvar DataSetName VeryWideSet
--:setvar DataSetName VeryDeepSet
--:setvar DataSetName HugeSet
--:setvar DataSetName SuperHugeSet


set nocount on;

DELETE SqlGraph.Sale
DELETE SqlGraph.ReportsTo
DELETE SqlGraph.Company 
DBCC CHECKIDENT ('SqlGraph.Sale',RESEED,0)
DBCC CHECKIDENT ('SqlGraph.Company',RESEED,0)
ALTER SEQUENCE SqlGraph.CompanyDataGenerator_SEQUENCE RESTART
go


SET IDENTITY_INSERT SqlGraph.Company ON
go
INSERT INTO SqlGraph.Company(CompanyId, Name)
SELECT CAST(SUBSTRING(CHildName,5,10) AS INT) AS CompanyId,
	   ChildName AS Name
FROM GraphDBTests_DataGenerator.DemoCreator.Hierarchy_$(DataSetName)
go
SET IDENTITY_INSERT SqlGraph.Company OFF
go

insert into SqlGraph.ReportsTo($From_id, $To_id)
select FromNode.$node_id, ToNode.$node_id
from   GraphDBTests_DataGenerator.DemoCreator.Hierarchy_$(DataSetName)
		 join SqlGraph.Company as FromNode
			on FromNode.Name = Hierarchy_$(DataSetName).ParentName
		 join SqlGraph.Company as ToNode
			on ToNode.Name = Hierarchy_$(DataSetName).ChildName
group by FromNode.$node_id, ToNode.$node_id
--having count(*) > 1


DECLARE @cursor CURSOR, @CompanyName VARCHAR(20)
SET @cursor = CURSOR FOR SELECT ChildName FROM GraphDBTests_DataGenerator.DemoCreator.Hierarchy_$(DataSetName) WHERE LeafNodeFlag = 1 ORDER BY Level,parentName, ChildName
OPEN @cursor
WHILE (1=1)
 BEGIN
	FETCH NEXT FROM @cursor INTO @CompanyName
	IF @@FETCH_STATUS <> 0
		BREAK
    
	EXEC SqlGraph.Sale$InsertTestData @Name = @CompanyName
 END
GO

SELECT COUNT(*) as CompanyCount
FROM   SqlGraph.Company
SELECT COUNT(*) as SalesCount
FROM   SqlGraph.sale