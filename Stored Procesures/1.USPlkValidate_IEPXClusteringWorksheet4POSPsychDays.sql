USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPlkValidate_IEPXClusteringWorksheet4POSPsychDays]    Script Date: 4/4/2026 1:28:35 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[USPlkValidate_IEPXClusteringWorksheet4POSPsychDays]
/*=============================================
Sample call: exec dbo.USPRPT_POSPSYCHDAYSDetail
Purpose: This stored procedure is to perform data validation in the IEPX Clustering Worksheet   
                  Staging.lk_IEPXClusteringWorksheet4POSPsychDays. 
		What valiations are performed?
		1. All Elementary and MiddleSchool clusters add to 5 days
		2. Clusters do not have Invalid DBNs				
		3. All 'Chinese' clusters have a language override (either as Chinese(Both), Mandarin, Cantonese, English or something else.
				'Chinese' is too generic. We can't assign to 'Chinese' langugae. We should know whether Chinese represents Cantonese or Mandarin or both.
				In a few rare instances, a 'Chinese' cluster can have a monolingual clinician. In such cases, the override is English.
Modification History:
Name		Date			Comments
Raji		01/25/2025		Initial Draft
Pcissthomas 10/20/2025		Data validation / validation for appointed clinician - chinese is added.
							https://seoanalytics.atlassian.net/browse/MIS-14408
Raji		11/12/2025		Modified to include ClusterName when checking LanguageOverride
---=============================================*/
as
begin
	declare @ETLProcessedDateTime datetime, @ETLProcessedDate date
	select @ETLProcessedDateTime = max(ETLProcessedDateTime), @ETLProcessedDate = max(ETLProcessedDate)
	from Staging.lk_IEPXClusteringWorksheet4POSPsychDays
	 
--BEGIN: Remove leading oupdate Staging.lk_IEPXClusteringWorksheet4POSPsychDays set [CL Cluster Code] = TRIM(isnull([CL Cluster Code], ''))
	update Staging.lk_IEPXClusteringWorksheet4POSPsychDays 
	set [CL Cluster Name] = TRIM(isnull([CL Cluster Name], ''))
		, [CL Cluster District] = TRIM(isnull([CL Cluster District], ''))
		,[Appointed Clinician] = TRIM(isnull([Appointed Clinician], ''))
		,[Cluster Name:CL Cluster Service] = TRIM(isnull([Cluster Name:CL Cluster Service], ''))
		,[PSY - L1 Schools_Cleaned] = TRIM(isnull([PSY - L1 Schools], ''))
		,[PSY - L2 Schools_Cleaned] = TRIM(isnull([PSY - L2 Schools], ''))
		,[PSY - L3 Schools_Cleaned] = TRIM(isnull([PSY - L3 Schools], ''))
		,[PSY - L4 Schools_Cleaned] = TRIM(isnull([PSY - L4 Schools], ''))
		,[PSY - L5 Schools_Cleaned] = TRIM(isnull([PSY - L5 Schools], ''))
		,[PSY - L6 Schools_Cleaned] = TRIM(isnull([PSY - L6 Schools], ''))
		,[PSY - L7 Schools_Cleaned] = TRIM(isnull([PSY - L7 Schools], ''))
		,[PSY - Cluster Language] = TRIM(isnull([PSY - Cluster Language], ''))
		,[Cluster Name:CL Cluster Language Delivery] = TRIM(isnull([Cluster Name:CL Cluster Language Delivery], ''))
	where ETLProcessedDateTime = @ETLProcessedDateTime
--END: Remove leading oupdate Staging.lk_IEPXClusteringWorksheet4POSPsychDays set [CL Cluster Code] = TRIM(isnull([CL Cluster Code], ''))

--BEGIN: Data updates as a result of our initial findings and subsequent follow up from Purvi
	--Make the updates in the file itself, thereby we don't have to make those corrections in the scirpt

	--Two Invalid DBNs resulted in the total days not to add to 5 for two clinicians (Bianca Pelaez and Betty Player) 
	--A third invalid DBN doesn't impact our process bcz it is connected to D75
	--Purvi confirmed the invalidity and asked us to replace those with correct ones: Replace 03M534 with 03M421, 31R373@R074  with 75R373@R074 and 75R37@31R002 with 75R037@31R002
	update Staging.lk_IEPXClusteringWorksheet4POSPsychDays 
	set [PSY - L1 Schools_Cleaned] = replace(replace(replace(isnull([PSY - L1 Schools_Cleaned], ''), '03M534', '03M421'), '31R373@R074', '75R373@R074'), '75R37@31R002', '75R037@31R002')
	where ETLProcessedDateTime = @ETLProcessedDateTime

	update Staging.lk_IEPXClusteringWorksheet4POSPsychDays 
	set [PSY - L2 Schools_Cleaned] = replace(replace(replace(isnull([PSY - L2 Schools_Cleaned], ''), '03M534', '03M421'), '31R373@R074', '75R373@R074'), '75R37@31R002', '75R037@31R002')
	where ETLProcessedDateTime = @ETLProcessedDateTime

	update Staging.lk_IEPXClusteringWorksheet4POSPsychDays 
	set [PSY - L3 Schools_Cleaned] = replace(replace(replace(isnull([PSY - L3 Schools_Cleaned], ''), '03M534', '03M421'), '31R373@R074', '75R373@R074'), '75R37@31R002', '75R037@31R002')
	where ETLProcessedDateTime = @ETLProcessedDateTime

	update Staging.lk_IEPXClusteringWorksheet4POSPsychDays 
	set [PSY - L4 Schools_Cleaned] = replace(replace(replace(isnull([PSY - L4 Schools_Cleaned], ''), '03M534', '03M421'), '31R373@R074', '75R373@R074'), '75R37@31R002', '75R037@31R002')
	where ETLProcessedDateTime = @ETLProcessedDateTime

	update Staging.lk_IEPXClusteringWorksheet4POSPsychDays 
	set [PSY - L5 Schools_Cleaned] = replace(replace(replace(isnull([PSY - L5 Schools_Cleaned], ''), '03M534', '03M421'), '31R373@R074', '75R373@R074'), '75R37@31R002', '75R037@31R002')
	where ETLProcessedDateTime = @ETLProcessedDateTime

	update Staging.lk_IEPXClusteringWorksheet4POSPsychDays 
	set [PSY - L6 Schools_Cleaned] = replace(replace(replace(isnull([PSY - L6 Schools_Cleaned], ''), '03M534', '03M421'), '31R373@R074', '75R373@R074'), '75R37@31R002', '75R037@31R002')
	where ETLProcessedDateTime = @ETLProcessedDateTime

	update Staging.lk_IEPXClusteringWorksheet4POSPsychDays 
	set [PSY - L7 Schools_Cleaned] = replace(replace(replace(isnull([PSY - L7 Schools_Cleaned], ''), '03M534', '03M421'), '31R373@R074', '75R373@R074'), '75R37@31R002', '75R037@31R002')
	where ETLProcessedDateTime = @ETLProcessedDateTime

--END: Data updates as a result of our initial findings and subsequent follow up from Purvi

