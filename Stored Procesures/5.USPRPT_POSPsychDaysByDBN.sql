USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPRPT_POSPsychDaysByDBN]    Script Date: 4/4/2026 1:37:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[USPRPT_POSPsychDaysByDBN]
AS
/*
Sample call: exec dbo.USPRPT_POSPsychDaysByDBN
Purpose: This stored proc creates RPT_POSPsychDaysByDBN by rolling up RPT_POSPsychDaysDetail by DBN
		
		IMPORTANT NOTE: The number of psychologist days for all types of schools, 
		including High Schoolss, Middle Schools, Junior-High are loaded into this table.
		In order to exclude high schools for KIP Assignment by setting NumOfPsycDays to 0, then manipulation should happen 
		at vw_T5Capacity level not in the main table 

Modification History:
Name		Date		Comments
Raji		1/25/2025		Initial Draft
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @ETLProcessedDate date, @ETLProcessedDateTime datetime
	select @ETLProcessedDateTime = getdate()
	select @ETLProcessedDate = cast(@ETLProcessedDateTime as date)

	truncate table RPT_POSPsychDaysByDBN

	insert into dbo.RPT_POSPsychDaysByDBN(
		SchoolDBN
		, D75Site 
		,POSPsychDaysMonolingual
		,POSPsychDaysBilingual
		,POSPsychDaysSpanish
		,POSPsychDaysChinese
		,POSPsychDaysRussian
		,POSPsychDaysArabic
		,POSPsychDaysCantonese
		,POSPsychDaysHaitianCreole
		,POSPsychDaysHindi
		,POSPsychDaysKorean
		,POSPsychDaysMandarin
		,POSPsychDaysUrdu
		,ETLProcessedDate
		,ETLProcessedDateTime
	)
	Select 
		left(SchoolDBN, 6) as SchoolDBN,
		case when charindex('@',SchoolDBN,1) > 0 then right(SchoolDBN, len(SchoolDBN) - charindex('@',SchoolDBN,1)) else '' end as D75Site,
		isnull([English], 0) as POSPsychDaysMonolingual, 
		isnull([Spanish], 0) + isnull([Chinese], 0) + isnull([RUSSIAN], 0) + isnull([ARABIC], 0) + isnull([Cantonese], 0) +
			isnull([Haitian Creole], 0) + isnull([Hindi], 0) +	isnull([Korean], 0) + isnull([Mandarin], 0) +
			isnull([Urdu], 0) 
		as POSPsychDaysBilingual,
		isnull([Spanish], 0) as POSPsychDaysSpanish, 
		isnull([Chinese], 0) as POSPsychDaysChinese, 
		isnull([RUSSIAN], 0) as POSPsychDaysRussian, 
		isnull([ARABIC], 0) as POSPsychDaysArabic,
		isnull([Cantonese], 0) as POSPsychDaysCantonese,
		isnull([Haitian Creole], 0) as POSPsychDaysHaitianCreole,
		isnull([Hindi], 0) as POSPsychDaysHindi,
		isnull([Korean], 0) as POSPsychDaysKorean,
		isnull([Mandarin], 0) as POSPsychDaysMandarin,
		isnull([Urdu], 0) as POSPsychDaysUrdu,
		@ETLProcessedDate,
		@ETLProcessedDateTime
	from
	(
		select SchoolDBN, case when Language = 'Chinese(Both)' then 'Chinese' else Language end as Language, POSPsychDaysInDBN
		FROM RPT_POSPSYCHDAYSDetail
		where ETLProcessedDateTime = (SELECT MAX(ETLProcessedDateTime) FROM RPT_POSPSYCHDAYSDetail)
	) A
	PIVOT(
		sum(POSPsychDaysInDBN) 
		FOR Language in (
			[ARABIC],
			[Cantonese],
			[Chinese],
			[English],
			[Haitian Creole],
			[Hindi],
			[Korean],
			[Mandarin],
			[RUSSIAN],
			[Spanish],
			[Urdu]
		)
	) pv
	--order by 1

	--Archive
	insert into arch.RPT_POSPsychDaysByDBN(
		SchoolDBN
		, D75Site
		, POSPsychDaysMonolingual
		, POSPsychDaysBilingual
		, POSPsychDaysSpanish
		, POSPsychDaysChinese
		, POSPsychDaysRussian
		, POSPsychDaysArabic
		, POSPsychDaysCantonese
		, POSPsychDaysHaitianCreole
		, POSPsychDaysHindi
		, POSPsychDaysKorean
		, POSPsychDaysMandarin
		, POSPsychDaysUrdu
		, ETLProcessedDate
		, ETLProcessedDateTime
		, ArchivedDate
		, ArchivedDateTime
	)
	select
		SchoolDBN
		, D75Site
		, POSPsychDaysMonolingual
		, POSPsychDaysBilingual
		, POSPsychDaysSpanish
		, POSPsychDaysChinese
		, POSPsychDaysRussian
		, POSPsychDaysArabic
		, POSPsychDaysCantonese
		, POSPsychDaysHaitianCreole
		, POSPsychDaysHindi
		, POSPsychDaysKorean
		, POSPsychDaysMandarin
		, POSPsychDaysUrdu
		, ETLProcessedDate
		, ETLProcessedDateTime
		, @ETLProcessedDate ArchivedDate
		, @ETLProcessedDateTime ArchivedDateTime	
	from RPT_POSPsychDaysByDBN
END
