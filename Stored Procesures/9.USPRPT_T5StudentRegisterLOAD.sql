USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPRPT_T5StudentRegisterLOAD]    Script Date: 4/4/2026 1:43:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[USPRPT_T5StudentRegisterLOAD]
AS
BEGIN
    
    SET NOCOUNT ON
/****************************************************************************************************************************************************************
Object Name: dbo.USPRPT_T5StudentRegisterLOAD
Sample call: EXEC USPRPT_T5StudentRegisterLOAD;
Purpose: It is used to populate RPT_T5StudentRegister data from CAP into SEO_MART. 
         Also, load the T5 -Students created directly in SESIS (after May 1st SY).
		 RPT_T5StudentRegister table merge eligible T5 student data from both CAP and SESIS.
Date Created: 12/06/2018

Modification Details:

Author					ModifiedDate		Comments
Nithya Guruprakash							Initial Draft - Populate T5_StudentRegister. Update only for kids who have not gone through the wave process
											Remove the hardcoded school Year once we decide on a way to make it dynamic
Nithya Guruprakash		12/28/2018			MIS-3579 SiblingKey added to the table
Nithya Guruprakash		02/07/2019			MIS-3684 Remove the LocationType check to determine the students' PreK Flag and PreK School
Nithya Guruprakash		03/27/2019			MIS-3801 Load the T5 - Students created directly in SESIS
Nithya Guruprakash		03/28/2019			MIS-3802 T5 Biog Delta File - Exclude students in Boro Y,Z and HomeDist 88,98,99
Raja M					07/25/2019			As per discussion happened during design sprint we decided to replace Source_SESISStudents with DWH_SESISStudents.
Pangajam Subburaja      11/07/2019          Recoding T5 as per data governance 2.0 standards and incorporate new business logic
Pangajam Subburaja      11/08/2019          Corrected Twinkey logic to concat string and text value
Pangajam Subburaja      11/15/2019          Rename source column NYCID/OSISID to StudentID,DOB to BirthDate, T5ProcessFlagInitial to IsTurning5
Pangajam Subburaja      11/18/2019          Rename Twinkey/Twinflag as SiblingKey/SiblingFlag and removed DOB from its logic.
Pangajam Subburaja      11/21/2019          Added archive logic. Archive only once a day all T5 students data.
Pangajam Subburaja      12/02/2019          As discussed, renamed Proc from T5_StudentRegisterLOAD to RPT_T5StudentRegisterLOAD
Pangajam Subburaja      12/03/2019          As discussed, replaced table from T5_Referral to RPT_T5Referral
Pangajam Subburaja      12/12/2019          Implemented new cleanup logic for city name and guardian phone number with new business logic
Pangajam Subburaja      12/13/2019          Updated logic for CaseType column to check for FirstPDConsentedForSVCSDate field value : 0,NULL or Empty
Pangajam Subburaja      12/13/2019          As discussed, Updated CAP home district(35) logic as two digit EG: 01,02,03 to 31,32,33,88,98,99 
Pangajam Subburaja      12/16/2019          Updated logic for guardian language for default value as 'EN' English
Raja M					04/30/2020			Updated Isturning5 flag for SESIS students to be populated from SESIS instead of calculating it again..
Raja M					05/18/2020			Updated ReferralDate for SESIS referrals to be picked from SESIS instead of CAP and 
											populated null for FirstPDConfDate instead of picking value from CAP for SESIS referrals.
Raja M					05/26/2020			Commented Activeflag = Y condition in Assignment table while picking the SESIS referrals not exists in assignment.
Raja M					08/11/2020			DWH_Referral table column is renamed from IsIDMergDelete to IsDelete..
Pangajam Subburaja      11/10/2019          Rollover as per 2.0 standard.
Pangajam Subburaja      11/10/2019          Added dynamic school year and birthdate calculation.
Pangajam Subburaja      03/08/2021          Updated address logic(HomeNumber, Street) for SESIS kids
Pangajam Subburaja      04/29/2021          Manual updated (T5 student register and referral linkage) to flag 31 shelter kids from (file driven) DWH_T5DHSShelters table
Pangajam Subburaja      05/05/2021          Manual updated (T5 student register and referral linkage) to flag  8 shelter kids from SEO_MART.dbo.INT_ATSStudents table
Pangajam Subburaja      05/07/2021          Added logic to flag shelter kids from SEO_MART.dbo.INT_ATSStudents table
Raja M					11/17/2021			Rolled over the structure to new school year and automated the Schoolyear calculation..
Christopher Agwu		10/25/2022			Added code for SchoolYear, Birthdate, FirstPDConfDateYear dates Lookup 		
Christopher Agwu		12/07/2022			Added IsBilingual,IsPOSLanguage columns to RPT_T5StudentRegister. See JIRA ticket MIS-8819
Christopher Agwu		12/29/2022			Added new logic for T5INITIAL. See JIRA ticket MIS-8866 for details.
Christopher Agwu		01/20/2023			Reverse T5INITIAL logic to original logic. See JIRA ticket MIS-8926 for details.
											Removed T5INITIAL logic code for ticket MIS-8866
Christopher Agwu		02/07/2023			Update IsPOSLanguage is not update IsBilling when EN. Rearranged code to fix issue by not filter by language. 
Sergey Gavryushenko		02/23/2023			Replaced lc.SourceName='T5CAP' with lc.SourceName='CAP' as T5CAP source for language codes is demised and replaced with CAP
Christopher Agwu		03/24/2023			MIS-9077:	DHSDVFLag indicator no longer indicates DV students as DWH_T5DVShelters is no longer used hence DV students shall be iditified with following logic
											Using: NoNameStreetFlag including expanded conditions, See JIRA ticket for details
Christopher Agwu		05/11/2023			Changed DWH_Referral table JOIN code to extract only the initial referral to ensure only 1 referral date is populated to RPT_StudentRegister table.
											UPDATE/INSERT error was encountered on (RPT_StudentRegister) due to multiple referral records hence this change. MIS-9196 
Christopher Agwu		05/18/2023			MIS-9164 - When student data is not available in CAPExtract and data is sourced from SESIS, student SiblingKey is blank.
											This update is to source SiblingKey data from SESIS when CAPExtract is not available.
Christopher Agwu		05/22/2023			RPT_T5SR SESIS students source are missing required data values such as (CSECode, AssignedLocationForTracking) when same student CAPExtract data is not available.
											MIS-9164 ticket is used to populate/source those columns from SESIS data.
											Changed get MaxArchiveDate code as previous code was retriving wrong maxc date due to unnecessary date conversion
											Hence change @MaxArchiveDate to DATE datatype and used with data datatype column of ArchiveDate.
Christopher Agwu		06/06/2023			MIS-9285 - On SESIS section of code, change HouseNumber, Street,BoroughCode,Zipcode, ApartmentNumnber source from CAPExtract.
											When CAPExtract record not exist then source from SESIS. This is so that student data is consistent with other columns such as NoNameStreetFlag.
Christopher Agwu		06/20/2023			Update SESIS BoroughCode to point to (LocationBoroughCode) columns.
Christopher Agwu		08/07/2023			MIS-9462 - New logic for IsBilingual indicator: 
											IsBilingual indicator will be set to 1 (TRUE) when student AssessmentLanguage is not english.
											If the student AssessmentLanguage is blank then use GuardianLanguage that is not english.
Christopher Agwu		09/08/2023			Modified ASL code section to exclude ASL population as BiLingual. JIRA Ticket MIS-9492
Christopher Agwu		09/21/2023			Added code to include(PRE-SCH-INITIAL) to IsTurning5 logic. JIRA Ticket MIS-9727  
Christopher Agwu		09/21/2023			Replaced CAP (CaseType) logic as requested in the JIRA ticket MIS-9728.
Christopher Agwu		09/29/2023			Added BirthDate Year in CAP IsTurning5 logic. Per JIRA Ticket MIS-9727.
Christopher Agwu		10/02/2023			Added new column (ModifiedReasons) to the archive script. No need to add to insert script. Per JIRA Ticket MIS-9826
Christopher Agwu		10/13/2023			Added new columns (WaveID,WaveDate) to the archive script. Per JIRA Ticket MIS-9911
Christopher Agwu		10/20/2023			Revert back (IsTurning5 logic) changes made in ticket MIS-9727.
Christopher Agwu		10/23/2023			Implemented new logic for SY24 (CaseType logic). See ticket MIS-9728 and Ariel comment of (October 20, 2023 at 9:03 AM)
Christopher Agwu		10/23/2023			Implemented new column and logic for (IsCSETrueInitial). See ticket MIS-9729.
Christopher Agwu		11/28/2023			Add code to implement (HomeDistrict>=1 and HomeDistrict<=32) condition on capextract section for IsTurning5=1. See JIRA Ticket MIS-9727.
Christopher Agwu		11/28/2023			Add TRIM fuction to all CAPEXTRACT HouseNumber and Street columns so blank-space are removed from these data. See JIRA Ticket MIS-10120.
Christopher Agwu		01/18/2024			(1) Remove filter code (AND WaveProcessedDate IS NULL) in UPDATE SET DHSDVFlag=DV so all students can be updated for students without DHS. 
											(2) SET DHSDVFlag=DV for studentid (257731133) in RPT_T5StudentRegister. See JIRA Ticket MIS-10468 
Christopher Agwu		05/14/2024			DWH_Referral table join includes multiple student referraldate which error out if encountered during existing student record update.
											The DWH_Referral table dataset should only contain referral record with maximum DocumentIDT. Therefore DocumentIDT will be added to join.
											See JIRA Ticket MIS-1165
Christopher Agwu		07/16/2024			Change SP to load DBO first then load archive data after. MIS-11490
Christopher Agwu		08/12/2024			Remove HomeDistrict 1-32 filter so that all HomeDistrict will be included. MIS-11626
Christopher Agwu		08/12/2024			Remove DWH_T5D75PrekEnrollment table and add ATSPhysicalLocation to ATS table. MIS-11644
Christopher Agwu		09/25/2024			Added DataValidation exec code. MIS-11488
Pcissthomas				09/25/2024			Commented out the lines using DWH_T5DVShelters. MIS-11906
Christopher Agwu		09/30/2024			Commented out BoroughCode for IsTurning5 logic because HomeDistrict outside 1-32 are now included.
Christopher Agwu		09/30/2024			Deployment to production.
Christopher Agwu		10/01/2024			Revert back BoroughCode script for IsTurning5 logic.
Christopher Agwu		10/01/2024			Commented HomeDistricts outside NYC to include then in the elig populate
Christopher Agwu		10/22/2024			Update D75Flag logic from StudentID to SchoolDBN Like 75%. MIS-12172
Christopher Agwu		10/23/2024			Populate CSE Value=00/AssignedLocationForTracking Value=CSE 00 for Non-D1-32 Students On Insert Only but not update. MIS-12186
Christopher Agwu		10/31/2024			Removed (Added DataValidation exec code. MIS-11488) from this SP. Will be a separate Job.
Christopher Agwu		11/27/2024			Replace T5CAPExtract source with (ATLAS) T5SourceExtract MIS-12295
Christopher Agwu		12/03/2024			Point source data (KIPData) to target table to RPT_T5SudentRegister MIS-12456
Christopher Agwu		12/09/2024			Point to Prod Source server to (ES00VPSEDAG001) to replace SEO_REPORTING MIS-12454
Christopher Agwu		03/26/2025			Add new column GuardianEmail to T5SR table and populated by KIPData. MIS-12976
Christopher Agwu		04/18/2025			Commented-out (ReferralTypeCode=1) to allow all DWH_Referral data to be joined to SESIS data.
											Commented-out (S.IsTurning5 = 1)   to all SESIS students to be evaluated. MIS-13151	
Christopher Agwu		04/22/2025			Force IsCSETrueInitial=1 for SESIS students. Per ticket MIS-13135
Raji					07/18/2025			Removed check on DWH_SESISStudents.SchoolYear = @SchoolYear
											You should not use SchoolYear column on DWH_SESISStudents. 
Christopher Agwu		07/22/2025			Walk-IN KIP Students (Opened directly in SESIS from June-August) are missing in RPT_T5StudentRegister. Modify SP to bring them in. MIS-13672
Christopher Agwu        09/25/2025          Replaced Staging.CitywidePOSDBN with RPT_POSPsychDaysByDBNandLanguage MIS-14282
Christopher Agwu        09/26/2025          Replace DWH_T5Shelter (DHS) with INT_ATSStudents
Charlotte Wang          12/10/2025          HardCoded T5RecordSource to ATLAS where it used be CAP or ATLAS
Raji                    12/12/2025          Exclude students who are enrolled in KG at a charter school by setting IsTurning5 to 0
Christopher Agwu        01/23/2026          Process/Load ATLAS students first before loading SESIS and Exclude SESIS students already listed as ATLAS. See ticket MIS-14873 
Michael                 02/25/2026          MIS-14446 .Modified reference DWH_T5DuplicateStudent to DWH_T5DuplicateStudentCorrection table
***************************************************************************************************************************************************************************************/
/**********Archive last wave student register data before wave run********/

