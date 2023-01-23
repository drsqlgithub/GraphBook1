Use BillOfMaterialsExample;
GO

SET NOCOUNT ON;
DELETE FROM PartsSystem.Includes;
DELETE FROM PartsSystem.Part;

INSERT INTO PartsSystem.Part(PartName, AssemblyItemCode, AssemblyPartName)
VALUES ('Shelvii',NULL,'Shelvii');
INSERT INTO PartsSystem.Part(PartName, AssemblyItemCode, AssemblyPartName)
VALUES ('Shelvii Shelf Set','A','Shelf Set');
INSERT INTO PartsSystem.Part(PartName, AssemblyItemCode, AssemblyPartName)
VALUES ('Shelvii Shelf Enhancer','A','Shelf Enchancer');
INSERT INTO PartsSystem.Part(PartName, AssemblyItemCode, AssemblyPartName)
VALUES ('10x10x2 Shelf','B','Flat Shelf');
INSERT INTO PartsSystem.Part(PartName, AssemblyItemCode, AssemblyPartName)
VALUES ('Shelvii Side Shelf','A','Shelvii Side');
INSERT INTO PartsSystem.Part(PartName, AssemblyItemCode, AssemblyPartName)
VALUES ('Small Wooden Dowl Pack','A','Wooden Dowel Pack');
INSERT INTO PartsSystem.Part(PartName, AssemblyItemCode, AssemblyPartName)
VALUES ('Wooden Dowl',NULL,'Wooden Dowel');
INSERT INTO PartsSystem.Part(PartName, AssemblyItemCode, AssemblyPartName)
VALUES ('3.2R Small Screw Pack','2','Small Screw Pack');
INSERT INTO PartsSystem.Part(PartName, AssemblyItemCode, AssemblyPartName)
VALUES ('3.2R Screw',NULL,'Small Screw');
GO


INSERT INTO PartsSystem_UI.Part_Includes_Part(PartName, IncludeCount, IncludesPartName)
VALUES ('Shelvii', 3, 'Shelvii Shelf Set');
INSERT INTO PartsSystem_UI.Part_Includes_Part(PartName, IncludeCount, IncludesPartName)
VALUES ('Shelvii', 2, '10x10x2 Shelf');
INSERT INTO PartsSystem_UI.Part_Includes_Part(PartName, IncludeCount, IncludesPartName)
VALUES ('Shelvii', 5,'Small Wooden Dowl Pack');
INSERT INTO PartsSystem_UI.Part_Includes_Part(PartName, IncludeCount, IncludesPartName)
VALUES ('Shelvii', 2, 'Shelvii Side Shelf');
INSERT INTO PartsSystem_UI.Part_Includes_Part(PartName, IncludeCount, IncludesPartName)
VALUES ('Shelvii', 2, '3.2R Small Screw Pack');

INSERT INTO PartsSystem_UI.Part_Includes_Part(PartName, IncludeCount, IncludesPartName)
VALUES ('Shelvii Shelf Set', 2, 'Shelvii Shelf Enhancer');
INSERT INTO PartsSystem_UI.Part_Includes_Part(PartName, IncludeCount, IncludesPartName)
VALUES ('Shelvii Shelf Set', 1, '10x10x2 Shelf');
INSERT INTO PartsSystem_UI.Part_Includes_Part(PartName, IncludeCount, IncludesPartName)
VALUES ('Shelvii Shelf Set', 3, '3.2R Small Screw Pack');

INSERT INTO PartsSystem_UI.Part_Includes_Part(PartName, IncludeCount, IncludesPartName)
VALUES ('3.2R Small Screw Pack', 3, '3.2R Screw');

INSERT INTO PartsSystem_UI.Part_Includes_Part(PartName, IncludeCount, IncludesPartName)
VALUES ('Small Wooden Dowl Pack', 3, 'Wooden Dowl');

GO
SELECT * FROM PartsSystem_UI.Part_Includes_Part;