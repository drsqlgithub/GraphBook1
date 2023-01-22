USE ImagesDirectory
GO
 
DROP PROCEDURE IF EXISTS Locations.ItemType$Maintain
DROP PROCEDURE IF EXISTS Locations.Item$Maintain
DROP TABLE IF EXISTS Locations.RelatedTo
DROP TABLE IF EXISTS Locations.RelationshipType
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

--used to document if a node fully contains the nodes, or if it is a related item
CREATE TABLE Locations.RelationshipType
(
	RelationshipTypeId INT NOT NULL IDENTITY CONSTRAINT PKRelationshipType PRIMARY KEY,
	RelationshipType VARCHAR(100) NOT NULL,
	Description VARCHAR(1000) NOT NULL
);

--this will be the edge that holds the structure of the DAG. Note that for this example, I included both types of relationships in the one object and left the type of relationship to an attribute. Why? Mostly just to show how that works. If you are rarely going to treat the relationships as different, you might go this way.

CREATE TABLE Locations.RelatedTo (
	RelationshipTypeId INT NOT NULL  
	  CONSTRAINT FKRelatedTo$References$RelationshipType 
	     REFERENCES Locations.RelationshipType (RelationshipTypeId)
) AS EDGE
GO

--The main thing we need to make sure of with a DAG is that there are no cycles. This is easiest done with a trigger that executes after inserts and updates.
CREATE TRIGGER Locations.RelatedTo$InsertUpdateTrigger
ON Locations.RelatedTo
AFTER INSERT, UPDATE
AS
 BEGIN
	SET NOCOUNT ON
	--Simplest case, a self relationship
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
	FROM   Locations.Item AS Item,
		   Locations.RelatedTo FOR PATH AS RelatedTo,
		   Locations.Item FOR PATH AS FollowedItem
	WHERE  MATCH(SHORTEST_PATH(Item(-(RelatedTo)->FollowedItem)+))
	)
	SELECT @CycleFoundFlag = 1
	FROM   BaseRows
	WHERE  ItemName = ConnectedItem

	IF @CycleFoundFlag = 1
	 THROW 50000, 'The data entered causes a cyclic relationship',1;
 END;
 GO

--Making views and instead of triggers to ease data entry

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE schemas.Name = 'Locations_UI')
EXECUTE ('CREATE SCHEMA Locations_UI')
GO
CREATE OR ALTER VIEW Locations_UI.Item_RelatedTo_Item
AS
SELECT Item.ItemName AS ItemName, RelatedToItem.ItemName AS ToItemName, RelationshipType
FROM   Locations.Item,Locations.RelatedTo,Locations.Item AS RelatedToItem, Locations.RelationshipType
WHERE MATCH(Item-(RelatedTo)->RelatedToItem)
  AND RelatedTo.RelationshipTypeId = RelationshipType.RelationshipTypeId
GO

CREATE OR ALTER TRIGGER Locations_UI.Item_RelatedTo_Item$InsteadOfInsertTrigger
ON Locations_UI.Item_RelatedTo_Item
INSTEAD OF INSERT
AS
SET NOCOUNT ON
  BEGIN
   INSERT INTO Locations.RelatedTo($from_id, $to_id, RelationshipTypeId)
   SELECT Item.$node_id, RelatedToItem.$node_id, RelationshipTypeId
   FROM Inserted
         LEFT JOIN Locations.Item
                ON Item.ItemName = Inserted.ItemName
         LEFT JOIN Locations.Item AS RelatedToItem
                ON RelatedToItem.ItemName = Inserted.ToItemName
		 LEFT JOIN Locations.RelationshipType
			ON Inserted.RelationshipType = RelationshipType.RelationshipType
   END;
GO
CREATE OR ALTER TRIGGER Locations_UI.Item_RelatedTo_Item$InsteadOfDeleteTrigger
ON Locations_UI.Item_RelatedTo_Item
INSTEAD OF UPDATE
AS
SET NOCOUNT ON
  BEGIN
       DELETE FROM Locations.RelatedTo
       FROM deleted, Locations.Item,
              Locations.RelatedTo,
              Locations.Item AS LocationsItem
       WHERE MATCH(Item-(RelatedTo)->LocationsItem)
		  AND deleted.ItemName = Item.ItemName
		  AND deleted.ItemName = LocationsItem.ItemName

   INSERT INTO Locations.RelatedTo($from_id, $to_id, RelationshipTypeId)
   SELECT Item.$node_id, RelatedToItem.$node_id, RelationshipTypeId
   FROM Inserted
		 LEFT JOIN Locations.Item
                ON Item.ItemName = Inserted.ItemName
         LEFT JOIN Locations.Item AS RelatedToItem
                ON RelatedToItem.ItemName = Inserted.ToItemName
		 LEFT JOIN Locations.RelationshipType
			ON Inserted.RelationshipType = RelationshipType.RelationshipType
   END;
GO

CREATE OR ALTER TRIGGER Locations_UI.Item_RelatedTo_Item$InsteadOfDeleteTrigger
ON Locations_UI.Item_RelatedTo_Item
INSTEAD OF DELETE
AS
SET NOCOUNT ON
  BEGIN
       DELETE FROM Locations.RelatedTo
       FROM deleted, Locations.Item,
              Locations.RelatedTo,
              Locations.Item AS LocationsItem
       WHERE MATCH(Item-(RelatedTo)->LocationsItem)
		  AND deleted.ItemName = Item.ItemName
		  AND deleted.ItemName = LocationsItem.ItemName

   END;
GO
