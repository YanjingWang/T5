USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPRPT_T5StudentAssignmentLOAD]    Script Date: 4/4/2026 4:34:02 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[USPRPT_T5StudentAssignmentLOAD]

AS 
BEGIN
	Set Nocount on
     
/**********************************************************************************************************************************************************************************************************
Object Name: dbo.USPRPT_T5StudentAssignmentLOAD
Sample call: EXEC USPRPT_T5StudentAssignmentLOAD;
Purpose: Use to populate RPT_T5StudentAssignment table and update wave processing tables and end wave processing cycle.
Date Created: 11/02/2023

Modification Details:

Author				ModifiedDate	Comments
Christopher Agwu	11/02/2023		Initial 
Christopher Agwu	11/14/2023		Deployed to production
Christopher Agwu	11/17/2023		Restructure students information to be populated to final table (RPT_T5StudentAssignmemnt)
Christopher Agwu	12/19/2023		Student HomeDistrict value to be sourced from JH dataset so its consistent with Assignment process due to HD change in JH file.
									See JIRA Ticket MIS-10313.
Christopher Agwu	1/4/2024		Change (Location) column logic per code in JIRA Ticket MIS-10366
Christopher Agwu	11/1/2024		Move Archive process to buttom of SP. MIS-12245
Raji M				2/6/2025		Added AssignmentLanguage as part of enhancements for language-match
Christopher Agwu	03/26/2025		Added new column GuardianEmail. MIS-12976
Christopher Agwu	05/05/2025		Add code to write to event log for the type of wave been processed (manual wave). No other change. MIS-13180
Christopher Agwu	05/30/2025		Added code to check waveid in schedule and int_T5SSA. They must match to finalize wave. MIS-13419
Christopher Agwu	02/25/2026		Commented code for updating (dbo.DWH_T5StudentInvalidAddress) as table name changed and no longer required to update table. MIS-15047
Christopher Agwu	 03/26/2026		Add ModifiedReasons to archive load. MIS-15188
**********************************************************************************************************************************************************************************************************/

DECLARE 
@TodayDT DATETIME,
@YEAR1900 DATE,
@MaxArchiveDate DATE,
@ProcessedDate DATE,
@EventCnt INT,
@EventHeader VARCHAR(150),
@EventType VARCHAR(50),
@EventMessage VARCHAR(1500); 

DECLARE 
@ErrorMessage  NVARCHAR(4000), 
@ErrorSeverity INT, 
@ErrorState    INT,
@ErrorLine	   NVARCHAR(20);


/**** Dynamic date calculation ****/
SET @ProcessedDate=GETDATE();
SET @TodayDT = GETDATE();
SET @YEAR1900 = '1900-01-01'


--Get active waveid for this process
DECLARE 
@WaveID INT,@INT5SSAWaveID INT,
@WaveDate Date,
@WaveCount INT, 
@WaveDesc VARCHAR(150), 
@CSEOnlyFlag VARCHAR(1),
@INTProcessedDate Date;


SET @WaveID=0
SET @CSEOnlyFlag=NULL
Select @WaveID=WaveID,@WaveDate=WaveDate,@WaveDesc=WaveDescription,@CSEOnlyFlag=CSEOnlyFlag 
from SEO_MART.dbo.INT_T5WaveSchedule Where WaveStatus='I';
SET @INT5SSAWaveID=(Select Max(WaveID) From dbo.INT_T5StudentSchoolAssignment);

SET @EventType='T5Wave';
SET @EventHeader=CONCAT('Wave ',CONVERT(VARCHAR,@WaveID),' Process - USPRPT_T5StudentAssignmentLOAD');

EXEC dbo.USPLOG_SEOEventLog  @EventType,'','';		--linespace

IF @WaveID=0
BEGIN
	SET @EventMessage='Invalid Wave ID: 0, process cannot continue.'
	EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;	
	RAISERROR(@EventMessage, 16, 1);
	RETURN;
END;

