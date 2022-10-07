USE GraphDBTests
GO
CREATE SCHEMA GappedNestedSets
GO

CREATE TABLE GappedNestedSets.Company
(
    CompanyId   INT IDENTITY CONSTRAINT PKCompany PRIMARY KEY,
    Name        VARCHAR(20) CONSTRAINT AKCompany_Name UNIQUE,
	HierarchyLeft INT,
	HierarchyRight INT
	,CONSTRAINT AKCompany_HierarchyLeft__HierarchyRight
					 UNIQUE (HierarchyLeft,HierarchyRight)
);  
GO
--create unique index HierarchyRight__HierarchyLeft on GappedNestedSets.Company (HierarchyRight, HierarchyLeft)
--go

CREATE SEQUENCE GappedNestedSets.CompanyDataGenerator_SEQUENCE
AS INT
START WITH 1
GO
CREATE TABLE GappedNestedSets.Sale
(
	SalesId	INT NOT NULL IDENTITY (1,1) CONSTRAINT PKSale PRIMARY KEY,
	TransactionNumber VARCHAR(10) NOT NULL CONSTRAINT AKSale UNIQUE,
	Amount NUMERIC(12,2) NOT NULL,
	CompanyId INT NOT NULL REFERENCES GappedNestedSets.Company (CompanyId)
)
GO
CREATE INDEX XCompanyId ON GappedNestedSets.Sale(CompanyId, Amount)
go

CREATE PROCEDURE GappedNestedSets.Company$Insert(@Name varchar(20), @ParentCompanyName  varchar(20), @gapSize INT = 20) 
as 
BEGIN
	if @gapSize < 2
		throw 50000,'GapSize must be 2 or greater',1

	--note, enhancement ideas I have seen include leaving gaps to make inserts cheaper, but 
	--this would be far more complex, and certainly make the demo unwieldy. The inserts are 
	--slow compared to all other methods, but not impossibly so...
	SET NOCOUNT ON;
	BEGIN TRANSACTION

	if @ParentCompanyName is NULL
	 begin
		if exists (select * from GappedNestedSets.Company)
			THROW 50000,'More than one root node is not supported in this code',1;
		else
			insert into GappedNestedSets.Company (Name, HierarchyLeft, HierarchyRight)
			values (@Name, 1,1+@gapSize)
	 end 
	 ELSE
	 BEGIN


		if not exists (select * from GappedNestedSets.Company)
			THROW 50000,'You must start with a root node',1;

		--find the place in the Hierarchy where you will add a node
		DECLARE @ParentRight INT,
				@parentLeft INT,
				@childRight INT 
		select @ParentRight = HierarchyRight,
			   @parentLeft = HierarchyLeft 
		from   GappedNestedSets.Company 
		where Name = @ParentCompanyName

		select @childRight = MAX(HierarchyRight)
		FROM   GappedNestedSets.Company
		WHERE  HierarchyLeft > @parentLeft and HierarchyLeft < @ParentRight

		--select @ParentRight pr, @parentLeft pl, @childRight

		
		IF (@ChildRight IS NULL AND @ParentRight - @parentLeft >= 3) 
		  BEGIN	
				--SELECT 'quick'
				INSERT GappedNestedSets.Company (Name, HierarchyLeft, HierarchyRight)
				SELECT @Name, @parentLeft + 1, @parentLeft + 2 
		  END
		ELSE IF (@ChildRight IS NOT NULL AND @ParentRight - @ChildRight >= 3)
		  BEGIN	
				--SELECT 'quick'
				INSERT GappedNestedSets.Company (Name, HierarchyLeft, HierarchyRight)
				SELECT @Name, @childRight + 2, @childRight + 3 
		  END
		ELSE 
		BEGIN
		    --SELECT 'not quick'
			--make room for the new nodes.  
			UPDATE GappedNestedSets.Company 
			SET	   HierarchyRight = @gapSize + Company.HierarchyRight + 2, --for the parent node and all things right, add 2 to the hierachy right

				   --for all nodes right of the parent (not incl the parent), add 2
				   HierarchyLeft = Company.HierarchyLeft + CASE WHEN Company.HierarchyLeft > @ParentRight THEN  @gapSize + 2  ELSE 0 end
			WHERE  HierarchyRight >= @ParentRight

			--insert the node
			INSERT GappedNestedSets.Company (Name, HierarchyLeft, HierarchyRight)
			SELECT @Name, @ParentRight, @ParentRight + 1
		END
	END

	commit transaction
END
GO

CREATE PROCEDURE GappedNestedSets.Sale$InsertTestData
@Name varchar(20), 
@RowCount    int = 5
AS 
	SET NOCOUNT ON 
	WHILE @RowCount > 0
	  BEGIN
		INSERT INTO GappedNestedSets.Sale (TransactionNumber, Amount, CompanyId)
		SELECT	CAST (NEXT VALUE FOR GappedNestedSets.CompanyDataGenerator_SEQUENCE AS varchar(10)),
				.25 * CAST (NEXT VALUE FOR GappedNestedSets.CompanyDataGenerator_SEQUENCE AS numeric(12,2)), 
				(SELECT CompanyId FROM GappedNestedSets.Company WHERE Name = @Name)
		SET @rowCount = @rowCOunt - 1
	  END
