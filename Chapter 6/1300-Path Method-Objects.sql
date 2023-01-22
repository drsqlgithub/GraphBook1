USE GraphDBTests;
GO

CREATE SCHEMA PathMethod;
GO

--use for surrogate creation to make the insert eaasier...
CREATE SEQUENCE PathMethod.Company_SEQUENCE AS INT START WITH 1;
GO

CREATE TABLE PathMethod.Company
(
    CompanyId INT          NOT NULL CONSTRAINT PKCompany PRIMARY KEY,
    Name      VARCHAR(20)  NOT NULL CONSTRAINT AKCompany_Name UNIQUE,
    Path      VARCHAR(1700) NOT NULL --indexes max out at 1700 bytes. Allows for at least a 1600+ deep Hierarchy, which is very deep
                                             --for most uses, but is a limitation. Removing the index could really hurt perf.
);

CREATE INDEX XPath
ON PathMethod.Company(Path);
GO

--same demo stuff as before
CREATE SEQUENCE PathMethod.CompanyDataGenerator_SEQUENCE
AS int
START WITH 1;
GO

CREATE TABLE PathMethod.Sale
(
    SalesId           int            NOT NULL IDENTITY(1, 1) CONSTRAINT PKSale PRIMARY KEY,
    TransactionNumber varchar(10)    NOT NULL CONSTRAINT AKSale UNIQUE,
    Amount            numeric(12, 2) NOT NULL,
    CompanyId         int            NOT NULL REFERENCES PathMethod.Company(CompanyId)
);
GO

CREATE INDEX XCompanyId
ON PathMethod.Sale
(
    CompanyId,
    Amount);
GO