--Added 5/30/2025
IF @WaveID<>@INT5SSAWaveID
BEGIN
	SET @EventMessage='INT_T5SSA Processed WaveID and active schedule WaveID does not match, cannot finalize wave.'
	EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;	
	RAISERROR(@EventMessage, 16, 1);
	RETURN;
END;


SET @EventMessage='Start of RPT_T5StudentAssignmentLoad and finalize and close wave process.'
EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;


IF @CSEOnlyFlag='Y'
BEGIN
	SET @EventMessage='This wave is CSEDBN only StudentAssignmentLoad process.'
	EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;		
END;


IF @CSEOnlyFlag='M'		--added 05/05/2025
BEGIN
	SET @EventMessage='This is a MANUAL WAVE StudentAssignmentLoad process.'
	EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;		
END;



--Get CSEDBN Codes--
If OBJECT_ID ('Tempdb..#CSEDBN') is not null
	Drop table #CSEDBN;

Select SchoolDBN AS CSESchoolDBN,LocationCode,RIGHT(LocationCode,2) as CSECode 
INTO #CSEDBN
From SEO_MART.dbo.RPT_Locations Where LEFT(LocationCode,3) = 'CS0' OR LEFT(LocationCode,3)='CS1';



--Get all student info for write to final table (RPT_T5StudentAssignment) --
IF OBJECT_ID('tempdb..#T5SRTemp') IS NOT NULL
	DROP TABLE #T5SRTemp;

Select WES.StudentID
		,WES.SchoolYear
		,SR.CaseType
		,SR.LastName
		,SR.FirstName
		,SR.BirthDate
		,SR.Gender
		,WES.HouseNumber
		,WES.Street
		,WES.BoroughCode
		,WES.ZipCode
		,SR.ApartmentNumber
		,SR. CityName
		,SR.GuardianLastName
		,SR.GuardianFirstName
		,SR.GuardianPhoneNumber
		,SR.GuardianLanguage		
		,SR.T5recordsource				
		,SR.SelectFlag
		,SR.SelectFlagDate		
		,CASE WHEN ISNULL(Z.ZHomeDistrict,'0')='0' THEN SR.HomeDistrict
		WHEN SR.HomeDistrict=Z.ZHomeDistrict THEN SR.HomeDistrict 
		ELSE Z.ZHomeDistrict END as HomeDistrict
		,SR.CSE
		,CS.CSESchoolDBN as CSESchool
		,CONCAT('CSE ',SR.CSE) AS AssignedLocationForTracking
		,WES.IsTurning5
		,SSA.StudentCategory
		,CASE WHEN SSA.StudentCategory='TopBottom' AND SR.IsTop=0 THEN 1 ELSE SR.IsTop END as IsTop
		,CASE WHEN SSA.StudentCategory='TopBottom' AND SR.IsBottom=0 THEN 1 ELSE SR.IsBottom END as IsBottom
		,CASE WHEN SSA.StudentCategory='DV' THEN 1 ELSE 0 END AS IsNoNameStreet
		,WES.IsSibling
		,WES.SiblingKey
		,CASE WHEN SSA.StudentCategory='DHS' THEN 'DHS' WHEN SSA.StudentCategory='DV' THEN 'DV' ELSE NULL END AS DHSDVFlag
		,CASE WHEN SSA.StudentCategory='D75' THEN 'Y' ELSE 'N' END AS D75Flag
		,SR.D75AdminDBN		
		,SR.D75PhysicalDBN
		,SSA.IsBilingualStudent as IsBilingual
		,SSA.IsPOSLanguage		
		,CASE WHEN SSA.StudentCategory='CSETrueInitial' THEN 1 ELSE SR.IsCSETrueInitial END as IsCSETrueInitial		
		,SR.CAPPrekSchool
		,SR.ATSPrekSchoolDBN
		,SR.IsPrek
		,SR.EvalIniConsentDate
		,SR.FirstPDConfDate as FirstPDConferenceDate
		,SR.referralschool 
		,SR.AssessmentBilLangCode 
		,SR.ReferralDate 
		,SR.EvaluationComplianceDate
		,SR.PlacementComplianceDate
		,SR.RecommendedProgram
		,SR.CAPDischargeCode
		,SR.CaseCloseReasonCode 
		,SR.CurrentCAPServiceSchool 
		,SR.ServiceSchoolName 
		,NULL AS CurrentWaveFlag	
		,SR.BiogReportFlag
		,NULL AS ValidAddressFlag
		,NULL AS T5ProcessFlag
		,NULL AS ZonedDistrict
		,SR.ZonedSchool
		,SR.CAPRunDate
		,SR.GuardianEmail
		INTO #T5SRTemp
