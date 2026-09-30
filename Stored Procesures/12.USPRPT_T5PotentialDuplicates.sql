USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPRPT_T5PotentialDuplicates]    Script Date: 4/4/2026 1:48:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[USPRPT_T5PotentialDuplicates]
/******************************************************************************************************************************************************************************
Object Name: dbo.USPRPT_T5PotentialDuplicates
Sample call: Exec USPRPT_T5PotentialDuplicates
Purpose: It is used to identify potential duplicate suplicates in T5 Source Extract and 
	load into T5WaveOutput_PotentialDuplicates DB 
	This is made available to the T5 business team (Andrea, Brigid) via a view in SEO_T5 on top of this SEOMART table
Criteria for duplicate flag:
	1. More than one StudentID with the same LastName, FirstName and BirthDate 
	2. More then one record for the same StudentID 
Date Created: 10/15/2025

ModificatiON Details:

Author		ModifiedDate		Comments
Charlotte	10/15/2025			Initial Draft
*****************************************************************************************************************************************************************************/
AS
BEGIN
    SET NOCOUNT ON;

	declare @ETLProcessedDate date, @ETLProcessedDateTime datetime
	set @ETLProcessedDateTime = getdate() 
	set @ETLProcessedDate = cast(@ETLProcessedDateTime as date) 

	--NOTE: Do not delete records from this table. 
	--During every run, just append. ETLProcessedDate can be used to know current vs prior records
	--delete from SEO_T5.dbo.T5WaveOutput_PotentialDuplicates

	

	INSERT INTO SEO_MART.dbo.RPT_T5PotentialDuplicates(
		StudentID
		, LastName
		, FirstName
		, BirthDate
		, Gender
		, GuardianLastName
		, GuardianFirstName
		, GuardianPhoneNumber
		, HouseNumber
		, Street
		, BoroughCode
		, ZipCode
		, ApartmentNumber
		, CityName
		, CaseCloseReasonCode
		, CaseCloseDate
		, CaseCloseDesc
		, CAPDischargeCode
		, CAPDischargeDate
		, SchoolYear
		, ETLProcessedDate
		, ETLProcessedDateTime
	)
	--More than one StudentID for the same FirstName, LastName and BirthDate
    SELECT StudentID, LastName, FirstName, BirthDate, Gender,
           GuardianLastName, GuardianFirstName, GuardianPhoneNumber,
           HouseNumber, Street, BoroughCode, ZipCode, ApartmentNumber,
           CityName, CaseCloseReasonCode, CaseCloseDate, CaseCloseDesc,
           CAPDischargeCode, CAPDischargeDate, SchoolYear, @ETLProcessedDate, @ETLProcessedDateTime
    FROM SEO_MART.dbo.DWH_T5SourceExtract e
	where exists(select 1 from SEO_MART.dbo.DWH_T5SourceExtract e1
					where e.FirstName = e1.FirstName
					and e.LastName = e1.LastName
					and e.BirthDate = e1.BirthDate
					and e.StudentID <> e1.StudentID) 
	UNION
	--More than one record per StudentID
	SELECT StudentID, LastName, FirstName, BirthDate, Gender,
           GuardianLastName, GuardianFirstName, GuardianPhoneNumber,
           HouseNumber, Street, BoroughCode, ZipCode, ApartmentNumber,
           CityName, CaseCloseReasonCode, CaseCloseDate, CaseCloseDesc,
           CAPDischargeCode, CAPDischargeDate, SchoolYear, @ETLProcessedDate, @ETLProcessedDateTime
    FROM SEO_MART.dbo.DWH_T5SourceExtract (nolock)
    WHERE StudentID IN (
            SELECT StudentID from SEO_MART.dbo.DWH_T5SourceExtract (nolock)
            GROUP BY StudentID HAVING COUNT(*) > 1) 

	--No need to archive since dbo contains all the data for the current T5 school year
	--INSERT INTO SEO_T5.arch.T5WaveOutput_PotentialDuplicates(
	--	StudentID
	--	, LastName
	--	, FirstName
	--	, BirthDate
	--	, Gender
	--	, GuardianLastName
	--	, GuardianFirstName
	--	, GuardianPhoneNumber
	--	, HouseNumber
	--	, Street
	--	, BoroughCode
	--	, ZipCode
	--	, ApartmentNumber
	--	, CityName
	--	, CaseCloseReasonCode
	--	, CaseCloseDate
	--	, CaseCloseDesc
	--	, CAPDischargeCode
	--	, CAPDischargeDate
	--	, SchoolYear
	--	, ETLProcessedDate
	--	, ETLProcessedDateTime
	--	, ArchivedDateTime
	--)
	--select *, @ETLProcessedDateTime as ArchivedDateTime
	--from SEO_T5.dbo.T5Wave_PotentialDuplicates

END
