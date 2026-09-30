USE [SEO_REPORTING]
GO

/****** Object:  View [BI].[vw_T5Dashboard_CaseAssignmentProcessingSummary]    Script Date: 4/6/2026 1:35:29 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO














/*========================================================================================================
View: [BI].[vw_T5Dashboard_CaseAssignmentProcessingSummary]
Sample call: select * from SEO_REPORTING.[BI].[vw_T5Dashboard_CaseAssignmentProcessingSummary] order by WaveID,StudentID
Purpose: To  illustrate students excluded from T5 case assignment with exclusion reason 
      + To illustrate active students included in T5 case assignment to-date with critical fields for reporting per business requirements. 
View to be used as base for new tab in PowerBI dashboard.
Assignments considerate of reassignments/inactivations.
File also includes each student’s SendT5Letter flag and T5ZonedDBNNoAssignmentReasons per business logic
	[SendT5Letter]
		--NO = any of the following 
			--Student residing in Choice District (i.e. HomeDistrict=1,HomeDistrict=7, or HomeDistrict=23) 
			--Student is located in unshared zone and assigned to school indicated on KZonedESDBNsList
		--TBD= any of the following
			--Student is located in shared zone and assigned to at least 1 of the schools indicated on the KZonedESDBNsList 
			--Student is not assigned to their zoned school  
			--Student address is invalid
			--All else

Date Created: 12/22/2025

ModificatiON Details:

Author		ModifiedDate		Comments
Ariel H		 12/22/2025			Initial View created by UNIONING T5AssignmentLogic with RPT_T5WaveIneligibleStudents for KIP Processing Summary underlying data
Ariel H      01/05/2026         Ineligible table is a merge, not truncate and load. Pull latest data only.
Ariel H      01/12/2026         Exclude students where NSA.ReasonDesc<>'Not in DWH_T5SourceExtract' as these are students dropped from ATLAS completely
Charlotte W  01/13/2026
                                Key fixes applied (per your request):
                                1) FIX compile errors by replacing missing columns from T5 (ReferralLinkage) with REG (StudentRegister):
                                   - D75Flag, IsTop, IsBottom, IsSibling, SiblingKey, GuardianEmail

                                2) BRING IN these fields “like [BI].[vw_T5Dashboard_Referrals_Latest_v2] did” by joining to:
                                   SEO_REPORTING.BI.vw_T5Dashboard_Referrals_Latest_v2 (alias RF)
                                   - WaveAssignmentFlag
                                   - ELLStatus
                                   - EthnicityCC
                                   - TemporaryHousingStatus   
                                   - [Requires Bilingual Psych]    

                                3) Ensure UNION schema alignment by adding the same columns (same order, same names) to BOTH CTEs.

                                Notes:
                                - For Assigned records, ELLStatus is set as COALESCE(T5.ELLStatus, RF.ELLStatus) to be resilient.
                                - For Ineligible records, ELLStatus is pulled from RF when available.
Ariel H      01/16/2026        - Change source for Assignment critical fields from REG to back to StudentAssignment
                               - Add IsLanguageMatch
                               - Change T5RecordSource to ATLAS for CAP records
Ariel H      02/02/2026	       Corrected WaveAssignmentFlag to WaveAssignedFlag + Added AssignmentProcess added to clearly distinguish between Wave Assigned, Walk-Ins, and Ineligible students
Ariel H      02/06/2026        Per Lauren DiLorenzo request to include ATS info for ineligible population, fields not avail in assignment data set to NULL for assign block
                                   --renamed ATSPreKSchoolDBN to ATSSchoolDBN 
                                   --added ATSPhysicalLocation
                                   --renamed PreKD75PhysicalDBN as ATSD75PhysicalDBN 
                                   --added GradeLevel
                                   --renamed CSE to HomeCSE
                                   --added CSESchoolDBN
Ariel H      02/27/26          Comment out INNER JOIN in ATS query so CSESchooLDBN appears for all records
Ariel H      03/04/36          Added CTE for SESIS to include ELLStatus and Ethnicity logic for inactivated students, Added CTE for assigned population to include inactivated studetns
========================================================================================================*/

CREATE VIEW [BI].[vw_T5Dashboard_CaseAssignmentProcessingSummary]
AS

WITH