FROM dbo.INT_T5WaveEligibleStudents WES
INNER JOIN (select Distinct StudentID,StudentCategory,AssignmentPriorityTypeID,IsBilingualStudent,IsPOSLanguage 
	from dbo.INT_T5StudentSchoolAssignment) SSA
ON SSA.StudentID=WES.StudentID
LEFT Join dbo.RPT_T5StudentRegister SR 
ON SR.StudentID= WES.StudentID
LEFT JOIN 
(Select Distinct StudentID,
CASE WHEN LEN(HomeDistrict)<2 and LEN (HomeDistrict)>1 THEN
CONCAT('0',HomeDistrict) ELSE
HomeDistrict
END ZHomeDistrict From SEO_MART.dbo.INT_T5StudentZoneSchool) Z	--Added 12/19/2023 MIS-10313 ChrisAgwu
ON Z.StudentID=SR.StudentID
LEFT JOIN #CSEDBN CS
ON CS.CSECode=SR.CSE;


---Get all assigned students in INT_T5StudentSchoolAssignments DS---
IF OBJECT_ID('tempdb..#INTSSAssignments') IS NOT NULL
	DROP TABLE #INTSSAssignments;

Select WaveID,WaveDate,StudentID, AssignedSchoolDBN AS AssignmentDBN, AssignmentLanguage
INTO #INTSSAssignments
From dbo.INT_T5StudentSchoolAssignment


--Format Assignments Final DS--
IF OBJECT_ID('tempdb..#AssignmentsFinal') IS NOT NULL
		DROP TABLE #AssignmentsFinal;

