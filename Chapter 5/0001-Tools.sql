
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE schemas.name = 'Tools')
	EXECUTE ('CREATE SCHEMA Tools')
GO
CREATE OR ALTER FUNCTION Tools.Graph$EdgeIdFormat
(
	@edge_id nvarchar(1000)
) RETURNS nvarchar(30) 
AS
 BEGIN
	RETURN (
SELECT CAST(CONCAT(OBJECT_SCHEMA_NAME(OBJECT_ID_FROM_EDGE_ID(@edge_id)),'.',
		OBJECT_NAME(OBJECT_ID_FROM_EDGE_ID(@edge_id)),
		' id:',GRAPH_ID_FROM_EDGE_ID(@edge_id)) AS NVARCHAR(30)) AS [$edge_id]
		)
 END;
GO

CREATE OR ALTER FUNCTION Tools.Graph$NodeIdFormat
(
	@Node_id nvarchar(1000)
) RETURNS nvarchar(30) 
AS
 BEGIN
	RETURN (
SELECT CAST(CONCAT(OBJECT_SCHEMA_NAME(OBJECT_ID_FROM_NODE_ID(@node_id)),'.',
		OBJECT_NAME(OBJECT_ID_FROM_NODE_ID(@node_id)),
		' id:',GRAPH_ID_FROM_NODE_ID(@node_id)) AS NVARCHAR(30)) AS [$node_id]
		)
 END;
GO