ATS AS
(
    SELECT a.StudentID,
                   a.SchoolDBN,
                   [Status],
                   GradeLevel,
			       DHS,
			       ATSPhysicalLocation,
                   c.CSEDistrict,
                   cse.CSESchoolDBN,
                   ELLStatus,
                   Ethnicity
            FROM SEO_MART.dbo.INT_ATSStudents a WITH (NOLOCK)
            /* Query for only records in CAP extract. */
            --INNER JOIN SEO_MART.dbo.DWH_T5SourceExtract	b ON a.StudentID=b.StudentID
            LEFT JOIN SEO_MART.dbo.RPT_Locations c ON a.SchoolDBN=c.SchoolDBN
                    LEFT JOIN 
        (SELECT 
        CSESchoolDBN 
        ,CSEDistrict
        FROM SEO_MART.dbo.lk_CSECapacity with(nolock) 
        )cse
        ON c.CSEDistrict=cse.CSEDistrict
                    WHERE Status='A'
),

--Added to create Ethnicity and ELLStatus filter
SESIS as
(SELECT 
    StudentID,
    Ethnicity,
    ELLStatus
FROM SEO_MART.dbo.DWH_SESISStudents	S with(nolock)
WHERE S.IsDelete = 0
),

W1ProcessedDate AS
(
    SELECT ProcessedDate AS W1ProcessedDate
    FROM SEO_MART.dbo.INT_T5WaveSchedule WITH (NOLOCK)
    WHERE WaveID = 1
),

CleanAddress AS
(
    SELECT
          StudentID
        , REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(HouseNumber)),'"',''),'  ',' '),'   ',' '),'    ',' '),CHAR(9),' '),CHAR(10),' '),CHAR(13),' ') AS HouseNumber
        , REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(Street))    ,'"',''),'  ',' '),'   ',' '),'    ',' '),CHAR(9),' '),CHAR(10),' '),CHAR(13),' ') AS Street
        , BoroughCode
        , ZipCode
    FROM SEO_MART.dbo.INT_T5WaveEligibleStudents WITH (NOLOCK)
),

LanguageLookup AS
(
    SELECT
          SourceName
        , Code
        , CASE WHEN Code IS NULL THEN 'ENGLISH' ELSE LinkageLanguage END AS LinkageLanguage
    FROM SEO_MART.dbo.lk_LanguageCodes WITH (NOLOCK)
    WHERE SourceName = 'CAP'
       OR (SourceName = 'ATS' AND LinkageLanguage IN ('English','Other'))
),

LanguageLookupGuardian AS
(
    SELECT
          SourceName
        , Code
        , LinkageLanguage
    FROM SEO_MART.dbo.lk_LanguageCodes WITH (NOLOCK)
    WHERE SourceName = 'CAP'
),

--Added to include inactivated population
AssignmentInfo AS
(   SELECT * 
    ,NULL as T5InactivationReason
    FROM SEO_MART.dbo.RPT_T5StudentAssignment SA WITH (NOLOCK)
    WHERE SA.ActiveFlag='Y'
    
    --inactivations
    UNION ALL
    
    SELECT *
    ,CASE WHEN ModifiedReasons='No Disability' THEN 'SESIS Inactivated' ELSE ModifiedReasons END T5InactivationReason
    FROM SEO_MART.dbo.RPT_T5StudentAssignment SAI with(nolock)
    WHERE SAI.ActiveFlag='N'			--Inactivated
	      AND SAI.ModifiedReasons is not NULL --Only students with a inactivation and no corresponding activation will have a modified reason
	      AND SAI.ModifiedReasons not like '%Reassignment%'
),

