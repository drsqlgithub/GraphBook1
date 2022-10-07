USE CategorizationGraph
GO
WITH BaseRows AS (
SELECT	
		Tag.Tagname + STRING_AGG('--> ' + CategorizedTag.TagName, '') WITHIN GROUP (GRAPH PATH) AS HierarchyDisplay,
		LAST_VALUE(CategorizedTag.$node_id) WITHIN GROUP (GRAPH PATH) AS NodeId
FROM   Classifications.Tag AS Tag,
		 Classifications.Categorizes FOR PATH AS Categorizes,
		 Classifications.Tag FOR PATH AS CategorizedTag
WHERE  MATCH(SHORTEST_PATH(Tag(-(Categorizes)->CategorizedTag)+))
--gets me root nodes of the various trees, where I don't want to just have 1 connected tree.
AND    tag.$Node_id NOT IN (SELECT Checker.$to_id FROM Classifications.Categorizes AS Checker)

UNION ALL
SELECT  Tag.TagName, $node_id
FROM   Classifications.Tag
WHERE   NOT EXISTS (SELECT *
						 FROM   Classifications.Categorizes 
						 WHERE  $to_id = Tag.$node_id
						   )
), BaseRows2 AS (
SELECT HierarchyDisplay	, (SELECT COUNT(*)
						   FROM   Resources.Document,
								  Classifications.Categorizes,
								  Classifications.Tag
							WHERE MATCH(Document<-(Categorizes)-Tag)
							 and Tag.$Node_id = BaseRows.NodeId) as FilteredDocumentCount,
						   (SELECT COUNT(*)
						   FROM   Resources.Document,
								  Classifications.Categorizes,
								  Classifications.Tag
							WHERE MATCH(Document<-(Categorizes)-Tag)) AS DocumentCount
						   
FROM  BaseRows
)
SELECT *, CASE WHEN COALESCE(FilteredDocumentCount,0) = 0 THEN 0.00
			   ELSE FilteredDocumentCount * 100.0 / DocumentCount END AS Percentage
FROM   BaseRows2
WHERE filteredDocumentCount <> 0
order by HierarchyDisplay	
GO


--DELETE FROM [Classifications_UI].[Tag_Categorizes_Tag]
--WHERE TagName = 'Caption Competitons'
--AND   CategoryTagName = 'Opinion'

WITH BaseRows AS (
SELECT	
		Tag.Tagname + STRING_AGG('--> ' + CategorizedTag.TagName, '') WITHIN GROUP (GRAPH PATH) AS HierarchyDisplay,
		LAST_VALUE(CategorizedTag.$node_id) WITHIN GROUP (GRAPH PATH) AS NodeId
FROM   Classifications.Tag AS Tag,
		 Classifications.Categorizes FOR PATH AS Categorizes,
		 Classifications.Tag FOR PATH AS CategorizedTag
WHERE  MATCH(SHORTEST_PATH(Tag(-(Categorizes)->CategorizedTag)+))
--gets me root nodes of the various trees, where I don't want to just have 1 connected tree.
AND    tag.$Node_id NOT IN (SELECT Checker.$to_id FROM Classifications.Categorizes AS Checker)

UNION ALL
SELECT  Tag.TagName, $node_id
FROM   Classifications.Tag
WHERE   NOT EXISTS (SELECT *
						 FROM   Classifications.Categorizes 
						 WHERE  $to_id = Tag.$node_id
						   )
)
SELECT HierarchyDisplay, DocumentList.DocumentName, DocumentList.URL
FROM  BaseRows
		LEFT OUTER JOIN	(SELECT Tag.$Node_id as NodeId, Document.DocumentName, Url
					FROM   Resources.Document,
							Classifications.Categorizes,
							Classifications.Tag
					WHERE MATCH(Document<-(Categorizes)-Tag)) as DocumentList
	on baseRows.NodeId = DocumentList.NodeId
order by HierarchyDisplay	