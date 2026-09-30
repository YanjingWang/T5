USE [SEO_REPORTING]
GO

/****** Object:  View [BI].[vw_T5Dashboard_ReferralsLinkage_SYxxLatest]    Script Date: 4/6/2026 1:43:03 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



















CREATE VIEW [BI].[vw_T5Dashboard_ReferralsLinkage_SYxxLatest]

/****************************************************************************************************************************************************************************************************************
Object Name: [SEO_REPORTING].[BI].[vw_T5Dashboard_ReferralsLinkage_SYxxLatest]

Sample call: select ProcessedDate, COUNT(*) from BI.vw_T5Dashboard_ReferralsLinkage_SYxxLatest GROUP BY ProcessedDate

Purpose: Latest Outcomes made based on the Compliance Date and finalized with the IEP and PWN compliance in the 60 days for last 3 years.

Date Created: 09/09/2024

ModificatiON Details: INITIAL

Author		       ModifiedDate		Comments
Prem B                10/09/2024       INITIAL
Ariel H				  06/11/2025	   Update WaveAssignedFlag case statement
Charlotte Wang        12/17/2025       Dynamic Rollover
Charlotte Wang        12/22/2025       Hard coded SY23-24 Last ProcessedDate 2024-09-09 instead of 2024-09-17
Charlotte Wang        12/23/2025       Add para and AT fields
Ariel H               12/23/2025       Moved SY24 condition up to recursive so script remains dynamic YOY
Ariel H			      02/02/2026	  AssignmentProcess added to clearly distinguish between Wave Assigned, Walk-Ins, and Ineligible students
Ariel H			      03/09/2026		   TemporaryHousingStatus was written incorrectly. Instead of not NULl changed to 'DHS'
***************************************************************************************************************************************************************************************************************/
AS

WITH
Params AS
(
    SELECT
        CAST(YEAR(DATEADD(MONTH, -6, GETDATE())) AS varchar(4)) + '-' + CAST(YEAR(DATEADD(MONTH,  6, GETDATE())) AS varchar(4)) AS CurSY,
        CAST(YEAR(DATEADD(MONTH, -6, GETDATE()))-1 AS varchar(4)) + '-' + CAST(YEAR(DATEADD(MONTH,  6, GETDATE()))-1 AS varchar(4)) AS PrevSY,
        CAST(YEAR(DATEADD(MONTH, -6, GETDATE()))-2 AS varchar(4)) + '-' + CAST(YEAR(DATEADD(MONTH,  6, GETDATE()))-2 AS varchar(4)) AS Prev2SY
),
LastProcessed AS
(
    SELECT
        ms.SchoolYear,
        CASE WHEN SchoolYear = '2023-2024' THEN CONVERT(date, '2024-09-09')  --Hardcode for SY24: DM should have stopped job on the date we finally punblished the dashboard, for SY24 max processeddate should be 2024-09-09 instead of 2024-09-17
        ELSE MAX(TRY_CONVERT(date, ms.ProcessedDate)) 
        END AS LastProcessedDate
    FROM SEO_MART.[arch].[RPT_T5ReferralLinkage_MultiSY] ms WITH (NOLOCK)
    GROUP BY ms.SchoolYear
),
          /*
        --2024-09-09	SY2023-2024 
        --SELECT MAX(ProcessedDate) FROM arch.RPT_T5ReferralLinkage_MultiSY 
        --2025-08-25    SY2024-2025 correct
        --DM should have stopped job on the date we finally punblished the dashboard, for 2024-09-09	SY2023-2024 instead of 2024-09-17

        SELECT T5SESISStatus,count(*) FROM [SEO_REPORTING].[BI].[vw_T5Dashboard_ReferralsLinkage_SYxxLatest] WHERE ProcessedDate = '2024-09-17'  GROUP BY T5SESISStatus ORDER BY  T5SESISStatus
        SELECT T5SESISStatus,count(*) FROM [SEO_REPORTING].[tempbackup].[vw_T5Dashboard_ReferralsLinkage_SYxxLatest_20251218_RemovePostSY25RolloverQC] WHERE ProcessedDate = '2024-09-09' GROUP BY T5SESISStatus ORDER BY  T5SESISStatus

        SELECT ProcessedDate,count(*) FROM [SEO_REPORTING].[BI].[vw_T5Dashboard_ReferralsLinkage_SYxxLatest] GROUP BY ProcessedDate ORDER BY ProcessedDate
        SELECT ProcessedDate,count(*) FROM [SEO_REPORTING].[tempbackup].[vw_T5Dashboard_ReferralsLinkage_SYxxLatest_20251218_RemovePostSY25RolloverQC] GROUP BY ProcessedDate ORDER BY ProcessedDate
        */

