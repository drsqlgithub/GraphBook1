--In this chapter, I want to show one of the more prominent (and straightforward) DAG (directed acyclic graph) examples. A bill of materials (or I will shorten to BOM when it gets repetitive). A bill of materials represents a product breakdown. Using it, you can determine what parts make up other parts. The example I will use is a simple shelf system you might purchas from your favorite meatball restaurant. (The referenc is meaningless to the example, but if you know you know.) What looks like a huge solid shelf will actually come in about 1000 pieces. Some of those pieces will be used in multiple parts of the shelves. Screws and dowels are easy examples, but go a bit higher and you may see repetition in things like shelves. 

--For our example I am going A shelf might be included multiple times, with the same parts. On the instructions you may see 3X on a sheet. In Figure 7-1, I have sketched out the tree representation of what I am calling the "Shelvii". Note that there are some duplications in the structure, as the 2 - Small Screw Pack (the 2 is to replicate the number you see printed on the items, just like all my identifier values...Of course, those identifiers are not key values for the overall system because not every shelf system would actually need it, so other things might be labeled 1 for the Tablii system. Good thing I am not actually in charge of product naming.) THere is also a B-Flat Shelf that is repeated for the main system, and the shelf set. (I may draw this) The idea is that the same flat shelf is used for the top and the bottom, but just doesn't include the same shelf enhancer, so it is stand alone.

--Without turning this into a completely modular furniture design article, I wanted to include an example of such a common structure because there are a few things you will almost certainly want to do with this data that is unlike a tree. In a BOM a node can as many to/parent relationships as you want because the we are in the end we probably are not going to create this system like a tree such as this. But rather as a DAG like you can see in Figure 7-2. Note too I am going to completely ignore packaging in this discussion as well. Only the parts that make up the shelf will be included, and I will ignore details like if the part can be sold individually,too. 

--Both the Shelvii node and the A-Shelf Set node are parents to the 2-Small Screw Pack nodes. This would tell the person fetching these items to fetch 2 of the 2-Small Screw Pack bags and put into the box. And most likely (I am not in manufacturing, admittedly), but what I see occurring is that there would be processes set up to create each of the nodes. So there probably are bins of Shelf Enhancers, Flat Shelves, Small Screpes, Wooden Dowels and Shelvii Sides. Proceed up the list, and there are processes to create a Shelf Set, Small Screw Pack, Wooden Dowel Pack. Some of these packs may be used in different shelves, some not. If one system needed 20 small screws and another 2, then there would be more than 1 Small Screw Pack size. For sake of brevity, give me a modicum of leeway in my example to keep it simple. 

--Lastly, to finish up the setup, we need magnitudes. In Figure 7-3, I am going to add the number of each item needed per shelf system.

--In this chapter, I am going to include the typical stuff for an example. Structures and queries to build the node and edge table. I will keep it to just the necessary data needed to represent the DAG. So just name, letter, and magnitude, but no type, size, etc. Code to load in the graph I have designed.

--Then I will implement several of the types of queries you might do with a bill of materials.
--1. Determining if a part is used in a build
--2. Picking items for a build
--3. Printing and summing out the parts list for a build


Use BillOfMaterialsExample;
GO

DROP TABLE IF EXISTS PartsSystem.Includes;
DROP TABLE IF EXISTS PartsSystem.Part;
DROP SCHEMA PartsSystem;
GO

CREATE SCHEMA PartsSystem;
GO

CREATE TABLE PartsSystem.Part(
	PartId	int NOT NULL IDENTITY
		CONSTRAINT PKPart PRIMARY KEY,
	PartName  nvarchar(30) NOT NULL 
	         CONSTRAINT AKPart UNIQUE
) as NODE;

CREATE TABLE PartsSystem.Includes
(
	IncludeCount int NOT NULL,
	CONSTRAINT AKIncludes_UniqueParts UNIQUE
					($from_id, $to_id),
	CONSTRAINT ECIncludes CONNECTION (PartsSystem.Part to PartsSystem.Part)
) AS EDGE;
GO

