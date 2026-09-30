USE [SEO_REPORTING]
GO

/****** Object:  View [BI].[vw_T5Dashboard_Referrals_v2]    Script Date: 4/6/2026 1:38:41 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
















































CREATE view [BI].[vw_T5Dashboard_Referrals_v2]

/****************************************************************************************************************************************************************************************************************
Object Name: [SEO_REPORTING].[BI].[vw_T5Dashboard_Referrals_v2]

Sample call: 
SELECT * FROM BI.vw_T5Dashboard_Referrals_v2

Purpose: 
This view captures Referrals made based on the Compliance Date and finalized with the IEP and PWN compliance within 60 days.

Date Created: 10/01/2019

Modification Details: INITIAL

Author             ModifiedDate   Comments
-----------------  -------------  ----------------------------------------------
Prem Boompagh      11/12/2023      Updated [IEPStandardComplianceDate] Replaced hard-coded values with dynamic values retrieved from the [lk_T5ReferralComplianceDate] lookup structure.
Prem Boompagh      11/15/2023      Updated [AssessmentBilLangCode] Replaced hard-coded values with dynamic values retrieved from the [lk_LanguageCodes] lookup structure.                      
Prem Boompagh      11/17/2023      Updated [Ethnicity] Replaced hard-coded values with dynamic values retrieved from the [lk_EthnicityCodes] lookup structure.
Prem Boompagh      11/19/2023      Updated [SchoolYear] Replaced hard-coded values with dynamic values retrieved from the [lk_SEOBusinessRules] lookup structure.
Prem Boompagh      11/24/2023      Set 'Superintendent' to 'CSE Chairperson' if 'SchoolType' is 'CSE' and 'Superintendent' is NULL.
Prem Boompagh      10/07/2024      Updated LookupCategory='T5Wave' in lk_SEOBusinessRules join.
Prem Boompagh      04/08/2025      Ranked the 'AT Services' and Partitioned by OutcomeDocumentIDT to avoid duplicates.
Prem Boompagh      04/16/2025      Enhanced paraprofessional data by concatenating multiple ParaTypes for each student. 
Ariel H			   06/11/2025	   Update WaveAssignedFlag case statement
Maneesh Vellanki   07/22/2025	   Updated 'School DBN' as per Lauren to show walkins to cse users.
Maneesh Vellanki   08/8/2025	   Updated 'T5IEPTeamType' for Lauren to show walkins to cse users.
Maneesh Vellanki   08/20/2025	   Removed 'AST.ServiceTypeOther' (causing one to many relations), 
								   Added 'ATGroup',
								   Updated Para->[Group] logic to change priority from 'Individual' to 'Group' as per discussions with Ariel.
Charlotte Wang     12/16/2025      Dynamic Rollover
Charlotte Wang     12/22/2025      Removed old fields from para and AT and removed left join from para and AT
Ariel H			   02/02/2026	   AssignmentProcess added to clearly distinguish between Wave Assigned, Walk-Ins, and Ineligible students
Ariel H			   03/09/2026		   TemporaryHousingStatus was written incorrectly. Instead of not NULl changed to 'DHS'
***************************************************************************************************************************************************************************************************************/
AS



