USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPVAL_RPT5StudentAssignmentValidation]    Script Date: 4/4/2026 4:35:07 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



/************************************************************************************************************************************************************************
Object Name: USPVAL_RPT5StudentAssignmentValidation
Purpose:	This procedure validates RPT_T5StudentAssignment data load per BRD
			
Date Created: 10/31/2024
Modification Details:

Author				ModifiedDate		Comments
Christopher Agwu	10/31/2024			Initial version
Christopher Agwu	01/10/2025			Commented out eval #4 bcos no guaranttee thet we'll get JH Error file hence count may not be valid.
***************************************************************************************************************************************************************************/

ALTER PROCEDURE [dbo].[USPVAL_RPT5StudentAssignmentValidation] 

AS
BEGIN
	SET NOCOUNT ON

	Declare @SourceCNT INT, @DestCNT INT, @T5BDYear INT,@Today Date,@IsValDone SmallINT,@IsValOverride SmallINT,@WaveID INT,
	@MsgModifier Varchar(50),@ValStatus Varchar(4), @ValKey INT,@ValidationMsgs varchar(1000), @ValHeader Varchar(100)

	SET @Today=getdate()
	SET @ValHeader='RPT_T5StudentAssignment Validation.'
	SET @ValKey=272001
	SET @ValStatus='BEG'
	SET @ValidationMsgs=Concat('Starting ',@ValHeader);
	SET @WaveID=(Select Max(WaveID) as WaveID from dbo.INT_T5WaveSchedule where WaveStatus='P');


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
	SET @ValidationMsgs=''
	

	--verify RPT_T5SA wave count matches INT_T5SSA count
	SET @SourceCNT=(Select count(*) from dbo.INT_T5StudentSchoolAssignment where WaveID=@WaveID);
	SET @DestCNT=(Select count(*) from dbo.RPT_T5StudentAssignment where WaveID=@WaveID);

	IF (@SourceCNT+@DestCNT=0 OR @SourceCNT<>@DestCNT)
	BEGIN
		SET @ValidationMsgs=CONCAT(@ValidationMsgs,'1:RPT_T5SA wave:',Cast(@WaveID as varchar),' count does not match INT_T5SSA. ');
		SET @ValStatus='FAIL';
	END;


	--Verify that there is no over-assignments due to KIP assignment
	--Check for over-assignment
	Select * into #OverAssigned
	from
	(
		Select distinct
		l.SchoolDBN
		,a.schoolType
		,l.GeographicalDistrict
		,a.CaseAssignmentCapacity
		,a.AssignedCapacity
		,(a.AssignedCapacity - a.CaseAssignmentCapacity) as OverAssigned
		, A.availablecapacity
		, l.IsBilingualPsych
		,a.ProcessedDate
		From dbo.vwRPT_T5CaseAssignmentCapacity a WITH(NOLOCK)
		Left Join dbo.RPT_Locations l on a.SchoolDBN = l.schooldbn
		Where a.CaseAssignmentCapacity < a.AssignedCapacity
	) G
	Where g.Overassigned > 0; 

	SET @SourceCNT=(Select SUM(OverAssigned) From #OverAssigned Where SchoolDBN in (select DISTINCT T5IEPTeam from dbo.RPT_T5StudentAssignment Where WaveID=@WaveID));	
	IF (@SourceCNT<>0)
	BEGIN
		SET @ValidationMsgs=CONCAT(@ValidationMsgs,'2:RPT_T5SA Wave ',Cast(@WaveID as varchar),' has over-assigments. ');
		SET @ValStatus='FAIL';
	END;


	--verify RPT_T5SR final statuses are populated
	SET @SourceCNT=(Select Count(*) from dbo.RPT_T5StudentRegister where WaveID=@WaveID);
	IF (@SourceCNT=0)
	BEGIN
		SET @ValidationMsgs=CONCAT(@ValidationMsgs,'3:RPT_T5SR final wave statuses were not populated. Wave:',Cast(@WaveID as varchar), ' final process. ');
		SET @ValStatus='FAIL';
	END;


	--verify that ETLWave IDs in DWH_T5StudentInvalidAddress were populated. We'll not evaluate individual WaveID
	--commented 1/10/2025 - There is no gauranttee that we will have JH Error file for each wave.
	--SET @SourceCNT=(Select Count(*) from dbo.DWH_T5StudentInvalidAddress where ETLWaveID=@WaveID);
	--IF (@SourceCNT=0)
	--BEGIN
	--	SET @ValidationMsgs=CONCAT(@ValidationMsgs,'4:DWH_T5StudentInvalidAddress final wave statuses were not populated. Wave:',Cast(@WaveID as varchar), ' final process. ');
	--	SET @ValStatus='FAIL';
	--END;
	

	--verify INT_T5WES final statuses are populated
	SET @SourceCNT=(Select Count(*) from dbo.INT_T5WaveEligibleStudents where WaveID=@WaveID);
	IF (@SourceCNT=0)
	BEGIN
		SET @ValidationMsgs=CONCAT(@ValidationMsgs,'5:INT_T5WaveEligibleStudents final wave statuses were not populated. Wave:',Cast(@WaveID as varchar), ' final process. ');
		SET @ValStatus='FAIL';
	END;


	--verify that INT_T5WaveSchedule waveactualcount is populated
	SET @SourceCNT=(Select ISNULL(WaveActualCount,0) from dbo.INT_T5WaveSchedule where WaveID=@WaveID);
	IF (@SourceCNT=0)
	BEGIN
		SET @ValidationMsgs=CONCAT(@ValidationMsgs,'6:INT_T5WaveSchedule wave actual count were not populated. Wave:',Cast(@WaveID as varchar), ' final process. ');
		SET @ValStatus='FAIL';
	END;
	

	--Write final validation outcome---------------------------------------------------------------------------------	
	OverrideValidation:
	IF @ValStatus='FAIL'
	BEGIN
		SET @ValidationMsgs=Concat(@ValHeader,' - ***Validation Errors!*** ',@ValidationMsgs)	
		Exec dbo.USPSEO_DataValidationOutcomeINS @ValStatus,@ValKey,@ValidationMsgs;
		RAISERROR (@ValidationMsgs,16,1);		
	END
	ELSE
	BEGIN
		SET @ValStatus='PASS'
		SET @ValidationMsgs=Concat(@ValHeader, ' Successful.')
		Exec dbo.USPSEO_DataValidationOutcomeINS @ValStatus,@ValKey,@ValidationMsgs;
	END;	
END;