CREATE TRIGGER PartsSystem.Includes$InsertUpdateTrigger
ON PartsSystem.Includes
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
	SELECT Part.PartId,  
		  LAST_VALUE(IncludedPart.PartId) WITHIN GROUP (GRAPH PATH)
													AS IncludedPartId
	FROM   PartsSystem.Part AS Part,
		   PartsSystem.Includes FOR PATH AS Includes,
		   PartsSystem.Part FOR PATH AS IncludedPart
	WHERE  MATCH(SHORTEST_PATH(Part(-(Includes)->IncludedPart)+))
	)
	SELECT @CycleFoundFlag = 1
	FROM   BaseRows
	WHERE  PartId = IncludedPartId

	IF @CycleFoundFlag = 1
	 THROW 50000, 'The data entered causes a cyclic relationship',1;
 END;
 GO

 IF NOT EXISTS (SELECT * FROM sys.schemas WHERE schemas.Name = 'PartsSystem_UI')
EXECUTE ('CREATE SCHEMA PartsSystem_UI')
GO
CREATE OR ALTER VIEW PartsSystem_UI.Part_Includes_Part
AS
SELECT Part.PartName, Includes.IncludeCount, IncludesPart.PartName as IncludesPartName
FROM   PartsSystem.Part, PartsSystem.Includes,PartsSystem.Part as IncludesPart
WHERE MATCH(Part-(Includes)->IncludesPart)
GO

CREATE OR ALTER TRIGGER PartsSystem_UI.Part_Includes_Part$InsteadOfInsertTrigger
ON PartsSystem_UI.Part_Includes_Part
INSTEAD OF INSERT
AS
SET NOCOUNT ON
  BEGIN
   INSERT INTO PartsSystem.Includes($from_id, $to_id, IncludeCount)
   SELECT Part.$node_id, IncludesPart.$node_id, IncludeCount
   FROM Inserted
         LEFT JOIN PartsSystem.Part
                ON Part.PartName = Inserted.PartName
         LEFT JOIN PartsSystem.Part AS IncludesPart
                ON IncludesPart.PartName = Inserted.IncludesPartName;
   END;
GO
CREATE OR ALTER TRIGGER PartsSystem_UI.Part_IncludesPart$InsteadOfDeleteTrigger
ON PartsSystem_UI.Part_Includes_Part
INSTEAD OF UPDATE
AS
SET NOCOUNT ON
  BEGIN
       DELETE FROM PartsSystem.Includes
       FROM deleted, PartsSystem.Part,
              PartsSystem.Includes,
              PartsSystem.Part AS IncludesPart
       WHERE MATCH(Part-(Includes)->IncludesPart)
		  AND deleted.PartName = Part.PartName
		  AND deleted.PartName = IncludesPart.PartName

   INSERT INTO PartsSystem.Includes($from_id, $to_id, IncludeCount)
   SELECT Part.$node_id, IncludesPart.$node_id, IncludeCount
   FROM Inserted
         LEFT JOIN PartsSystem.Part
                ON Part.PartName = Inserted.PartName
         LEFT JOIN PartsSystem.Part AS IncludesPart
                ON IncludesPart.PartName = Inserted.IncludesPartName;
   END;
GO

CREATE OR ALTER TRIGGER PartsSystem_UI.Item_Includes_Item$InsteadOfDeleteTrigger
ON PartsSystem_UI.Item_Includes_Item
INSTEAD OF DELETE
AS
SET NOCOUNT ON
  BEGIN
       DELETE FROM PartsSystem.Includes
       FROM deleted, PartsSystem.Part,
              PartsSystem.Includes,
              PartsSystem.Part AS IncludesPart
       WHERE MATCH(Part-(Includes)->IncludesPart)
		  AND deleted.PartName = Part.PartName
		  AND deleted.PartName = IncludesPart.PartName;
   END;
GO