SELECT distinct t5.[StudentID]
	,t5.[FirstName]
	,t5.[LastName]
	,t5.[BirthDate]
	,COALESCE(t5.T5IEPTeam,t5.T5SchoolDBN,cse.CSESchoolDBN) AS 'School DBN'--added as per Lauren to show walkins to cse users.
	,t5.[IsTurning5]
	,t5.[ConsentDocumentIDT]
	,t5.[OutcomeDocumentIDT]
	,t5.[OutcomeTypeCode]
	,t5.[OutcomeTypeDesc]
	,t5.[OutcomeDocStatus]
	,t5.[OutcomeDocStatusDesc]
	,t5.[PlacementDocumentIDT]
	,t5.[PlacementTypeCode]
	,t5.[PlacementTypeDesc]
	,t5.[SLLDocumentIDT]
	,t5.[SLLTypeCode]
	,t5.[SLLTypeDesc]
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
     ,t5.FirstOutcomeDate		
          ,CASE 
			WHEN t5.FirstOutcomeDate <= t5.IEPComplianceDate and t5.T5SESISStatusDashboard in ('Complete','Finalize PNP')
				THEN 1
			ELSE 0
			END AS T5IEPTimeliness
	,t5.FirstOutcomeDocumentIDT
	,t5.[PlacementDate]
	,t5.[ConsentProvisionServiceDate] --[ConsentProvisionService]
	,t5.[LocationLetterDate]
	,t5.[IEPComplianceDate]
	,COALESCE(rcd.ComplianceDateDesc, 'Non-Standard Compliance Date') AS [IEPStandardComplianceDate]
	--,t5.[IEPComplianceDate]
	--            ,case when t5.[IEPComplianceDate] = '2023-06-01' then 'Thursday, June 01, 2023' --2022
	--            when t5.[IEPComplianceDate] = '2023-07-03' then 'Monday, July 03, 2023'  --2022 
	--            when t5.[IEPComplianceDate] = '2023-08-02' then 'Wednesday, August 02, 2023'  --2022
	--            else 'Non-Standard Compliance Date'
	--            end as [IEPStandardComplianceDate]
	--,t5.[IEPStandardComplianceDate]	  
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
	,t5.ProjectedIEPImplementationDate AS [DateIEPImplementedProjected]
	,t5.[IniRefUplReceiveDate] --[DateIniRefUplReceive]
	,t5.[ProcessStage]
	,t5.[ProcessStageDesc]
	,t5.[OutcomeReason]
	,t5.[OutcomeReasonDesc]
	,t5.[DisabilityCode]
	,t5.[ClassificationDesc]
	,t5.[ReasonForRecommendPlacement]
	,t5.[RecommendPlacementDesc]
	--,CASE 
	--	WHEN t5.[RecommendPlacementDesc] IS NULL
	--		THEN 'Awaiting Placement Recommendation'
	--	WHEN t5.[RecommendPlacementDesc] = 'Board of Cooperative Educational Services'
	--		THEN 'Board of Cooperative Educational Services'
	--	WHEN t5.[RecommendPlacementDesc] = 'Charter School'
	--		THEN 'Charter School'
	--	WHEN t5.[RecommendPlacementDesc] = 'Day Treatment'
	--		THEN 'Day Treatment'
	--	WHEN t5.[RecommendPlacementDesc] = 'Home/Hospital Instruction'
	--		THEN 'Home/Hospital Instruction'
	--	WHEN t5.[RecommendPlacementDesc] = 'NYC DOE School Non-Specialized (District 1-32)'
	--		THEN 'District 1-32'
	--	WHEN t5.[RecommendPlacementDesc] = 'NYC DOE Specialized School'
	--		THEN 'D75'
	--	WHEN t5.[RecommendPlacementDesc] = 'NYC DOE Specialized School co-located in an NYC DOE Community School'
	--		THEN 'D75 Co-Located'
	--	WHEN t5.[RecommendPlacementDesc] IN ('NYS Supported Non Public School – 4201 - Day', 'NYS Supported Non Public School – 4201 - Residential')
	--		THEN 'NYS Supported NPS'
	--	WHEN t5.[RecommendPlacementDesc] IN ('NYSED-Approved Non Public School - Day', 'NYSED-Approved Non Public School - Placed by ACS', 'NYSED-Approved Non Public School - Residential')
	--		THEN 'NYSED-Approved'
	--	WHEN t5.[RecommendPlacementDesc] = 'Other'
	--		THEN 'Other'
	--	WHEN t5.[RecommendPlacementDesc] = 'Student is Parentally Placed in a Non-Public School'
	--		THEN 'Parentally Placed in NPS'
	--	ELSE t5.[RecommendPlacementDesc]
	--	END AS 'RecommendedPlacement'
	,t5.[RecommendedPlacementReportingDesc] --Raji added this new field
	,t5.[OtherFactors]
	,t5.[T5RecordSource]
	,t5.[SESISOpenDate]
	,t5.[ZonedSchool]
	,t5.[CapPreKSchool]
	,t5.[SESISEnrollDBN]
	,t5.[T5SchoolDBN]
    ,COALESCE(t5.T5IEPTeam,t5.T5SchoolDBN,cse.CSESchoolDBN) as 'AssignedSchoolDBN'
	,t5.[WaveAssignedSchoolDBN]
	--,t5.[ATSPrekSchoolDBN]
	,t5.[D75AdminDBN]
	,t5.[D75PhysicalDBN]
	,t5.[CurrentAddAdminDBN]
	,t5.[SchoolType]
	,t5.[T5IEPTeamDesc]
	,CASE WHEN t5.[T5IEPTeamType] is not null THEN t5.[T5IEPTeamType]
		  WHEN COALESCE(t5.T5IEPTeam,t5.T5SchoolDBN,cse.CSESchoolDBN) like '%CS%' then 'CSE IEP team' 
		  ELSE 'School-based IEP team' END [T5IEPTeamType]
	,t5.[SupsOfPsychName]
	,t5.[T5CaseLoad]
	,t5.[CSE]
	-- ,t5.[AddLocAdmin]
	,t5.[EnrollPhyical]
	,t5.[AddLocationPhysical]
	,t5.[ReceivingAdmin]
	,t5.[ReceivingPhysical]
	,t5.[FSCLeaderName]
	,t5.[FSCName]
	,t5.[FSCReportingName]
	--,t5.[Superintendent]
	,case when t5.SchoolType='CSE' and t5.Superintendent is NULL 
	then concat(t5.[CSE], ' Chairperson') else t5.Superintendent end Superintendent
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
	--,t5.[HadFinalPlanFL]
	--,t5.[HadFinalIEPFL]
	--,t5.[HadFinalIESPFL]
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
	--,t5.[CAPRefDate]
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
	--,lc.[Description] as 'LanguageDescription'
	--,lc.[CCGrouping] as 'LanguageDescriptionGrouping'
	,t5.[IsBilingual]
	,CASE 
		WHEN t5.[IsBilingual] = 1
			THEN 'Y'
		ELSE 'N'
		END [Requires Bilingual Psych]
	,LCode.CCGrouping AS 'LanguageDescriptionGrouping'
	--,t5.[CCDate]
	,t5.[CaseCloseReasonCode] --[CCReasonCode]
	,t5.[CaseCloseDesc] --[CCDesc]
	--,t5.[EvalComplianceDate]
	--,t5.[PlacementComplianceDate]
	--,t5.[CAPDischargeDate]
	,t5.[CAPDischargeCode]
	--,t5.[IEPConfDate]
	,t5.[RecommendedProgram] AS [RecmProgram]
	,t5.[EvaluationDesc] AS [EvalDesc]
	,t5.[EvaluationType] AS [EvalType]
	,t5.[DualRecmInd]
	,t5.[RecommServiceCategory] --[RecmServiceCategory]
	,t5.[CloseCode]
	,t5.[SEITSessionPerWeek]
	,t5.[RecommendedRS]
	--,t5.[AuthDate]
	--,t5.[FirstAttendDate]
	--,t5.[FinalNoticeDate]
	--,t5.[FinalNoticeConsentDate]
	,t5.OutcomeCreatedDate AS [OutcomeCreatedOn]
	,t5.OutcomeFinalizedDate AS [OutcomeFinalizedOn]
	,t5.PlacementCreatedDate AS [PlacementCreatedOn]
	,t5.PlacementFinalizedDate AS [PlacementFinalizedOn]
	,t5.SLLCreatedDate AS [SLLCreatedOn]
	,t5.SLLFinalizedDate AS [SLLFinalizedOn]
	,t5.[LinkageBucket]
	,t5.[WaveProcessedDate]
	--,[ReportFlag]
	,CASE 
		WHEN t5.OutcomeTypeDesc IN ('IEP', 'IESP')
			THEN t5.PlacementFinalizedDate
		WHEN OutcomeTypeDesc IN ('Ineligible', 'Declass', 'Caseclose', 'Discharge')
			THEN t5.OutcomeFinalizedDate
		END AS FinalizedDate
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
		WHEN t5.ClassificationDesc IN ('Multiple Disabilities', 'Emotional Disability', 'Autism', 'Other Health Impairment', 'Intellectual Disability', 'Speech or Language Impairment', 'Learning Disability')
			THEN t5.ClassificationDesc
		ELSE 'Other'
		END AS ClassificationGroup
	,t5.[ClassificationDesc] AS Classification
	--  ,ss.ProgramTypeMRE
	,CASE 
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
		END AS ProgramTypeMRE
	,ProgramTypeMRERatio
