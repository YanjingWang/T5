USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPINT_T5WaveEligibleStudents]    Script Date: 4/4/2026 1:54:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*===========================================================================================================================================================================
Object Name: dbo.USPINT_T5WaveEligibleStudents
Purpose:	Extract T5 wave eligible students for insert and generate JH file for zoing and siblings with different address.
Execute:	dbo.USPINT_T5WaveEligibleStudents(@)
Parameters:	(SibWithDiffAdr)	- Get dataset of siblings with different address.
			(EligStudents)		- Merge new eligible students into T5WaveEligibleStudents table and get the dataset
			(MWEligStudents)	- Merge new manual eligible students into T5WaveEligibleStudents table and get the dataset
Date Created: 8/4/2023

Modification Details:
Author				ModifiedDate	Comments
Christopher Agwu	8/4/2023		Initial 
Christopher Agwu	10/16/2023		Deployment to productiion
Christopher Agwu	10/25/2023		Resolve bug on Sibling with diff address code block.
Christopher Agwu	11/21/2023		Only students in CAP home district between 1 and 32 should be considered for T5 wave . See JIRA ticket MIS-10198
Christopher Agwu	11/29/2023		Add code for students with diff address to pick the address with highest assignment priority (DHS,BLPOS,BLNotPOS). See ticket MIS-102225
Christopher Agwu	01/16/2024		Fixed Object_ID and drop table name mismatch (#tblStudDiffAddressTemp)
Christopher Agwu	06/26/2024		Added code to start T5 Wave processing from this SP. MIS-11231
Christopher Agwu	08/12/2024		Remove HomeDistrict 1-32 filter so that all HomeDistrict will be included. MIS-11626
Christopher Agwu	10/01/2024		Updated code to resolve duplicate insert when there are three or more siblings with different address
Christopher Agwu	01/09/2025		Add code to calculate Student Categories so that it can be filtered out based on Wave processing requirement in INT_T5WaveSchedule (MIS-12579)
Christopher Agwu	04/25/2025		Add code and new columns for manual wave assignment eligibility. MIS-13180
Christopher Agwu	05/20/2025		Add code to populate (CaseType) column and IsManualWave in INT_T5WaveEligibleStudents. MIS-13315
Christopher Agwu	05/29/2025		Added IsManualWave=1 to the manual wave request file extract this way only manual records are selected.
Christopher Agwu	06/10/2025		Added IsManualWave=1 to manualwave update codeblock. Added IsManualWave=0 to EligStudent update codeblock so students are not missed.
Charlotte Wang      11/04/2025      Update the proc so it stamps ProcessedDatetime on both UPDATE and INSERT
Raji				12/18/2025		Added IsTurning5, IsSibling, SiblingKey to UPDATE as part of MERGE-MATCHED
==================================================================================================================================================================================*/

ALTER   PROCEDURE [dbo].[USPINT_T5WaveEligibleStudents]
(
	@GetDataSet VARCHAR(20)	
)	
AS

Declare @BirthYear INT
DECLARE @EventHeader VARCHAR(150), @EventType VARCHAR(50);
DECLARE @EventMessage VARCHAR(1500);
Declare @CatID1ASL SMALLINT, @CatID2SpecialPop SMALLINT, @CatID3Sibling SMALLINT, @CatID4DHS SMALLINT;
Declare @CatID5BLInPOS SMALLINT, @CatID6BLNotPOS SMALLINT,@CatID7MonoL SMALLINT, @TodayDate Date;
Declare @WaveCatIDS Varchar(20), @NextWaveID SmallInt, @ManualAssignmentFlag Varchar(1),@SchoolYear Varchar(10), @IsManualWave BIT;


BEGIN

	SET NOCOUNT ON;
	
	If OBJECT_ID ('Tempdb..#tblEligibleStud') is not null
		Drop table #tblEligibleStud;

	If OBJECT_ID ('Tempdb..#tblStudDiffAddressTemp') is not null	--added 11/29/2023
		Drop table #tblStudDiffAddressTemp;

	If OBJECT_ID ('Tempdb..#tblStudAddressDiff') is not null
		Drop table #tblStudAddressDiff;

	If OBJECT_ID ('Tempdb..#tblWaveEligibleDS') is not null
		Drop table #tblWaveEligibleDS;

	If OBJECT_ID ('Tempdb..#tblWCIDS') is not null
		Drop table #tblWCIDS;


	SET @BirthYear=(select dbo.fn_GetT5BirthYear());
	SET @CatID1ASL=1
	SET @CatID2SpecialPop=2
	SET @CatID3Sibling=3
	SET @CatID4DHS=4
	SET @CatID5BLInPOS=5
	SET @CatID6BLNotPOS=6
	SET @CatID7MonoL=7

	SET @SchoolYear=(Select dbo.fn_GetT5SchoolYear());
	SET @TodayDate=getdate();

	SET @EventType='T5Wave';
	SET @EventHeader='Wave Process - USPINT_T5WaveEligibleStudents';
		
	--Get next Wave WaveCatIDS-- Added 1/9/2025--	
	IF (Select count(*) From dbo.INT_T5WaveSchedule Where WaveStatus='I')>=1 and @GetDataSet IN ('EligStudents','MWEligStudents')
	BEGIN
		SET @EventMessage=CONCAT('InputDataset: ',@GetDataSet, '. There is an active wave processing in progress. Cannot start a new wave processing!')
		EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;
		RAISERROR (@EventMessage,16,1)		
		RETURN;
	END;

	Select TOP 1 @NextWaveID=WaveID,@WaveCatIDS=ISNULL(WaveCatIDS,0), @ManualAssignmentFlag=CSEOnlyFlag From dbo.INT_T5WaveSchedule Where WaveStatus='E' Order by WaveID ASC;
	
	SET @EventHeader=CONCAT('Wave ',CONVERT(varchar,@NextWaveID),' Process - USPINT_T5WaveEligibleStudents');
		
	SELECT value as WCatIDS INTO #tblWCIDS
	FROM STRING_SPLIT(@WaveCatIDS, ',')
	WHERE RTRIM(value) <> '';
	
	--get all wave eligible students population
	--Added columns DHS,BL,POS	11/29/2023
	Select ES.* INTO #tblEligibleStud From (
		Select SR.SchoolYear,SR.StudentID,
		CASE WHEN SR.DHSDVFlag IS NULL THEN 0 ELSE 1 END as IsDHSDV,
		SR.IsBilingual,SR.IsPOSLanguage,
		SR.IsSibling,SiblingKey, TRIM(SR.HouseNumber) AS HouseNumber ,TRIM(SR.Street) AS STREET,
		CONCAT(TRIM(SR.HouseNumber),' ', TRIM(SR.Street)) AS HouseNumberStreet, SR.BoroughCode,SR.ZipCode,SR.IsTurning5,	
		CASE		
		WHEN (SR.ATSPrekSchoolDBN = '02M047' OR SR.GuardianLanguage='SX' OR SR.AssessmentBilLangCode='SX')  THEN @CatID1ASL
		WHEN SR.ATSPrekSchoolDBN = '02M347' THEN @CatID1ASL
		WHEN (SR.IsTop=1 OR SR.IsBottom=1) THEN @CatID2SpecialPop
		WHEN SR.D75Flag='Y' THEN @CatID2SpecialPop
		WHEN SR.ATSPrekSchoolDBN LIKE '84%' THEN @CatID2SpecialPop
		WHEN SR.DHSDVFlag='DV' THEN @CatID4DHS
		WHEN SR.IsCSETrueInitial=1 THEN @CatID2SpecialPop
		WHEN SR.DHSDVFlag='DHS' THEN @CatID4DHS
		WHEN SR.IsBilingual=1 AND SR.IsPOSLanguage=1 THEN @CatID5BLInPOS
		WHEN SR.IsBilingual=1 AND SR.IsPOSLanguage=0 THEN @CatID6BLNotPOS
		WHEN SR.IsBilingual=0 THEN @CatID7MonoL
		ELSE 0
		END StudentCatPriorityID,	--added 1/9/2025 MIS-12579--
		--added 4/25/2025 due to manual assignment
		SR.HomeDistrict,
		CS.CSESchoolDBN as CSEDBN,
		SR.T5RecordSource,
		CASE WHEN 
			SR.IsCSETrueInitial=1
			OR SR.IsNoNameStreet=1
			OR SR.IsTop=1
			OR SR.IsBottom=1
			OR SR.ATSPrekSchoolDBN LIKE '84%'
			OR SR.D75Flag='Y'
		THEN 1 ELSE 0 END IsSpecialPopulation,
		SR.IsCSETrueInitial,
		SR.FirstPDConsentedForSVCSDate,
		SR.IEPConferenceDate,													
		SR.EvaluationDesc,															
		SR.CaseCloseReasonCode,
		SR.IsNoNameStreet as IsDV,
		CASE WHEN SR.IsTop=1 OR SR.IsBottom=1 THEN 1 ELSE 0 END IsTopBottom,
		SR.ATSPreKSchoolDBN,
		SR.CaseType
		FROM dbo.RPT_T5StudentRegister SR
		LEFT JOIN dbo.vwlk_CSESchoolDBN CS
		ON CS.CSEDistrict=SR.CSE
		Where SR.IsTurning5=1 and SR.WaveProcessedDate IS NULL
		--AND TRIM(SR.HomeDistrict) NOT IN ('88','98','99')		--Discontinued 11/21/2023 
		--AND Cast(SR.HomeDistrict AS INT)>=1	--Commented 8/12/2024 MIS-11626.	--Added 11/21/2023
		--AND Cast(SR.HomeDistrict AS INT)<=32	--Commented 8/12/2024 MIS-11626.	--Added 11/21/2023	
		AND YEAR(SR.BirthDate)=@BirthYear
	) ES Where ES.StudentCatPriorityID IN (select WCatIDS from #tblWCIDS)
	OR (CASE WHEN @WaveCatIDS='0' THEN 1 END=1)
	Order by ES.SiblingKey;	
	
	--added 11/29/2023
	--Find only unique siblings with different address. 
	--This is just to identify siblings with diff address but the address here is not necessarily to be used for final eligibility file.	
	Select A.* INTO #tblStudDiffAddressTemp from (
		Select SiblingKey,IsSibling, HouseNumber,Street,HouseNumberStreet,BoroughCode,ZipCode,
		ROW_NUMBER() OVER(Partition by SiblingKey Order by SiblingKey) as DiffAdrID	
		from #tblEligibleStud			
		Group by SiblingKey,IsSibling, HouseNumber,Street,HouseNumberStreet,BoroughCode,ZipCode
	) A
	Where A. DiffAdrID>1;
	

	--Find the best address pick based in order of priorities (DHS,BLPOS,BLNotPOS) for eligibility file which will be sent to JH 		
	Select A.* INTO #tblStudAddressDiff from (						
		Select IsDHSDV,IsBilingual,IsPOSLanguage, SiblingKey,IsSibling, HouseNumber,Street,HouseNumberStreet,BoroughCode,ZipCode,
		ROW_NUMBER() OVER(Partition by SiblingKey Order by IsDHSDV ASC,IsBilingual ASC,IsPOSLanguage ASC) as HSHID		
		from #tblEligibleStud
		Where SiblingKey IN (Select SiblingKey From #tblStudDiffAddressTemp) 		
		Group by IsDHSDV,IsBilingual,IsPOSLanguage,SiblingKey,IsSibling, HouseNumber,Street,HouseNumberStreet,BoroughCode,ZipCode				
	) A
	Where A.HSHID>1 and A.HSHID<=2 --added 2nd filter to only get 1 sinbling record 10/01/2024
	

	If @GetDataSet='SibWithDiffAdr'
	BEGIN
		--get only siblings with diff address, exclude siblings with only 1 count
		Select S.StudentID,S.IsSibling, S.SiblingKey,S.HouseNumber,S.Street,S.HouseNumberStreet,S.BoroughCode,S.ZipCode
		From (Select * from #tblStudAddressDiff) A
		INNER JOIN #tblEligibleStud S
		ON S.SiblingKey=A.SiblingKey;
		Return;
	END;


	If @GetDataSet IN ('EligStudents','MWEligStudents')
	BEGIN

		--Added 06/26/2024 MIS-11231
		--Start of wave process and get new waveid for this process
		DECLARE @WaveID INT,@WaveDate Date
		SET @WaveID=0
		SET @WaveDate=null		
		EXEC dbo.USPINT_T5WaveSchedule 'BegWave',0,@WaveID OUTPUT,@WaveDate OUTPUT,NULL; 
	
		IF @NextWaveID=0
		BEGIN
			SET @EventMessage=CONCAT('Invalid WaveID: ', Convert(varchar,@NextWaveID),', unable to start wave and get new waveID, cannot creat T5 Wave eligibility file.')
			EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;
			RAISERROR (@EventMessage,16,1)		
			RETURN;
		END;

		--Added 1/9/2025 - To ensure that new waveid with wavecatids matches waveid received after start of wave
		IF @NextWaveID<>@WaveID
		BEGIN
			SET @EventMessage=CONCAT('Next WaveID for WaveCatIDS: ', Convert(varchar,@WaveID),', does not match start new T5 WaveID: ',Convert(varchar,@NextWaveID),', cannot creat T5 Wave eligibility file.')
			EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;		
			RAISERROR (@EventMessage,16,1)		
			RETURN;
		END;

		--add code here to write eventlog.		
		SET @EventMessage=CONCAT('Beginning of Wave: ', Convert(varchar,@WaveID), ' Process.');
		EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;		
		SET @EventMessage=CONCAT('Start process Wave: ', Convert(varchar,@WaveID), ' - ',@GetDataSet,' T5WaveEligibleStudents.');
		EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;
	END;

	--create elig temp table
	DROP TABLE IF EXISTS #tblWaveEligibleDS;
	Select StudentID, SiblingKey,IsSibling,HouseNumber,Street,CAST(NULL as Varchar(255)) as HouseNumberStreet,BoroughCode,ZipCode,IsTurning5, 
	HomeDistrict,CAST(NULL as Varchar(6)) as CSEDBN, T5RecordSource,CAST(NULL as BIT) as IsSpecialPopulation,IsCSETrueInitial,FirstPDConsentedForSVCSDate,
	IEPConferenceDate,EvaluationDesc,CaseCloseReasonCode,CAST(NULL as BIT) as IsDV,IsTop as IsTopBottom,ATSPreKSchoolDBN,CaseType,CAST(0 as bit) as IsManualWave
	INTO #tblWaveEligibleDS
	From dbo.RPT_T5StudentRegister Where 1=0;
		
	If @GetDataSet='EligStudents'
	BEGIN
		--Merge sibling diff addresses so addresses match/same for sending to JH--
		INSERT INTO #tblWaveEligibleDS (
			StudentID,SiblingKey,IsSibling,HouseNumber,Street,HouseNumberStreet,BoroughCode,ZipCode,IsTurning5
		)		
		Select S.StudentID, A.SiblingKey,A.IsSibling,A.HouseNumber,A.Street,A.HouseNumberStreet,A.BoroughCode,A.ZipCode,S.IsTurning5
		From (Select * from #tblStudAddressDiff) A
		INNER JOIN #tblEligibleStud S
		ON S.SiblingKey=A.SiblingKey
		UNION
		Select S.StudentID, S.SiblingKey,S.IsSibling,S.HouseNumber,S.Street,S.HouseNumberStreet,S.BoroughCode,S.ZipCode,S.IsTurning5
		from #tblEligibleStud S
		Where SiblingKey NOT IN (Select SiblingKey from #tblStudAddressDiff);
				
		--Do INSERT and UPDATE--		
		MERGE INTO dbo.INT_T5WaveEligibleStudents DT
		USING #tblWaveEligibleDS SR
		ON SR.StudentID=DT.StudentID
		WHEN MATCHED AND DT.SchoolYear=@SchoolYear AND DT.WaveID IS NULL THEN
			UPDATE SET
			DT.HouseNumber=SR.HouseNumber,
			DT.Street=SR.Street,
			DT.HouseNumberStreet=SR.HouseNumberStreet,
			DT.BoroughCode=SR.BoroughCode,
			DT.ZipCode=SR.ZipCode,
			DT.ModifiedDatetime=@TodayDate,
			DT.IsManualWave=0,
			DT.IsTurning5 = SR.IsTurning5,
			DT.IsSibling = SR.IsSibling,
			DT.SiblingKey = SR.SiblingKey
		WHEN NOT MATCHED THEN
			INSERT (SchoolYear,StudentID,IsSibling,SiblingKey,HouseNumber,Street,HouseNumberStreet,BoroughCode,ZipCode,IsTurning5)
			VALUES (@SchoolYear,SR.StudentID,SR.IsSibling,SR.SiblingKey, SR.HouseNumber,SR.Street,SR.HouseNumberStreet,SR.BoroughCode,SR.ZipCode,SR.IsTurning5);
	
		---Get the wave eligible students dataset for Ariel to send to JH
		Select StudentID,IsSibling,SiblingKey,HouseNumber,Street,HouseNumberStreet,BoroughCode,ZipCode
		From dbo.INT_T5WaveEligibleStudents where WaveID IS NULL AND IsManualWave=0
		Order by IsSibling,SiblingKey;
		RETURN;
	END;

	IF @GetDataSet='MWEligStudents' and @ManualAssignmentFlag='M'	--manual wave assignment
	BEGIN
		SET @IsManualWave=1;
		--Merge sibling diff addresses so addresses match/same for sending to JH--
		INSERT INTO #tblWaveEligibleDS (
			StudentID,SiblingKey,IsSibling,HouseNumber,Street,HouseNumberStreet,BoroughCode,ZipCode,IsTurning5,HomeDistrict,CSEDBN,T5RecordSource,
			IsSpecialPopulation,IsCSETrueInitial,FirstPDConsentedForSVCSDate,IEPConferenceDate,EvaluationDesc,CaseCloseReasonCode,IsDV,IsTopBottom,ATSPreKSchoolDBN,CaseType,IsManualWave
		)
		Select S.StudentID, A.SiblingKey,A.IsSibling,A.HouseNumber,A.Street,A.HouseNumberStreet,A.BoroughCode,A.ZipCode,S.IsTurning5,S.HomeDistrict,S.CSEDBN,S.T5RecordSource,
		S.IsSpecialPopulation,S.IsCSETrueInitial,S.FirstPDConsentedForSVCSDate,S.IEPConferenceDate,S.EvaluationDesc,S.CaseCloseReasonCode,S.IsDV,S.IsTopBottom,S.ATSPreKSchoolDBN,S.CaseType,@IsManualWave
		From (Select * from #tblStudAddressDiff) A
		INNER JOIN #tblEligibleStud S
		ON S.SiblingKey=A.SiblingKey
		UNION
		Select S.StudentID, S.SiblingKey,S.IsSibling,S.HouseNumber,S.Street,S.HouseNumberStreet,S.BoroughCode,S.ZipCode,S.IsTurning5,S.HomeDistrict,S.CSEDBN,S.T5RecordSource,
		S.IsSpecialPopulation,S.IsCSETrueInitial,S.FirstPDConsentedForSVCSDate,S.IEPConferenceDate,S.EvaluationDesc,S.CaseCloseReasonCode,S.IsDV,S.IsTopBottom,S.ATSPreKSchoolDBN,S.CaseType,@IsManualWave
		from #tblEligibleStud S
		Where SiblingKey NOT IN (Select SiblingKey from #tblStudAddressDiff);
		
		--Do INSERT and UPDATE--
		MERGE INTO dbo.INT_T5WaveEligibleStudents DT
		USING #tblWaveEligibleDS SR
		ON SR.StudentID=DT.StudentID
		WHEN MATCHED AND DT.SchoolYear=@SchoolYear AND DT.WaveID IS NULL THEN
			UPDATE SET
			DT.HouseNumber=SR.HouseNumber,
			DT.Street=SR.Street,
			DT.HouseNumberStreet=SR.HouseNumberStreet,
			DT.BoroughCode=SR.BoroughCode,
			DT.ZipCode=SR.ZipCode,
			DT.HomeDistrict=SR.HomeDistrict,
			DT.CSEDBN=SR.CSEDBN,
			DT.T5RecordSource=SR.T5RecordSource,
			DT.IsSpecialPopulation=SR.IsSpecialPopulation,
			DT.IsCSETrueInitial=SR.IsCSETrueInitial,
			DT.FirstPDConsentedForSVCSDate=SR.FirstPDConsentedForSVCSDate,
			DT.IEPConferenceDate=SR.IEPConferenceDate,
			DT.EvaluationDesc=SR.EvaluationDesc,
			DT.CaseCloseReasonCode=SR.CaseCloseReasonCode,
			DT.IsDV=SR.IsDV,
			DT.IsTopBottom=SR.IsTopBottom,
			DT.ATSPreKSchoolDBN=SR.ATSPreKSchoolDBN,
			DT.CaseType=SR.CaseType,
			DT.ModifiedDatetime=@TodayDate,
			/*Charlotte: Update the proc so it stamps ProcessedDatetime on both UPDATE and INSERT*/
			DT.ProcessedDatetime = @TodayDate,      -- <— add this
			DT.IsManualWave=@IsManualWave,
			DT.IsTurning5 = SR.IsTurning5,
			DT.IsSibling = SR.IsSibling,
			DT.SiblingKey = SR.SiblingKey
		WHEN NOT MATCHED THEN
			INSERT (SchoolYear,StudentID,IsSibling,SiblingKey,HouseNumber,Street,HouseNumberStreet,BoroughCode,ZipCode,IsTurning5,HomeDistrict,CSEDBN,T5RecordSource,
			IsSpecialPopulation,IsCSETrueInitial,FirstPDConsentedForSVCSDate,IEPConferenceDate,EvaluationDesc,CaseCloseReasonCode,IsDV,IsTopBottom,ATSPreKSchoolDBN,CaseType,
			ProcessedDatetime,IsManualWave) -- <— add this
			VALUES (@SchoolYear,SR.StudentID,SR.IsSibling,SR.SiblingKey, SR.HouseNumber,SR.Street,SR.HouseNumberStreet,SR.BoroughCode,SR.ZipCode,SR.IsTurning5,SR.HomeDistrict,SR.CSEDBN,SR.T5RecordSource,
			SR.IsSpecialPopulation,SR.IsCSETrueInitial,SR.FirstPDConsentedForSVCSDate,SR.IEPConferenceDate,SR.EvaluationDesc,SR.CaseCloseReasonCode,SR.IsDV,SR.IsTopBottom,SR.ATSPreKSchoolDBN,SR.CaseType,
			@TodayDate, @IsManualWave);-- <— add this
	
		---Get the wave eligible students dataset for Ariel to send to JH
		Select StudentID,IsSpecialPopulation,IsCSETrueInitial,FirstPDConsentedForSVCSDate,IEPConferenceDate,EvaluationDesc,CaseCloseReasonCode,IsDV,IsTopBottom,ATSPreKSchoolDBN,
		CaseType,IsSibling,SiblingKey,HouseNumber,Street,HouseNumberStreet,BoroughCode,ZipCode,HomeDistrict,@NextWaveID as WaveID,@TodayDate as ProcessedDate, CSEDBN,T5RecordSource, 
		'' as ReturnValueT5IEPTeam
		From dbo.INT_T5WaveEligibleStudents where WaveID IS NULL And IsManualWave=1
		Order by IsSibling,SiblingKey;
		RETURN;		
	END;

	If @GetDataSet NOT IN ('EligStudents','MWEligStudents')
	BEGIN
		SET @EventMessage='Invalid data extract type entered!';
		EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;
		RAISERROR (@EventMessage,16,1)
		RETURN;
	END;
END
