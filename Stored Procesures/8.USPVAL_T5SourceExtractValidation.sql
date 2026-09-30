USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPVAL_T5SourceExtractValidation]    Script Date: 4/4/2026 1:42:21 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



/************************************************************************************************************************************************************************
Object Name: USPVAL_T5SourceExtractValidation
Purpose:	This procedure validates T5SourceExtract file load per BRD
			
Date Created: 12/18/2024
Modification Details:

Author				ModifiedDate		Comments
Christopher Agwu	12/18/2024			Initial version
Christopher Agwu	12/30/2024			Added VAL #2 and #3
***************************************************************************************************************************************************************************/

ALTER PROCEDURE [dbo].[USPVAL_T5SourceExtractValidation] 

AS
BEGIN
	SET NOCOUNT ON

	Declare @SourceCNT INT, @DestCNT INT, @T5BDYear INT,@Today Date, @SchoolYear Varchar(9),
	@ValStatus Varchar(4), @ValKey INT,@ValidationMsgs varchar(1000), @ValHeader Varchar(100),
	@ProcessedDate Date, @WarningMsg Varchar(100),@IsValOverride SmallINT,  @IsValDone SmallINT,
	@LastRunDate as date
	
	
	SET @Today=getdate()
	SET @SchoolYear=dbo.fn_GetT5SchoolYear();	
	SET @T5BDYear=dbo.fn_GetT5BirthYear();
	SET @ValHeader='T5SourceExtract Load Validation'
	SET @ValKey=405001;
	SET @ValStatus='BEG'
	SET @ValidationMsgs=Concat('Starting ',@ValHeader);

	--get/check validation overrideID
	SET @IsValDone=2;
	SET @IsValOverride=(Select ValOverrideID From dbo.SEODataValidationOutcome where ValKey=@ValKey and ValOverrideID=1 and CAST(CreatedDatetime as Date)=@Today);

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

	--Val #1:
	--check if job was run today monday and successful.
	Set @LastRunDate=(select dbo.fn_GetWeekDayDate('CMO')); --get run date
	Set @SourceCNT=(select count(*) from dbo.DWH_T5SourceExtract where ProcessedDate>=@LastRunDate);
	
	IF @SourceCNT=0
	BEGIN		
		SET @ValidationMsgs=CONCAT(@ValidationMsgs, ' 1:No DWHT5SourceExtract data load found!');
		SET @ValStatus='FAIL';		
	END;

	--Val #2:
	--check school year
	Set @SourceCNT=(select count(*) from dbo.DWH_T5SourceExtract where ProcessedDate>=@LastRunDate and SchoolYear=@SchoolYear);
	IF @SourceCNT=0
	BEGIN		
		SET @ValidationMsgs=CONCAT(@ValidationMsgs, ' 2:DWHT5SourceExtract SchoolYear does not match T5SchoolYear in lk_SEOBusinessRules!');
		SET @ValStatus='FAIL';		
	END;
	
	--Val #3:
	--check T5 BirthYear
	Set @SourceCNT=(select count(*) from dbo.DWH_T5SourceExtract where ProcessedDate>=@LastRunDate and Year(BirthDate)=@T5BDYear);
	IF @SourceCNT=0
	BEGIN		
		SET @ValidationMsgs=CONCAT(@ValidationMsgs, ' 3:DWHT5SourceExtract BirthYear does not match T5BirthYear in lk_SEOBusinessRules!');
		SET @ValStatus='FAIL';		
	END;

		
	--Write final validation outcome--	
	OverrideValidation:
	IF @ValStatus='FAIL'
	BEGIN
		SET @ValidationMsgs=Concat(@ValHeader,' - Error!',@ValidationMsgs)	
		Exec dbo.USPSEO_DataValidationOutcomeINS @ValStatus,@ValKey,@ValidationMsgs;
		RAISERROR (@ValidationMsgs,16,1);		
	END
	ELSE
	BEGIN
		SET @ValStatus='PASS'
		SET @ValidationMsgs=Concat(@ValHeader, ' - Successful. ', @WarningMsg)
		Exec dbo.USPSEO_DataValidationOutcomeINS @ValStatus,@ValKey,@ValidationMsgs;
	END;	
END;

