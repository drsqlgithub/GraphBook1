USE ImagesDirectory
GO
DELETE Locations.Includes
DELETE Locations.Item;
DELETE Locations.IncludeType
DELETE Locations.ItemType
DELETE Locations.ItemClass;

GO

INSERT INTO Locations.ItemClass
(
    ItemClass,
    Description
)
VALUES
('Resort','A multi-purpose location with attractions, hotels, restaurants, etc')
,('Hotel', 'A place to sleep when you aren''t doing something else :)')
,('Restaurant','A place to get prepared food to eat')
,('Lounge','A place to get small food and drinks')
,('Area','Specific named area of another area')
,('Transportation','Method of moving from one place to another')
GO
 
INSERT INTO Locations.IncludeType (IncludeType, Description)
VALUES ('Contains', 'Item physically contains related item')

INSERT INTO Locations.IncludeType (IncludeType, Description)
VALUES ('Related', 'Item related to other item')
GO


EXEC Locations.ItemType$Maintain 'Resort','Theme Park','A park with rides, attractions, etc'
EXEC Locations.ItemType$Maintain 'Resort','Full Theme Park Resort','A group of items that could stand alone, which includes theme parks'
EXEC Locations.ItemType$Maintain 'Resort','Resort Shopping Area','A group of shopping location items'
EXEC Locations.ItemType$Maintain 'Transportation','Trolley','Bus transportation'
EXEC Locations.ItemType$Maintain 'Transportation','Trolley Station','Place to catch the trolley'
EXEC Locations.ItemType$Maintain 'Area','Theme Park Land','Chapest hotel location'

GO
EXEC Locations.[Item$Maintain] 'Happy Fun Resort','Full Theme Park Resort','Fun theme park resort','HappyFunResort',0

EXEC Locations.[Item$Maintain] 'Fun Shopping Zone','Resort Shopping Area','Fun Kingdom Park','FunKingdom',0
EXEC Locations.[Item$Maintain] 'Fun Kingdom','Theme Park','Fun Kingdom Park','FunKingdom',0
EXEC Locations.[Item$Maintain] 'Silly Studios','Theme Park','Silly Studios Park','Silly Studios',0

EXEC Locations.[Item$Maintain] 'Funville','Theme Park Land','Fun Kingdom Park Area','FunVille',0
EXEC Locations.[Item$Maintain] 'Fun Homeland','Theme Park Land','Fun Kingdom Park Area','FunHomeLand',0
EXEC Locations.[Item$Maintain] 'Fun Vittles','Theme Park Land','Fun Kingdom Park Area','FunVittles',0

EXEC Locations.[Item$Maintain] 'Silly Studio Zone','Theme Park Land','Silly Studios Park Area','SillyStudio',0
EXEC Locations.[Item$Maintain] 'Silly Town','Theme Park Land','Silly Studios Park Area','SillyTown',0



EXEC Locations.[Item$Maintain] 'Happy Fun Resort Trolley','Trolley','Takes you between theme parks','HFTrolley',0

EXEC Locations.[Item$Maintain] 'Silly Town Trolley Station','Trolley Station','Place to catch the trolley','SillyTownTrolleyStation',0
EXEC Locations.[Item$Maintain] 'Funville Trolley Station','Trolley Station','Place to catch the trolley','FunvilleTrolleyStation',0
EXEC Locations.[Item$Maintain] 'Fun Shopping Zone Trolley Station','Trolley Station','Place to catch the trolley','FunvShoppingZoneTrolleyStation',0

GO


INSERT INTO Locations_UI.Item_Includes_Item
(    ItemName,    ToItemName, IncludeType)
VALUES
('Happy Fun Resort','Fun Shopping Zone','Contains'),
('Happy Fun Resort','Fun Kingdom','Contains'),
('Happy Fun Resort','Silly Studios','Contains'),
('Happy Fun Resort','Happy Fun Resort Trolley','Contains'),
('Happy Fun Resort','Funville Trolley Station','Contains'),

('Fun Kingdom','Funville','Contains'),
('Fun Kingdom','Fun Homeland','Contains'),
('Fun Kingdom','Fun Vittles','Contains'),

('Silly Studios','Silly Studio Zone','Contains'),
('Silly Studios','Silly Town','Contains'),

('Silly Town','Silly Town Trolley Station','Contains'),
('Funville','Funville Trolley Station','Contains'),
('Fun Shopping Zone','Fun Shopping Zone Trolley Station','Contains'),

('Funville Trolley Station','Happy Fun Resort Trolley','Related'),
('Silly Town Trolley Station','Happy Fun Resort Trolley','Related'),
('Fun Shopping Zone Trolley Station','Happy Fun Resort Trolley','Related')

--self relationship test
--,('Silly Studios','Silly Studios','Contains')

--cycle test
--,('Silly Studios','Happy Fun Resort','Contains')



SELECT *
FROM    Locations_UI.Item_Includes_Item