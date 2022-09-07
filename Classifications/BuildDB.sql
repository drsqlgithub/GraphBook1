CREATE DATABASE CategorizationGraph
GO

USE CategorizationGraph
GO

CREATE SCHEMA Classifications
GO
CREATE SCHEMA Resources
GO


DROP TABLE IF EXISTS Resources.Writes
DROP TABLE IF EXISTS Classifications.Categorizes

DROP TABLE IF EXISTS Resources.Person
DROP TABLE IF EXISTS Resources.Document


DROP TABLE IF EXISTS Classifications.Tag


CREATE TABLE Resources.Person
(
	PersonId  INT IDENTITY NOT NULL CONSTRAINT PKPerson PRIMARY KEY,
	PersonName NVARCHAR(100) NOT NULL,
	RowCreatedTime DATETIME2(0) NOT NULL CONSTRAINT DFLTPerson_RowCreatedTime DEFAULT (SYSDATETIME()),
	RowLastModifiedTime DATETIME2(0) NOT NULL CONSTRAINT DFLTPerson_RowLastModifiedTime DEFAULT (SYSDATETIME())
) AS NODE;

CREATE TABLE Resources.Document
(
	DocumentId  INT IDENTITY NOT NULL CONSTRAINT PKDocument PRIMARY KEY,
	DocumentName NVARCHAR(100) NOT NULL,
	DocumentType VARCHAR(30) NOT NULL,
	DocumentStatus VARCHAR(30) NOT NULL,
	PublishDate DATE NULL,
	RowCreatedTime Datetime2(0) NOT NULL CONSTRAINT DFLTDocument_RowCreatedTime DEFAULT (SYSDATETIME()),
	RowLastModifiedTime Datetime2(0) NOT NULL CONSTRAINT DFLTDocument_RowLastModifiedTime DEFAULT (SYSDATETIME()),
	CONSTRAINT CHKDocument_PublishDate CHECK (PublishDate IS NULL OR (PublishDate IS NOT NULL AND DocumentStatus = 'Published'))
) AS NODE

CREATE TABLE Classifications.Tag
(
	TagId  INT IDENTITY NOT NULL CONSTRAINT PKTag PRIMARY KEY,
	TagName NVARCHAR(100) NOT NULL,
	RowCreatedTime Datetime2(0) NOT NULL CONSTRAINT DFLTTag_RowCreatedTime DEFAULT (SYSDATETIME()),
	RowLastModifiedTime Datetime2(0) NOT NULL CONSTRAINT DFLTTag_RowLastModifiedTime DEFAULT (SYSDATETIME())
) AS NODE

CREATE TABLE Resources.Writes(
CONSTRAINT ECWrites CONNECTION (Resources.Person TO Resources.Document)) AS EDGE

CREATE TABLE Classifications.Categorizes(
CONSTRAINT ECWrites CONNECTION (Classifications.Tag TO Resources.Document,
								Classifications.Tag TO Classifications.Tag)) AS EDGE



