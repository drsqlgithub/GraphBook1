USE CategorizationGraph
Go
EXEC Resources_UI.DocumentCreate
--	@AuthorName = 'Louis Davidson',
 --@AuthorName = 'Grant Fritchey',
--@AuthorName = 'Kathi Kellenberger',
	@AuthorName = 'Devyani Borade',
--	@AuthorName = 'Robert Sheldon',
--	@AuthorName = 'Aditya Bikkani',
--	@AuthorName = 'Mallika Gunturu',
--	@AuthorName = 'Greg Larsen',
--	@AuthorName = 'Lukas Vileikis',
--	@AuthorName = 'Dennes Torres',
--	@AuthorName = 'EzzEddin Abdullah',
--	@AuthorName = 'Joe Celko',
--	@AuthorName = 'Aneesh Lal Gopalakrishnan',
--	@AuthorName = 'Camilo Reyes',
	--@AuthorName = 'Edward Pollack',
--@AuthorName ='Naveed Janvekar',
	--@AuthorName = 'Kumar Abhishek',
--	@AuthorName = 'Boemo Mmopelwa',
--@AuthorName = 'Rohan Kapoor',
--@AuthorName = 'Goodness Woke',
--@AuthorName = 'Sanil Mhatre',
--@AuthorName = 'Jonathan Lewis',
--@AuthorName = 'Priyanka Chouhan',
--@AuthorName = 'Rajeshkumar Sasidharan',
--@AuthorName = 'Adam Aspin',
--@AuthorName = 'Samuel Nitsche',
	@DocumentName = 'Mighty Tester – Here we go round the Mulberry bush',
	@DocumentType = 'Article',
	@DocumentStatus = 'Published',
	@PublishDate = '10 Feb 2022',
	@TagList = 'Editorials',
	@ViewCount = 2631,
	@Url = 'https://www.red-gate.com/simple-talk/opinion/editorials/mighty-tester-here-we-go-round-the-mulberry-bush/'
--	@TagList = 'Editorial'

SELECT Document.PublishDate, Person.PersonName, DocumentName, STRING_AGG(Tag.TagName,', '), Document.ViewCount AS ViewCount,
	   Document.url
FROM   Resources.Document,
	   Classifications.Categorizes,
	   Classifications.Tag,
	   Resources.Person,
	   Resources.Writes
WHERE  MATCH(Tag-(Categorizes)->Document)
  AND  MATCH(Person-(Writes)->Document)
GROUP BY PublishDate,
         PersonName,
         DocumentName,
         ViewCount,URL
ORDER BY PersonName --PublishDate 

--INSERT INTO Classifications.Categorizes
--(
--    $from_id,
--    $to_id
--)
--SELECT Tag.$node_id, Document.$node_id
--FROM   Resources.Document
--		CROSS JOIN Classifications.Tag
--WHERE TagName = 'SQL Server'
--AND Document.DocumentName = 'Eight Azure SQL Configurations You May Have Missed'


--INSERT INTO Classifications.Categorizes
--(
--    $from_id,
--    $to_id
--)
--SELECT FromTag.$node_id, ToTag.$node_id
--FROM   Classifications.Tag AS FromTag
--		CROSS JOIN Classifications.Tag AS ToTag
--WHERE FromTag.TagName = 'Databases'
--AND ToTag.TagName = 'BI'

SELECT Tagname, $edge_id
FROM   Resources.Document
		LEFT JOIN Classifications.Categorizes
			ON $node_id = $to_id
		LEFT JOIN Classifications.Tag
			ON Tag.$node_id = $from_id
WHERE DocumentName = 'Sentiment Analysis with Python'
ORDER BY DocumentName
	
DELETE FROM Classifications.Categorizes
WHERE $edge_id = '{"type":"edge","schema":"Classifications","table":"Categorizes","id":196}'

--INSERT INTO Classifications_UI.Tag_Categorizes_ResourcesDocument
--(
--    TagName,
--    DocumentName
--)
--VALUES
--(   'Data Science', -- TagName - nvarchar(100)
--    'Introduction to artificial intelligence'  -- DocumentName - nvarchar(100)
--    )
--SELECT *
--FROM  Classifications.Tag
--ORDER BY TagName

--SELECT *
--FROM   Resources.Document
--		LEFT JOIN Classifications.Categorizes
--			ON $node_id = $to_id
--ORDER BY DocumentName