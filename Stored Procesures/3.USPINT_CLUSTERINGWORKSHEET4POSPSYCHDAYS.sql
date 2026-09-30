USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPINT_CLUSTERINGWORKSHEET4POSPSYCHDAYS]    Script Date: 4/4/2026 1:33:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[USPINT_CLUSTERINGWORKSHEET4POSPSYCHDAYS]
/*
Sample call: exec USPINT_CLUSTERINGWORKSHEET4POSPSYCHDAYS
Purpose: This stored proc cleans up the values in DWH layer and readies the data for RPT layer 
		1. If "Schools" fields have any special character other than '@', ',' or 'space', replace by 'comma'
		2. Make sure "Language" and "LanguageDelivery" are aligned (English <--> Monolingual, non-English <--> BiLingual
		3. Read only "Psychologist" rows. Exclude "SocialWorker" rows
		4. Exclude rows where AppointedClinician is blank or vacant

Modification History:
Name		Date		Comments
Raji		1/25/2025		Initial Draft
*/
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @ETLProcessedDate date, @ETLProcessedDateTime datetime
	select @ETLProcessedDateTime = getdate()
	select @ETLProcessedDate = cast(@ETLProcessedDateTime as date)

	SELECT * 
	INTO #IEPCONNECTDATA
	FROM DWH_CLUSTERINGWORKSHEET4POSPSYCHDAYS
	WHERE ETLProcessedDateTime = (SELECT MAX(ETLProcessedDateTime) FROM DWH_CLUSTERINGWORKSHEET4POSPSYCHDAYS)

	--Exclude rows where AppointedClinician is missing or is Vacant
	and isnull(AppointedClinician , '') <> '' and AppointedClinician not like 'Vacant%'

	--Include only "Psychologist" rows
	and isnull(CLClusterService, '') = 'Psychologist'

	--BEGIN: Clean up "PSY - L1 Schools", L2 Schools, etc. 

	--(1)Remove any consecutive blank spaces with a single blank space
	--(2)Remove any preceeding or succeeding blank spaces before or after '@' sign in D75 Schools
	--(3)Replacing any non-alphanumeric character other than '@', 'space' and ',' by ',' by calling fn_CleanString function
	--Sample Bad values that get cleaned up are: 11x287/11X370, 75K396@ 23K327, 75K721 @ 21K721, 32k347/32k349,
	--11x287/11X370 is updated to 11x287,11X370
	--75K396@ 23K327 is updated to 75K396@23K327

		--Clean up L1 Schools
			--remove consecutive blank spaces with a single blank space. Since '<>' is used as a clever trick, remove any '<' or '>' with 'space' first. 
			update #IEPCONNECTDATA 
			set PSYL1Schools = replace(replace(replace(TRANSLATE(PSYL1Schools, '<>', '  '), ' ', '<>'), '><', ''), '<>', ''),
				PSYL2Schools = replace(replace(replace(TRANSLATE(PSYL2Schools, '<>', '  '), ' ', '<>'), '><', ''), '<>', ''),
				PSYL3Schools = replace(replace(replace(TRANSLATE(PSYL3Schools, '<>', '  '), ' ', '<>'), '><', ''), '<>', ''),
				PSYL4Schools = replace(replace(replace(TRANSLATE(PSYL4Schools, '<>', '  '), ' ', '<>'), '><', ''), '<>', ''),
				PSYL5Schools = replace(replace(replace(TRANSLATE(PSYL5Schools, '<>', '  '), ' ', '<>'), '><', ''), '<>', ''),
				PSYL6Schools = replace(replace(replace(TRANSLATE(PSYL6Schools, '<>', '  '), ' ', '<>'), '><', ''), '<>', ''),
				PSYL7Schools = replace(replace(replace(TRANSLATE(PSYL7Schools, '<>', '  '), ' ', '<>'), '><', ''), '<>', '') 

			--remove blankspace before and after "@" for D75 sites or sites with a building code 
			update #IEPCONNECTDATA 
			set PSYL1Schools = replace(replace(replace(PSYL1Schools, ' @ ', '@'), ' @', '@'), '@ ', '@'),
				PSYL2Schools = replace(replace(replace(PSYL2Schools, ' @ ', '@'), ' @', '@'), '@ ', '@'),
				PSYL3Schools = replace(replace(replace(PSYL3Schools, ' @ ', '@'), ' @', '@'), '@ ', '@'),
				PSYL4Schools = replace(replace(replace(PSYL4Schools, ' @ ', '@'), ' @', '@'), '@ ', '@'),
				PSYL5Schools = replace(replace(replace(PSYL5Schools, ' @ ', '@'), ' @', '@'), '@ ', '@'),
				PSYL6Schools = replace(replace(replace(PSYL6Schools, ' @ ', '@'), ' @', '@'), '@ ', '@'),
				PSYL7Schools = replace(replace(replace(PSYL7Schools, ' @ ', '@'), ' @', '@'), '@ ', '@')
		
			--replace special characters other than '@', and ',' with ',' by calling fn_CleanString function 
			update #IEPCONNECTDATA 
			set PSYL1Schools = dbo.fn_CleanStringsFromUnwantedCharacters(PSYL1Schools, '[^A-Za-z0-9@,]', ','),
				PSYL2Schools = dbo.fn_CleanStringsFromUnwantedCharacters(PSYL2Schools, '[^A-Za-z0-9@,]', ','),
				PSYL3Schools = dbo.fn_CleanStringsFromUnwantedCharacters(PSYL3Schools, '[^A-Za-z0-9@,]', ','),
				PSYL4Schools = dbo.fn_CleanStringsFromUnwantedCharacters(PSYL4Schools, '[^A-Za-z0-9@,]', ','),
				PSYL5Schools = dbo.fn_CleanStringsFromUnwantedCharacters(PSYL5Schools, '[^A-Za-z0-9@,]', ','),
				PSYL6Schools = dbo.fn_CleanStringsFromUnwantedCharacters(PSYL6Schools, '[^A-Za-z0-9@,]', ','),
				PSYL7Schools = dbo.fn_CleanStringsFromUnwantedCharacters(PSYL7Schools, '[^A-Za-z0-9@,]', ',')
		
	
	--END: Clean up "PSY - L1 Schools", L2 Schools, etc. 

	--If language is "English" but language delivery is blank, then update blank to "Monolingual"
		update #IEPConnectData set CLClusterLanguageDelivery = 'Monolingual' 
		where PSYClusterLanguage = 'English'  or PSYClusterLanguage like 'EN%'
		and isnull(CLClusterLanguageDelivery, '') = ''

	--If language is one of the non-EN lang, but language delivery is blank, then update blank to "Bilingual"
	update #IEPConnectData set CLClusterLanguageDelivery = 'Bilingual' 
	where isnull(PSYClusterLanguage, '') <> '' and PSYClusterLanguage <> 'English' and PSYClusterLanguage not like 'EN%'
	--and PSYClusterLanguage in ('ARABIC', 'Cantonese', 'Chinese', 'Haitian Creole', 'Hindi',
	--		'Korean', 'Mandarin', 'RUSSIAN', 'Spanish',	'Urdu')
	and isnull(CLClusterLanguageDelivery, '') = ''

	--Update "OC" (On Call) days to 0
	update #IEPCONNECTDATA set PSYL1Days = '0' where TRIM(PSYL1Days) = 'OC'
	update #IEPCONNECTDATA set PSYL2Days = '0' where TRIM(PSYL2Days) = 'OC'
	update #IEPCONNECTDATA set PSYL3Days = '0' where TRIM(PSYL3Days) = 'OC'
	update #IEPCONNECTDATA set PSYL4Days = '0' where TRIM(PSYL4Days) = 'OC'
	update #IEPCONNECTDATA set PSYL5Days = '0' where TRIM(PSYL5Days) = 'OC'
	update #IEPCONNECTDATA set PSYL6Days = '0' where TRIM(PSYL6Days) = 'OC'
	update #IEPCONNECTDATA set PSYL7Days = '0' where TRIM(PSYL7Days) = 'OC'

	--Update any non-numeric value in "days" to 0
	update #IEPCONNECTDATA set PSYL1Days = '0' where isnumeric(TRIM(PSYL1Days)) = 0
	update #IEPCONNECTDATA set PSYL2Days = '0' where isnumeric(TRIM(PSYL2Days)) = 0
	update #IEPCONNECTDATA set PSYL3Days = '0' where isnumeric(TRIM(PSYL3Days)) = 0
	update #IEPCONNECTDATA set PSYL4Days = '0' where isnumeric(TRIM(PSYL4Days)) = 0
	update #IEPCONNECTDATA set PSYL5Days = '0' where isnumeric(TRIM(PSYL5Days)) = 0
	update #IEPCONNECTDATA set PSYL6Days = '0' where isnumeric(TRIM(PSYL6Days)) = 0
	update #IEPCONNECTDATA set PSYL7Days = '0' where isnumeric(TRIM(PSYL7Days)) = 0

	INSERT INTO dbo.INT_CLUSTERINGWORKSHEET4POSPSYCHDAYS(
		CLClusterCode
		, CLClusterName
		, CLClusterDistrict
		, AppointedClinician
		, CLClusterService
		, PSYClusterLanguage
		, CLClusterLanguageDelivery
		, PSYL1Schools
		, PSYL1Days
		, PSYL2Schools
		, PSYL2Days
		, PSYL3Schools
		, PSYL3Days
		, PSYL4Schools
		, PSYL4Days
		, PSYL5Schools
		, PSYL5Days
		, PSYL6Schools
		, PSYL6Days
		, PSYL7Schools
		, PSYL7Days
		, ETLProcessedDate
		, ETLProcessedDateTime
	)
	select 
		CLClusterCode
		, CLClusterName
		, CLClusterDistrict
		, AppointedClinician
		, CLClusterService
		, PSYClusterLanguage
		, CLClusterLanguageDelivery
		, PSYL1Schools
		, PSYL1Days
		, PSYL2Schools
		, PSYL2Days
		, PSYL3Schools
		, PSYL3Days
		, PSYL4Schools
		, PSYL4Days
		, PSYL5Schools
		, PSYL5Days
		, PSYL6Schools
		, PSYL6Days
		, PSYL7Schools
		, PSYL7Days
		, ETLProcessedDate
		, ETLProcessedDateTime
	from #IEPCONNECTDATA
END