GO

			             
CREATE OR ALTER FUNCTION GappedNestedSets.Company$ReturnHierarchy 
(
	@CompanyName VARCHAR(20)
) 

RETURNS @Output TABLE (CompanyId INT, Name VARCHAR(20), Level INT, Hierarchy NVARCHAR(4000), IdHierarchy NVARCHAR(4000), HierarchyDisplay NVARCHAR(4000))
AS
BEGIN
DECLARE @HierarchyLeft INT, @HierarchyRight INT

SELECT @HierarchyLeft = HierarchyLeft,
		@HierarchyRight = HierarchyRight
FROM  GappedNestedSets.Company
WHERE  Company.Name = @CompanyName;

WITH BaseRows AS
(
SELECT *, LAG(HierarchyRight,1) OVER (ORDER BY HierarchyLeft) AS PreviousHierarchyLeft
FROM   GappedNestedSets.Company
WHERE  HierarchyLeft >= @HierarchyLeft
 AND   HierarchyRight <= @HierarchyRight
),
LevelConfig AS (
SELECT *,
		CASE WHEN BaseRows.PreviousHierarchyLeft > HierarchyRight THEN 1
			    WHEN BaseRows.HierarchyRight - BaseRows.HierarchyLeft = 1 THEN 0
				WHEN BaseRows.PreviousHierarchyLeft < HierarchyRight THEN -1
				ELSE 0 END AS LevelMethod
FROM   BaseRows)
INSERT INTO @Output
(
    CompanyId,
    Name,
    Level,
    Hierarchy,
    IdHierarchy,
    hierarchyDisplay
)
SELECT CompanyId, Name, SUM(LevelConfig.LevelMethod) OVER (ORDER BY HierarchyLeft) + 1,
		'Not Feasible','Not feasible',
		CONCAT(REPLICATE ('--> ',SUM(LevelConfig.LevelMethod) OVER (ORDER BY HierarchyLeft)),Name) AS HieararchyDisplay
FROM   LevelConfig
ORDER BY HierarchyLEft;

RETURN

END
GO

CREATE OR ALTER FUNCTION GappedNestedSets.Company$CheckForChild
(
	@CompanyName varchar(20),
	@CheckForChildOfCompanyName VARCHAR(20)
) 
RETURNS Bit
AS 
BEGIN
	DECLARE @output BIT = 0;

	DECLARE @HierarchyLeft INT, @HierarchyRight INT

	DECLARE @CompanyId int
	SELECT  @CompanyId = CompanyId
	FROM  GappedNestedSets.Company
	WHERE  Company.Name = @CompanyName;

	SELECT @HierarchyLeft = HierarchyLeft,
			@HierarchyRight = HierarchyRight
	FROM   GappedNestedSets.Company
	WHERE  Name = @CheckForChildOfCompanyName;

	IF EXISTS (SELECT *
				FROM   GappedNestedSets.Company
				WHERE  HierarchyLeft >= @HierarchyLeft
				  AND   HierarchyRight <= @HierarchyRight
				  AND   CompanyId = @CompanyId)
	  SET @output = 1;
	RETURN @output;
END;
GO




CREATE OR ALTER  PROCEDURE GappedNestedSets.[Company$ReportSales]
(
	@DisplayFromNodeName VARCHAR(20) 
)
as
BEGIN

--aggregating over the Hierarchy
WITH ExpandedHierarchy AS
(
SELECT Company.CompanyId AS ParentCompanyId, Findrows.CompanyId AS ChildCompanyId,
		Company.hierarchyLeft AS OrderingDevice
from   GappedNestedSets.Company
		 JOIN GappedNestedSets.Company AS FindRows
			ON FindRows.HierarchyLeft BETWEEN Company.HierarchyLeft AND Company.HierarchyRight
),
FilterAndSweeten AS (

	SELECT ExpandedHierarchy.*, CompanyHierarchyDisplay.HierarchyDisplay
	from   ExpandedHierarchy
	JOIN GappedNestedSets.[Company$ReturnHierarchy](@DisplayFromNodeName) AS CompanyHierarchyDisplay
		ON CompanyHierarchyDisplay.CompanyId = ExpandedHierarchy.ParentCompanyId

	),
CompanyTotals AS
(
	SELECT CompanyId, SUM(Amount) AS TotalAmount
	FROM   GappedNestedSets.Sale
	GROUP BY CompanyId
),
Aggregations AS 
(
	SELECT FilterAndSweeten.ParentCompanyId, SUM(CompanyTotals.TotalAmount) AS TotalSalesAmount,
			MAX(HierarchyDisplay) AS HierarchyDisplay, MAX(FilterAndSweeten.OrderingDevice) AS OrderingDevice
	FROM   FilterAndSweeten
			 LEFT JOIN CompanyTotals
				ON CompanyTotals.CompanyId = FilterAndSweeten.ChildCompanyId
	GROUP  BY FilterAndSweeten.ParentCompanyId
)
SELECT Company.CompanyId, Company.NAME, Aggregations.TotalSalesAmount, HierarchyDisplay
FROM   GappedNestedSets.Company
		 JOIN Aggregations
		 ON Company.CompanyId = Aggregations.ParentCompanyId
ORDER BY Aggregations.OrderingDevice
END;
GO
