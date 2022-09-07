--SELECT *
--FROM   Resources.Person
--SELECT *
--FROM   Resources.Document
--SELECT *
--FROM   Resources.Writes



DECLARE @EdgeSchema sysname = 'Resources',
		@EdgeName sysname = 'Writes',

		@FromSchema sysname = 'Resources',
		@FromObject sysname = 'Person',
		@FromObjectColumnName sysname = 'PersonName',
		@FromObjectColumnNameAS sysname ,

		@ToSchema sysname = 'Resources',
		@ToObject sysname = 'Document',
		@ToObjectColumnName sysname = 'DocumentName',
		@ToObjectColumnNameAS sysname,


		@NameDelimiter CHAR(1) = '_'
		,@crlf nvarchar(2) = CHAR(13) + CHAR(10)
		
DECLARE @Query TABLE (LineNumber INT PRIMARY KEY, Line VARCHAR(1000))

INSERT INTO @Query (LineNumber, Line)
VALUES 
     
       
       (1,CONCAT('IF NOT EXISTS (SELECT * FROM sys.schemas WHERE schemas.name = ''', @EdgeSchema,'_UI'')')),
	   (2,CONCAT( 'EXECUTE (''CREATE SCHEMA ',@EdgeSchema,'_UI'')',@crlf,'GO')),
	   (10, CONCAT('CREATE OR ALTER VIEW ',@EdgeSchema,'_UI.', CASE WHEN @EdgeSchema <> @FromSchema THEN @FromSchema END + @NameDelimiter,@FromObject,@NameDelimiter,@EdgeName,@NameDelimiter, CASE WHEN @EdgeSchema <> @ToSchema THEN @ToSchema END,
					@ToObject)),
	   (20, 'AS'),
	   (30, CONCAT('SELECT ', @FromObject,'.',@FromObjectColumnName, ' AS ', COALESCE(@FromObjectColumnNameAS, @FromObjectColumnName), ', ',@EdgeName,@ToObject,'.',@ToObjectColumnName, ' AS ', COALESCE(@ToObjectColumnNameAS, @ToObjectColumnName))),
	   (40, CONCAT('FROM   ',@FromSchema,'.',@FromObject,',',@EdgeSchema, '.',@EdgeName,',',@ToSchema,'.',@ToObject, ' AS ',@EdgeName,@ToObject)),
	   (50, CONCAT('WHERE MATCH(',@FromObject,'-(',@EdgeName,')->',@EdgeName,@ToObject,')')),
	   (60, 'GO'),
	   (70,''),
	   (80, CONCAT('CREATE OR ALTER TRIGGER ',@EdgeSchema,'_UI.'
	   	   , CASE WHEN @EdgeSchema <> @FromSchema THEN @FromSchema END + @NameDelimiter,@FromObject,@NameDelimiter,@EdgeName,@NameDelimiter, CASE WHEN @EdgeSchema <> @ToSchema THEN @ToSchema END,
					@ToObject,'$InsteadOfInsertTrigger')),
		(90, CONCAT('ON ',@EdgeSchema,'_UI.', CASE WHEN @EdgeSchema <> @FromSchema THEN @FromSchema END + @NameDelimiter,@FromObject,@NameDelimiter,@EdgeName,@NameDelimiter, CASE WHEN @EdgeSchema <> @ToSchema THEN @ToSchema END,
					@ToObject)),
		(100,CONCAT('INSTEAD OF INSERT',@crlf,'AS',@crlf,'SET NOCOUNT ON',@CRLF,'  BEGIN')),
		(110, CONCAT('   INSERT INTO ',@EdgeSchema,'.',@EdgeName,'($from_id, $to_id)')),
		(120, CONCAT('   SELECT ',@FromObject,'.$node_id, ',@EdgeName,@ToObject,'.$node_id' )),
		(130, '   FROM Inserted'),
		(140, CONCAT('         JOIN ',@FromSchema,'.',@FromObject)),
		(150, CONCAT('                ON ',@FromObject,'.',@FromObjectColumnName,' = Inserted.',@FromObjectColumnName)),
		(160, CONCAT('         JOIN ',@ToSchema,'.',@ToObject,' AS ',@EdgeName,@ToObject)),
		(170, CONCAT('                ON ',@EdgeName,@ToObject,'.',@ToObjectColumnName,' = Inserted.',@ToObjectColumnName)),
		(180, CONCAT('   END;',@crlf,'GO',@crlf))
		

SELECT Line
FROM  @Query
ORDER BY LineNumber

--CREATE OR ALTER TRIGGER Network_UI.Person_FollowsPerson_$InsteadOfInsertTrigger
--ON Network_UI.Person_Follows_Person
--INSTEAD OF INSERT
--AS
--SET NOCOUNT ON;
-- --If you add more code, you should add error handling code.
-- BEGIN 
--  INSERT INTO Network.Follows($from_id, $to_id, Value)
--  SELECT Person.$node_id, FollowedPerson.$node_id, 
--		inserted.Value
--  FROM Inserted
--       JOIN Network.Person
--           ON Person.PersonId = Inserted.PersonId
--       JOIN Network.Person AS FollowedPerson
--           ON FollowedPerson.PersonId = Inserted.FollowsPersonId;
-- END;
