USE ImdbRelational
GO
DROP TABLE IF EXISTS imdb.profession
GO
CREATE TABLE [Imdb].[Profession](
	ProfessionId INT IDENTITY CONSTRAINT PKProfession PRIMARY KEY,
	[ProfessionName] [VARCHAR](100) NOT NULL,
 CONSTRAINT [AKProfession] UNIQUE
(
	[ProfessionName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
)
 WITH (DATA_COMPRESSION = PAGE)
GO
