USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPT5_T5CaseAssignmentCapacityTracker]    Script Date: 4/4/2026 4:39:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



/*===================================================================================================================
Object Name: dbo.USPT5_T5CaseAssignmentCapacityTracker
Date Created: 1/5/2024

Purpose:	This is to capture current View T5CaseAssignmentCapacity count before and after a process
			that can change the vwRPT_T5CaseAssignmentCapacity counts
			
Usage:		Pass parameter value of the process about to change vwRPT_T5CaseAssignmentCapacity counts
Example:	Exec USPT5_T5CaseAssignmentCapacityTracker @

Modification Details:
Author				ModifiedDate	Comments
Christopher Agwu	1/5/2024		Initial 
Christopher Agwu	3/5/2024		Add column AdminDistrict due to addition to vwRPT_T5CaseAssignmentCapacity. MIS-10749
Christopher Agwu	9/11/2024		Removed RPT_Location and source (IsBilingualPsych) from vwRPT_T5CaseAssignmentCapacity. MIS-11812
Christopher Agwu	3/19/2025		Change Capacity view to new current one and add Language to Tracker Table. MIS-12849
Christopher Agwu	3/23/2026		Added code to fix pickup of wrong wave id as before description for T5Wave tracker. MIS-15177
===================================================================================================================================*/

ALTER PROCEDURE [dbo].[USPT5_T5CaseAssignmentCapacityTracker]
(
	@TrackerTypeBeforeOrAfter Varchar(6),
	@TrackerName VARCHAR(60)
)	AS

Declare @TrackerFullName varchar(100),
@TrackerType Varchar(6),
@SchoolYear Varchar(9)

BEGIN
	
	SET NOCOUNT ON;	
	SET @SchoolYear = (Select dbo.fn_GetT5SchoolYear());
	SET @TrackerType=@TrackerTypeBeforeOrAfter;
	SET @TrackerFullName=CONCAT(@TrackerType,@TrackerName);

	If UPPER(@TrackerType) NOT IN ('BEFORE','AFTER')
	BEGIN
		RAISERROR ('Invalid tracker type entered, process cannot continue!',16,1)
		Return 0
	END;
		
	If ISNULL(TRIM(@TrackerName),'')=''
	BEGIN
		RAISERROR ('Invalid tracker name entered, process cannot continue!',16,1)
		Return 0
	END;

	If UPPER(@TrackerName)='T5WAVE'
	BEGIN		
		--commented 3/23/2026 ChrisAgwu - script displaying wrong description--
		--SET @TrackerName=(Select Top 1 CONCAT('T5Wave',CAST(F.WaveID as varchar(2))) as WaveDesc from (
		--	Select WaveID from [dbo].[INT_T5WaveSchedule] where WaveStatus='I'
		--	UNION
		--	Select MAX(WaveID) as WaveID from [dbo].[INT_T5WaveSchedule] where WaveStatus='P'
		--) F);
		------------------------------------------------------------------

		--Added 3/23/2026 ChrisAgwu - To correct Tracker description--
		 With tblWID as
		 (
			Select TOP 1 W.* from (
			Select WaveID,WaveStatus  from dbo.INT_T5WaveSchedule where WaveStatus='I'			
			UNION
			Select MAX(WaveID) as WaveID,Max(WaveStatus) as WaveStatus from dbo.INT_T5WaveSchedule where WaveStatus='P'
			) W Order by W.WaveStatus,WaveID
		 ) 
		 Select @TrackerName=CONCAT('T5Wave',CAST(WaveID as varchar(2))) from tblWID		
		 SET @TrackerFullName=CONCAT(@TrackerType,@TrackerName);
	END;

	
	--Assignment Capacity Tracker--
	INSERT INTO dbo.RPT_T5CaseAssignmentCapacityTracker
	(SchoolYear,SchoolDBN,LocationType,POSPsychDays,CSE,Capacity,CaseAssignmentCapacity,SchoolType,GeographicalDistrict,AdminDistrict,ZipCode,AssignedCapacity,	
	AvailableCapacity,Tracker,[Language])
	Select @SchoolYear as SchoolYear, C.SchoolDBN,C.LocationType,C.POSPsychDays,C.CSE,C.Capacity,C.CaseAssignmentCapacity,C.SchoolType,
	C.GeographicalDistrict,C.AdminDistrict, C.ZipCode,C.AssignedCapacity,C.AvailableCapacity,@TrackerFullName as Tracker,[Language]
	From dbo.vwRPT_T5CaseAssignmentCapacityByDBNAndLanguage C;


	--Overassignment tracker
	INSERT INTO dbo.RPT_T5OverAssignmentTracker 
	(SchoolYear,SchoolDBN,SchoolType,GeographicalDistrict,AdminDistrict,CaseAssignmentCapacity,AssignedCapacity,AvailableCapacity,OverAssignedCnt,	
	IsBilingualPsych,Tracker,[Language])

	Select G.*
	from
	(
		Select distinct
		@SchoolYear as SchoolYear
		,a.SchoolDBN
		,a.SchoolType
		,a.GeographicalDistrict
		,a.AdminDistrict
		,a.CaseAssignmentCapacity
		,a.AssignedCapacity
		, A.AvailableCapacity
		,(a.AssignedCapacity - a.CaseAssignmentCapacity) as OverAssignedCnt
		, a.IsBilingualPsych
		,@TrackerFullName as Tracker
		,[Language]
		From [SEO_MART].[dbo].vwRPT_T5CaseAssignmentCapacityByDBNAndLanguage a WITH(NOLOCK)		
		Where a.CaseAssignmentCapacity < a.AssignedCapacity
	) G
	Where G.OverAssignedCnt > 0;

END

