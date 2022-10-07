USE CategorizationGraph
GO
DECLARE @TopLevel TABLE (TagName NVARCHAR(100));
DECLARE @BottomLevel TABLE (TagName NVARCHAR(100));

--INSERT INTO @TopLevel (TagName)
--VALUES ('Cloud');
--INSERT INTO @BottomLevel (TagName)
--VALUES ('MySQL');

--dSELECT COUNT(*) FROM Resources.Document;

WITH BaseRows AS (
SELECT	
		Tag.TagName AS CategoryName,
		LAST_VALUE(CategorizedTag.TagId) WITHIN GROUP (GRAPH PATH) AS TagId,
		LAST_VALUE(CategorizedTag.TagName) WITHIN GROUP (GRAPH PATH) AS TagName,
		Tag.Tagname + STRING_AGG('--> ' + CategorizedTag.TagName, '') WITHIN GROUP (GRAPH PATH) AS HierarchyDisplay
FROM   Classifications.Tag AS Tag,
		 Classifications.Categorizes FOR PATH AS Categorizes,
		 Classifications.Tag FOR PATH AS CategorizedTag
WHERE  MATCH(SHORTEST_PATH(Tag(-(Categorizes)->CategorizedTag)+))
UNION ALL
SELECT  Tag.TagName,
		TagId,
		Tag.TagName,
		Tag.TagName
FROM   Classifications.Tag
WHERE   NOT EXISTS (SELECT *
						 FROM   Classifications.Categorizes 
						 WHERE  $to_id = Tag.$node_id)
),
FilteredRows AS (
SELECT *
FROM  BaseRows
WHERE NOT EXISTS (SELECT * FROM @TopLevel)
  OR  CategoryName IN (SELECT tagName FROM @TopLevel)
)

SELECT Document.PublishDate, Person.PersonName, DocumentName
		,Document.ViewCount AS ViewCount,
		STRING_AGG('['+FilteredRows.HierarchyDisplay +']','  '), 
		STRING_AGG('['+Tag.TagName +']','  '), 

	   Document.url
FROM   Resources.Document,
	   Classifications.Categorizes,
	   Classifications.Tag,
	   Resources.Person,
	   Resources.Writes
	   ,FilteredRows
WHERE  MATCH(Tag-(Categorizes)->Document)
  AND  MATCH(Person-(Writes)->Document)
  AND Tag.TagId = FilteredRows.TagId
AND ( NOT EXISTS (SELECT * FROM @BottomLevel)
	OR  Tag.TagName IN (SELECT tagName FROM @BottomLevel))
GROUP BY PublishDate,
         PersonName,
         DocumentName,
         ViewCount,URL
--ORDER BY PersonName 
--ORDER BY PublishDate 
--ORDER BY ViewCount Desc
ORDER BY DocumentName