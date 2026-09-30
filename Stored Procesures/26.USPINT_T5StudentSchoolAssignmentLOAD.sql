USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPINT_T5StudentSchoolAssignmentLOAD]    Script Date: 4/14/2026 6:13:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[USPINT_T5StudentSchoolAssignmentLOAD]
/***************************************************************************************************
Order of Assignments for a regular wave (which is SBST + CSE)
ASL
SpecialPopulation
Sibling w a prior assignment
Sibling w/o a prior assignment, bilingual in POS - with language match in zoned DBN   
Sibling w/o a prior assignment, bilingual in POS - with language match in nearest DBN 

Bilingual in POS - with language match in Zoned DBN - priority order DHS followed by BilingaulInPOS
Bilingual in POS - with language match in nearest DBN - priority order DHS followed by BilingaulInPOS

Zoned DBN - priority order  Sibling, DHS followed by all others  
Nearest DBN - priority order  Sibling, DHS followed by all others 

CSE DBN - everybody without an assignment

Modification History
2/2/2025		Raji			Initial Version
4/7/2025		Raji			Created ##sibling_T5 table in the 'create gloabl temp table' section
								to avoid errors with the existence of that table for 'CSEOnly' wave
5/2/2025		ChrisA			Added code for T5 Manual Wave Assignment process. MIS-13180
11/22/2025		Charlotte		Replaced global temp tables with permanent tables ending with "_WT" (WT = Working Table)
04/09/2026		Raji			Fix failure of the assignment process when more than one record is inserted into  
								RPT_T5newAssignments_WT table when a student having a sibling with prior assignemnt 
								is a 'SpecialPopulation' (Ex: StudentID: 250034270, WaveID 8, SY25-26 wave)
								To fix the issue, the assignment order is changed. Siblings with prior assignment
								are assigned before assigning 'SpecialPopulation'
********************************************************************************************************/
AS 
BEGIN
	Set Nocount on

	DECLARE @Today DATETIME;
	DECLARE @YEAR1900 DATE;
	DECLARE @SchoolYear VARCHAR(10);
	DECLARE @MaxArchiveDate DATE;
	DECLARE @ProcessedDate DATE;
	DECLARE @EventCnt INT
	DECLARE @EventHeader VARCHAR(150), @EventType VARCHAR(50);
	DECLARE @EventMessage VARCHAR(1500); 
	Declare @CheckErrorMsg varchar(50);
	Declare @DebugMode INT=1;	--1=Yes,0=No. *** SET TO NO FOR PRODUCTION PROCESSING ***

	/**** Dynamic date calculation ****/
	SET @ProcessedDate=GETDATE();
	SET @Today = GETDATE();
	SET @YEAR1900 = '1900-01-01'
	SET @SchoolYear = (Select SEO_MART.dbo.fn_GetT5SchoolYear());


	--Get active waveid for this process
	DECLARE @WaveID INT,@WaveDate Date, @WaveCount INT, @WaveDesc VARCHAR(150), @CSEOnlyFlag VARCHAR(1)
	SET @WaveID=0
	SET @CSEOnlyFlag=NULL
	Select @WaveID=WaveID,@WaveDate=WaveDate,@WaveDesc=WaveDescription,@CSEOnlyFlag=CSEOnlyFlag 
	from SEO_MART.dbo.INT_T5WaveSchedule 
	Where WaveStatus='I';

	SET @EventType='T5Wave';
	SET @EventHeader=CONCAT('Wave ',CONVERT(VARCHAR,@WaveID),' Process - USPINT_T5StudentSchoolAssignmentLOAD');

	IF @WaveID=0
	BEGIN
		SET @EventMessage='Invalid Wave ID: 0, process cannot continue.'
		EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;
		RAISERROR(@EventMessage, 16, 1);	--added 1/29/2024
		RETURN;
	END;

	IF @CSEOnlyFlag='M'		--T5 manual wave assignment		- Added 5/2/2025
	BEGIN
		EXEC dbo.USPINT_T5MWAStudentSchoolAssignmentINS 'MWADBN',@WaveID
		RETURN;
	END;

	SET @EventMessage='Start of Wave: ' + Convert(varchar,@WaveID) + ' Assignment Process.'
	EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;

	IF @CSEOnlyFlag='Y'
	BEGIN
		SET @EventMessage='This Wave is CSEDBN only assignment process.'
		EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;		
	END;

	---************BEGIN: DELETE PRIOR Data from WTs (Working Tables)
		DELETE FROM RPT_T5tfDBNCapacity_WT
		DELETE FROM RPT_T5TargetStudents_WT
		DELETE FROM RPT_T5tfDBNLanguageCapacity_WT
		DELETE FROM RPT_T5Siblings_WT
		DELETE FROM RPT_T5languageRankToAssignAsMono_WT
		DELETE FROM RPT_T5newAssignments_WT
	----------------END***********************----

	/*******************************************************************************
	Clearup tables for processing
	********************************************************************************/
	Truncate Table dbo.INT_T5StudentSchoolAssignment;
	Truncate Table dbo.INT_T5StudentSchoolAssignmentNearestDBN;

	--Determine student's language using AssessmentLanguageCode and GuardianLanguageCode
	exec dbo.USPINT_T5DetermineStudentLanguage

	INSERT INTO RPT_T5languageRankToAssignAsMono_WT(
		Language,
		MonoAssignmentRank
	)
	values 
	('English', 1),
	('Spanish', 2),
	('Mandarin', 3),
	('Russian', 4),
	('Chinese(Both)', 5),
	('Haitian Creole', 6),
	('Cantonese', 7),
	('ARABIC', 8),
	('Hindi', 9),
	('Korean', 10),
	('Urdu', 11)

	--Load TargetStudents 
	INSERT INTO RPT_T5TargetStudents_WT(
		StudentID
		, HomeDistrict
		, SiblingKey
		, StudentLanguage
		, StudentLanguageCode
		, StudentLanguageCategory
		, AssignmentLanguage
		, AssignmentPriorityType
		, AssignmentPriorityTypeID
		, AssignedSchoolDBN
		, OtherSiblingAssignedSchoolDBN
		, StudentCategory
	)
	select reg.StudentID, reg.HomeDistrict, reg.SiblingKey, 
		lang.Language as StudentLanguage,
		lang.LanguageCode as StudentLanguageCode,
		lang.LanguageCategory as StudentLanguageCategory,
		case when priorSibAsg.AssignedSchoolDBN = '02M347' then 'ASL'
			when isnull(priorSibAsg.AssignedSchoolDBN, '') like '%CS%' then 'CSE'
			else cast('' as varchar(50))
		end as AssignmentLanguage,    
		prt.AssignmentPriorityType, prt.AssignmentPriorityTypeID
		, cast('' as char(6)) as AssignedSchoolDBN
		, priorSibAsg.AssignedSchoolDBN as OtherSiblingAssignedSchoolDBN 
		,prt.StudentCategory
	--select count(*)
	from SEO_MART.dbo.RPT_T5StudentRegister reg
		left join RPT_T5StudentLanguage_WT lang
			on reg.StudentID = lang.StudentID 
		inner join (select distinct StudentID, AssignmentPriorityType, AssignmentPriorityTypeID, HomeDistrict, StudentCategory
					from SEO_MART.dbo.RPT_T5StudentSchoolPriorities 
					) prt 
			on reg.StudentID = prt.StudentID
		left join (
			--If for whatever, siblings are previously assigned to more than one DBN, this picks the 1st DBN alphabetically
			select SiblingKey, T5IEPTeam as AssignedSchoolDBN, sl.Language, 
				row_number() over(partition by Siblingkey order by T5IEPTeam) as rnk 
			from SEO_MART.dbo.RPT_T5StudentAssignment a
				inner join RPT_T5StudentLanguage_WT sl on a.StudentID = sl.StudentID  
			where ActiveFlag = 'Y'
		) priorSibAsg on priorSibAsg.SiblingKey = reg.SiblingKey and priorSibAsg.rnk = 1
	where reg.IsTurning5 = 1
	and reg.WaveID is null 

	SET @EventCnt=(Select count(*) from RPT_T5TargetStudents_WT)
	SET @EventMessage=CONCAT('Wave [ ',Convert(varchar,@WaveID), ' ] eligible students total count: ',Convert(varchar,@EventCnt));
	EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;

	--This loads available capacity by DBN and by DBN-and-Language into  RPT_T5tfDBNCapacity_WT and RPT_T5tfDBNLanguageCapacity_WT
	--Source: vwRPT_T5CaseAssignmentCapacitybyDBNAndLanguage
	exec dbo.USPINT_T5LoadAvailableCapacity

	SET @EventMessage=CONCAT('Wave ',CONVERT(VARCHAR,@WaveID),' Process - execution of USPINT_T5LoadAvailableCapacity is completed.');
	EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;

	IF @WaveID=0
	BEGIN
		SET @EventMessage='Invalid Wave ID: 0, process cannot continue.'
		EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;
		RAISERROR(@EventMessage, 16, 1);	--added 1/29/2024
		RETURN;
	END;

	SET @EventCnt=(Select count(*) from RPT_T5tfDBNCapacity_WT);
	SET @EventMessage=CONCAT('Total SchoolDBN with capacity: ',CONVERT(VARCHAR(9),@EventCnt));
	EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;

	/*
	INSERT INTO RPT_T5newAssignments_WT(
		StudentID
		, AssignedSchoolDBN
		, AssignmentLanguage
		, AssignmentPriorityType
		, AssignmentPriorityTypeID
		, Notes
		, AssignedDateTime
		, DBNPriorityType
		, DBNPriorityTypeID
		, DBNPrioritySequence
		, DBNProximity
	)
	*/
	--Assign ASL (No need to reduce capacity after assignemt, since ASL has unlimited capacity
		update RPT_T5TargetStudents_WT
		set AssignedSchoolDBN = '02M347', AssignmentLanguage = 'ASL'
		output inserted.StudentID, Inserted.AssignedSchoolDBN, inserted.AssignmentLanguage, inserted.AssignmentPriorityType
			, inserted.AssignmentPriorityTypeID, 'ASL', getdate()
			,'ASLDBN' as DBNPriorityType, 4 as DBNPriorityTypeID, 1 as DBNPrioritySequence, NULL as DBNProximity 
		into RPT_T5newAssignments_WT
		--select OtherSiblingAssignedSchoolDBN, Language, count(*) as RPT_T5newAssignments_WT 
		where isnull(AssignedSchoolDBN, '') = '' 
		and AssignmentPriorityType = 'ASL' 

	SET @EventMessage=CONCAT('Wave ',CONVERT(VARCHAR,@WaveID),' Process - Assignment of ASL students is completed.');
	EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;

	IF @CSEOnlyFlag='Y'	--Added 5/20/2024
	BEGIN		
		--Assign "Everybody" to CSE - this is a 'CSEOnly' wave
			exec dbo.USPINT_T5AssisgnToCSE 'CSEOnlyWave'

			SET @EventMessage=CONCAT('Wave ',CONVERT(VARCHAR,@WaveID),' Process - CSEOnlyWave - Assignment of all students is completed.');
			EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;

	END
	ELSE
	BEGIN

		--BEGIN: Assign sibligs who have previously assigned siblings to their sibling AssignedSchoolDBN---
			declare @assignedDateTime datetime
			set @AssignedDateTime = getdate() 

			update RPT_T5TargetStudents_WT
			set AssignedSchoolDBN = OtherSiblingAssignedSchoolDBN --NOTE: AssignmentLanguage is already assigned above when loading RPT_T5TargetStudents_WT
			output inserted.StudentID, Inserted.AssignedSchoolDBN, inserted.AssignmentLanguage, inserted.AssignmentPriorityType
				, inserted.AssignmentPriorityTypeID, 'SiblingDBN w a PriorAssignment', @AssignedDateTime
				,'SIBLINGDBN' as DBNPriorityType, 5 as DBNPriorityTypeID, 1 as DBNPrioritySequence, NULL as DBNProximity 
			into RPT_T5newAssignments_WT
			--select OtherSiblingAssignedSchoolDBN, Language, count(*) as RPT_T5newAssignments_WT 
			where OtherSiblingAssignedSchoolDBN is not null

			--Determine "AssignmentLanguage" and update in RPT_T5newAssignments_WT
			exec dbo.USPINT_T5AssignmentLanguageUPD @AssignedDateTime

			--If AssignmentLanguage couldn't be determined bcz this sigbling assignment resulted in exceeded capacity, 
			--then assume capacity is 'overused' in the 1st language that the DBN has capacity .  
			update n
			set AssignmentLanguage =  isnull(l.Language, 'English')
			from RPT_T5newAssignments_WT n
				left join (
					select vw.SchoolDBN, lrnk.Language, row_number() over(partition by vw.SchooLDBN order by lrnk.MonoAssignmentRank) as rnk
					from SEO_MART.dbo.RPT_POSPsychDaysByDBNandLanguage vw  
						inner join RPT_T5languageRankToAssignAsMono_WT lrnk on vw.Language = lrnk.Language  
							and isnull(vw.D75Site, '') = '' and isnull(vw.POSPsychDays, 0) > 0
				) l
				on n.AssignedSchoolDBN = l.SchoolDBN
			where isnull(n.AssignmentLanguage, '') = '' and  n.AssignedDateTime = @AssignedDateTime  and n.DBNPriorityType = 'SIBLINGDBN'
			and isnull(n.AssignedSchoolDBN, '') <> '' and l.rnk = 1

			--Reduce these siblings assignments from available capacity  
			exec dbo.USPPROC_T5UpdateCapacityFromNewAssignments @AssignedDateTime

			SET @EventMessage=CONCAT('Wave ',CONVERT(VARCHAR,@WaveID),' Process - Assignment of Siblings with a prior assignment is completed.');
			EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;

		--END: Assign sibligs who have previously assigned siblings to their sibling AsssignedDBN---

		--Assign "SpecialPopulation" to CSE
			exec dbo.USPINT_T5AssisgnToCSE 'SpecialPopulation'

			SET @EventMessage=CONCAT('Wave ',CONVERT(VARCHAR,@WaveID),' Process - Assignment of SpecialPopulation is completed.');
			EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;


		--Assign siblings where none of the siblings are previously assigned ---
		exec dbo.USPINT_T5AssignSiblings @SchoolYear, @WaveID, @WaveDate 
		SET @EventMessage=CONCAT('Wave ',CONVERT(VARCHAR,@WaveID),' Process - Assignment of Siblings without a prior assignment is completed.');
		EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;

		----------BEGIN: Bilingual in a POS Language - Language Match in Zoned DBN and Nearest DBN
		exec dbo.USPINT_T5AssignLanguageMatchInZonedDBN
		SET @EventMessage=CONCAT('Wave ',CONVERT(VARCHAR,@WaveID),' Process - Assignment of LanguageMatches in ZonedDBN is completed.');
		EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;

		exec dbo.USPINT_T5AssignLanguageMatchInNearestDBN @SchoolYear, @WaveID, @WaveDate
		SET @EventMessage=CONCAT('Wave ',CONVERT(VARCHAR,@WaveID),' Process - Assignment of LanguageMatches in NearestDBN is completed.');
		EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;
		----------END: Bilingual In POS language - Zoned and Nearest DBN Language Match-----------*********** 

		--BEGIN: **********************Everything left - Treat as "equivalent to Monolingual"------------------------
		--Don't consider language match or bilingual capacity

			--Assign to ZonedDBN
			exec dbo.USPINT_T5AssignZonedDBN
			SET @EventMessage=CONCAT('Wave ',CONVERT(VARCHAR,@WaveID),' Process - Assignment to ZonedDBN (monolingual or treating as monolingual) is completed.');
			EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;

			--Assign to NearestDN
			exec dbo.USPINT_T5AssignNearestDBN @SchoolYear, @WaveID, @WaveDate 

			SET @EventMessage=CONCAT('Wave ',CONVERT(VARCHAR,@WaveID),' Process - Assignment to NearestDBN (monolingual or treating as monolingual) is completed.');
			EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;

			--As a LastResort, Assign to CSE   (NOTE: Students with HomeDistrict 00 also get assigned to CSE)
			exec dbo.USPINT_T5AssisgnToCSE 'LastResort'
			SET @EventMessage=CONCAT('Wave ',CONVERT(VARCHAR,@WaveID),' Process - Assignment to CSE, including alternate CSE, as a last resort is completed.');
			EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;
		--END: Everything left - Treat as "equivalent to Monolingual"**********************----------

	END --End of regular wave

	EXEC dbo.USPINT_T5UpdateNoAssignmentReason @SchoolYear, @WaveID

	--Load INT_T5StudentSchoolAssignment
	exec dbo.USPINT_T5StudentSchoolAssignmentINS @SchoolYear, @WaveID, @WaveDate
	SET @EventMessage=CONCAT('Wave ',CONVERT(VARCHAR,@WaveID),' Process - Assignments are loaded into INT_T5StudentSchoolAssignment');
	EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;


END
