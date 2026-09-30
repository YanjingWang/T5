USE [SEO_REPORTING]
GO

/****** Object:  View [BI].[vw_T5Dashboard_Referrals_YOYReferrals]    Script Date: 4/6/2026 1:39:35 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


















CREATE VIEW [BI].[vw_T5Dashboard_Referrals_YOYReferrals]

AS
/****************************************************************************************************************************************************************************************************************
Object Name: [SEO_REPORTING].[BI].[vw_T5Dashboard_Referrals_YOYReferrals]

Sample call: SELECT * FROM [BI].[vw_T5Dashboard_Referrals_YOYReferrals]

 
Purpose: This view is designed to retrieve year-over-year referral data for school days, presenting the school year.
Note: This view is used to reference vw_T5Dashboard_Referrals_YOYReferrals_CTE in the KIP Dashboard

Date Created: 10/22/2023
    
Modification Details: INITIAL

Author             ModifiedDate   Comments
-----------------  -------------  ----------------------------------------------
PBoompagh          10/15/2024     Updated view to dynamically retrieve SchoolYear by joining with lk_SEOBusinessRules.
Mvellanki		   07/22/2025	  Updated 'School DBN' as per Lauren to show walkins to cse users.
Charlotte Wang     12/17/2025     Dynamic Rollover 
								  rul = T5SchoolYear (LookupCategory = T5Dashboard, ReturnValue = 2)
							      rul2 = T5FinalProcessedDate (LookupCategory = T5Dashboard)
								  rul = T5SchoolYear (LookupCategory = T5Dashboard, ReturnValue = 1) in the 2nd SELECT (after UNION)
Ariel H			   02/02/2026	  AssignmentProcess added to clearly distinguish between Wave Assigned, Walk-Ins, and Ineligible students
Ariel H			   03/09/2026		   TemporaryHousingStatus was written incorrectly. Instead of not NULl changed to 'DHS'
****************************************************************************************************************************************************************************************************************/