AssignPriority AS
(
    SELECT
          StudentID
        , AssignmentPriorityTypeID
        , StudentCategory
        , AssignmentPriorityType
        , DBNPriorityType
        , DBNProximity
        , IsBilingualStudent
        , StudentLanguageCode
        , StudentLanguage
        , AssignmentLanguage
        , IsLanguageMatch
        , IsSibling
        , SiblingKey
        , DBNPriorityTypeDesc
        , DBNNoAssignmentReasons AS T5ZonedDBNNoAssignmentReasonDesc
    FROM
    (
        SELECT
              SA.StudentID
            , CASE WHEN ISA.StudentID IS NULL THEN ISA2.AssignmentPriorityTypeID ELSE ISA.AssignmentPriorityTypeID  END AS AssignmentPriorityTypeID
            , CASE WHEN ISA.StudentID IS NULL THEN ISA2.StudentCategory         ELSE ISA.StudentCategory            END AS StudentCategory
            , CASE WHEN ISA.StudentID IS NULL THEN ISA2.AssignmentPriorityType  ELSE ISA.AssignmentPriorityType     END AS AssignmentPriorityType
            , CASE WHEN ISA.StudentID IS NULL THEN ISA2.DBNPriorityType         ELSE ISA.DBNPriorityType            END AS DBNPriorityType
            , CASE WHEN ISA.StudentID IS NULL THEN ISA2.DBNProximity            ELSE ISA.DBNProximity               END AS DBNProximity
            , CASE WHEN ISA.StudentID IS NULL THEN ISA2.IsBilingualStudent      ELSE ISA.IsBilingualStudent         END AS IsBilingualStudent
            , CASE WHEN ISA.StudentID IS NULL THEN ISA2.StudentLanguageCode     ELSE ISA.StudentLanguageCode        END AS StudentLanguageCode
            , CASE WHEN ISA.StudentID IS NULL THEN ISA2.StudentLanguage         ELSE ISA.StudentLanguage            END AS StudentLanguage
            , CASE WHEN ISA.StudentID IS NULL THEN ISA2.AssignmentLanguage      ELSE ISA.AssignmentLanguage         END AS AssignmentLanguage
            , CASE WHEN ISA.StudentID IS NULL THEN ISA2.IsLanguageMatch         ELSE ISA.IsLanguageMatch            END AS IsLanguageMatch
            , CASE WHEN ISA.StudentID IS NULL THEN ISA2.IsSibling               ELSE ISA.IsSibling                  END AS IsSibling
            , CASE WHEN ISA.StudentID IS NULL THEN ISA2.SiblingKey              ELSE ISA.SiblingKey                 END AS SiblingKey
            , P.DBNPriorityTypeDesc
            , CASE WHEN ISA.StudentID IS NULL THEN ISA2.DBNNoAssignmentReasons   ELSE ISA.DBNNoAssignmentReasons   END AS DBNNoAssignmentReasons
            , ROW_NUMBER() OVER
              (
                  PARTITION BY SA.StudentID
                  ORDER BY CASE
                              WHEN (CASE WHEN ISA.StudentID IS NULL THEN ISA2.DBNNoAssignmentReasons ELSE ISA.DBNNoAssignmentReasons END) IS NOT NULL
                                  THEN 1
                              ELSE 2
                           END
              ) AS rn
      --  FROM SEO_MART.dbo.RPT_T5ReferralLinkage T5 WITH (NOLOCK)
        FROM AssignmentInfo SA
        LEFT JOIN seo_mart.dbo.INT_T5StudentSchoolAssignment      ISA  WITH (NOLOCK) ON SA.StudentID = ISA.StudentID
        --LEFT JOIN seo_mart.arch.INT_T5StudentSchoolAssignment     ISA2 WITH (NOLOCK) ON SA.StudentID = ISA2.StudentID
        LEFT JOIN (SELECT *
                    , ROW_NUMBER() OVER
                              (
                                  PARTITION BY StudentID
                                  ORDER BY ProcessedDateTime desc --to account for re-runs
                                ) AS rn
                    FROM seo_mart.arch.INT_T5StudentSchoolAssignment     ISA2 WITH (NOLOCK)
                    )ISA2 ON RN=1 and SA.StudentID = ISA2.StudentID
        LEFT JOIN SEO_MART.dbo.lk_T5DBNPriorities                 P    WITH (NOLOCK)
            ON (CASE WHEN ISA.StudentID IS NULL THEN ISA2.DBNPriorityType ELSE ISA.DBNPriorityType END) = P.DBNPriorityType
    ) x
    WHERE rn = 1
),



