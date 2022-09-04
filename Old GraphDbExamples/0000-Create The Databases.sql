--NOTE: Before executing, change to SQLCMD mode
--takes about 7 seconds on my machine
--built to support rather large Hierarchy examples

USE master;
GO

SET NOCOUNT ON;
GO

--drop db if you are recreating it, dropping all connections to existing database.
IF EXISTS (   SELECT *
              FROM   sys.databases
              WHERE  Name = 'GraphDBTests')
    EXEC('
alter database  GraphDBTests
 
	set single_user with rollback immediate;

drop database GraphDBTests;');

:setvar dataFile "C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\"
:setvar logFile "C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\"

--:setvar dataFile "C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\DATA\"
--:setvar logFile "C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\DATA\"

CREATE DATABASE GraphDBTests CONTAINMENT = NONE
ON PRIMARY(Name = N'GraphDBTests',
           FILEName = N'$(dataFile)GraphDBTests.mdf',
           SIZE = 10GB,
           MAXSIZE = 20GB,
           FILEGROWTH = 2GB)

--If you want to do mem optimized tables in 2017, uncomment
-- ,FILEGROUP [MemoryOptimizedFG] CONTAINS MEMORY_OPTIMIZED_DATA  DEFAULT
--( Name = N'GraphDBTests_inmemFiles', FILEName = N'$(dataFile)GraphDBTestsInMemfiles' , MAXSIZE = UNLIMITED)

LOG ON(Name = N'GraphDBTests_log',
       FILEName = N'$(logFile)GraphDBTests_log.ldf',
       SIZE = 2GB,
       MAXSIZE = 4GB,
       FILEGROWTH = 1GB);
GO

ALTER DATABASE GraphDBTests SET RECOVERY SIMPLE;
GO
--This has proved VERY helpful on a desktop machine
ALTER DATABASE GraphDBTests SET DELAYED_DURABILITY=FORCED;
GO

------------------------------------------------------------------

--drop db if you are recreating it, dropping all connections to existing database.
IF EXISTS (   SELECT *
              FROM   sys.databases
              WHERE  Name = 'GraphDBTests_DataGenerator')
    EXEC('
alter database  GraphDBTests_DataGenerator
 
	set single_user with rollback immediate;

drop database GraphDBTests_DataGenerator;');


--:setvar dataFile "C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\DATA\"
--:setvar logFile "C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\DATA\"

CREATE DATABASE GraphDBTests_DataGenerator CONTAINMENT = NONE
ON PRIMARY(Name = N'GraphDBTests_DataGenerator',
           FILEName = N'$(dataFile)GraphDBTests_DataGenerator.mdf',
           SIZE = 10GB,
           MAXSIZE = 20GB,
           FILEGROWTH = 2GB)

--If you want to do mem optimized tables in 2017, uncomment
-- ,FILEGROUP [MemoryOptimizedFG] CONTAINS MEMORY_OPTIMIZED_DATA  DEFAULT
--( Name = N'GraphDBTests_DataGenerator_inmemFiles', FILEName = N'$(dataFile)GraphDBTests_DataGeneratorInMemfiles' , MAXSIZE = UNLIMITED)

LOG ON(Name = N'GraphDBTests_DataGenerator_log',
       FILEName = N'$(logFile)GraphDBTests_DataGenerator_log.ldf',
       SIZE = 2GB,
       MAXSIZE = 4GB,
       FILEGROWTH = 1GB);
GO

ALTER DATABASE GraphDBTests_DataGenerator SET RECOVERY SIMPLE;
GO
--This has proved VERY helpful on a desktop machine
ALTER DATABASE GraphDBTests_DataGenerator SET DELAYED_DURABILITY=FORCED;
GO