DECLARE @SchoolStartDate DATE
DECLARE @Today DATETIME
DECLARE @SchoolYear VARCHAR(9), @KIPSYPart INT;
																					  
DECLARE @BirthYear INT;
DECLARE @FirstPDConfDateYear INT
DECLARE @FirstPDConfDateYearCSY VARCHAR(4), @FirstPDConfDateYearPSY VARCHAR(4)
DECLARE @LookupValues VARCHAR(50)


/**** Dynamic date calculation ****/
SET @Today = GETDATE();
SET @Lookupvalues=(Select STRING_AGG(ISNULL(LookupValue,' '),',') AS Lookupvalues from (Select LookupValue from SEO_MART.dbo.lk_SEOBusinessRules where LookupCategory='T5Wave' and LookupName in ('T5SchoolYear','T5BirthDate','FirstPDConfDateYear')) t);
SET @SchoolYear=SUBSTRING(@Lookupvalues,1,9);
SET @KIPSYPart = RIGHT(@SchoolYear,4);
SET @BirthYear=CONVERT(INT,SUBSTRING(@Lookupvalues,11,4));
SET @FirstPDConfDateYear=CONVERT(INT,SUBSTRING(@Lookupvalues,16,4))
SET @FirstPDConfDateYearCSY=CONVERT(VARCHAR,@FirstPDConfDateYear);
SET @FirstPDConfDateYearPSY = CONVERT(VARCHAR,(@FirstPDConfDateYear-1));
-------------------------------------------------------------------------------
					 			  
		 		 					
/**** Pick active ATS student demographic and gradelevel details for only records in CAP extract  ****/

    IF OBJECT_ID('tempdb..#ATS') IS NOT NULL
        DROP TABLE #ATS;

    SELECT StudentID AS StudentID,
           SchoolDBN,
           [Status] AS ATSStatus,
           GradeLevel,
		   DHS,
		   ATSPhysicalLocation
    INTO #ATS
    FROM
    (
        SELECT StudentID,
               SchoolDBN,
               [Status],
               GradeLevel,
			   DHS,
			   ATSPhysicalLocation
        FROM SEO_MART.dbo.INT_ATSStudents WITH (NOLOCK)
        /* Query for only records in CAP extract. */
        WHERE StudentID IN
              (                  
				  SELECT DISTINCT StudentID FROM SEO_MART.dbo.DWH_T5SourceExtract	--Added 11/27/2024
              )
    ) t
    WHERE [Status] = 'A'
		--and DHS is not null
    ORDER BY StudentID;


	--Added 5/14/2024 - Get extract latest Referral DocumentIDT of students for joining with SESIS data. MIS-11165 
	IF OBJECT_ID('tempdb..#DWHReferral') IS NOT NULL
        DROP TABLE #DWHReferral;
		
	Select t.* INTO #DWHReferral From (		
		Select StudentID, ReferralDate,Deleted,DocStatus,IsDelete,ReferralSchoolYear,DocumentIDT,
		ROW_NUMBER() OVER(Partition by StudentID Order by DocumentIDT DESC) RefNum
		From SEO_MART.dbo.DWH_Referral Where 1=1
		--AND ReferralTypeCode=1 commented 4/18/2025		
		
		--Added 7/22/2025 to ensure correct finalized and non-deleted referrals are extracted before joining with student population		
		AND RIGHT(ReferralSchoolYear,4)>=@KIPSYPart				
		AND Deleted = 0		----Non-Deleted
		AND DocStatus = 3	----Finalized
		AND IsDelete = 0	----Non-Deleted			
	) t Where t.RefNum=1;
	
   
	--MERGE CAPEXTRACT/KIPDATA-------------------------------------------------------------------------------------------------------------------
    MERGE INTO SEO_MART.dbo.RPT_T5StudentRegister tgt
    USING
    (
        SELECT src1.*,
               CASE
                   WHEN SUM(   CASE
								     WHEN IsTurning5 = 1 THEN
                                       1
                                   ELSE
                                       0
                               END
                           ) OVER (PARTITION BY GuardianLastName, GuardianFirstName, ZipCode) > 1 THEN
                       1
                   ELSE
                       0
               END SiblingFlag
        FROM
    (
        SELECT DISTINCT
				/*** SY24 new logic. Added 10/23/2023 ticket MIS-9728 *******************************************/
				CASE WHEN 
				ISNULL(cap.PreviousClassificationCode, 'XYZXYZ') IN ( 'PD', 'LD' )
				and cap.FirstPDConsentedForSVCSDate is NULL --INITIAL rule
						THEN 'T5 INITIAL'
				WHEN 
				ISNULL(cap.PreviousClassificationCode, 'XYZXYZ') IN ('PD', 'LD')
				AND cap.EvaluationDesc='PRE-SCH INITIAL'
				AND cap.FirstPDConsentedForSVCSDate is not NULL --INITIALS that already received consent but submitted a parental withdrawal
				AND cap.CaseCloseReasonCode=64					--INITIALS that already received consent but submitted a parental withdrawal			
						 THEN 'T5 INITIAL'
				WHEN 
				ISNULL(cap.PreviousClassificationCode, 'XYZXYZ') IN ('PD', 'LD')
				AND cap.FirstPDConsentedForSVCSDate is not NULL --REEVAL rule
					THEN 'T5 RE-EVAL' 
				ELSE NULL END as CaseType,

				/*** SY23 Logic commented 10/23/2023**************************************************************
                CASE
              WHEN cap.NewSelectFlagDesc IN ( 'Y: INITIAL TYPE 1', 'Y: INITIAL TYPE 2' ) THEN
                       'T5 INITIAL'
                   WHEN cap.NewSelectFlagDesc IN ( 'Y: INITIAL OR RE-EVAL TYPE 1', 'Y: INITIAL OR RE-EVAL TYPE 2',
                                       'Y: INITIAL OR RE-EVAL TYPE 3', 'Y: INITIAL OR RE-EVAL TYPE 4'
                                                 ) THEN
                       'T5 RE-EVAL'
                   WHEN cap.NewSelectFlagDesc = 'N: DOES NOT MEET CRITERIA'
						 AND (FirstPDConsentedForSVCSDate IS NULL) THEN
                       'T5 INITIAL'
                   WHEN cap.NewSelectFlagDesc = 'N: DOES NOT MEET CRITERIA'
						AND (FirstPDConsentedForSVCSDate IS NOT NULL) THEN
                       'T5 RE-EVAL'
                   ELSE
                       NULL
               END AS CaseType,
               **************************************************************************************************/
			   --Commented below 10/20/2023 ChrisAgwu to revert back to above CaseType logic per Ariel/Business Team. MIS-9728
			   /*
			   --Replaced 9/21/2021 - Above CaseType logic with below logic per ticket MIS-9728
				CASE WHEN cap.PreviousClassificationCode is NULL	--New starting SY24, changed from 'PD' to NULL
				AND cap.EvaluationDesc='PRE-SCH INITIAL'
				AND cap.FirstPDConsentedForSVCSDate is NULL
				AND cap.IEPConferenceDate is NULL					--New starting SY24, difference between CSE and SBST Initial. Approved by Arwina V./Jessica W.
				AND  cap.CaseCloseReasonCode in (14,50,62,63,77,85,90,92,97)
					THEN 'T5 INITIAL'
				WHEN cap.PreviousClassificationCode='PD'
				AND cap.EvaluationDesc='PRE-SCH INITIAL'
				AND cap.FirstPDConsentedForSVCSDate is not NULL 
				AND cap.CaseCloseReasonCode in (64)				--Pre-SY24, parental withdrawal
					THEN 'T5 INITIAL'
				WHEN cap.PreviousClassificationCode is NULL  
				AND cap.EvaluationDesc='PRE-SCH INITIAL' 
				AND cap.FirstPDConsentedForSVCSDate is NULL
				AND cap.IEPConferenceDate is not NULL				--New starting SY24, difference between CSE and SBST Initial. Approved by Arwina V./Jessica W.
				AND cap.CaseCloseReasonCode in (14,50,62,63,77,85,90,92,97)
					THEN 'T5 INITIAL'							--New Type
				WHEN cap.EvaluationDesc like 'PRE-SCH%' 
				AND cap.PreviousClassificationCode='PD'  
					THEN 'T5 REEVAL' 
				ELSE NULL END as CaseType,
				*/

				/**** IsCSETrueInitial Implementation. Ticket MIS-9729 ***/
				CASE WHEN (ISNULL(cap.PreviousClassificationCode, 'XYZXYZ') IN ('PD', 'LD') 
				AND cap.FirstPDConsentedForSVCSDate is NULL and cap.IEPConferenceDate is NULL)		--NewSelectFlagDesc = INITIAL TYPE 1
				OR (ISNULL(cap.PreviousClassificationCode, 'XYZXYZ') IN ('PD', 'LD')	
				AND cap.EvaluationDesc='PRE-SCH INITIAL'
				AND cap.FirstPDConsentedForSVCSDate is not NULL	
				AND  cap.CaseCloseReasonCode=64) --NewSelectFlagDesc = INITIAL TYPE 2
				THEN 1 ELSE 0 END IsCSETrueInitial,
			   cap.StudentID,               
			   CASE WHEN cap.HomeDistrict>32 THEN 'CSE 00' ELSE cap.AssignedLocationForTracking END as AssignedLocationForTracking,		--added 10-23-2024 MIS-12186
               cap.AssignedLocationSource,
               cap.CaseStatus,
               cap.CaseProgress,
               cap.EvaluationType,
               cap.EvaluationDesc,
               cap.ReferralDate,
               cap.ReferralSchool,
               cap.ConsentDate,
               cap.CurrentCAPServiceSchool,
               cap.ServiceSchoolName,
               cap.AssessmentBilLangCode,
               cap.CaseCloseDate,
               cap.CaseCloseReasonCode,
               cap.CaseCloseDesc,
               cap.EvaluationComplianceDate,
               cap.PlacementComplianceDate,
               cap.CAPDischargeDate,
               cap.CAPDischargeCode,
			   CASE WHEN LEN(cap.HomeDistrict) = 1 THEN CONCAT('0',cap.HomeDistrict)
               ELSE cap.HomeDistrict END AS HomeDist,
               cap.LastName,
               cap.FirstName,
               cap.BirthDate,
			   cap.Gender,
               cap.IEPConferenceDate,
               cap.RecommProgram,
               cap.DualRecommInd,
               cap.StudParticipateInTestingFlag,
               cap.EPCCOHPromotionCode,
               cap.OldSelectFlag,
               cap.OldSelectFlagDesc,
               cap.NewSelectFlag,
               cap.NewSelectFlagDesc,
               cap.RecommServiceCategory,
               cap.[12MonthInd] AS [12MonthInd],
               cap.ClassificationCode,
               cap.PreviousClassificationCode,
               cap.SEITSessionsPerWk,
               cap.RecommendedRS,
               cap.FinalNoticeDate,
               cap.FinalNoticeConsentDate,
               cap.AuthDate,
               cap.FirstAttendDate,
               cap.NextMostRecentFAD,
               cap.[Site],
               cap.SiteClassNumber,
               cap.ZonedSchool,
               cap.ZonedSchoolForLCGMS,
               cap.AssignedDBN,
               TRIM(cap.HouseNumber) AS HouseNumber,
               TRIM(cap.Street) AS Street,
               cap.BoroughCode,
               cap.ZipCode,
               cap.ApartmentNumber,
               /******Cleaned up: City Name *****/
			    CASE WHEN PATINDEX('%[^A-Z ]%',cap.CityName) >0  
              THEN SEO_MART.dbo.fn_T5RemoveNonAlphabets(cap.CityName) 
			  ELSE LTRIM(RTRIM(cap.CityName)) END  CityName,
               cap.GuardianLastName,
               cap.GuardianFirstName,
			   /******Cleaned up: Guardian Phone number *****/
			  CASE WHEN PATINDEX('%[^0-9]%',cap.GuardianPhoneNumber) >0  
              THEN SEO_MART.dbo.fn_T5RemoveNonNumeric(cap.GuardianPhoneNumber) 
			  ELSE CASE WHEN LEN(LTRIM(RTRIM(cap.GuardianPhoneNumber)))<>10 THEN '' ELSE LTRIM(RTRIM(cap.GuardianPhoneNumber)) END
			    END GuardianPhoneNo,
              CASE WHEN ISNULL(cap.GuardianLanguage,'')='' 
				   THEN 'EN' 
			   ELSE cap.GuardianLanguage 
			   END AS GuardianLanguage,  
               CASE WHEN cap.HomeDistrict>32 THEN '00' ELSE cap.CSE END as CSE,		--added 10-23-2024 MIS-12186
               cap.SchoolCluster,
               cap.ClusterLeader,
               cap.SchoolNetwork,
               cap.NetworkLeader,
               cap.Phase1Ind,
               cap.FirstTimeFlag,
               cap.FirstTimeDate,
               cap.AlreadyAssigned,
               cap.RunDate,
               cap.SiteOfferCTR,
               cap.FNRStatus,
               cap.LocationGroup,
               cap.ComplianceGroup,
               cap.CAPCompletionStatus,
               cap.FirstPDConfDate,
               cap.FirstPDConsentedForSVCSDate,
               CASE
                   WHEN cap.FirstPDConfDate < CONCAT(@FirstPDConfDateYearPSY,'-10-01')	--MIS-8716 Rollover
                        AND CONVERT(DATE, GETDATE()) >= CONCAT(@FirstPDConfDateYearCSY,'-03-26') 
                        AND CONVERT(DATE, GETDATE()) < CONCAT(@FirstPDConfDateYearCSY,'-04-01')
               THEN
                       1
                   WHEN cap.FirstPDConfDate < CONCAT(@FirstPDConfDateYearCSY,'-03-01')
                        AND CONVERT(DATE, GETDATE()) >= CONCAT(@FirstPDConfDateYearCSY,'-04-09')
                        AND CONVERT(DATE, GETDATE()) < CONCAT(@FirstPDConfDateYearCSY,'-04-14')
               THEN
                       2
                   WHEN cap.FirstPDConfDate >= CONCAT(@FirstPDConfDateYearCSY,'-03-01')
                        AND cap.FirstPDConfDate < CONCAT(@FirstPDConfDateYearCSY,'-04-01')
                        AND CONVERT(DATE, GETDATE()) >= CONCAT(@FirstPDConfDateYearCSY,'-05-14')
                        AND CONVERT(DATE, GETDATE()) < CONCAT(@FirstPDConfDateYearCSY,'-05-19')
				THEN
                       3
                   WHEN cap.FirstPDConfDate >= CONCAT(@FirstPDConfDateYearCSY,'-04-01')
                        AND cap.FirstPDConfDate < CONCAT(@FirstPDConfDateYearCSY,'-05-10')
                        AND CONVERT(DATE, GETDATE()) >= CONCAT(@FirstPDConfDateYearCSY,'-06-11')
						AND CONVERT(DATE, GETDATE()) < CONCAT(@FirstPDConfDateYearCSY,'-06-16') 
				THEN
                     4
                   ELSE
                     0
               END NewT5Flag,
               CASE
                   WHEN cap.CurrentCAPServiceSchool IN ( 'K22C009', 'Q26C564' )
                        AND cap.RecommProgram = 'CP'
                        AND SUBSTRING(a.SchoolDBN, 1, 2) = '88' ------------note this testing and verify it 
               THEN
                       1
                   ELSE
                       0
               END TopFlag,
               CASE
                 WHEN cap.CurrentCAPServiceSchool IN ( 'K22C009', 'Y98C153' )
                        AND cap.RecommProgram = 'CP'
                        AND a.SchoolDBN LIKE '88%' THEN
                       1
                   ELSE
                       0
               END BottomFlag,
               CASE
					WHEN cap.Street LIKE 'NO NAME' OR cap.Street LIKE 'NONAME' THEN 1				    
					WHEN (cap.HouseNumber like 'DV') OR (cap.HouseNumber like 'NO NAME') OR (cap.HouseNumber like 'NONAME') OR (cap.Street like 'NO NAME%') THEN 1 
					WHEN (cap.Street like 'NONAME%') OR (cap.HouseNumber like 'PO BOX')  OR (cap.Street like 'PO BOX') OR (cap.HouseNumber like 'P.O BOX') THEN 1   
					WHEN (cap.Street like 'P.O BOX') OR (cap.HouseNumber like 'P.O. BOX') OR (cap.Street like 'P.O. BOX') THEN 1			   
                   ELSE
                       0
               END NoNameStreetFlag,   --this flag now indicates DV students. MIS-9077                                                               
               	/****Students are T5 eligible if the following is true. 
					IsTurning5 is set for T5 eligible students. Not all eligible students will go through the wave process. 
					Check T5ProcessFlag in T5_StudentSchoolPriorties for more details.
				b.  if birthdate (year) is equals @BirthYear then student is eligible  --Added 9/29/2023 ChristopherAgwu per updated JIRA Ticket MIS-9727
				c.	If the PreviousClassifCd is ‘PD’ or ‘LD’ -  nulls excluded  
				d.	if the EvaluationDesc='PRE-SCH-INITIAL' AND PreviousClassificationCode IS NULL	--Added 9/21/2023 ChristopherAgwu per JIRA Ticket MIS-9727
				e.	If the Recmprogram is NOT ‘NH’ or ‘RC’ or ‘GE’ - null included 
				f.	If the CAPDischCd is NOT either 15 or 11- nulls included 
				g.	If CCReasonCd is NOT either 15 or 65 - nulls included 
				h.	If BoroCd is not ‘Y’ or ‘Z’ nulls included 
				i.	If HomeDist is not either 88 or 98 or 99 - nulls included 
				****/
               --This is condition to pick CAP students for T5 wave processing                                              
               CASE
                   WHEN ISNULL(cap.PreviousClassificationCode, 'XYZXYZ') IN ( 'PD', 'LD' )-----Preschooler with a disability or have a learning disability  (PreviousClassifCd is ‘PD’ or ‘LD)
                        --OR (cap.EvaluationDesc='PRE-SCH-INITIAL' AND cap.PreviousClassificationCode IS NULL)) --Added 9/21/2023 ChristopherAgwu per JIRA Ticket MIS-9727
						--commented above 10/20/2023 ChrisAgwu to revert back ticket MIS-9727 per Ariel
						AND ISNULL(cap.RecommProgram, 'XYZXYZ') NOT IN ( 'NH', 'RC', 'GE' )---Non-Handicapped (NH) , Revocation of Consent (RC), General Education (GE)
                        AND ISNULL(cap.CAPDischargeCode, 999999) NOT IN ( 15, 11 )---Moved or Transferred from NYC (code 11) or Deceased (code 15)
                        AND ISNULL(cap.CaseCloseReasonCode, 999999) NOT IN ( 15, 65 )----Deceased (code 15) ,Moved out of NYC (code 65) 
                        AND ISNULL(cap.BoroughCode, 'XYZXYZ') NOT IN ( 'Y', 'Z' )	---outside of NYC 
                        --AND ISNULL(cap.HomeDistrict, 999999) NOT IN ( 88, 98, 99 )	--Commented 11/28/2023 per ticket MIS-9727 requirement.
						--AND (cap.HomeDistrict>=1 AND cap.HomeDistrict<=32)	--Commented 8/12/2024 MIS-11626. --Added code per ticket MIS-9727 requirement.
						AND YEAR(cap.BirthDate)=@BirthYear 	--Added 9/29/2023 ChrisAgwu per JIRA Ticket MIS-9727
                        --Raji: 12/12/25 Exclude ATS children enrolled in Kindergarten
                        AND (a.StudentID is null OR isnull(a.GradeLevel, '') <> '0K' or isnull(a.SchoolDBN, '') not like '84%') 
                      THEN	
                         1
                   ELSE
                         0
               END IsTurning5,
               NULL AS WaveProcessedDate,
			   @SchoolYear SchoolYear,
               --cap.ATLASSourcedFrom as T5RecordSource,	--Added 11/27/2024
                          --cap.ATLASSourcedFrom as T5RecordSource,	--Added 11/27/2024
                'ATLAS' AS T5RecordSource,   -- Charlotte 2025-12-10: Hardcode for ATLAS (DWH_T5SourceExtract) to avoid CAP confusion
               'Y' SelectFlag,
               @Today as SelectFlagDate,
               a.SchoolDBN SchoolDBN,

               --D75.SchoolDBN AS D75AdminDBN,		Commented and to be replaced by ATS data 8/12/2024 MIS-11644.
               --D75.Site AS D75PhysicalDBN,		Commented and to be replaced by ATS data 8/12/2024 MIS-11644.
			   CASE WHEN a.GradeLevel='PK' and a.SchoolDBN Like '75%' Then a.SchoolDBN ELSE NULL END as D75AdminDBN,
			   CASE WHEN a.GradeLevel='PK' and a.SchoolDBN Like '75%' Then a.ATSPhysicalLocation END as D75PhysicalDBN,		

               --CASE WHEN D75.Site IS NULL		Commented and to be replaced by ATS data 8/12/2024 MIS-11644.
				   /*
					WHEN a.ATSPhysicalLocation IS NULL	
                        AND LEN(cap.CurrentCAPServiceSchool) = 7
                        AND cap.RecommProgram LIKE 'CP'
                        AND a.SchoolDBN LIKE '88%' THEN
                       cap.CurrentCAPServiceSchool
                   ELSE
                       NULL
				   */
				   CASE WHEN a.GradeLevel<>'PK' and a.SchoolDBN not like '75%'
					    AND LEN(cap.CurrentCAPServiceSchool) = 7
                        AND cap.RecommProgram LIKE 'CP'
                        AND a.SchoolDBN LIKE '88%' 
				   THEN cap.CurrentCAPServiceSchool
                   ELSE NULL END as CAPPrekSchool,
               --MIS-3684: Removing LocationType logic to find the Prek Flag and Prek school.
               CASE
                   WHEN --l.LocationType  in ('ES','K-12','K-8') and 
               a.GradeLevel = 'PK' THEN
                       1
                   ELSE
                       0
               END AS PreKFlag,
               CASE
                   WHEN --l.LocationType  in ('ES','K-12','K-8') and 
               a.GradeLevel = 'PK' THEN
                       a.SchoolDBN
                   ELSE
                       NULL
               END AS ATSPrekSchDBN,
               CAST(s.DateEvalIniConsent AS DATE) AS DateEvalIniConsent,
			   /**** DHSDVFlag 
					a.	It is set to DHS if the student is present in DWH_T5DHSShelters
					b.	It is set to DV if the student is present in DWH_T5DVShelters
					c.  Set DHS if T5 kid is flagged as DHS='Y' in INT_ATSStudents
			   ****/
               CASE
                   /*WHEN DHS.StudentID IS NOT NULL THEN
                       'DHS'*/                              --Commented 09/26/2025 MIS-13928 - DWH_T5DHSShelters no longer in use and will be retired.
                   /*WHEN DV.StudentID IS NOT NULL THEN		--Commented 09/25/2024 MIS-11906
                       'DV'*/
                   WHEN (a.StudentID IS NOT NULL AND a.DHS='Y') THEN
                       'DHS'
                   ELSE
                       NULL
               END DHSDVFlag,
			   
			   /**************Commented 08/12/2024 per ticket MIS-11644**************************
			   /**** D75Flag 
			        a.	It is set to Y if the student is present in DWH_T5D75prekenrollment
			   ****/
               CASE
                   WHEN D75.StudentID IS NOT NULL THEN
                       'Y'
                   ELSE
                       'N'
               END D75Flag,
			   **********************************************************************************/
			   /* Ticket MIS-11644. 08/12/2024 New D75Flag calculation from ATS student data */
			   CASE
                   WHEN a.GradeLevel='PK' AND a.SchoolDBN Like '75%' THEN	--Updated D75Flag logic to SchoolDBN NOT StudentID - MIS-12172
                       'Y'
                   ELSE
                       'N'
               END D75Flag,

              CONCAT(cap.GuardianLastName,cap.GuardianFirstName,cap.ZipCode) AS SiblingKey,
			   /********SESISFlag is set to N if the following are true:
				a.	The student is NOT present in DWH_SESISStudents
				b.	The student is NOT a deleted student
			   ***/
               CASE
                   WHEN s.StudentID IS NULL
                        AND dup.OldStudentID IS NULL THEN
                       'N'
                   ELSE
                       'Y'
               END AS SESISFlag, --Duplicate students need not be in "Not in sesis report"
               CONCAT(
                         cap.LastName,
                         cap.FirstName,
                         cap.BirthDate,
                         cap.Gender,
                        CASE WHEN LEN(cap.HomeDistrict) = 1 THEN CONCAT('0',cap.HomeDistrict)
                         ELSE cap.HomeDistrict END,
                         TRIM(cap.HouseNumber),
                         TRIM(cap.Street),
                         cap.BoroughCode,
                         cap.ZipCode,
                         cap.ApartmentNumber,
                      	/*******Cleaned up : CityName ****/
						CASE WHEN PATINDEX('%[^A-Z ]%',cap.CityName) >0  
						  THEN SEO_MART.dbo.fn_T5RemoveNonAlphabets(cap.CityName) 
						  ELSE LTRIM(RTRIM(cap.CityName)) END,
                         cap.GuardianLastName,
                         cap.GuardianFirstName,
                         /*******Cleaned up : Guardian Phone number ****/
						 CASE WHEN PATINDEX('%[^0-9]%',cap.GuardianPhoneNumber) >0  
                              THEN SEO_MART.dbo.fn_T5RemoveNonNumeric(cap.GuardianPhoneNumber) 
			                  ELSE CASE WHEN LEN(LTRIM(RTRIM(cap.GuardianPhoneNumber)))<>10 THEN '' ELSE LTRIM(RTRIM(cap.GuardianPhoneNumber)) END
			             END,
                        CASE WHEN ISNULL(cap.GuardianLanguage,'')='' 
						   THEN 'EN' 
					     ELSE cap.GuardianLanguage 
					     END  
                     ) BiogReportKey,
					 cap.GuardianEmail
        FROM SEO_MART.dbo.DWH_T5SourceExtract cap	--Added 11/27/2024
            LEFT JOIN #ATS a
                ON (a.StudentID = cap.StudentID)
            --LEFT JOIN SEO_MART.dbo.DWH_T5D75PrekEnrollment D75	Commented and to be replaced by ATS data 8/12/2024 MIS-11644.
                --ON (D75.StudentID = cap.StudentID)				Commented and to be replaced by ATS data 8/12/2024 MIS-11644.
            LEFT JOIN
            (
                SELECT StudentID,
                       DateEvalIniConsent
                FROM SEO_MART.dbo.DWH_SESISStudents WITH (NOLOCK)
            ) s
                ON (s.StudentID = cap.StudentID)
            /*LEFT JOIN SEO_MART.dbo.DWH_T5DHSShelters DHS
                ON (DHS.StudentID = cap.StudentID)*/        --Commented 09/26/2025 MIS-13928 - DWH_T5DHSShelters no longer in use and will be retired.
            /*LEFT JOIN SEO_MART.dbo.DWH_T5DVShelters DV	--Commented 09/25/2024 MIS-11906
                ON (DV.StudentID = cap.StudentID)*/
			LEFT JOIN SEO_MART.dbo.DWH_T5DuplicateStudentCorrection dup
                ON (dup.OldStudentID = cap.StudentID)
		/****Pick all the students from DWH_T5CAPExtract CAP file. 
		But, not in students whose referrals are opened in SESIS ****/	    
        
        /* 01-23-2026 - Chris Agwu: Commented to ensure all ATLAS students are loaded first before SESIS students. See ticket MIS-14873
        WHERE cap.StudentID NOT IN
        (
         SELECT sesis.StudentID FROM #SESISStud sesis
        )
        */
    ) src1
    ) src
    ON (tgt.StudentID = src.StudentID)	
    WHEN MATCHED --AND tgt.WaveProcessedDate IS NULL
    THEN
        UPDATE SET tgt.SchoolYear = src.SchoolYear,
          tgt.T5RecordSource = src.T5RecordSource,
                   tgt.selectFlagDate = src.SelectFlagDate,
                   tgt.SelectFlag = src.SelectFlag,
                   tgt.D75AdminDBN = src.D75AdminDBN,
                   tgt.D75PhysicalDBN = src.D75PhysicalDBN,
                   tgt.CAPPrekSchool = src.CAPPrekSchool,
                   tgt.ATSPrekSchoolDBN = src.ATSPrekSchDBN,
                   tgt.IsPreK = src.PreKFlag,
                   tgt.EvalIniConsentDate = src.DateEvalIniConsent,
                   tgt.casetype = src.casetype,
				   tgt.IsCSETrueInitial= src.IsCSETrueInitial,                   
				   tgt.AssignedLocationForTracking = CASE WHEN src.HomeDist<=32 THEN src.AssignedLocationForTracking END, --added 10-23-2024 MIS-12186				   
                   tgt.AssignedLocationSource = src.AssignedLocationSource,
                   tgt.CaseStatus = src.CaseStatus,
                   tgt.CaseProgress = src.CaseProgress,
                   tgt.EvaluationType = src.EvaluationType,
                   tgt.EvaluationDesc = src.EvaluationDesc,
                   tgt.ReferralDate = src.ReferralDate,
                   tgt.ReferralSchool = src.ReferralSchool,
                   tgt.ConsentDate = src.ConsentDate,
                   tgt.CurrentCAPServiceSchool = src.CurrentCAPServiceSchool,
                   tgt.ServiceSchoolName = src.ServiceSchoolName,
                   tgt.AssessmentBilLangCode = src.AssessmentBilLangCode,
                   tgt.CaseCloseDate = src.CaseCloseDate,
                   tgt.CaseCloseReasonCode = src.CaseCloseReasonCode,
                   tgt.CaseCloseDesc = src.CaseCloseDesc,
                   tgt.EvaluationComplianceDate = src.EvaluationComplianceDate,
                   tgt.PlacementComplianceDate = src.PlacementComplianceDate,
                   tgt.CAPDischargeDate = src.CAPDischargeDate,
                   tgt.CAPDischargeCode = src.CAPDischargeCode,
                   tgt.HomeDistrict = src.HomeDist,
                  tgt.LastName = src.LastName,
                   tgt.FirstName = src.FirstName,
                   tgt.BirthDate = src.BirthDate,
                   tgt.Gender = src.Gender,
                   tgt.IEPConferenceDate = src.IEPConferenceDate,
				   tgt.RecommendedProgram = src.RecommProgram,
                   tgt.DualRecmInd = src.DualRecommInd,
                   tgt.StudParticipateInTestingFlag = src.StudParticipateInTestingFlag,
                   tgt.EPCCOHPromotionCode = src.EPCCOHPromotionCode,
                   tgt.OldSelectFlag = src.OldSelectFlag,
                   tgt.OldSelectFlagDesc = src.OldSelectFlagDesc,
                   tgt.NewSelectFlag = src.NewSelectFlag,
                   tgt.NewSelectFlagDesc = src.NewSelectFlagDesc,
                   tgt.RecommServiceCategory = src.RecommServiceCategory,
                   tgt.[12MonthInd] = src.[12MonthInd],
                   tgt.ClassificationCode = src.ClassificationCode,
                   tgt.PreviousClassificationCode = src.PreviousClassificationCode,
                   tgt.SEITSessionsPerWeek = src.SEITSessionsPerWk,
                   tgt.RecommendedRS = src.RecommendedRS,
                   tgt.FinalNoticeDate = src.FinalNoticeDate,
                   tgt.FinalNoticeConsentDate = src.FinalNoticeConsentDate,
                   tgt.AuthDate = src.AuthDate,
                   tgt.FirstAttendDate = src.FirstAttendDate,
                   tgt.NextMostRecentFAD = src.NextMostRecentFAD,
                   tgt.[Site] = src.[Site],
                   tgt.SiteClassNumber = src.SiteClassNumber,
                   tgt.ZonedSchool = src.ZonedSchool,
                   tgt.ZonedSchoolForLCGMS = src.ZonedSchoolForLCGMS,
                   tgt.AssignedDBN = src.AssignedDBN,
                   tgt.HouseNumber = src.HouseNumber,
                   tgt.Street = src.Street,
                   tgt.BoroughCode = src.BoroughCode,
                   tgt.ZipCode = src.ZipCode,
                   tgt.ApartmentNumber = src.ApartmentNumber,
                   tgt.CityName = src.CityName,
                   tgt.GuardianLastName = src.GuardianLastName,
                   tgt.GuardianFirstName = src.GuardianFirstName,
                   tgt.GuardianPhoneNumber = src.GuardianPhoneNo,
                   tgt.GuardianLanguage = src.GuardianLanguage,
                   tgt.CSE = CASE WHEN src.HomeDist<=32 THEN src.CSE END,	--added 10-23-2024 MIS-12186
                   tgt.SchoolCluster = src.SchoolCluster,
                   tgt.ClusterLeader = src.ClusterLeader,
                   tgt.SchoolNetwork = src.SchoolNetwork,
                   tgt.NetworkLeader = src.NetworkLeader,
                   tgt.Phase1Ind = src.Phase1Ind,
                   tgt.FirstTimeFlag = src.FirstTimeFlag,
                   tgt.FirstTimeDate = src.FirstTimeDate,
                   tgt.AlreadyAssigned = src.AlreadyAssigned,
                   tgt.CAPRunDate = src.RunDate,
                   tgt.SiteOfferCTR = src.SiteOfferCTR,
                   tgt.FNRStatus = src.FNRStatus,
                   tgt.LocationGroup = src.LocationGroup,
                   tgt.ComplianceGroup = src.ComplianceGroup,
                   tgt.CAPCompletionStatus = src.CAPCompletionStatus,
                   tgt.FirstPDConfDate = src.FirstPDConfDate,
				   tgt.FirstPDConsentedForSVCSDate = src.FirstPDConsentedForSVCSDate,
                   tgt.IsNewT5 = src.NewT5Flag,
                   tgt.IsTop = src.TopFlag,
                   tgt.IsBottom = src.BottomFlag,
                   tgt.IsNoNameStreet = src.NoNameStreetFlag,
                   tgt.IsSibling = src.SiblingFlag,
                   tgt.IsTurning5 = src.IsTurning5,
                   tgt.schoolDBN = src.SchoolDBN,  
                   tgt.DHSDVFlag = src.DHSDVFlag,
                   tgt.D75Flag = src.D75Flag,
                   tgt.SiblingKey = src.SiblingKey,
				   /**** BiogReportFlag is set to Y if the following condition is true:		
						a.	If the current run’s biog are not same as the previous run’s biog data
						b.	If the Boro is not ‘Y’ or ‘Z’ 
						c.	If the Home district is not 88,98,99

						BiogReportFlag indicates the list of wave students in biog report. 
						Not all wave new student will be in biog report. 
						Only student with T5ProcessFlag=’Y’ (valid address or any DBN options) should be in biog report
				   ****/
                   tgt.BiogReportFlag = CASE
                                            WHEN CONCAT(
                                                           tgt.LastName,
                                                           tgt.FirstName,
                                                           tgt.BirthDate,
                                                           tgt.Gender,
                                                           tgt.HomeDistrict,
                                                           tgt.HouseNumber,
                                                           tgt.Street,
                                                           tgt.BoroughCode,
                                                           tgt.ZipCode,
                                                           tgt.ApartmentNumber,
                                                           tgt.CityName,
                                                           tgt.GuardianLastName,
                                                           tgt.GuardianFirstName,
                                                           tgt.GuardianPhoneNumber,
                                                           tgt.GuardianLanguage
                                                       ) <> BiogReportKey
                                                 --MIS-3802
                                                 AND src.BoroughCode NOT IN ( 'Y', 'Z' )
                                                 --AND src.HomeDist NOT IN ( 88, 98, 99 )	--Commented 10/01/2024 to include HD outside of NYC
												 THEN
                                                'Y'
                                            ELSE
                                                'N'
                                        END,
                   tgt.SESISFlag = src.SESISFlag, --Check for the impact of duplicate students
				   tgt.GuardianEmail = src.GuardianEmail,
                   tgt.ModifiedDate = @Today
    WHEN NOT MATCHED THEN
        INSERT
        (
            SchoolYear,
            T5RecordSource,
            SelectFlag,
            SelectFlagDate,
            D75AdminDBN,
            D75PhysicalDBN,
            CAPPrekSchool,
            ATSPrekSchoolDBN,
            IsPreK,
            EvalIniConsentDate,
            casetype,
			IsCSETrueInitial,
            StudentID,
            AssignedLocationForTracking,
            AssignedLocationSource,
            CaseStatus,
            CaseProgress,
            EvaluationType,
            EvaluationDesc,
            ReferralDate,
            ReferralSchool,
            ConsentDate,
            CurrentCAPServiceSchool,
            ServiceSchoolName,
            AssessmentBilLangCode,
            CaseCloseDate,
            CaseCloseReasonCode,
            CaseCloseDesc,
            EvaluationComplianceDate,
            PlacementComplianceDate,
            CAPDischargeDate,
            CAPDischargeCode,
            HomeDistrict,
            LastName,
            FirstName,
            BirthDate,
            Gender,
            IEPConferenceDate,
            RecommendedProgram,
            DualRecmInd,
            StudParticipateInTestingFlag,
            EPCCOHPromotionCode,
            OldSelectFlag,
            OldSelectFlagDesc,
            NewSelectFlag,
            NewSelectFlagDesc,
            RecommServiceCategory,
            [12MonthInd],
            ClassificationCode,
            PreviousClassificationCode,
            SEITSessionsPerWeek,
            RecommendedRS,
            FinalNoticeDate,
            FinalNoticeConsentDate,
            AuthDate,
            FirstAttendDate,
            NextMostRecentFAD,
            [Site],
            SiteClassNumber,
            ZonedSchool,
            ZonedSchoolForLCGMS,
            AssignedDBN,
            HouseNumber,
			Street,
            BoroughCode,
            ZipCode,
            ApartmentNumber,
            CityName,
            GuardianLastName,
            GuardianFirstName,
            GuardianPhoneNumber,
            GuardianLanguage,
            CSE,
            SchoolCluster,
            ClusterLeader,
            SchoolNetwork,
            NetworkLeader,
            Phase1Ind,
            FirstTimeFlag,
            FirstTimeDate,
            AlreadyAssigned,
            CAPRunDate,
            SiteOfferCTR,
            FNRStatus,
            LocationGroup,
            ComplianceGroup,
            CAPCompletionStatus,
            FirstPDConfDate,
            FirstPDConsentedForSVCSDate,
            IsNewT5,
            IsTop,
            IsBottom,
            IsNoNameStreet,
            IsSibling,
            IsTurning5,
            SchoolDBN,
            WaveProcessedDate,
            DHSDVFlag,
            D75Flag,
            SiblingKey,
            SESISFlag,
            BiogReportFlag,
			GuardianEmail,
            ModifiedDate
        )
        VALUES
        (   src.SchoolYear, src.T5RecordSource, src.SelectFlag, src.SelectFlagDate, src.D75AdminDBN,
            src.D75PhysicalDBN, src.CAPPrekSchool, src.ATSPrekSchDBN, src.PreKFlag, src.DateEvalIniConsent,
            src.casetype,src.IsCSETrueInitial, src.StudentID, src.AssignedLocationForTracking, src.AssignedLocationSource, src.CaseStatus,
            src.CaseProgress, src.EvaluationType, src.EvaluationDesc, src.ReferralDate, src.ReferralSchool, src.ConsentDate,
            src.CurrentCAPServiceSchool, src.ServiceSchoolName, src.AssessmentBilLangCode, src.CaseCloseDate,
            src.CaseCloseReasonCode, src.CaseCloseDesc, src.EvaluationComplianceDate, src.PlacementComplianceDate, src.CAPDischargeDate,
            src.CAPDischargeCode, src.HomeDist, src.LastName, src.FirstName, src.BirthDate,
            src.Gender, src.IEPConferenceDate, src.RecommProgram, src.DualRecommInd, src.StudParticipateInTestingFlag,
            src.EPCCOHPromotionCode, src.OldSelectFlag, src.OldSelectFlagDesc, src.NewSelectFlag,
            src.NewSelectFlagDesc, src.RecommServiceCategory, src.[12MonthInd], src.ClassificationCode, src.PreviousClassificationCode,
            src.SEITSessionsPerWk, src.RecommendedRS, src.FinalNoticeDate, src.FinalNoticeConsentDate, src.AuthDate,
            src.FirstAttendDate, src.NextMostRecentFAD, src.[Site], src.SiteClassNumber, src.ZonedSchool,
            src.ZonedSchoolForLCGMS, src.AssignedDBN, src.HouseNumber, src.Street, src.BoroughCode, src.ZipCode,
            src.ApartmentNumber, src.CityName, src.GuardianLastName, src.GuardianFirstName, src.GuardianPhoneNo,
            src.GuardianLanguage, src.CSE, src.SchoolCluster, src.ClusterLeader, src.SchoolNetwork, src.NetworkLeader,
            src.Phase1Ind, src.FirstTimeFlag, src.FirstTimeDate, src.AlreadyAssigned, src.RunDate, src.SiteOfferCTR,
            src.FNRStatus, src.LocationGroup, src.ComplianceGroup, src.CAPCompletionStatus, src.FirstPDConfDate,
	        src.FirstPDConsentedForSVCSDate, 
			src.NewT5Flag, src.TopFlag, src.BottomFlag,
            src.NoNameStreetFlag,
            src.SiblingFlag,
            src.IsTurning5, src.SchoolDBN, src.WaveProcessedDate, src.DHSDVFlag, src.D75Flag, src.SiblingKey,
            src.SESISFlag,
			/** BiogReportFlag: Not all new students will be in BiogReport. 
			Only new students with T5ProcessFlag='Y' should be in BioReport. So for these new students we will update to Y in the same place we update ****/
            'N', 
			src.GuardianEmail,
            NULL       --tgt.ModifiedDate
            );

