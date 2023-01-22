USE ImagesDirectory
GO

CREATE OR ALTER PROCEDURE Locations.[ItemType$Maintain]
(
	@ItemClass VARCHAR(100),
	@ItemType VARCHAR(100),
	@Description VARCHAR(1000)
) 
AS
 BEGIN
	SET NOCOUNT ON;

	DECLARE @ItemClassId INT = (SELECT ItemClassId FROM Locations.ItemClass WHERE ItemClass = @ItemClass),
			@Msg NVARCHAR(1000)
	
	IF @ItemClassId IS NULL
	  BEGIN
		SET @Msg = CONCAT('Invalid ItemClass:',@ItemClass);
		THROW 50000,@msg, 1;
	  END;

	UPDATE Locations.ItemType
	SET   Description = @Description,
			ItemClassId = @ItemClassId
	WHERE ItemType = @ItemType
	IF @@ROWCOUNT = 0 
	   	INSERT INTO Locations.ItemType(ItemType,ItemClassId,Description)
		VALUES (@ItemType, @ItemClassId, @Description)


 END;
GO



CREATE OR ALTER PROCEDURE [Locations].[Item$Maintain]
(
	@ItemName	VARCHAR(100),
	@ItemType VARCHAR(100),
	@Description VARCHAR(1000),
	@HashTag VARCHAR(100),
	@CreateDirectoryFlag BIT
)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @msg NVARCHAR(1000),
			@ItemTypeId INT 

	SELECT @ItemTypeId = ItemTypeId
	FROM  Locations.ItemType
	WHERE  ItemType.ItemType = @ItemType

	IF @ItemTypeId IS NULL 
	  BEGIN
		SET @msg = CONCAT('Invalid ItemType or ItemClass sent to procedure. ItemType:', @ItemType);
		THROW 50000, @msg, 1;
	  END

	  UPDATE Locations.Item
	  SET  Description = @Description,
		   HashTag = @HashTag,
		   CreateDirectoryFlag = @CreateDirectoryFlag
	  WHERE  ItemName = @ItemName

	  INSERT INTO Locations.Item
	  (
	      ItemName,
	      Description,
		  HashTag,
		  CreateDirectoryFlag
	  )
	  VALUES
	  (   @ItemName,
	      @Description,
		  @HashTag,
		  @CreateDirectoryFlag
	      )


 END;

GO