--BEGIN: Clean up "PSY - L1 Schools", L2 Schools, etc.  
--Sample Bad values that get cleaned up are: 11x287/11X370, 75K396@ 23K327, 75K721 @ 21K721, 32k347/32k349,

	--Clean up L1 Schools
			update Staging.lk_IEPXClusteringWorksheet4POSPsychDays 
			set [PSY - L1 Schools_Cleaned]  =  replace(replace(replace(isnull([PSY - L1 Schools_Cleaned], ''), ' @ ', '@'), ' @', '@'), '@ ', '@')
			where ETLProcessedDateTime = @ETLProcessedDateTime

			--Replace any character other than A-Z, 0-9 or '@', ' ', ',' with a ','
			update Staging.lk_IEPXClusteringWorksheet4POSPsychDays  
			set [PSY - L1 Schools_Cleaned]  = dbo.fn_CleanStringsFromUnwantedCharacters([PSY - L1 Schools_Cleaned], '[^A-Za-z0-9@, ]', ',')
			where isnull([PSY - L1 Schools_Cleaned], '') <> ''
			and ETLProcessedDateTime = @ETLProcessedDateTime

			update Staging.lk_IEPXClusteringWorksheet4POSPsychDays set [PSY - L1 Schools_Cleaned]  =  replace([PSY - L1 Schools_Cleaned], ' ', ',') 
			where isnull([PSY - L1 Schools_Cleaned], '') <> '' and ETLProcessedDateTime = @ETLProcessedDateTime

	--Clean up L2 Schools
			update Staging.lk_IEPXClusteringWorksheet4POSPsychDays 
			set [PSY - L2 Schools_Cleaned]  =  replace(replace(replace(isnull([PSY - L2 Schools_Cleaned], ''), ' @ ', '@'), ' @', '@'), '@ ', '@')
			where ETLProcessedDateTime = @ETLProcessedDateTime

			--Replace any character other than A-Z, 0-9 or '@', ' ', ',' with a ','
			update Staging.lk_IEPXClusteringWorksheet4POSPsychDays  
			set [PSY - L2 Schools_Cleaned]  = dbo.fn_CleanStringsFromUnwantedCharacters([PSY - L2 Schools_Cleaned], '[^A-Za-z0-9@, ]', ',')
			where isnull([PSY - L2 Schools_Cleaned], '') <> ''
			and ETLProcessedDateTime = @ETLProcessedDateTime

			update Staging.lk_IEPXClusteringWorksheet4POSPsychDays set [PSY - L2 Schools_Cleaned]  =  replace([PSY - L2 Schools_Cleaned], ' ', ',') 
			where isnull([PSY - L2 Schools_Cleaned], '') <> '' and ETLProcessedDateTime = @ETLProcessedDateTime
	--Clean up L3 Schools
			update Staging.lk_IEPXClusteringWorksheet4POSPsychDays 
			set [PSY - L3 Schools_Cleaned]  =  replace(replace(replace(isnull([PSY - L3 Schools_Cleaned], ''), ' @ ', '@'), ' @', '@'), '@ ', '@')
			where ETLProcessedDateTime = @ETLProcessedDateTime

			--Replace any character other than A-Z, 0-9 or '@', ' ', ',' with a ','
			update Staging.lk_IEPXClusteringWorksheet4POSPsychDays  
			set [PSY - L3 Schools_Cleaned]  = dbo.fn_CleanStringsFromUnwantedCharacters([PSY - L3 Schools_Cleaned], '[^A-Za-z0-9@, ]', ',')
			where isnull([PSY - L3 Schools_Cleaned], '') <> ''
			and ETLProcessedDateTime = @ETLProcessedDateTime

			update Staging.lk_IEPXClusteringWorksheet4POSPsychDays set [PSY - L3 Schools_Cleaned]  =  replace([PSY - L3 Schools_Cleaned], ' ', ',') 
			where isnull([PSY - L3 Schools_Cleaned], '') <> '' and ETLProcessedDateTime = @ETLProcessedDateTime

	--Clean up L4 Schools
			update Staging.lk_IEPXClusteringWorksheet4POSPsychDays 
			set [PSY - L4 Schools_Cleaned]  =  replace(replace(replace(isnull([PSY - L4 Schools_Cleaned], ''), ' @ ', '@'), ' @', '@'), '@ ', '@')
			where ETLProcessedDateTime = @ETLProcessedDateTime

			--Replace any character other than A-Z, 0-9 or '@', ' ', ',' with a ','
			update Staging.lk_IEPXClusteringWorksheet4POSPsychDays  
			set [PSY - L4 Schools_Cleaned]  = dbo.fn_CleanStringsFromUnwantedCharacters([PSY - L4 Schools_Cleaned], '[^A-Za-z0-9@, ]', ',')
			where isnull([PSY - L4 Schools_Cleaned], '') <> ''
			and ETLProcessedDateTime = @ETLProcessedDateTime

			update Staging.lk_IEPXClusteringWorksheet4POSPsychDays set [PSY - L4 Schools_Cleaned]  =  replace([PSY - L4 Schools_Cleaned], ' ', ',') 
			where isnull([PSY - L4 Schools_Cleaned], '') <> '' and ETLProcessedDateTime = @ETLProcessedDateTime

	--Clean up L5 Schools
			update Staging.lk_IEPXClusteringWorksheet4POSPsychDays 
			set [PSY - L5 Schools_Cleaned]  =  replace(replace(replace(isnull([PSY - L5 Schools_Cleaned], ''), ' @ ', '@'), ' @', '@'), '@ ', '@')
			where ETLProcessedDateTime = @ETLProcessedDateTime

			--Replace any character other than A-Z, 0-9 or '@', ' ', ',' with a ','
			update Staging.lk_IEPXClusteringWorksheet4POSPsychDays  
			set [PSY - L5 Schools_Cleaned]  = dbo.fn_CleanStringsFromUnwantedCharacters([PSY - L5 Schools_Cleaned], '[^A-Za-z0-9@, ]', ',')
			where isnull([PSY - L5 Schools_Cleaned], '') <> ''
			and ETLProcessedDateTime = @ETLProcessedDateTime

			update Staging.lk_IEPXClusteringWorksheet4POSPsychDays set [PSY - L5 Schools_Cleaned]  =  replace([PSY - L5 Schools_Cleaned], ' ', ',') 
			where isnull([PSY - L5 Schools_Cleaned], '') <> '' and ETLProcessedDateTime = @ETLProcessedDateTime

	--Clean up L6 Schools
			update Staging.lk_IEPXClusteringWorksheet4POSPsychDays 
			set [PSY - L6 Schools_Cleaned]  =  replace(replace(replace(isnull([PSY - L6 Schools_Cleaned], ''), ' @ ', '@'), ' @', '@'), '@ ', '@')
			where ETLProcessedDateTime = @ETLProcessedDateTime

			--Replace any character other than A-Z, 0-9 or '@', ' ', ',' with a ','
			update Staging.lk_IEPXClusteringWorksheet4POSPsychDays  
			set [PSY - L6 Schools_Cleaned]  = dbo.fn_CleanStringsFromUnwantedCharacters([PSY - L6 Schools_Cleaned], '[^A-Za-z0-9@, ]', ',')
			where isnull([PSY - L6 Schools_Cleaned], '') <> ''
			and ETLProcessedDateTime = @ETLProcessedDateTime

			update Staging.lk_IEPXClusteringWorksheet4POSPsychDays set [PSY - L6 Schools_Cleaned]  =  replace([PSY - L6 Schools_Cleaned], ' ', ',') 
			where isnull([PSY - L6 Schools_Cleaned], '') <> '' and ETLProcessedDateTime = @ETLProcessedDateTime

	--Clean up L7 Schools
			update Staging.lk_IEPXClusteringWorksheet4POSPsychDays 
			set [PSY - L7 Schools_Cleaned]  =  replace(replace(replace(isnull([PSY - L7 Schools_Cleaned], ''), ' @ ', '@'), ' @', '@'), '@ ', '@')
			where ETLProcessedDateTime = @ETLProcessedDateTime

			--Replace any character other than A-Z, 0-9 or '@', ' ', ',' with a ','
			update Staging.lk_IEPXClusteringWorksheet4POSPsychDays  
			set [PSY - L7 Schools_Cleaned]  = dbo.fn_CleanStringsFromUnwantedCharacters([PSY - L7 Schools_Cleaned], '[^A-Za-z0-9@, ]', ',')
			where isnull([PSY - L7 Schools_Cleaned], '') <> ''
			and ETLProcessedDateTime = @ETLProcessedDateTime

			update Staging.lk_IEPXClusteringWorksheet4POSPsychDays set [PSY - L7 Schools_Cleaned]  =  replace([PSY - L7 Schools_Cleaned], ' ', ',') 
			where isnull([PSY - L7 Schools_Cleaned], '') <> '' and ETLProcessedDateTime = @ETLProcessedDateTime

--END: Clean up "PSY - L1 Schools", L2 Schools, etc. by calling string clean up function


--If language is "English" but language delivery is blank, then update blank to "Monolingual"
update Staging.lk_IEPXClusteringWorksheet4POSPsychDays set [Cluster Name:CL Cluster Language Delivery] = 'Monolingual' 
where [PSY - Cluster Language] = 'English' 
and isnull([Cluster Name:CL Cluster Language Delivery], '') = ''
and ETLProcessedDateTime = @ETLProcessedDateTime

--If language is one of the non-ELL lang, but language delivery is blank, then update blank to "Bilingual"
update Staging.lk_IEPXClusteringWorksheet4POSPsychDays set [Cluster Name:CL Cluster Language Delivery] = 'Bilingual' 
where isnull([PSY - Cluster Language], '') <> ''
and [PSY - Cluster Language] in ('ARABIC', 'Cantonese', 'Chinese', 'Haitian Creole', 'Hindi',
		'Korean', 'Mandarin', 'RUSSIAN', 'Spanish',	'Urdu')
and isnull([Cluster Name:CL Cluster Language Delivery], '') = ''
and ETLProcessedDateTime = @ETLProcessedDateTime

	select * into #IEPConnectRawData 
	from Staging.lk_IEPXClusteringWorksheet4POSPsychDays
	where ETLProcessedDateTime = @ETLProcessedDateTime

--Delete "Social Worker" cluters. We are interested only in "Psychologist" clusters
delete from #IEPConnectRawData where [Cluster Name:CL Cluster Service] = 'Social Worker'

drop table if exists #DataValidationIssues
create table #DataValidationIssues(IssueDescription varchar(1500), IssueContent varchar(1500), IssueCount int)

--Delete rows where AppointedClinician is missing
		insert into #DataValidationIssues(IssueDescription, IssueContent)
		select 'Appointed Clinician missing: Excluded from consideration', 
			isnull([CL Cluster Code], '') + '; Cluster District: ' + isnull([CL Cluster District], '')  +  '; PSY-L1 Schools: ' + isnull([PSY - L1 Schools_Cleaned], '')
		From #IEPConnectRawData 
		where isnull([Appointed Clinician] , '') = ''

		delete
		From #IEPConnectRawData 
		where isnull([Appointed Clinician] , '') = ''