ZoneCTE AS
(
    SELECT
          SA.StudentID
        , CASE WHEN IA.StudentID IS NOT NULL THEN 1 ELSE 0 END AS IsStudentAddressInvalid
        , CASE
              WHEN ZON1.KZonedDistrictID IN (0,1,7,23) OR ZON2.KZonedDistrictID IN (0,1,7,23)
                OR ZON3.KZonedDistrictID IN (0,1,7,23) OR ZON4.KZonedDistrictID IN (0,1,7,23)
                OR ZON5.KZonedDistrictID IN (0,1,7,23)
                  THEN 1
              ELSE 0
          END AS IsStudentAddressInNonZonedRegion
        , CASE WHEN ZON1.StudentID IS NOT NULL AND ZON2.StudentID IS NOT NULL THEN 1 ELSE 0 END AS IsStudentAddressInSharedZone
        , COALESCE(ZON1.KZonedDistrictID,ZON2.KZonedDistrictID,ZON3.KZonedDistrictID,ZON4.KZonedDistrictID,ZON5.KZonedDistrictID) AS KZonedDistrictID
        , ZON1.KZonedESDBN AS KZonedESDBN_1
        , ZON2.KZonedESDBN AS KZonedESDBN_2
        , ZON3.KZonedESDBN AS KZonedESDBN_3
        , ZON4.KZonedESDBN AS KZonedESDBN_4
        , ZON5.KZonedESDBN AS KZonedESDBN_5
        , CASE
              WHEN IA.StudentID IS NULL
               AND (
                        ZON1.KZonedDistrictID IN (0,1,7,23) OR ZON2.KZonedDistrictID IN (0,1,7,23)
                     OR ZON3.KZonedDistrictID IN (0,1,7,23) OR ZON4.KZonedDistrictID IN (0,1,7,23)
                     OR ZON5.KZonedDistrictID IN (0,1,7,23)
                     OR (ZON1.StudentID IS NOT NULL AND ZON2.StudentID IS NULL AND ZON1.KZonedESDBN = SSA.AssignedSchoolDBN)
                  )
                  THEN 'NO'
              ELSE 'TBD'
          END AS SendT5Letter
   -- FROM SEO_MART.dbo.RPT_T5ReferralLinkage T5 with(nolock)
    FROM AssignmentInfo SA
    LEFT JOIN seo_mart.dbo.INT_T5StudentSchoolAssignment SSA WITH (NOLOCK)
        ON SA.StudentID=SSA.StudentID
    LEFT JOIN seo_mart.arch.INT_T5StudentZoneSchool ZON1 WITH (NOLOCK)
        ON SA.StudentID = ZON1.StudentID
       AND ZON1.ESDBNSequence = 1
       AND ZON1.ArchiveDate >= (SELECT W1ProcessedDate FROM W1ProcessedDate)
    LEFT JOIN seo_mart.arch.INT_T5StudentZoneSchool ZON2 WITH (NOLOCK)
        ON SA.StudentID = ZON2.StudentID
       AND ZON2.ESDBNSequence = 2
       AND ZON2.ArchiveDate >= (SELECT W1ProcessedDate FROM W1ProcessedDate)
    LEFT JOIN seo_mart.arch.INT_T5StudentZoneSchool ZON3 WITH (NOLOCK)
        ON SA.StudentID = ZON3.StudentID
       AND ZON3.ESDBNSequence = 3
       AND ZON3.ArchiveDate >= (SELECT W1ProcessedDate FROM W1ProcessedDate)
    LEFT JOIN seo_mart.arch.INT_T5StudentZoneSchool ZON4 WITH (NOLOCK)
        ON SA.StudentID = ZON4.StudentID
       AND ZON4.ESDBNSequence = 4
       AND ZON4.ArchiveDate >= (SELECT W1ProcessedDate FROM W1ProcessedDate)
    LEFT JOIN seo_mart.arch.INT_T5StudentZoneSchool ZON5 WITH (NOLOCK)
        ON SA.StudentID = ZON5.StudentID
       AND ZON5.ESDBNSequence = 5
       AND ZON5.ArchiveDate >= (SELECT W1ProcessedDate FROM W1ProcessedDate)
    LEFT JOIN SEO_MART.dbo.DWH_T5StudentInvalidAddressFromLCGMS IA WITH (NOLOCK)
        ON SA.StudentID = IA.StudentID
),