SELECT DISTINCT t5.[StudentID],
	t5.[FirstName],
	t5.[LastName],
	t5.[BirthDate],
	COALESCE(t5.T5IEPTeam,t5.T5SchoolDBN,cse.CSESchoolDBN) AS 'School DBN', --added as per Lauren to show walkins to cse users.
	t5.[IsTurning5],
	t5.[ConsentDocumentIDT],
	t5.[OutcomeDocumentIDT],
	t5.[OutcomeTypeCode],
	t5.[OutcomeTypeDesc],
	t5.[OutcomeDocStatus],
	t5.[OutcomeDocStatusDesc],
	t5.[PlacementDocumentIDT],
	t5.[PlacementTypeCode],
	t5.[PlacementTypeDesc],
	t5.[SLLDocumentIDT],
	t5.[SLLTypeCode],
	t5.[SLLTypeDesc],
	t5.[ReferralDate],
	t5.[ConsentDate],
	t5.[SocialHistoryAssessDate],
	t5.[PhysicalExamAssessDate],
	t5.[ClassroomOBSAssessDate],
	t5.[PsychoEDAssessDate],
	t5.[IEPNoticeDate],
	t5.[T5IEPNoticeDate],
	t5.[OutcomeDate],
	MONTH(t5.[OutcomeDate]) [Outcome Month],
	DATENAME(MONTH, t5.[OutcomeDate]) [Outcome Month Name],
	od.FirstOutcomeDate,
	CASE 
		WHEN od.FirstOutcomeDate <= t5.IEPComplianceDate
			AND t5.T5SESISStatusDashboard IN (
				'Complete',
				'Finalize PNP'
				)
			THEN 1
		ELSE 0
		END AS T5IEPTimeliness,
	DocumentIDT AS 'FirstOutcomeDocumentIDT',
	t5.[PlacementDate],
	t5.[ConsentProvisionServiceDate] --[ConsentProvisionService]
	,
	t5.[LocationLetterDate],
	t5.[IEPComplianceDate],
	COALESCE(rcd.ComplianceDateDesc, 'Non-Standard Compliance Date') AS [IEPStandardComplianceDate]
	--,case when t5.[IEPComplianceDate] = '2024-06-03' then 'Monday, June 03, 2024' --2023
	--     when t5.[IEPComplianceDate] = '2024-07-04' then 'Thursday, July 04, 2024'  --2023 
	--     when t5.[IEPComplianceDate] = '2024-08-05' then 'Monday, August 05, 2024'  --2023
	--	ELSE 'Non-Standard Compliance Date'
	--	END AS [IEPStandardComplianceDate]
	,
	t5.[PWNComplianceDate],
	t5.[InActiveSinceDate],
	CASE 
		WHEN t5.[InActiveSinceDate] IS NULL
			THEN 'Y' -- The case satatement was added to flag students who are Active - Prem Boompagh 5/19/2022
		ELSE 'N'
		END AS [IsActive],
	t5.[SchoolYear],
	t5.[PlacementDocStatus],
	t5.[PlacementDocStatusDesc],
	t5.[SLLDocStatus],
	t5.[SLLDocStatusDesc]
	--  ,t5.[DateIEP]
	,
	t5.ProjectedIEPImplementationDate AS [DateIEPImplementedProjected],
	t5.[IniRefUplReceiveDate] --[DateIniRefUplReceive]
	,
	t5.[ProcessStage],
	t5.[ProcessStageDesc],
	t5.[OutcomeReason],
	t5.[OutcomeReasonDesc],
	t5.[DisabilityCode],
	t5.[ClassificationDesc],
	t5.[ReasonForRecommendPlacement],
	t5.[RecommendPlacementDesc],
	CASE 
		WHEN t5.[RecommendPlacementDesc] IS NULL
			THEN 'Awaiting Placement Recommendation'
		WHEN t5.[RecommendPlacementDesc] = 'Board of Cooperative Educational Services'
			THEN 'Board of Cooperative Educational Services'
		WHEN t5.[RecommendPlacementDesc] = 'Charter School'
			THEN 'Charter School'
		WHEN t5.[RecommendPlacementDesc] = 'Day Treatment'
			THEN 'Day Treatment'
		WHEN t5.[RecommendPlacementDesc] = 'Home/Hospital Instruction'
			THEN 'Home/Hospital Instruction'
		WHEN t5.[RecommendPlacementDesc] = 'NYC DOE School Non-Specialized (District 1-32)'
			THEN 'District 1-32'
		WHEN t5.[RecommendPlacementDesc] = 'NYC DOE Specialized School'
			THEN 'D75'
		WHEN t5.[RecommendPlacementDesc] = 'NYC DOE Specialized School co-located in an NYC DOE Community School'
			THEN 'D75 Co-Located'
		WHEN t5.[RecommendPlacementDesc] IN (
				'NYS Supported Non Public School – 4201 - Day',
				'NYS Supported Non Public School – 4201 - Residential'
				)
			THEN 'NYS Supported NPS'
		WHEN t5.[RecommendPlacementDesc] IN (
				'NYSED-Approved Non Public School - Day',
				'NYSED-Approved Non Public School - Placed by ACS',
				'NYSED-Approved Non Public School - Residential'
				)
			THEN 'NYSED-Approved'
		WHEN t5.[RecommendPlacementDesc] = 'Other'
			THEN 'Other'
		WHEN t5.[RecommendPlacementDesc] = 'Student is Parentally Placed in a Non-Public School'
			THEN 'Parentally Placed in NPS'
		ELSE t5.[RecommendPlacementDesc]
		END AS 'RecommendedPlacement',
	t5.[OtherFactors],
	t5.[T5RecordSource],
	t5.[SESISOpenDate],
	t5.[ZonedSchool],
	t5.[CapPreKSchool],
	t5.[SESISEnrollDBN],
	t5.[T5SchoolDBN],
	--,t5.[AssignedSchoolDBN] --Change AssignedSchoolDBN to dynamic per Summer cases
  CASE WHEN CAST(GETDATE() as Date)>=(Select Max(WaveDate) From SEO_MART.dbo.INT_T5WaveSchedule) 
    THEN COALESCE(t5.T5IEPTeam,t5.T5SchoolDBN,cse.CSESchoolDBN) 
    END AssignedSchoolDBN,
	t5.[WaveAssignedSchoolDBN]
	--  ,t5.[ATSPrekSchoolDBN]
	,
	t5.[D75AdminDBN],
	t5.[D75PhysicalDBN],
	t5.[CurrentAddAdminDBN],
	t5.[SchoolType],
	t5.[T5IEPTeamDesc],
	t5.[T5IEPTeamType],
	t5.[SupsOfPsychName],
	t5.[T5CaseLoad],
	t5.[CSE]
	-- ,t5.[AddLocAdmin]
	,
	t5.[EnrollPhyical],
	t5.[AddLocationPhysical],
	t5.[ReceivingAdmin],
	t5.[ReceivingPhysical],
	t5.[FSCLeaderName],
	t5.[FSCName],
	t5.[FSCReportingName],
	t5.[Superintendent],
	t5.[AdminDistrict],
	t5.[CaseType],
	CASE 
		WHEN t5.[CaseType] = 'T5 RE-EVAL'
			THEN 'Reevaluation'
		WHEN t5.[CaseType] = 'T5 INITIAL'
			THEN 'Initial'
		ELSE t5.[CaseType]
		END AS ReferralType,
	t5.[ReassignmentDate],
	t5.AccessibleProgramFlag --[IsAccessibleProgram]
	,
	t5.[ELLStatus],
	t5.[Gender],
	t5.[Ethnicity]
	--,CASE 
	--	WHEN t5.Ethnicity IN (
	--			'Asian'
	--			,'Native Hawaiian or Other Pacific Islander'
	--			,'ASIAN OR PACIFIC ISLANDER'
	--			)
	--		THEN 'Asian'
	--	WHEN t5.Ethnicity IN (
	--			'Black'
	--			,'BLACK - NOT OF HISPANIC ORIGIN'
	--			,'BLACK'
	--			)
	--		THEN 'Black'
	--	WHEN t5.Ethnicity IN (
	--			'WHITE - NOT OF HISPANIC ORIGIN'
	--			,'White'
	--			)
	--		THEN 'White'
	--	WHEN t5.Ethnicity IN (
	--			'Hispanic'
	--			,'HISPANIC'
	--			)
	--		THEN 'Hispanic'
	--	WHEN t5.Ethnicity IN (
	--			'Multi-Racial'
	--			,'American Indian or Alaskan Native'
	--			,'Unknown'
	--			,'Parent Refused to Sign'
	--			,'UNDETERMINED'
	--			)
	--		THEN 'Other'
	--	WHEN t5.Ethnicity IS NULL
	--		THEN 'Other'
	--	ELSE t5.Ethnicity
	--	END AS EthnicityCC
	,
	eth.CCGrouping AS EthnicityCC,
	t5.[HomeDistrict],
	t5.[HouseNumber],
	t5.[Street],
	t5.[BoroCode],
	t5.[ZipCode],
	t5.[ApartmentNumber],
	t5.[CityName],
	t5.[GuardianFirstName],
	t5.[GuardianLastName],
	t5.[GuardianPhoneNumber]
	--,t5.[GuardianLanguage]
	--,t5.[GuardianLanguageDesc]
	--,t5.[HadFinalPlanFL]
	--,t5.[HadFinalIEPFL]
	--,t5.[HadFinalIESPFL]
	,
	t5.ESYFlag --[ESY]
	,
	t5.ESYSameServiceFlag --[ESYSameService]
	,
	t5.[T5SESISStatus],
	t5.[T5SESISStatusCode],
	t5.[T5SESISStatusGrouping],
	t5.[T5SESISStatusCodeGrouping],
	t5.[T5SESISStatusCodeDashboard],
	t5.[T5SESISStatusDashboard],
	t5.[ReportStatus],
	t5.[Notice]
	-- ,t5.[CAPRefDate]
	,
	t5.[DHSDVFlag],
	CASE 
		WHEN t5.[DHSDVFlag] ='DHS'--IS NOT NULL
			THEN 'Y'
		WHEN t5.[DHSDVFlag] IS NULL
			THEN 'N'
		END AS TemporaryHousingStatus,
	t5.[ReferralSchool],
	t5.[CurrentCAPServiceSchool],
	t5.[ServiceSchoolName],
	t5.[AssessmentBilLangCode]
	--,lc.[Description] as 'LanguageDescription'
	--,lc.[CCGrouping] as 'LanguageDescriptionGrouping'
	/*,t5.[IsBilingual]
	,CASE 
		WHEN t5.[IsBilingual] = 1
			THEN 'Y'
		ELSE 'N'
		END [Requires Bilingual Psych]    */ -----ARCH needed
	,
	LCode.CCGrouping AS 'LanguageDescriptionGrouping'
	--,t5.[CCDate]
	,
	t5.[CaseCloseReasonCode] --[CCReasonCode]
	,
	t5.[CaseCloseDesc] --[CCDesc]
	--,t5.[EvalComplianceDate]
	--,t5.[PlacementComplianceDate]
	--,t5.[CAPDischargeDate]
	,
	t5.[CAPDischargeCode]
	--,t5.[IEPConfDate]
	,
	t5.[RecommendedProgram] AS [RecmProgram],
	t5.[EvaluationDesc] AS [EvalDesc],
	t5.[EvaluationType] AS [EvalType],
	t5.[DualRecmInd],
	t5.[RecommServiceCategory] --[RecmServiceCategory]
	,
	t5.[CloseCode],
	t5.[SEITSessionPerWeek],
	t5.[RecommendedRS]
	--,t5.[AuthDate]
	--,t5.[FirstAttendDate]
	--,t5.[FinalNoticeDate]
	--,t5.[FinalNoticeConsentDate]
	,
	t5.OutcomeCreatedDate AS [OutcomeCreatedOn],
	t5.OutcomeFinalizedDate AS [OutcomeFinalizedOn],
	t5.PlacementCreatedDate AS [PlacementCreatedOn],
	t5.PlacementFinalizedDate AS [PlacementFinalizedOn],
	t5.SLLCreatedDate AS [SLLCreatedOn],
	t5.SLLFinalizedDate AS [SLLFinalizedOn],
	t5.[LinkageBucket]
	--,t5.[WaveProcessedDate]
	--,[ReportFlag]
	,
	CASE 
		WHEN t5.OutcomeTypeDesc IN (
				'IEP',
				'IESP'
				)
			THEN t5.PlacementFinalizedDate
		WHEN t5.OutcomeTypeDesc IN (
				'Ineligible',
				'Declass',
				'Caseclose',
				'Discharge'
				)
			THEN t5.OutcomeFinalizedDate
		END AS FinalizedDate,
	DATEDIFF(day, t5.[ProcessedDate], t5.IEPComplianceDate) AS 'Date Diff',
	t5.[ProcessedDate]
	/* Thomas Giresi - The following logic was added to this view on 11/27/2019 to provide monthly case distributions for the 'New T5 Year to Date' report */
	,
	CASE 
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
		END AS MonthlyCaseDistribution,
	CASE 
		WHEN t5.ClassificationDesc IN (
				'Multiple Disabilities',
				'Emotional Disability',
				'Autism',
				'Other Health Impairment',
				'Intellectual Disability',
				'Speech or Language Impairment',
				'Learning Disability'
				)
			THEN t5.ClassificationDesc
		ELSE 'Other'
		END AS ClassificationGroup,
	t5.[ClassificationDesc] AS Classification
	--  ,ss.ProgramTypeMRE
	,
	CASE 
		WHEN ss.ProgramTypeMRE = 'Integrated Co-Teaching Services'
			THEN 'ICT'
		WHEN ss.ProgramTypeMRE = 'Special Class'
			THEN 'Special Class'
		WHEN ss.ProgramTypeMRE = 'Special Education Teacher Support Services (SETSS)'
			THEN 'SETSS'
		WHEN ss.ProgramTypeMRE = 'RS Only'
			THEN 'RS Only'
		WHEN ss.ProgramTypeMRE = 'Other Program'
			THEN 'Other'
		WHEN ss.ProgramTypeMRE IS NULL
			THEN 'Awaiting'
		ELSE ss.ProgramTypeMRE
		END AS ProgramTypeMRE,
	ProgramTypeMRERatio,
	DIEP.DateIEP,
	CASE 
		WHEN t5.T5SESISStatusDashboard = 'Complete'
			THEN 'Complete'
		ELSE 'Open'
		END AS CaseStatus,
	'End of School Year' AS [Data Thru],
	CASE WHEN t5.WaveProcessedDate is null
		THEN 'N' ELSE 'Y' END AS WaveAssignedFlag,
	 CASE WHEN t5.WaveProcessedDate is null 
	THEN 'Walk-In' ELSE CONCAT('Wave ',reg.WaveID) 
	END AS AssignmentProcess --2/2/26 Added for filter; WaveID is not in RPT_T5RL
