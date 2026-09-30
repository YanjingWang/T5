USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPINT_T5DuplicateStudentCorrectionUPD]    Script Date: 4/4/2026 2:24:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[USPINT_T5DuplicateStudentCorrectionUPD]

AS

BEGIN

/***********************************************************************************************************************************************************
Object Name: dbo.USPINT_T5DuplicateStudentCorrectionUPD
Sample call: Exec USPINT_T5DuplicateStudentCorrectionUPD
Purpose: Update new(duplicate) StudentID for students who have gone through wave in SEO_MART and whose profile created already in SESIS.
Date Created: 01/09/2019

Modification Details:

Author					ModifiedDate	Ticket# 	Comments
Pangajam Subburaja                                  Initial Draft
Pangajam Subburaja	    12/01/2020                  Rollover as per 2.0 standards
Raja M					11/19/2021			        Automated SchoolYear calculation..
Christopher Agwu		01/12/2024			        Added code to update ModifiedReason note to RPT_T5STudentAssignment table. See JIRA Ticket MIS-10368
											        And Set RPT_T5StudentRegister IsTurning5=0 for the duplicate StudentID
Christopher Agwu		01/16/2024			        Add code to execute T5CaseAssignmentCapacity Tracker. See JIRA Ticket MIS-9344
Christopher Agwu		11/05/2024			        Added table alias to update RPT_T5SA code block
Christopher Agwu		02/27/2025			        Updated code,added T5IEPTeamLanguage. Commented out CaseAssgnCapa Tracker until its updated.
Christopher Agwu		04/11/2025			        Add missing columns to RPT_T5StudentAssignment table (IsBilingual,ModifiedReasons,WaveID,WaveDate,T5IEPTeamLanguage,GuardianEmail) MIS-13120
Christopher Agwu		05/08/2025			        Add/update missing columns to RPT_T5StudentRegister table (IsTurning,WaveID, WabeDate,IsBilingual) MIS-13197
Michael                 01/16/2026     MIS-14446    Modified to reference DWH_T5DuplicateStudentCorrection table
Michael                 02/13/2026     MIS-14446    Changed wording from DuplicateStudent to DuplicateStudentCorrection
*********************************************************************************************************************************************************************************************/


    DECLARE @SchoolYear VARCHAR(9)
    DECLARE @Today DATETIME;
	
	Set @SchoolYear = (Select dbo.fn_GetT5SchoolYear());
    SET @Today = GETDATE();

	Exec dbo.USPT5_T5CaseAssignmentCapacityTracker 'Before','DuplicateStudentCorrection';		--Added 1/16/2024

    IF OBJECT_ID('tempdb..#T5Reg') IS NOT NULL
        DROP TABLE #T5Reg;

    SELECT Old.[StudentID],
           Old.NewStudentID, ----Newer StudentID for wave assigned Kid
           Old.OldStudentID, ----Existing StudentID for wave assigned Kid
           Old.[CaseType],
           Old.[SchoolYear],
           Old.[AssignedLocationForTracking],
           Old.[AssignedLocationSource],
           Old.[CaseStatus],
           Old.[CaseProgress],
           Old.[EvaluationType],
           Old.[EvaluationDesc],
           Old.[ReferralDate],
           Old.[ReferralSchool],
           Old.[ConsentDate],
           Old.[CurrentCAPServiceSchool],
           Old.[ServiceSchoolName],
           Old.[AssessmentBilLangCode],
           Old.[CaseCloseDate],
           Old.[CaseCloseReasonCode],
           Old.[CaseCloseDesc],
           Old.[EvaluationComplianceDate],
           Old.[PlacementComplianceDate],
           Old.[CAPDischargeDate],
           Old.[CAPDischargeCode],
           Old.[HomeDistrict],
           Old.[LastName],
           Old.[FirstName],
           Old.[BirthDate],
           Old.[Gender],
           Old.[IEPConferenceDate],
           Old.[RecommendedProgram],
           Old.[DualRecmInd],
           Old.[StudParticipateInTestingFlag],
           Old.[EPCCOHPromotionCode],
           Old.[OldSelectFlag],
           Old.[OldSelectFlagDesc],
           Old.[NewSelectFlag],
           Old.[NewSelectFlagDesc],
           Old.[RecommServiceCategory],
           Old.[12MonthInd],
           Old.[ClassificationCode],
           Old.[PreviousClassificationCode],
           Old.[SEITSessionsPerWeek],
           Old.[RecommendedRS],
           Old.[FinalNoticeDate],
           Old.[FinalNoticeConsentDate],
           Old.[AuthDate],
           Old.[FirstAttendDate],
           Old.[NextMostRecentFAD],
           Old.[Site],
           Old.[SiteClassNumber],
           Old.[ZonedSchool],
           Old.[ZonedSchoolForLCGMS],
           Old.[AssignedDBN],
           Old.[HouseNumber],
           Old.[Street],
           Old.[BoroughCode],
           Old.[ZipCode],
           Old.[ApartmentNumber],
           Old.[CityName],
           Old.[GuardianLastName],
           Old.[GuardianFirstName],
           Old.[GuardianPhoneNumber],
           Old.[GuardianLanguage],
           Old.[CSE],
           Old.[SchoolCluster],
           Old.[ClusterLeader],
           Old.[SchoolNetwork],
           Old.[NetworkLeader],
           Old.[Phase1Ind],
           Old.[FirstTimeFlag],
           Old.[FirstTimeDate],
           Old.[AlreadyAssigned],
           Old.[CAPRunDate],
           Old.[SiteOfferCTR],
           Old.[FNRStatus],
           Old.[LocationGroup],
           Old.[ComplianceGroup],
           Old.[CAPCompletionStatus],
           Old.[FirstPDConfDate],
           Old.[FirstPDConsentedForSVCSDate],
           --Old.[ProcessedDate],
		   @Today AS [ProcessedDate],
		   @Today AS [ProcessedDateTime],----Newly Added
           Old.[IsNewT5],
           Old.[SchoolDBN],
           Old.[IsTop],
           Old.[IsBottom],
           Old.[IsNoNameStreet],
           Old.[SelectFlag],
           Old.[SelectFlagDate],
           Old.[D75AdminDBN],
           Old.[D75PhysicalDBN],
           Old.[CAPPrekSchool],
           Old.[IsPreK],
           Old.[ATSPrekSchoolDBN],
           Old.[EvalIniConsentDate],
           Old.[T5RecordSource],
           Old.[IsTurning5],
           Old.[DHSDVFlag],
           Old.[D75Flag],
           Old.[IsSibling],
           Old.[SiblingKey],
           Old.[SESISFlag],
           Old.[BiogReportFlag],
           Old.[WaveProcessedDate],
		   Old.IsBilingual,
		   Old.WaveID,
		   Old.WaveDate		   
		    --@Today AS [WaveProcessedDate]	--commented 2/27/2025 Cagwu. We should not change WaveProcessedDate here. Today is not the wave date
    INTO #T5Reg
    FROM
    (
        SELECT S.*,
               S.StudentID AS OldStudentID, ----Existing StudentID for wave assigned Kid
               DS.StudentID AS NewStudentID ----Newer StudentID for wave assigned Kid
        FROM [SEO_MART].[dbo].[DWH_T5DuplicateStudentCorrection] DS WITH (NOLOCK)
        LEFT JOIN [SEO_MART].[dbo].[RPT_T5StudentRegister] S WITH (NOLOCK)
        ON S.StudentID = DS.OldStudentID
        AND S.SchoolYear = DS.SchoolYear
        WHERE DS.SchoolYear = @SchoolYear
        AND DS.ProcessedDate IS NULL
    ) Old
        LEFT JOIN
        (
            SELECT S.* ----Existing Student data for wave assigned Kid
            FROM [SEO_MART].[dbo].[DWH_T5DuplicateStudentCorrection] DS WITH (NOLOCK)
            LEFT JOIN [SEO_MART].[dbo].[RPT_T5StudentRegister] S WITH (NOLOCK)
            ON S.StudentID = DS.StudentID ----New student from T5_DuplicateStudentCorrection table
            AND S.SchoolYear = DS.SchoolYear
            WHERE DS.SchoolYear = @SchoolYear
            AND DS.ProcessedDate IS NULL
        ) New
            ON Old.NewStudentID = New.StudentID -----Join on new StudentID
            AND Old.SchoolYear = New.SchoolYear
    WHERE 
    New.StudentID IS NULL ----Pick only new studentId records not existing in RPT_T5StudentRegister table
   


    INSERT INTO SEO_MART.dbo.RPT_T5StudentAssignment
    (
        [StudentID], ----Newer StudentID for wave assigned Kid
        [T5IEPTeam],
        [T5IEPTeamDesc],
        [T5IEPTeamType],
        [LocationType],
        [SchoolYear],
        [CaseType],
        [LastName],
        [FirstName],
        [BirthDate],
        [Gender],
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
        [CurrentAddAdminDBN],
        [SelectFlag],
        [SelectFlagDate],
        [CSE],
        [HomeDistrict],
        [AssignedLocationForTracking],
        [CSESchool],
        [IsTurning5],
        [IsTop],
        [IsBottom],
        [IsNoNameStreet],
        [IsSibling],
        [DHSDVFlag],
        [D75Flag],
        [D75AdminDBN],
        [D75PhysicalDBN],
        [CAPPreKSchool],
        [ATSPreKSchoolDBN],
        [ZonedSchool],
        [IsPreK],
        [EvalIniConsentDate],
        [FirstPDConferenceDate],
        [ReferralSchool],
        [AssessmentBilLangCode],
        [ReferralDate],
        [ProcessedDate], 
		[ProcessedDateTime],----Newly Added
        [RecommendedProgram],
        [CAPDischargeCode],
        [CaseCloseReasonCode],
        [T5RecordSource],
        [CurrentCAPServiceSchool],
        [ServiceSchoolName],
        [SiblingKey],
        [Location],
       -- [CreatedDate], 
       -- [ModifiedDate],
        [CurrentWaveFlag],
        [BiogReportFlag],
        [ValidAddressFlag],
        [T5ProcessFlag],
        [ActiveFlag],
        [ZonedDistrict],
        [CAPRunDate],
        [ReassignmentDate],
		IsBilingual,
		ModifiedReasons,
		WaveID,
		WaveDate,
		T5IEPTeamLanguage,
		GuardianEmail		
    )
    SELECT NewStudentID, ----Newer StudentID for wave assigned Kid
           Old.[T5IEPTeam],
           Old.[T5IEPTeamDesc],
           Old.[T5IEPTeamType],
           Old.[LocationType],
           Old.[SchoolYear],
           Old.[CaseType],
           Old.[LastName],
           Old.[FirstName],
           Old.[BirthDate],
           Old.[Gender],
           Old.[HouseNumber],
           Old.[Street],
           Old.[BoroughCode],
           Old.[ZipCode],
           Old.[ApartmentNumber],
           Old.[CityName],
           Old.[GuardianLastName],
           Old.[GuardianFirstName],
           Old.[GuardianPhoneNumber],
           Old.[GuardianLanguage],
           Old.[CurrentAddAdminDBN],
           Old.[SelectFlag],
           Old.[SelectFlagDate],
           Old.[CSE],
           Old.[HomeDistrict],
           Old.[AssignedLocationForTracking],
           Old.[CSESchool],
           Old.[IsTurning5],
           Old.[IsTop],
           Old.[IsBottom],
           Old.[IsNoNameStreet],
           Old.[IsSibling],
           Old.[DHSDVFlag],
           Old.[D75Flag],
           Old.[D75AdminDBN],
           Old.[D75PhysicalDBN],
           Old.[CAPPreKSchool],
           Old.[ATSPreKSchoolDBN],
           Old.[ZonedSchool],
           Old.[IsPreK],
           Old.[EvalIniConsentDate],
           Old.[FirstPDConferenceDate],
           Old.[ReferralSchool],
           Old.[AssessmentBilLangCode],
           Old.[ReferralDate],
           Old.[ProcessedDate],
		   Old.ProcessedDateTime, -----------Newly Added
           Old.[RecommendedProgram],
           Old.[CAPDischargeCode],
           Old.[CaseCloseReasonCode],
           Old.[T5RecordSource],
           Old.[CurrentCAPServiceSchool],
           Old.[ServiceSchoolName],
           Old.[SiblingKey],
           Old.[Location],
         --  @Today AS [CreatedDate],------------------double check
          -- Old.[ModifiedDate],
           Old.[CurrentWaveFlag],
           Old.[BiogReportFlag],
           Old.[ValidAddressFlag],
           Old.[T5ProcessFlag],
           Old.[ActiveFlag],
           Old.[ZonedDistrict],
           Old.[CAPRunDate],
           Old.[ReassignmentDate],
		   Old.IsBilingual,
			Old.ModifiedReasons,
			Old.WaveID,
			Old.WaveDate,		
		   Old.T5IEPTeamLanguage,
		   Old.GuardianEmail		
    FROM
    (
        SELECT S.*,
               DS.StudentID AS NewStudentID  ----Newer StudentID for wave assigned Kid
        FROM [SEO_MART].[dbo].[DWH_T5DuplicateStudentCorrection] DS WITH (NOLOCK)
        LEFT JOIN [SEO_MART].[dbo].[RPT_T5StudentAssignment] S WITH (NOLOCK)
        ON S.StudentID = DS.OldStudentID
        AND S.SchoolYear = DS.SchoolYear
        WHERE S.ActiveFlag = 'Y'
        AND DS.SchoolYear = @SchoolYear
        AND DS.ProcessedDate IS NULL
    ) Old
        LEFT JOIN
        (
            SELECT S.* ----Existing StudentID for wave assigned Kid
            FROM [SEO_MART].[dbo].[DWH_T5DuplicateStudentCorrection] DS WITH (NOLOCK)
            LEFT JOIN [SEO_MART].[dbo].[RPT_T5StudentAssignment] S WITH (NOLOCK)
            ON S.StudentID = DS.StudentID
            AND S.SchoolYear = DS.SchoolYear
            WHERE S.ActiveFlag = 'Y'
            AND DS.SchoolYear = @SchoolYear
            AND DS.ProcessedDate IS NULL
        ) New
        ON Old.NewStudentID = New.StudentID
    WHERE New.StudentID IS NULL;

	
   INSERT INTO [SEO_MART].[dbo].[RPT_T5StudentRegister]
    (
        [StudentID], ----Newer StudentID for wave assigned Kid
        [CaseType],
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
        [ProcessedDate],
		[ProcessedDateTime], ----Newly Added
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
		 IsBilingual,
		 WaveID,
		 WaveDate		
      --  ,[CreatedDate]----double check now
    )
    SELECT NewStudentID, ----Newer StudentID for wave assigned Kid							 
           [CaseType],
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
           [ProcessedDate],
		   [ProcessedDateTime],------------Newly Added
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
		    IsBilingual,
		   WaveID,
		   WaveDate		
          --,@Today
    FROM #T5Reg;

    -------------Update Inactive record for older StudentID
    UPDATE S
    SET S.ActiveFlag ='N',
	    S.CurrentWaveFlag='N',
        S.ModifiedDate = @Today,
        --T5RecordSource = 'DuplicateStudentCorrection'	--commented 1/12/2024
		S.ModifiedReasons='DuplicateStudentCorrection'	--added 1/12/2024
        FROM [SEO_MART].[dbo].[RPT_T5StudentAssignment] S WITH(NOLOCK)
        INNER JOIN [SEO_MART].[dbo].[DWH_T5DuplicateStudentCorrection] DS WITH (NOLOCK)
        ON DS.OldStudentID = S.StudentID
        AND DS.SchoolYear = S.SchoolYear
		WHERE S.ActiveFlag ='Y'
        AND DS.SchoolYear = @SchoolYear
        AND DS.ProcessedDate IS NULL;

	
	--Set IsTurning5=0 in RPT_T5STudentRegister for the duplicate studentid--
	--Added 1/12/2024--
	UPDATE SR
	SET SR.IsTurning5=0,
	SR.ModifiedDate=@Today,
	SR.ModifiedReasons='DuplicateStudentCorrection'
	FROM dbo.RPT_T5StudentRegister SR
	INNER JOIN dbo.DWH_T5DuplicateStudentCorrection DS
	ON DS.OldStudentID=SR.StudentID
	AND DS.SchoolYear=SR.SchoolYear
	Where DS.ProcessedDate IS NULL;
	   

    /****After processing current week duplicate student, update processedDate.T5_DuplicateStudentCorrection table is incremental table and no truncate. 
Pick latest correction data using processedDate as NULL at the begining of T5 duplicate correction process and update at the end of process.***/
    UPDATE [SEO_MART].[dbo].[DWH_T5DuplicateStudentCorrection]
    SET ProcessedDate = GETDATE()
    WHERE ProcessedDate IS NULL;

	Exec dbo.USPT5_T5CaseAssignmentCapacityTracker 'After','DuplicateStudentCorrection';		--Added 1/16/2024
END;


