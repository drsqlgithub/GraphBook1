CREATE OR ALTER PROCEDURE Resources_UI.DocumentCreate(
	@AuthorName NVARCHAR(100),
	@DocumentName NVARCHAR(100),
	@DocumentType VARCHAR(30),
	@DocumentStatus VARCHAR(30),
	@PublishDate DATE = NULL,
	@TagList NVARCHAR(MAX)
	)
AS
BEGIN
 SET XACT_ABORT ON;
 BEGIN TRANSACTION
	IF NOT EXISTS (SELECT *
					FROM  Resources.Person
					WHERE PersonName = @AuthorName)
		INSERT INTO Resources.Person (PersonName)
		VALUES (@AuthorName)

	IF NOT EXISTS (SELECT *
				   FROM    Resources.Document
				   WHERE  DocumentName = @DocumentName)
		INSERT INTO Resources.Document
		(
		    DocumentName,
		    DocumentType,
			DocumentStatus,
			PublishDate
		)
		VALUES
		(   @DocumentName,
			@DocumentType,
			@DocumentStatus,
			@PublishDate
		);
	ELSE
		UPDATE Resources.Document
		SET DocumentStatus = @DocumentStatus,
			PublishDate = @PublishDate,
			DocumentType = @DocumentType
		WHERE DocumentName = @DocumentName


	INSERT INTO Classifications.Tag
	(   TagName	)
	SELECT *
	FROM STRING_SPLIT(@TagList,',')
	WHERE  value NOT IN (SELECT TagName FROM Classifications.Tag);

	WITH LinkRows AS (
	SELECT (SELECT $node_id FROM Resources.Person WHERE PersonName = @AuthorName) AS FromId,
		   (SELECT $node_id FROM Resources.Document WHERE DocumentName = @DocumentName) AS ToId
	)
		
	INSERT INTO Resources.Writes
	(
	    $from_id,
	    $to_id
	)
	SELECT LinkRows.FromId, LinkRows.ToId
	FROM  LinkRows
	WHERE  NOT EXISTS (SELECT *
					   FROM   Resources.Writes
					   WHERE  $from_id = LinkRows.FromId
					     AND   $to_id =  LinkRows.ToId);
	 
	 

	 WITH LinkRows AS (
	SELECT Tag.$node_id AS FromId,
			(SELECT $node_id FROM Resources.Document WHERE Document.DocumentName = @DocumentName) AS ToId
	FROM STRING_SPLIT(@TagList,',')
			JOIN Classifications.Tag
				ON value = TagName
	)
	INSERT INTO Classifications.Categorizes
	(
	    $from_id,
	    $to_id
	)
	SELECT FromId, ToId
	FROM LinkRows
	WHERE  NOT EXISTS (SELECT *
					   FROM   Classifications.Categorizes
					   WHERE  $from_id = LinkRows.FromId
					     AND   $to_id =  LinkRows.ToId);

	COMMIT
END;
GO

SELECT PersonName, DocumentName, STRING_AGG(TagName,',') AS Tags
FROM   Classifications.Tag, Classifications.Categorizes, Resources.Document,
		Resources.Writes, Resources.Person
WHERE  MATCH(Tag-(Categorizes)->Document)
  AND  MATCH(Person-(Writes)->Document)
GROUP BY DocumentName, PersonName
