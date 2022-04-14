Download files from:
https://datasets.imdbws.com/

Files are gz files. Used: https://www.7-zip.org/ to unpack them

Files locations are set in the ProjectParams
	Set the root directory with the RootDirectory parameter.

Edit and execute the CreateDirectories.cmd file to create a set of directories to hold the files 

Unzipe the files and drop the unzipped files with the name data.tsv (as it comes in the gz files)

Use he 3 SQL files to create the databases and objects (edit the 001-CreateDatabase.sql file for your directories)

Use the SSIS package to load the staging database.

Use the staging database with the IMDB database code.
