USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPRPT_T5WaveIneligibleStudents]    Script Date: 4/4/2026 1:59:05 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[USPRPT_T5WaveIneligibleStudents]
/****************************************************************************************************************************************************************
Object Name: dbo.USPRPT_T5WaveIneligibleStudents
Sample call: EXEC USPRPT_T5WaveIneligibleStudents;
Purpose: It is used to populate RPT_T5WaveIneligibleStudents table
        This is based on RPT_T5StudentRegister.IsTurning5 = 0 and DWH_T5SourceKIPDataErrors
Date Created: 12/15/2025

Modification Details:

Author			ModifiedDate		Comments
Raji            12/15/2025          Initial Draft. 
                                    Load Ineligible students for KIPWave assignment and log reason for ineligibility
Charlotte       02/23/2026          Add SESIS ineligibility 
***************************************************************************************************************************************************************************************/
AS
BEGIN
	SET NOCOUNT ON

    DECLARE @SchoolYear VARCHAR(9), 
            @BirthYear INT,
            @WaveID int,
            @ETLProcessedDatetime datetime

    Select top 1 @SchoolYear = LookupValue from dbo.lk_SEOBusinessRules 
    where LookupCategory='T5Wave' 
    and LookupName = 'T5SchoolYear'
    
    Select @BirthYear = LookupValue from dbo.lk_SEOBusinessRules 
    where LookupCategory='T5Wave' 
    and LookupName = 'T5BirthDate'

    select  @WaveID = min(WaveID) from INT_T5WaveSchedule  
    where (WaveStatus = 'E' and WaveEligRunDate = cast(getdate() as date))
    or WaveStatus = 'I'

    set @ETLProcessedDatetime = getdate()

    IF OBJECT_ID('tempdb..#ATS') IS NOT NULL
        DROP TABLE #ATS;

    SELECT StudentID,
            SchoolDBN,
            GradeLevel
    into #ATS
    FROM SEO_MART.dbo.INT_ATSStudents WITH (NOLOCK)
    WHERE [Status] = 'A'

    /*New - Added 2/20/26 for SESIS ineligible*/
    IF OBJECT_ID('tempdb..#DWHReferral') IS NOT NULL
        DROP TABLE #DWHReferral;

	Select t.* INTO #DWHReferral From (
		Select StudentID, ReferralDate,Deleted,DocStatus,IsDelete,ReferralSchoolYear,DocumentIDT,
		    ROW_NUMBER() OVER(Partition by StudentID Order by DocumentIDT DESC) RefNum
		From SEO_MART.dbo.DWH_Referral 
        Where ReferralTypeCode=1 
		AND Deleted=0 AND IsDelete=0
        AND ReferralSchoolYear=@SchoolYear
	) t 
    Where t.RefNum=1 


    /*NEW - 02/18/26
      - Prevent repeatedly logging the same ineligible students every wave: insert only "new" (SchoolYear+StudentID+Reason+Source) rows
      - SESIS/CCS logic: do NOT depend on reg.IsTurning5 (register is refreshed earlier in sequence). Use SESIS source row (s.*) instead.
      - Add IsActive=0 as the first reason category/desc for SESIS (inactivated in SESIS/CCS).
    */
    create table #IneligibleStudents(
        SchoolYear	char(9),
        WaveID	int,
        StudentID	int,
        ReasonCategory	varchar(100),
        ReasonDesc	varchar(4000),
        T5RecordSource	varchar(100),
        ETLProcessedDate	date,
        ETLProcessedDateTime	datetime
    )

    insert into #IneligibleStudents(
        SchoolYear
        , WaveID
        , StudentID
        , ReasonCategory
        , ReasonDesc
        , T5RecordSource
        , ETLProcessedDate
        , ETLProcessedDateTime
    )    
    select distinct
        @SchoolYear as SchoolYear,
        @WaveID as WaveID, 
        s.StudentID,
        'IsTurning5 not 1' as 'ReasonCategory',
        case when YEAR(s.BirthDate) <> @BirthYear then concat('YOB ', YEAR(s.BirthDate), ' Not KIP YOB')
                when ats.GradeLevel = '0K' and ats.SchoolDBN like '84%' then 'KG in a charter school in ATS'
                when isnull(s.PreviousClassificationCode, '') not in ('PD', 'LD') 
                then 'Not PD'
                when isnull(s.RecommendedProgram, '') = 'NH' then 'RecommProgram: Not Handicapped'
                when isnull(s.RecommendedProgram, '') = 'RC' then 'RecommProgram: Parent Revocation of Consent'
                when isnull(RecommendedProgram, '') = 'GE' then 'RecommProgram: General Education'
                when s.CAPDischargeCode = 11 or s.CaseCloseReasonCode = 65 then 'Discharge/CaseCloseRsn: Moved or Transferred from NYC'
                when s.CAPDischargeCode = 15 or s.CaseCloseReasonCode = 15 then 'Discharge/CaseCloseRsn: Deceased'
                when s.BoroughCode = 'Y' or s.BoroughCode = 'Z' then 'Borough(Y/Z): Student Lives Outside of NYC'
                when ex.StudentID is null then 'Not in DWH_T5SourceExtract'
            else '' 
        end as 'ReasonDesc',
        s.T5RecordSource,
        CAST(@ETLProcessedDatetime as date) as ETLProcessedDate,
        @ETLProcessedDatetime
    from RPT_T5StudentRegister s 
        left join #ATS ats on s.StudentID = ats.StudentID
        left join DWH_T5SourceExtract ex on s.StudentID = ex.StudentID
    where isnull(s.IsTurning5, 0) <> 1
    and isnull(s.T5RecordSource, '') <> 'SESIS'
    and s.WaveID is null

    union all

    select 
        @SchoolYear as SchoolYear,
        @WaveID as WaveID, 
        StudentID, 
        'ATLASErrorFile' as 'ReasonCategory',
        error_out_info as  'ReasonDesc',
        'ATLAS' as T5RecordSource,
        CAST(@ETLProcessedDatetime as date) as ETLProcessedDate,
        @ETLProcessedDatetime 
    From DWH_T5SourceKIPDataErrors
    where StudentID not in (select StudentID from RPT_T5StudentRegister) 
    and isnull(PreviousClassificationCode, '') in ('PD', 'LD')
    and YEAR(BirthDate) = @BirthYear

    /*New - Added 2/20/26 for SESIS Ineligible*/
    --SESIS ineligible students in reg
    insert into #IneligibleStudents(
        SchoolYear
        , WaveID
        , StudentID
        , ReasonCategory
        , ReasonDesc
        , T5RecordSource
        , ETLProcessedDate
        , ETLProcessedDateTime
    )    
    SELECT
            @SchoolYear as SchoolYear
            ,@WaveID as WaveID
            ,s.StudentID
		    /*NEW - 02/18/26: reason logic based on SESIS source row (s.*), not reg.IsTurning5; IsActive=0 is the first reason */
		    ,Case when s.IsActive=0 THEN 'Inactive in SESIS'
			        when s.IsTurning5=0 THEN 'IsTurning5 not 1'
			        when s.IsTurning5=1 and ref.DocStatus<>3 THEN 'Referral not finalized'
			        ELSE NULL
			        END  'ReasonCategory'
		    ,Case when s.IsActive=0 THEN 'Student inactivated in SESIS'
			        when s.IsTurning5=0 AND ref.DocStatus=3 THEN 'SESIS T5 checkbox not checked'
			        when s.IsTurning5=0 and ref.DocStatus<>3 THEN 'SESIS T5 checkbox not checked + referral not finalized'
			        when s.IsTurning5=1 and ref.DocStatus<>3 THEN 'SESIS Referral not finalized'
			        ELSE NULL
			        END  'ReasonDesc'
		    ,reg.T5RecordSource
		    ,CAST(@ETLProcessedDatetime as date) as ETLProcessedDate
            ,@ETLProcessedDatetime ETLProcessedDateTime
    FROM 
	    (
	    select 
		    StudentID
		    , IsTurning5
		    , IsActive --NEW - 02/18/26: include IsActive so we can log inactive students
	    from seo_mart.dbo.DWH_SESISstudents s with(nolock) 
	    WHERE IsDelete=0
	    --AND IsActive=1  --NEW - 02/18/26: removed to allow logging IsActive=0 students
	    AND YEAR(BirthDate)=@BirthYear
	    AND SchoolYear=@SchoolYear
	    )s
    JOIN SEO_MART.dbo.RPT_T5StudentRegister reg
	    ON reg.studentid=s.studentID
    JOIN #DWHReferral ref
        ON ref.StudentID =s.StudentID
    WHERE T5RecordSource='SESIS'
    AND reg.WaveID IS NULL --NEW - 02/18/26: align with ATLAS in-reg filter (only students not already wave-tagged)
    and s.StudentID not in (select StudentID from #IneligibleStudents 
                    where isnull(WaveID, 0) = isnull(@WaveID, 0))


    --SESIS Students not in reg
    insert into #IneligibleStudents(
        SchoolYear
        , WaveID
        , StudentID
        , ReasonCategory
        , ReasonDesc
        , T5RecordSource
        , ETLProcessedDate
        , ETLProcessedDateTime
    )    
    SELECT 
            @SchoolYear as SchoolYear
            ,@WaveID as WaveID
            ,s.StudentID
		    /*NEW - 02/18/26: reason logic based on SESIS source row (s.*), not reg.IsTurning5; IsActive=0 is the first reason */
		    ,Case when s.IsActive=0 THEN 'Inactive in SESIS'
			        when s.IsTurning5=0 THEN 'IsTurning5 not 1'
			        when s.IsTurning5=1 and ref.DocStatus<>3 THEN 'Referral not finalized'
			        ELSE NULL
			        END  'ReasonCategory'
            ,Case when s.IsActive=0 THEN 'Student inactivated in SESIS'
			        when s.IsTurning5=0 AND ref.DocStatus=3 THEN 'SESIS T5 checkbox not checked'
			        when s.IsTurning5=0 and ref.DocStatus<>3 THEN 'SESIS T5 checkbox not checked + referral not finalized'
			        when s.IsTurning5=1 and ref.DocStatus<>3 THEN 'SESIS Referral not finalized'
			        ELSE NULL
			        END  'ReasonDesc'
		    ,'SESIS' T5RecordSource
		    ,CAST(@ETLProcessedDatetime as date) as ETLProcessedDate
            ,@ETLProcessedDatetime ETLProcessedDateTime
    FROM 
	    (
	    select 
		    StudentID
		    , IsTurning5
		    , IsActive --NEW - 02/18/26: include IsActive so we can log inactive students
	    from seo_mart.dbo.dwh_SESISstudents s with(nolock) 
	    WHERE IsDelete=0
	    --AND IsActive=1  --NEW - 02/18/26: removed to allow logging IsActive=0 students
	    AND YEAR(BirthDate)=@BirthYear
	    AND SchoolYear=@SchoolYear
	    )s
    LEFT JOIN SEO_MART.dbo.RPT_T5StudentRegister reg
	    ON reg.studentid=s.studentID
    JOIN #DWHReferral ref
        ON ref.StudentID =s.StudentID
    WHERE reg.StudentID is NULL --student in SESIS and DWH_Referral but not reg
    and s.StudentID not in (select StudentID from #IneligibleStudents 
                    where isnull(WaveID, 0) = isnull(@WaveID, 0))

    INSERT INTO RPT_T5WaveIneligibleStudents(
        SchoolYear
        , WaveID
        , StudentID
        , ReasonCategory
        , ReasonDesc
        , T5RecordSource --Added 02/20/26
        , ETLProcessedDate
        , ETLProcessedDateTime
    )
    SELECT
        i.SchoolYear
        ,i.WaveID
        ,i.StudentID
        ,i.ReasonCategory
        ,i.ReasonDesc
        ,i.T5RecordSource
        ,i.ETLProcessedDate
        ,i.ETLProcessedDateTime
    FROM #IneligibleStudents i
    --WHERE i.ReasonCategory IS NOT NULL
      --/*NEW - 02/18/26: avoid repeated logging each wave; only insert "new" rows for the SchoolYear */
      --AND NOT EXISTS
      --(
      --    SELECT 1
      --    FROM dbo.RPT_T5WaveIneligibleStudents x WITH (NOLOCK)
      --    WHERE x.SchoolYear = i.SchoolYear
      --      AND x.StudentID = i.StudentID
      --      AND ISNULL(x.ReasonCategory,'') = ISNULL(i.ReasonCategory,'')
      --      AND ISNULL(x.ReasonDesc,'') = ISNULL(i.ReasonDesc,'')
      --      AND ISNULL(x.T5RecordSource,'') = ISNULL(i.T5RecordSource,'')
      --);

END
