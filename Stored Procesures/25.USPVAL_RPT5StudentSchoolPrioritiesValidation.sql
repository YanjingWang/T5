USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPVAL_RPT5StudentSchoolPrioritiesValidation]    Script Date: 4/4/2026 2:51:05 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/************************************************************************************************************************************************************************  
Object Name: USPVAL_RPT5StudentSchoolPrioritiesValidation  
Purpose: This procedure validates RPT_T5StudentSchoolPriorities data load per BRD  
     
Date Created: 10/07/2024  
Modification Details:  
  
Author    ModifiedDate  Comments  
Christopher Agwu 10/02/2024   Initial version  
Christopher Agwu 10/17/2024   Added code to filter RPT_T5SSP by current WaveID  
Christopher Agwu 10/28/2024   Added code to override failed validation per review outcome.  
Chritopher Agwu  12/05/2024   Added code for warning message and remove compare with StudentInvalidAddress as error file is loaded much later.  
Christopher Agwu 05/29/2025   Added validation for T5Manual Wave processing  
Charlotte Wang      10/28/2025          Change CSEONLYFlag='X' validation to IN ('Y','N') for standard waves (non-manual). Add check: if CSEOnlyFlag='X' => consider “no wave in progress” and FAIL. Remove lines 81–97 (old zoning/priorities cross-check + wa

rning) by commenting out the block. Rename counters: SourceCNT -> EligibleCNT; DestCNT -> PrioritiesCNT (variable names updated throughout).  
Christopher Agwu    11/26/2025  Change old Valkey from 129001 to 147001. This is due to merging RPT_T5SSP and INT_T5TSA to one job.
Charlotte          02/05/2026       When checking "sibling" count, a zero sibling count is a non-issue
                                We may not have any siblings in later waves.
                                For ex, in SY26, Wave 4 doens't have any siblings
***************************************************************************************************************************************************************************/  
  