CREATE PROCEDURE PathMethod.Company$Insert
(
    @Name              varchar(20),
    @ParentCompanyName varchar(20)
)
AS
BEGIN
    --gets Path, which looks like \CompanyId\CompanyId\...
    DECLARE @ParentPath varchar(1700) = COALESCE((  SELECT Company.Path
                                                    FROM   PathMethod.Company
                                                    WHERE  Company.Name = @ParentCompanyName), '\');
    --needn't use a SEQUENCE, but it made it easier to be able to do the next step 
    --in a single statement
    DECLARE @NewCompanyId int = NEXT VALUE FOR PathMethod.Company_SEQUENCE;

    --appends the new id to the parents Path 
    INSERT INTO PathMethod.Company(CompanyId, Name, Path)
    SELECT @NewCompanyId, @Name, @ParentPath + CAST(@NewCompanyId AS varchar(10)) + '\';
END;
GO

CREATE OR ALTER PROCEDURE PathMethod.Sale$InsertTestData
    @Name     varchar(20),
    @RowCount int = 5
AS
SET NOCOUNT ON;

WHILE @RowCount > 0
BEGIN
    INSERT INTO PathMethod.Sale(TransactionNumber, Amount, CompanyId)
    SELECT CAST(NEXT VALUE FOR PathMethod.CompanyDataGenerator_SEQUENCE AS varchar(10)),
           .25 * CAST(NEXT VALUE FOR PathMethod.CompanyDataGenerator_SEQUENCE AS numeric(12, 2)),
           (   SELECT Company.CompanyId
               FROM   PathMethod.Company
               WHERE  Company.Name = @Name);

    SET @RowCount = @RowCount - 1;
END;
GO





CREATE OR ALTER FUNCTION PathMethod.Company$ReturnHierarchy 
(
     @CompanyName varchar(20)
) 
RETURNS @Output TABLE (CompanyId INT, Name VARCHAR(20), 
                       Level INT, Hierarchy NVARCHAR(4000), 
                            IdHierarchy NVARCHAR(4000), 
                            HierarchyDisplay NVARCHAR(4000))
AS
 BEGIN 

DECLARE @CompanyId INT,
          @CompanyPath varchar(12),
          @CompanyPathReplace varchar(12)
          
--get the companyId and path for the item you want to get the child rows of
SELECT @CompanyId = CompanyId,
        @CompanyPath = CONCAT('\',CompanyId,'\'),
        @CompanyPathReplace = Path
FROM   PathMethod.Company
WHERE  Name = @CompanyName;

WITH BaseRows AS
(
--get the child rows using the simple like expression 
--to get child rows whose path startw with the parent
SELECT CompanyId, Name, 
        --make the path look like it starts at searched node
       REPLACE(path,@CompanyPathReplace,@CompanyPath) AS IdHierarchy
FROM   PathMethod.Company
WHERE  Path LIKE @CompanyPathReplace + '%'
)
--output the rows
INSERT INTO @Output
(
    CompanyId,
    Name,
    Level,
    Hierarchy,
    IdHierarchy,
    hierarchyDisplay
)
SELECT Baserows.CompanyId, BaseRows.Name
          , LEN(IdHierarchy) - LEN(REPLACE(BaseRows.IdHierarchy,'\',''))-1 AS Level,
          'Not Feasible' as Hierarchy,
          BaseRows.IdHierarchy,
          --put in the arrows for the simple output
           REPLICATE('--> ',LEN(IdHierarchy) - 
                LEN(REPLACE(BaseRows.IdHierarchy,'\',''))-2) + Name AS HierarchyDisplay
FROM BaseRows;
RETURN;
END 

GO


CREATE OR ALTER FUNCTION PathMethod.Company$CheckForChild
(
     @CompanyName varchar(20),
     @CheckForChildOfCompanyName VARCHAR(20)
) 
RETURNS Bit
AS 
BEGIN
     DECLARE @output BIT = 0;

     --get the companyId of the item passed in
     DECLARE @CompanyPath varchar(1700)
     SELECT  @CompanyPath = Path
     FROM   PathMethod.Company
     WHERE  Name = @CompanyName;

     --get the company id for the child
     DECLARE @CheckForChildOfCompanyPath varchar(1700)
     SELECT  @CheckForChildOfCompanyPath = Path
     FROM   PathMethod.Company
     WHERE  Name = @CheckForChildOfCompanyName;

     --IF the item IS A child OF the company TO check, the
     --path will include parent company
     IF REPLACE(@CompanyPath,@CheckForChildOfCompanyPath, '') <> @CompanyPath
       SET @output = 1;

	 RETURN @output
END;
GO




CREATE OR ALTER  PROCEDURE [PathMethod].[Company$ReportSales] 
(
     @DisplayFromNodeName VARCHAR(20) 
)
as
BEGIN

--take the expanded Hierarchy...
     WITH ExpandedHierarchy
AS (SELECT Company.CompanyId AS ParentCompanyId, ChildRows.CompanyId AS ChildCompanyId
    FROM   PathMethod.Company
           JOIN PathMethod.Company AS ChildRows
               ON ChildRows.Path LIKE Company.Path + '%'
     ),

     --add in the formatting code and filter (less of a concern in the method
     --as the first section does filter.
     FilterAndSweeten AS (

     SELECT ExpandedHierarchy.*, CompanyHierarchyDisplay.IdHierarchy, 
            CompanyHierarchyDisplay.HierarchyDisplay
     from   ExpandedHierarchy
     JOIN PathMethod.[Company$ReturnHierarchy](@DisplayFromNodeName) AS CompanyHierarchyDisplay
          ON CompanyHierarchyDisplay.CompanyId = ExpandedHierarchy.ParentCompanyId

     )
     ,
     --get totals for each Company for the aggregate
     CompanyTotals AS
     (
          SELECT CompanyId, SUM(Amount) AS TotalAmount
          FROM   PathMethod.Sale
          GROUP BY CompanyId
     ),
     --aggregate each Company for the Company
     Aggregations AS (
     SELECT FilterAndSweeten.ParentCompanyId,SUM(CompanyTotals.TotalAmount) AS TotalSalesAmount,
             MAX(FilterAndSweeten.IdHierarchy) AS IdHiearchy,
             MAX(FilterAndSweeten.HierarchyDisplay) AS HiearachyDisplay
     FROM   FilterAndSweeten
                LEFT JOIN CompanyTotals
                    ON CompanyTotals.CompanyId = FilterAndSweeten.ChildCompanyId
     GROUP  BY FilterAndSweeten.ParentCompanyId)

     --display the data...
     SELECT Company.CompanyId, Company.Name,  Aggregations.TotalSalesAmount,Aggregations.HiearachyDisplay
     FROM   PathMethod.Company 
               JOIN Aggregations
               ON Company.CompanyID = Aggregations.ParentCompanyID
     ORDER BY Aggregations.IdHiearchy
          

END;
GO