--#####################################################################################################################################
--01-23-2026--
--Moved SESIS load to this position so ATLAS students may be loaded/processed first before SESIS students. Ticket MIS-14873

/**** Pick all the students directly created(after May 1st SY) in SESIS.
The rules for student whose referrals are opened in SESIS but not in CAP.
a.	Students with finalized referral in DWH_Referral but no referral in RPT_T5Referral
b.	Students with birth year 2016
 *****/
 
    IF OBJECT_ID('tempdb..#SESISStud') IS NOT NULL
        DROP TABLE #SESISStud;
    SELECT DISTINCT
            CASE
               WHEN S.ProcessStageDesc = 'Initial' THEN
                   'T5 INITIAL'
               WHEN S.ProcessStageDesc = 'Reevaluation' THEN
                   'T5 RE-EVAL'
           END AS CaseType,
		   (1) as IsCSETrueInitial,		--Added 4/22/2025 MIS-13135
           S.StudentID StudentID,        		   
		   DC.CSE as AssignedLocationForTracking,	--changed 5/22/2023 MIS-9164
           cap.AssignedLocationSource,
           cap.CaseStatus,
           cap.CaseProgress,
           cap.EvaluationType,
           cap.EvaluationDesc,
           R.ReferralDate, 
           cap.ReferralSchool,
           cap.ConsentDate,
           cap.CurrentCAPServiceSchool,
           cap.ServiceSchoolName,
           cap.AssessmentBilLangCode,
           cap.CaseCloseDate,
           cap.CaseCloseReasonCode,
           cap.CaseCloseDesc,
           cap.EvaluationComplianceDate,
           cap.PlacementComplianceDate,
           cap.CAPDischargeDate,
           cap.CAPDischargeCode,
		   CASE when len(S.HomeDistrict) = 1 then CONCAT('0',S.HomeDistrict)
              ELSE S.HomeDistrict END as HomeDist,                                        
           UPPER(S.LastName) StudentLastName,   --added upper 5/18/2023                                                                                
           UPPER(S.FirstName) StudentFirstName,	--added upper 5/18/2023                                                                                        
           CONVERT(VARCHAR(35), S.BirthDate, 112) StudentDOB,                                                                  
           CASE
               WHEN S.Gender = 'Male' THEN
					'M'
               ELSE
                   'F'
           END StudentGender,                                                                                                  
           cap.IEPConferenceDate,
           cap.RecommProgram,
           cap.DualRecommInd,
           cap.StudParticipateInTestingFlag,
           cap.EPCCOHPromotionCode,
           cap.OldSelectFlag,
           cap.OldSelectFlagDesc,
           cap.NewSelectFlag,
           cap.NewSelectFlagDesc,
           cap.RecommServiceCategory,
           cap.[12MonthInd] AS [12MonthInd],
           cap.ClassificationCode,
           cap.PreviousClassificationCode,
           cap.SEITSessionsPerWk,
           cap.RecommendedRS,
           cap.FinalNoticeDate,
           cap.FinalNoticeConsentDate,
           cap.AuthDate,
           cap.[FirstAttendDate],
           cap.NextMostRecentFAD,
           cap.[Site],
           cap.SiteClassNumber,
           cap.ZonedSchool,
           cap.ZonedSchoolForLCGMS,
           cap.AssignedDBN,

			/*Commented 6/6/2023 to source data from CAPExtract per MIS-9285 ticket----------------------------
			,CASE WHEN S.[Address] LIKE ' ' THEN
                  LEFT(S.[Address], CHARINDEX(' ', S.[Address]) - 1) 
				  ELSE 'NO'
				  END HouseNumber                                               
			,CASE WHEN S.[Address] LIKE ' ' THEN
		         LTRIM(SUBSTRING(S.[Address], LEN(LEFT(S.[Address], CHARINDEX(' ', S.[Address]) - 1)) + 1, LEN(S.[Address]))) 
				 ELSE 'NO NAME'
				 END Street
			,S.[Address]
			,S.LocationBoroughCode BoroCd,                                                                                        
			S.ZipCode,                                                                                                
			S.ApartmentNumber AptNumber,                                        
		   -------------------------------------------------------------*/
		   --Added below 6/6/2023 per MIS-9285 ticket--------------------
		  --USING CAPExtract Data but when not available use SESIS--
		   CASE WHEN cap.HouseNumber IS NULL THEN	--student not in capextract 6/6/2023
				CASE WHEN trim(S.HouseNumber)='' OR S.HouseNumber LIKE 'DV%' OR S.HouseNumber LIKE 'NO%' OR S.HouseNumber LIKE 'PO%' THEN 'NO NAME'
				ELSE S.HouseNumber END
			ELSE
				TRIM(cap.HouseNumber) END as HouseNumber,
			CASE WHEN cap.HouseNumber IS NULL THEN 	--student not in capextract 6/6/2023
				CASE WHEN trim(S.HouseNumber)='' OR S.HouseNumber LIKE 'DV%' OR S.HouseNumber LIKE 'NO%' OR S.HouseNumber LIKE 'PO%' THEN 'NO NAME'
				ELSE S.Street END
			ELSE						   
				TRIM(cap.Street) END as Street,
			
			CASE WHEN cap.HouseNumber IS NULL THEN S.LocationBoroughCode ELSE cap.BoroughCode END as BoroCd,
			CASE WHEN cap.HouseNumber IS NULL THEN S.ZipCode ELSE cap.ZipCode END as ZipCode,
			CASE WHEN cap.HouseNumber IS NULL THEN S.ApartmentNumber ELSE cap.ApartmentNumber END as AptNumber,
			--End-of-MIS-9285 ticket------------------------------------

            /****Cleaned : City Name *****/
			CASE WHEN patindex('%[^A-Z ]%',S.StudentCity) >0  
              THEN SEO_MART.dbo.fn_T5RemoveNonAlphabets(S.StudentCity) 
			ELSE LTRIM(RTRIM(S.StudentCity)) END  CityName,                                                                                             
           UPPER(S.ParentLastName) GuardianLastName,	--added upper 5/18/2023                                                                                   
           UPPER(S.ParentFirstName) GuardianFirstName,  --added upper 5/18/2023                                                                               
           /****Cleaned : Guardian phone number *****/ 
		   CASE WHEN patindex('%[^0-9]%',S.Parent1phone1) >0  
			 THEN SEO_MART.dbo.fn_T5RemoveNonNumeric(S.Parent1phone1) 
			ELSE CASE WHEN LEN(LTRIM(RTRIM(S.Parent1phone1)))<>10 THEN '' ELSE LTRIM(RTRIM(S.Parent1phone1)) END
		   END  GuardianPhoneNo,  
		   CASE WHEN ISNULL(Cap.GuardianLanguage,'')='' 
			   THEN 'EN' 
		   ELSE Cap.GuardianLanguage 
		   END AS GuardianLanguage,                                                                                                                                                                                  
           DC.CSEDistrict CSE,	--changed 5/22/2023 MIS-9164                                                                                                   
           cap.SchoolCluster,
           cap.ClusterLeader,
           cap.SchoolNetwork,
           cap.NetworkLeader,
           cap.Phase1Ind,
           cap.FirstTimeFlag,
           cap.FirstTimeDate,
           cap.AlreadyAssigned,
           cap.RunDate,
           cap.SiteOfferCTR,
           cap.FNRStatus,
           cap.LocationGroup,
           cap.ComplianceGroup,
           cap.CAPCompletionStatus,
           --Null FirstPDConfDate, --------------Added by Raja as per reporting need
		   CAST(NULL AS DATE) FirstPDConfDate,
           cap.FirstPDConsentedForSVCSDate, 
           @Today as processedDate,                                                                                             
           CASE
               WHEN cap.FirstPDConfDate < CONCAT(@FirstPDConfDateYearPSY,'-10-01') --MIS-8716 Rollover
                    AND CONVERT(DATE, GETDATE()) >= CONCAT(@FirstPDConfDateYearCSY,'-03-26')
				   AND CONVERT(DATE, GETDATE()) < CONCAT(@FirstPDConfDateYearCSY,'-04-01')
           THEN
                   1
               WHEN cap.FirstPDConfDate < CONCAT(@FirstPDConfDateYearCSY,'-03-01') 
                    AND CONVERT(DATE, GETDATE()) >= CONCAT(@FirstPDConfDateYearCSY,'-04-09')
                    AND CONVERT(DATE, GETDATE()) < CONCAT(@FirstPDConfDateYearCSY,'-04-14')
           THEN
                   2
               WHEN cap.FirstPDConfDate >= CONCAT(@FirstPDConfDateYearCSY,'-03-01')
                    AND cap.FirstPDConfDate < CONCAT(@FirstPDConfDateYearCSY,'-04-01')
                    AND CONVERT(DATE, GETDATE()) >= CONCAT(@FirstPDConfDateYearCSY,'-05-14')
                    AND CONVERT(DATE, GETDATE()) < CONCAT(@FirstPDConfDateYearCSY,'-05-19')
					THEN
                   3
               WHEN cap.FirstPDConfDate >= CONCAT(@FirstPDConfDateYearCSY,'-04-01')
                    AND cap.FirstPDConfDate < CONCAT(@FirstPDConfDateYearCSY,'-05-10')
                    AND CONVERT(DATE, GETDATE()) >= CONCAT(@FirstPDConfDateYearCSY,'-06-11')
                    AND CONVERT(DATE, GETDATE()) < CONCAT(@FirstPDConfDateYearCSY,'-06-16')
					THEN
                   4
               ELSE
                   0
           END NewT5Flag,
		   /*********Top Flag and Bottom Flag is set only when CAP School is 'K22C009', 'Q26C564', 'Y98C153'*********/
           CASE
               WHEN cap.CurrentCAPServiceSchool IN ( 'K22C009', 'Q26C564' )
                    AND cap.RecommProgram = 'CP'
                    AND SUBSTRING(SchoolDBN, 1, 2) = '88' THEN
                   1
               ELSE
                   0
     END TopFlag,
           CASE
               WHEN cap.CurrentCAPServiceSchool IN ( 'K22C009', 'Y98C153' )
                    AND cap.RecommProgram = 'CP'
                    AND a.SchoolDBN LIKE '88%' THEN
                   1
               ELSE
                   0
           END BottomFlag,
			CASE WHEN cap.HouseNumber IS NULL THEN	--Added 6/6/2023. Student not in CAPExtract - MIS-9285
				CASE WHEN trim(S.HouseNumber)='' OR S.HouseNumber LIKE 'DV%' OR S.HouseNumber LIKE 'NO%' OR S.HouseNumber LIKE 'PO%' THEN 1
				ELSE 0 END
		   ELSE
			   CASE			   
				   WHEN cap.Street LIKE 'NO NAME' OR cap.Street LIKE 'NONAME' THEN 1
				   WHEN (cap.HouseNumber like 'DV') OR (cap.HouseNumber like 'NO NAME') OR (cap.HouseNumber like 'NONAME') OR (cap.Street like 'NO NAME%') THEN 1 
				   WHEN (cap.Street like 'NONAME%') OR (cap.HouseNumber like 'PO BOX')  OR (cap.Street like 'PO BOX') OR (cap.HouseNumber like 'P.O BOX') THEN 1   
				   WHEN (cap.Street like 'P.O BOX') OR (cap.HouseNumber like 'P.O. BOX') OR (cap.Street like 'P.O. BOX') THEN 1			   
				   ELSE 0
				END
			END NoNameStreetFlag,	--this flag now indicates DV students MIS-9077

			/****Students are T5 eligible if the following is true. 
				IsTurning5 is set for T5 eligible students. Not all eligible students will go through the wave process. 
				Check T5ProcessFlag in T5_StudentSchoolPriorties for more details.
			c.	If the PreviousClassifCd is ‘PD’ or ‘LD’ -  nulls excluded
			e.	If the Recmprogram is NOT ‘NH’ or ‘RC’ or ‘GE’ - null included 
			f.	If the CAPDischCd is NOT either 15 or 11- nulls included 
			g.	If CCReasonCd is NOT either 15 or 65 - nulls included 
			h.	If BoroCd is not ‘Y’ or ‘Z’ nulls included 
			i.	If HomeDist is not either 88 or 98 or 99 - nulls included 
			****/
           --This is condition to pick CAP students for T5 wave processin
		   S.IsTurning5, ----Added by Raja as per reporting request
           Convert(Datetime,Null) AS WaveProcessedDate,
		   @SchoolYear SchoolYear,
           'SESIS' T5RecordSource,
           'Y' SelectFlag,
           @Today as SelectFlagDate,
           a.SchoolDBN SchoolDBN,
           NULL D75AdminDBN,                                                                                                    
           NULL D75PhysicalDBN,                                                                                                
           NULL CAPPrekSchool,
           --MIS-3684: Removing LocationType logic to find the Prek Flag and Prek school.
           CASE
               WHEN --l.LocationType  in ('ES','K-12','K-8') and 
           a.GradeLevel = 'PK' THEN
                   1
               ELSE
                   0
           END AS PreKFlag,
           CASE
               WHEN --l.LocationType  in ('ES','K-12','K-8') and 
           a.GradeLevel = 'PK' THEN
                   a.SchoolDBN
               ELSE
                   NULL
           END AS ATSPrekSchDBN,
           CAST(S.DateEvalIniConsent AS DATE) AS DateEvalIniConsent,
		   /***Set DHS if T5 kid is flagged as DHS='Y' in INT_ATSStudents ***/
           CASE WHEN (a.StudentID IS NOT NULL AND a.DHS='Y') THEN 'DHS' 
		   ELSE NULL END DHSDVFlag,
           NULL D75Flag,

		   --CONCAT(cap.GuardianLastName,cap.GuardianFirstName,cap.ZipCode) AS SiblingKey,	--commented 5/18/2023	MIS-9164
		   CASE WHEN ISNULL(cap.GuardianLastName,'')='' OR TRIM(cap.GuardianLastName)='' THEN	--added 5/18/2023	MIS-9164
				CONCAT(UPPER(S.ParentLastName),UPPER(S.ParentFirstName),S.ZipCode)	
			ELSE
				CONCAT(cap.GuardianLastName,cap.GuardianFirstName,cap.ZipCode)
			END AS SiblingKey,

			/********SESISFlag is set to N if the following are true:
			a.	The student is NOT present in DWH_SESISStudents
			b.	The student is NOT a deleted student
			 ***/
           'Y' SESISFlag,
           CONCAT(
                     cap.LastName,
                     cap.FirstName,
                     cap.BirthDate,
                     cap.Gender,
				     CASE when len(cap.HomeDistrict) = 1 then CONCAT('0',cap.HomeDistrict)
                      ELSE cap.HomeDistrict END, 
                     TRIM(cap.HouseNumber),
                     TRIM(cap.Street),
                     cap.BoroughCode,
                     cap.ZipCode,
                     cap.ApartmentNumber,
					  CASE WHEN patindex('%[^A-Z ]%',cap.CityName) >0  
                      THEN SEO_MART.dbo.fn_T5RemoveNonAlphabets(cap.CityName) 
			          ELSE LTRIM(RTRIM(cap.CityName)) END ,
                     cap.GuardianLastName,
                     cap.GuardianFirstName,
					  CASE WHEN patindex('%[^0-9]%',cap.GuardianPhoneNumber) >0  
              THEN SEO_MART.dbo.fn_T5RemoveNonNumeric(cap.GuardianPhoneNumber) 
			  ELSE CASE WHEN LEN(LTRIM(RTRIM(cap.GuardianPhoneNumber)))<>10 THEN '' ELSE LTRIM(RTRIM(cap.GuardianPhoneNumber)) END END,
					 CASE WHEN ISNULL(cap.GuardianLanguage,'')='' 
						   THEN 'EN' 
					 ELSE cap.GuardianLanguage 
					   END  
                 ) BiogReportKey
    INTO #SESISStud
    FROM SEO_MART.dbo.DWH_SESISStudents S WITH (NOLOCK)
        --JOIN SEO_MART.dbo.DWH_Referral R WITH (NOLOCK)	--commented 5/11/2023 per MIS-9196 student could have multiple referrals but only first is needed.
		--JOIN (Select StudentID, ReferralDate,Deleted,DocStatus,IsDelete,ReferralSchoolYear from SEO_MART.dbo.DWH_Referral where ReferralTypeCode=1) R	--added 5/11/2023 per MIS-9196 to ensure only the initial referraldate is selected.
		--Commented above join 5/14/2024 and replaced with temp table #DWHReferral. See JIRA ticket MIS-11165
		JOIN #DWHReferral R
            ON S.StudentID = R.StudentID
		LEFT JOIN SEO_MART.dbo.RPT_T5StudentAssignment RL
            ON R.StudentID = RL.StudentID
			  AND RL.SchoolYear=@SchoolYear
        LEFT JOIN SEO_MART.dbo.DWH_T5SourceExtract cap 	--Added 11/27/2024
            ON (cap.StudentID = S.StudentID)
        LEFT JOIN #ATS a
            ON (a.StudentID = cap.StudentID)
		LEFT JOIN SEO_MART.dbo.lk_CSEDistrictCodes DC	--added 5/22/2023 MIS-9164
		ON DC.DistrictText=S.HomeDistrict
    WHERE 1=1 --S.IsTurning5 = 1 ---------SESIS T5 Eligible (Commented-out 4/18/2025 to all SESIS students to be evaluated)
	      /****The rules for student whose referrals are opened in SESIS but not in CAP.
		  a. Students with finalized referral in DWH_Referral but no referral in RPT_T5StudentAssignment
		  b. Students with birth year 2016*****/
          
		  /**** Commented 7/22/2025. (MIS-13672) All Referral filters and added them to DWH_Referral data extract ***********
		  --AND R.Deleted = 0 ----Non-Deleted			
          --AND R.DocStatus = 3 -------Finalized		
          --AND R.IsDelete = 0
          --AND R.ReferralSchoolYear=@SchoolYear	
		  ***************************************************************************************************************/
          AND RL.StudentID IS NULL
		  --Raji removed this SchoolYear conidtion. S.SchoolYear changes to next year on 7/15
		  --AND S.SchoolYear=@SchoolYear	--added 10/01/2024
		AND YEAR(S.BirthDate) = @BirthYear

         --Added 01-23-2026 - Chris Agwu: Added to exclude SESIS students already loaded from ATLAS. See ticket MIS-14873
         AND S.StudentID NOT IN (SELECT SE.StudentID FROM SEO_MART.dbo.DWH_T5SourceExtract SE);
	
    --MERGE SESIS DATA----
    MERGE INTO SEO_MART.dbo.RPT_T5StudentRegister tgt
    USING
    (
        SELECT src1.*,
               CASE
                   WHEN SUM(CASE WHEN src1.IsTurning5 = 1 THEN 1 ELSE 0 END) OVER (PARTITION BY src1.GuardianLastName,src1.GuardianFirstName,src1.ZipCode) > 1 THEN
                       1
                   ELSE
                       0
               END SiblingFlag
        FROM (SELECT * FROM #SESISStud ) src1
    ) src
    ON (tgt.StudentID=src.StudentID)	
    WHEN MATCHED --AND tgt.WaveProcessedDate IS NULL
    THEN
        UPDATE SET tgt.SchoolYear = src.SchoolYear,
           tgt.T5RecordSource = src.T5RecordSource,
                   tgt.selectFlagDate = src.SelectFlagDate,
                   tgt.SelectFlag = src.SelectFlag,
                   tgt.D75AdminDBN = src.D75AdminDBN,
                   tgt.D75PhysicalDBN = src.D75PhysicalDBN,
                   tgt.CAPPrekSchool = src.CAPPrekSchool,
                   tgt.ATSPrekSchoolDBN = src.ATSPrekSchDBN,
                   tgt.IsPreK = src.PreKFlag,
                   tgt.EvalIniConsentDate = src.DateEvalIniConsent,
                   tgt.casetype = src.CaseType,
				   tgt.IsCSETrueInitial = src.IsCSETrueInitial,		--Added 4/22/2025 MIS-13135
                   tgt.AssignedLocationForTracking = src.AssignedLocationForTracking,
                   tgt.AssignedLocationSource = src.AssignedLocationSource,
                   tgt.CaseStatus = src.CaseStatus,
                   tgt.CaseProgress = src.CaseProgress,
                   tgt.EvaluationType = src.EvaluationType,
                   tgt.EvaluationDesc = src.EvaluationDesc,
                   tgt.ReferralDate = src.ReferralDate,
                   tgt.ReferralSchool = src.ReferralSchool,
                   tgt.ConsentDate = src.ConsentDate,
                   tgt.CurrentCAPServiceSchool = src.CurrentCAPServiceSchool,
                   tgt.ServiceSchoolName = src.ServiceSchoolName,
                   tgt.AssessmentBilLangCode = src.AssessmentBilLangCode,
                   tgt.CaseCloseDate = src.CaseCloseDate,
                   tgt.CaseCloseReasonCode = src.CaseCloseReasonCode,
                   tgt.CaseCloseDesc = src.CaseCloseDesc,
                   tgt.EvaluationComplianceDate = src.EvaluationComplianceDate,
                   tgt.PlacementComplianceDate = src.PlacementComplianceDate,
                   tgt.CAPDischargeDate = src.CAPDischargeDate,
                   tgt.CAPDischargeCode = src.CAPDischargeCode,
                   tgt.HomeDistrict = src.HomeDist,
                   tgt.LastName = src.StudentLastName,
                   tgt.FirstName = src.StudentFirstName,
                   tgt.BirthDate = src.StudentDOB,
                   tgt.Gender = src.StudentGender,
                   tgt.IEPConferenceDate = src.IEPConferenceDate,
                   tgt.RecommendedProgram = src.RecommProgram,
                   tgt.DualRecmInd = src.DualRecommInd,
                   tgt.StudParticipateInTestingFlag = src.StudParticipateInTestingFlag,
                   tgt.EPCCOHPromotionCode = src.EPCCOHPromotionCode,
                   tgt.OldSelectFlag = src.OLDSelectFlag,
                   tgt.OldSelectFlagDesc = src.OLDSelectFlagDesc,
                   tgt.NewSelectFlag = src.NEWSelectFlag,
                   tgt.NewSelectFlagDesc = src.NEWSelectFlagDesc,
                   tgt.RecommServiceCategory = src.RecommServiceCategory,
                   tgt.[12MonthInd] = src.[12MonthInd],
                   tgt.ClassificationCode = src.ClassificationCode,
                   tgt.PreviousClassificationCode = src.PreviousClassificationCode,
                   tgt.SEITSessionsPerWeek = src.SEITSessionsPerWk,
                   tgt.RecommendedRS = src.RecommendedRS,
                   tgt.FinalNoticeDate = src.FinalNoticeDate,
                   tgt.FinalNoticeConsentDate = src.FinalNoticeConsentDate,
                   tgt.AuthDate = src.AuthDate,
                   tgt.FirstAttendDate = src.FirstAttendDate,
                   tgt.NextMostRecentFAD = src.NextMostRecentFAD,
                   tgt.[Site] = src.[Site],
                   tgt.SiteClassNumber = src.SiteClassNumber,
                   tgt.ZonedSchool = src.ZonedSchool,
                   tgt.ZonedSchoolForLCGMS = src.ZONEDSchoolForLCGMS,
                   tgt.AssignedDBN = src.AssignedDBN,
                   tgt.HouseNumber = src.HouseNumber,
                   tgt.Street = src.Street,
                   tgt.BoroughCode = src.BoroCd,
                   tgt.ZipCode = src.ZipCode,
                   tgt.ApartmentNumber = src.AptNumber,
                   tgt.CityName = src.CityName,
                   tgt.GuardianLastName = src.GuardianLastName,
                   tgt.GuardianFirstName = src.GuardianFirstName,
                   tgt.GuardianPhoneNumber = src.GuardianPhoneNo,
                   tgt.GuardianLanguage = src.GuardianLanguage,
                   tgt.CSE = src.CSE,
                   tgt.SchoolCluster = src.SchoolCluster,
                   tgt.ClusterLeader = src.ClusterLeader,
                   tgt.SchoolNetwork = src.SchoolNetwork,
                   tgt.NetworkLeader = src.NetworkLeader,
                   tgt.Phase1Ind = src.Phase1Ind,
                   tgt.FirstTimeFlag = src.FirstTimeFlag,
                   tgt.FirstTimeDate = src.FirstTimeDate,
                   tgt.AlreadyAssigned = src.AlreadyAssigned,
                   tgt.CAPRunDate = src.RunDate,
                   tgt.SiteOfferCTR = src.SiteOfferCTR,
                   tgt.FNRStatus = src.FNRStatus,
                   tgt.LocationGroup = src.LocationGroup,
                   tgt.ComplianceGroup = src.ComplianceGroup,
                   tgt.CAPCompletionStatus = src.CAPCompletionStatus,
                   tgt.FirstPDConfDate = src.FirstPDConfDate,
                   tgt.FirstPDConsentedForSVCSDate = src.FirstPDConsentedForSVCSDate,
                   tgt.IsNewT5 = src.NewT5Flag,
                   tgt.IsTop = src.TopFlag,
                   tgt.IsBottom = src.BottomFlag,
                   tgt.IsNoNameStreet = src.NoNameStreetFlag,
                   tgt.IsSibling = src.SiblingFlag,
                   tgt.IsTurning5 = src.IsTurning5,
                   tgt.SchoolDBN = src.SchoolDBN,
                   tgt.WaveProcessedDate = src.WaveProcessedDate,
                   tgt.DHSDVFlag = src.DHSDVFlag,
                   tgt.D75Flag = src.D75Flag,
                   tgt.SiblingKey = src.SiblingKey,
				   /**** BiogReportFlag is set to Y if the following condition is true:		
						a.	If the current run’s biog are not same as the previous run’s biog data
						b.	If the Boro is not ‘Y’ or ‘Z’ 
						c.	If the Home district is not 88,98,99

						BiogReportFlag indicates the list of wave students in biog report. 
						Not all wave new student will be in biog report. 
						Only student with T5ProcessFlag=’Y’ (valid address or any DBN options) should be in biog report
				   ****/
                   tgt.BiogReportFlag = CASE
                                            WHEN CONCAT(
                                                           tgt.LastName,
                                                           tgt.FirstName,
                                                           tgt.BirthDate,
                                                           tgt.Gender,
                                                           tgt.HomeDistrict,
                                                           tgt.HouseNumber,
                                                           tgt.Street,
                                                           tgt.BoroughCode,
                                                           tgt.ZipCode,
                                                           tgt.ApartmentNumber,
                                                           tgt.CityName,
                                                           tgt.GuardianLastName,
                                                           tgt.GuardianFirstName,
                                                           tgt.GuardianPhoneNumber,
                                                           tgt.GuardianLanguage
                                                       ) <> BiogReportKey
                                                 --MIS-3802
                                                 AND src.BoroCd NOT IN ( 'Y', 'Z' )
                                                 --AND src.HomeDist NOT IN ( 88, 98, 99 ) --Commented 10/01/2024 to include HD outside NYC
												 THEN
                                                'Y'
                                            ELSE
                                                'N'
                                        END,
                   tgt.SESISFlag = src.SESISFlag, --Change the logic if this will impact deleted students we need to have 'N' SESISFlag only for new students. duplicate students will have 'Y'
                   tgt.ModifiedDate = @Today
    WHEN NOT MATCHED THEN
        INSERT
        (
            SchoolYear,
            T5RecordSource,
            SelectFlag,
            SelectFlagDate,
            D75AdminDBN,
            D75PhysicalDBN,
            CAPPrekSchool,
            ATSPrekSchoolDBN,
            IsPreK,
            EvalIniConsentDate,
            CaseType,
			IsCSETrueInitial,	--Added 4/22/2025 MIS-13135
            StudentID,
            AssignedLocationForTracking,
            AssignedLocationSource,
            CaseStatus,
            CaseProgress,
            EvaluationType,
            EvaluationDesc,
            ReferralDate,
            ReferralSchool,
            ConsentDate,
            CurrentCAPServiceSchool,
            ServiceSchoolName,
            AssessmentBilLangCode,
            CaseCloseDate,
            CaseCloseReasonCode,
            CaseCloseDesc,
            EvaluationComplianceDate,
            PlacementComplianceDate,
            CAPDischargeDate,
            CAPDischargeCode,
            HomeDistrict,
            LastName,
            FirstName,
            BirthDate,
            Gender,
            IEPConferenceDate,
            RecommendedProgram,
            DualRecmInd,
            StudParticipateInTestingFlag,
            EPCCOHPromotionCode,
            OldSelectFlag,
            OldSelectFlagDesc,
            NewSelectFlag,
            NewSelectFlagDesc,
            RecommServiceCategory,
            [12MonthInd],
            ClassificationCode,
            PreviousClassificationCode,
            SEITSessionsPerWeek,
            RecommendedRS,
            FinalNoticeDate,
            FinalNoticeConsentDate,
            AuthDate,
            FirstAttendDate,
            NextMostRecentFAD,
            [Site],
            SiteClassNumber,
            ZonedSchool,
            ZonedSchoolForLCGMS,
            AssignedDBN,
            HouseNumber,
            Street,
            BoroughCode,
            ZipCode,
            ApartmentNumber,
            CityName,
            GuardianLastName,
            GuardianFirstName,
            GuardianPhoneNumber,
            GuardianLanguage,
            CSE,
            SchoolCluster,
            ClusterLeader,
            SchoolNetwork,
            NetworkLeader,
            Phase1Ind,
            FirstTimeFlag,
            FirstTimeDate,
            AlreadyAssigned,
            CAPRunDate,
            SiteOfferCTR,
            FNRStatus,
            LocationGroup,
            ComplianceGroup,
            CAPCompletionStatus,
            FirstPDConfDate,
            FirstPDConsentedForSVCSDate,
            IsNewT5,
            IsTop,
            IsBottom,
            IsNoNameStreet,
            IsSibling,
            IsTurning5,
            SchoolDBN,
            WaveProcessedDate,
            DHSDVFlag,
            D75Flag,
            SiblingKey,
            SESISFlag,
            BiogReportFlag,
            ModifiedDate
        )
        VALUES
        (   src.SchoolYear, src.T5RecordSource, src.SelectFlag, src.SelectFlagDate, src.D75AdminDBN,
            src.D75PhysicalDBN, src.CAPPrekSchool, src.ATSPrekSchDBN, src.PreKFlag, src.DateEvalIniConsent,
            src.CaseType,src.IsCSETrueInitial, src.StudentID, src.AssignedLocationForTracking, src.AssignedLocationSource, src.CaseStatus,
            src.CaseProgress, src.EvaluationType, src.EvaluationDesc, src.ReferralDate, src.ReferralSchool, src.ConsentDate,
            src.CurrentCAPServiceSchool, src.ServiceSchoolName, src.AssessmentBilLangCode, src.CaseCloseDate,
            src.CaseCloseReasonCode, src.CaseCloseDesc, src.EvaluationComplianceDate, src.PlacementComplianceDate, src.CAPDischargeDate,
            src.CAPDischargeCode, src.HomeDist, src.StudentLastName, src.StudentFirstName, src.StudentDOB,
            src.StudentGender, src.IEPConferenceDate, src.RecommProgram, src.DualRecommInd, src.StudParticipateInTestingFlag,
            src.EPCCOHPromotionCode, src.OldSelectFlag, src.OldSelectFlagDesc, src.NewSelectFlag,
            src.NewSelectFlagDesc, src.RecommServiceCategory, src.[12MonthInd], src.ClassificationCode, src.PreviousClassificationCode,
            src.SEITSessionsPerWk, src.RecommendedRS, src.FinalNoticeDate, src.FinalNoticeConsentDate, src.AuthDate,
            src.FirstAttendDate, src.NextMostRecentFAD, src.[Site], src.SiteClassNumber, src.ZonedSchool,
            src.ZonedSchoolForLCGMS, src.AssignedDBN, src.HouseNumber, src.Street, src.BoroCd, src.ZipCode,
            src.AptNumber, src.CityName, src.GuardianLastName, src.GuardianFirstName, src.GuardianPhoneNo,
            src.GuardianLanguage, src.CSE, src.SchoolCluster, src.ClusterLeader, src.SchoolNetwork, src.NetworkLeader,
            src.Phase1Ind, src.FirstTimeFlag, src.FirstTimeDate, src.AlreadyAssigned, src.RunDate, src.SiteOfferCTR,
            src.FNRStatus, src.LocationGroup, src.ComplianceGroup, src.CAPCompletionStatus, src.FirstPDConfDate,
            src.FirstPDConsentedForSVCSDate,
			src.NewT5Flag, src.TopFlag, src.BottomFlag,
            src.NoNameStreetFlag,
            src.SiblingFlag,
            src.IsTurning5, src.SchoolDBN, src.WaveProcessedDate, src.DHSDVFlag, src.D75Flag, src.SiblingKey,
            src.SESISFlag,
			/** BiogReportFlag: Not all new students will be in BiogReport. 
			Only new students with T5ProcessFlag='Y' should be in BioReport. So for these new students we will update to Y in the same place we update ****/
            'N' ,      --BiogReportFlag 
            NULL    --tgt.ModifiedDate
            );
--##################################################################################################################################################


/**************************************************************
Christopher Agwu 12-07-2022 - MIS-8819
Update newly added columns IsBilingual and IsPOSLanguage
**************************************************************/
--Merge students languages 
Select StudentID, 
CASE WHEN GuardianLanguage='NO' THEN 'EN'
WHEN GuardianLanguage IS NULL THEN AssessmentBilLangCode ELSE GuardianLanguage 
END as NWGuardianLanguage,
CASE WHEN AssessmentBilLangCode='NO' THEN 'EN'  
WHEN AssessmentBilLangCode IS NULL THEN GuardianLanguage ELSE AssessmentBilLangCode
END AS NWAssessmentBilLangCode 
INTO #T5StudentLangMerge
From SEO_MART.dbo.RPT_T5StudentRegister
--Where WaveProcessedDate IS NULL; --Commented 1/29/2026 so students wqave/no wave will be updated. See ticket MIS-14873


/***************************************************************************
Christopher Agwu 08-07-2023 - MIS-9462
New IsBilingual indicator logic is now changed to use  AssessmentBilLangCode
and when AssessmentBilLangCode is blank then use GuardianLanguage
***************************************************************************/
--get t5 students bilingual languages
Select 'T5StudentRegister' as T5Source, l.*,
lc.LinkageLanguage as LangDescription,
--commented 9/8/2023 cagwu MIS-9492 - CASE WHEN ISNULL(l.StudentLanguageCode,'EN')='EN' THEN 0 ELSE 1 END as IsBilingual
CASE WHEN ISNULL(l.StudentLanguageCode,'EN') IN ('EN','SX') THEN 0 ELSE 1 END as IsBilingual
INTO #T5StudentLanguage
from (
	select StudentID, NWGuardianLanguage,NWAssessmentBilLangCode, 
	--commented 9/8/2023 cagwu MIS-9492 - CASE WHEN NWAssessmentBilLangCode<>'EN' THEN NWAssessmentBilLangCode	
	CASE WHEN NWAssessmentBilLangCode<>'EN' THEN NWAssessmentBilLangCode ELSE
	CASE WHEN NWGuardianLanguage='SX' AND NWAssessmentBilLangCode='EN' THEN NWGuardianLanguage END
	END AS StudentLanguageCode
	From #T5StudentLangMerge
) l left join SEO_MART.dbo.lk_LanguageCodes lc
on lc.Code=l.StudentLanguageCode
and lc.SourceName='CAP'			-- added by SergeyG on 2/23/2023 to substitute T5CAP with CAP as T5CAP data will not be used and is the same as CAP


--Changed to RPT_POSPsychDaysByDBNandLanguage 9/25/2025 ChrisAgwu
--Get t5 BL student and pos languages
Select f.*,
CASE WHEN f.LangDescription=f.POSLanguage AND f.POSLanguage<>'ENGLISH' THEN 1 ELSE 0 END as IsStudentPOSLanguage
INTO #T5StudentPOSLanguage 
From (
Select SL.*,POSL.* From #T5StudentLanguage SL
LEFT JOIN (select Distinct 'POSFile' as POSSource, UPPER(Language) AS POSLanguage from SEO_MART.dbo.RPT_POSPsychDaysByDBNandLanguage where IsBilingualPsych=1) POSL
ON POSL.POSLanguage=SL.LangDescription
) f;

--update t5studentregister isbilingual and isPOSlang
UPDATE SR 
SET SR.IsBilingual=SPOSL.IsBilingual,
SR.IsPOSLanguage=SPOSL.IsStudentPOSLanguage,
ModifiedDate=@Today
FROM SEO_MART.dbo.RPT_T5StudentRegister SR
INNER JOIN #T5StudentPOSLanguage SPOSL
ON SPOSL.StudentID=SR.StudentID
--Where SR.WaveProcessedDate IS NULL;  --Commented 1/29/2026 so students wqave/no wave will be updated. See ticket MIS-14873
--End-of-MIS-8819------------------------------------------------


--MIS-9077 DV Students Indicator. Currently using NoNameStreetFlag
--hence we need still to update DHSDVflag=DV for if NoNameStreetFlag=1
--This way all processes using DHSDVflag will still get correct count of DV students.
UPDATE SEO_MART.dbo.RPT_T5StudentRegister
SET DHSDVflag='DV',
ModifiedDate=@Today
WHERE IsNoNameStreet=1
--AND WaveProcessedDate IS NULL;	--Commented 1/18/2024 so students wave/no wave will be updated. per ticket MIS-10408
AND DHSDVFlag IS NULL;				--Adding filter so students already DHS will be skipped per ticket MIS-10408

--End-of-MIS-9077------------------------------------------------

---Archive Data--
--Load archive data-- Added 07/15/2024 MIS-11490
	--DECLARE @MaxArchiveDate DATETIME;
	--DECLARE @ArchiveData Bit=0

	--SET @MaxArchiveDate =
	--(
	--	SELECT MAX(ArchiveDate)
	--	FROM SEO_MART.arch.RPT_T5StudentRegister WITH (NOLOCK)
	--);	
	
 --   ------Archive only once in a day. This avoid multiple archive of same data in case of procedure rerun.		
	--IF CAST(@MaxArchiveDate as Date)=CAST(@Today as Date)
	--BEGIN
	--	Delete From SEO_MART.arch.RPT_T5StudentRegister Where ArchiveDate=@MaxArchiveDate;
	--	SET @ArchiveData=1;
	--END;    

	--IF (ISNULL(@MaxArchiveDate, 0) < CAST(@Today as Date))
 --   BEGIN
	--	SET @ArchiveData=1;
	--END;

	--IF @ArchiveData=1
	--BEGIN
    
		INSERT INTO SEO_MART.arch.RPT_T5StudentRegister
		(
			StudentID,
			CaseType,
			IsCSETrueInitial,
			SchoolYear,
			AssignedLocationForTracking,
			AssignedLocationSource,
			CaseStatus,
			CaseProgress,
			EvaluationType,
			EvaluationDesc,
			ReferralDate,
			ReferralSchool,
			ConsentDate,
			CurrentCAPServiceSchool,
			ServiceSchoolName,
			AssessmentBilLangCode,
			CaseCloseDate,
			CaseCloseReasonCode,
			CaseCloseDesc,
			EvaluationComplianceDate,
			PlacementComplianceDate,
			CAPDischargeDate,
			CAPDischargeCode,
			HomeDistrict,
			LastName,
			FirstName,
			BirthDate,
			Gender,
			IEPConferenceDate,
			RecommendedProgram,
			DualRecmInd,
			StudParticipateInTestingFlag,
			EPCCOHPromotionCode,
			OldSelectFlag,
			OldSelectFlagDesc,
			NewSelectFlag,
			NewSelectFlagDesc,
			RecommServiceCategory,
			[12MonthInd],
			ClassificationCode,
			PreviousClassificationCode,
			SEITSessionsPerWeek,
			RecommendedRS,
			FinalNoticeDate,
			FinalNoticeConsentDate,
			AuthDate,
			FirstAttendDate,
			NextMostRecentFAD,
			[Site],
			SiteClassNumber,
			ZonedSchool,
			ZonedSchoolForLCGMS,
			AssignedDBN,
			HouseNumber,
			Street,
			BoroughCode,
			ZipCode,
			ApartmentNumber,
			CityName,
			GuardianLastName,
			GuardianFirstName,
			GuardianPhoneNumber,
			GuardianLanguage,
			CSE,
			SchoolCluster,
			ClusterLeader,
			SchoolNetwork,
			NetworkLeader,
			Phase1Ind,
			FirstTimeFlag,
			FirstTimeDate,
			AlreadyAssigned,
			CAPRunDate,
			SiteOfferCTR,
			FNRStatus,
			LocationGroup,
			ComplianceGroup,
			CAPCompletionStatus,
			FirstPDConfDate,
			FirstPDConsentedForSVCSDate,
			IsNewT5,
			SchoolDBN,
			IsTop,
			IsBottom,
			IsNoNameStreet,
			SelectFlag,
			SelectFlagDate,
			D75AdminDBN,
			D75PhysicalDBN,
			CAPPrekSchool,
			IsPreK,
			ATSPrekSchoolDBN,
			EvalIniConsentDate,
			T5RecordSource,
			IsTurning5,
			DHSDVFlag,
			D75Flag,
			IsSibling,
			SiblingKey,
			SESISFlag,
			BiogReportFlag,
			WaveProcessedDate,
			ModifiedDate,
			ProcessedDate,
			ProcessedDateTime,
			IsBilingual,
			IsPOSLanguage,
			ModifiedReasons,
			WaveID,
			WaveDate,
			ArchiveDate,
			GuardianEmail
		)
		SELECT [StudentID],
			   [CaseType],
			   IsCSETrueInitial,
			   [SchoolYear],
			   [AssignedLocationForTracking],
			   [AssignedLocationSource],
			   [CaseStatus],
			   [CaseProgress],
			   [EvaluationType],
			   [EvaluationDesc],
			   [ReferralDate],
			   [ReferralSchool],
			   [ConsentDate],
			   [CurrentCAPServiceSchool],
			   [ServiceSchoolName],
			   [AssessmentBilLangCode],
			   [CaseCloseDate],
			   [CaseCloseReasonCode],
			   [CaseCloseDesc],
			   [EvaluationComplianceDate],
			   [PlacementComplianceDate],
			   [CAPDischargeDate],
			   [CAPDischargeCode],
			   [HomeDistrict],
			   [LastName],
			   [FirstName],
			   [BirthDate],
			   [Gender],
			   [IEPConferenceDate],
			   [RecommendedProgram],
			   [DualRecmInd],
			   [StudParticipateInTestingFlag],
			   [EPCCOHPromotionCode],
			   [OldSelectFlag],
			   [OldSelectFlagDesc],
			   [NewSelectFlag],
			   [NewSelectFlagDesc],
			   [RecommServiceCategory],
			   [12MonthInd],
			   [ClassificationCode],
			   [PreviousClassificationCode],
			   [SEITSessionsPerWeek],
			   [RecommendedRS],
			   [FinalNoticeDate],
			   [FinalNoticeConsentDate],
			   [AuthDate],
			   [FirstAttendDate],
			   [NextMostRecentFAD],
			   [Site],
			   [SiteClassNumber],
			   [ZonedSchool],
			   [ZonedSchoolForLCGMS],
			   [AssignedDBN],
			  [HouseNumber],
			   [Street],
			   [BoroughCode],
			   [ZipCode],
			   [ApartmentNumber],
			   [CityName],
			   [GuardianLastName],
			   [GuardianFirstName],
			   [GuardianPhoneNumber],
			   [GuardianLanguage],
			   [CSE],
			   [SchoolCluster],
			   [ClusterLeader],
			   [SchoolNetwork],
			   [NetworkLeader],
			   [Phase1Ind],
			   [FirstTimeFlag],
			   [FirstTimeDate],
			   [AlreadyAssigned],
			   [CAPRunDate],
			   [SiteOfferCTR],
			   [FNRStatus],
			   [LocationGroup],
			   [ComplianceGroup],
			   [CAPCompletionStatus],
			   [FirstPDConfDate],
			   [FirstPDConsentedForSVCSDate],
			   [IsNewT5],
			   [SchoolDBN],
			   [IsTop],
			   [IsBottom],
			   [IsNoNameStreet],
			   [SelectFlag],
			   [SelectFlagDate],
			   [D75AdminDBN],
			   [D75PhysicalDBN],
			   [CAPPrekSchool],
			   [IsPreK],
			   [ATSPrekSchoolDBN],
			   [EvalIniConsentDate],
			   [T5RecordSource],
			   [IsTurning5],
			   [DHSDVFlag],
			   [D75Flag],
			   [IsSibling],
			   [SiblingKey],
			   [SESISFlag],
			   [BiogReportFlag],
			   [WaveProcessedDate],
			   [ModifiedDate],
			   [ProcessedDate],
			   [ProcessedDateTime],
			   IsBilingual,
			   IsPOSLanguage,
			   ModifiedReasons,
			   WaveID,
			   WaveDate,
			   @Today,
			   GuardianEmail
		FROM [SEO_MART].[dbo].[RPT_T5StudentRegister] WITH (NOLOCK);
        
	--END;
END;