T5Assignment AS
(
    SELECT DISTINCT
          SA.StudentID --T5.StudentID
        , REG.LastName --T5.LastName
        , REG.FirstName --T5.FirstName
        , REG.BirthDate --T5.BirthDate
        , REG.Gender --T5.Gender

        /* ===== NEW fields brought in for Referrals_Latest_v2 alignment, use logic instead of LJOIN for inactivated population ===== */
        , CASE WHEN SA.WaveID is null THEN 'N' ELSE 'Y' END AS WaveAssignedFlag   
        , CASE WHEN SA.WaveID is null THEN 'Walk-In' ELSE CONCAT('Wave ',reg.WaveID) END AS AssignmentProcess 
        , COALESCE(S.ELLStatus,ATS.ELLStatus)ELLStatus                        
        , eth.CCGrouping AS EthnicityCC                                            
        , CASE WHEN SA.[DHSDVFlag]='DHS' THEN 'Y'	
                WHEN SA.[DHSDVFlag] IS NULL	THEN 'N'
			END AS TemporaryHousingStatus                                                     --Dashboard filter, comes from SR for rest of dashboard         
        , CASE WHEN SA.[IsBilingual] = 1 THEN 'Y' ELSE 'N'	END AS [Requires Bilingual Psych] --Dashboard filter, comes from SR for rest of dashboard      

        , ISA.AssignmentPriorityTypeID
        , ISA.StudentCategory
        , ISA.AssignmentPriorityType

        , COALESCE(
            CASE
                WHEN ISA.DBNPriorityType LIKE '%NEAR%' THEN 'NEARESTDBN'
                WHEN CHARINDEX('-', ISA.DBNPriorityType) > 0
                    THEN LEFT(ISA.DBNPriorityType, CHARINDEX('-', ISA.DBNPriorityType)-1)
            END, ISA.DBNPriorityType
          ) AS AssignmentDBNPriorityType
        , ISA.DBNPriorityType AS AssignmentDBNPriorityTypeDetailed

        , SA.T5IEPTeam      --T5.T5IEPTeam
        , SA.T5IEPTeamType  --T5.T5IEPTeamType
        , SA.T5IEPTeamDesc  --T5.T5IEPTeamDesc
        , LEFT(SA.T5IEPTeam,2) AS T5IEPTeamDistrict  --LEFT(T5.T5IEPTeam,2) AS T5IEPTeamDistrict
        , ISA.DBNProximity     AS T5IEPTeamProximitytoHome

        --, T5.CaseType

       --, CASE
              --WHEN SA.ATSPrekSchoolDBN IN ('02M347','02M047')
              --  OR T5.GuardianLanguage = 'SX'
              --  OR T5.AssessmentBilLangCode = 'SX'
              --    THEN 1
         --, CASE WHEN SA.ATSPrekSchoolDBN LIKE '84%' THEN 1 ELSE 0 END AS IsPreKCharter
        --, CASE WHEN REG.D75Flag = 'Y' THEN 1 ELSE 0 END AS IsPreKD75
        --, CASE WHEN REG.IsTop = 1 OR REG.IsBottom = 1 THEN 1 ELSE 0 END AS IsPreKTopBottom
        --, CASE WHEN T5.DHSDVFlag = 'DV' THEN 1 ELSE 0 END AS IsStudentDV
        --, REG.IsCSETrueInitial AS IsStudentCSETrueInitial
        --, CASE WHEN T5.DHSDVFlag = 'DHS' THEN 1 ELSE 0 END AS IsStudentDHS
         --, T5.IsBilingual AS IsStudentBilingual
        --, T5.AssessmentBilLangCode
          --  , T5.IsBilingual AS IsStudentBilingual

        , SA.CaseType
        , CASE WHEN ISA.StudentCategory='ASL' THEN 1 ELSE 0 END AS IsPreKASL
        , CASE WHEN ISA.StudentCategory='Charter' THEN 1 ELSE 0 END AS IsPreKCharter
        , CASE WHEN ISA.StudentCategory='D75' THEN 1 ELSE 0 END AS IsPreKD75
        , CASE WHEN ISA.StudentCategory='TopBottom' THEN 1 ELSE 0 END AS IsPreKTopBottom
        , CASE WHEN ISA.StudentCategory= 'DV' THEN 1 ELSE 0 END AS IsStudentDV
        , Z.IsStudentAddressInvalid
        , CASE WHEN ISA.StudentCategory= 'CSETrueInitial' THEN 1 ELSE 0 END AS IsStudentCSETrueInitial
        , CASE WHEN ISA.StudentCategory= 'DHS' THEN 1 ELSE 0 END AS IsStudentDHS

        , ISA.IsBilingualStudent AS IsStudentBilingual
        --, T5.AssessmentBilLangCode
        --, lang1.LinkageLanguage AS AssessmentLangDescription
        --, T5.GuardianLanguage AS GuardianLangCode
        --, lang2.LinkageLanguage AS GuardianLangDescription
        --, T5.T5IEPTeamLanguage
        , ISA.StudentLanguageCode
        , ISA.StudentLanguage 
        , ISA.AssignmentLanguage AS T5IEPTeamLanguage
        , CASE WHEN ISA.StudentLanguage = 'English' and ISA.AssignmentLanguage='English' THEN 1 ELSE ISA.IsLanguageMatch END IsLanguageMatch

        --, REG.IsSibling AS IsStudentSibling
        --, REG.SiblingKey
        , ISA.IsSibling AS IsStudentSibling
        , ISA.SiblingKey

        , REG.GuardianLastName--T5.GuardianLastName
        , REG.GuardianFirstName--T5.GuardianFirstName
        , REG.GuardianPhoneNumber--T5.GuardianPhoneNumber

        /* FIXED: GuardianEmail from REG */
        , UPPER(LTRIM(RTRIM(REG.GuardianEmail))) AS GuardianEmail

       /*Following values do not exist in the assignment tables*/
        , REG.PreviousClassificationCode
        , REG.EvaluationDesc
        , REG.FirstPDConsentedForSVCSDate
        , REG.IEPConferenceDate
        , REG.FirstPDConfDate
        , REG.CaseCloseReasonCode

        , SA.ATSPreKSchoolDBN ATSSchoolDBN --02/06/26 renamed per Lauren DiLorenzo request
        , NULL ATSPhysicalLocation --02/06/26 added per Lauren DiLorenzo request, not avail in assignmnt data for non-D75s
        , CASE WHEN LEFT(SA.ATSPreKSchoolDBN,2)='75' THEN SA.ATSPreKSchoolDBN ELSE NULL END AS ATSD75PhysicalDBN --02/06/26 renamed per Lauren DiLorenzo request
        , NULL as GradeLevel          --02/06/26 added per Lauren DiLorenzo request for ineligible, not avail in assignmnt data
        , NULL CSESchoolDBN -- 02/06/26 added per Lauren DiLorenzo request, not avail in assignmnt data
        
        , CA.HouseNumber
        , CA.Street
        , CA.BoroughCode
        , CA.ZipCode
        --, REG.HomeDistrict
        --, REG.CSE
        , SA.HomeDistrict
        , SA.CSE HomeCSE --02/06/26 renamed per Lauren DiLorenzo request

        , Z.IsStudentAddressInNonZonedRegion
        , Z.IsStudentAddressInSharedZone
        , Z.KZonedDistrictID
        , Z.KZonedESDBN_1
        , Z.KZonedESDBN_2
        , Z.KZonedESDBN_3
        , Z.KZonedESDBN_4
        , Z.KZonedESDBN_5

        , CASE
              WHEN Z.KZonedESDBN_1 IS NULL AND ISA.DBNPriorityType LIKE '%NEAR%'
                  THEN 'Solely eligible for NEARESTDBN assignment'
              ELSE ISA.DBNPriorityTypeDesc
          END AS AssignmentDBNPriorityTypeDesc

        , ISA.T5ZonedDBNNoAssignmentReasonDesc
        , Z.SendT5Letter

        /* Ineligible fields (NULL for Assigned side) */
        , NULL AS T5IneligibleReason
        , NULL AS T5IneligibleReasonDesc
        , SA.T5InactivationReason   --added 03/03/26

        , SA.WaveID--T5.WaveID
        , COALESCE(T5.ProcessedDate,SA.ProcessedDate)ProcessedDate
        , SA.WaveDate--T5.WaveDate
        , SA.ReAssignmentDate--T5.ReassignmentDate
        ,  CASE WHEN SA.T5RecordSource='CAP' THEN 'ATLAS' ELSE SA.T5RecordSource END AS T5RecordSource--CASE WHEN T5.T5RecordSource='CAP' THEN 'ATLAS' ELSE T5.T5RecordSource END AS T5RecordSource 
        , SA.ActiveFlag           --added 03/03/26

    FROM AssignmentInfo SA
    LEFT JOIN SEO_MART.dbo.RPT_T5ReferralLinkage T5 WITH (NOLOCK) ON SA.StudentID = T5.StudentID -- switch join so base is coming from assignment table
    --FROM SEO_MART.dbo.RPT_T5ReferralLinkage T5 WITH (NOLOCK)

    --/* Join to studentassignment for assignment info not in linkage table/info required to remain static */
    --LEFT JOIN AssignmentInfo SA WITH (NOLOCK)
    --    ON SA.StudentID = T5.StudentID AND SA.ActiveFlag='Y'

    LEFT JOIN AssignPriority ISA WITH (NOLOCK)
        ON SA.StudentID = ISA.StudentID

    LEFT JOIN SEO_MART.dbo.RPT_T5StudentRegister REG WITH (NOLOCK)
        ON SA.StudentID = REG.StudentID

    LEFT JOIN CleanAddress CA
        ON SA.StudentID = CA.StudentID

    LEFT JOIN LanguageLookup lang1
        ON REG.AssessmentBilLangCode = lang1.Code
        OR (REG.AssessmentBilLangCode IS NULL AND lang1.Code IS NULL)

    LEFT JOIN LanguageLookupGuardian lang2
        ON REG.GuardianLanguage = lang2.Code

    LEFT JOIN ZoneCTE Z
        ON SA.StudentID = Z.StudentID

    LEFT JOIN ATS ats
        ON SA.StudentID=ats.StudentID --added 02/06/26

    LEFT JOIN SESIS S
        ON SA.StudentID=S.StudentID

    LEFT JOIN (
		SELECT DISTINCT CCGrouping
			,Description
		FROM SEO_MART.dbo.lk_EthnicityCodes	WITH(NOLOCK)
		) eth
		ON COALESCE(S.Ethnicity,ats.Ethnicity) = eth.Description

    /* ===== NEW: bring the same fields Referrals_Latest_v2 uses ===== */
    --LEFT JOIN SEO_REPORTING.BI.vw_T5Dashboard_Referrals_Latest_v2 RF WITH (NOLOCK)
    --    ON RF.StudentID = SA.StudentID
),


