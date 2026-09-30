USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPVAL_T5DuplicateStudentstValidation]    Script Date: 4/4/2026 2:31:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/************************************************************************************************************************************************************************
Object Name: USPVAL_T5DuplicateStudentstValidation
Purpose:	This procedure validates T5Duplicate SESIS Students Validation data load per BRD
			
Date Created: 11/05/2024
Modification Details:

Author				ModifiedDate		Comments
Christopher Agwu	11/05/2024			Initial version
***************************************************************************************************************************************************************************/

ALTER PROCEDURE [dbo].[USPVAL_T5DuplicateStudentstValidation] 

AS
BEGIN
	SET NOCOUNT ON

	Declare @SourceCNT INT, @DestCNT INT, @T5BDYear INT,@Today Date, @SchoolYear Varchar(9),
	@ValStatus Varchar(4), @ValKey INT,@ValidationMsgs varchar(1000), @ValHeader Varchar(100),
	@ProcessedDate Date, @WarningMsg Varchar(100),@IsValOverride SmallINT,  @IsValDone SmallINT
	
	SET @Today=getdate()
	SET @SchoolYear=dbo.fn_GetT5SchoolYear()	
	SET @ValHeader='T5DuplicateStudents Validation'
	SET @ValKey=319001
	SET @ValStatus='BEG'
	SET @ValidationMsgs=Concat('Starting ',@ValHeader);

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

	--Test-1--
	--Verify that loaded Duplicates data count in DWH is same in RPT_T5StudentAssignment table
	SET @SourceCNT=(Select Count(*) From dbo.DWH_T5DuplicateStudent where ProcessedDate=@Today and SchoolYear=@SchoolYear);	
	SET @DestCNT=(select Count(*) from dbo.RPT_T5StudentAssignment where ModifiedReasons='DuplicateStudent' and CAST(ModifiedDate as Date)=@Today and SchoolYear=@SchoolYear)

	IF (@SourceCNT<>@DestCNT)	--this will pass if no file was loaded (0,0)
	BEGIN
		SET @ValidationMsgs='1:DWH_T5DuplicateStudent count does not match RPT_T5StudentAssignment count for Duplicate Students. ';
		SET @ValStatus='FAIL';
	END;	

	SET @DestCNT=0;
	SET @DestCNT=(select Count(*) from dbo.RPT_T5StudentRegister where ModifiedReasons='DuplicateStudent' and CAST(ModifiedDate as Date)=@Today and SchoolYear=@SchoolYear)

	IF (@SourceCNT<>@DestCNT)	--this will pass if no file was loaded (0,0)
	BEGIN
		SET @ValidationMsgs=CONCAT(@ValidationMsgs, ' 2:DWH_T5DuplicateStudent count does not match RPT_T5StudentRegister count for Duplicate Students.');
		SET @ValStatus='FAIL';
	END;	

	IF ((@SourceCNT+@DestCNT)=0)
		SET @WarningMsg=' With ***Warning*** No data loaded';
	ELSE
		SET @WarningMsg='';
		

	--Write final validation outcome--	
	OverrideValidation:
	IF @ValStatus='FAIL'
	BEGIN
		SET @ValidationMsgs=Concat(@ValHeader,' - T5Reassignment Data Validation Error!',@ValidationMsgs)	
		Exec dbo.USPSEO_DataValidationOutcomeINS @ValStatus,@ValKey,@ValidationMsgs;
		RAISERROR (@ValidationMsgs,16,1);		
	END
	ELSE
	BEGIN
		SET @ValStatus='PASS'
		SET @ValidationMsgs=Concat(@ValHeader, ' Successful. ', @WarningMsg)
		Exec dbo.USPSEO_DataValidationOutcomeINS @ValStatus,@ValKey,@ValidationMsgs;
	END;	
END;