select SSA.WaveID,
		SSA.WaveDate,
		SSA.StudentID, 
		SSA.AssignmentDBN AS AssignmentDBN, 
		case when CAC.SchoolType ='CSE' then 'CSE'	
			when SSA.AssignmentDBN = '02M347' then 'ASL'
			else SSA.AssignmentLanguage
		end as AssignmentLanguage, 
		SR.CaseType,
              CASE
              WHEN SSA.AssignmentDBN = 'Excd'
                     THEN 'Overflow'
              ELSE CAC.SchoolType 
              END AS T5IEPTeamDesc
         ,CASE
              WHEN CAC.SchoolType = 'CSE'
                     THEN 'CSE IEP team'
              WHEN SSA.AssignmentDBN = 'Excd'
                     THEN 'Overflow'
              ELSE 'School-based IEP team'
              END AS T5IEPTeamType 
		 ,CAC.LocationType		
		 ,SR.SchoolYear
		,SR.LastName
		,SR.FirstName
		,SR.BirthDate
		,SR.Gender
		,SR.HouseNumber
		,SR.Street
		,SR.BoroughCode
		,SR.ZipCode
		,SR.ApartmentNumber
		,SR.CityName
		,SR.GuardianLastName
		,SR.GuardianFirstName
		,SR.GuardianPhoneNumber
		,SR.GuardianLanguage		
		,Left(SSA.AssignmentDBN,2) as IEPTeamDistrict
		,SR.SelectFlag
		,SR.SelectFlagDate
		,SR.HomeDistrict
		,SR.CSE
		,SR.CSESchool
		,SR.AssignedLocationForTracking
		,SR.IsTurning5
		,SR.IsTop
		,SR.IsBottom
		,SR.IsNoNameStreet
		,SR.IsPrek
		,SR.IsBilingual
		,SR.IsSibling
		,SR.SiblingKey
		,SR.DHSDVFlag
		,SR.D75Flag
		,SR.D75AdminDBN
		,SR.D75PhysicalDBN
		,SR.CAPPrekSchool
		,SR.ATSPrekSchoolDBN
		 --Discontinued 1/4/2024 ,CASE WHEN ISNULL(SR.ATSPrekSchoolDBN,'NA') = 'NA' THEN SR.CSESchool ELSE SR.ATSPrekSchoolDBN END
		 ,CASE WHEN ISNULL(SR.ATSPrekSchoolDBN,'NA')='NA' OR SR.ATSPrekSchoolDBN LIKE '88%' THEN SR.CSESchool ELSE SR.ATSPrekSchoolDBN END	--Added 1/4/2024 MIS-10366
		 Location
		,SR.ZonedSchool
		,SR.EvalIniConsentDate
		,SR.FirstPDConferenceDate
		,SR.referralschool 
		,SR.AssessmentBilLangCode 
		,SR.ReferralDate 
		,SR.EvaluationComplianceDate
		,SR.PlacementComplianceDate
		,SR.RecommendedProgram
		,SR.CAPDischargeCode 
		,SR.CaseCloseReasonCode 						
		,SR.CurrentCAPServiceSchool 
		,SR.ServiceSchoolName 	
		,SR.CurrentWaveFlag	
		,SR.BiogReportFlag
		,SR.ValidAddressFlag
		,SR.T5ProcessFlag
		,NULL AS ZonedDistrict
		,SR.CAPRunDate	
		,SR.T5RecordSource		
		,@TodayDT as ProcessedDate
		,@TodayDT as ProcessedDateTime
		,SR.GuardianEmail
		INTO #AssignmentsFinal
From #INTSSAssignments SSA
LEFT Join #T5SRTemp SR 
ON SR.studentid= SSA.StudentID
LEFT JOIN (Select DISTINCT SchoolDBN,SchoolType,LocationType From SEO_MART.dbo.vwRPT_T5CaseAssignmentCapacity) CAC
ON SSA.AssignmentDBN = CAC.SchoolDBN;

SET @EventMessage='AssignmentsFinal temp table created!.'
EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;