T5NoAssignment AS
(
    SELECT DISTINCT
          NSA.StudentID
        , COALESCE(REG.LastName, Err.LastName) AS LastName
        , COALESCE(REG.FirstName, Err.FirstName) AS FirstName
        , COALESCE(REG.BirthDate, Err.BirthDate) AS BirthDate
        , COALESCE(REG.Gender, Err.Gender) AS Gender

        /* ===== NEW fields brought in like Referrals_Latest_v2 ===== */
        , NULL as WaveAssignedFlag
        , 'Unassigned'                   AS AssignmentProcess
        , COALESCE(S.ELLStatus,ATS.ELLStatus) AS ELLStatus                        
        , eth.CCGrouping AS EthnicityCC       
        , NULL      AS TemporaryHousingStatus      
        , NULL  AS [Requires Bilingual Psych]    

        , NULL AS AssignmentPriorityTypeID
        , NULL AS StudentCategory
        , NULL AS AssignmentPriorityType

        , NULL AS AssignmentDBNPriorityType
        , NULL AS AssignmentDBNPriorityTypeDetailed

        , NULL AS T5IEPTeam
        , NULL AS T5IEPTeamType
        , NULL AS T5IEPTeamDesc
        , NULL AS T5IEPTeamDistrict
        , NULL AS T5IEPTeamProximitytoHome

        , REG.CaseType

        , CASE
              WHEN REG.ATSPrekSchoolDBN IN ('02M347','02M047')
                OR REG.GuardianLanguage='SX'
                OR REG.AssessmentBilLangCode='SX'
                  THEN 1
              WHEN REG.ATSPrekSchoolDBN IS NULL THEN NULL
              ELSE 0
          END AS IsPreKASL

        , CASE
              WHEN REG.ATSPrekSchoolDBN LIKE '84%' THEN 1
              WHEN REG.ATSPrekSchoolDBN IS NULL THEN NULL
              ELSE 0
          END AS IsPreKCharter

        , CASE
              WHEN REG.D75Flag='Y' THEN 1
              WHEN REG.D75Flag IS NULL THEN NULL
              ELSE 0
          END AS IsPreKD75

        , CASE
              WHEN REG.IsTop=1 OR REG.IsBottom=1 THEN 1
              WHEN REG.IsTop IS NULL AND REG.IsBottom IS NULL THEN NULL
              ELSE 0
          END AS IsPreKTopBottom

        , CASE
              WHEN REG.DHSDVFlag='DV' THEN 1
              WHEN REG.DHSDVFlag IS NULL THEN NULL
              ELSE 0
          END AS IsStudentDV

        , NULL AS IsStudentAddressInvalid
        , REG.IsCSETrueInitial AS IsStudentCSETrueInitial

        , CASE
              WHEN REG.DHSDVFlag='DHS' THEN 1
              WHEN REG.DHSDVFlag IS NULL THEN NULL
              ELSE 0
          END AS IsStudentDHS

        , REG.IsBilingual AS IsStudentBilingual
        --, REG.AssessmentBilLangCode
        --, lang1.LinkageLanguage AS AssessmentLangDescription
        --, REG.GuardianLanguage AS GuardianLangCode
        --, lang2.LinkageLanguage AS GuardianLangDescription
        ,CASE WHEN REG.AssessmentBilLangCode IS NULL THEN REG.GuardianLanguage ELSE REG.AssessmentBilLangCode END AS StudentLanguageCode
        ,CASE WHEN REG.AssessmentBilLangCode IS NULL THEN lang2.LinkageLanguage ELSE lang1.LinkageLanguage END AS StudentLanguage 
        ,NULL T5IEPTeamLanguage
        ,NULL IsLanguageMatch

        , REG.IsSibling AS IsStudentSibling
        , REG.SiblingKey

        , COALESCE(REG.GuardianLastName, Err.GuardianLastName) AS GuardianLastName
        , COALESCE(REG.GuardianFirstName, Err.GuardianFirstName) AS GuardianFirstName
        , COALESCE(REG.GuardianPhoneNumber, Err.GuardianPhoneNumber) AS GuardianPhoneNumber
        , UPPER(LTRIM(RTRIM(REG.GuardianEmail))) AS GuardianEmail

        , COALESCE(REG.PreviousClassificationCode, Err.PreviousClassificationCode) AS PreviousClassificationCode
        , REG.EvaluationDesc
        , REG.FirstPDConsentedForSVCSDate
        , REG.IEPConferenceDate
        , REG.FirstPDConfDate
        , REG.CaseCloseReasonCode

        , ATS.SchoolDBN ATSSchoolDBN --02/06/26 added per Lauren DiLorenzo request
        , ATS.ATSPhysicalLocation --02/06/26 added per Lauren DiLorenzo request
        , CASE WHEN LEFT(ATS.SchoolDBN,2)='75' THEN ATS.SchoolDBN ELSE NULL END AS ATSD75PhysicalDBN --02/06/26 added per Lauren DiLorenzo request
        , ATS.GradeLevel  --02/06/26 added per Lauren DiLorenzo request
        , ATS.CSESchoolDBN -- 02/06/26 added per Lauren DiLorenzo request

        , COALESCE(REG.HouseNumber, Err.HouseNumber) AS HouseNumber
        , COALESCE(REG.Street, Err.Street) AS Street
        , COALESCE(REG.BoroughCode, Err.BoroughCode) AS BoroughCode
        , COALESCE(REG.ZipCode, Err.Zip) AS ZipCode
        , COALESCE(REG.HomeDistrict, Err.HomeDistrict) AS HomeDistrict
        , COALESCE(REG.CSE, Err.CSE) AS HomeCSE --02/06/26 renamed per Lauren DiLorenzo request

        , NULL AS IsStudentAddressInNonZonedRegion
        , NULL AS IsStudentAddressInSharedZone
        , NULL AS KZonedDistrictID
        , NULL AS KZonedESDBN_1
        , NULL AS KZonedESDBN_2
        , NULL AS KZonedESDBN_3
        , NULL AS KZonedESDBN_4
        , NULL AS KZonedESDBN_5

        , NULL AS AssignmentDBNPriorityTypeDesc
        , NULL AS T5ZonedDBNNoAssignmentReasonDesc
        , 'NO' AS SendT5Letter

        /* Ineligible reason logic (your existing logic preserved) */
        , CASE
              WHEN NSA.ReasonCategory = 'ATLASErrorFile' THEN NSA.ReasonCategory
              ELSE NSA.ReasonDesc
          END AS T5IneligibleReason
        , NSA.ReasonDesc AS T5IneligibleReasonDesc
        , NULL T5InactivationReason

        , REG.WaveID
        , COALESCE(REG.ProcessedDate, Err.Load_Date) AS ProcessedDate
        , REG.WaveDate
        , NULL AS ReassignmentDate
        , CASE WHEN REG.T5RecordSource='CAP' THEN 'ATLAS' ELSE ISNULL(REG.T5RecordSource,'ATLAS') END AS T5RecordSource

        ,'N' as ActiveFlag

    FROM SEO_MART.dbo.RPT_T5WaveIneligibleStudents NSA WITH (NOLOCK)
    LEFT JOIN SEO_MART.dbo.RPT_T5StudentRegister REG WITH (NOLOCK)
        ON NSA.StudentID = REG.StudentID
    LEFT JOIN SEO_MART.dbo.DWH_T5SourceKIPDataErrors Err WITH (NOLOCK)
        ON NSA.StudentID = Err.STUDENTID
    LEFT JOIN LanguageLookup lang1
        ON REG.AssessmentBilLangCode = lang1.Code
        OR (REG.AssessmentBilLangCode IS NULL AND lang1.Code IS NULL)
    LEFT JOIN LanguageLookupGuardian lang2
        ON REG.GuardianLanguage = lang2.Code

    /* Exclude if they exist in assigned set */
    LEFT JOIN T5Assignment T5 WITH (NOLOCK)
        ON NSA.StudentID = T5.StudentID

    LEFT JOIN ATS ats
        ON NSA.StudentID=ats.StudentID

    LEFT JOIN SESIS S
        ON NSA.StudentID=S.StudentID

    LEFT JOIN (
		SELECT DISTINCT CCGrouping
			,Description
		FROM SEO_MART.dbo.lk_EthnicityCodes	WITH(NOLOCK)
		) eth
		ON COALESCE(S.Ethnicity,ats.Ethnicity) = eth.Description

    WHERE T5.StudentID IS NULL
      AND NSA.ETLProcessedDate = (SELECT MAX(ETLProcessedDate) FROM SEO_MART.dbo.RPT_T5WaveIneligibleStudents WITH (NOLOCK))
      AND NSA.ReasonDesc <> 'Not in DWH_T5SourceExtract' --This population was relevant only during W2 post-testing and excluded to avoid business confusion
)

--Drop table #testT5
--SELECT * FROM T5Assignment where T5InactivationReason is NULL
SELECT *
--INTO #testT5
FROM
(
    SELECT * FROM T5Assignment
    UNION
    SELECT * FROM T5NoAssignment
) a
/*
SELECT ATSSchoolDBN,ATSPhysicalLocation,GradeLevel,CSESchoolDBN
FROM #test
WHERE T5IneligibleReason='KG in a charter school in ATS'
*/
;
GO


