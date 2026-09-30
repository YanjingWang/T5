USE [SEO_REPORTING]
GO

/****** Object:  View [BI].[vw_T5Dashboard_Referrals_YOYReferrals_Citywide]    Script Date: 4/6/2026 1:40:51 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO












CREATE view [BI].[vw_T5Dashboard_Referrals_YOYReferrals_Citywide]

/****************************************************************************************************************************************************************************************************************
Object Name: [SEO_REPORTING].[BI].[vw_T5Dashboard_Referrals_YOYReferrals_Citywide]

Sample call: select * from BI.vw_T5Dashboard_Referrals_YOYReferrals_Citywide

Purpose: Overall Citywide Metrics comparision.

Date Created: 8/21/2024

Modification Details: INITIAL

Author             ModifiedDate   Comments
-----------------  -------------  ----------------------------------------------
Prem Boompagh      8/21/2024      Initial.	
Charlotte Wang     12/17/2025     Dynamic Rollover
Ariel H			   12/23/2025	  Commented out INT_ServicesSummary join as it's not being actively used
Ariel H			   03/09/2026     TemporaryHousingStatus was written incorrectly. Instead of not NULl changed to 'DHS'
***************************************************************************************************************************************************************************************************************/
AS
SELECT t5.[StudentID]
	,t5.[FirstName]
	,t5.[LastName]
	,t5.[BirthDate]
	,t5.[School DBN]
	,t5.[IsTurning5]
	,t5.[ReferralDate]
	,t5.[ConsentDate]
	,t5.[SocialHistoryAssessDate]
	,t5.[PhysicalExamAssessDate]
	,t5.[ClassroomOBSAssessDate]
	,t5.[PsychoEDAssessDate]
	,t5.[IEPNoticeDate]
	,t5.[T5IEPNoticeDate]
	,t5.[OutcomeDate]
	,MONTH(t5.[OutcomeDate]) [Outcome Month]
	,DATENAME(MONTH, t5.[OutcomeDate]) [Outcome Month Name]
	,t5.[PlacementDate]
	,t5.[ConsentProvisionServiceDate] --[ConsentProvisionService]
	,t5.[LocationLetterDate]
	
	,t5.[PWNComplianceDate]
	,t5.[InActiveSinceDate]
	,CASE 
		WHEN t5.[InActiveSinceDate] IS NULL
			THEN 'Y' -- The case satatement was added to flag students who are Active - Prem Boompagh 5/19/2022
		ELSE 'N'
		END AS [IsActive]
	,t5.[SchoolYear]
	,t5.[PlacementDocStatus]
	,t5.[PlacementDocStatusDesc]
	,t5.[SLLDocStatus]
	,t5.[SLLDocStatusDesc]
	--  ,t5.[DateIEP]
	
	,t5.[IniRefUplReceiveDate] --[DateIniRefUplReceive]
	,t5.[ProcessStage]
	,t5.[ProcessStageDesc]
	,t5.[OutcomeReason]
	,t5.[OutcomeReasonDesc]
	,t5.[DisabilityCode]
	,t5.[ClassificationDesc]
	,t5.[ReasonForRecommendPlacement]
	,t5.[RecommendPlacementDesc]	
	,t5.[AssignedSchoolDBN]
	,t5.[WaveAssignedSchoolDBN]
	--  ,t5.[ATSPrekSchoolDBN]
	,t5.[D75AdminDBN]
	,t5.[D75PhysicalDBN]
	,t5.[CurrentAddAdminDBN]
	,t5.[SchoolType]
	,t5.[T5IEPTeamDesc]
	,t5.[T5IEPTeamType]
	,t5.[SupsOfPsychName]
	,t5.[T5CaseLoad]
	,t5.[CSE]
	-- ,t5.[AddLocAdmin]
	
	,t5.[Superintendent]
	,t5.[AdminDistrict]
	,t5.[CaseType]
	,CASE 
		WHEN t5.[CaseType] = 'T5 RE-EVAL'
			THEN 'Reevaluation'
		WHEN t5.[CaseType] = 'T5 INITIAL'
			THEN 'Initial'
		ELSE t5.[CaseType]
		END AS ReferralType
	,t5.[ReassignmentDate]
	,t5.AccessibleProgramFlag --[IsAccessibleProgram]
	,t5.[ELLStatus]
	,t5.[Gender]
	,t5.[Ethnicity]
     ,eth.CCGrouping as EthnicityCC
	,t5.[HomeDistrict]
	,t5.[HouseNumber]
	,t5.[Street]
	,t5.[BoroCode]
	,t5.[ZipCode]
	,t5.[ApartmentNumber]
	,t5.[CityName]
	,t5.[GuardianFirstName]
	,t5.[GuardianLastName]
	,t5.[GuardianPhoneNumber]
	,t5.ESYFlag --[ESY]
	,t5.ESYSameServiceFlag --[ESYSameService]
	,t5.[T5SESISStatus]
	,t5.[T5SESISStatusCode]
	,t5.[T5SESISStatusGrouping]
	,t5.[T5SESISStatusCodeGrouping]
	,t5.[T5SESISStatusCodeDashboard]
	,t5.[T5SESISStatusDashboard]
	,t5.[ReportStatus]
	,t5.[Notice]
	-- ,t5.[CAPRefDate]
	,t5.[DHSDVFlag]
	,CASE 
		WHEN t5.[DHSDVFlag] ='DHS'--IS NOT NULL
			THEN 'Y'
		WHEN t5.[DHSDVFlag] IS NULL
			THEN 'N'
		END AS TemporaryHousingStatus
	,t5.[ReferralSchool]
	,t5.[CurrentCAPServiceSchool]
	,t5.[ServiceSchoolName]
	,t5.[AssessmentBilLangCode]
	
	,LCode.CCGrouping AS 'LanguageDescriptionGrouping'
	--,t5.[CCDate]
	,t5.[CaseCloseReasonCode] --[CCReasonCode]
	,t5.[CaseCloseDesc] --[CCDesc]
	
	,t5.[CAPDischargeCode]
	--,t5.[IEPConfDate]
	,t5.[RecmProgram]
	,t5.[EvalDesc]
	,t5.[EvalType]
	,t5.[DualRecmInd]
	,t5.[RecommServiceCategory] --[RecmServiceCategory]
	,t5.[CloseCode]
	,t5.[SEITSessionPerWeek]
	,t5.[RecommendedRS]
	
	,t5.[OutcomeCreatedOn]
	,t5.[OutcomeFinalizedOn]
	,t5.[PlacementCreatedOn]
	,t5.[PlacementFinalizedOn]
	,t5.[SLLCreatedOn]
	,t5.[SLLFinalizedOn]
	,t5.[LinkageBucket]
	,t5.FinalizedDate
	,DATEDIFF(day, t5.[ProcessedDate], t5.IEPComplianceDate) AS 'Date Diff'
	,t5.[ProcessedDate]
	/* Thomas Giresi - The following logic was added to this view on 11/27/2019 to provide monthly case distributions for the 'New T5 Year to Date' report */
	,CASE 
		WHEN YEAR(t5.[ReferralDate]) = CAST(SUBSTRING(t5.SchoolYear, 6, 4) AS INT)
			THEN /* 2nd Semester */
				CASE 
					WHEN MONTH(t5.[ReferralDate]) = 1
						THEN 'Jan Distributed Cases'
					WHEN MONTH(t5.[ReferralDate]) = 2
						THEN 'Feb Distributed Cases'
					ELSE 'Mar - June Distributed Cases'
					END
		ELSE 'Dec Distributed Cases' /* 1st Semester */
		END AS MonthlyCaseDistribution
	,CASE 
		WHEN t5.ClassificationDesc IN (
				'Multiple Disabilities'
				,'Emotional Disability'
				,'Autism'
				,'Other Health Impairment'
				,'Intellectual Disability'
				,'Speech or Language Impairment'
				,'Learning Disability'
				)
			THEN t5.ClassificationDesc
		ELSE 'Other'
		END AS ClassificationGroup
	,t5.[ClassificationDesc] AS Classification
	--  ,ss.ProgramTypeMRE
	,DIEP.DateIEP
	,CASE 
		WHEN t5.T5SESISStatusDashboard = 'Complete'
			THEN 'Complete'
		ELSE 'Open'
		END AS CaseStatus
    ,CONCAT('First ', (select max(SchoolDays) from [SEO_REPORTING].[BI].[vw_T5Dashboard_YOYReferralsSchoolDays] WITH(NOLOCK)), ' Days of School') as [Data Thru]