FROM [SEO_MART].[arch].[RPT_T5ReferralLinkage_MultiSY] AS t5 WITH(NOLOCK)
/*Charlotte: add cross join*/
CROSS JOIN (
    SELECT
        CAST(YEAR(DATEADD(month,-6,GETDATE())) - 1 AS varchar(4))
        + '-'
        + CAST(YEAR(DATEADD(month,-6,GETDATE()))     AS varchar(4)) AS T5SchoolYear,
        (YEAR(DATEADD(month,-6,GETDATE())) - 1) - 4 AS T5BirthYear
) br
LEFT JOIN SEO_MART.dbo.INT_ServicesSummary AS ss  WITH(NOLOCK)
	ON t5.OutcomeDocumentIDT = ss.OutcomeDocumentIDT
---------------CSE---------
LEFT JOIN 
        (SELECT 
          CSESchoolDBN           
          ,CSEDistrict
        FROM SEO_MART.dbo.lk_CSECapacity with(nolock) 
        )cse
        ON t5.CSE=cse.CSEDistrict
LEFT JOIN (
	SELECT StudentID,
		MIN(OutcomeDate) AS FirstOutcomeDate,
		MIN(DocumentIDT) AS DocumentIDT
	--,ROW_NUMBER() OVER (
	--	PARTITION BY StudentID ORDER BY OutcomeDate ASC
	--	) AS Rank
	FROM seo_mart.dbo.DWH_Outcome OC  WITH(NOLOCK)
	WHERE OC.Deleted = 0
		AND OC.DocStatus = 3
		AND OC.IsDelete = 0
		AND OC.Outcometypecode IN (
			1,
			2,
			3,
			5,
			6,
			7,
			8
			)
	GROUP BY StudentID
	) od
	ON od.StudentID = t5.StudentID