----------------para---------------------------
/*Charlotte: add new fields*/
	,t5.Paraprofessional
	,t5.ParaType
	,t5.[ParaGroup]
	,t5.[ParaDuration]
	,t5.ParaFullDescription
	,t5.ParaStartDate
	,t5.ParaEndDate
	,t5.ParaViewFlag  
/*Charlotte: delete this block*/
--,para_agg.ServiceTypeDesc AS Paraprofessional
--		,para_agg.ConcatenatedParaTypes AS ParaType
--		,para_agg.[Group]
--		,para_agg.Duration
--		,para_agg.FullDescription
--		,para_agg.StartDate
--		,para_agg.EndDate
--		,CASE WHEN para_agg.ServiceTypeDesc IS NOT NULL THEN 'Y' ELSE 'N' END as ParaViewFlag 


--,para.ServiceTypeDesc AS Paraprofessional
--	,CASE 
--		WHEN para.ConsolidatedParatype IS NULL
--			THEN 'Unknown'
--		WHEN para.ConsolidatedParatype IN ('Crisis Management', 'Behavior Management')
--			THEN 'Behavior'
--		WHEN para.ConsolidatedParatype = 'Orientation and Mobility'
--			THEN 'O&M'
--		WHEN para.ConsolidatedParatype = 'Physical Assistance'
--			THEN 'Physical Assist'
--		ELSE para.ConsolidatedParatype
--		END AS ParaType
--	,CASE 
--		WHEN para.ConsolidatedGroup IN ('Group', 'Group service')
--			THEN 'Group'
--		ELSE 'Individual'
--		END AS [Group]
--	,CASE 
--		WHEN para.ConsolidatedDuration = 'Full time'
--			THEN 'Full time'
--		ELSE 'Part time'
--		END AS Duration
--	,para.ConsolidatedService AS FullDescription
--	,para.StartDate
--	,para.EndDate
--,CASE WHEN ServiceTypeDESC = 'Paraprofessional'
--		AND DocStatus = 3
--		AND Deleted = 0
--		AND [IsDelete] = 0
--		AND PlanType <> 'CSP'
--		AND (
--			para.IsTwelveMonthProgram <> 1
--			OR para.IsTwelveMonthProgram IS NULL
--			)
--	Then 'Y'	else 'N'
--END as ParaViewFlag
----------------AT-------------------------------
/*Charlotte: add new fields*/
,t5.ATServiceType
,t5.ATGroup
,t5.ATServiceFlag
,t5.[ATActiveServiceFlag]
,t5.ATServiceCategory
,t5.ATViewFlag
/*Charlotte: delete this block*/
--,AST.ServiceType
--,AST.[ATGroup]
--	,AST.ATServiceFlag
--	,AST.[ActiveServiceFlag]
--	,CASE 
--		WHEN AST.ATServiceFlag = 'Y'
--			THEN 'AT Service Recommendation'
--		WHEN AST.ATServiceFlag = 'N'
--			AND AST.ServiceType IS NOT NULL
--			THEN 'AT Device Recommendation'
--		END AS ATServiceCategory
--,CASE WHEN AST.ServiceType IS NOT NULL
-- Then 'Y' else 'N'
-- END as ATViewFlag
 ,CASE WHEN t5.WaveProcessedDate is null
  THEN 'N' ELSE 'Y' END AS WaveAssignedFlag
 ,CASE WHEN t5.WaveProcessedDate is null 
	THEN 'Walk-In' ELSE CONCAT('Wave ',reg.WaveID) 
	END AS AssignmentProcess --2/2/26 Added for filter; WaveID is not in RPT_T5RL
