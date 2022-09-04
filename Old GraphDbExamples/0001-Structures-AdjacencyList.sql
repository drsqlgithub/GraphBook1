USE GraphDBTests;
GO

/********************
Simple adjacency list
********************/

DROP PROCEDURE IF EXISTS AdjacencyList.Company$ReturnHierarchy_WHILELOOP;
DROP PROCEDURE IF EXISTS AdjacencyList.Company$ReturnHierarchy_CTE;
DROP PROCEDURE IF EXISTS AdjacencyList.Company$AggregateHierarchy_CTE
DROP PROCEDURE IF EXISTS AdjacencyList.Company$Reparent;
DROP PROCEDURE IF EXISTS AdjacencyList.Company$Delete;
DROP PROCEDURE IF EXISTS AdjacencyList.Company$Insert;
DROP FUNCTION IF EXISTS AdjacencyList.Company$returnHierarchyHelper;
DROP PROCEDURE IF EXISTS AdjacencyList.Sale$InsertTestData;
DROP TABLE IF EXISTS AdjacencyList.Sale;
DROP TABLE IF EXISTS AdjacencyList.Company;
DROP SEQUENCE IF EXISTS AdjacencyList.CompanyDataGenerator_SEQUENCE;

DROP SCHEMA IF EXISTS AdjacencyList;
GO

CREATE SCHEMA AdjacencyList;
GO

CREATE TABLE AdjacencyList.Company
(
    CompanyId       int         IDENTITY(1, 1) CONSTRAINT PKCompany PRIMARY KEY,
    Name            varchar(20) NOT NULL CONSTRAINT AKCompany_Name UNIQUE,
    ParentCompanyId int         NULL 
	CONSTRAINT FKCompany$isParentOf$AdjacencyListCompany 
									REFERENCES AdjacencyList.Company( CompanyId),
     --used when fetching rows by their parentCompanyId
	INDEX XCorporate_Company_ParentCompanyId CLUSTERED (ParentCompanyId)
);


--this object is simply used to generate a Company Name to make the demo a bit more textual.
--it would not be used for a "real" build

CREATE SEQUENCE AdjacencyList.CompanyDataGenerator_SEQUENCE
AS int
START WITH 1;
GO

CREATE TABLE AdjacencyList.Sale
(
    SalesId           int            NOT NULL IDENTITY(1, 1) CONSTRAINT PKSale PRIMARY KEY,
    TransactionNumber varchar(10)    NOT NULL CONSTRAINT AKSale UNIQUE,
    Amount            numeric(12, 2) NOT NULL,
    CompanyId         int            NOT NULL REFERENCES AdjacencyList.Company(CompanyId),
	INDEX XCompanyId (CompanyId, Amount)
);
GO

--the sale table is here for when we do aggregations to make the situation more "real".
--note that I just use a sequential number for the Amount. This makes sure that when we do aggregations
--on each type that the value is the exact same.

CREATE PROCEDURE AdjacencyList.Sale$InsertTestData
    @Name     varchar(20), --Note that all procs use natural keys to make it easier for you to work with manually.
                           --If you are implementing this for a tool to manipulate, use the surrogate keys
    @RowCount int = 5
AS
SET NOCOUNT ON;

WHILE @RowCount > 0
BEGIN
    INSERT INTO AdjacencyList.Sale(TransactionNumber, Amount, CompanyId)
    SELECT CAST(NEXT VALUE FOR AdjacencyList.CompanyDataGenerator_SEQUENCE AS varchar(10)),
           CAST(NEXT VALUE FOR AdjacencyList.CompanyDataGenerator_SEQUENCE AS numeric(12, 2)),
           (   SELECT Company.CompanyId
               FROM   AdjacencyList.Company
               WHERE  Company.Name = @Name);

    SET @RowCount = @RowCount - 1;
END;
GO