--Delete rows where Cluster District is blank or not one of the accepted values
		insert into #DataValidationIssues(IssueDescription, IssueContent)
		select 'Cluster District is invalid: Excluded from consideration', 
			isnull([CL Cluster Code], '') + '; Cluster District: ' + isnull([CL Cluster District], '')  +  '; PSY-L1 Schools: ' + isnull([PSY - L1 Schools_Cleaned], '')
		from #IEPConnectRawData 
		where [CL Cluster District] = '' OR 
		not
		(
			[CL Cluster District] in ('MHS', 'KHS', 'BAS', 'XHS', 'QHS')
			or 
			([CL Cluster District] like 'D%' and len([CL Cluster District]) = 3 
			and right([CL Cluster District], 2) between '01' and '32') 
		)

		delete i 
		from #IEPConnectRawData i
		where [CL Cluster District] = '' OR 
		not
		(
			[CL Cluster District] in ('MHS', 'KHS', 'BAS', 'XHS', 'QHS')
			or 
			([CL Cluster District] like 'D%' and len([CL Cluster District]) = 3 
			and right([CL Cluster District], 2) between '01' and '32') 
		)

--BEGIN: Language and LanguageDelivery validations		
		insert into #DataValidationIssues(IssueDescription, IssueContent)
		select 'Language is missing', i.[CL Cluster Code] + '  ' + i.[CL Cluster District] + ' ' + i.[Appointed Clinician] 
		from #IEPConnectRawData i
		where isnull([PSY - Cluster Language], '') = '' and isnull([Appointed Clinician], '') <> ''

		delete from #IEPConnectRawData 
		where isnull([PSY - Cluster Language], '') = '' and isnull([Appointed Clinician], '') <> ''

		insert into #DataValidationIssues(IssueDescription, IssueContent)
		select 'Conflicting Language and Delivery', i.[CL Cluster Code] + '  ' + i.[CL Cluster District] + ' ' + i.[Appointed Clinician] + ' ' + [PSY - Cluster Language] + ' - ' + [Cluster Name:CL Cluster Language Delivery] 
		from #IEPConnectRawData i
		where [PSY - Cluster Language] = 'English' and isnull([Cluster Name:CL Cluster Language Delivery], '') <> 'Monolingual'
		union all 
		select 'Conflicting Language and Delivery', i.[CL Cluster Code] + '  ' + i.[CL Cluster District] + ' ' + i.[Appointed Clinician] + ' ' + [PSY - Cluster Language] + ' - ' + [Cluster Name:CL Cluster Language Delivery]  
		from #IEPConnectRawData i
		where isnull([PSY - Cluster Language], '') in  ('ARABIC', 'Cantonese', 'Chinese', 'Haitian Creole', 'Hindi',
		'Korean', 'Mandarin', 'RUSSIAN', 'Spanish',	'Urdu') 
		and isnull([Cluster Name:CL Cluster Language Delivery], '') <> 'Bilingual'

		--Delete rows with conflicting language and languageDelivery values
		delete i 
		from #IEPConnectRawData i
		where [PSY - Cluster Language] = 'English' and isnull([Cluster Name:CL Cluster Language Delivery], '') <> 'Monolingual'
		
		delete i 
		from #IEPConnectRawData i
		where isnull([PSY - Cluster Language], '') in  ('ARABIC', 'Cantonese', 'Chinese', 'Haitian Creole', 'Hindi',
		'Korean', 'Mandarin', 'RUSSIAN', 'Spanish',	'Urdu') 
		and isnull([Cluster Name:CL Cluster Language Delivery], '') <> 'Bilingual'

		--select * from #IEPConnectRawData where isnull([PSY - Cluster Language], '') = '' and isnull([Cluster Name:CL Cluster Language Delivery], '') = 'Bilingual'
		--select [PSY - Cluster Language], count(*) from #IEPConnectRawData where isnull([Cluster Name:CL Cluster Language Delivery], '') = 'Bilingual' group by [PSY - Cluster Language]
	--END: Language and LanguageDelivery validations


--Identify locations that are not valid per RPT_Locations. Check with business if they are valid
--A valid reason is new schools begin opened for upcoming school year 
--Do this validation only for "D" clusters
insert into #DataValidationIssues(IssueDescription, IssueContent)
select 'Invalid DBN codes per LCGMS', isnull(Cluster, '') + '  ' + SchoolDBNSource + '  ' + isnull(SchoolDBN, '') 
from (
		select i.[CL Cluster Code] + '  ' + i.[CL Cluster Name] + '  ' + i.[CL Cluster District] + ' ' + i.[Appointed Clinician] as Cluster, TRIM(pl1.value) as SchoolDBN, 'PSY - L1' as 'SchoolDBNSource' 
		from #IEPConnectRawData i
			cross apply string_split(i.[PSY - L1 Schools_Cleaned], ',') pl1
		where TRIM(iif(i.[PSY - L1 Days] is null, '', i.[PSY - L1 Days])) <> ''
		and ISNUMERIC(i.[PSY - L1 Days]) = 1 
		and trim(pl1.value) <> ''
		and left(trim(pl1.value), 6) not in (select SchoolDBN from RPT_Locations)
		and [CL Cluster District] like 'D%'
		union all
		select i.[CL Cluster Code] + '  ' + i.[CL Cluster Name] + '  ' + i.[CL Cluster District] + ' ' + i.[Appointed Clinician] as Cluster, TRIM(pl1.value) as SchoolDBN, 'PSY - L2' as 'SchoolDBNSource' from #IEPConnectRawData i
			cross apply string_split(i.[PSY - L2 Schools_Cleaned], ',') pl1
		where TRIM(iif(i.[PSY - L2 Days] is null, '', i.[PSY - L2 Days])) <> ''
		and ISNUMERIC(i.[PSY - L2 Days]) = 1 
		and trim(pl1.value) <> ''
		and left(trim(pl1.value), 6) not in (select SchoolDBN from RPT_Locations)
		and [CL Cluster District] like 'D%'
		union all
		select i.[CL Cluster Code] + '  ' + i.[CL Cluster Name] + '  ' + i.[CL Cluster District] + ' ' + i.[Appointed Clinician] as Cluster, TRIM(pl1.value) as SchoolDBN, 'PSY - L3' as 'SchoolDBNSource' from #IEPConnectRawData i
			cross apply string_split(i.[PSY - L3 Schools_Cleaned], ',') pl1
		where TRIM(iif(i.[PSY - L3 Days] is null, '', i.[PSY - L3 Days])) <> ''
		and ISNUMERIC(i.[PSY - L3 Days]) = 1 
		and trim(pl1.value) <> ''
		and left(trim(pl1.value), 6) not in (select SchoolDBN from RPT_Locations)
		and [CL Cluster District] like 'D%'
		union all
		select i.[CL Cluster Code] + '  ' + i.[CL Cluster Name] + '  ' + i.[CL Cluster District] + ' ' + i.[Appointed Clinician] as Cluster, TRIM(pl1.value) as SchoolDBN, 'PSY - L4' as 'SchoolDBNSource' from #IEPConnectRawData i
			cross apply string_split(i.[PSY - L4 Schools_Cleaned], ',') pl1
		where TRIM(iif(i.[PSY - L4 Days] is null, '', i.[PSY - L4 Days])) <> ''
		and ISNUMERIC(i.[PSY - L4 Days]) = 1 
		and trim(pl1.value) <> ''
		and left(trim(pl1.value), 6) not in (select SchoolDBN from RPT_Locations)
		and [CL Cluster District] like 'D%'
		union all
		select i.[CL Cluster Code] + '  ' + i.[CL Cluster Name] + '  ' + i.[CL Cluster District] + ' ' + i.[Appointed Clinician] as Cluster, TRIM(pl1.value) as SchoolDBN, 'PSY - L5' as 'SchoolDBNSource' from #IEPConnectRawData i
			cross apply string_split(i.[PSY - L5 Schools_Cleaned], ',') pl1
		where TRIM(iif(i.[PSY - L5 Days] is null, '', i.[PSY - L5 Days])) <> ''
		and ISNUMERIC(i.[PSY - L5 Days]) = 1 
		and trim(pl1.value) <> ''
		and left(trim(pl1.value), 6) not in (select SchoolDBN from RPT_Locations)
		and [CL Cluster District] like 'D%'
		union all
		select i.[CL Cluster Code] + '  ' + i.[CL Cluster Name] + '  ' + i.[CL Cluster District] + ' ' + i.[Appointed Clinician] as Cluster, TRIM(pl1.value) as SchoolDBN, 'PSY - L6' as 'SchoolDBNSource' from #IEPConnectRawData i
			cross apply string_split(i.[PSY - L6 Schools_Cleaned], ',') pl1
		where TRIM(iif(i.[PSY - L6 Days] is null, '', i.[PSY - L6 Days])) <> ''
		and ISNUMERIC(i.[PSY - L6 Days]) = 1 
		and trim(pl1.value) <> ''
		and left(trim(pl1.value), 6) not in (select SchoolDBN from RPT_Locations)
		and [CL Cluster District] like 'D%'
		union all
		select i.[CL Cluster Code] + '  ' + i.[CL Cluster Name] + '  ' + i.[CL Cluster District] + ' ' + i.[Appointed Clinician] as Cluster, TRIM(pl1.value) as SchoolDBN, 'PSY - L7' as 'SchoolDBNSource' from #IEPConnectRawData i
			cross apply string_split(i.[PSY - L7 Schools_Cleaned], ',') pl1
		where TRIM(iif(i.[PSY - L7 Days] is null, '', i.[PSY - L7 Days])) <> ''
		and ISNUMERIC(i.[PSY - L7 Days]) = 1 
		and trim(pl1.value) <> ''
		and left(trim(pl1.value), 6) not in (select SchoolDBN from RPT_Locations)
		and [CL Cluster District] like 'D%'
) A 