------------------------------------------------------------------------------
	,t5.DateIEP
	,'End of School Year' as [Data Thru]
FROM [SEO_MART].[dbo].[RPT_T5ReferralLinkage] AS t5	  WITH(NOLOCK)
/*Charlotte: add dynamic rollover*/
CROSS JOIN (
    SELECT
        CAST(YEAR(DATEADD(month,-6,GETDATE())) AS varchar(4))
        + '-'
        + CAST(YEAR(DATEADD(month, 6,GETDATE())) AS varchar(4)) AS T5SchoolYear,
        YEAR(DATEADD(month,-6,GETDATE())) - 4 AS T5BirthYear
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
------para------------
/*Charlotte: delete this block and moved to RPT_T5ReferalLinkage table*/
--LEFT JOIN (
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
--        ) WITHIN GROUP (ORDER BY 
--            CASE 
--                WHEN ConsolidatedParatype IN ('Health', 'Medical') THEN 1
--                WHEN ConsolidatedParatype IN ('Crisis Management', 'Behavior Management') THEN 2
--                WHEN ConsolidatedParatype = 'Orientation and Mobility' THEN 3
--                WHEN ConsolidatedParatype = 'Physical Assistance' THEN 4
--                WHEN ConsolidatedParatype = 'Transportation' THEN 5
--                ELSE 6
--            END
--        ) AS ConcatenatedParaTypes,
--        MIN(CASE WHEN ConsolidatedGroup IN ('Group', 'Group service') THEN 'Group' ELSE 'Individual' END) AS [Group],
--        MIN(CASE WHEN ConsolidatedDuration = 'Full time' THEN 'Full time' ELSE 'Part time' END) AS Duration,
--        MAX(ConsolidatedService) AS FullDescription,
--        MIN(StartDate) AS StartDate,
--        MAX(EndDate) AS EndDate
--    FROM SEO_MART.dbo.DWH_SupplementaryAids	WITH(NOLOCK)
--    WHERE ServiceTypeDesc = 'Paraprofessional'
--        AND DocStatus = 3
--        AND Deleted = 0
--        AND IsDelete = 0
--        AND PlanType <> 'CSP'
--        AND (IsTwelveMonthProgram <> 1 OR IsTwelveMonthProgram IS NULL)
--    GROUP BY DocumentIDT
--) para_agg ON t5.OutcomeDocumentIDT = para_agg.DocumentIDT

