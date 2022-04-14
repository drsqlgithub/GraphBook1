CREATE PROCEDURE Tools.GraphDB$LookupItem
(
	@ObjectId int,
	@Id int 
)
AS
BEGIN
	DECLARE @SchemaName sysname = OBJECT_SCHEMA_NAME(@ObjectId),
		    @TableName sysname = OBJECT_NAME(@ObjectId),
	        @SQLStatement nvarchar(MAX)
	SET @SQLStatement = CONCAT('SELECT * FROM ', QUOTENAME(@SchemaName),'.',QUOTENAME(@TableName),
			' WHERE JSON_VALUE(CAST($node_id AS nvarchar(1000)),''$.id'') = ',@Id)

	EXECUTE (@SQLStatement)
END;
GO