EXEC Resources_UI.DocumentCreate
--	@AuthorName = 'Louis Davidson',
--	@AuthorName = 'Grant Fritchey',
--	@AuthorName = 'Kathi Kellenberger',
--	@AuthorName = 'Devyani Borade',
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
--	@AuthorName = 'Edward Pollack',
	@AuthorName = 'Kumar Abhishek',
	@DocumentName = 'Introduction to artificial intelligence',
	@DocumentType = 'Article',
	@DocumentStatus = 'Published',
	@PublishDate = '10 May 2022',
	@TagList = '[Data Science], Introduction'
--	@TagList = 'Editorial'


INSERT INTO Classifications_UI.Tag_Categorizes_ResourcesDocument
(
    TagName,
    DocumentName
)
VALUES
(   'Data Science', -- TagName - nvarchar(100)
    'Introduction to artificial intelligence'  -- DocumentName - nvarchar(100)
    )
SELECT *
FROM  Classifications.Tag
ORDER BY TagName

SELECT *
FROM   Resources.Document
		LEFT JOIN Classifications.Categorizes
			ON $node_id = $to_id
ORDER BY DocumentName