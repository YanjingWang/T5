USE [SEO_REPORTING]
GO

/****** Object:  View [BI].[vw_T5Dashboard_ReferralsCitywide_v2]    Script Date: 4/6/2026 1:41:58 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



























CREATE view [BI].[vw_T5Dashboard_ReferralsCitywide_v2]

/****************************************************************************************************************************************************************************************************************
Object Name: [SEO_REPORTING].[BI].[vw_T5Dashboard_ReferralsCitywide_v2]

Sample call: select * from BI.vw_T5Dashboard_ReferralsCitywide_v2

Purpose: Overall Citywide Metrics comparision.

Date Created: 10/01/2019

Modification Details: INITIAL

Author             ModifiedDate   Comments
-----------------  -------------  ----------------------------------------------
Prem Boompagh      5/23/2022      The CASE statement was added to flag active students.
Prem Boompagh      12/04/2024     Added the Case statement based on current business rules for 
                                   Para from supplementary aids and assistive technology services.
Prem Boompagh      04/08/2025      Ranked the 'AT Services' and Partitioned by OutcomeDocumentIDT to avoid duplicates.		
Prem Boompagh      04/16/2025      Enhanced paraprofessional data by concatenating multiple ParaTypes for each student. 
Ariel H			   06/11/2025	   Update WaveAssignedFlag case statement
Maneesh Vellanki   08/20/2025	   Removed 'AST.ServiceTypeOther' (causing one to many relations), 
								   Added 'ATGroup',
								   Updated Para->[Group] logic to change priority from 'Individual' to 'Group' as per discussions with Ariel.
Charlotte Wang     12/17/2025      Dynamic Rollover
Charlotte Wang     12/22/2025      Removed old fields from para and AT and removed left join from para and AT
Ariel H			   02/02/2026	  AssignmentProcess added to clearly distinguish between Wave Assigned, Walk-Ins, and Ineligible students
Ariel H			   03/09/2026      TemporaryHousingStatus was written incorrectly. Instead of not NULl changed to 'DHS'
***************************************************************************************************************************************************************************************************************/
AS

SELECT DISTINCT
     r.[StudentID]
    ,r.[School DBN]
    ,r.[RecommendPlacementDesc]
    ,r.[OutcomeTypeDesc]
    ,r.[ClassificationDesc]
    ,r.[T5SESISStatusDashboard]
    --,r.[RecommendedPlacement]
    ,r.[RecommendedPlacementReportingDesc] -- Raji added this new field
    ,r.[ProgramTypeMRE]
    ,r.Ethnicity
    ,r.[EthnicityCC]
    ,r.[ELLStatus]
    ,r.[T5IEPTeamType]
    ,r.Classification
    ,r.[GuardianLanguage]
    ,r.[GuardianLanguageDesc]
    ,r.[IsBilingual]
    ,CASE WHEN r.[IsBilingual] = 1 THEN 'Y' ELSE 'N' END AS [Requires Bilingual Psych]
    ,r.[DHSDVFlag]
    ,CASE WHEN r.[DHSDVFlag] ='DHS' THEN 'Y' ELSE 'N' END AS TemporaryHousingStatus
    ,r.[CaseType]
    ,CASE
        WHEN r.[CaseType] = 'T5 RE-EVAL' THEN 'Reevaluation'
        WHEN r.[CaseType] = 'T5 INITIAL' THEN 'Initial'
        ELSE r.[CaseType]
     END AS ReferralType
    ,r.[InActiveSinceDate]
    ,CASE WHEN r.[InActiveSinceDate] IS NULL THEN 'Y' ELSE 'N' END AS [IsActive]
    ,r.[WaveProcessedDate]
    ,r.DateIEP
    ,r.IEPStandardComplianceDate
    ,r.FirstOutcomeDate
    ,r.FirstOutcomeDocumentIDT
    ,r.T5IEPTimeliness

    ---------------- para ----------------
    /*Charlotte: add new fields*/
	,r.Paraprofessional
    ,r.ParaType
	,r.[ParaGroup]
	,r.[ParaDuration]
	,r.ParaFullDescription
	,r.ParaStartDate
	,r.ParaEndDate
	,r.ParaViewFlag  
    /*Charlotte: delete this block*/
    --,para_agg.ServiceTypeDesc AS Paraprofessional
    --,para_agg.ConcatenatedParaTypes AS ParaType
    --,para_agg.[Group]
    --,para_agg.Duration
    --,para_agg.FullDescription
    --,para_agg.StartDate
    --,para_agg.EndDate
    --,CASE WHEN para_agg.ServiceTypeDesc IS NOT NULL THEN 'Y' ELSE 'N' END AS ParaViewFlag

    ---------------- AT ------------------
/*Charlotte: add new fields*/
,r.ATServiceType
,r.ATGroup
,r.ATServiceFlag
,r.[ATActiveServiceFlag]
,r.ATServiceCategory
,r.ATViewFlag
/*Charlotte: delete this block*/
    --,AST.ServiceType
    --,AST.ATGroup
    --,AST.ATServiceFlag
    --,AST.[ActiveServiceFlag]
    --,CASE
    --    WHEN AST.ATServiceFlag = 'Y' THEN 'AT Service Recommendation'
    --    WHEN AST.ATServiceFlag = 'N' AND AST.ServiceType IS NOT NULL THEN 'AT Device Recommendation'
    -- END AS ATServiceCategory
    --,CASE WHEN AST.ServiceType IS NOT NULL THEN 'Y' ELSE 'N' END AS ATViewFlag

    ,CASE WHEN r.WaveProcessedDate IS NULL THEN 'N' ELSE 'Y' END AS WaveAssignedFlag
    ,CASE WHEN r.WaveProcessedDate is null 
	THEN 'Walk-In' ELSE CONCAT('Wave ',reg.WaveID) 
	END AS AssignmentProcess --2/2/26 Added for filter; WaveID is not in RPT_T5RL
