USE Tempdb
GO

DECLARE @TargetDatabase sysname = 'ImportTest'

DECLARE @TargetSchema sysname = 'Demo';
DECLARE @IndependentEdgesFlag bit = 1 --Each edge type gets its own table.
DECLARE @MergeMethod varchar(30) = 'DELETE'; 
DECLARE @UniqueifyDuplicateNodes bit = 1;
DECLARE @filenameLike nvarchar(100) = 'NodeType-DefaultEdgeType-Sample'

DROP TABLE IF EXISTS #Node;
CREATE TABLE #Node(
	[Filename] [nvarchar](200) NOT NULL,
	[NodeId] [int] NOT NULL,
	[Name] [nvarchar](100) NOT NULL,
	[NodeType] [nvarchar](100) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Filename] ASC,
	[NodeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY];


WITH BaseRows AS (
SELECT Node.Filename, NodeId, Name, Node.NodeType, ROW_NUMBER() OVER (PARTITION BY Node.Filename, Node.NodeType, Node.Name ORDER BY Node.NodeId) AS NodeNum
FROM   NodeStaging.Node
)
INSERT INTO #Node(FileName, NodeId, Name, NodeType)
SELECT FileName, NodeId, CONCAT(Name, CASE WHEN NodeNum > 1 THEN ' (' + CAST(NodeNum AS varchar(10)) + ')' ELSE NULL END) AS Name, NodeType
FROM   BaseRows;




DECLARE @NodeCursor CURSOR, @EdgeCursor CURSOR, @filenameCursor CURSOR,
	    @NodeTableName sysname, @EdgeTableName sysname, @filename nvarchar(200);
DECLARE @crlf nvarchar(2) = CHAR(13) + CHAR(10)


DECLARE @Table table (outputId int IDENTITY, outputValue nvarchar(4000))


INSERT INTO @Table (outputValue)
SELECT 'USE ' + @TargetDatabase + @crlf + 'GO'

SET NOCOUNT ON;
INSERT INTO @Table (outputValue)
SELECT 'IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = ''' + @TargetSchema + ''')' + @crlf + 
	'      EXEC (''CREATE SCHEMA ' + QUOTENAME(@TargetSchema) + ''');'


SET @NodeCursor = CURSOR FOR (
	SELECT DISTINCT NodeType
	FROM   #Node
	WHERE  filename LIKE @filenameLike
	)
OPEN @NodeCursor

WHILE (1=1)
 BEGIN
	FETCH NEXT FROM @NodeCursor INTO @NodeTableName
	IF @@FETCH_STATUS <> 0		
		BREAK
	
	INSERT INTO @Table (outputValue)
	SELECT 'IF NOT EXISTS (SELECT * FROM Sys.Tables where schema_id = SCHEMA_ID(''' + @TargetSchema + ''') AND name = ''' + REPLACE(@NodeTableName,'''','''''''') + ''' and type = ''U'')' + @crlf +
	       '      CREATE TABLE ' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@NodeTableName) + '(' + @NodeTableName + 'Id INT Identity CONSTRAINT PK' + @NodeTableName + ' PRIMARY KEY, ' + @crlf +
		   '            Name varchar(100) NOT NULL CONSTRAINT ' + QUOTENAME('AK' + @NodeTableName) + ' UNIQUE) AS NODE;' + @crlf + @crlf + 
		   CASE WHEN @MergeMethod = 'DELETE'
			THEN 'DELETE FROM ' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@NodeTableName)
			ELSE '' END

 END;

CLOSE @NodeCursor;

SET @EdgeCursor = CURSOR FOR (
	SELECT DISTINCT EdgeType
	FROM   Tempdb.NodeStaging.Edge
	WHERE  filename LIKE @filenameLike
	)
OPEN @EdgeCursor