LEFT JOIN (
	SELECT DateIEP,
		StudentID,
		IEPComplianceDate
	FROM (
		SELECT Row_Number() OVER (
				PARTITION BY RL.StudentID ORDER BY DO.DocumentIDT
				) TRank,
			RL.IEPComplianceDate,
			DO.*
		FROM SEO_MART.dbo.RPT_T5ReferralLinkage RL WITH (NOLOCK) --DateIEP, T5SESISStatusDashboard,
		LEFT JOIN SEO_MART.dbo.DWH_Outcome DO WITH (NOLOCK)
			ON RL.StudentID = DO.StudentID
				AND Deleted = 0
				AND DocStatus IN (
					1,
					2
					)
				AND IsDelete = 0
		) G
	WHERE TRank = 1
	) DIEP
	ON t5.StudentID = DIEP.StudentID --Added the DateIEP from DWH_Outcome by Prem.B
LEFT JOIN (
	SELECT Code,
		Description,
		CCGrouping
	FROM (
		SELECT lc.SourceName,
			lc.Code,
			lc.Description,
			lc.CCGrouping
		FROM SEO_MART.[dbo].[lk_LanguageCodes] lc  WITH(NOLOCK)
		) X
	WHERE SourceName = 'CAP'
	) LCode
	ON t5.AssessmentBilLangCode = LCode.Code
LEFT JOIN (
	SELECT DISTINCT CCGrouping,
		Description
	FROM SEO_MART.dbo.lk_EthnicityCodes	 WITH(NOLOCK)
	) eth
	ON t5.Ethnicity = eth.Description
LEFT JOIN SEO_MART.dbo.lk_T5ReferralComplianceDate rcd
	ON t5.IEPComplianceDate = rcd.ComplianceDate
		AND rcd.ComplianceCategory = 'IEP'
LEFT JOIN 
		(SELECT DISTINCT StudentID, WaveID
		FROM SEO_MART.arch.RPT_T5StudentRegister_MultiSY reg WITH(NOLOCK)
		INNER JOIN
			(
			SELECT SchoolYear, MAX(ProcessedDate) AS MaxProcessedDate
			FROM [SEO_MART].[arch].RPT_T5StudentRegister_MultiSY WITH(NOLOCK)
			 GROUP BY SchoolYear
			) pdate
				 ON reg.SchoolYear = pdate.SchoolYear
				 AND reg.ProcessedDate = pdate.MaxProcessedDate
		)reg --2/2/26 Adding because ReferralLinkage does not have WaveID
		ON t5.StudentID=reg.StudentID
