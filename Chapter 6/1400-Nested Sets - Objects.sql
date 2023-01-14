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

CREATE or alter PROCEDURE GappedNestedSets.Company$Insert(
	@Name varchar(20), 
	@ParentCompanyName  varchar(20), 
	@gapSize INT = 20 --amount of space to leave between new nodes when there is space
	) 
as 
BEGIN
	if @gapSize < 2
		throw 50000,'GapSize must be 2 or greater',1

	--note, enhancement ideas I have seen include leaving gaps to make inserts cheaper, but 
	--this would be far more complex, and certainly make the demo unwieldy. The inserts are 
	--slow compared to all other methods, but not impossibly so...
	SET NOCOUNT ON;
	BEGIN TRANSACTION

	--this take care of the initialization phase, and can only happen once
	--but it is a variable comparison so it is work keeping
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

		--checks to make sure a row exists already
		if not exists (select * from GappedNestedSets.Company)
			THROW 50000,'You must start with a root node',1;

		--find the place in the Hierarchy where you will add a node
		--as a child. 
		DECLARE @ParentRight INT,
				@parentLeft INT,
				@childRight INT 
		select @ParentRight = HierarchyRight,
			   @parentLeft = HierarchyLeft 
		from   GappedNestedSets.Company 
		where Name = @ParentCompanyName

		--get the right value for any existing child of the parent node
		select @childRight = MAX(HierarchyRight)
		FROM   GappedNestedSets.Company
		WHERE  HierarchyLeft > @parentLeft and HierarchyLeft < @ParentRight

		--select @ParentRight pr, @parentLeft pl, @childRight

		--if no node exists for the parent, easy mode, we insert it
		IF (@ChildRight IS NULL AND @ParentRight - @parentLeft >= 3) 
		  BEGIN	
				--This means you can just add it in wihtout 
				INSERT GappedNestedSets.Company (Name, HierarchyLeft, HierarchyRight)
				SELECT @Name, @parentLeft + 1, @parentLeft + 2 
		  END
		--if a child does exist, and there is space for it (no gap)
		--we can simply insert it to the right of the other child (so 2 and 3 away_
		ELSE IF (@ChildRight IS NOT NULL 
		         AND @ParentRight - @ChildRight >= 3) --3 means there is space for 2 values
		  BEGIN	
				--just insert it
				INSERT GappedNestedSets.Company (Name, HierarchyLeft, HierarchyRight)
				SELECT @Name, @childRight + 2, @childRight + 3 
		  END
		ELSE 
		BEGIN
		    
			--make room for the new nodes by pushing all the other nodes in the tree to the right
			--enough for the new nodes (plus the 
			UPDATE GappedNestedSets.Company 
			SET	   HierarchyRight = @gapSize + Company.HierarchyRight + 2, --for the parent node and all things right, add 2 to the hierachy right

				   --for all nodes right of the parent (not incl the parent), add 2
				   HierarchyLeft = Company.HierarchyLeft + CASE WHEN Company.HierarchyLeft > @ParentRight THEN  @gapSize + 2  ELSE 0 end
			WHERE  HierarchyRight >= @ParentRight

			--insert the chikd node (i erred on the side of caution that since most items would be leaf nodes
			--in most trees, I did not leave a gap.
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

RETURNS @Output TABLE (CompanyId INT, Name VARCHAR(20), 
                       Level INT, Hierarchy NVARCHAR(4000), 
                       IdHierarchy NVARCHAR(4000), 
					   HierarchyDisplay NVARCHAR(4000))
AS
BEGIN
DECLARE @HierarchyLeft INT, @HierarchyRight INT

--get the left and right values from the hierarchy
--so we can get the child rows
SELECT @HierarchyLeft = HierarchyLeft,
		@HierarchyRight = HierarchyRight
FROM  GappedNestedSets.Company
WHERE  Company.Name = @CompanyName;

WITH BaseRows AS
(
SELECT *, --the lag gets us the value of HierarchyLeft for the previous row in the tree
		LAG(HierarchyRight,1) OVER (ORDER BY HierarchyLeft) AS PreviousHierarchyLeft
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
		'Not Feasible','Not feasible', --getting all the other values in the tree isn't feasible, but
									   --replicating the cleanest view is
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

	--translate the child companyId from parameter
	DECLARE @CompanyId int
	SELECT  @CompanyId = CompanyId
	FROM  GappedNestedSets.Company
	WHERE  Company.Name = @CompanyName;

	--the the position in the tree of the row being checked as the parent row
	SELECT @HierarchyLeft = HierarchyLeft,
			@HierarchyRight = HierarchyRight
	FROM   GappedNestedSets.Company
	WHERE  Name = @CheckForChildOfCompanyName;

	--see if the values of left and right of the 
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
--fetch the rows we are going to output. Here we are getting the
--parent and child matched up
SELECT Company.CompanyId AS ParentCompanyId, Findrows.CompanyId AS ChildCompanyId,
		Company.hierarchyLeft AS OrderingDevice
from   GappedNestedSets.Company
		 JOIN GappedNestedSets.Company AS FindRows
			ON FindRows.HierarchyLeft BETWEEN Company.HierarchyLeft AND Company.HierarchyRight
),
FilterAndSweeten AS (
	--then we filter using the retorn hierarchy proc (and get the output stuff we need for display
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
	--Sum up rows and output, sorting by the value of their hierarcy left (which is included as OrderingDevice)
	SELECT FilterAndSweeten.ParentCompanyId, SUM(CompanyTotals.TotalAmount) AS TotalSalesAmount,
			MAX(HierarchyDisplay) AS HierarchyDisplay, MAX(FilterAndSweeten.OrderingDevice) AS OrderingDevice
	FROM   FilterAndSweeten
			 LEFT JOIN CompanyTotals
				ON CompanyTotals.CompanyId = FilterAndSweeten.ChildCompanyId
	GROUP  BY FilterAndSweeten.ParentCompanyId
)
--ooutput the rows
SELECT Company.CompanyId, Company.NAME, Aggregations.TotalSalesAmount, HierarchyDisplay
FROM   GappedNestedSets.Company
		 JOIN Aggregations
		 ON Company.CompanyId = Aggregations.ParentCompanyId
ORDER BY Aggregations.OrderingDevice
END;
GO
