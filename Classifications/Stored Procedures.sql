USE CategorizationGraph
GO
CREATE OR ALTER PROCEDURE Resources_UI.DocumentCreate(
	@AuthorName NVARCHAR(100),
	@DocumentName NVARCHAR(100),
	@DocumentType VARCHAR(30),
	@DocumentStatus VARCHAR(30),
	@PublishDate DATE = NULL,
	@TagList NVARCHAR(MAX),
	@ViewCount INT,
	@Url NVARCHAR(3000)
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
			PublishDate,
			ViewCount,
			Url
		)
		VALUES
		(   @DocumentName,
			@DocumentType,
			@DocumentStatus,
			@PublishDate,
			@ViewCount,
			@Url
		);
	ELSE
		UPDATE Resources.Document
		SET DocumentStatus = @DocumentStatus,
			PublishDate = @PublishDate,
			DocumentType = @DocumentType,
			ViewCount = @ViewCount,
			Url = @Url
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

CREATE OR ALTER TRIGGER Resources.Document$updateTime_Trigger
ON Resources.Document
FOR UPDATE
AS
BEGIN
	UPDATE Resources.Document
	SET Document.RowLastModifiedTime = SYSDATETIME(),
		Document.ViewCountLastCapturedChangeTime = CASE WHEN COALESCE(Document.ViewCount,-1) <> COALESCE(Inserted.ViewCount,-1) OR Document.ViewCountLastCapturedChangeTime IS NULL THEN SYSDATETIME() ELSE Document.ViewCountLastCapturedChangeTime END
	FROM   Resources.Document
			JOIN Inserted
				ON Inserted.DocumentId = Document.DocumentId
END
GO