USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPINT_T5LoadAvailableCapacity]    Script Date: 4/4/2026 3:59:03 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[USPINT_T5LoadAvailableCapacity]
/*
Modification History:
Raji		11/20/2024		Initial Draft
Charlotte	11/22/2025		Replaced global temp tables with permanent tables with suffix "_WT" (WT = Working Table)
Charlotte   02/04/2026      FIX: DBN-level AvailableCapacity must be computed as (SUM(CaseAssignmentCapacity) - SUM(AssignedCapacity))
                            instead of SUM(AvailableCapacity), because view AvailableCapacity is non-negative (clipped at 0) and
                            does not reflect overage when a language capacity drops to 0 but existing assignments remain.
                            This prevents Wave from assigning into a DBN that is already over capacity at the total DBN level.
Raji		02/05/2026		Discontinue the load of mono and bi columns in DBN level capacity table RPT_T5tfDBNCapacity_WT
*/
as
BEGIN
	SET NOCOUNT ON

	--Get all DBN with Available Capacity  
	truncate table RPT_T5tfDBNCapacity_WT
	insert into RPT_T5tfDBNCapacity_WT(
		SchoolDBN,
		LocationType,
		SchoolType,
		GeographicalDistrict,
		ZipCode,
		--AssignedCapacity_Bilingual,
		--AvailableCapacity_CC_Bilingual,
		--MaxCaseAssignmentCapacity_Bilingual,
		--AssignedCapacity_Monolingual,
		--AvailableCapacity_CC_Monolingual,
		--MaxCaseAssignmentCapacity_Monolingual,
		AssignedCapacity_MonoAndBiCombo,
		AvailableCapacity_CC_MonoAndBiCombo,
		MaxCaseAssignmentCapacity_MonoAndBiCombo,
		Latitude,
		Longitude
	)
	Select DISTINCT DC.* From (
		Select 
			AC.SchoolDBN, 
			AC.LocationType,
			AC.SchoolType,	
			CASE WHEN AC.LocationType<>'CSE' AND AC.AdminDistrict<>AC.GeographicalDistrict 
			THEN AC.AdminDistrict ELSE AC.GeographicalDistrict END as GeographicalDistrict,
			AC.ZipCode,
			--sum(case when IsBilingualPsych = 1 then AssignedCapacity else 0 end) as AssignedCapacity_Bilingual,
			--sum(case when IsBilingualPsych = 1 then AvailableCapacity else 0 end) as AvailableCapacity_CC_Bilingual,
			--sum(case when IsBilingualPsych = 1 then CaseAssignmentCapacity else 0 end) as MaxCaseAssignmentCapacity_Bilingual,
			--sum(case when IsBilingualPsych = 0 then AssignedCapacity else 0 end) as AssignedCapacity_Monolingual,
			--sum(case when IsBilingualPsych = 0 then AvailableCapacity else 0 end) as AvailableCapacity_CC_Monolingual,
			--sum(case when IsBilingualPsych = 0 then CaseAssignmentCapacity else 0 end) as MaxCaseAssignmentCapacity_Monolingual,
			sum(AssignedCapacity) as AssignedCapacity_MonoAndBiCombo,
			--sum(AvailableCapacity) as AvailableCapacity_CC_MonoAndBiCombo,
			case when sum(CaseAssignmentCapacity) - sum(AssignedCapacity) <=0 then 0 
					else sum(CaseAssignmentCapacity) - sum(AssignedCapacity) end
				as AvailableCapacity_CC_MonoAndBiCombo,
			sum(CaseAssignmentCapacity) as MaxCaseAssignmentCapacity_MonoAndBiCombo,
			AC.Latitude,
			AC.Longitude
		From SEO_MART.dbo.vwRPT_T5CaseAssignmentCapacitybyDBNAndLanguage AC
		group by SchoolDBN, AdminDistrict, GeographicalDistrict, LocationType, SchoolType, ZipCode, Latitude, Longitude
	) DC Where DC.AvailableCapacity_CC_MonoAndBiCombo>0;


	truncate table RPT_T5tfDBNLanguageCapacity_WT
	insert into RPT_T5tfDBNLanguageCapacity_WT(
		SchoolDBN,
		Language,
		LocationType,
		SchoolType,
		GeographicalDistrict,
		ZipCode,
		IsBilingualPsych,
		AssignedCapacity,
		AvailableCapacity_CC,
		MaxCaseAssignmentCapacity,
		Latitude,
		Longitude
	)
	Select DISTINCT DC.* From (
		Select 
			AC.SchoolDBN, 
			AC.Language,
			AC.LocationType,
			AC.SchoolType,	
			CASE WHEN AC.LocationType<>'CSE' AND AC.AdminDistrict<>AC.GeographicalDistrict 
					THEN AC.AdminDistrict 
				ELSE AC.GeographicalDistrict 
			END as GeographicalDistrict,
			AC.ZipCode,
			IsBilingualPsych,
			AssignedCapacity,
			AvailableCapacity as AvailableCapacity_CC,
			CaseAssignmentCapacity as MaxCaseAssignmentCapacity,
			AC.Latitude,
			AC.Longitude
		From SEO_MART.dbo.vwRPT_T5CaseAssignmentCapacitybyDBNAndLanguage AC
	) DC Where DC.AvailableCapacity_CC>0;

END
