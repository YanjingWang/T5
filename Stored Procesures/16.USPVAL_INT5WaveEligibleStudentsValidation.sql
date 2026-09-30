USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPVAL_INT5WaveEligibleStudentsValidation]    Script Date: 4/4/2026 1:57:08 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/************************************************************************************************************************************************************************
Object Name: dbo.INT_T5WaveEligibleStudents
Purpose:	This procedure validates INT_T5WaveEligibleStudents data load per BRD
			
Date Created: 09/27/2024
Modification Details:

Author				ModifiedDate		Comments
Christopher Agwu	09/27/2024			Initial version
Christopher Agwu	10/01/2024			Added code for checking HouseNumber and Street
Christopher Agwu	10/07/2024			Removed hardcoded test date code and replaced with @Today var
Chritopher Agwu		05/05/2025			Change validations messages too be neutral as this process now include LCGMS Request file or T5 Manual Wave Request file.
Christopher Agwu	06/10/2025			Added code to check type of wave been run (regular or manual wave) so currect elig count can be taken.
-- Charlotte Wang	10/24/2025			Move HouseNumber/Street validation to DWH_T5SourceExtractVAL (SourceExtract), remove from this proc.
Christopher Agwu	12/22/2025			Added function to send warning message when no active wave is found or no record in INT_T5WaveElig
***************************************************************************************************************************************************************************/

ALTER PROCEDURE [dbo].[USPVAL_INT5WaveEligibleStudentsValidation] 
AS
BEGIN
	SET NOCOUNT ON;

	Declare @SourceCNT INT, @DestCNT INT, @T5BDYear INT,@Today Date,@WaveID INT,
	@ValStatus Varchar(4), @ValKey INT,@ValidationMsgs varchar(1000), @ValHeader Varchar(100),
	@IsValOverride SmallINT, @IsValDone SmallINT, @IsWaveEligCnt INT,@IsTurning5CntSR INT,
	@CSEOnlyFlag Varchar(1),@WarningMsg Varchar(100);

	SET @Today=getdate();
	SET @ValHeader='INT_T5WaveEligibleStudents Validation';
	SET @ValKey=301001;
	SET @ValStatus='BEG';
	SET @ValidationMsgs=Concat('Starting ',@ValHeader);
	SET @WarningMsg='';


	--check make sure there is active wave, of not send warning message
	IF (select [dbo].[fn_GetT5ActiveWave]() as IsActiveWave)=0
	BEGIN
		SET @WarningMsg='***Warning*** No active wave status found.';
		SET @ValStatus='WARN'
		Goto OverrideValidation;		
	END;


	--get/check validation overrideID
	SET @IsValDone=2;
	SET @IsValOverride=(Select ValOverrideID From dbo.SEODataValidationOutcome where ValKey=@ValKey and 
	ValOverrideID=1 and CAST(CreatedDatetime as Date)=@Today);

	IF @IsValOverride=1
	BEGIN
		SET @ValHeader=(Select CONCAT(@ValHeader, ' - Overridden - '));
		SET @ValStatus='OVERRIDE';

		--update ValOverrideID
		UPDATE dbo.SEODataValidationOutcome 
		SET ValOverrideID=@IsValDone,
		ModifiedDateTime=getdate(),
		ModifiedBy=SYSTEM_USER
		Where ValKey=@ValKey and ValOverrideID=1 and CAST(CreatedDatetime as Date)=@Today;				
		Goto OverrideValidation;
	END;

	--Start validation
	Exec dbo.USPSEO_DataValidationOutcomeINS @ValStatus,@ValKey,@ValidationMsgs;
	
	--get wave run type
	SET @CSEOnlyFlag=(Select CSEOnlyFlag from dbo.INT_T5WaveSchedule where WaveStatus='I');

	--Verify that elig data in INT_T5WaveEligibleStudents table is processed today(date)
	IF @CSEOnlyFlag='M'		
		SET @IsWaveEligCnt=(Select Count(DISTINCT StudentID) From dbo.INT_T5WaveEligibleStudents where WaveID IS NULL And IsManualWave=1); 
	ELSE
		SET @IsWaveEligCnt=(Select Count(DISTINCT StudentID) From dbo.INT_T5WaveEligibleStudents where WaveID IS NULL); 
	
	IF @IsWaveEligCnt=0
	BEGIN
		SET @ValidationMsgs='1:T5 Wave Eligibility count is ZERO (0).';
		SET @ValStatus='FAIL';
	END;

	--Test11B--	
	SET @T5BDYear=dbo.fn_GetT5BirthYear();
	SET @IsTurning5CntSR=(Select Count(*) from dbo.RPT_T5StudentRegister where IsTurning5=1 and YEAR(BirthDate)=@T5BDYear and WaveProcessedDate is NULL);
	
	--compare WElig and T5SR Elig cnt, should match
	IF (@IsWaveEligCnt+@IsTurning5CntSR)=0 OR @IsWaveEligCnt!=@IsTurning5CntSR
	BEGIN
		SET @ValidationMsgs=CONCAT(@ValidationMsgs,' 2:T5 Wave Eligibility count does not match RPT_T5SR IsTurning5=1 count.');
		SET @ValStatus='FAIL';
	END;

	/* -----------------------------------------------------------------------------------------
	   Charlotte: HouseNumber/Street validation was previously here.
	   It has been MOVED to SourceExtract validation procedure: DWH_T5SourceExtractVAL.
	   (Request: "Move HouseNumber and Street validation to DWH_T5SourceExtractVAL for SourceExtract + Remove from INT_T5WaveEligibleStudentValidation")
	   ----------------------------------------------------------------------------------------- */
	
	
	-- Optional: write an INFO line to the log so operators know where this check now lives
	/* Commented by ChrisAgwu 11-03-2025: Not necessary to write this message to log since validation is no longer done here.
		
	IF @ValStatus <> 'FAIL'
	BEGIN
		EXEC dbo.USPSEO_DataValidationOutcomeINS 'INFO', @ValKey, 'HouseNumber/Street check moved to DWH_T5SourceExtractVAL.';
	END;
	*/

	--Write final validation outcome--	
	OverrideValidation:
	IF @ValStatus='FAIL'
	BEGIN
		SET @ValidationMsgs=Concat(@ValHeader,' - INT_T5WaveEligibleStudents Data Validation Error!', @ValidationMsgs)	
		Exec dbo.USPSEO_DataValidationOutcomeINS @ValStatus,@ValKey,@ValidationMsgs;
		RAISERROR (@ValidationMsgs,16,1);		
	END
	ELSE IF @ValStatus='WARN'
	BEGIN
		SET @ValidationMsgs=Concat(@ValHeader, ' Completed. ', @WarningMsg)
		Exec dbo.USPSEO_DataValidationOutcomeINS @ValStatus,@ValKey,@ValidationMsgs;
	END
	ELSE
	BEGIN
		SET @ValStatus='PASS'		
		SET @ValidationMsgs=Concat(@ValHeader, ' Successful. ', @WarningMsg)
		Exec dbo.USPSEO_DataValidationOutcomeINS @ValStatus,@ValKey,@ValidationMsgs;
	END;	
END;