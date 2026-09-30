USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPINT_T5StudentSchoolAssignmentINS]    Script Date: 4/4/2026 4:19:13 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[USPINT_T5StudentSchoolAssignmentINS]
	@SchoolYear char(9), @WaveID int, @WaveDate Date
/*
Modification History:
Raji			11/20/2024				Initial Draft
Charlotte		11/22/2025				Replaced global temp tables with permanent tables prefixed with "_WT"
*/
as
BEGIN
	SET NOCOUNT ON	

	declare @Today datetime
	set @Today = getdate() 

	delete from dbo.INT_T5StudentSchoolAssignment where WaveID = @WaveID

	;WITH HomeCSE AS
	(
		SELECT
			reg.StudentID,
			prt.DBNPriority AS HomeCSE
		FROM dbo.RPT_T5TargetStudents_WT reg
		INNER JOIN SEO_MART.dbo.RPT_T5StudentSchoolPriorities prt
			ON reg.StudentID = prt.StudentID
		   AND prt.DBNPriorityType = 'CSEDBN'
		   AND prt.DBNPrioritySequence  = 1
	)	
	insert into dbo.INT_T5StudentSchoolAssignment (
	WaveID
	, WaveDate
	, StudentID
	, IsSibling
	, SiblingKey
	, StudentCategory
	, AssignmentPriorityType
	, AssignmentPriorityTypeID
	, ProcessAssignedPriorityTypeID
	, AssignedSchoolDBN
	, SchoolDBNType
	, DBNPrioritySequence
	, DBNPriorityType
	, DBNPriorityTypeID
	, DBNProximity
	, IsBilingualStudent
	, IsPOSLanguage
	, IsBilingualDBN
	, AssignmentSetting
	, DBNNoAssignmentReasons
	, ProcessedDate
	, ProcessedDateTime
	, SchoolYear
	, IsLanguageMatch
	, StudentLanguageCode
	, StudentLanguage
	, AssignmentLanguage
	, AssignmentNotes
	)

	select @WaveID as WaveID, @WaveDate as WaveDate, n.StudentID, 
		case when sb.SiblingKey is not null then 1 else 0 end as IsSibling, 
		ts.SiblingKey, 
		ts.StudentCategory, 
		ts.AssignmentPriorityType, ts
		.AssignmentPriorityTypeID, 
		0 as ProcessAssignedPriorityTypeID,
		n.AssignedSchoolDBN as AssignedSchoolDBN,
		dbn.SchoolType as 'SchoolDBNType',
		n.DBNPrioritySequence,
		n.DBNPriorityType, 
		n.DBNPriorityTypeID,
		n.DBNProximity,
		case when ts.StudentLanguageCategory in ('POS', 'NonPOS') then 1 else 0 end as 'IsBilingualStudent',
		case when ts.StudentLanguageCategory = 'POS' then 1 else 0 end IsPOSLanguage,
		null as IsBilingualDBN, 
		case when ts.AssignedSchoolDBN = '02M347' then 'DOE' 
			when ts.AssignmentPriorityType = 'SpecialPopulation' then 'CSE' 
			else 'DOECSE' 
		end as AssignmentSetting, 
		CASE 
			  WHEN (ts.AssignmentPriorityTypeID = 1 AND n.DBNPriorityType <> 'ASLDBN')
				OR (ts.AssignmentPriorityTypeID = 2 AND ISNULL(n.AssignedSchoolDBN,'') <> ISNULL(hc.HomeCSE,''))
				OR (ts.AssignmentPriorityTypeID > 2 AND n.DBNPriorityType NOT LIKE '%ZONEDBN%')
			  THEN ts.DBNNoAssignmentReasons
			  ELSE NULL
		END AS DBNNoAssignmentReasons,
		cast(getdate() as date) as ProcessedDate,
		n.AssignedDateTime as ProcessedDateTime, 
		@SchoolYear 
		, case when isnull(n.DBNPriorityType, '') like '%lngMatch%' then 1 else 0 end as IsLanguageMatch
		,ts.StudentLanguageCode
		,ts.StudentLanguage
		, case when n.AssignmentLanguage = 'CSE' then ts.StudentLanguage 
			when n.AssignedSchooLDBN = '02M347' then 'ASL' 
			else  n.AssignmentLanguage end  as AssignmentLanguage
		, n.Notes
	from RPT_T5newAssignments_WT n
		inner join RPT_T5TargetStudents_WT ts on n.StudentID = ts.StudentID 
		LEFT JOIN HomeCSE hc ON hc.StudentID = ts.StudentID
		left join RPT_T5Siblings_WT sb on sb.SiblingKey = ts.SiblingKey 
		left join SEO_MART.dbo.RPT_T5StudentRegister reg on ts.StudentID = reg.StudentID 
		left join RPT_T5tfDBNCapacity_WT dbn on n.AssignedSchoolDBN = dbn.SchoolDBN 


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

	INSERT INTO arch.INT_T5StudentSchoolAssignmentNearestDBN
	(
		WaveID,
		WaveDate,
		StudentID,	
		IsSibling,
		SiblingKey,
		StudentCategory,
		IsBilingualStudent,
		HomeDistrict,
		Latitude,
		Longitude,
		SchoolDBN,
		IsBilingualDBN,
		AvailableCapacity,
		IsAvailableCap,
		DBNProximity,
		ProcessedDate,
		ProcessedDateTime,
		ArchiveDate,
		SchoolYear,
		IsLanguageMatch,
		StudentLanguageCode,
		StudentLanguage,
		AssignmentLanguage,
		Notes
	)
	Select 
		WaveID,
		WaveDate,
		StudentID,	
		IsSibling,
		SiblingKey,
		StudentCategory,
		IsBilingualStudent,
		HomeDistrict,
		Latitude,
		Longitude,
		SchoolDBN,
		IsBilingualDBN,
		AvailableCapacity,
		IsAvailableCap,
		DBNProximity,
		ProcessedDate,
		ProcessedDateTime,
		@Today as ArchiveDate,
		SchoolYear,
		IsLanguageMatch,
		StudentLanguageCode,
		StudentLanguage,
		AssignmentLanguage,
		Notes
	From dbo.INT_T5StudentSchoolAssignmentNearestDBN;

END
