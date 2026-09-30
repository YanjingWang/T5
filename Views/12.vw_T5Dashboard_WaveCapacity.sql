USE [SEO_REPORTING]
GO

/****** Object:  View [BI].[vw_T5Dashboard_WaveCapacity]    Script Date: 4/6/2026 1:45:31 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
















CREATE VIEW [BI].[vw_T5Dashboard_WaveCapacity]
/****************************************************************************************************************************************************************************************************************
Object Name: dbo.vw_T5Dashboard_WaveCapacity
Sample call: select * from SEO_REPORTING.BI.vw_T5Dashboard_WaveCapacity order by SchoolDBN
Purpose: Generate school level capacity utilization metrics for T5 business users.
	This request came from Arwina

Date Created: 3/4/2024

ModificatiON Details:

Author		ModifiedDate		Comments
Prem B		3/4/2024			Initial
Prem B		7/2/2024			updated the view with "[SEO_REPORTING].[BI].[vw_T5Report_CapacityUtilizationByIEPTeam_Cumulative]" in CTE cteCapacity and AvailableCapacity,OverAssignedCNT,OverassignmentReason
Prem B      1/13/2025           Added the ASL population(02M347).
Prem B      02/14/2025          Added the T5IEPTeamLanguage 
Prem B      04/09/2025          Added the T5Awaiting
Ariel H		04/10/2025			Simplified script
Ariel H		04/11/2025			Add COALESCE on T5IEPTeam Language join to include assignments w/NULL language in RPT_T5SA
Ariel H		06/11/2025			Change reference from RPT_T5SA to RPT_T5RL per addition of WaveDate,WaveID,and T5IEPTeamLanguage 
Prem B      06/18/2025			Added WaveAssignedFlag
***************************************************************************************************************************************************************************************************************/
AS

SELECT 
	c.T5IEPTeamType AS 'School Category'
	,CONCAT('Wave ',WaveID) AS 'Wave#'
	,c.T5IEPTeam as SchoolDBN
    ,c.T5IEPTeamLanguage
	,CaseAssignmentCapacity
    ,T5Awaiting
	,ISNULL(asg.AssignedCapacity,0)AssignedCapacity				--pulling from here instead of capacity view for by wave counts
	,AvailableCapacity
	,OverAssignedCNT
	,OverassignmentReason
	,PctT5CapacityUtilized
	,WaveDate
	,WaveAssignedFlag
FROM SEO_REPORTING.BI.vw_T5Dashboard_CumulativeCapacity c	   WITH(NOLOCK)
--CROSS JOIN
--(
--	SELECT WaveID,WaveDate
--	FROM seo_mart.dbo.INT_T5WaveSchedule  WITH(NOLOCK)
--	/*WHERE 
--		WaveID>0												--Ignore weeks w/ no Wave'
--		AND WaveStatus='P'	*/									--Only include Processed WaveDates
--)w
LEFT JOIN 
	(
		SELECT 
		T5IEPTeam
		, T5IEPTeamLanguage
		,WaveID
		,WaveDate
		,COUNT(DISTINCT STUDENTID) AS AssignedCapacity
		FROM SEO_MART.dbo.RPT_T5ReferralLinkage	 WITH(NOLOCK)
		--FROM SEO_MART.dbo.RPT_T5StudentAssignment
		--WHERE SchoolYear = (SELECT LookupValue FROM SEO_MART.dbo.lk_SEOBusinessRules WHERE LookupCategory = 'T5Wave' AND LookupName = 'T5SchoolYear')
		--	AND ActiveFlag = 'Y'
		GROUP BY T5IEPTeam, T5IEPTeamLanguage,WaveID, WaveDate 
	) asg
ON c.T5IEPTeam=asg.T5IEPTeam
	AND COALESCE(c.T5IEPTeamLanguage,'') = COALESCE(asg.T5IEPTeamLanguage,'')
	--AND w.WaveDate = asg.WaveDate






GO


