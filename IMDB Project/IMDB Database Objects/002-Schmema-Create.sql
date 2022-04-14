USE Imdb
GO
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE schemas.name = 'Imdb')
	EXECUTE ('CREATE SCHEMA Imdb')
GO
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE schemas.name = 'ImdbInterface')
	EXECUTE ('CREATE SCHEMA ImdbInterface')

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE schemas.name = 'RelationalEdge')
	EXECUTE ('CREATE SCHEMA RelationalEdge')