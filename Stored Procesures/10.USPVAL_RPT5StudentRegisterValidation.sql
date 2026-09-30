USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPVAL_RPT5StudentRegisterValidation]    Script Date: 4/4/2026 1:45:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/************************************************************************************************************************************************************************
Object Name: dbo.RPT5StudentRegisterValidation
Purpose:	This procedure validates RPT_StudentRegister data load per BRD
			
Date Created: 09/23/2024
Modification Details:

Author				ModifiedDate		Comments
Christopher Agwu	09/23/2024			Initial version
Christopher Agwu	09/30/2024			Added BirthDate filter to RPT_T5SR. Added ISNULL(RecommProgram,'XX')
Christopher Agwu	09/30/2024			Added code to return WARNING when all elig count in T5SR is in CAP but CAP cnt is higher than T5SR with less than 10 students
Christopher Agwu	12/09/2024			Switched to production, DWH_T5CAPExtract to DWH_T5SourceExtract
Christopher Agwu	04/28/2025			Added code to filter out SESIS population before compare with ATLAS data as it does not include SESIS
Christopher Agwu	05/25/2025			Modified code to align with RPT_T5SR count and SourceExtract. Commented out #3 validation until it is clearly defined.
Christopher Agwu	07/25/2025			Added script to check for available wave schedule. if not exist then skip data validation. MIS-13694
Christopher Agwu	08/12/2025			Modified SourceExtract select script to only include stuents elibiglr for wave. This is bcos stuent might not be isturning5=1 for can pass other conditionds.
Charlotte Wang      10/24/2025          Add record fail count to SEODataValidationOutcome by validation; Look into SEODataValidationOutcome (it is  a log), Replace >20  with <>0, Remove >10  with <>0, ADD WHERE ISNULL([T5RecordSource],'')<> 'SESIS', Remov
e 'LD' reference, Add WHERE ISNULL([T5RecordSource],'')<> 'SESIS'
Charlotte Wang      10/27/2025          Commented out override block (line 43 59) per Christopher:  we want to accumulate and display all validation messages, not overwrite them. 
Christopher Agwu	03/02/2026			Added new validation to check that all students eligible for wave in T5SourceExtract are also present and eligible in RPT_T5StudentRegister table. MIS-14927
Christopher Agwu	03/02/2026		    Check total StudentRegister (IsTurning5=1) and T5RecordSource=ATLAS. Check total initials of this population. The initial cannot be more than 10% of the StudentRegister (IsTurning5=1).
******************************************************************************************************************************************************************************************************/

