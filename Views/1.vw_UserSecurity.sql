USE [SEO_REPORTING]
GO

/****** Object:  View [BI].[vw_UserSecurity]    Script Date: 4/6/2026 1:31:23 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE View [BI].[vw_UserSecurity]
AS
/***********************************************************************************

	Date	        Author		         Comment
----------	-----  ------         	      -----------------------------------------
01/10/2023	SergeyG		       Add uniqueness into listing BI users (based of source priority in case of few entries for a user)
11/04/2024   Pcissthomas     Change the PrefOrder . MIS-12258

*************************************************************************************/
with UsersFromAllSources as (		-- WITH is added on 01/10/2023
/* Executive Superintendent --*/ 

Select distinct * from (

	--SELECT DISTINCT 
	--   'Executive Superintendent' AS 'BIRole',
	--	[ExecutiveSuperintendentName] AS 'LocationKey', 
	--	[ExecutiveSuperintendentName] AS 'UserName', 
	--	[ExecutiveSuperintendentEmail] AS 'UserEmail'
	--	, 'RPT_Locations' as SourceDatasetName
	--FROM [SEO_MART].[dbo].[RPT_Locations] with(nolock)
	--WHERE  schooltype = 'CSD' AND [StatusDescription] = 'Open' and ActiveFlag = 'Y' AND [ExecutiveSuperintendentName] IS NOT NULL
	--and ExecutiveSuperintendentName not like '%ketler%'
	--and ExecutiveSuperintendentEmail <> 'MDegovi@schools.nyc.gov'

	--UNION

/* Superintendednt -- */ 

SELECT DISTINCT                        
	'Superintendent' AS 'BIRole',
	[superintendentname] AS 'LocationKey', 
	superintendentname AS 'UserName', 
	CASE WHEN [HSNetworkSuperintendentEmail] IS NULL THEN [communitySchoolSupEmail] 
	ELSE [HSNetworkSuperintendentEmail] END AS 'UserEmail'
	, 'RPT_Locations' as SourceDatasetName
FROM [SEO_MART].[dbo].[RPT_Locations] with(nolock)
WHERE schooltype = 'CSD' AND [StatusDescription] = 'Open' AND superintendentname IS NOT NULL 
and ActiveFlag = 'Y'
AND ([communitySchoolSupEmail] IS NOT NULL OR  [HSNetworkSuperintendentEmail] IS NOT NULL)

UNION

--- Supperintendent SupportStaff 

SELECT DISTINCT                        
	'Superintendent Support' AS 'BIRole',
	[SuperintendentLocationCode] AS 'LocationKey', 
	StaffName AS 'UserName', 
	StaffEmail as 'UserEmail'
	, 'lk_SuptDistrictStaff' as SourceDatasetName
FROM [SEO_MART].[dbo].[lk_SuptDistrictStaff] with(nolock)
where [ActiveFlag] = 'Y' and 
StaffRole in ('Academic Policy and Performance & Assessment Leads', 'Administrator of Special Education','Deputy Superintendent','Specialized Student Support Lead',
'Executive Director of School Support and Operations', 'District Achievement and Instructional Specialist')

UNION

-- Director of Special Education -- Jai 03/02/26
SELECT DISTINCT                        
	'DSE' AS 'BIRole',
	Tier3SupportLocationCode AS 'LocationKey', 
	StaffName AS 'UserName', 
	StaffEmail as 'UserEmail'
	, 'lk_SuptDistrictStaff' as SourceDatasetName
FROM [SEO_MART].[dbo].[lk_SuptDistrictStaff] with(nolock)
where [ActiveFlag] = 'Y' and StaffRole = 'Director for Special Education' 

/* ASEs-- */ 

--SELECT DISTINCT                        
--	'Superintendent Support' AS 'BIRole',
--	[SuperintendentLocationCode] AS 'LocationKey', 
--	ASEName AS 'UserName', 
--	[ASEEmail] as 'UserEmail'
--	, 'lk_SuptSupportStructure' as SourceDatasetName
--FROM [SEO_MART].[dbo].[lk_SuptSupportStructure] with(nolock)
--where ASEName <> 'Vacancy'

--UNION
 
--/* Deputy Superintendednt -- */ 
--SELECT DISTINCT                        
--	'Superintendent Support' AS 'BIRole',
--	[SuperintendentLocationCode] AS 'LocationKey', 
--	DeputyName AS 'UserName', 
--	DeputyEmail as 'UserEmail'
--	, 'lk_SuptSupportStructure' as SourceDatasetName
--FROM [SEO_MART].[dbo].[lk_SuptSupportStructure] with(nolock)
--where DeputyName <> 'Vacancy'

UNION
/* Supervisor of Psychologists --*/ --Enabled 8/26/2022 -- Prasanth kumar Bonam

SELECT DISTINCT 
	'Supervisor of Psychologists' AS 'BIRole',
	[SupervisorPsychName] AS 'LocationKey',
	[SupervisorPsychName] AS 'UserName', 
	[SupervisorPsychEmail] AS 'UserEmail'
	, 'RPT_Locations' as SourceDatasetName
 FROM  [SEO_MART].[dbo].[RPT_Locations] with(nolock)
 WHERE schooltype = 'CSD' AND [StatusDescription] = 'Open' AND [SupervisorPsychEmail] IS NOT NULL
 and ActiveFlag = 'Y'
 and [SupervisorPsychName] <> 'Purvi Dharia'
 and [CSEFlag] = 'N'

 UNION 
/* Summer Supervisor of Psychologists --*/ --Disabled 8/26/2022 -- Prasanth kumar Bonam
--Enabled 07/10/2023 and added UNION statement on top of this - Prasanth Kumar Bonam

--Disbaled on 09/06/2023 --Prasanth Kumar Bonam

-- SELECT DISTINCT 
-- 	'Supervisor of Psychologists' AS 'BIRole',
--	[SOPSummerName] AS 'LocationKey',
--	[SOPSummerName] AS 'UserName', 
--	[SOPSummerEmail] AS 'UserEmail'
--	, 'RPT_Locations' as SourceDatasetName
-- FROM [SEO_MART].[dbo].[RPT_Locations] with(nolock)
--WHERE schooltype = 'CSD' AND [StatusDescription] = 'Open' AND [SOPSummerEmail] IS NOT NULL
--and ActiveFlag = 'Y'
--and [SupervisorPsychName] <> 'Purvi Dharia'
--and [CSEFlag] = 'N'

--UNION

/* CSE Supervisor of Psychologists--*/

SELECT DISTINCT 
	'CSE Supervisor of Psychologists' AS 'BIRole',
	SupervisorPsychName AS 'LocationKey',
	SupervisorPsychname  AS  'UserName', 
	SupervisorPsychEmail AS 'UserEmail' 
	, 'RPT_Locations' as SourceDatasetName
FROM  [SEO_MART].[dbo].[RPT_Locations] with(nolock)
where ActiveFlag = 'Y' and CSESchoolDBN like '%CSE%'

UNION

/* CSE Chairperson--*/

SELECT DISTINCT 
	'CSE Chairperson' AS 'BIRole',
	[CSE] AS 'LocationKey',
	[CSEChairPerson] AS 'UserName', 
	[CSEChairEmail] AS 'UserEmail'
	, 'lk_CSESupervisor' as SourceDatasetName
FROM  [SEO_MART].[dbo].[lk_CSESupervisor] with(nolock)

UNION

/* CSE SEEPPO--*/

SELECT DISTINCT 
	'CSE SEEPO' AS 'BIRole',
	[CSE] AS 'LocationKey',
	[CSESEEPPOName] AS 'UserName', 
	[CSESEEPPOEmail] AS 'UserEmail'
	, 'lk_CSESupervisor' as SourceDatasetName
FROM  [SEO_MART].[dbo].[lk_CSESupervisor] with(nolock)

UNION

/* RS OT Manager--*/

SELECT DISTINCT 
	'Central' AS 'BIRole',
	'N/A' AS 'LocationKey',
	[OTManager] AS 'UserName', 
	[OTManagerEmail] AS 'UserEmail' 
	, 'lk_RSSupervisorManager' as SourceDatasetName
FROM [SEO_MART].[dbo].[lk_RSSupervisorManager] with(nolock)
where [OTManager] is not null 

UNION

/* RS PT Manager--*/

SELECT DISTINCT 
	'Central' AS 'BIRole',
	'N/A' AS 'LocationKey',
	[PTManager] AS 'UserName', 
	[PTManagerEmail] AS 'UserEmail'
	, 'lk_RSSupervisorManager' as SourceDatasetName
FROM [SEO_MART].[dbo].[lk_RSSupervisorManager] with(nolock)
where [PTManager] is not null 

UNION

/* RS Speech Manager--*/

SELECT DISTINCT 
	'Central' AS 'BIRole',
	'N/A' AS 'LocationKey',
	[SpeechManager] AS 'UserName', 
	[SpeechManagerEmail] AS 'UserEmail'
	, 'lk_RSSupervisorManager' as SourceDatasetName
FROM [SEO_MART].[dbo].[lk_RSSupervisorManager] with(nolock)
where [SpeechManager] is not null 

UNION

/* RS OT supervisor--*/

SELECT DISTINCT 
	'OTSupervisor' AS 'BIRole',
	[OTSupervisor] AS 'LocationKey',
	[OTSupervisor] AS 'UserName', 
	[OTSupervisorEmail] AS 'UserEmail'
	, 'lk_RSSupervisorManager' as SourceDatasetName
FROM [SEO_MART].[dbo].[lk_RSSupervisorManager] with(nolock)
where [OTSupervisor] is not null 
and [OTSupervisorEmail] <> [OTManagerEmail]
-- and OTSupervisorEmail not in (select OTManagerEmail from  [SEO_MART].[dbo].[lk_RSSupervisorManager]) 

UNION

/* RS PT Supervisor --*/

SELECT DISTINCT 
	'PTSupervisor' AS 'BIRole',
	[PTSupervisor] AS 'LocationKey',
	[PTSupervisor] AS 'UserName', 
	[PTSupervisorEmail] AS 'UserEmail'
	, 'lk_RSSupervisorManager' as SourceDatasetName
FROM [SEO_MART].[dbo].[lk_RSSupervisorManager] with(nolock)
where [PTSupervisor] is not null 
and [PTSupervisorEmail] <> [PTManagerEmail]

UNION

/* RS Speech Manager--*/

SELECT DISTINCT 
	'SpeechSupervisor' AS 'BIRole',
	[SpeechSupervisor] AS 'LocationKey',
	[SpeechSupervisor] AS 'UserName', 
	[SpeechSupervisorEmail] AS 'UserEmail'
	, 'lk_RSSupervisorManager' as SourceDatasetName
FROM [SEO_MART].[dbo].[lk_RSSupervisorManager] with(nolock)
where [SpeechSupervisor] is not null 
and SpeechSupervisorEmail <> SpeechManagerEmail

UNION

/*ASEs*/

--SELECT DISTINCT 
--	'FSC' AS 'BIRole',
	---[FieldSupportCenterReportingName] AS 'LocationKey',
	--[ASEName] AS 'UserName', 
--	[ASEEmail] AS 'UserEmail'
--	, 'lk_ASE' as SourceDatasetName
--FROM [SEO_MART].[dbo].[lk_ASE] with(nolock)
--where ASEEmail <> 'VACANCY'

--UNION

/*central and other users*/ 

SELECT [BIRole],
    [LocationKey], 
	[UserName], 
	[UserEmail] 
	, 'lk_BICentralBCOUsers' as SourceDatasetName
FROM [SEO_MART].dbo.lk_BICentralBCOUsers
WHERE status = 1 ) as a
)
--  The code below is added on 01/20/2023:
--
	, SourcePref as (select * 
						from ( Values	
										('RPT_Locations',			1 )
									,	('lk_SuptDistrictStaff',	2 )
									,	('lk_CSESupervisor',		3 )
									,	('lk_RSSupervisorManager',	4 )
									,	('lk_BICentralBCOUsers',	99)
							) V (SourceDatasetName, PrefOrder)
					)
	, DupEmail	as (select UserEmail, 1 IsDupEmail, count(*) cnt from UsersFromAllSources group by UserEmail having count(*)>1)
	, UserRankedBySource 
				as (select u.*, p.PrefOrder
						, rank() over (partition by UserEmail order by PrefOrder asc, UserName asc) UserRecordRank
					from UsersFromAllSources	u
					left outer
					join SourcePref				p	on u.SourceDatasetName = p.SourceDatasetName
					)
	select ur.*, isnull(de.cnt,1) as SameEmailCount, isnull(de.IsDupEmail,0) IsDupEmail
	  from UserRankedBySource	ur
	  left outer
	  join DupEmail				de	on ur.UserEmail	= de.UserEmail
	  where ur.UserRecordRank = 1
--	order by IsDupEmail desc, UserEmail, SourceDatasetName, UserName
--- End of code added by Sergey G on 01/10/2023



GO