FROM [SEO_REPORTING].[BI].[vw_T5Dashboard_Referrals_YOYReferrals] AS t5	 WITH(NOLOCK)
/*Charlotte: add dynamic rollover*/
CROSS JOIN (
    SELECT
        CAST(YEAR(DATEADD(month,-6,GETDATE())) AS varchar(4))
        + '-'
        + CAST(YEAR(DATEADD(month, 6,GETDATE())) AS varchar(4)) AS T5SchoolYear,
        YEAR(DATEADD(month,-6,GETDATE())) - 4 AS T5BirthYear
) br
--LEFT OUTER JOIN SEO_MART.dbo.INT_ServicesSummary AS ss	WITH(NOLOCK)
--	ON t5.OutcomeDocumentIDT = ss.OutcomeDocumentIDT
LEFT JOIN (
	SELECT DateIEP
		,StudentID
		,IEPComplianceDate
	FROM (
		SELECT Row_Number() OVER (
				PARTITION BY RL.StudentID ORDER BY DO.DocumentIDT
				) TRank
			,RL.IEPComplianceDate
			,DO.*
		FROM SEO_MART.dbo.RPT_T5ReferralLinkage RL WITH (NOLOCK) --DateIEP, T5SESISStatusDashboard,
		LEFT JOIN SEO_MART.dbo.DWH_Outcome DO WITH (NOLOCK)
			ON RL.StudentID = DO.StudentID
				AND Deleted = 0
				AND DocStatus IN (
					1
					,2
					)
				AND IsDelete = 0
		) G
	WHERE TRank = 1
	) DIEP
	ON t5.StudentID = DIEP.StudentID --Added the DateIEP from DWH_Outcome by Prem.B
LEFT JOIN (
	SELECT Code
		,Description
		,CCGrouping
	FROM (
		SELECT lc.SourceName
			,lc.Code
			,lc.Description
			,lc.CCGrouping
		FROM SEO_MART.[dbo].[lk_LanguageCodes] lc WITH(NOLOCK)
		) X
	WHERE SourceName = 'CAP'
	) LCode
	ON t5.AssessmentBilLangCode = LCode.Code
left join (select distinct CCGrouping,Description from SEO_MART.dbo.lk_EthnicityCodes) eth 	
	on t5.Ethnicity = eth.Description
/*Charlotte: Remove the lk_SEOBusinessRules join + where*/
--inner join (select LookupValue from SEO_MART.dbo.lk_SEOBusinessRules WITH(NOLOCK) where LookupName = 'T5SchoolYear') rul
--	on t5.SchoolYear = rul.LookupValue
--where t5.SchoolYear = rul.LookupValue
/*Charlotte: add this condition*/
WHERE t5.SchoolYear = br.T5SchoolYear





GO