--Load Final wave dataset to [RPT_T5StudentAssignment] 
BEGIN TRY
	BEGIN TRANSACTION TRAN1

	INSERT INTO dbo.[RPT_T5StudentAssignment]
	(   
		WaveID
		,WaveDate
		,SchoolYear
		,StudentID
		,T5IEPTeamLanguage--Raji: 2/6/25
		,T5IEPTeam
		,T5IEPTeamDesc
		,T5IEPTeamType
		,LocationType
		,CaseType
		,LastName
		,FirstName
		,BirthDate
		,Gender
		,HouseNumber
		,Street
		,BoroughCode
		,ZipCode
		,ApartmentNumber
		,CityName
		,GuardianLastName
		,GuardianFirstName
		,GuardianPhoneNumber
		,GuardianLanguage
		,SelectFlag
		,SelectFlagDate
		,HomeDistrict
		,CSE
		,CSESchool
		,IsTurning5
		,IsTop
		,IsBottom
		,IsNoNameStreet
		,IsPreK
		,IsBilingual
		,IsSibling
		,SiblingKey
		,DHSDVFlag
		,D75Flag
		,D75AdminDBN
		,D75PhysicalDBN
		,CAPPreKSchool
		,ATSPreKSchoolDBN
		,ZonedSchool
		,Location
		,AssignedLocationForTracking
		,EvalIniConsentDate
		,FirstPDConferenceDate
		,ReferralSchool
		,AssessmentBilLangCode
		,ReferralDate
		,RecommendedProgram
		,CAPDischargeCode
		,CaseCloseReasonCode
		,CurrentCAPServiceSchool
		,ServiceSchoolName
		,CurrentWaveFlag
		,BiogReportFlag
		,ValidAddressFlag
		,T5ProcessFlag
		,ActiveFlag
		,ZonedDistrict
		,T5RecordSource
		,CAPRunDate
		,ProcessedDate
		,ProcessedDateTime
		,GuardianEmail
	)
	SELECT 
		AF.WaveID
		,AF.WaveDate
		,AF.SchoolYear
		,AF.StudentID	
		,AF.AssignmentLanguage as T5IEPTeamLanguage--Raji: 2/6/25
		,AF.AssignmentDBN AS T5IEPTeam
		,AF.T5IEPTeamDesc	
		,AF.T5IEPTeamType	
		,AF.LocationType	
		,AF.CaseType
		,AF.LastName	
		,AF.FirstName	
		,AF.BirthDate	
		,AF.Gender	
		,AF.HouseNumber	
		,AF.Street	
		,AF.BoroughCode	
		,AF.ZipCode	
		,AF.ApartmentNumber	
		,AF.CityName	
		,AF.GuardianLastName	
		,AF.GuardianFirstName	
		,AF.GuardianPhoneNumber	
		,AF.GuardianLanguage	
		,AF.SelectFlag	
		,AF.SelectFlagDate	
		,AF.HomeDistrict	
		,AF.CSE
		,AF.CSESchool
		,AF.IsTurning5	
		,AF.IsTop	
		,AF.IsBottom	
		,AF.IsNoNameStreet	
		,AF.IsPrek	
		,AF.IsBilingual
		,AF.IsSibling	
		,AF.SiblingKey
		,AF.DHSDVFlag
		,AF.D75Flag
		,AF.D75AdminDBN	
		,AF.D75PhysicalDBN	
		,AF.CAPPrekSchool	
		,AF.ATSPrekSchoolDBN	
		,AF.ZonedSchool
		,AF.Location	
		,AF.AssignedLocationForTracking	
		,AF.EvalIniConsentDate	
		,AF.FirstPDConferenceDate
		,AF.Referralschool	
		,AF.AssessmentBilLangCode	
		,AF.ReferralDate
		,AF.RecommendedProgram	
		,AF.CAPDischargeCode	
		,AF.CaseCloseReasonCode	
		,AF.CurrentCAPServiceSchool	
		,AF.ServiceSchoolName	
		,AF.CurrentWaveFlag	
		,AF.BiogReportFlag
		,AF.ValidAddressFlag	
		,AF.T5ProcessFlag
		,'Y' as ActiveFlag
		,AF.ZonedDistrict
		,AF.T5recordsource		
		,AF.CAPRunDate	
		,AF.ProcessedDate	
		,AF.ProcessedDateTime
		,AF.GuardianEmail
	FROM #AssignmentsFinal AF;
	---
	SET @EventMessage='Insert to RPT_T5StudentAssignment final table completed!.'
	EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;

	/*Commented 2/25/2026 - Target table name changed and no longer required to update table. MIS-15047
	--Update students wave process info in DWH_T5StudentInvalidAddress table with current wave info--
	UPDATE DST
		SET 
		DST.ETLWaveID=SOR.WaveID,
		DST.ETLWaveDate=SOR.WaveDate,
		DST.ETLWaveProcessedDate=@TodayDT, 
		DST.ETLModifiedDate=@TodayDT
	FROM dbo.DWH_T5StudentInvalidAddress DST
	INNER JOIN #INTSSAssignments SOR
	ON SOR.StudentID=DST.StudentID;
	----
	SET @EventMessage='Update DWH_T5StudentInvalidAddress table with wave information completed!.'
	EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;
	*/

	--Update students wave process  info on INT_T5WaveEligibleStudents table with current wave info
	UPDATE DST
		SET 
		DST.WaveID=SOR.WaveID,
		DST.WaveDate=SOR.WaveDate,
		DST.WaveProcessedDate=@TodayDT, 
		DST.ModifiedDateTime=@TodayDT
	FROM dbo.INT_T5WaveEligibleStudents DST
	INNER JOIN #INTSSAssignments SOR
	ON SOR.StudentID=DST.StudentID;
	----
	SET @EventMessage='Update INT_T5WaveEligibleStudents table with wave information completed!.'
	EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;



	--update students wave process info on dbo.RPT_T5StudentRegister table with current wave info
	UPDATE DST
		SET 
		DST.WaveID=SOR.WaveID,
		DST.WaveDate=SOR.WaveDate,
		DST.WaveProcessedDate=@TodayDT, 
		DST.ModifiedDate=@TodayDT
	FROM dbo.RPT_T5StudentRegister DST
	INNER JOIN #INTSSAssignments SOR
	ON SOR.StudentID=DST.StudentID;
	-----
	SET @EventMessage='Update RPT_T5StudentRegister table with wave information completed!.'
	EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;


	--update INT_T5WaveSchedule and close current wave processing indicators
	DECLARE @UPDRecAffected INT;

	SET @WaveCount=(Select Count(*) From #INTSSAssignments)
	EXEC @UPDRecAffected=dbo.USPINT_T5WaveSchedule 'EndWave',@WaveCount,@WaveID,NULL,NULL
	--should be 1 else nothing was updated
	IF(@UPDRecAffected=0)	--nothing was updated hence wave process not finalized
	BEGIN
		SET @EventMessage='Error - While updating T5WaveSchedule and ending wave process. all updates are rolled back!' 
		EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;
		RAISERROR('Error - Unbale to End Wave process and update T5WaveSchedule table.', 16, 1);
	END
	ELSE
	BEGIN		
		COMMIT TRANSACTION TRAN1;
	
		SET @EventMessage='Update USPINT_T5WaveSchedule and closing wave process completed successfully!.'
		EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;
		
		SET @EventMessage='Write assigned students to RPT_T5StudentAssignment table completed.' 
		EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;

		--write total student count assigned on this wave
		SET @EventMessage=CONCAT('Total students assigned on wave:', Convert(varchar,@WaveID), ' : ', CONVERT(VARCHAR,@WaveCount)) 
		EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;
	
		--write total students count NOT assigned on this wave	
		SET @WaveCount=(Select count(*)CNT From (
			Select Distinct StudentID From dbo.INT_T5WaveEligibleStudents
			Except
			Select Distinct StudentID From #INTSSAssignments
		) A);	
		SET @EventMessage=CONCAT('Total students NOT assigned on wave:', Convert(varchar,@WaveID), ' : ', CONVERT(VARCHAR,@WaveCount))
		EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;

		--write end of wave process
		SET @EventMessage='End of Wave:' + Convert(varchar,@WaveID) + ' process.'
		EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;
		EXEC dbo.USPLOG_SEOEventLog  @EventType,'','';
	END;
END TRY
BEGIN CATCH
	SELECT @ErrorMessage = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorLine=CAST(ERROR_LINE() AS VARCHAR(50));

	ROLLBACK TRANSACTION TRAN1;

	SET @EventMessage=CONCAT('Error - Occurred and RPT_T5StudentAssignment trancations are rolled back!.', ' - SQL ErrorMessage - ',@ErrorMessage, ' ErrorLine:',@ErrorLine);
	EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;

	RAISERROR(@EventMessage, 16, 1);

END CATCH;
--END-OF-WAVE-PROCESS--


--11/1/2024 MIS-12245
--Archive each time this SP is run. Any multiple archive run in a day will be manually corrected. 
/*
SET @MaxArchiveDate =
(
    SELECT CASE WHEN MAX(ArchiveDate) IS NULL THEN @YEAR1900 ELSE MAX(ArchiveDate) END
	FROM arch.RPT_T5StudentAssignment	
);

--------Archive only once in a day. This will avoid multiple archive of same last wave data in case of procedure rerun.		
IF @MaxArchiveDate < CAST(@TodayDT as DATE)
BEGIN
END;
*/

   --Archive RPT_T5StudentAssignment table--
  INSERT INTO arch.RPT_T5StudentAssignment
    (
		WaveID
		,WaveDate
		,SchoolYear
		,StudentID
		,T5IEPTeamLanguage
		,T5IEPTeam
		,T5IEPTeamDesc
		,T5IEPTeamType
		,LocationType
		,CaseType
		,LastName
		,FirstName
		,BirthDate
		,Gender
		,HouseNumber
		,Street
		,BoroughCode
		,ZipCode
		,ApartmentNumber
		,CityName
		,GuardianLastName
		,GuardianFirstName
		,GuardianPhoneNumber
		,GuardianLanguage
		,CurrentAddAdminDBN
		,SelectFlag
		,SelectFlagDate
		,HomeDistrict
		,AssignedLocationForTracking
		,EvalIniConsentDate
		,FirstPDConferenceDate
		,ReferralSchool
		,AssessmentBilLangCode
		,ReferralDate
		,RecommendedProgram
		,CAPDischargeCode
		,CaseCloseReasonCode
		,CurrentCAPServiceSchool
		,ServiceSchoolName
		,CSE
		,CSESchool
		,IsTurning5
		,IsTop
		,IsBottom
		,IsNoNameStreet
		,IsPreK
		,IsSibling
		,SiblingKey
		,DHSDVFlag
		,D75Flag
		,D75AdminDBN
		,D75PhysicalDBN
		,CAPPreKSchool
		,ATSPreKSchoolDBN		
		,Location
		,ZonedSchool
		,CurrentWaveFlag
		,BiogReportFlag
		,ValidAddressFlag
		,T5ProcessFlag
		,ActiveFlag
		,ZonedDistrict
		,CAPRunDate
		,ReassignmentDate
		,T5RecordSource
		,IsBilingual
		,ModifiedDate
		,ModifiedReasons
		,ProcessedDate
		,ProcessedDateTime		
		,ArchiveDate
		,GuardianEmail
	)
	SELECT  
	  	WaveID
		,WaveDate
		,SchoolYear
		,StudentID
		,T5IEPTeamLanguage
		,T5IEPTeam
		,T5IEPTeamDesc
		,T5IEPTeamType
		,LocationType
		,CaseType
		,LastName
		,FirstName
		,BirthDate
		,Gender
		,HouseNumber
		,Street
		,BoroughCode
		,ZipCode
		,ApartmentNumber
		,CityName
		,GuardianLastName
		,GuardianFirstName
		,GuardianPhoneNumber
		,GuardianLanguage
		,CurrentAddAdminDBN
		,SelectFlag
		,SelectFlagDate
		,HomeDistrict
		,AssignedLocationForTracking
		,EvalIniConsentDate
		,FirstPDConferenceDate
		,ReferralSchool
		,AssessmentBilLangCode
		,ReferralDate
		,RecommendedProgram
		,CAPDischargeCode
		,CaseCloseReasonCode
		,CurrentCAPServiceSchool
		,ServiceSchoolName
		,CSE
		,CSESchool
		,IsTurning5
		,IsTop
		,IsBottom
		,IsNoNameStreet
		,IsPreK
		,IsSibling
		,SiblingKey
		,DHSDVFlag
		,D75Flag
		,D75AdminDBN
		,D75PhysicalDBN
		,CAPPreKSchool
		,ATSPreKSchoolDBN		
		,Location
		,ZonedSchool
		,CurrentWaveFlag
		,BiogReportFlag
		,ValidAddressFlag
		,T5ProcessFlag
		,ActiveFlag
		,ZonedDistrict
		,CAPRunDate
		,ReassignmentDate
		,T5RecordSource
		,IsBilingual
		,ModifiedDate
		,ModifiedReasons
		,ProcessedDate
		,ProcessedDateTime		
	    ,@TodayDT AS ArchiveDate
		,GuardianEmail
  FROM dbo.RPT_T5StudentAssignment;

--post to event log
SET @EventMessage=CONCAT('arch_RPT_T5StudentAssignment date of: ', CONVERT(VARCHAR(24),@MaxArchiveDate), ' completed.') 
EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;


END;
