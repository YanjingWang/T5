USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPINT_T5MWAStudentSchoolAssignmentINS]    Script Date: 4/4/2026 3:57:06 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[USPINT_T5MWAStudentSchoolAssignmentINS]
(
	@WaveAssignmentType Varchar(10), --MWADBN
	@WaveID INT		
)
/**********************************************************************************************************************************************************************************************************
Object Name: USPINT_T5MWAStudentSchoolAssignmentINS
Sample call: USPINT_T5MWAStudentSchoolAssignmentINS
Purpose: Insert manual wave assignment to INT_T5StudentSchoolAssignment table.
Date Created: 5/02/2025

Modification Details:
Author				ModifiedDate	Comments
Christopher Agwu	05/02/2025		Initial
**********************************************************************************************************************************************************************************************************/

AS 
BEGIN
	Set Nocount on

	DECLARE @Today DATETIME;	
	DECLARE @SchoolYear VARCHAR(10);
	DECLARE @ProcessedDate DATE;
	DECLARE @EventCnt INT
	DECLARE @EventHeader VARCHAR(150), @EventType VARCHAR(50);
	DECLARE @EventMessage VARCHAR(1500); 
	
	
	/**** Dynamic date calculation ****/
	SET @Today = GETDATE();	
	SET @ProcessedDate=GETDATE();	
	SET @SchoolYear = (Select SEO_MART.dbo.fn_GetT5SchoolYear());

	SET @EventType='T5Wave';
	SET @EventHeader=CONCAT('Wave ',CONVERT(VARCHAR,@WaveID),' Process - USPINT_T5MWAStudentSchoolAssignmentINS');

	--Check caller is manual wave
	IF @WaveAssignmentType!='MWADBN'
	BEGIN
		SET @EventMessage='Invalid Wave assignment type, manual wave process cannot continue.'
		EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;
		RAISERROR(@EventMessage, 16, 1);	
		RETURN;
	END;
		
	SET @EventMessage='Start of Wave: ' + Convert(varchar,@WaveID) + ' Manual Wave Assignment Process.'
	EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;


	/*******************************************************************************
	Clearup destination tables for processing
	********************************************************************************/
	Truncate Table dbo.INT_T5StudentSchoolAssignment;
	Truncate Table dbo.INT_T5StudentSchoolAssignmentNearestDBN;
	
	--Do Insert--
	INSERT INTO dbo.INT_T5StudentSchoolAssignment
	(
		WaveID,WaveDate,StudentID,IsSibling,SiblingKey,StudentCategory,AssignmentPriorityType,AssignmentPriorityTypeID,ProcessAssignedPriorityTypeID,
		AssignedSchoolDBN,SchoolDBNType,DBNPrioritySequence,DBNPriorityType,DBNPriorityTypeID,DBNProximity,IsBilingualStudent,IsPOSLanguage,IsBilingualDBN,
		AssignmentSetting,DBNNoAssignmentReasons,ProcessedDate,ProcessedDateTime,SchoolYear,IsLanguageMatch,StudentLanguageCode,StudentLanguage,AssignmentLanguage,
		AssignmentNotes
	)
	Select P.WaveID,P.WaveDate,P.StudentID,P.IsSibling,P.SiblingKey,P.StudentCategory,P.AssignmentPriorityType,P.AssignmentPriorityTypeID, 
	P.AssignmentPriorityTypeID as ProcessAssignedPriorityTypeID,
	P.DBNPriority AS AssignedSchoolDBN,
	CASE WHEN P.DBNPriority LIKE '%CS%' THEN 'CSE' ELSE 'ZONED' END AS SchoolDBNType,
	P.DBNPrioritySequence,P.DBNPriorityType,P.DBNPriorityTypeID,P.DBNProximity,P.IsBilingualStudent,P.IsPOSLanguage,
	P.IsBilingualDBN,P.AssignmentSetting, NULL as DBNNoAssignmentReasons,@ProcessedDate as ProcessedDate,@Today as ProcessedDateTime,P.SchoolYear,0 as IsLanguageMatch,
	ISNULL(R.AssessmentBilLangCode,R.GuardianLanguage) as StudentLanguageCode,
	LC.LanguageDesc as StudentLanguage,
	dbo.fn_GetReassignedDBNLangCodeCP(ISNULL(R.AssessmentBilLangCode,R.GuardianLanguage), P.DBNPriority) as AssignmentLanguage,
	'Manual Wave Assignment process' as AssignmentNotes
	From dbo.RPT_T5StudentSchoolPriorities P 
	INNER JOIN dbo.RPT_T5StudentRegister R
	ON R.StudentID=P.StudentID
	LEFT JOIN dbo.vwlk_T5LanguageCodes LC
	ON LC.LanguageCode=ISNULL(R.AssessmentBilLangCode,R.GuardianLanguage)
	where P.DBNPriorityTypeID=5;

	SET @EventCnt=(Select count(*) From dbo.INT_T5StudentSchoolAssignment);
	SET @EventMessage=CONCAT('INT_T5SSA insert completed. ', CONVERT(VARCHAR,@EventCnt),' students affected!');
	EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;

	--Archive data--
	INSERT INTO arch.INT_T5StudentSchoolAssignment
    (
		WaveID,
		WaveDate,
		StudentID,
		IsSibling,
		SiblingKey,
		StudentCategory,
		AssignmentPriorityType,
		AssignmentPriorityTypeID,
		ProcessAssignedPriorityTypeID,		
		AssignedSchoolDBN,
		SchoolDBNType,
		DBNPrioritySequence,
		DBNPriorityType,
		DBNPriorityTypeID,
		DBNProximity,
		AssignmentSetting,
		IsBilingualStudent,
		IsPOSLanguage,
		IsBilingualDBN,
		DBNNoAssignmentReasons,
		ProcessedDate,
		ProcessedDateTime,
		ArchiveDate,
		SchoolYear,
		IsLanguageMatch,
		StudentLanguageCode,
		StudentLanguage,
		AssignmentLanguage,
		AssignmentNotes
	)
	SELECT  
	  	WaveID,
		WaveDate,
		StudentID,
		IsSibling,
		SiblingKey,
		StudentCategory,
		AssignmentPriorityType,
		AssignmentPriorityTypeID,
		ProcessAssignedPriorityTypeID,	
		AssignedSchoolDBN,
		SchoolDBNType,
		DBNPrioritySequence,
		DBNPriorityType,
		DBNPriorityTypeID,
		DBNProximity,
		AssignmentSetting,
		IsBilingualStudent,
		IsPOSLanguage,
		IsBilingualDBN,
		DBNNoAssignmentReasons,
		ProcessedDate,
		ProcessedDateTime,
	    @Today as ArchiveDate,
		SchoolYear,
		IsLanguageMatch,
		StudentLanguageCode,
		StudentLanguage,
		AssignmentLanguage,
		AssignmentNotes
  FROM dbo.INT_T5StudentSchoolAssignment;


END
