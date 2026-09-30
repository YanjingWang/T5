USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPINT_T5DOBChangeUPD]    Script Date: 4/4/2026 1:47:13 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[USPINT_T5DOBChangeUPD]
AS
BEGIN
	SET NOCOUNT ON;

/**************************************************************************************************************************************************
Object Name: dbo.USPINT_T5DOBChangeUPD
Sample call: Exec USPINT_T5DOBChangeUPD
Purpose: This process compares RPT_T5SR DOB to SourceExtract and ATS DOB YEAR, if missing in CAP and RPT_T5SR.DOB is different from ATS.DOB then
ATS.DOB will replace RPT_T5SR.DOB.

Date Created: 09/28/2023

Modification Details:
Author					ModifiedDate		Comments
Christopher Agwu		9/28/2023			Initial
Christopher Agwu		1/9/2025			Change source data from DWH_T5CAPExtract to DWH_T5SourceExtract (MIS-12577)
***************************************************************************************************************************************************/

	Declare  @TodayDate datetime, @BirthYear Int, @NewEntry Bit, @ModifiedReasons Varchar(100)
	Declare @RecCount INT


	SET @BirthYear=dbo.fn_GetT5BirthYear();	
	SET @TodayDate=getdate();
	SET @ModifiedReasons='DOBChange - Student dropped from T5SourceExtract';


	--compare DOB--
	SELECT DISTINCT a.StudentID, a.LastName,a.FirstName,a.SchoolYear,a.IsTurning5, a.BirthDate as T5SRBirthDate,b.SchoolYear as ATSSchoolYear, 
	c.BirthDate as CAPBirthDate, cast(b.BirthDate as date) as ATSBirthDate, cast(b.BirthDate as date) as NewT5SRBirthDate, 1 as IsNewEntry,
	Cast(@TodayDate as Date) as ProcessedDate,@TodayDate as ProcessedDateTime
	INTO #tblDOBDiff
	FROM SEO_MART.dbo.RPT_T5StudentRegister a with(nolock)
	LEFT JOIN SEO_MART.dbo.DWH_ATSStudents b with(nolock)
	ON a.StudentID=b.StudentID
	AND a.SchoolYear=b.SchoolYear
	LEFT JOIN SEO_MART.dbo.DWH_T5SourceExtract c
	ON a.StudentID=c.StudentID
	AND a.SchoolYear=c.SchoolYear
	WHERE
	a.birthdate<>b.birthdate	
	and YEAR(a.BirthDate)=@BirthYear 
	and a.IsTurning5=1
	and c.StudentID is null; --Student is dropped from SourceExtract

	SET @RecCount=(Select count(*) From #tblDOBDiff);
	
	--Set old records to zero
	if @RecCount>0
	BEGIN
		UPDATE dbo.DWH_T5DOBChange
		SET IsNewEntry=0
		Where IsNewEntry=1;	


		--Insert into history table--
		SET @NewEntry=1;
		INSERT INTO dbo.DWH_T5DOBChange
		(StudentID,	LastName,FirstName,SchoolYear,IsTurning5,T5SRBirthDate,CAPBirthDate,ATSBirthDate,NewT5SRBirthDate,NewIsTurning5, IsNewEntry,ProcessedDate,ProcessedDateTime)
		Select StudentID,LastName,FirstName,SchoolYear,IsTurning5,T5SRBirthDate,CAPBirthDate,ATSBirthDate,ATSBirthDate,
		CASE WHEN YEAR(ATSBirthDate) <> YEAR(T5SRBirthDate) THEN 0 ELSE 1 END as NewIsTurning5,@NewEntry as IsNewEntry,ProcessedDate,ProcessedDateTime
		From #tblDOBDiff;


		--Update T5SR Student DOB---------
		UPDATE dst
		SET dst.BirthDate=scr.NewT5SRBirthDate,
		dst.IsTurning5=scr.NewIsTurning5,
		dst.ModifiedDate=@TodayDate,
		dst.ModifiedReasons=@ModifiedReasons
		FROM SEO_MART.dbo.RPT_T5StudentRegister dst
		INNER JOIN (Select StudentID,NewT5SRBirthDate,NewIsTurning5 From SEO_MART.dbo.DWH_T5DOBChange Where IsNewEntry=@NewEntry) scr
		ON dst.StudentID = scr.StudentID;	

	
		--update T5SA Student DOB and reclaim capacity--
		UPDATE dst
		SET dst.BirthDate=scr.NewT5SRBirthDate,
		dst.IsTurning5=scr.NewIsTurning5,
		dst.ActiveFlag='N',
		dst.ModifiedDate=@TodayDate,
		dst.ModifiedReasons=@ModifiedReasons
		From SEO_MART.dbo.RPT_T5StudentAssignment dst
		INNER JOIN (Select StudentID,NewT5SRBirthDate,NewIsTurning5 From SEO_MART.dbo.DWH_T5DOBChange Where IsNewEntry=@NewEntry) scr
		ON scr.StudentID=dst.StudentID;
	END;
END