----LEFT JOIN SEO_MART.dbo.DWH_SupplementaryAids AS para
----	ON t5.OutcomeDocumentIDT = para.DocumentIDT
------AT---------------
/*Charlotte: delete this block and moved to RPT_T5ReferalLinkage table*/
--LEFT JOIN (
--    SELECT 
--		AST0.OutcomeDocumentIDT,
--        MAX(ActiveServiceFlag) ActiveServiceFlag,
--        MAX(AST0.ATServiceFlag) AS ATServiceFlag,
--		STUFF((
--		    SELECT DISTINCT ', ' + ServiceType
--		    FROM SEO_MART.dbo.INT_AssistiveTechnology AST1	WITH(NOLOCK)
--			Where AST1.OutcomeDocumentIDT = AST0.OutcomeDocumentIDT
--		    FOR XML PATH('')
--		), 1, 2, '') 
--		 AS ServiceType,
--        MIN(CASE WHEN RecommendedGroupType IN ('Group', 'Group service') THEN 'Group' ELSE RecommendedGroupType END) AS [ATGroup]
--    FROM SEO_MART.dbo.INT_AssistiveTechnology AST0	WITH(NOLOCK)
--	WHERE (ActiveDocumentFlag='Y' OR (IEPLatestOutcomeFlag is NULL and InactiveDate is NULL))
--    GROUP BY AST0.OutcomeDocumentIDT
--) AST ON t5.OutcomeDocumentIDT = AST.OutcomeDocumentIDT 