ALTER PROCEDURE [dbo].[USPVAL_RPT5StudentRegisterValidation] 
AS
BEGIN
	SET NOCOUNT ON;

	Declare 
		  @IsTurning5CntSR INT
		, @IsTurning5CntCAPX INT
		, @IsTurning5CntMissing INT
		, @T5InitialsCnt INT
		, @T5InitialsPct Float 
		, @T5BDYear INT
		, @IsWarning BIT
		, @DiffCnt INT
		, @Today DATE
		, @ValStatus VARCHAR(4)
		, @ValKey INT
		, @ValidationMsgs VARCHAR(1000)
		, @ValHeader VARCHAR(100)
		, @EmailMsg VARCHAR(100)
		, @IsValOverride SMALLINT
		, @IsValDone SMALLINT
		, @IsWaveAval SMALLINT
		, @LogMsg VARCHAR(2000);  -- Charlotte: buffer for per-validation log text;

	--check for available wave schedule
	SET @IsWaveAval = (SELECT COUNT(*) FROM dbo.INT_T5WaveSchedule WHERE WaveStatus='E');
	IF @IsWaveAval = 0
		RETURN;
	---/

	SET @Today = GETDATE();
	SET @ValHeader = 'RPT_T5StudentRegisterLoad Validation';
	SET @ValKey = 278001;
	SET @ValStatus = 'BEG';
	SET @ValidationMsgs = CONCAT('Starting ', @ValHeader);

	--get/check validation overrideID
	SET @IsValDone = 2;
	SET @IsValOverride = (
		SELECT ValOverrideID 
		FROM dbo.SEODataValidationOutcome 
		WHERE ValKey=@ValKey AND ValOverrideID=1 AND CAST(CreatedDatetime AS DATE)=@Today
	);

	IF @IsValOverride = 1
	BEGIN
		SET @ValHeader = (SELECT CONCAT(@ValHeader, ' - Overridden - '));
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
	EXEC dbo.USPSEO_DataValidationOutcomeINS @ValStatus, @ValKey, @ValidationMsgs;
	
	--#1 eval
	SET @T5BDYear = dbo.fn_GetT5BirthYear();
	
	-- RPT_T5StudentRegister elig count
	SET @IsTurning5CntSR = (
		SELECT COUNT(*) 
		FROM dbo.RPT_T5StudentRegister WITH (NOLOCK)
		WHERE IsTurning5=1 
		  AND WaveProcessedDate IS NULL 	
		  AND PreviousClassificationCode='PD'	
		  AND ISNULL(RecommendedProgram,'XX') NOT IN ('NH','RC','GE')
		  AND ISNULL(CAPDischargeCode,0) NOT IN (11,15)
		  AND ISNULL(CaseCloseReasonCode,0) NOT IN (15,65)
		  AND YEAR(BirthDate)=@T5BDYear
		  AND ISNULL(BoroughCode, 'XYZXYZ') NOT IN ('Y','Z') ---outs
		  -- Charlotte: exclude SESIS from SR side per requirement (line ~82)
		  AND ISNULL(T5RecordSource,'') <> 'SESIS'
	);


	-- SourceExtract elig count
	SET @IsTurning5CntCAPX = (
		SELECT COUNT(*) 
		FROM dbo.DWH_T5SourceExtract WITH (NOLOCK)
		WHERE PreviousClassificationCode='PD'
		  AND ISNULL(RecommProgram,'XX') NOT IN ('NH','RC','GE')
		  AND ISNULL(CAPDischargeCode,0) NOT IN (11,15)
		  AND ISNULL(CaseCloseReasonCode,0) NOT IN (15,65)
		  AND YEAR(BirthDate)=@T5BDYear
		  AND ISNULL(BoroughCode,'XYZXYZ') NOT IN ('Y','Z')  ---outside of NYC
		  -- Charlotte: exclude SESIS if present in SourceExtract schema (line ~92)
		  AND ISNULL(ATLASSourcedFrom,'') <> 'SESIS'
		  AND StudentID IN (
				SELECT StudentID 
				FROM dbo.RPT_T5StudentRegister WITH (NOLOCK)
				WHERE IsTurning5=1 
				  AND WaveProcessedDate IS NULL
				  -- Charlotte: keep SR subset aligned, exclude SESIS
				  AND ISNULL(T5RecordSource,'') <> 'SESIS'
		  )
	);	--modified 8/12/2015

	--411
	--compare CAPX and T5SR Elig cnt, should match
	--#1 Eval
	SET @DiffCnt = (@IsTurning5CntCAPX - @IsTurning5CntSR);

	-- Charlotte: Replace >20 with <>0 (line ~101)
	IF (@IsTurning5CntCAPX + @IsTurning5CntSR) = 0 OR (@DiffCnt) <> 0
	BEGIN
		SET @ValStatus = 'FAIL';
		SET @ValidationMsgs = CONCAT(
			@ValidationMsgs, 
			' | 1: Eligible count mismatch between DWH_T5SourceExtract and RPT_T5SR. ',
			'SR=', @IsTurning5CntSR, ', CAP=', @IsTurning5CntCAPX, ', Diff=', @DiffCnt, '.'
		);

		-- build log text, then EXEC with variable (avoids parser error near @ValHeader)
		SET @LogMsg = CONCAT(@ValHeader, ' - ', @ValidationMsgs);
		EXEC dbo.USPSEO_DataValidationOutcomeINS 
			 @ValStatus, 
			 @ValKey, 
			 @LogMsg;
	END;

	--Test3A--
		--n/a

	--Test4A-------------------------------------------------------------------------
	--Total SBST Initial (School Based Support Team)
	--SET @IsTurning5CntSR = (
	--	SELECT COUNT(*) 
	--	FROM SEO_MART.dbo.RPT_T5StudentRegister WITH (NOLOCK)
	--	WHERE IsTurning5=1
	--	  AND WaveProcessedDate IS NULL 
	--	  AND PreviousClassificationCode='PD'	
	--	  AND ISNULL(RecommendedProgram,'XX') NOT IN ('NH','RC','GE')
	--	  AND ISNULL(CAPDischargeCode,0) NOT IN (11,15)
	--	  AND ISNULL(CaseCloseReasonCode,0) NOT IN (15,65)
	--	  AND YEAR(BirthDate)=@T5BDYear
	--	  AND ISNULL(BoroughCode,'XYZXYZ') NOT IN ('Y','Z') ---outs
	--	  AND IsCSETrueInitial=0 
	--	  AND CaseType='T5 INITIAL'
	--	  -- Charlotte: exclude SESIS on SR side for SBST Initial (alignment with requirement; line ~125)
	--	  AND ISNULL(T5RecordSource,'') <> 'SESIS'
	--);

	--create temp table for SR subset used below
	SELECT * 
	INTO #RPT_T5SR 
	FROM SEO_MART.dbo.RPT_T5StudentRegister WITH (NOLOCK)
	WHERE IsTurning5=1 
	  AND WaveProcessedDate IS NULL 
	  AND PreviousClassificationCode='PD'	
	  AND ISNULL(RecommendedProgram,'XX') NOT IN ('NH','RC','GE')
	  AND ISNULL(CAPDischargeCode,0) NOT IN (11,15)
	  AND ISNULL(CaseCloseReasonCode,0) NOT IN (15,65)
	  AND YEAR(BirthDate)=@T5BDYear
	  AND ISNULL(BoroughCode,'XYZXYZ') NOT IN ('Y','Z') ---outs	
	  AND IsCSETrueInitial=0 
	  AND CaseType='T5 INITIAL'
	  -- Charlotte: exclude SESIS in temp table as well (line ~125)
	  AND ISNULL(T5RecordSource,'') <> 'SESIS';

	--Total SBST Initial (School Based Support Team)
	SET @IsTurning5CntSR = (SELECT COUNT(*) FROM #RPT_T5SR); 

	-- CAPX count for SBST Initial
	SET @IsTurning5CntCAPX = (
		SELECT COUNT(*) 
		FROM dbo.DWH_T5SourceExtract WITH (NOLOCK)
		WHERE 
			-- Charlotte: remove 'LD' reference (line ~137)
			ISNULL(PreviousClassificationCode, 'XYZXYZ') IN ('PD') 
			AND ISNULL(RecommProgram, 'XYZXYZ') NOT IN ('NH','RC','GE')
			AND ISNULL(CAPDischargeCode,0) NOT IN (15,11)
			AND ISNULL(CaseCloseReasonCode,0) NOT IN (15,65)
			AND ISNULL(BoroughCode,'XYZXYZ') NOT IN ('Y','Z') 	---outside of NYC 	
			AND YEAR(BirthDate)=@T5BDYear
			AND FirstPDConsentedForSVCSDate IS NULL 
			AND IEPConferenceDate IS NOT NULL
			-- Charlotte: exclude SESIS from SourceExtract if present (line ~137)
			AND ISNULL(ATLASSourcedFrom,'') <> 'SESIS'
			AND StudentID IN (SELECT StudentID FROM #RPT_T5SR)
	);

	--compare CAPX and T5SR SBST Initial cnt, should match
	SET @DiffCnt = (@IsTurning5CntCAPX - @IsTurning5CntSR);

	-- Charlotte: Replace '>=10' (or '>10') with '<>0' (line ~149)
	IF (@IsTurning5CntCAPX + @IsTurning5CntSR) = 0 OR (@DiffCnt) <> 0
	BEGIN
		SET @ValStatus = 'FAIL';
		SET @ValidationMsgs = CONCAT(
			@ValidationMsgs, 
			' | 2: DWH_T5SourceExtract elig T5 INITIAL vs RPT_T5SR mismatch. ',
			'SR=', @IsTurning5CntSR, ', CAP=', @IsTurning5CntCAPX, ', Diff=', @DiffCnt, '.'
		);

		SET @LogMsg = CONCAT(@ValHeader, ' - ', @ValidationMsgs);
		EXEC dbo.USPSEO_DataValidationOutcomeINS 
			 @ValStatus, 
			 @ValKey, 
			 @LogMsg;
	END;

	/* Commented 5/25/2025 - Until validation logic is clearly defined.
	--Test5A----------------------------------------------
	--Total CSE true initials
	SET @IsTurning5CntSR=(Select Count(*) From dbo.RPT_T5StudentRegister with(nolock)
	where IsTurning5=1 
	and YEAR(BirthDate)=@T5BDYear 
	and WaveProcessedDate is NULL and IsCSETrueInitial=1 and T5RecordSource!='SESIS');

	SET @IsTurning5CntCAPX=(Select count(*) From dbo.DWH_T5SourceExtract with(nolock)
	Where StudentID in (Select StudentID from seo_mart.dbo.RPT_T5StudentRegister with(nolock) Where IsTurning5=1 and YEAR(BirthDate)=@T5BDYear and IsCSETrueInitial=1 and WaveProcessedDate is NULL and T5RecordSource!='SESIS')
	and ISNULL(PreviousClassificationCode, 'XYZXYZ') IN ( 'PD', 'LD' )-----Preschooler with a disability or have a learning disability  (PreviousClassifCd is  PD  or  LD)
	and ISNULL(RecommProgram, 'XYZXYZ') not IN ( 'NH', 'RC', 'GE' )---Non-Handicapped (NH) , Revocation of Consent (RC), General Education (GE)
	and ISNULL(CAPDischargeCode, 0) not IN ( 15, 11 )---Moved or Transferred from NYC (code 11) or Deceased (code 15)
	and ISNULL(CaseCloseReasonCode, 0) not IN ( 15, 65 )----Deceased (code 15) ,Moved out of NYC (code 65) 
	and ISNULL(BoroughCode, 'XYZXYZ') not IN ( 'Y', 'Z' )---outside of NYC 
	and YEAR(BirthDate)=@T5BDYear
	and StudentID NOT IN (Select StudentID from dbo.RPT_T5StudentRegister where IsTurning5=1 and WaveID IS NOT NULL and T5RecordSource!='SESIS')
	and ((FirstPDConsentedForSVCSDate is not NULL and CaseCloseReasonCode=64 and EvaluationDesc='PRE-SCH INITIAL')
		OR (FirstPDConsentedForSVCSDate is NULL and IEPConferenceDate is null ))); 
	--compare CAPX and T5SR CSE T-Initial cnt, should match
	
	IF @IsTurning5CntCAPX!=@IsTurning5CntSR
	BEGIN
		SET @ValidationMsgs=Concat(@ValidationMsgs, '3:DWH_T5SourceExtract elig CSE T5 INITIAL does not match RPT_T5SR.');
		SET @ValStatus='FAIL';
	END;
	
	--Test6A: IsSibling compare--
		--n/a

	--Check if there was a WARNING--
	IF @IsWarning=1
	BEGIN
		SET @ValStatus='WARN'
		SET @ValidationMsgs=Concat('Successful with Warning - ', @ValidationMsgs)
		Exec dbo.USPSEO_DataValidationOutcomeINS @ValStatus,@ValKey,@ValidationMsgs;
		Return;
	END;
	*/
	--New validation added 2/9/2026--------------------------------------------------------------
	--BEGIN: Validation #3:	Eligible Students in SourceExtract are 
	--1. either missing in the Register OR
	--2. Turning5 is not 1

	DROP TABLE IF EXISTS #ATS;
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
   ) t
   WHERE [Status] = 'A';

   --get count if missing eligible students
   Select @IsTurning5CntMissing = Count(*) from 
   (
   SELECT SE.ATLASSourcedFrom,SE.StudentID
   FROM SEO_MART.dbo.DWH_T5SourceExtract SE WITH (NOLOCK)
   LEFT JOIN #ATS a ON A.StudentID=SE.StudentID
   WHERE 1=1   
	   AND ISNULL(SE.PreviousClassificationCode, 'XYZXYZ') IN ('PD') 
	   AND ISNULL(SE.RecommProgram, 'XYZXYZ') NOT IN ('NH','RC','GE')
	   AND ISNULL(SE.CAPDischargeCode,0) NOT IN (15,11)
	   AND ISNULL(SE.CaseCloseReasonCode,0) NOT IN (15,65)
	   AND ISNULL(SE.BoroughCode,'XYZXYZ') NOT IN ('Y','Z') 	---outside of NYC 	
	   AND YEAR(SE.BirthDate)=@T5BDYear
	   AND (a.StudentID is null OR isnull(a.GradeLevel, '') <> '0K' or isnull(a.SchoolDBN, '') not like '84%')
   ) a
   Where a.StudentID NOT IN (Select StudentID From arch.RPT_T5StudentRegister where ISTurning5=1)
   AND a.StudentID NOT IN (Select StudentID From dbo.RPT_T5StudentRegister where ISTurning5=1)	   
   
   --check missing count
   IF (@IsTurning5CntMissing>=1)
   BEGIN
	   SET @ValStatus = 'FAIL';
	   SET @ValidationMsgs = CONCAT(
		   @ValidationMsgs, 
		   ' | 3: Students elig for wave in DWH_T5SourceExtract are not in RPT_T5SR. ',
		   'DWH_T5SE Count: ', @IsTurning5CntMissing
	   );
	   SET @LogMsg = CONCAT(@ValHeader, ' - ', @ValidationMsgs);
	   EXEC SEO_MART.dbo.USPSEO_DataValidationOutcomeINS 
			@ValStatus, 
			@ValKey, 
			@LogMsg;
   END;
   --END: Validation #3 

   --BEGIN: get percent of initials and compare to 10% - 2/9/26
   --Validation #4:
   /*
   Check total StudentRegister (IsTurning5=1) and T5RecordSource=ATLAS
   Check total initials of this population.
   The initial cannot be more than 10% of the StudentRegister (IsTurning5=1).
	Check the totals and initials in the entire T5-eligible-population. 
	Check against all students regardless of wave assignment status.
   */
   Select @IsTurning5CntSR=count(*) 
   From dbo.RPT_T5StudentRegister
   Where IsTurning5=1 
   AND T5RecordSource='ATLAS';

   Select @T5InitialsCnt=count(*) 
   From dbo.RPT_T5StudentRegister
   Where IsTurning5=1 
   and T5RecordSource='ATLAS' 
   AND CASETYPE='T5 INITIAL';   

   SET @T5InitialsPct=((@T5InitialsCnt/@IsTurning5CntSR)*100.0)
   IF (@T5InitialsPct>10)
   BEGIN
	SET @ValStatus = 'FAIL';
	SET @ValidationMsgs = CONCAT(
	 @ValidationMsgs, 
	 ' | 4: ATLAS "Initials" cnt is more than 10% of total population. ',
	 'Initials cnt: ', @T5InitialsCnt,' Total cnt: ',@IsTurning5CntSR
	);
	SET @LogMsg = CONCAT(@ValHeader, ' - ', @ValidationMsgs);
	EXEC SEO_MART.dbo.USPSEO_DataValidationOutcomeINS 
	@ValStatus, 
    @ValKey, 
    @LogMsg;
   END;
   --END: get percent of initials and compare to 10% - 2/9/26

	--Write final validation outcome--	
OverrideValidation:
IF @ValStatus = 'FAIL'
BEGIN
    -- keep accumulated details instead of overwriting
    SET @LogMsg = CONCAT(
        @ValHeader, 
        ' - ***Errors!*** See individual validation logs above for SR/CAP/Diff counts. ',
        @ValidationMsgs
    );
    EXEC dbo.USPSEO_DataValidationOutcomeINS @ValStatus, @ValKey, @LogMsg;
    RAISERROR(@LogMsg, 16, 1);
END
ELSE
BEGIN
    SET @LogMsg = CONCAT(@ValHeader, ' - Successful. ', @ValidationMsgs);
    EXEC dbo.USPSEO_DataValidationOutcomeINS @ValStatus, @ValKey, @LogMsg;
END;
		
END