LCode AS
(
    SELECT Code, CCGrouping
    FROM SEO_MART.dbo.lk_LanguageCodes WITH (NOLOCK)
    WHERE SourceName = 'CAP'
),
Eth AS
(
    SELECT DISTINCT Description, CCGrouping
    FROM SEO_MART.dbo.lk_EthnicityCodes WITH (NOLOCK)
)

---- =========================
---- Current School Year (live)
---- =========================
SELECT
     t5.[StudentID]
    ,t5.[FirstName]
    ,t5.[LastName]
    ,t5.[BirthDate]
    ,t5.[IsTurning5]
    ,t5.[ConsentDocumentIDT]
    ,t5.[OutcomeDocumentIDT]
    ,t5.[PlacementDocumentIDT]
    ,t5.[SLLDocumentIDT]
    ,t5.[OutcomeTypeCode]
    ,t5.[OutcomeTypeDesc]
    ,t5.[PlacementTypeCode]
    ,t5.[PlacementTypeDesc]
    ,t5.[SLLTypeCode]
    ,t5.[SLLTypeDesc]
    ,t5.[OutcomeDocStatus]
    ,t5.[OutcomeDocStatusDesc]
    ,t5.[ReferralDate]
    ,t5.[ConsentDate]
    ,t5.[SocialHistoryAssessDate]
    ,t5.[PhysicalExamAssessDate]
    ,t5.[ClassroomOBSAssessDate]
    ,t5.[PsychoEDAssessDate]
    ,t5.[IEPNoticeDate]
    ,t5.[OutcomeDate]
    ,t5.[EffectiveDate]
    ,t5.[PlacementDate]
    ,t5.[ConsentProvisionServiceDate]
    ,t5.[LocationLetterDate]
    ,t5.[IEPComplianceDate]
    ,t5.[PWNComplianceDate]
    ,t5.[InActiveSinceDate]
    ,CASE WHEN t5.[InActiveSinceDate] IS NULL THEN 'Y' ELSE 'N' END AS [IsActive]
    ,t5.[SchoolYear]
    ,t5.[PlacementDocStatus]
    ,t5.[PlacementDocStatusDesc]
    ,t5.[SLLDocStatus]
    ,t5.[SLLDocStatusDesc]
    ,t5.[T5IEPNoticeDate]
    ,t5.[T5SESISStatus]
    ,t5.[T5SESISStatusCode]
    ,t5.[T5SESISStatusGrouping]
    ,t5.[T5SESISStatusCodeGrouping]
    ,t5.[T5SESISStatusCodeDashboard]
    ,t5.[T5SESISStatusDashboard]
    ,t5.[ReportStatus]
    ,t5.[ProjectedIEPImplementationDate]
    ,t5.[IniRefUplReceiveDate]
    ,t5.[ProcessStage]
    ,t5.[ProcessStageDesc]
    ,t5.[OutcomeReason]
    ,t5.[OutcomeReasonDesc]
    ,t5.[DisabilityCode]
    ,t5.[ClassificationDesc]
    ,t5.[ReasonForRecommendPlacement]
    ,t5.[RecommendPlacementDesc]
    ,t5.[RecommendedPlacementReportingDesc]
    ,t5.[OtherFactors]
    ,t5.[T5RecordSource]
    ,t5.[SESISOpenDate]
    ,t5.[ZonedSchool]
    ,t5.[CapPreKSchool]
    ,t5.[SESISEnrollDBN]
    ,t5.[T5SchoolDBN]
    ,t5.[AssignedSchoolDBN]
    ,t5.[T5IEPTeam]
    ,t5.[WaveAssignedSchoolDBN]
    ,t5.[D75AdminDBN]
    ,t5.[D75PhysicalDBN]
    ,t5.[CurrentAddAdminDBN]
    ,t5.[SchoolType]
    ,t5.[T5IEPTeamDesc]
    ,t5.[T5IEPTeamType]
    ,t5.[SupsOfPsychName]
    ,t5.[T5CaseLoad]
    ,t5.[CSE]
    ,t5.[EnrollPhyical]
    ,t5.[AddLocationPhysical]
    ,t5.[ReceivingAdmin]
    ,t5.[ReceivingPhysical]
    ,t5.[FSCLeaderName]
    ,t5.[FSCName]
    ,t5.[FSCReportingName]
    ,CASE WHEN t5.SchoolType = 'CSE' AND t5.[Superintendent] IS NULL
          THEN CONCAT(t5.[CSE],' Chairperson') ELSE t5.Superintendent END AS Superintendent
    ,t5.[AdminDistrict]
    ,t5.[CaseType]
    ,CASE WHEN t5.[CaseType] = 'T5 RE-EVAL' THEN 'Reevaluation'
          WHEN t5.[CaseType] = 'T5 INITIAL' THEN 'Initial'
          ELSE t5.[CaseType] END AS ReferralType
    ,t5.[ReassignmentDate]
    ,t5.[AccessibleProgramFlag]
    ,t5.[ELLStatus]
    ,t5.[Gender]
    ,t5.[Ethnicity]
    ,eth.CCGrouping AS EthnicityCC
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
    ,t5.[GuardianLanguage]
    ,t5.[GuardianLanguageDesc]
    ,t5.[Notice]
    ,t5.[DHSDVFlag]
    ,CASE WHEN t5.[DHSDVFlag] ='DHS' THEN 'Y' ELSE 'N' END AS TemporaryHousingStatus
    ,t5.[ReferralSchool]
    ,t5.[CurrentCAPServiceSchool]
    ,t5.[ServiceSchoolName]
    ,t5.[AssessmentBilLangCode]
    ,t5.[IsBilingual]
    ,CASE WHEN t5.[IsBilingual] = 1 THEN 'Y' ELSE 'N' END AS [Requires Bilingual Psych]
    ,lc.CCGrouping AS [LanguageDescriptionGrouping]
    ,t5.[CaseCloseReasonCode]
    ,t5.[CaseCloseDesc]
    ,t5.[CAPDischargeCode]
    ,t5.[RecommendedProgram]
    ,t5.[EvaluationDesc]
    ,t5.[EvaluationType]
    ,t5.[DualRecmInd]
    ,t5.[RecommServiceCategory]
    ,t5.[CloseCode]
    ,t5.[SEITSessionPerWeek]
    ,t5.[RecommendedRS]
    ,t5.[ESYFlag]
    ,t5.[ESYSameServiceFlag]
    ,t5.[LinkageBucket]
    ,t5.[FirstOutcomeDate]
    ,t5.[FirstOutcomeDocumentIDT]
    ,t5.[OutcomeCreatedDate]
    ,t5.[OutcomeFinalizedDate]
    ,t5.[PlacementCreatedDate]
    ,t5.[PlacementFinalizedDate]
    ,t5.[SLLCreatedDate]
    ,t5.[SLLFinalizedDate]
    ,t5.[DateIEP]
    ,t5.Paraprofessional
    ,t5.ParaType
    ,t5.[ParaGroup]
    ,t5.[ParaDuration]
    ,t5.ParaFullDescription
    ,t5.ParaStartDate
    ,t5.ParaEndDate
    ,t5.ParaViewFlag
    ,t5.ATServiceType
    ,t5.ATGroup
    ,t5.ATServiceFlag
    ,t5.[ATActiveServiceFlag]
    ,t5.ATServiceCategory
    ,t5.ATViewFlag
    ,t5.[ProcessedDateTime]
    ,t5.[ProcessedDate]
    ,t5.[WaveProcessedDate]
    ,CASE WHEN t5.WaveProcessedDate IS NULL THEN 'N' ELSE 'Y' END AS WaveAssignedFlag
    ,CASE WHEN t5.WaveProcessedDate is null 
	THEN 'Walk-In' ELSE CONCAT('Wave ',reg.WaveID) 
	END AS AssignmentProcess --2/2/26 Added for filter; WaveID is not in RPT_T5RL