----LEFT JOIN SEO_MART.dbo.INT_AssistiveTechnology AS AST
----	ON t5.OutcomeDocumentIDT = AST.OutcomeDocumentIDT

-----------------------------------------
--  LEFT JOIN (
--  Select DateIEP,StudentID, IEPComplianceDate from
--(Select Row_Number()  Over(Partition by RL.StudentID order by DO.DocumentIDT)TRank, RL.IEPComplianceDate,DO.* from SEO_MART.dbo.RPT_T5ReferralLinkage RL with(nolock) --DateIEP, T5SESISStatusDashboard,
--LEFT JOIN SEO_MART.dbo.DWH_Outcome DO with(nolock)
--on RL.StudentID = DO.StudentID
--and Deleted = 0
--and DocStatus in (1,2)
--and IsDelete = 0
----where T5SESISStatusDashboard = 'Incomplete'
----and IEPComplianceDate = '06/01/2022'
--)G
--where TRank = 1 ) DIEP 
--on t5.StudentID = DIEP.StudentID    --Added the DateIEP from DWH_Outcome by Prem.B 

--LEFT JOIN (
--		SELECT StudentID
--			,MIN(OutcomeDate) AS FirstOutcomeDate
--			,MIN(DocumentIDT) AS DocumentIDT
--			--,ROW_NUMBER() OVER (
--			--	PARTITION BY StudentID ORDER BY OutcomeDate ASC
--			--	) AS Rank
--		FROM seo_mart.dbo.DWH_Outcome OC
--		WHERE OC.Deleted = 0
--			AND OC.DocStatus = 3
--			AND OC.IsDelete = 0
--			AND OC.Outcometypecode IN (1, 2, 3, 5, 6, 7, 8)
--		GROUP BY StudentID
--		) od
--		ON od.StudentID = t5.StudentID



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
LEFT JOIN (
	SELECT DISTINCT CCGrouping
		,Description
	FROM SEO_MART.dbo.lk_EthnicityCodes	WITH(NOLOCK)
	) eth
	ON t5.Ethnicity = eth.Description
LEFT JOIN SEO_MART.dbo.lk_T5ReferralComplianceDate rcd
	ON t5.IEPComplianceDate = rcd.ComplianceDate
		AND rcd.ComplianceCategory = 'IEP'
LEFT JOIN 
		(SELECT StudentID, WaveID
		FROM SEO_MART.dbo.RPT_T5StudentRegister WITH(NOLOCK)
		)reg --2/2/26 Adding because ReferralLinkage does not have WaveID
		ON t5.StudentID=reg.StudentID
/*Charlotte: Remove the hard-coded join*/
--INNER JOIN (
--	SELECT distinct LookupValue
--	FROM SEO_MART.dbo.lk_SEOBusinessRules	WITH(NOLOCK)
--	WHERE LookupName = 'T5SchoolYear'AND LookupCategory='T5Wave'
--	) rul
--	ON t5.SchoolYear = rul.LookupValue

--INNER JOIN (SELECT MAX(ProcessedDate) as EndDate, SchoolYear FROM [SEO_MART].[arch].[RPT_T5ReferralLinkage_MultiSY] Group by SchoolYear) a
--on t5.SchoolYear = a.SchoolYear and t5.ProcessedDate = a.EndDate

--WHERE t5.SchoolYear = rul.LookupValue

--t5.SchoolYear = '2023-2024'
/*Charlotte: add this schoolyear condition*/
WHERE t5.SchoolYear = br.T5SchoolYear
























GO