/*Charlotte: remove this hard-coded schoolyear join*/
--INNER JOIN (
--	SELECT LookupValue
--	--FROM #T5Rule
--	FROM SEO_MART.dbo.lk_SEOBusinessRules  WITH(NOLOCK)
--	WHERE LookupName = 'T5SchoolYear'
--		AND LookupCategory = 'T5Dashboard'
--		AND IsActive = 1
--		AND ReturnValue = 2
--	) rul
--	ON t5.SchoolYear = rul.LookupValue
/*Charlotte: remove this hard-coded FinalProcessedDate join*/
--LEFT JOIN (
--	SELECT LookupValue,
--		SchoolYear
--	--FROM #T5Rule
--	FROM SEO_MART.dbo.lk_SEOBusinessRules WITH(NOLOCK)
--	WHERE LookupName = 'T5FinalProcessedDate'
--		AND LookupCategory = 'T5Dashboard'
--		AND IsActive = 1
--		AND ReturnValue IN (
--			2,
--			3
--			)
--	) rul2
--	ON t5.SchoolYear = rul2.SchoolYear
--WHERE t5.ProcessedDate = rul2.LookupValue
/*Charlotte: REPLACE with a deterministic “latest ProcessedDate per SchoolYear” derived table*/
INNER JOIN (
    SELECT SchoolYear, MAX(ProcessedDate) AS MaxProcessedDate
    FROM [SEO_MART].[arch].[RPT_T5ReferralLinkage_MultiSY] WITH(NOLOCK)
    GROUP BY SchoolYear
) pdate
    ON t5.SchoolYear = pdate.SchoolYear
   AND t5.ProcessedDate = pdate.MaxProcessedDate
 /*Charlotte: Add with below condition */
WHERE t5.SchoolYear = br.T5SchoolYear
--INNER JOIN (
--	SELECT SchoolYear,
--		MAX(ProcessedDate) mdate
--	FROM [SEO_MART].[arch].[RPT_T5ReferralLinkage_MultiSY]
--	GROUP BY SchoolYear
--	) Pdate
--	ON t5.ProcessedDate = Pdate.mdate
--		AND Pdate.SchoolYear = t5.SchoolYear

UNION