WHILE (1=1)
 BEGIN
	FETCH NEXT FROM @EdgeCursor INTO @EdgeTableName
	IF @@FETCH_STATUS <> 0		
		BREAK

	INSERT INTO @Table (outputValue)
	SELECT 'IF NOT EXISTS (SELECT * FROM Sys.Tables where schema_id = SCHEMA_ID(''' + @TargetSchema + ''') AND name = ''' + REPLACE(@EdgeTableName,'''','''''') + ''' and type = ''U'')' + @crlf +
	       '      CREATE TABLE ' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@EdgeTableName) + ' AS EDGE'+ @crlf + @crlf + 
		   CASE WHEN @MergeMethod = 'DELETE'
			THEN 'DELETE FROM ' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@EdgeTableName)
			ELSE '' END ;

 END;


IF EXISTS (SELECT Name
		   FROM  #Node
		   WHERE  filename LIKE @filenameLike
		   GROUP BY Name
		   HAVING COUNT(*) > 1)--Queries to output the nodes that have been created
 BEGIN
	INSERT INTO @Table (outputValue)
	SELECT '--' + @crlf + '--Note: there are duplicate nodes treated as one in this script' + @crlf + '--';
 END

SET @filenameCursor = CURSOR FOR (
	SELECT DISTINCT filename
	FROM   #Node
	WHERE  filename LIKE @filenameLike
	)
OPEN @filenameCursor

WHILE (1=1)
 BEGIN
	FETCH NEXT FROM @filenameCursor INTO @FileName
	IF @@FETCH_STATUS <> 0		
		BREAK
	
	INSERT INTO @Table (outputValue)
	SELECT DISTINCT 'INSERT INTO ' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@NodeTableName) + '(Name)' + @crlf + 
	       'VALUES (''' + REPLACE(Name,'''','''''') + ''');'
	FROM   #Node
	WHERE  filename LIKE @filenameLike

 END;

CLOSE @filenameCursor;

SET @filenameCursor = CURSOR FOR (
	SELECT DISTINCT filename
	FROM   #Node
	WHERE  filename LIKE @filenameLike
	)
OPEN @filenameCursor

WHILE (1=1)
 BEGIN
	FETCH NEXT FROM @filenameCursor INTO @FileName
	IF @@FETCH_STATUS <> 0		
		BREAK

	SET @NodeTableName = (SELECT MAX(NodeType) FROM #Node AS Node WHERE Node.Filename = @FileName);
	
	WITH Nodes AS (
		SELECT fromNode.name AS FromNode, ToNode.name AS ToNode, Edge.EdgeType
		FROM   NodeStaging.Edge
			JOIN #Node AS FromNode
				ON Edge.FromNodeId = FromNode.NodeId
					AND FromNode.Filename = Edge.Filename
			JOIN #Node AS ToNode
				ON Edge.ToNodeId = ToNode.NodeId
					AND ToNode.Filename = Edge.Filename
		WHERE Edge.FileName = 'NodeType-DefaultEdgeType-Sample')

	INSERT INTO @Table (outputValue)
	SELECT 'INSERT INTO ' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(EdgeType) + '($From_id,$To_Id)' + @crlf + 
	       'SELECT (SELECT $node_id FROM ' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@NodeTableName) + ' WHERE ' + QUOTENAME(@NodeTableName) + '.Name = ''' + REPLACE(Nodes.FromNode,'''','''''') + '''),' + @crlf +
		   '       (SELECT $node_id FROM ' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@NodeTableName) + ' WHERE ' + QUOTENAME(@NodeTableName) + '.Name = ''' + REPLACE(Nodes.ToNode,'''','''''') + ''')'
	FROM  Nodes

 END;

CLOSE @filenameCursor;


--ouput the script
SELECT OutputValue + @crlf + @crlf
FROM   @Table
ORDER BY outputId asc



 /*

CREATE SCHEMA Demo;
GO
CREATE TABLE Demo.NodeType (NodeTypeId int, Name varchar(100));
GO
CREATE TABLE Demo.DefaultEdgeType
GO
CREATE TABLE Demo.
*/


