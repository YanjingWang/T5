USE [SEO_REPORTING]
GO

/****** Object:  View [BI].[vw_T5Dashboard_CumulativeCapacity]    Script Date: 4/6/2026 1:37:20 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO















CREATE VIEW [BI].[vw_T5Dashboard_CumulativeCapacity]
/****************************************************************************************************************************************************************************************************************
Object Name: dbo.vw_T5Report_CapacityUtilizationByIEPTeam_Cumulative
Sample call: Select * from SEO_REPORTING.BI.vw_T5Dashboard_CumulativeCapacity order by T5IEPTeam
Purpose: Generate cumulative school level capacity utilization metrics for T5 business users.
	This request came from Arwina, Andrea, Amy

Date Created: 1/25/2024

ModificatiON Details:

Author		ModifiedDate		Comments
Raji M		1/25/2024			Initial
Ariel H		2/1/2024			Redo script. Capacity to be calculated based on RPT_T5StudentAssignment.
Ariel H		2/2/2024			Addtl fields added per Business Team request (GeographicaDistrict,OverassignmentReason,T5IEPTeamType)
Ariel H		2/5/2024			Correct script so file includes overassignments from previous week's file
Ariel H		3/6/2024			Update per vwRPT_T5CaseAssignmentCapacity update to include AdminDistrict and T5District
Ariel H		9/18/2024			No content change, address formatting for better readability
Ariel H		2/12/2025			Add T5IEPTeamLanguage to report and edit calc fields logic
Prem B      2/19/2025			Updated code block "Capacity of sites with capacity in latest POS AND have 0 active assignments"
Ariel H		3/5/2025			Update overassignment reasons now that ReassignmentList received
Ariel H		3/6/2025			Moved old script to retired schema, script requires update per new SEO_MART capacity table structure
Maneesh V	3/6/2025			Modified script to use SEO_MART.DBO.RPT_T5STUDENTASSIGNMENT and SEO_MART.DBO.RPT_POSPSYCHDAYSBYDBNANDLANGUAGE
								as base tables.
Ariel H		4/4/2025			Add  e.LocationCategoryDescription NOT IN ('K-12 all grades','Elementary','K-8','Early Childhood') THEN 0 to AvailCapacity and CaseAssignmentCapacity metric
Ariel H		4/9/2025			Add T5Awaiting to indicate IsTurning5 students in register not processed in Wave
Ariel H		06/11/2025			Change reference from RPT_T5SA to RPT_T5RL per addition of WaveDate,WaveID,and T5IEPTeamLanguage + Add lookup for CSESchoolDBN
Ariel H		06/16/2025			Add a GETDATE() so T5Awaiting populates as 0 as of the Final WaveDate
Ariel H		06/18/2025          Add WaveAssignedFlag per RPT_T5ReferralLinkage enhancement
Ariel H		06/24/2025			Rename to SEO_REPORTING.BI.vw_T5Dashboard_CumulativeCapacity
Charlotte W 01/16/2025          OverAssignedCNT = ABS(TotalCapacity - AssignedCapacity)
***************************************************************************************************************************************************************************************************************/
AS