SELECT distinct t5.[StudentID],
	t5.[FirstName],
	t5.[LastName],
	t5.[BirthDate],
	COALESCE(t5.T5IEPTeam,t5.T5SchoolDBN,cse.CSESchoolDBN) AS 'School DBN', --added as per Lauren to show walkins to cse users.
	t5.[IsTurning5],
	t5.[ConsentDocumentIDT],
	t5.[OutcomeDocumentIDT],
	t5.[OutcomeTypeCode],
	t5.[OutcomeTypeDesc],
	t5.[OutcomeDocStatus],
	t5.[OutcomeDocStatusDesc],
	t5.[PlacementDocumentIDT],
	t5.[PlacementTypeCode],
	t5.[PlacementTypeDesc],
	t5.[SLLDocumentIDT],
	t5.[SLLTypeCode],
	t5.[SLLTypeDesc],
	t5.[ReferralDate],
	t5.[ConsentDate],
	t5.[SocialHistoryAssessDate],
	t5.[PhysicalExamAssessDate],
	t5.[ClassroomOBSAssessDate],
	t5.[PsychoEDAssessDate],
	t5.[IEPNoticeDate],
	t5.[T5IEPNoticeDate],
	t5.[OutcomeDate],
	MONTH(t5.[OutcomeDate]) [Outcome Month],
	DATENAME(MONTH, t5.[OutcomeDate]) [Outcome Month Name],
	od.FirstOutcomeDate,
	CASE 
		WHEN od.FirstOutcomeDate <= t5.IEPComplianceDate
			AND t5.T5SESISStatusDashboard IN (
				'Complete',
				'Finalize PNP'
				)
			THEN 1
		ELSE 0
		END AS T5IEPTimeliness,
	DocumentIDT AS 'FirstOutcomeDocumentIDT',
	t5.[PlacementDate],
	t5.[ConsentProvisionServiceDate] --[ConsentProvisionService]
	,
	t5.[LocationLetterDate],
	t5.[IEPComplianceDate],
	COALESCE(rcd.ComplianceDateDesc, 'Non-Standard Compliance Date') AS [IEPStandardComplianceDate]
	--,case when t5.[IEPComplianceDate] = '2024-06-03' then 'Monday, June 03, 2024' --2023
	--     when t5.[IEPComplianceDate] = '2024-07-04' then 'Thursday, July 04, 2024'  --2023 
	--     when t5.[IEPComplianceDate] = '2024-08-05' then 'Monday, August 05, 2024'  --2023
	--	ELSE 'Non-Standard Compliance Date'
	--	END AS [IEPStandardComplianceDate]
	,
	t5.[PWNComplianceDate],
	t5.[InActiveSinceDate],
	CASE 
		WHEN t5.[InActiveSinceDate] IS NULL
			THEN 'Y' -- The case satatement was added to flag students who are Active - Prem Boompagh 5/19/2022
		ELSE 'N'
		END AS [IsActive],
	t5.[SchoolYear],
	t5.[PlacementDocStatus],
	t5.[PlacementDocStatusDesc],
	t5.[SLLDocStatus],
	t5.[SLLDocStatusDesc]
	--  ,t5.[DateIEP]
	,
	t5.ProjectedIEPImplementationDate AS [DateIEPImplementedProjected],
	t5.[IniRefUplReceiveDate] --[DateIniRefUplReceive]
	,
	t5.[ProcessStage],
	t5.[ProcessStageDesc],
	t5.[OutcomeReason],
	t5.[OutcomeReasonDesc],
	t5.[DisabilityCode],
	t5.[ClassificationDesc],
	t5.[ReasonForRecommendPlacement],
	t5.[RecommendPlacementDesc],
	CASE 
		WHEN t5.[RecommendPlacementDesc] IS NULL
			THEN 'Awaiting Placement Recommendation'
		WHEN t5.[RecommendPlacementDesc] = 'Board of Cooperative Educational Services'
			THEN 'Board of Cooperative Educational Services'
		WHEN t5.[RecommendPlacementDesc] = 'Charter School'
			THEN 'Charter School'
		WHEN t5.[RecommendPlacementDesc] = 'Day Treatment'
			THEN 'Day Treatment'
		WHEN t5.[RecommendPlacementDesc] = 'Home/Hospital Instruction'
			THEN 'Home/Hospital Instruction'
		WHEN t5.[RecommendPlacementDesc] = 'NYC DOE School Non-Specialized (District 1-32)'
			THEN 'District 1-32'
		WHEN t5.[RecommendPlacementDesc] = 'NYC DOE Specialized School'
			THEN 'D75'
		WHEN t5.[RecommendPlacementDesc] = 'NYC DOE Specialized School co-located in an NYC DOE Community School'
			THEN 'D75 Co-Located'
		WHEN t5.[RecommendPlacementDesc] IN (
				'NYS Supported Non Public School – 4201 - Day',
				'NYS Supported Non Public School – 4201 - Residential'
				)
			THEN 'NYS Supported NPS'
		WHEN t5.[RecommendPlacementDesc] IN (
				'NYSED-Approved Non Public School - Day',
				'NYSED-Approved Non Public School - Placed by ACS',
				'NYSED-Approved Non Public School - Residential'
				)
			THEN 'NYSED-Approved'
		WHEN t5.[RecommendPlacementDesc] = 'Other'
			THEN 'Other'
		WHEN t5.[RecommendPlacementDesc] = 'Student is Parentally Placed in a Non-Public School'
			THEN 'Parentally Placed in NPS'
		ELSE t5.[RecommendPlacementDesc]
		END AS 'RecommendedPlacement',
	t5.[OtherFactors],
	t5.[T5RecordSource],
	t5.[SESISOpenDate],
	t5.[ZonedSchool],
	t5.[CapPreKSchool],
	t5.[SESISEnrollDBN],
	t5.[T5SchoolDBN],
	--,t5.[AssignedSchoolDBN] --Change AssignedSchoolDBN to dynamic per Summer cases
  CASE WHEN CAST(GETDATE() as Date)>=(Select Max(WaveDate) From SEO_MART.dbo.INT_T5WaveSchedule) 
    THEN COALESCE(t5.T5IEPTeam,t5.T5SchoolDBN,cse.CSESchoolDBN) 
    END AssignedSchoolDBN,
	t5.[WaveAssignedSchoolDBN]
	--  ,t5.[ATSPrekSchoolDBN]
	,
	t5.[D75AdminDBN],
	t5.[D75PhysicalDBN],
	t5.[CurrentAddAdminDBN],
	t5.[SchoolType],
	t5.[T5IEPTeamDesc],
	t5.[T5IEPTeamType],
	t5.[SupsOfPsychName],
	t5.[T5CaseLoad],
	t5.[CSE]
	-- ,t5.[AddLocAdmin]
	,
	t5.[EnrollPhyical],
	t5.[AddLocationPhysical],
	t5.[ReceivingAdmin],
	t5.[ReceivingPhysical],
	t5.[FSCLeaderName],
	t5.[FSCName],
	t5.[FSCReportingName],
	t5.[Superintendent],
	t5.[AdminDistrict],
	t5.[CaseType],
	CASE 
		WHEN t5.[CaseType] = 'T5 RE-EVAL'
			THEN 'Reevaluation'
		WHEN t5.[CaseType] = 'T5 INITIAL'
			THEN 'Initial'
		ELSE t5.[CaseType]
		END AS ReferralType,
	t5.[ReassignmentDate],
	t5.AccessibleProgramFlag --[IsAccessibleProgram]
	,
	t5.[ELLStatus],
	t5.[Gender],
	t5.[Ethnicity]
	--,CASE 
	--	WHEN t5.Ethnicity IN (
	--			'Asian'
	--			,'Native Hawaiian or Other Pacific Islander'
	--			,'ASIAN OR PACIFIC ISLANDER'
	--			)
	--		THEN 'Asian'
	--	WHEN t5.Ethnicity IN (
	--			'Black'
	--			,'BLACK - NOT OF HISPANIC ORIGIN'
	--			,'BLACK'
	--			)
	--		THEN 'Black'
	--	WHEN t5.Ethnicity IN (
	--			'WHITE - NOT OF HISPANIC ORIGIN'
	--			,'White'
	--			)
	--		THEN 'White'
	--	WHEN t5.Ethnicity IN (
	--			'Hispanic'
	--			,'HISPANIC'
	--			)
	--		THEN 'Hispanic'
	--	WHEN t5.Ethnicity IN (
	--			'Multi-Racial'
	--			,'American Indian or Alaskan Native'
	--			,'Unknown'
	--			,'Parent Refused to Sign'
	--			,'UNDETERMINED'
	--			)
	--		THEN 'Other'
	--	WHEN t5.Ethnicity IS NULL
	--		THEN 'Other'
	--	ELSE t5.Ethnicity
	--	END AS EthnicityCC
	,
	eth.CCGrouping AS EthnicityCC,
	t5.[HomeDistrict],
	t5.[HouseNumber],
	t5.[Street],
	t5.[BoroCode],
	t5.[ZipCode],
	t5.[ApartmentNumber],
	t5.[CityName],
	t5.[GuardianFirstName],
	t5.[GuardianLastName],
	t5.[GuardianPhoneNumber]
	--,t5.[GuardianLanguage]
	--,t5.[GuardianLanguageDesc]
	--,t5.[HadFinalPlanFL]
	--,t5.[HadFinalIEPFL]
	--,t5.[HadFinalIESPFL]
	,
	t5.ESYFlag --[ESY]
	,
	t5.ESYSameServiceFlag --[ESYSameService]
	,
	t5.[T5SESISStatus],
	t5.[T5SESISStatusCode],
	t5.[T5SESISStatusGrouping],
	t5.[T5SESISStatusCodeGrouping],
	t5.[T5SESISStatusCodeDashboard],
	t5.[T5SESISStatusDashboard],
	t5.[ReportStatus],
	t5.[Notice]
	-- ,t5.[CAPRefDate]
	,
	t5.[DHSDVFlag],
	CASE 
		WHEN t5.[DHSDVFlag] IS NOT NULL
			THEN 'Y'
		WHEN t5.[DHSDVFlag] IS NULL
			THEN 'N'
		END AS TemporaryHousingStatus,
	t5.[ReferralSchool],
	t5.[CurrentCAPServiceSchool],
	t5.[ServiceSchoolName],
	t5.[AssessmentBilLangCode]
	--,lc.[Description] as 'LanguageDescription'
	--,lc.[CCGrouping] as 'LanguageDescriptionGrouping'
	/*,t5.[IsBilingual]
	,CASE 
		WHEN t5.[IsBilingual] = 1
			THEN 'Y'
		ELSE 'N'
		END [Requires Bilingual Psych]  */
	,
	LCode.CCGrouping AS 'LanguageDescriptionGrouping'
	--,t5.[CCDate]
	,
	t5.[CaseCloseReasonCode] --[CCReasonCode]
	,
	t5.[CaseCloseDesc] --[CCDesc]
	--,t5.[EvalComplianceDate]
	--,t5.[PlacementComplianceDate]
	--,t5.[CAPDischargeDate]
	,
	t5.[CAPDischargeCode]
	--,t5.[IEPConfDate]
	,
	t5.[RecommendedProgram] AS [RecmProgram],
	t5.[EvaluationDesc] AS [EvalDesc],
	t5.[EvaluationType] AS [EvalType],
	t5.[DualRecmInd],
	t5.[RecommServiceCategory] --[RecmServiceCategory]
	,
	t5.[CloseCode],
	t5.[SEITSessionPerWeek],
	t5.[RecommendedRS]
	--,t5.[AuthDate]
	--,t5.[FirstAttendDate]
	--,t5.[FinalNoticeDate]
	--,t5.[FinalNoticeConsentDate]
	,
	t5.OutcomeCreatedDate AS [OutcomeCreatedOn],
	t5.OutcomeFinalizedDate AS [OutcomeFinalizedOn],
	t5.PlacementCreatedDate AS [PlacementCreatedOn],
	t5.PlacementFinalizedDate AS [PlacementFinalizedOn],
	t5.SLLCreatedDate AS [SLLCreatedOn],
	t5.SLLFinalizedDate AS [SLLFinalizedOn],
	t5.[LinkageBucket]
	--,t5.[WaveProcessedDate]
	--,[ReportFlag]
	,
	CASE 
		WHEN t5.OutcomeTypeDesc IN (
				'IEP',
				'IESP'
				)
			THEN t5.PlacementFinalizedDate
		WHEN t5.OutcomeTypeDesc IN (
				'Ineligible',
				'Declass',
				'Caseclose',
				'Discharge'
				)
			THEN t5.OutcomeFinalizedDate
		END AS FinalizedDate,
	DATEDIFF(day, t5.[ProcessedDate], t5.IEPComplianceDate) AS 'Date Diff',
	t5.[ProcessedDate]
	/* Thomas Giresi - The following logic was added to this view on 11/27/2019 to provide monthly case distributions for the 'New T5 Year to Date' report */
	,
	CASE 
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
		END AS MonthlyCaseDistribution,
	CASE 
		WHEN t5.ClassificationDesc IN (
				'Multiple Disabilities',
				'Emotional Disability',
				'Autism',
				'Other Health Impairment',
				'Intellectual Disability',
				'Speech or Language Impairment',
				'Learning Disability'
				)
			THEN t5.ClassificationDesc
		ELSE 'Other'
		END AS ClassificationGroup,
	t5.[ClassificationDesc] AS Classification
	--  ,ss.ProgramTypeMRE
	,
	CASE 
		WHEN ss.ProgramTypeMRE = 'Integrated Co-Teaching Services'
			THEN 'ICT'
		WHEN ss.ProgramTypeMRE = 'Special Class'
			THEN 'Special Class'
		WHEN ss.ProgramTypeMRE = 'Special Education Teacher Support Services (SETSS)'
			THEN 'SETSS'
		WHEN ss.ProgramTypeMRE = 'RS Only'
			THEN 'RS Only'
		WHEN ss.ProgramTypeMRE = 'Other Program'
			THEN 'Other'
		WHEN ss.ProgramTypeMRE IS NULL
			THEN 'Awaiting'
		ELSE ss.ProgramTypeMRE
		END AS ProgramTypeMRE,
	ProgramTypeMRERatio,
	DIEP.DateIEP,
	CASE 
		WHEN t5.T5SESISStatusDashboard = 'Complete'
			THEN 'Complete'
		ELSE 'Open'
		END AS CaseStatus,
	CONCAT (
		'First ',
		(
			select max(SchoolDays) from [SEO_REPORTING].[BI].[vw_T5Dashboard_YOYReferralsSchoolDays] WITH(NOLOCK)
			),
		' Days of School'
		) AS [Data Thru],
	CASE WHEN t5.WaveProcessedDate is null
		THEN 'N' ELSE 'Y' END AS WaveAssignedFlag,
	CASE WHEN t5.WaveProcessedDate is null 
	THEN 'Walk-In' ELSE CONCAT('Wave ',reg.WaveID) 
	END AS AssignmentProcess --2/2/26 Added for filter; WaveID is not in RPT_T5RL
