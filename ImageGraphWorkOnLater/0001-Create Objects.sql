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

--Start out by creating the Locations schema where all of the location details will be located. (As noted, I will not build out the filetable structures for this chapter, but when I do, the images would be located in a different schema.
CREATE SCHEMA Locations;
GO

--To create the structures, I am going to start with the noe object. Each Item ( which can be an area, attraction, etc, will a name, description, a hashtag (which will be used when posting images from this location), and a flag to create a directory. 

CREATE TABLE Locations.Item
(
	ItemName VARCHAR(100) NOT NULL CONSTRAINT PKItem PRIMARY KEY NONCLUSTERED,
	Description VARCHAR(1000) NOT NULL,
		CONSTRAINT CHKItem_Description_NotEmpty CHECK (LEN(Description) > 0),
	HashTag VARCHAR(100) NOT NULL
			CONSTRAINT CHKItem_HashTag_NotEmpty CHECK (LEN(HashTag) > 0),
	CreateDirectoryFlag BIT NOT NULL 
		CONSTRAINT DFLTItem_CreateDirectoryFlag_False DEFAULT (0)

) AS NODE;

--Next I am going to create a node for the that will identify the type of item

CREATE TABLE Locations.ItemClass --Attraction, Restauraunt, Transportation Etc
(
	ItemClassId INT IDENTITY NOT NULL CONSTRAINT PKItemClass PRIMARY KEY,
	ItemClass VARCHAR(100) NOT NULL,
	Description VARCHAR(1000) NOT NULL
)


--This node will be associated with items and is the specific type of item being worked with

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
	Description VARCHAR(1000) NOT NULL
)


CREATE TABLE Locations.Includes(
	IncludeTypeId INT NOT NULL  CONSTRAINT FKIncludes$References$IncludeType REFERENCES Locations.IncludeType (IncludeTypeId)
) AS EDGE
GO

CREATE TRIGGER Locations.Includes$InsertUpdateTrigger
ON Locations.Includes
AFTER INSERT
AS
 BEGIN
	SET NOCOUNT ON
	IF EXISTS (SELECT *
			   FROM   Inserted
			   WHERE  Inserted.$from_id = Inserted.$to_id)
	  THROW 50000,'No self relationships allowed',1;

	--look for cycles by checking to see if there is any 
	--item where the connected item matches the itemName
	DECLARE @CycleFoundFlag BIT = 0;
	WITH BaseRows AS (
	SELECT Item.ItemName,  
		  LAST_VALUE(FollowedItem.ItemName) WITHIN GROUP (GRAPH PATH)
													AS ConnectedItem
		  --,STRING_AGG(FollowedItem.ItemName, '->') WITHIN GROUP 
		  --                                      (GRAPH PATH) AS Path
	FROM   Locations.Item AS Item,
		   Locations.Includes FOR PATH AS Includes,
		   Locations.Item FOR PATH AS FollowedItem
	WHERE  MATCH(SHORTEST_PATH(Item(-(Includes)->FollowedItem)+))
	)
	SELECT @CycleFoundFlag = 1
	FROM   BaseRows
	WHERE  ItemName = ConnectedItem

	IF @CycleFoundFlag = 1
	 THROW 50000, 'The data entered causes a cyclic relationship',1;


 END;
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