FROM SEO_MART.dbo.RPT_T5ReferralLinkage t5 WITH (NOLOCK)
CROSS JOIN Params p
LEFT JOIN LCode lc ON t5.AssessmentBilLangCode = lc.Code
LEFT JOIN Eth   eth ON t5.Ethnicity = eth.Description
LEFT JOIN 
		(SELECT StudentID, WaveID
		FROM SEO_MART.dbo.RPT_T5StudentRegister WITH(NOLOCK)
		)reg --2/2/26 Adding because ReferralLinkage does not have WaveID
		ON t5.StudentID=reg.StudentID
WHERE t5.SchoolYear = p.CurSY

UNION ALL

---- =========================
---- 1 Yr Prior (arch) - latest processed for that SY
---- =========================
SELECT
     t5.[StudentID]
    ,t5.[FirstName]
    ,t5.[LastName]
    ,t5.[BirthDate]
    ,t5.[IsTurning5]
    ,t5.[ConsentDocumentIDT]
    ,t5.[OutcomeDocumentIDT]
    ,t5.[PlacementDocumentIDT]
    ,t5.[SLLDocumentIDT]
    ,t5.[OutcomeTypeCode]
    ,t5.[OutcomeTypeDesc]
    ,t5.[PlacementTypeCode]
    ,t5.[PlacementTypeDesc]
    ,t5.[SLLTypeCode]
    ,t5.[SLLTypeDesc]
    ,t5.[OutcomeDocStatus]
    ,t5.[OutcomeDocStatusDesc]
    ,t5.[ReferralDate]
    ,t5.[ConsentDate]
    ,t5.[SocialHistoryAssessDate]
    ,t5.[PhysicalExamAssessDate]
    ,t5.[ClassroomOBSAssessDate]
    ,t5.[PsychoEDAssessDate]
    ,t5.[IEPNoticeDate]
    ,t5.[OutcomeDate]
    ,t5.[EffectiveDate]
    ,t5.[PlacementDate]
    ,t5.[ConsentProvisionServiceDate]
    ,t5.[LocationLetterDate]
    ,t5.[IEPComplianceDate]
    ,t5.[PWNComplianceDate]
    ,t5.[InActiveSinceDate]
    ,CASE WHEN t5.[InActiveSinceDate] IS NULL THEN 'Y' ELSE 'N' END AS [IsActive]
    ,t5.[SchoolYear]
    ,t5.[PlacementDocStatus]
    ,t5.[PlacementDocStatusDesc]
    ,t5.[SLLDocStatus]
    ,t5.[SLLDocStatusDesc]
    ,t5.[T5IEPNoticeDate]
    ,t5.[T5SESISStatus]
    ,t5.[T5SESISStatusCode]
    ,t5.[T5SESISStatusGrouping]
    ,t5.[T5SESISStatusCodeGrouping]
    ,t5.[T5SESISStatusCodeDashboard]
    ,t5.[T5SESISStatusDashboard]
    ,t5.[ReportStatus]
    ,t5.[ProjectedIEPImplementationDate]
    ,t5.[IniRefUplReceiveDate]
    ,t5.[ProcessStage]
    ,t5.[ProcessStageDesc]
    ,t5.[OutcomeReason]
    ,t5.[OutcomeReasonDesc]
    ,t5.[DisabilityCode]
    ,t5.[ClassificationDesc]
    ,t5.[ReasonForRecommendPlacement]
    ,t5.[RecommendPlacementDesc]
    ,t5.[RecommendedPlacementReportingDesc]
    ,t5.[OtherFactors]
    ,t5.[T5RecordSource]
    ,t5.[SESISOpenDate]
    ,t5.[ZonedSchool]
    ,t5.[CapPreKSchool]
    ,t5.[SESISEnrollDBN]
    ,t5.[T5SchoolDBN]
    ,t5.[AssignedSchoolDBN]
    ,t5.[T5IEPTeam]
    ,t5.[WaveAssignedSchoolDBN]
    ,t5.[D75AdminDBN]
    ,t5.[D75PhysicalDBN]
    ,t5.[CurrentAddAdminDBN]
    ,t5.[SchoolType]
    ,t5.[T5IEPTeamDesc]
    ,t5.[T5IEPTeamType]
    ,t5.[SupsOfPsychName]
    ,t5.[T5CaseLoad]
    ,t5.[CSE]
    ,t5.[EnrollPhyical]
    ,t5.[AddLocationPhysical]
    ,t5.[ReceivingAdmin]
    ,t5.[ReceivingPhysical]
    ,t5.[FSCLeaderName]
    ,t5.[FSCName]
    ,t5.[FSCReportingName]
    ,CASE WHEN t5.SchoolType = 'CSE' AND t5.[Superintendent] IS NULL
          THEN CONCAT(t5.[CSE],' Chairperson') ELSE t5.Superintendent END AS Superintendent
    ,t5.[AdminDistrict]
    ,t5.[CaseType]
    ,CASE WHEN t5.[CaseType] = 'T5 RE-EVAL' THEN 'Reevaluation'
          WHEN t5.[CaseType] = 'T5 INITIAL' THEN 'Initial'
          ELSE t5.[CaseType] END AS ReferralType
    ,t5.[ReassignmentDate]
    ,t5.[AccessibleProgramFlag]
    ,t5.[ELLStatus]
    ,t5.[Gender]
    ,t5.[Ethnicity]
    ,eth.CCGrouping AS EthnicityCC
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
    ,t5.[GuardianLanguage]
    ,t5.[GuardianLanguageDesc]
    ,t5.[Notice]
    ,t5.[DHSDVFlag]
    ,CASE WHEN t5.[DHSDVFlag] ='DHS' THEN 'Y' ELSE 'N' END AS TemporaryHousingStatus
    ,t5.[ReferralSchool]
    ,t5.[CurrentCAPServiceSchool]
    ,t5.[ServiceSchoolName]
    ,t5.[AssessmentBilLangCode]
    ,t5.[IsBilingual]
    ,CASE WHEN t5.[IsBilingual] = 1 THEN 'Y' ELSE 'N' END AS [Requires Bilingual Psych]
    ,lc.CCGrouping AS [LanguageDescriptionGrouping]
    ,t5.[CaseCloseReasonCode]
    ,t5.[CaseCloseDesc]
    ,t5.[CAPDischargeCode]
    ,t5.[RecommendedProgram]
    ,t5.[EvaluationDesc]
    ,t5.[EvaluationType]
    ,t5.[DualRecmInd]
    ,t5.[RecommServiceCategory]
    ,t5.[CloseCode]
    ,t5.[SEITSessionPerWeek]
    ,t5.[RecommendedRS]
    ,t5.[ESYFlag]
    ,t5.[ESYSameServiceFlag]
    ,t5.[LinkageBucket]
    ,t5.[FirstOutcomeDate]
    ,t5.[FirstOutcomeDocumentIDT]
    ,t5.[OutcomeCreatedDate]
    ,t5.[OutcomeFinalizedDate]
    ,t5.[PlacementCreatedDate]
    ,t5.[PlacementFinalizedDate]
    ,t5.[SLLCreatedDate]
    ,t5.[SLLFinalizedDate]
    ,t5.[DateIEP]
    ,t5.Paraprofessional
    ,t5.ParaType
    ,t5.[ParaGroup]
    ,t5.[ParaDuration]
    ,t5.ParaFullDescription
    ,t5.ParaStartDate
    ,t5.ParaEndDate
    ,t5.ParaViewFlag
    ,t5.ATServiceType
    ,t5.ATGroup
    ,t5.ATServiceFlag
    ,t5.[ATActiveServiceFlag]
    ,t5.ATServiceCategory
    ,t5.ATViewFlag
    ,t5.[ProcessedDateTime]
    ,t5.[ProcessedDate]
    ,t5.[WaveProcessedDate]
    ,CASE WHEN t5.WaveProcessedDate IS NULL THEN 'N' ELSE 'Y' END AS WaveAssignedFlag
    ,CASE WHEN t5.WaveProcessedDate is null 
	THEN 'Walk-In' ELSE CONCAT('Wave ',reg.WaveID) 
	END AS AssignmentProcess --2/2/26 Added for filter; WaveID is not in RPT_T5RL