FROM [SEO_REPORTING].[BI].[vw_T5Dashboard_Referrals_v2] r WITH (NOLOCK)
LEFT JOIN 
		(SELECT StudentID, WaveID
		FROM SEO_MART.dbo.RPT_T5StudentRegister WITH(NOLOCK)
		)reg --2/2/26 Adding because ReferralLinkage does not have WaveID
		ON r.StudentID=reg.StudentID
/*Charlotte: dynamic rollover*/
CROSS JOIN (
    SELECT
        CAST(YEAR(DATEADD(MONTH, -6, GETDATE())) AS varchar(4)) + '-' +
        CAST(YEAR(DATEADD(MONTH,  6, GETDATE())) AS varchar(4)) AS T5SchoolYear,
        YEAR(DATEADD(MONTH, -6, GETDATE())) - 4 AS T5BirthYear
) p

------ para (aggregated) ------
/*Charlotte: delete this block and moved to RPT_T5ReferalLinkage table*/
--LEFT JOIN
--(
--    SELECT
--        DocumentIDT,
--        MAX(ServiceTypeDesc) AS ServiceTypeDesc,
--        STRING_AGG(
--            CASE
--                WHEN ConsolidatedParatype IS NULL THEN 'Unknown'
--                WHEN ConsolidatedParatype IN ('Crisis Management', 'Behavior Management') THEN 'Behavior'
--                WHEN ConsolidatedParatype = 'Orientation and Mobility' THEN 'O&M'
--                WHEN ConsolidatedParatype = 'Physical Assistance' THEN 'Physical Assist'
--                ELSE ConsolidatedParatype
--            END,
--            ', '
--        ) WITHIN GROUP
--        (
--            ORDER BY
--                CASE
--                    WHEN ConsolidatedParatype IN ('Health', 'Medical') THEN 1
--                    WHEN ConsolidatedParatype IN ('Crisis Management', 'Behavior Management') THEN 2
--                    WHEN ConsolidatedParatype = 'Orientation and Mobility' THEN 3
--                    WHEN ConsolidatedParatype = 'Physical Assistance' THEN 4
--                    WHEN ConsolidatedParatype = 'Transportation' THEN 5
--                    ELSE 6
--                END
--        ) AS ConcatenatedParaTypes,
--        MIN(CASE WHEN ConsolidatedGroup IN ('Group', 'Group service') THEN 'Group' ELSE 'Individual' END) AS [Group],
--        MIN(CASE WHEN ConsolidatedDuration = 'Full time' THEN 'Full time' ELSE 'Part time' END) AS Duration,
--        MAX(ConsolidatedService) AS FullDescription,
--        MIN(StartDate) AS StartDate,
--        MAX(EndDate) AS EndDate
--    FROM SEO_MART.dbo.DWH_SupplementaryAids WITH (NOLOCK)
--    WHERE ServiceTypeDesc = 'Paraprofessional'
--      AND DocStatus = 3
--      AND Deleted = 0
--      AND IsDelete = 0
--      AND PlanType <> 'CSP'
--      AND (IsTwelveMonthProgram <> 1 OR IsTwelveMonthProgram IS NULL)
--    GROUP BY DocumentIDT
--) para_agg
--    ON r.OutcomeDocumentIDT = para_agg.DocumentIDT

------ AT (aggregated) ------
/*Charlotte: delete this block and moved to RPT_T5ReferalLinkage table*/
--LEFT JOIN
--(
--    SELECT
--        AST0.OutcomeDocumentIDT,
--        MAX(ActiveServiceFlag) AS ActiveServiceFlag,
--        MAX(AST0.ATServiceFlag) AS ATServiceFlag,
--        STUFF((
--            SELECT DISTINCT ', ' + ServiceType
--            FROM SEO_MART.dbo.INT_AssistiveTechnology AST1 WITH (NOLOCK)
--            WHERE AST1.OutcomeDocumentIDT = AST0.OutcomeDocumentIDT
--            FOR XML PATH('')
--        ), 1, 2, '') AS ServiceType,
--        MIN(CASE WHEN RecommendedGroupType IN ('Group', 'Group service') THEN 'Group' ELSE RecommendedGroupType END) AS [ATGroup]
--    FROM SEO_MART.dbo.INT_AssistiveTechnology AST0 WITH (NOLOCK)
--    WHERE (ActiveDocumentFlag = 'Y' OR (IEPLatestOutcomeFlag IS NULL AND InactiveDate IS NULL))
--    GROUP BY AST0.OutcomeDocumentIDT
--) AST
--    ON r.OutcomeDocumentIDT = AST.OutcomeDocumentIDT

-- Dynamic rollover filter (no lk_SEOBusinessRules)
WHERE r.SchoolYear = p.T5SchoolYear;
GO


