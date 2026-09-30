USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPDWH_T5SourceExtract]    Script Date: 4/4/2026 1:40:55 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[USPDWH_T5SourceExtract]  
  
AS  
  
BEGIN
  
SET XACT_ABORT ON;  
SET NOCOUNT ON;  

  
/**************************************************************************************************************************************************  
Object Name: USPDWH_SourceExtract
Purpose:    Populate USPDWH_SourceExtract data from ATLAS KIPData (source). Truncate and Load            
            
Date Created: 10/06/2025  
  
Modification Details:  
 
Author			    ModifiedDate	Comments  
Christopher Agwu    10/06/2025		Initial 
Christopher Agwu    10/07/2025      Nulled (RecommServiceCategory) column because it creates duplicate and its not needed in SEO MART. As discussed with Raji, Ariel, Thomas. MIS-14329
***************************************************************************************************************************************************/  


    Declare @TodayDate Date, @TodayDatetime Datetime, @RecCNT INT,@RecCNT2 INT, @SchoolYear Varchar(9),
    @ETLProcessedDate date, @ETLProcessedDateTime Datetime, @ETLPreviousDay date, @Msg Varchar(150);
    
    Set @TodayDatetime = getdate()
    Set @TodayDate = getdate()
    Set @SchoolYear=(Select dbo.fn_GetT5SchoolYear());

    --check rowcount of source--
    SET @RecCNT=(Select Count(*) from SEDMSLINK_180.SEDMS.dbo.KIPData Where SchoolYear=@SchoolYear);
    
    
    --if source count is 200 rows less than prod (14,317) then there is issue to look at--
    IF @RecCNT<=14117
    BEGIN
        SET @Msg='***ERROR*** KIPData rowcount is less than previous rowcount. Process cannot continue!'
        RAISERROR(@Msg,16,1);
        RETURN;        
    END;
    
    --truncate table--
    Truncate Table dbo.DWH_T5SourceExtract;

    --populate table--
    INSERT INTO dbo.DWH_T5SourceExtract
    (
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
        RecommProgram,
        DualRecommInd,
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
        SEITSessionsPerWk,
        RecommendedRS,
        FinalNoticeDate,
        FinalNoticeConsentDate,
        AuthDate,
        FirstAttendDate,
        NextMostRecentFAD,
        Site,
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
        RunDate,
        SiteOfferCTR,
        FNRStatus,
        LocationGroup,
        ComplianceGroup,
        CAPCompletionStatus,
        FirstPDConfDate,
        FirstPDConsentedForSVCSDate,
        SchoolYear,
        ATLASCreatedDate,
        ATLASModifiedDate,
        ATLASSourcedFrom,
        ProcessedDate,
        GuardianEmail
    )
    Select R.* From (
        Select DISTINCT
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
        CurrentATLASServiceSchool,
        ServiceSchoolName,
        AssessmentBilLangCode,
        CaseCloseDate,
        CaseCloseReasonCode,
        CaseCloseDesc,
        EvaluationComplianceDate,
        PlacementComplianceDate,
        ATLASDischargeDate,
        ATLASDischargeCode,
        HomeDistrict,
        LastName,
        FirstName,
        BirthDate,
        Gender,
        IEPConferenceDate,
        RecommProgram,
        DualRecmInd,
        StudParticipateInTestingFlag,
        EPCCOHPromotionCode,
        OldSelectFlag,
        OldSelectFlagDesc,
        NEWSelectFlag,
        NEWSelectFlagDesc,
        NULL as RecommServiceCategory,
        [12MonthInd],
        ClassificationCode,
        PreviousClassificationCode,
        SEITSessionsPerWeek,
        Recm_RS,
        FinalNoticeDt,
        FinalNoticeConsentDate,
        AuthorizedDate,
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
        ZIP,
        ApartmentNumber,
        City,
        GuardianLastName,
        GuardianFirstName,
        GuardianPhoneNumber,
        GuardianLanguage,
        CSE,
        SchCluster,
        ClusterLeader,
        SchNetwork,
        NetworkLeader,
        PhaseI_Ind,
        FirstTimeFlag,
        FirstTimeDate,
        AlreadyAssigned,
        ATLASRunDate,
        SITE_OFFER_CTR,
        FNR_STATUS,
        LOCATION_GROUP,
        COMPLIANCE_GROUP,
        ATLASCompletionStatus,
        FIRST_PD_CONF_DT,
        FirstPDConsentedForSVCSDate,
        SchoolYear,
        ATLASCreatedDate,
        ATLASModifiedDate,
        ATLASSourcedFrom,
        @TodayDate as ProcessedDate,
        GuardianEmail        
        From [SEDMSLINK_180].[SEDMS].[dbo].[KIPData]
        Where SchoolYear=@SchoolYear
     ) R;

     --archive--
     INSERT INTO arch.DWH_T5SourceExtract (
    StudentID,AssignedLocationForTracking,AssignedLocationSource,CaseStatus,CaseProgress,EvaluationType,EvaluationDesc,ReferralDate,
    ReferralSchool,ConsentDate,CurrentCAPServiceSchool,ServiceSchoolName,AssessmentBilLangCode,CaseCloseDate,CaseCloseReasonCode,
    CaseCloseDesc,EvaluationComplianceDate,PlacementComplianceDate,CAPDischargeDate,CAPDischargeCode,HomeDistrict,LastName,FirstName,
    BirthDate,Gender,IEPConferenceDate,RecommProgram,DualRecommInd,StudParticipateInTestingFlag,EPCCOHPromotionCode,OldSelectFlag,
    OldSelectFlagDesc,NewSelectFlag,NewSelectFlagDesc,RecommServiceCategory,[12MonthInd],ClassificationCode,PreviousClassificationCode,
    SEITSessionsPerWk,RecommendedRS,FinalNoticeDate,FinalNoticeConsentDate,AuthDate,FirstAttendDate,NextMostRecentFAD,[Site],SiteClassNumber,
    ZonedSchool,ZonedSchoolForLCGMS,AssignedDBN,HouseNumber,Street,BoroughCode,ZipCode,ApartmentNumber,CityName,GuardianLastName,GuardianFirstName,
    GuardianPhoneNumber,GuardianLanguage,CSE,SchoolCluster,ClusterLeader,SchoolNetwork,NetworkLeader,Phase1Ind,FirstTimeFlag,FirstTimeDate,AlreadyAssigned,
    RunDate,SiteOfferCTR,FNRStatus,LocationGroup,ComplianceGroup,CAPCompletionStatus,FirstPDConfDate,FirstPDConsentedForSVCSDate,SchoolYear,ATLASCreatedDate,
    ATLASModifiedDate,ATLASSourcedFrom,ProcessedDate,ArchiveDatetime, GuardianEmail
    )
    Select 
    StudentID,AssignedLocationForTracking,AssignedLocationSource,CaseStatus,CaseProgress,EvaluationType,EvaluationDesc,ReferralDate,
    ReferralSchool,ConsentDate,CurrentCAPServiceSchool,ServiceSchoolName,AssessmentBilLangCode,CaseCloseDate,CaseCloseReasonCode,
    CaseCloseDesc,EvaluationComplianceDate,PlacementComplianceDate,CAPDischargeDate,CAPDischargeCode,HomeDistrict,LastName,FirstName,
    BirthDate,Gender,IEPConferenceDate,RecommProgram,DualRecommInd,StudParticipateInTestingFlag,EPCCOHPromotionCode,OldSelectFlag,
    OldSelectFlagDesc,NewSelectFlag,NewSelectFlagDesc,RecommServiceCategory,[12MonthInd],ClassificationCode,PreviousClassificationCode,
    SEITSessionsPerWk,RecommendedRS,FinalNoticeDate,FinalNoticeConsentDate,AuthDate,FirstAttendDate,NextMostRecentFAD,[Site],SiteClassNumber,
    ZonedSchool,ZonedSchoolForLCGMS,AssignedDBN,HouseNumber,Street,BoroughCode,ZipCode,ApartmentNumber,CityName,GuardianLastName,GuardianFirstName,
    GuardianPhoneNumber,GuardianLanguage,CSE,SchoolCluster,ClusterLeader,SchoolNetwork,NetworkLeader,Phase1Ind,FirstTimeFlag,FirstTimeDate,AlreadyAssigned,
    RunDate,SiteOfferCTR,FNRStatus,LocationGroup,ComplianceGroup,CAPCompletionStatus,FirstPDConfDate,FirstPDConsentedForSVCSDate,SchoolYear,ATLASCreatedDate,
    ATLASModifiedDate,ATLASSourcedFrom,ProcessedDate, @TodayDatetime as ArchiveDatetime, GuardianEmail
    From
    dbo.DWH_T5SourceExtract;


END;