FROM [SEO_MART].[dbo].[RPT_T5ReferralLinkage] AS t5	  WITH(NOLOCK)
/*Charlotte: add cross join*/
CROSS JOIN (
    SELECT
        CAST(YEAR(DATEADD(month,-6,GETDATE())) AS varchar(4))
        + '-'
        + CAST(YEAR(DATEADD(month, 6,GETDATE())) AS varchar(4)) AS T5SchoolYear,
        YEAR(DATEADD(month,-6,GETDATE())) - 4 AS T5BirthYear
) br
LEFT JOIN SEO_MART.dbo.INT_ServicesSummary AS ss
	ON t5.OutcomeDocumentIDT = ss.OutcomeDocumentIDT
---------------CSE---------
LEFT JOIN 
        (SELECT 
          CSESchoolDBN           
          ,CSEDistrict
        FROM SEO_MART.dbo.lk_CSECapacity with(nolock) 
        )cse
        ON t5.CSE=cse.CSEDistrict
LEFT JOIN (
	SELECT StudentID,
		MIN(OutcomeDate) AS FirstOutcomeDate,
		MIN(DocumentIDT) AS DocumentIDT
	--,ROW_NUMBER() OVER (
	--	PARTITION BY StudentID ORDER BY OutcomeDate ASC
	--	) AS Rank
	FROM seo_mart.dbo.DWH_Outcome OC   WITH(NOLOCK)
	WHERE OC.Deleted = 0
		AND OC.DocStatus = 3
		AND OC.IsDelete = 0
		AND OC.Outcometypecode IN (
			1,
			2,
			3,
			5,
			6,
			7,
			8
			)
	GROUP BY StudentID
	) od
	ON od.StudentID = t5.StudentID
