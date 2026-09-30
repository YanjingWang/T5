USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPVAL_T5SESISInactveStudentValidation]    Script Date: 4/4/2026 2:43:12 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/************************************************************************************************************************************************************************
Object Name: USPVAL_T5SESISInactveStudentValidation
Purpose:	This procedure validates USPVAL_T5SESISInactveStudentValidation data load per BRD
			
Date Created: 10/22/2024
Modification Details:

Author				ModifiedDate		Comments
Christopher Agwu	10/22/2024			Initial version
Christopher Agwu	05/08/2025			SP missing (get Override code). Added code to extract filter by students in DWH table. MIS-13286
***************************************************************************************************************************************************************************/

ALTER PROCEDURE [dbo].[USPVAL_T5SESISInactveStudentValidation] 

AS
BEGIN
	SET NOCOUNT ON

	Declare @SourceCNT INT, @DestCNT1 INT,@DestCNT2 INT, @T5BDYear INT,@Today Date, @SchoolYear Varchar(9),
	@ValStatus Varchar(4), @ValKey INT,@ValidationMsgs varchar(1000), @ValHeader Varchar(100),
	@ReassignmentDate Date, @WarningMsg Varchar(100), @IsValOverride SmallINT,  @IsValDone SmallINT
	
	SET @Today=getdate()
	SET @SchoolYear=dbo.fn_GetT5SchoolYear()	
	SET @ValHeader='T5SESISInactveStudent Data Validation'
	SET @ValKey=317001
	SET @ValStatus='BEG'
	SET @ValidationMsgs=Concat('Starting ',@ValHeader);

	--get/check validation overrideID
	SET @IsValDone=2;
	SET @IsValOverride=(Select TOP 1 ValOverrideID From dbo.SEODataValidationOutcome where ValKey=@ValKey and 
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
	--Verify that loaded T5SESISInactveStudent  data count in DWH is same in RPT_T5StudentAssignment table
	SET @SourceCNT=(Select Count(*) From dbo.DWH_T5SESISInactiveNHKids where ProcessedDate=@Today and SchoolYear=@SchoolYear);
	SET @DestCNT1=(select Count(*) from dbo.RPT_T5StudentAssignment where ActiveFlag='N' and SchoolYear=@SchoolYear and StudentID IN (select StudentID from dbo.DWH_T5SESISInactiveNHKids where ProcessedDate=@Today));
	SET @DestCNT2=(select Count(*) from dbo.RPT_T5StudentRegister where ModifiedDate=@Today and IsTurning5=0 and SchoolYear=@SchoolYear and StudentID IN (select StudentID from dbo.DWH_T5SESISInactiveNHKids where ProcessedDate=@Today));

	IF (@SourceCNT<>@DestCNT1 )	--this will pass if no file was loaded (0,0)
	BEGIN
		SET @ValidationMsgs=CONCAT('1:DWH_T5SESISInactiveNHKids count does not match RPT_T5StudentAssignment count for Invalid students: ',Cast(@Today as Varchar));
		SET @ValStatus='FAIL';
	END;	

	IF (@SourceCNT<>@DestCNT2 )	--this will pass if no file was loaded (0,0)
	BEGIN
		SET @ValidationMsgs=@ValidationMsgs + CONCAT(' 2:DWH_T5SESISInactiveNHKids count does not match RPT_T5StudentRegister count for Invalid students: ',Cast(@Today as Varchar));
		SET @ValStatus='FAIL';
	END;	


	IF ((@SourceCNT+@DestCNT1+@DestCNT2)=0)
		SET @WarningMsg=' With ***Warning*** No data loaded';
	ELSE
		SET @WarningMsg='';
		

	--Write final validation outcome--	
	OverrideValidation:
	IF @ValStatus='FAIL'
	BEGIN
		SET @ValidationMsgs=Concat(@ValHeader,' - Error - ',@ValidationMsgs)	
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