SELECT DISTINCT
		 UPPER(CASE WHEN A.T5IEPTEAM IS NULL	
			  THEN D.SCHOOLDBN
			  ELSE A.T5IEPTEAM
		 END) [T5IEPTeam]
		, ISNULL(WAVEASSIGNEDFLAG,'N')WaveAssignedFlag
		, UPPER(CASE WHEN A.T5IEPTeam IS NULL 	
			  THEN D.[LANGUAGE] 
			  ELSE A.T5IEPTEAMLANGUAGE 
		 END) [T5IEPTeamLanguage]
		, CASE WHEN C.GEOGRAPHICALDISTRICT IS NULL
			  THEN E.GEOGRAPHICALDISTRICT
			  ELSE C.GEOGRAPHICALDISTRICT
		 END [GeographicalDistrict]		
		, CASE WHEN C.ADMINDISTRICT IS NULL
			  THEN E.ADMINDISTRICT
			  ELSE C.ADMINDISTRICT
		 END [AdminDistrict]
		, CASE WHEN T5IEPTEAM NOT LIKE '%CS%' 
					AND (
						CASE WHEN C.ADMINDISTRICT IS NULL
							  THEN E.ADMINDISTRICT
							  ELSE C.ADMINDISTRICT
						 END 
						) IS NOT NULL 
					AND ((CASE WHEN C.ADMINDISTRICT IS NULL
							  THEN E.ADMINDISTRICT
							  ELSE C.ADMINDISTRICT
						 END )<>(CASE WHEN C.GEOGRAPHICALDISTRICT IS NULL
									  THEN E.GEOGRAPHICALDISTRICT
									  ELSE C.GEOGRAPHICALDISTRICT
								 END)
						) 
					AND (CASE WHEN C.ADMINDISTRICT IS NULL
							  THEN E.ADMINDISTRICT
							  ELSE C.ADMINDISTRICT
						 END 
						)<>88 
			  THEN ( CASE WHEN C.ADMINDISTRICT IS NULL
						  THEN E.ADMINDISTRICT
						  ELSE C.ADMINDISTRICT
					 END) 
			  ELSE (CASE WHEN C.GEOGRAPHICALDISTRICT IS NULL
						  THEN E.GEOGRAPHICALDISTRICT
						  ELSE C.GEOGRAPHICALDISTRICT
					 END)
		 END [T5District]

		, CASE WHEN D.SCHOOLDBN LIKE '%CS%' AND [T5IEPTEAMTYPE] IS NULL
			  THEN 'CSE IEP TEAM'
			  WHEN D.SCHOOLDBN NOT LIKE '%CS%' AND [T5IEPTEAMTYPE] IS NULL
			  THEN 'SCHOOL-BASED IEP TEAM'
			  ELSE UPPER([T5IEPTEAMTYPE])
		 END [T5IEPTeamType]

		, CASE WHEN e.LocationCategoryDescription NOT IN ('K-12 all grades','Elementary','K-8','Early Childhood') THEN 0
			  WHEN A.T5IEPTEAMTYPE LIKE 'CSE%'	AND WaveAssignedFlag='Y'  THEN ISNULL(B.CASEASSIGNMENTCAPACITY,0)
			  WHEN A.T5IEPTEAMTYPE LIKE 'CSE%'	AND WaveAssignedFlag='N'  THEN 0 --Summer capacity may differ, requires business input to modify
			  ELSE ISNULL(FLOOR(D.POSPSYCHDAYS*7),0) 
			END [CaseAssignmentCapacity]

		, ISNULL(A.ASSIGNEDCAPACITY,0) [AssignedCapacity]

		, CASE WHEN e.LocationCategoryDescription NOT IN ('K-12 all grades','Elementary','K-8','Early Childhood') THEN 0
			  WHEN A.T5IEPTEAMTYPE LIKE 'CSE%'	
			  THEN ISNULL(B.AVAILABLECAPACITY,0)
			  WHEN ISNULL(FLOOR(D.POSPSYCHDAYS*7),0) - ISNULL(A.ASSIGNEDCAPACITY,0) <0 THEN 0
		      ELSE ISNULL(FLOOR(D.POSPSYCHDAYS*7),0) - ISNULL(A.ASSIGNEDCAPACITY,0) 
		 END [AvailableCapacity]
		
		, ISNULL(T5Awaiting,0)T5Awaiting
		
		, CASE WHEN A.T5IEPTEAM = '02M347'
           OR A.T5IEPTEAMTYPE LIKE 'CSE%'
           OR WaveAssignedFlag = 'N'  -- Summer capacity may differ, requires business input to modify
           OR e.LocationCategoryDescription NOT IN ('K-12 all grades','Elementary','K-8','Early Childhood')
        THEN 0

        -- TotalCapacity for school-based teams is FLOOR(POSPSYCHDAYS*7)
        WHEN ISNULL(A.ASSIGNEDCAPACITY,0) > ISNULL(FLOOR(D.POSPSYCHDAYS*7),0)
        THEN ISNULL(A.ASSIGNEDCAPACITY,0) - ISNULL(FLOOR(D.POSPSYCHDAYS*7),0)

        ELSE 0
        END AS [OverAssignedCNT]



		, CASE WHEN A.T5IEPTEAM = '02M347'
			  THEN '100.000000000000000000000000'
			  WHEN A.T5IEPTEAMTYPE LIKE 'CSE%' OR WaveAssignedFlag='N'	THEN 'NA' --Summer capacity may differ, requires business input to modify
			  WHEN ISNULL(A.ASSIGNEDCAPACITY,0)> ISNULL(FLOOR(D.POSPSYCHDAYS*7),0)
									--(
									--	CASE WHEN A.T5IEPTEAMTYPE LIKE 'CSE%'	
									--			THEN ISNULL(B.CASEASSIGNMENTCAPACITY,0)
									--			ELSE ISNULL(FLOOR(D.POSPSYCHDAYS*7),0) 
									--	END
									--	)
			  THEN '>100' 
			  WHEN 
					CASE WHEN A.T5IEPTEAMTYPE LIKE 'CSE%' 
						 THEN ISNULL(B.CASEASSIGNMENTCAPACITY,0)
						 ELSE ISNULL(FLOOR(D.POSPSYCHDAYS*7),0) 
					END = 0 
			  THEN '0'
			  ELSE LTRIM(ROUND((ISNULL(A.ASSIGNEDCAPACITY,0)/ISNULL(FLOOR(D.POSPSYCHDAYS*7),0)	
								--(
								--								CASE WHEN A.T5IEPTEAMTYPE LIKE 'CSE%'			
								--									 THEN ISNULL(
								--													CASE WHEN A.T5IEPTEAMTYPE LIKE 'CSE%'
								--														 THEN ISNULL(B.CASEASSIGNMENTCAPACITY,0)
								--														 ELSE ISNULL(FLOOR(D.POSPSYCHDAYS*7),0) 
								--													END
								--											  ,0)
								--									 ELSE ISNULL(FLOOR(D.POSPSYCHDAYS*7),0) 
								--								END
								--)
							   ) * 100.0,1
							  )
						) --ADD LTRIM SO FIELD CONVERTS TO VARCHAR FOR UNION
		 END PctT5CapacityUtilized 

		, CASE WHEN CAST(GETDATE() as Date)>=(Select Max(WaveDate) From SEO_MART.dbo.INT_T5WaveSchedule) THEN NULL
			  WHEN A.T5IEPTEAM = '02M347' OR WaveAssignedFlag='N'
				THEN NULL
			  WHEN ISNULL(A.ASSIGNEDCAPACITY,0)>0 AND 
				(CASE WHEN A.T5IEPTEAMTYPE LIKE 'CSE%'	
				 THEN ISNULL(B.CASEASSIGNMENTCAPACITY,0)
				  ELSE ISNULL(FLOOR(D.POSPSYCHDAYS*7),0) 
				  END)=0 
			   THEN 'POS DAYS DECREASE'
			WHEN ISNULL(A.ASSIGNEDCAPACITY,0)>(CASE WHEN A.T5IEPTEAMTYPE LIKE 'CSE%'	
			  THEN ISNULL(B.CASEASSIGNMENTCAPACITY,0)
			  ELSE ISNULL(FLOOR(D.POSPSYCHDAYS*7),0) 
		 END) THEN 'REASSIGNMENT' --'OTHER'
			ELSE NULL
			END OverassignmentReason
	--INTO ##VW_T5REPORT_CAPACITYUTILIZATIONBYIEPTEAM_CUMULATIVE_NEW --for testing
	FROM 
		(SELECT 
			*
			,COUNT(*)AssignedCapacity  
		FROM 
			(SELECT 
				COALESCE(ref.T5IEPTeam,ref.T5SchoolDBN,cse.CSESchoolDBN)T5IEPTeam --If not assigned via MIS/Analytics WAVE file, then Addtl Location else Home CSE
				,CASE WHEN (ref.T5IEPTeam is NULL AND ref.T5SchoolDBN LIKE '%CS%') OR (ref.T5IEPTeam is NULL AND ref.T5SchoolDBN is NULL) 
						THEN 'CSE IEP team' 
					WHEN ref.T5IEPTeam is NULL AND ref.T5SchoolDBN NOT LIKE '%CS%' THEN 'School-based IEP team' 
					ELSE ref.T5IEPTeamType
					END T5IEPTeamType			
				,CASE WHEN  (ref.T5IEPTeam is NULL AND ref.T5SchoolDBN LIKE '%CS%') OR (ref.T5IEPTeam is NULL AND ref.T5SchoolDBN is NULL) THEN 'CSE'
					WHEN ref.T5IEPTeam is NULL AND ref.T5SchoolDBN NOT LIKE '%CS%'	THEN NULL
					ELSE ref.T5IEPTeamLanguage
					END T5IEPTeamLanguage			
				,CASE WHEN ref.WaveID is not NULL THEN 'Y' ELSE 'N' END WaveAssignedFlag
			FROM SEO_MART.dbo.RPT_T5ReferralLinkage ref with(nolock)
			LEFT JOIN 
				(SELECT 
					CSESchoolDBN					 
					,CSEDistrict
				FROM seo_mart.dbo.lk_CSECapacity with(nolock) 
				)cse
				ON ref.CSE=cse.CSEDistrict
			)a 
		GROUP BY T5IEPTEAM,T5IEPTEAMTYPE,T5IEPTEAMLANGUAGE,WAVEASSIGNEDFLAG
		) A 
	LEFT JOIN SEO_MART.DBO.VWRPT_T5CASEASSIGNMENTCAPACITY B WITH(NOLOCK) 
		ON A.T5IEPTEAM=B.SCHOOLDBN
	LEFT JOIN SEO_MART.DBO.RPT_LOCATIONS C WITH(NOLOCK) 
		ON A.T5IEPTEAM=C.SCHOOLDBN
	FULL OUTER JOIN 
		(SELECT D.* 
		FROM SEO_MART.DBO.RPT_POSPSYCHDAYSBYDBNANDLANGUAGE D WITH(NOLOCK)
		INNER JOIN SEO_MART.dbo.DWH_T5OSEKinderGarten K WITH(NOLOCK) ON D.SchoolDBN=K.SchoolDBN
		)D
		ON A.T5IEPTEAM=D.SCHOOLDBN
		AND A.T5IEPTEAMLANGUAGE = D.[LANGUAGE]
		AND (D75SITE='' OR D75SITE IS NULL)
	LEFT JOIN SEO_MART.DBO.RPT_LOCATIONS E WITH(NOLOCK) 
		ON D.SCHOOLDBN=E.SCHOOLDBN
	LEFT JOIN (SELECT 
					CSESchoolDBN
					,CASE WHEN CAST(GETDATE() as Date)>=(Select Max(WaveDate) From SEO_MART.dbo.INT_T5WaveSchedule) 
					THEN 0 ELSE count(*) END T5Awaiting
				FROM SEO_MART.dbo.RPT_T5StudentRegister a with(nolock) 
				JOIN SEO_MART.dbo.lk_CSECapacity b with(nolock) 
					ON a.AssignedLocationForTracking=b.CSEDescription
				WHERE WaveID is NULL and IsTurning5=1
				GROUP BY CSESchoolDBN
			)F 
		ON A.T5IEPTeam=F.CSESchoolDBN
	WHERE 1=1
		AND ISNULL(A.T5IEPTEAM,'NA') NOT LIKE '75%'
		AND ISNULL(D.SCHOOLDBN,'NA') NOT LIKE '75%'
		AND ISNULL(D.SCHOOLDBN,'NA') <> '02M347'
		AND (NULLIF(D75SITE,'') is NULL) 

		
				

















GO


