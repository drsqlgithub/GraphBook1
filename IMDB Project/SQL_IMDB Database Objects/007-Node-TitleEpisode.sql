
/****** Object:  Table [Imdb].[TitleEpisode]    Script Date: 3/3/2021 6:25:30 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
--DROP TABLE [Imdb].[TitleEpisode]

CREATE TABLE [Imdb].[TitleEpisode](
	[TitleId] int NOT NULL CONSTRAINT FKTitleEpisode$Ref$Title REFERENCES Imdb.Title(TitleId),
	[SeasonNumber] [int] NOT NULL,
	[EpisodeNumber] [int] NOT NULL,
 CONSTRAINT [PKTitleEpisode] PRIMARY KEY CLUSTERED 
(
	[TitleId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
)
AS NODE  WITH (DATA_COMPRESSION = PAGE)
GO