LEFT JOIN (
	SELECT DateIEP,
		StudentID,
		IEPComplianceDate
	FROM (
		SELECT Row_Number() OVER (
				PARTITION BY RL.StudentID ORDER BY DO.DocumentIDT
				) TRank,
			RL.IEPComplianceDate,
			DO.*
		FROM SEO_MART.dbo.RPT_T5ReferralLinkage RL WITH (NOLOCK) --DateIEP, T5SESISStatusDashboard,
		LEFT JOIN SEO_MART.dbo.DWH_Outcome DO WITH (NOLOCK)
			ON RL.StudentID = DO.StudentID
				AND Deleted = 0
				AND DocStatus IN (
					1,
					2
					)
				AND IsDelete = 0
		) G
	WHERE TRank = 1
	) DIEP
	ON t5.StudentID = DIEP.StudentID --Added the DateIEP from DWH_Outcome by Prem.B
LEFT JOIN (
	SELECT Code,
		Description,
		CCGrouping
	FROM (
		SELECT lc.SourceName,
			lc.Code,
			lc.Description,
			lc.CCGrouping
		FROM SEO_MART.[dbo].[lk_LanguageCodes] lc WITH(NOLOCK)
		) X
	WHERE SourceName = 'CAP'
	) LCode
	ON t5.AssessmentBilLangCode = LCode.Code
LEFT JOIN (
	SELECT DISTINCT CCGrouping,
		Description
	FROM SEO_MART.dbo.lk_EthnicityCodes WITH(NOLOCK)
	) eth
	ON t5.Ethnicity = eth.Description
LEFT JOIN SEO_MART.dbo.lk_T5ReferralComplianceDate rcd WITH(NOLOCK)
	ON t5.IEPComplianceDate = rcd.ComplianceDate
		AND rcd.ComplianceCategory = 'IEP'
LEFT JOIN 
		(SELECT StudentID, WaveID
		FROM SEO_MART.dbo.RPT_T5StudentRegister WITH(NOLOCK)
		)reg --2/2/26 Adding because ReferralLinkage does not have WaveID
		ON t5.StudentID=reg.StudentID
/*Charlotte: remove this hard-coded schoolyear join*/
--INNER JOIN (
--	SELECT LookupValue
--	--FROM #T5Rule
--	FROM SEO_MART.dbo.lk_SEOBusinessRules	WITH(NOLOCK)
--	WHERE LookupName = 'T5SchoolYear'
--		AND LookupCategory = 'T5Dashboard'
--		AND IsActive = 1
--		AND ReturnValue = 1
--	) rul
--	ON t5.SchoolYear = rul.LookupValue
		--INNER JOIN (
		--	SELECT LookupValue
		--	FROM SEO_MART.dbo.lk_SEOBusinessRules
		--	WHERE LookupName = 'T5SchoolYear'
		--	) rul
		--	ON t5.SchoolYear = rul.LookupValue
		--WHERE t5.SchoolYear = rul.LookupValue
/*Charlotte: Add with below condition */
WHERE t5.SchoolYear = br.T5SchoolYear


GO