ALTER PROCEDURE [dbo].[USPVAL_RPT5StudentSchoolPrioritiesValidation]  
AS  
BEGIN  
 SET NOCOUNT ON;  
  
 -- Original declarations (kept where still relevant); renamed per requirement.  
 --Declare @SourceCNT INT, @DestCNT INT,@ZonedRecCNT INT, @TotZonedCNT INT, @T5BDYear INT,@Today Date,@WaveID INT,@RecCNT INT,  
 --@ValStatus Varchar(4), @ValKey INT,@ValidationMsgs varchar(1000), @ValHeader Varchar(100),@WarningMsg Varchar(100),@CSEOnlyFlag Varchar(1),  
 --@IsValOverride SmallINT,  @IsValDone SmallINT, @CTUEDate Date  
  
 -- Charlotte: Renamed / added variables  
 Declare @EligibleCNT INT, @PrioritiesCNT INT, @ZonedRecCNT INT, @TotZonedCNT INT,  
         @T5BDYear INT, @Today Date, @WaveID INT, @RecCNT INT,  
         @ValStatus Varchar(4), @ValKey INT, @ValidationMsgs varchar(1000),  
         @ValHeader Varchar(100), @WarningMsg Varchar(100),  
         @CSEOnlyFlag Varchar(1), @IsValOverride SmallINT, @IsValDone SmallINT, @CTUEDate Date,  
         @EligibleCNTSibling INT, @PrioritiesCNTSibling INT,
         @LogMsg varchar(2000);  -- Charlotte: for logging expressions  
  
 SET @Today = GETDATE();  
 SET @CTUEDate = (SELECT dbo.fn_GetWeekDayDate('CTU'));  
 SET @ValHeader = 'RPT_T5StudentSchoolPriorities Validation';  
 SET @ValKey = 147001;  
 SET @ValStatus = 'BEG';  
 SET @ValidationMsgs = CONCAT('Starting ', @ValHeader);  
  
 -- Current wave in-progress info  
 SELECT @WaveID = WaveID, @CSEOnlyFlag = CSEOnlyFlag  
 FROM dbo.INT_T5WaveSchedule   
 WHERE WaveStatus = 'I';  
  
 --get/check validation overrideID  
 SET @IsValDone = 2;  
 SET @IsValOverride = (  
  SELECT ValOverrideID  
  FROM dbo.SEODataValidationOutcome  
  WHERE ValKey=@ValKey AND ValOverrideID=1 AND CAST(CreatedDatetime AS DATE)=@Today  
 );  
  
 IF @IsValOverride = 1  
 BEGIN  
  --SET @ValHeader = (SELECT CONCAT(@ValHeader, ' - Overridden - ')); -- Charlotte: avoid SELECT wrapper  
  SET @ValHeader = @ValHeader + ' - Overridden - ';  
  SET @ValStatus = 'OVERRIDE';  
  
  --update ValOverrideID  
  UPDATE dbo.SEODataValidationOutcome   
   SET ValOverrideID=@IsValDone,  
       ModifiedDateTime=GETDATE(),  
       ModifiedBy=SYSTEM_USER  
  WHERE ValKey=@ValKey AND ValOverrideID=1 AND CAST(CreatedDatetime AS DATE)=@Today;      
  GOTO OverrideValidation;  
 END;  
  
 --Start validation  
 SET @LogMsg = @ValidationMsgs;  
 EXEC dbo.USPSEO_DataValidationOutcomeINS @ValStatus, @ValKey, @LogMsg;  
  
 /* Charlotte: New guard - if CSEOnlyFlag = 'X' (unexpected) or no in-progress wave, FAIL immediately */  
 IF ISNULL(@CSEOnlyFlag, 'X') = 'X' OR @WaveID IS NULL  
 BEGIN  
  SET @ValStatus = 'FAIL';  
  SET @ValidationMsgs = CONCAT(@ValidationMsgs, ' 0: No active wave in progress (CSEOnlyFlag=''X'' or WaveID is NULL).');  
  SET @LogMsg = CONCAT(@ValHeader, ' - ', @ValidationMsgs);  
  EXEC dbo.USPSEO_DataValidationOutcomeINS @ValStatus, @ValKey, @LogMsg;  
  GOTO OverrideValidation;  
 END;  
  
 --Test-D18--   
 --Verify all students in INT_T5WaveEligibleStudent are in RPT_T5StudentSchoolPriorities (includes students in JH error file)  
 -- Charlotte: Change CSEONLYFlag='X' validation to IN ('Y','N') (standard waves)  
 IF ISNULL(@CSEOnlyFlag,'X') IN ('Y','N')  
 BEGIN  
  -- Charlotte: variable rename SourceCNT -> EligibleCNT ; DestCNT -> PrioritiesCNT  
  SET @EligibleCNT = (  
   SELECT COUNT(DISTINCT StudentID)  
   FROM dbo.INT_T5WaveEligibleStudents  
   WHERE WaveID IS NULL  
  );  
  
  SET @PrioritiesCNT = (  
   SELECT COUNT(DISTINCT StudentID)  
   FROM dbo.RPT_T5StudentSchoolPriorities  
   WHERE WaveID = @WaveID  
  );  
  
  IF (@EligibleCNT + @PrioritiesCNT) = 0 OR (@EligibleCNT <> @PrioritiesCNT)  
  BEGIN  
   SET @ValStatus = 'FAIL';  
   SET @ValidationMsgs = CONCAT(  
    @ValidationMsgs,  
    ' 1:RPT_T5StudentSchoolPriorities is empty or count does not match INT_T5WaveEligibleStudents. ',  
    'EligibleCnt=', @EligibleCNT, ', PrioritiesCnt=', @PrioritiesCNT, '.'  
   );  
   SET @LogMsg = CONCAT(@ValHeader, ' - ', @ValidationMsgs);  
   EXEC dbo.USPSEO_DataValidationOutcomeINS @ValStatus, @ValKey, @LogMsg;  
  END;  
  
  /* --------------------- REMOVED LINES 81–97 BY REQUEST ---------------------  
     Original block compared @ZonedRecCNT to @PrioritiesCNT and emitted a warning for not-zoned students.  
     Keeping it commented (do not execute) to preserve history.  
  ---------------------------------------------------------------------------  
  SET @ZonedRecCNT = (  
   SELECT COUNT(DISTINCT StudentID)  
   FROM dbo.INT_T5StudentZoneSchool  
   WHERE ProcessedDate = @CTUEDate  
  );  
  
  IF (@ZonedRecCNT + @PrioritiesCNT) = 0 OR (@ZonedRecCNT > @PrioritiesCNT)  
  BEGIN  
   SET @ValStatus='FAIL';  
   SET @ValidationMsgs = CONCAT(@ValidationMsgs, ' 2:RPT_T5StudentSchoolPriorities is missing students from INT_T5StudentZoneSchool tables.');  
   SET @LogMsg = CONCAT(@ValHeader, ' - ', @ValidationMsgs);  
   EXEC dbo.USPSEO_DataValidationOutcomeINS @ValStatus, @ValKey, @LogMsg;  
  END;  
  
  IF (@ZonedRecCNT < @EligibleCNT)  
  BEGIN  
   SET @RecCNT = (@EligibleCNT - @ZonedRecCNT);  
   SET @WarningMsg = CONCAT(' With ***Warning*** ', @RecCNT, ' Students not zoned. Check that these students are in the error file!');  
  END  
  ELSE  
   SET @WarningMsg = '';  
  --------------------------------------------------------------------------- */  
  
  --Test-D20--  
  --Verify all siblings (as identified in Step A) are processed in RPT_StudentSchoolPriorities.  
  SET @EligibleCNTSibling = (  
   SELECT COUNT(DISTINCT StudentID)  
   FROM dbo.INT_T5WaveEligibleStudents  
   WHERE WaveID IS NULL AND IsSibling = 1  
  );  
  
  SET @PrioritiesCNTSibling = (  
   SELECT COUNT(DISTINCT StudentID)  
   FROM dbo.RPT_T5StudentSchoolPriorities  
   WHERE WaveID = @WaveID AND IsSibling = 1  
  );  
  
  IF (@EligibleCNTSibling <> @PrioritiesCNTSibling)  
  BEGIN  
   SET @ValStatus='FAIL';  
   SET @ValidationMsgs = CONCAT(  
    @ValidationMsgs,  
    ' 3:RPT_T5StudentSchoolPriorities is empty or missing siblings from INT_T5WaveEligibleStudents. ',  
    'EligibleSiblingCnt=', @EligibleCNT, ', PrioritiesSiblingCnt=', @PrioritiesCNT, '.'  
   );  
   SET @LogMsg = CONCAT(@ValHeader, ' - ', @ValidationMsgs);  
   EXEC dbo.USPSEO_DataValidationOutcomeINS @ValStatus, @ValKey, @LogMsg;  
  END; 
 END;  
  
 -- Manual wave branch remains unchanged except for variable renames  
 IF ISNULL(@CSEOnlyFlag,'X') = 'M' --manual wave  
 BEGIN  
  SET @EligibleCNT = (  
   SELECT COUNT(DISTINCT StudentID)  
   FROM dbo.DWH_T5ManualWaveSchoolDBN  
   WHERE WaveID = @WaveID  
  );  
  
  SET @PrioritiesCNT = (  
   SELECT COUNT(DISTINCT StudentID)  
   FROM dbo.RPT_T5StudentSchoolPriorities  
   WHERE WaveID = @WaveID  
  );  
  
  IF (@EligibleCNT + @PrioritiesCNT) = 0 OR (@EligibleCNT <> @PrioritiesCNT)  
  BEGIN  
   SET @ValStatus='FAIL';  
   SET @ValidationMsgs = CONCAT(  
    @ValidationMsgs,  
    ' 1:RPT_T5StudentSchoolPriorities is empty or count does not match DWH_T5ManualWaveSchoolDBN. ',  
    'EligibleCnt=', @EligibleCNT, ', PrioritiesCnt=', @PrioritiesCNT, '.'  
   );  
   SET @LogMsg = CONCAT(@ValHeader, ' - ', @ValidationMsgs);  
   EXEC dbo.USPSEO_DataValidationOutcomeINS @ValStatus, @ValKey, @LogMsg;  
  END;  
 END;  
   
 --Write final validation outcome--   
OverrideValidation:  
 IF @ValStatus='FAIL'  
 BEGIN  
  SET @ValidationMsgs = CONCAT(@ValHeader,' - ***Validation Errors!*** ', @ValidationMsgs);  
  SET @LogMsg = @ValidationMsgs;  
  EXEC dbo.USPSEO_DataValidationOutcomeINS @ValStatus, @ValKey, @LogMsg;  
  RAISERROR (@ValidationMsgs, 16, 1);    
 END  
 ELSE  
 BEGIN  
  SET @ValStatus='PASS';  
  -- Charlotte: @WarningMsg may be blank since the zoning block is removed.  
  SET @ValidationMsgs = CONCAT(@ValHeader, ' Successful. ', ISNULL(@WarningMsg, ''));  
  SET @LogMsg = @ValidationMsgs;  
  EXEC dbo.USPSEO_DataValidationOutcomeINS @ValStatus, @ValKey, @LogMsg;    
 END;   
END; 