--------***********BEGIN: Data Checks/Exploration and Validations********--------------
	--BEGIN: Cluster District
		--select 'Explore Cluster District column', [CL Cluster District], count(*) From #IEPConnectRawData 
		--group by [CL Cluster District] 
		--order by 2

	--END: Cluster District 

	--BEGIN: Appointed Clinician
		--select 'Explore Appointed Clinician column', [Appointed Clinician], count(*) From #IEPConnectRawData 
		--group by [Appointed Clinician] 
		--order by 2

		insert into #DataValidationIssues(IssueDescription, IssueContent, IssueCount)
		select 'Appointed Clinician''s is suspecious (too short - < 5 characters)', [Appointed Clinician], count(*) From #IEPConnectRawData 
		where isnull([Appointed Clinician] , '') <> ''
		and len([Appointed Clinician]) < 5
		group by [Appointed Clinician] 

		--Identity clinicians who are part of more than one cluster (means, have more than one row)
		insert into #DataValidationIssues(IssueDescription, IssueContent, IssueCount)
		select 'FYI - >1 clusters with same clinician name', [Appointed Clinician], count(*) from #IEPConnectRawData 
		where isnull([Appointed Clinician] , '') <> ''
		group by [Appointed Clinician] having count(*) > 2 and count(distinct [CL Cluster Name]) = 1

		--insert into #DataValidationIssues(IssueDescription, IssueContent, IssueCount)
		--select 'Appointed Clinician has multiple rows', [Appointed Clinician], count(*) From #IEPConnectRawData 
		--where isnull([Appointed Clinician] , '') <> ''
		--group by [Appointed Clinician] 
		--having count(*) > 1
	--END: Appointed Clinician

	--BEGIN: [PSY - L1 Schools_Cleaned], L2 Schools, etc.
		insert into #DataValidationIssues(IssueDescription, IssueContent)
		select 'Cluster is missing School DBNs', [CL Cluster Code] + ' ' + [CL Cluster District] + ' ' +  [Appointed Clinician] 
		From #IEPConnectRawData 
		where isnull([PSY - L1 Schools_Cleaned], '') = ''
		and  isnull([PSY - L2 Schools_Cleaned], '') = '' 
		and  isnull([PSY - L3 Schools_Cleaned], '') = '' 
		and  isnull([PSY - L4 Schools_Cleaned], '') = '' 
		and  isnull([PSY - L5 Schools_Cleaned], '') = '' 
		and  isnull([PSY - L6 Schools_Cleaned], '') = '' 
		and  isnull([PSY - L7 Schools_Cleaned], '') = '' 

		drop table if exists #PSYSchools
		create table #PSYSchools(
		[CL Cluster Code] varchar(10),
		[CL Cluster Name] varchar(200),
		[CL Cluster District] varchar(10),
		[Appointed Clinician] varchar(100),
		SchoolDBN varchar(15),
		NumberOfDaysInDBNOriginal numeric(10,2),
		SchoolDBNSource varchar(8),
		NumberOfDaysInDBNAdjusted numeric(10,2),
		NumberOfDaysInClusterPL numeric(10,2),
		NumberOfSchoolsInClusterPL int,
		[PSY - Cluster Language] varchar(50),
		[Cluster Name:CL Cluster Language Delivery] varchar(30),
		Notes varchar(100)
		)

		;with cte as (
			select f.[CL Cluster District], [Appointed Clinician], TRIM(r.value) as SchoolDBN,
				'PSY - L1' as SchoolDBNSource 
			from #IEPConnectRawData f
				cross apply string_split(f.[PSY - L1 Schools_Cleaned], ',') r
		) 
		insert into #PSYSchools(
			[CL Cluster Code],
			[CL Cluster Name],	
			[CL Cluster District],
			[Appointed Clinician],
			SchoolDBN,
			SchoolDBNSource,
			NumberOfDaysInDBNOriginal,
			NumberOfDaysInClusterPL,
			NumberOfSchoolsInClusterPL,
			[PSY - Cluster Language],
			[Cluster Name:CL Cluster Language Delivery]
		)
		select 
			f.[CL Cluster Code],
			f.[CL Cluster Name],	
			c.[CL Cluster District], c.[Appointed Clinician], c.SchoolDBN, c.SchoolDBNSource,
			case when TRIM(f.[PSY - L1 Days]) = 'OC' or f.[PSY - L1 Days] is null or 
				isnumeric(f.[PSY - L1 Days]) = 0 then 0
				when isnull(d75.NumOfSchools, 0) = 0 and isnull(d1to32.NumOfSchools, 0) > 0 
					then (cast(f.[PSY - L1 Days] as int) * 1.0)/d1to32.NumOfSchools
				when isnull(d75.NumOfSchools, 0) > 0 and isnull(d1to32.NumOfSchools, 0) = 0 
					then (cast(f.[PSY - L1 Days] as int) * 1.0)/d75.NumOfSchools
				when isnull(d75.NumOfSchools, 0) > 0 and isnull(d1to32.NumOfSchools, 0) > 0 then 
					case when (cast(f.[PSY - L1 Days] as int) >= 4) then 
						case when c.SchoolDBN like '75%' then 
								(1.0/d75.NumOfSchools)
							when c.SchoolDBN not like '75%' then 
								((cast(f.[PSY - L1 Days] as int) - 1.0) * 1.0)/d1to32.NumOfSchools
							end
					else
						case when c.SchoolDBN like '75%' then 
								(0.5/d75.NumOfSchools)
							when c.SchoolDBN not like '75%' then 
								((cast(f.[PSY - L1 Days] as int) - 0.5) * 1.0)/d1to32.NumOfSchools
							end
					end
			end as NumberOfDaysInDBNOriginal,
			case when TRIM(f.[PSY - L1 Days]) = 'OC' or f.[PSY - L1 Days] is null or 
				isnumeric(f.[PSY - L1 Days]) = 0 then 0
				else cast(f.[PSY - L1 Days] as numeric(10,2)) 
			end as NumberOfDaysInClusterPL,
			isnull(d75.NumOfSchools, 0) + isnull(d1to32.NumOfSchools, 0) as NumberOfSchoolsInClusterPL,
			f.[PSY - Cluster Language],
			f.[Cluster Name:CL Cluster Language Delivery]
		from #IEPConnectRawData f 
			inner join cte c 
				on f.[CL Cluster District] = c.[CL Cluster District]
				and f.[Appointed Clinician] = c.[Appointed Clinician]
			left join (
				select [CL Cluster District], [Appointed Clinician], count(*) as NumOfSchools
				from cte 
				where isnull(SchoolDBN, '') <> ''
				--Count only valid locations (LEFT(6) function is used to handle D75 SchoolDBNs which has format of 75XXXX@DDYYYY)
				and left(SchoolDBN, 6) in (select SchoolDBN from RPT_Locations)
				and SchoolDBN not like '75%' 
				group by [CL Cluster District], [Appointed Clinician]	
			) d1to32
				on f.[CL Cluster District] = d1to32.[CL Cluster District]
				and f.[Appointed Clinician] = d1to32.[Appointed Clinician]
			left join (
				select [CL Cluster District], [Appointed Clinician], count(*) as NumOfSchools 
				from cte 
				where isnull(SchoolDBN, '') <> ''
				--Count only valid locations (LEFT(6) function is used to handle D75 SchoolDBNs which has format of 75XXXX@DDYYYY)
				and left(SchoolDBN, 6) in (select SchoolDBN from RPT_Locations)
				and SchoolDBN like '75%' 
				group by [CL Cluster District], [Appointed Clinician]	
			) d75
				on f.[CL Cluster District] = d75.[CL Cluster District]
				and f.[Appointed Clinician] = d75.[Appointed Clinician]
		where isnull(c.SchoolDBN, '') <> '' and left(c.SchoolDBN, 6) in (select SchoolDBN from RPT_Locations)
		--and f.[Appointed Clinician] = 'Alexandra Griffin'

		--select * From #PSYSchools order by [Appointed Clinician]

		;with cte as (
			select f.[CL Cluster District], [Appointed Clinician], TRIM(r.value) as SchoolDBN,
				'PSY - L2' as SchoolDBNSource 
			from #IEPConnectRawData f
				cross apply string_split(f.[PSY - L2 Schools_Cleaned], ',') r
		) 
		insert into #PSYSchools(
			[CL Cluster Code],
			[CL Cluster Name],	
			[CL Cluster District],
			[Appointed Clinician],
			SchoolDBN,
			SchoolDBNSource,
			NumberOfDaysInDBNOriginal,
			NumberOfDaysInClusterPL,
			NumberOfSchoolsInClusterPL,
			[PSY - Cluster Language],
			[Cluster Name:CL Cluster Language Delivery]
		)
		select 
			f.[CL Cluster Code],
			f.[CL Cluster Name],	
			c.[CL Cluster District], c.[Appointed Clinician], c.SchoolDBN, c.SchoolDBNSource,
			case when TRIM(f.[PSY - L2 Days]) = 'OC' or f.[PSY - L2 Days] is null or 
				isnumeric(f.[PSY - L2 Days]) = 0 then 0
				when isnull(d75.NumOfSchools, 0) = 0 and isnull(d1to32.NumOfSchools, 0) > 0 
					then (cast(f.[PSY - L2 Days] as int) * 1.0)/d1to32.NumOfSchools
				when isnull(d75.NumOfSchools, 0) > 0 and isnull(d1to32.NumOfSchools, 0) = 0 
					then (cast(f.[PSY - L2 Days] as int) * 1.0)/d75.NumOfSchools
				when isnull(d75.NumOfSchools, 0) > 0 and isnull(d1to32.NumOfSchools, 0) > 0 then 
					case when (cast(f.[PSY - L2 Days] as int) >= 4) then 
						case when c.SchoolDBN like '75%' then 
								(1.0/d75.NumOfSchools)
							when c.SchoolDBN not like '75%' then 
								((cast(f.[PSY - L2 Days] as int) - 1.0) * 1.0)/d1to32.NumOfSchools
							end
					else
						case when c.SchoolDBN like '75%' then 
								(0.5/d75.NumOfSchools)
							when c.SchoolDBN not like '75%' then 
								((cast(f.[PSY - L2 Days] as int) - 0.5) * 1.0)/d1to32.NumOfSchools
							end
					end
			end as NumberOfDaysInDBNOriginal,
			case when TRIM(f.[PSY - L2 Days]) = 'OC' or f.[PSY - L2 Days] is null or 
				isnumeric(f.[PSY - L2 Days]) = 0 then 0
				else cast(f.[PSY - L2 Days] as numeric(10,2)) 
			end as NumberOfDaysInClusterPL,
			isnull(d75.NumOfSchools, 0) + isnull(d1to32.NumOfSchools, 0) as NumberOfSchoolsInClusterPL,
			f.[PSY - Cluster Language],
			f.[Cluster Name:CL Cluster Language Delivery]
		from #IEPConnectRawData f 
			inner join cte c 
				on f.[CL Cluster District] = c.[CL Cluster District]
				and f.[Appointed Clinician] = c.[Appointed Clinician]
			left join (
				select [CL Cluster District], [Appointed Clinician], count(*) as NumOfSchools
				from cte 
				where isnull(SchoolDBN, '') <> ''
				--Count only valid locations (LEFT(6) function is used to handle D75 SchoolDBNs which has format of 75XXXX@DDYYYY)
				and left(SchoolDBN, 6) in (select SchoolDBN from RPT_Locations)
				and SchoolDBN not like '75%' 
				group by [CL Cluster District], [Appointed Clinician]	
			) d1to32
				on f.[CL Cluster District] = d1to32.[CL Cluster District]
				and f.[Appointed Clinician] = d1to32.[Appointed Clinician]
			left join (
				select [CL Cluster District], [Appointed Clinician], count(*) as NumOfSchools 
				from cte 
				where isnull(SchoolDBN, '') <> ''
				--Count only valid locations (LEFT(6) function is used to handle D75 SchoolDBNs which has format of 75XXXX@DDYYYY)
				and left(SchoolDBN, 6) in (select SchoolDBN from RPT_Locations)
				and SchoolDBN like '75%' 
				group by [CL Cluster District], [Appointed Clinician]	
			) d75
				on f.[CL Cluster District] = d75.[CL Cluster District]
				and f.[Appointed Clinician] = d75.[Appointed Clinician]
		where isnull(c.SchoolDBN, '') <> '' and left(c.SchoolDBN, 6) in (select SchoolDBN from RPT_Locations)
		--and f.[Appointed Clinician] = 'Alexandra Griffin'

		;with cte as (
			select f.[CL Cluster District], [Appointed Clinician], TRIM(r.value) as SchoolDBN,
				'PSY - L3' as SchoolDBNSource 
			from #IEPConnectRawData f
				cross apply string_split(f.[PSY - L3 Schools_Cleaned], ',') r
		) 
		insert into #PSYSchools(
			[CL Cluster Code],
			[CL Cluster Name],	
			[CL Cluster District],
			[Appointed Clinician],
			SchoolDBN,
			SchoolDBNSource,
			NumberOfDaysInDBNOriginal,
			NumberOfDaysInClusterPL,
			NumberOfSchoolsInClusterPL,
			[PSY - Cluster Language],
			[Cluster Name:CL Cluster Language Delivery]
		)
		select 
			f.[CL Cluster Code],
			f.[CL Cluster Name],	
			c.[CL Cluster District], c.[Appointed Clinician], c.SchoolDBN, c.SchoolDBNSource,
			case when TRIM(f.[PSY - L3 Days]) = 'OC' or f.[PSY - L3 Days] is null or 
				isnumeric(f.[PSY - L3 Days]) = 0 then 0
				when isnull(d75.NumOfSchools, 0) = 0 and isnull(d1to32.NumOfSchools, 0) > 0 
					then (cast(f.[PSY - L3 Days] as int) * 1.0)/d1to32.NumOfSchools
				when isnull(d75.NumOfSchools, 0) > 0 and isnull(d1to32.NumOfSchools, 0) = 0 
					then (cast(f.[PSY - L3 Days] as int) * 1.0)/d75.NumOfSchools
				when isnull(d75.NumOfSchools, 0) > 0 and isnull(d1to32.NumOfSchools, 0) > 0 then 
					case when (cast(f.[PSY - L3 Days] as int) >= 4) then 
						case when c.SchoolDBN like '75%' then 
								(1.0/d75.NumOfSchools)
							when c.SchoolDBN not like '75%' then 
								((cast(f.[PSY - L3 Days] as int) - 1.0) * 1.0)/d1to32.NumOfSchools
							end
					else
						case when c.SchoolDBN like '75%' then 
								(0.5/d75.NumOfSchools)
							when c.SchoolDBN not like '75%' then 
								((cast(f.[PSY - L3 Days] as int) - 0.5) * 1.0)/d1to32.NumOfSchools
							end
					end
			end as NumberOfDaysInDBNOriginal,
			case when TRIM(f.[PSY - L3 Days]) = 'OC' or f.[PSY - L3 Days] is null or 
				isnumeric(f.[PSY - L3 Days]) = 0 then 0
				else cast(f.[PSY - L3 Days] as numeric(10,2)) 
			end as NumberOfDaysInClusterPL,
			isnull(d75.NumOfSchools, 0) + isnull(d1to32.NumOfSchools, 0) as NumberOfSchoolsInClusterPL,
			f.[PSY - Cluster Language],
			f.[Cluster Name:CL Cluster Language Delivery]
		from #IEPConnectRawData f 
			inner join cte c 
				on f.[CL Cluster District] = c.[CL Cluster District]
				and f.[Appointed Clinician] = c.[Appointed Clinician]
			left join (
				select [CL Cluster District], [Appointed Clinician], count(*) as NumOfSchools
				from cte 
				where isnull(SchoolDBN, '') <> ''
				--Count only valid locations (LEFT(6) function is used to handle D75 SchoolDBNs which has format of 75XXXX@DDYYYY)
				and left(SchoolDBN, 6) in (select SchoolDBN from RPT_Locations)
				and SchoolDBN not like '75%' 
				group by [CL Cluster District], [Appointed Clinician]	
			) d1to32
				on f.[CL Cluster District] = d1to32.[CL Cluster District]
				and f.[Appointed Clinician] = d1to32.[Appointed Clinician]
			left join (
				select [CL Cluster District], [Appointed Clinician], count(*) as NumOfSchools 
				from cte 
				where isnull(SchoolDBN, '') <> ''
				--Count only valid locations (LEFT(6) function is used to handle D75 SchoolDBNs which has format of 75XXXX@DDYYYY)
				and left(SchoolDBN, 6) in (select SchoolDBN from RPT_Locations)
				and SchoolDBN like '75%' 
				group by [CL Cluster District], [Appointed Clinician]	
			) d75
				on f.[CL Cluster District] = d75.[CL Cluster District]
				and f.[Appointed Clinician] = d75.[Appointed Clinician]
		where isnull(c.SchoolDBN, '') <> '' and left(c.SchoolDBN, 6) in (select SchoolDBN from RPT_Locations)
		--and f.[Appointed Clinician] = 'Alexandra Griffin'
 
		;with cte as (
			select f.[CL Cluster District], [Appointed Clinician], TRIM(r.value) as SchoolDBN,
				'PSY - L4' as SchoolDBNSource 
			from #IEPConnectRawData f
				cross apply string_split(f.[PSY - L4 Schools_Cleaned], ',') r
		) 
		insert into #PSYSchools(
			[CL Cluster Code],
			[CL Cluster Name],	
			[CL Cluster District],
			[Appointed Clinician],
			SchoolDBN,
			SchoolDBNSource,
			NumberOfDaysInDBNOriginal,
			NumberOfDaysInClusterPL,
			NumberOfSchoolsInClusterPL,
			[PSY - Cluster Language],
			[Cluster Name:CL Cluster Language Delivery]
		)
		select 
			f.[CL Cluster Code],
			f.[CL Cluster Name],	
			c.[CL Cluster District], c.[Appointed Clinician], c.SchoolDBN, c.SchoolDBNSource,
			case when TRIM(f.[PSY - L4 Days]) = 'OC' or f.[PSY - L4 Days] is null or 
				isnumeric(f.[PSY - L4 Days]) = 0 then 0
				when isnull(d75.NumOfSchools, 0) = 0 and isnull(d1to32.NumOfSchools, 0) > 0 
					then (cast(f.[PSY - L4 Days] as int) * 1.0)/d1to32.NumOfSchools
				when isnull(d75.NumOfSchools, 0) > 0 and isnull(d1to32.NumOfSchools, 0) = 0 
					then (cast(f.[PSY - L4 Days] as int) * 1.0)/d75.NumOfSchools
				when isnull(d75.NumOfSchools, 0) > 0 and isnull(d1to32.NumOfSchools, 0) > 0 then 
					case when (cast(f.[PSY - L4 Days] as int) >= 4) then 
						case when c.SchoolDBN like '75%' then 
								(1.0/d75.NumOfSchools)
							when c.SchoolDBN not like '75%' then 
								((cast(f.[PSY - L4 Days] as int) - 1.0) * 1.0)/d1to32.NumOfSchools
							end
					else
						case when c.SchoolDBN like '75%' then 
								(0.5/d75.NumOfSchools)
							when c.SchoolDBN not like '75%' then 
								((cast(f.[PSY - L4 Days] as int) - 0.5) * 1.0)/d1to32.NumOfSchools
							end
					end
			end as NumberOfDaysInDBNOriginal,
			case when TRIM(f.[PSY - L4 Days]) = 'OC' or f.[PSY - L4 Days] is null or 
				isnumeric(f.[PSY - L4 Days]) = 0 then 0
				else cast(f.[PSY - L4 Days] as numeric(10,2)) 
			end as NumberOfDaysInClusterPL,
			isnull(d75.NumOfSchools, 0) + isnull(d1to32.NumOfSchools, 0) as NumberOfSchoolsInClusterPL,
			f.[PSY - Cluster Language],
			f.[Cluster Name:CL Cluster Language Delivery]
		from #IEPConnectRawData f 
			inner join cte c 
				on f.[CL Cluster District] = c.[CL Cluster District]
				and f.[Appointed Clinician] = c.[Appointed Clinician]
			left join (
				select [CL Cluster District], [Appointed Clinician], count(*) as NumOfSchools
				from cte 
				where isnull(SchoolDBN, '') <> ''
				--Count only valid locations (LEFT(6) function is used to handle D75 SchoolDBNs which has format of 75XXXX@DDYYYY)
				and left(SchoolDBN, 6) in (select SchoolDBN from RPT_Locations)
				and SchoolDBN not like '75%' 
				group by [CL Cluster District], [Appointed Clinician]	
			) d1to32
				on f.[CL Cluster District] = d1to32.[CL Cluster District]
				and f.[Appointed Clinician] = d1to32.[Appointed Clinician]
			left join (
				select [CL Cluster District], [Appointed Clinician], count(*) as NumOfSchools 
				from cte 
				where isnull(SchoolDBN, '') <> ''
				--Count only valid locations (LEFT(6) function is used to handle D75 SchoolDBNs which has format of 75XXXX@DDYYYY)
				and left(SchoolDBN, 6) in (select SchoolDBN from RPT_Locations)
				and SchoolDBN like '75%' 
				group by [CL Cluster District], [Appointed Clinician]	
			) d75
				on f.[CL Cluster District] = d75.[CL Cluster District]
				and f.[Appointed Clinician] = d75.[Appointed Clinician]
		where isnull(c.SchoolDBN, '') <> '' and left(c.SchoolDBN, 6) in (select SchoolDBN from RPT_Locations)
		--and f.[Appointed Clinician] = 'Alexandra Griffin'

		;with cte as (
			select f.[CL Cluster District], [Appointed Clinician], TRIM(r.value) as SchoolDBN,
				'PSY - L5' as SchoolDBNSource 
			from #IEPConnectRawData f
				cross apply string_split(f.[PSY - L5 Schools_Cleaned], ',') r
		) 
		insert into #PSYSchools(
			[CL Cluster Code],
			[CL Cluster Name],	
			[CL Cluster District],
			[Appointed Clinician],
			SchoolDBN,
			SchoolDBNSource,
			NumberOfDaysInDBNOriginal,
			NumberOfDaysInClusterPL,
			NumberOfSchoolsInClusterPL,
			[PSY - Cluster Language],
			[Cluster Name:CL Cluster Language Delivery]
		)
		select 
			f.[CL Cluster Code],
			f.[CL Cluster Name],	
			c.[CL Cluster District], c.[Appointed Clinician], c.SchoolDBN, c.SchoolDBNSource,
			case when TRIM(f.[PSY - L5 Days]) = 'OC' or f.[PSY - L5 Days] is null or 
				isnumeric(f.[PSY - L5 Days]) = 0 then 0
				when isnull(d75.NumOfSchools, 0) = 0 and isnull(d1to32.NumOfSchools, 0) > 0 
					then (cast(f.[PSY - L5 Days] as int) * 1.0)/d1to32.NumOfSchools
				when isnull(d75.NumOfSchools, 0) > 0 and isnull(d1to32.NumOfSchools, 0) = 0 
					then (cast(f.[PSY - L5 Days] as int) * 1.0)/d75.NumOfSchools
				when isnull(d75.NumOfSchools, 0) > 0 and isnull(d1to32.NumOfSchools, 0) > 0 then 
					case when (cast(f.[PSY - L5 Days] as int) >= 4) then 
						case when c.SchoolDBN like '75%' then 
								(1.0/d75.NumOfSchools)
							when c.SchoolDBN not like '75%' then 
								((cast(f.[PSY - L5 Days] as int) - 1.0) * 1.0)/d1to32.NumOfSchools
							end
					else
						case when c.SchoolDBN like '75%' then 
								(0.5/d75.NumOfSchools)
							when c.SchoolDBN not like '75%' then 
								((cast(f.[PSY - L5 Days] as int) - 0.5) * 1.0)/d1to32.NumOfSchools
							end
					end
			end as NumberOfDaysInDBNOriginal,
			case when TRIM(f.[PSY - L5 Days]) = 'OC' or f.[PSY - L5 Days] is null or 
				isnumeric(f.[PSY - L5 Days]) = 0 then 0
				else cast(f.[PSY - L5 Days] as numeric(10,2)) 
			end as NumberOfDaysInClusterPL,
			isnull(d75.NumOfSchools, 0) + isnull(d1to32.NumOfSchools, 0) as NumberOfSchoolsInClusterPL,
			f.[PSY - Cluster Language],
			f.[Cluster Name:CL Cluster Language Delivery]
		from #IEPConnectRawData f 
			inner join cte c 
				on f.[CL Cluster District] = c.[CL Cluster District]
				and f.[Appointed Clinician] = c.[Appointed Clinician]
			left join (
				select [CL Cluster District], [Appointed Clinician], count(*) as NumOfSchools
				from cte 
				where isnull(SchoolDBN, '') <> ''
				--Count only valid locations (LEFT(6) function is used to handle D75 SchoolDBNs which has format of 75XXXX@DDYYYY)
				and left(SchoolDBN, 6) in (select SchoolDBN from RPT_Locations)
				and SchoolDBN not like '75%' 
				group by [CL Cluster District], [Appointed Clinician]	
			) d1to32
				on f.[CL Cluster District] = d1to32.[CL Cluster District]
				and f.[Appointed Clinician] = d1to32.[Appointed Clinician]
			left join (
				select [CL Cluster District], [Appointed Clinician], count(*) as NumOfSchools 
				from cte 
				where isnull(SchoolDBN, '') <> ''
				--Count only valid locations (LEFT(6) function is used to handle D75 SchoolDBNs which has format of 75XXXX@DDYYYY)
				and left(SchoolDBN, 6) in (select SchoolDBN from RPT_Locations)
				and SchoolDBN like '75%' 
				group by [CL Cluster District], [Appointed Clinician]	
			) d75
				on f.[CL Cluster District] = d75.[CL Cluster District]
				and f.[Appointed Clinician] = d75.[Appointed Clinician]
		where isnull(c.SchoolDBN, '') <> '' and left(c.SchoolDBN, 6) in (select SchoolDBN from RPT_Locations)
		--and f.[Appointed Clinician] = 'Alexandra Griffin'

		;with cte as (
			select f.[CL Cluster District], [Appointed Clinician], TRIM(r.value) as SchoolDBN,
				'PSY - L6' as SchoolDBNSource 
			from #IEPConnectRawData f
				cross apply string_split(f.[PSY - L6 Schools_Cleaned], ',') r
		) 
		insert into #PSYSchools(
			[CL Cluster Code],
			[CL Cluster Name],	
			[CL Cluster District],
			[Appointed Clinician],
			SchoolDBN,
			SchoolDBNSource,
			NumberOfDaysInDBNOriginal,
			NumberOfDaysInClusterPL,
			NumberOfSchoolsInClusterPL,
			[PSY - Cluster Language],
			[Cluster Name:CL Cluster Language Delivery]
		)
		select 
			f.[CL Cluster Code],
			f.[CL Cluster Name],	
			c.[CL Cluster District], c.[Appointed Clinician], c.SchoolDBN, c.SchoolDBNSource,
			case when TRIM(f.[PSY - L6 Days]) = 'OC' or f.[PSY - L6 Days] is null or 
				isnumeric(f.[PSY - L6 Days]) = 0 then 0
				when isnull(d75.NumOfSchools, 0) = 0 and isnull(d1to32.NumOfSchools, 0) > 0 
					then (cast(f.[PSY - L6 Days] as int) * 1.0)/d1to32.NumOfSchools
				when isnull(d75.NumOfSchools, 0) > 0 and isnull(d1to32.NumOfSchools, 0) = 0 
					then (cast(f.[PSY - L6 Days] as int) * 1.0)/d75.NumOfSchools
				when isnull(d75.NumOfSchools, 0) > 0 and isnull(d1to32.NumOfSchools, 0) > 0 then 
					case when (cast(f.[PSY - L6 Days] as int) >= 4) then 
						case when c.SchoolDBN like '75%' then 
								(1.0/d75.NumOfSchools)
							when c.SchoolDBN not like '75%' then 
								((cast(f.[PSY - L6 Days] as int) - 1.0) * 1.0)/d1to32.NumOfSchools
							end
					else
						case when c.SchoolDBN like '75%' then 
								(0.5/d75.NumOfSchools)
							when c.SchoolDBN not like '75%' then 
								((cast(f.[PSY - L6 Days] as int) - 0.5) * 1.0)/d1to32.NumOfSchools
							end
					end
			end as NumberOfDaysInDBNOriginal,
			case when TRIM(f.[PSY - L6 Days]) = 'OC' or f.[PSY - L6 Days] is null or 
				isnumeric(f.[PSY - L6 Days]) = 0 then 0
				else cast(f.[PSY - L6 Days] as numeric(10,2)) 
			end as NumberOfDaysInClusterPL,
			isnull(d75.NumOfSchools, 0) + isnull(d1to32.NumOfSchools, 0) as NumberOfSchoolsInClusterPL,
			f.[PSY - Cluster Language],
			f.[Cluster Name:CL Cluster Language Delivery]
		from #IEPConnectRawData f 
			inner join cte c 
				on f.[CL Cluster District] = c.[CL Cluster District]
				and f.[Appointed Clinician] = c.[Appointed Clinician]
			left join (
				select [CL Cluster District], [Appointed Clinician], count(*) as NumOfSchools
				from cte 
				where isnull(SchoolDBN, '') <> ''
				--Count only valid locations (LEFT(6) function is used to handle D75 SchoolDBNs which has format of 75XXXX@DDYYYY)
				and left(SchoolDBN, 6) in (select SchoolDBN from RPT_Locations)
				and SchoolDBN not like '75%' 
				group by [CL Cluster District], [Appointed Clinician]	
			) d1to32
				on f.[CL Cluster District] = d1to32.[CL Cluster District]
				and f.[Appointed Clinician] = d1to32.[Appointed Clinician]
			left join (
				select [CL Cluster District], [Appointed Clinician], count(*) as NumOfSchools 
				from cte 
				where isnull(SchoolDBN, '') <> ''
				--Count only valid locations (LEFT(6) function is used to handle D75 SchoolDBNs which has format of 75XXXX@DDYYYY)
				and left(SchoolDBN, 6) in (select SchoolDBN from RPT_Locations)
				and SchoolDBN like '75%' 
				group by [CL Cluster District], [Appointed Clinician]	
			) d75
				on f.[CL Cluster District] = d75.[CL Cluster District]
				and f.[Appointed Clinician] = d75.[Appointed Clinician]
		where isnull(c.SchoolDBN, '') <> '' and left(c.SchoolDBN, 6) in (select SchoolDBN from RPT_Locations)
		--and f.[Appointed Clinician] = 'Alexandra Griffin'

		;with cte as (
			select f.[CL Cluster District], [Appointed Clinician], TRIM(r.value) as SchoolDBN,
				'PSY - L7' as SchoolDBNSource 
			from #IEPConnectRawData f
				cross apply string_split(f.[PSY - L7 Schools_Cleaned], ',') r
		) 
		insert into #PSYSchools(
			[CL Cluster Code],
			[CL Cluster Name],	
			[CL Cluster District],
			[Appointed Clinician],
			SchoolDBN,
			SchoolDBNSource,
			NumberOfDaysInDBNOriginal,
			NumberOfDaysInClusterPL,
			NumberOfSchoolsInClusterPL,
			[PSY - Cluster Language],
			[Cluster Name:CL Cluster Language Delivery]
		)
		select 
			f.[CL Cluster Code],
			f.[CL Cluster Name],	
			c.[CL Cluster District], c.[Appointed Clinician], c.SchoolDBN, c.SchoolDBNSource,
			case when TRIM(f.[PSY - L7 Days]) = 'OC' or f.[PSY - L7 Days] is null or 
				isnumeric(f.[PSY - L7 Days]) = 0 then 0
				when isnull(d75.NumOfSchools, 0) = 0 and isnull(d1to32.NumOfSchools, 0) > 0 
					then (cast(f.[PSY - L7 Days] as int) * 1.0)/d1to32.NumOfSchools
				when isnull(d75.NumOfSchools, 0) > 0 and isnull(d1to32.NumOfSchools, 0) = 0 
					then (cast(f.[PSY - L7 Days] as int) * 1.0)/d75.NumOfSchools
				when isnull(d75.NumOfSchools, 0) > 0 and isnull(d1to32.NumOfSchools, 0) > 0 then 
					case when (cast(f.[PSY - L7 Days] as int) >= 4) then 
						case when c.SchoolDBN like '75%' then 
								(1.0/d75.NumOfSchools)
							when c.SchoolDBN not like '75%' then 
								((cast(f.[PSY - L7 Days] as int) - 1.0) * 1.0)/d1to32.NumOfSchools
							end
					else
						case when c.SchoolDBN like '75%' then 
								(0.5/d75.NumOfSchools)
							when c.SchoolDBN not like '75%' then 
								((cast(f.[PSY - L7 Days] as int) - 0.5) * 1.0)/d1to32.NumOfSchools
							end
					end
			end as NumberOfDaysInDBNOriginal,
			case when TRIM(f.[PSY - L7 Days]) = 'OC' or f.[PSY - L7 Days] is null or 
				isnumeric(f.[PSY - L7 Days]) = 0 then 0
				else cast(f.[PSY - L7 Days] as numeric(10,2)) 
			end as NumberOfDaysInClusterPL,
			isnull(d75.NumOfSchools, 0) + isnull(d1to32.NumOfSchools, 0) as NumberOfSchoolsInClusterPL,
			f.[PSY - Cluster Language],
			f.[Cluster Name:CL Cluster Language Delivery]
		from #IEPConnectRawData f 
			inner join cte c 
				on f.[CL Cluster District] = c.[CL Cluster District]
				and f.[Appointed Clinician] = c.[Appointed Clinician]
			left join (
				select [CL Cluster District], [Appointed Clinician], count(*) as NumOfSchools
				from cte 
				where isnull(SchoolDBN, '') <> ''
				--Count only valid locations (LEFT(6) function is used to handle D75 SchoolDBNs which has format of 75XXXX@DDYYYY)
				and left(SchoolDBN, 6) in (select SchoolDBN from RPT_Locations)
				and SchoolDBN not like '75%' 
				group by [CL Cluster District], [Appointed Clinician]	
			) d1to32
				on f.[CL Cluster District] = d1to32.[CL Cluster District]
				and f.[Appointed Clinician] = d1to32.[Appointed Clinician]
			left join (
				select [CL Cluster District], [Appointed Clinician], count(*) as NumOfSchools 
				from cte 
				where isnull(SchoolDBN, '') <> ''
				--Count only valid locations (LEFT(6) function is used to handle D75 SchoolDBNs which has format of 75XXXX@DDYYYY)
				and left(SchoolDBN, 6) in (select SchoolDBN from RPT_Locations)
				and SchoolDBN like '75%' 
				group by [CL Cluster District], [Appointed Clinician]	
			) d75
				on f.[CL Cluster District] = d75.[CL Cluster District]
				and f.[Appointed Clinician] = d75.[Appointed Clinician]
		where isnull(c.SchoolDBN, '') <> '' and left(c.SchoolDBN, 6) in (select SchoolDBN from RPT_Locations)
		--and f.[Appointed Clinician] = 'Alexandra Griffin'

		--Adjust indefinite fractional days that contribtue to sum increasing or decreaing by 0.01 by adding or subtracting 0.01  
		--For example, if a PL in cluster has 2 days and 3 schools, 2/3 gives 0.67, 0.67, 0.67 whose sum 2.01 exceeds the cluster capacity of 2. 
		update #PSYSchools set NumberOfDaysInDBNAdjusted = NumberOfDaysInDBNOriginal

		update p 
		set NumberOfDaysInDBNAdjusted = 
			case when prt.SumOfDBNDays > prt.NumberOfPLClusterDays then p.NumberOfDaysInDBNOriginal - 0.01
				when  prt.SumOfDBNDays < prt.NumberOfPLClusterDays then p.NumberOfDaysInDBNOriginal + 0.01
			end
		from #PSYSchools p
		inner join (
			select *, ROW_NUMBER() over(partition by [CL Cluster District], [Appointed Clinician], SchoolDBNSource order by SchoolDBN) as rnk 
			from #PSYSchools  
		) rnk
			on p.[CL Cluster District] = rnk.[CL Cluster District] 
			and p.[Appointed Clinician] = rnk.[Appointed Clinician] 
			and p.SchoolDBNSource = rnk.SchoolDBNSource 
			and p.SchoolDBN = rnk.SchoolDBN 
			and rnk.rnk = 1
		inner join (
			select [CL Cluster District], [Appointed Clinician], SchoolDBNSource,
					sum(isnull(NumberOfDaysInDBNOriginal, 0)) as SumOfDBNDays,
					max(NumberOfDaysInClusterPL) as NumberOfPLClusterDays 
			from #PSYSchools
			where [CL Cluster District] like 'D%'
			group by [CL Cluster District], [Appointed Clinician], SchoolDBNSource 
			having abs(sum(isnull(NumberOfDaysInDBNOriginal, 0)) - max(NumberOfDaysInClusterPL)) = 0.01
		) prt 
			on p.[CL Cluster District] = prt.[CL Cluster District] 
			and p.[Appointed Clinician] = prt.[Appointed Clinician] 
			and p.SchoolDBNSource = prt.SchoolDBNSource 


		--IDentify Business Rules for HighSchool Clusters
		--select * from #PSYSchools 
		--where [CL Cluster District] = 'XHS'
		--and [Appointed Clinician] = 'Cynthia Mensah-white'
		  
		insert into #DataValidationIssues(IssueDescription, IssueContent, IssueCount)
		select 'D type Cluster doesn''t add to 5 days - most likely due to invalid DBNs', 
			[CL Cluster District] + '  ' +  [Appointed Clinician], sum(NumberOfDaysInDBNAdjusted)
		from #PSYSchools 
		where [CL Cluster District] like 'D%' --Run validation for only Elementary and middle schools
		group by [CL Cluster District], [Appointed Clinician]
		having sum(NumberOfDaysInDBNAdjusted) is null or sum(NumberOfDaysInDBNAdjusted) <> 5.00
	--END: [PSY - L1 Schools_Cleaned], L2 Schools, etc.
	
	--BEGIN: Validate Cluster value
		insert into #DataValidationIssues(IssueDescription, IssueContent)
		select 'FYI - Blank Cluster Code (we still process if CL District and Clinician are available', 
			[CL Cluster District] + '  ' +  [Appointed Clinician]
		from #IEPConnectRawData where isnull([CL Cluster Code], '') = ''
		
		insert into #DataValidationIssues(IssueDescription, IssueContent, IssueCount)
		select 'Cluster Code on multiple rows (we still process if CL District and Clinician are unique', 
			[CL Cluster Code], count(*)  
		from #IEPConnectRawData group by [CL Cluster Code] having count(*) > 1
		and isnull([CL Cluster Code], '') <> '' 
		--select isnull(Cluster, '') + isnull([CL Cluster District], '') + isnull([Appointed Clinician], ''), count(*) 
		--from #IEPConnectRawData group by isnull(Cluster, '') + isnull([CL Cluster District], '') + isnull([Appointed Clinician], '') having count(*) > 1
		

		insert into #DataValidationIssues(IssueDescription, IssueContent, IssueCount)
		select 'Violation of Uniqueness: CL District + Clinician', isnull([CL Cluster District], '') + isnull([Appointed Clinician], ''), count(*) from #IEPConnectRawData 
		group by isnull([CL Cluster District], '') + isnull([Appointed Clinician], '') 
		having count(*) > 1
	--END: Validate Cluster value

	--BEGIN: PsychDays should sum to 5 per clinician. Anything other than 5 is an issue
		insert into #DataValidationIssues(IssueDescription, IssueContent)
		select 'Psych Days don''t add to 5', [Appointed Clinician] + '. Total Days: ' + str(sum(isnull(NumberOfDaysInDBNAdjusted, 0)))
		from #PSYSchools 
		where [CL Cluster District] like 'D%'
		group by [Appointed Clinician], [CL Cluster District] having sum(isnull(NumberOfDaysInDBNAdjusted, 0)) <> 5
		
	--END: PsychDays should sum to 5 per clinician. Anything other than 5 is an issue
	--select * From #PSYSchools where [Appointed Clinician] = 'Jeffrey Yorke'

	drop table if exists #INT_POSPsychDaysByDBN
	select SchoolDBN, 
			isnull([English], 0) as NumDaysMonolingual, 
			isnull([Spanish], 0) + 
			isnull([Chinese], 0) + 
			isnull([RUSSIAN], 0) +
			isnull([ARABIC], 0) + 
			isnull([Cantonese], 0) +
			isnull([Haitian Creole], 0) +
			isnull([Hindi], 0) +
			isnull([Korean], 0) +
			isnull([Mandarin], 0) +
			isnull([Urdu], 0) as NumDaysBilingual,
			isnull([Spanish], 0) as NumdaysSpanish, 
			isnull([Chinese], 0) as NumDaysChinese, 
			isnull([RUSSIAN], 0) as NumDaysRussian, 
			isnull([ARABIC], 0) as NumDaysArabic,
			isnull([Cantonese], 0) as NumDaysCantonese,
			isnull([Haitian Creole], 0) as NumDaysHaitianCreole,
			isnull([Hindi], 0) as NumDaysHindi,
			isnull([Korean], 0) as NumDaysKorean,
			isnull([Mandarin], 0) as NumDaysMandarin,
			isnull([Urdu], 0) as NumDaysUrdu 
	into #INT_POSPsychDaysByDBN
	from (
		select SchoolDBN, [PSY - Cluster Language], isnull(NumberOfDaysInDBNAdjusted, 0) as NumOfDays
		from #PSYSchools  
	) A
	PIVOT(
		sum(NumOfDays) 
		FOR [PSY - Cluster Language] in (
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
	order by 1

--Added Appointed Clinician override validation -10/20/2025

	DROP TABLE IF EXISTS #AppointedClinicianOverride
	SELECT DISTINCT [Appointed Clinician], [CL Cluster Code], [CL Cluster Name], [Cluster Name:CL Cluster Language Delivery]
	INTO #AppointedClinicianOverride
	FROM [Staging].[lk_IEPXClusteringWorksheet4POSPsychDays] a
	WHERE [Cluster Name:CL Cluster Service] = 'Psychologist'
	AND [PSY - Cluster Language] = 'Chinese'
	AND not exists ( 
				SELECT 1 
				FROM [SEO_MART].[dbo].[RPT_POSPsychDaysLanguageOverride] b
				where b.CLClusterName = a.[CL Cluster Name]  --Raji: 11/12/2025
				and b.[PsychologistName] = a.[Appointed Clinician]
			)

	--SELECT * FROM #AppointedClinicianOverride

	

	If ((SELECT COUNT(*) FROM #AppointedClinicianOverride) >0)
	BEGIN
	INSERT INTO #DataValidationIssues(IssueDescription, IssueContent)
	SELECT 'Chinese Appointed clinician missing in override table' AS IssueDescription, 
		'Chinese Appointed Clinician: ' + [Appointed Clinician] + '  in Cluster Code: ' + [CL Cluster Code] 
			+ ' with CL Cluster Language Delivery: '+ [Cluster Name:CL Cluster Language Delivery] 
			+ ' is not in [SEO_MART].[dbo].[RPT_POSPsychDaysLanguageOverride] table' 
		AS IssueContent
	FROM
	#AppointedClinicianOverride
	END
  
--SELECT * FROM #DataValidationIssues

	insert into #DataValidationIssues(IssueDescription, IssueContent)
	select 'School doesn''t have a psychologist', c.SchoolDBN 
	from #INT_POSPsychDaysByDBN c
		inner join RPT_Locations l on left(c.SchoolDBN, 6) = l.SchoolDBN 
	where isnull(l.LocationCategoryDescription, '') in (
		'Elementary', 'K-12 all grades', 'K-8'
	)
	and c.NumDaysMonolingual + c.NumDaysBilingual = 0
	and c.SchoolDBN not like '75%'
	order by 2


	insert into Staging.lk_IEPXClusteringWorksheet4POSPsychDays_ValidationIssues 
	(IssueDescription, IssueContent, IssueCount, ETLProcessedDate, ETLProcessedDateTime)
	select IssueDescription, IssueContent, IssueCount, @ETLProcessedDate, @ETLProcessedDateTime 
	from #DataValidationIssues 

	select 'Validation Issues', * from #DataValidationIssues
	where IssueDescription not like 'Appointed Clinician Missing%'
	order by IssueDescription 
	
end