USE ImagesDirectory
GO
 
DROP PROCEDURE IF EXISTS Locations.ItemType$Maintain
DROP PROCEDURE IF EXISTS Locations.Item$Maintain
DROP TABLE IF EXISTS Locations.Includes
DROP TABLE IF EXISTS Locations.IncludeType
DROP TABLE IF EXISTS Locations.ItemType
DROP TABLE IF EXISTS Locations.ItemClass
DROP TABLE IF EXISTS Locations.Item 
DROP SCHEMA IF EXISTS Locations;
GO

CREATE SCHEMA Locations;
GO

CREATE TABLE Locations.Item
(
	ItemName VARCHAR(100) NOT NULL CONSTRAINT PKItem PRIMARY KEY NONCLUSTERED,
	Description VARCHAR(1000) NOT NULL,
		CONSTRAINT CHKItem_Description_NotEmpty CHECK (LEN(Description) > 0),
	HashTag VARCHAR(100) NOT NULL
			CONSTRAINT CHKItem_HashTag_NotEmpty CHECK (LEN(HashTag) > 0),
	CreateDirectoryFlag BIT NOT NULL CONSTRAINT DFLTItem_CreateDirectoryFlag_False DEFAULT (0)

) AS NODE;

CREATE TABLE Locations.ItemClass --Attraction, Restauraunt, Transportation Etc
(
	ItemClassId INT Identity NOT NULL CONSTRAINT PKItemClass PRIMARY KEY,
	ItemClass VARCHAR(100) NOT NULL,
	Description VARCHAR(1000) NOT NULL
)


CREATE TABLE Locations.ItemType ----RollerCoaster, QuickService Restauraunt, Etc
(
	ItemTypeId INT NOT NULL IDENTITY CONSTRAINT PKItemType PRIMARY KEY,
	ItemClassId INT NOT NULL CONSTRAINT FKItemType$References$ItemClass REFERENCES Locations.ItemClass (ItemClassId),
	ItemType VARCHAR(100) NOT NULL,
	Description VARCHAR(1000) NOT NULL
) AS NODE;

CREATE TABLE Locations.IncludeType
(
	IncludeTypeId INT NOT NULL IDENTITY CONSTRAINT PKIncludeType PRIMARY KEY,
	IncludeType VARCHAR(100) NOT NULL,
	Description varchar(1000) NOT NULL
)


CREATE TABLE Locations.Includes(
	IncludeTypeId INT NOT NULL  CONSTRAINT FKIncludes$References$IncludeType REFERENCES Locations.IncludeType (IncludeTypeId)
) as EDGE

GO


IF NOT EXISTS (SELECT * FROM sys.schemas WHERE schemas.Name = 'Locations_UI')
EXECUTE ('CREATE SCHEMA Locations_UI')
GO
CREATE OR ALTER VIEW Locations_UI.Item_Includes_Item
AS
SELECT Item.ItemName AS ItemName, IncludesItem.ItemName AS ToItemName, IncludeType
FROM   Locations.Item,Locations.Includes,Locations.Item AS IncludesItem, Locations.IncludeType
WHERE MATCH(Item-(Includes)->IncludesItem)
  AND includes.IncludeTypeId = IncludeType.IncludeTypeId
GO

CREATE OR ALTER TRIGGER Locations_UI.Item_Includes_Item$InsteadOfInsertTrigger
ON Locations_UI.Item_Includes_Item
INSTEAD OF INSERT
AS
SET NOCOUNT ON
  BEGIN
   INSERT INTO Locations.Includes($from_id, $to_id, IncludeTypeId)
   SELECT Item.$node_id, IncludesItem.$node_id, IncludeTypeId
   FROM Inserted
         LEFT JOIN Locations.Item
                ON Item.ItemName = Inserted.ItemName
         LEFT JOIN Locations.Item AS IncludesItem
                ON IncludesItem.ItemName = Inserted.ToItemName
		 LEFT JOIN Locations.IncludeType
			ON Inserted.IncludeType = IncludeType.IncludeType
   END;
GO
CREATE OR ALTER TRIGGER Locations_UI.Item_Includes_Item$InsteadOfDeleteTrigger
ON Locations_UI.Item_Includes_Item
INSTEAD OF UPDATE
AS
SET NOCOUNT ON
  BEGIN
       DELETE FROM Locations.Includes
       FROM deleted, Locations.Item,
              Locations.Includes,
              Locations.Item AS LocationsItem
       WHERE MATCH(Item-(Includes)->LocationsItem)
		  AND deleted.ItemName = Item.ItemName
		  AND deleted.ItemName = LocationsItem.ItemName

   INSERT INTO Locations.Includes($from_id, $to_id, IncludeTypeId)
   SELECT Item.$node_id, IncludesItem.$node_id, IncludeTypeId
   FROM Inserted
		 LEFT JOIN Locations.Item
                ON Item.ItemName = Inserted.ItemName
         LEFT JOIN Locations.Item AS IncludesItem
                ON IncludesItem.ItemName = Inserted.ToItemName
		 LEFT JOIN Locations.IncludeType
			ON Inserted.IncludeType = IncludeType.IncludeType
   END;
GO

CREATE OR ALTER TRIGGER Locations_UI.Item_Includes_Item$InsteadOfDeleteTrigger
ON Locations_UI.Item_Includes_Item
INSTEAD OF DELETE
AS
SET NOCOUNT ON
  BEGIN
       DELETE FROM Locations.Includes
       FROM deleted, Locations.Item,
              Locations.Includes,
              Locations.Item AS LocationsItem
       WHERE MATCH(Item-(Includes)->LocationsItem)
		  AND deleted.ItemName = Item.ItemName
		  AND deleted.ItemName = LocationsItem.ItemName

   END;
GO