FROM SEO_MART.[arch].[RPT_T5ReferralLinkage_MultiSY] t5 WITH (NOLOCK)
CROSS JOIN Params p
INNER JOIN LastProcessed lp
    ON lp.SchoolYear = t5.SchoolYear
   AND TRY_CONVERT(date, t5.ProcessedDate) = lp.LastProcessedDate
LEFT JOIN LCode lc ON t5.AssessmentBilLangCode = lc.Code
LEFT JOIN Eth   eth ON t5.Ethnicity = eth.Description
LEFT JOIN 
		(SELECT DISTINCT StudentID, WaveID
		FROM SEO_MART.arch.RPT_T5StudentRegister_MultiSY reg WITH(NOLOCK)
        INNER JOIN LastProcessed lp
            ON lp.SchoolYear = reg.SchoolYear
            AND TRY_CONVERT(date, reg.ProcessedDate) = lp.LastProcessedDate
		)reg --2/2/26 Adding because ReferralLinkage does not have WaveID
		ON t5.StudentID=reg.StudentID
WHERE t5.SchoolYear = p.PrevSY

UNION ALL

-- =========================
-- 2 Yrs Prior (arch) - hard-coded SY23-24 processed date
-- =========================
SELECT
     t5.[StudentID]
    ,t5.[FirstName]
    ,t5.[LastName]
    ,t5.[BirthDate]
    ,t5.[IsTurning5]
    ,t5.[ConsentDocumentIDT]
    ,t5.[OutcomeDocumentIDT]
    ,t5.[PlacementDocumentIDT]
    ,t5.[SLLDocumentIDT]
    ,t5.[OutcomeTypeCode]
    ,t5.[OutcomeTypeDesc]
    ,t5.[PlacementTypeCode]
    ,t5.[PlacementTypeDesc]
    ,t5.[SLLTypeCode]
    ,t5.[SLLTypeDesc]
    ,t5.[OutcomeDocStatus]
    ,t5.[OutcomeDocStatusDesc]
    ,t5.[ReferralDate]
    ,t5.[ConsentDate]
    ,t5.[SocialHistoryAssessDate]
    ,t5.[PhysicalExamAssessDate]
    ,t5.[ClassroomOBSAssessDate]
    ,t5.[PsychoEDAssessDate]
    ,t5.[IEPNoticeDate]
    ,t5.[OutcomeDate]
    ,t5.[EffectiveDate]
    ,t5.[PlacementDate]
    ,t5.[ConsentProvisionServiceDate]
    ,t5.[LocationLetterDate]
    ,t5.[IEPComplianceDate]
    ,t5.[PWNComplianceDate]
    ,t5.[InActiveSinceDate]
    ,CASE WHEN t5.[InActiveSinceDate] IS NULL THEN 'Y' ELSE 'N' END AS [IsActive]
    ,t5.[SchoolYear]
    ,t5.[PlacementDocStatus]
    ,t5.[PlacementDocStatusDesc]
    ,t5.[SLLDocStatus]
    ,t5.[SLLDocStatusDesc]
    ,t5.[T5IEPNoticeDate]
    ,t5.[T5SESISStatus]
    ,t5.[T5SESISStatusCode]
    ,t5.[T5SESISStatusGrouping]
    ,t5.[T5SESISStatusCodeGrouping]
    ,t5.[T5SESISStatusCodeDashboard]
    ,t5.[T5SESISStatusDashboard]
    ,t5.[ReportStatus]
    ,t5.[ProjectedIEPImplementationDate]
    ,t5.[IniRefUplReceiveDate]
    ,t5.[ProcessStage]
    ,t5.[ProcessStageDesc]
    ,t5.[OutcomeReason]
    ,t5.[OutcomeReasonDesc]
    ,t5.[DisabilityCode]
    ,t5.[ClassificationDesc]
    ,t5.[ReasonForRecommendPlacement]
    ,t5.[RecommendPlacementDesc]
    ,t5.[RecommendedPlacementReportingDesc]
    ,t5.[OtherFactors]
    ,t5.[T5RecordSource]
    ,t5.[SESISOpenDate]
    ,t5.[ZonedSchool]
    ,t5.[CapPreKSchool]
    ,t5.[SESISEnrollDBN]
    ,t5.[T5SchoolDBN]
    ,t5.[AssignedSchoolDBN]
    ,t5.[T5IEPTeam]
    ,t5.[WaveAssignedSchoolDBN]
    ,t5.[D75AdminDBN]
    ,t5.[D75PhysicalDBN]
    ,t5.[CurrentAddAdminDBN]
    ,t5.[SchoolType]
    ,t5.[T5IEPTeamDesc]
    ,t5.[T5IEPTeamType]
    ,t5.[SupsOfPsychName]
    ,t5.[T5CaseLoad]
    ,t5.[CSE]
    ,t5.[EnrollPhyical]
    ,t5.[AddLocationPhysical]
    ,t5.[ReceivingAdmin]
    ,t5.[ReceivingPhysical]
    ,t5.[FSCLeaderName]
    ,t5.[FSCName]
    ,t5.[FSCReportingName]
    ,CASE WHEN t5.SchoolType = 'CSE' AND t5.[Superintendent] IS NULL
          THEN CONCAT(t5.[CSE],' Chairperson') ELSE t5.Superintendent END AS Superintendent
    ,t5.[AdminDistrict]
    ,t5.[CaseType]
    ,CASE WHEN t5.[CaseType] = 'T5 RE-EVAL' THEN 'Reevaluation'
          WHEN t5.[CaseType] = 'T5 INITIAL' THEN 'Initial'
          ELSE t5.[CaseType] END AS ReferralType
    ,t5.[ReassignmentDate]
    ,t5.[AccessibleProgramFlag]
    ,t5.[ELLStatus]
    ,t5.[Gender]
    ,t5.[Ethnicity]
    ,eth.CCGrouping AS EthnicityCC
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
    ,t5.[GuardianLanguage]
    ,t5.[GuardianLanguageDesc]
    ,t5.[Notice]
    ,t5.[DHSDVFlag]
    ,CASE WHEN t5.[DHSDVFlag] = 'DHS' THEN 'Y' ELSE 'N' END AS TemporaryHousingStatus
    ,t5.[ReferralSchool]
    ,t5.[CurrentCAPServiceSchool]
    ,t5.[ServiceSchoolName]
    ,t5.[AssessmentBilLangCode]
    ,t5.[IsBilingual]
    ,CASE WHEN t5.[IsBilingual] = 1 THEN 'Y' ELSE 'N' END AS [Requires Bilingual Psych]
    ,lc.CCGrouping AS [LanguageDescriptionGrouping]
    ,t5.[CaseCloseReasonCode]
    ,t5.[CaseCloseDesc]
    ,t5.[CAPDischargeCode]
    ,t5.[RecommendedProgram]
    ,t5.[EvaluationDesc]
    ,t5.[EvaluationType]
    ,t5.[DualRecmInd]
    ,t5.[RecommServiceCategory]
    ,t5.[CloseCode]
    ,t5.[SEITSessionPerWeek]
    ,t5.[RecommendedRS]
    ,t5.[ESYFlag]
    ,t5.[ESYSameServiceFlag]
    ,t5.[LinkageBucket]
    ,t5.[FirstOutcomeDate]
    ,t5.[FirstOutcomeDocumentIDT]
    ,t5.[OutcomeCreatedDate]
    ,t5.[OutcomeFinalizedDate]
    ,t5.[PlacementCreatedDate]
    ,t5.[PlacementFinalizedDate]
    ,t5.[SLLCreatedDate]
    ,t5.[SLLFinalizedDate]
    ,t5.[DateIEP]
    ,t5.Paraprofessional
    ,t5.ParaType
    ,t5.[ParaGroup]
    ,t5.[ParaDuration]
    ,t5.ParaFullDescription
    ,t5.ParaStartDate
    ,t5.ParaEndDate
    ,t5.ParaViewFlag
    ,t5.ATServiceType
    ,t5.ATGroup
    ,t5.ATServiceFlag
    ,t5.[ATActiveServiceFlag]
    ,t5.ATServiceCategory
    ,t5.ATViewFlag
    ,t5.[ProcessedDateTime]
    ,t5.[ProcessedDate]
    ,t5.[WaveProcessedDate]
    ,CASE WHEN t5.WaveProcessedDate IS NULL THEN 'N' ELSE 'Y' END AS WaveAssignedFlag
    ,CASE WHEN t5.WaveProcessedDate is null 
	THEN 'Walk-In' ELSE CONCAT('Wave ',reg.WaveID) 
	END AS AssignmentProcess --2/2/26 Added for filter; WaveID is not in RPT_T5RL
FROM SEO_MART.[arch].[RPT_T5ReferralLinkage_MultiSY] t5 WITH (NOLOCK)
CROSS JOIN Params p
INNER JOIN LastProcessed lp
    ON lp.SchoolYear = t5.SchoolYear
   AND TRY_CONVERT(date, t5.ProcessedDate) = lp.LastProcessedDate
LEFT JOIN LCode lc ON t5.AssessmentBilLangCode = lc.Code
LEFT JOIN Eth   eth ON t5.Ethnicity = eth.Description
LEFT JOIN 
		(SELECT DISTINCT StudentID, WaveID
		FROM SEO_MART.arch.RPT_T5StudentRegister_MultiSY reg WITH(NOLOCK)
        INNER JOIN LastProcessed lp
            ON lp.SchoolYear = reg.SchoolYear
            AND TRY_CONVERT(date, reg.ProcessedDate) = lp.LastProcessedDate
		)reg --2/2/26 Adding because ReferralLinkage does not have WaveID
		ON t5.StudentID=reg.StudentID
WHERE t5.SchoolYear = p.Prev2SY
  

  ;
GO


