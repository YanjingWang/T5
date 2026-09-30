USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPRPT_POSPSYCHDAYSDetail]    Script Date: 4/4/2026 1:35:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[USPRPT_POSPSYCHDAYSDetail]
/*
Sample call: exec dbo.USPRPT_POSPSYCHDAYSDetail
Purpose: This stored proc creates RPT_POSPSYCHDAYSDetail at the most granual level: Clinician, Language, DBN, Days 
		It's created by applying below distribution rules for "PSYDays" into "PSYSchools" from INT_CLUSTERINGWORKSHEET4POSPSYCHDAYS
		If PSYSchools don't have a mix of D1-32 schools and D75 schools, then district PSYDays uniformly among PSYSchools
			Ex: PSYSchools: 01M015, 01M019 and PSYDays: 5 then give 2.5 days to 01M015 and 2.5 days 01M019
		If PSY is a mix of D1-32 and D75, then apply below rule
			If PSYDays is 4 or higher, then set aside 1 day for all D75 schools combined and distribute the rest unifomrly among D1-32 schools
			If PSYDays is 3 or lower, then set aside 0.5 day for all D75 schools combined and distribute the rest unifomrly among D1-32 schools
		After all distributions are combined, if total clinician days add to 4.99 or 5.01, then add or subtract 0.01 from any DBN of the clinician
			Ex, if Mr X is 5 days to 01M015, 01M019 and 01M023, then distribute 1.67 to each school. But the total becomes 5.01
				So, substract 0.01 from one school to make final distribution as 1.67, 1.67 and 1.66 that adds to 5

Modification History:
Name		Date			Comments
Raji		01/25/2025		Initial Draft
Raji		11/12/2025		Modified to support LanguageOverride to be any language. Prior to this, 
							the LangaugeOverride was expecting only Chinese(Both), Mandarin and Cantonese 
							Why change? To support instances where ClinicianLanguage is different from ClusterLanguage.
							Sometimes, when ClusterLanguage is 'Chinese', ClinicalLanguage can be 'English'. Ex: Clinician Winnie Chen
							This happens when monolingual clinicians are hired into bilingual clusters, due to staffing or timing or other constraints
							In the override table, LanguageOriginal = ClusterLanguage and LanguageOverride = AppointedClinicianLanguage
*/
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @ETLProcessedDate date, @ETLProcessedDateTime datetime
	select @ETLProcessedDateTime = getdate()
	select @ETLProcessedDate = cast(@ETLProcessedDateTime as date)

	SELECT * 
	INTO #IEPCONNECTDATA
	FROM INT_CLUSTERINGWORKSHEET4POSPSYCHDAYS
	WHERE ETLProcessedDateTime = (SELECT MAX(ETLProcessedDateTime) FROM INT_CLUSTERINGWORKSHEET4POSPSYCHDAYS)

	--BEGIN: Override Language when ClusterLanguage is different from the AppointedClinician Language
	--We obtained this information from Kathy and Arwina on a Teams call and Chat on 2/5/2025 and subsequently in Oct 2025 via Teams chat
	--In the override table, LanguageOriginal = ClusterLanguage and LanguageOverride = AppointedClinicianLanguage
	update iep 
	set PSYClusterLanguage = ov.LanguageOverride,
		CLClusterLanguageDelivery = case when ov.LanguageOverride = 'English' then 'Monolingual' else 'Bilingual' end
	--select *
	from #IEPCONNECTDATA iep	
		inner join RPT_POSPsychDaysLanguageOverride ov
			on iep.AppointedClinician = ov.PsychologistName
			and iep.CLClusterName = ov.CLClusterName
			and iep.PSYClusterLanguage = ov.LanguageOriginal 
			and getdate() between ov.OverrideEffDate and ov.OverrideEndDate
	--END: Override Language when ClusterLanguage is different from the AppointedClinician Language

	truncate table dbo.RPT_POSPSYCHDAYSDetail

	insert into RPT_POSPSYCHDAYSDetail(
		CLClusterCode
		, CLClusterName
		, CLClusterDistrict
		, PsychologistName
		, Language
		, LanguageFlag
		, SchoolDBN
		, POSPsychDaysInDBN
		, PSYLotName
		, POSPsychDaysInPSYLot
		, NumberOfSchoolsInPSYLot
		, ETLProcessedDate
		, ETLProcessedDateTime
	)
	select 
		f.CLClusterCode,
		f.CLClusterName,	
		f.CLClusterDistrict, 
		f.AppointedClinician as PsychologistName, 
		f.PSYClusterLanguage,
		case when f.CLClusterLanguageDelivery = 'Monolingual' then 'M' else 'B' end as LanguageFlag,
		f.SchoolDBN, 
		isnull(f.POSPsychDaysInDBN, 0) as POSPsychDaysInDBN,
		f.PSYLName as PSYLotName,
		f.POSPsychDaysInPSYLot,
		f.NumberOfSchoolsInCluster as NumberOfSchoolsInPSYLot,
		@ETLProcessedDate,
		@ETLProcessedDateTime
	from 
	(
		select i.CLClusterCode, i.CLClusterName, i.CLClusterDistrict, i.AppointedClinician, 'PSYL1' as PSYLName, 
			i.PSYL1Days as POSPsychDaysInPSYLot, i.PSYClusterLanguage, i.CLClusterLanguageDelivery, r.*
		from #IEPCONNECTDATA i
			cross apply 
			(
				select * from dbo.FN_PSOPsychDaysDistribution(i.PSYL1Schools, i.PSYL1Days)
			) r
		where isnull(r.SchoolDBN, '') <> ''
		union all 
		select i.CLClusterCode, i.CLClusterName, i.CLClusterDistrict, i.AppointedClinician, 'PSYL2' as PSYLName, 
			i.PSYL2Days as POSPsychDaysInPSYLot, i.PSYClusterLanguage, i.CLClusterLanguageDelivery, r.*
		from #IEPCONNECTDATA i
			cross apply 
			(
				select * from dbo.FN_PSOPsychDaysDistribution(i.PSYL2Schools, i.PSYL2Days)
			) r
		where isnull(r.SchoolDBN, '') <> ''
		and isnull(i.PSYL2Schools, '') <> ''
		union all 
		select i.CLClusterCode, i.CLClusterName, i.CLClusterDistrict, i.AppointedClinician, 'PSYL3' as PSYLName, 
			i.PSYL3Days as POSPsychDaysInPSYLot, i.PSYClusterLanguage, i.CLClusterLanguageDelivery, r.*
		from #IEPCONNECTDATA i
			cross apply 
			(
				select * from dbo.FN_PSOPsychDaysDistribution(i.PSYL3Schools, i.PSYL3Days)
			) r
		where isnull(r.SchoolDBN, '') <> ''
		and isnull(i.PSYL3Schools, '') <> ''
		union all 
		select i.CLClusterCode, i.CLClusterName, i.CLClusterDistrict, i.AppointedClinician, 'PSYL4' as PSYLName, 
			i.PSYL4Days as POSPsychDaysInPSYLot, i.PSYClusterLanguage, i.CLClusterLanguageDelivery, r.*
		from #IEPCONNECTDATA i
			cross apply 
			(
				select * from dbo.FN_PSOPsychDaysDistribution(i.PSYL4Schools, i.PSYL4Days)
			) r
		where isnull(r.SchoolDBN, '') <> ''
		and isnull(i.PSYL4Schools, '') <> ''
		union all 
		select i.CLClusterCode, i.CLClusterName, i.CLClusterDistrict, i.AppointedClinician, 'PSYL5' as PSYLName, 
			i.PSYL5Days as POSPsychDaysInPSYLot, i.PSYClusterLanguage, i.CLClusterLanguageDelivery, r.*
		from #IEPCONNECTDATA i
			cross apply 
			(
				select * from dbo.FN_PSOPsychDaysDistribution(i.PSYL5Schools, i.PSYL5Days)
			) r
		where isnull(r.SchoolDBN, '') <> ''
		and isnull(i.PSYL5Schools, '') <> ''
		union all 
		select i.CLClusterCode, i.CLClusterName, i.CLClusterDistrict, i.AppointedClinician, 'PSYL6' as PSYLName, 
			i.PSYL6Days as POSPsychDaysInPSYLot, i.PSYClusterLanguage, i.CLClusterLanguageDelivery, r.*
		from #IEPCONNECTDATA i
			cross apply 
			(
				select * from dbo.FN_PSOPsychDaysDistribution(i.PSYL6Schools, i.PSYL6Days)
			) r
		where isnull(r.SchoolDBN, '') <> ''
		and isnull(i.PSYL6Schools, '') <> ''
		union all 
		select i.CLClusterCode, i.CLClusterName, i.CLClusterDistrict, i.AppointedClinician, 'PSYL7' as PSYLName, 
			i.PSYL7Days as POSPsychDaysInPSYLot, i.PSYClusterLanguage, i.CLClusterLanguageDelivery, r.*
		from #IEPCONNECTDATA i
			cross apply 
			(
				select * from dbo.FN_PSOPsychDaysDistribution(i.PSYL7Schools, i.PSYL7Days)
			) r
		where isnull(r.SchoolDBN, '') <> ''
		and isnull(i.PSYL7Schools, '') <> ''
	) f

	--Archive 
	insert into arch.RPT_POSPSYCHDAYSDetail
	(
		CLClusterCode
		, CLClusterName
		, CLClusterDistrict
		, PsychologistName
		, Language
		, LanguageFlag
		, SchoolDBN
		, POSPsychDaysInDBN
		, PSYLotName
		, POSPsychDaysInPSYLot
		, NumberOfSchoolsInPSYLot
		, ETLProcessedDate
		, ETLProcessedDateTime
		, ArchivedDate
		, ArchivedDateTime
	)
	select 
		CLClusterCode
		, CLClusterName
		, CLClusterDistrict
		, PsychologistName
		, Language
		, LanguageFlag
		, SchoolDBN
		, POSPsychDaysInDBN
		, PSYLotName
		, POSPsychDaysInPSYLot
		, NumberOfSchoolsInPSYLot
		, ETLProcessedDate
		, ETLProcessedDateTime
		, @ETLProcessedDate as ArchiveDate
		, @ETLProcessedDateTime as ArchivedDateTime
	from dbo.RPT_POSPSYCHDAYSDetail

END
