USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPINT_T5StudentZoneSchoolWrapper]    Script Date: 4/4/2026 2:05:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[USPINT_T5StudentZoneSchoolWrapper] 
	@ProcessOutcome varchar(10) OUTPUT
/***********************************************************************
Object name: USPINT_T5StudentSchoolZoning
Purpose:	load DWH_T5StudentSchoolZoning and INT_T5StudentZoneSchool tables based on LCGMS data
	This proc is called after the LCGMS zoning file has been validated and no errors are found.
	It is called by the same SSIS package that loads the LCGMS files into SEOMart.
	This proc calls nested stored procs and logs their status 

Sample call:	
declare @ProcessOutcome varchar(10)
exec dbo.USPINT_T5StudentZoneSchoolWrapper @ProcessOutcome OUTPUT
select @ProcessOutcome

Modification Details:
Author		ModifiedDate	Comments
--------	------------	--------
Raji		11/14/2025		Initial Draft
************************************************************************/
AS
BEGIN
	SET NOCOUNT ON

	Declare 
		  @ProcessStatus CHAR(1)
		, @ProcessType varchar(30)
		, @ProcessCatID INT = 0
		, @ProcessMessage VARCHAR(300)
		, @ProcessHeader VARCHAR(100)
		, @DWH_ETL_Outcome varchar(10) --It decides if we load INT or NOT
		, @ErrorMessage varchar(4000)
	SET @ProcessOutcome = ''
	SET @ProcessType = 'T5-Zoning frm LCGMS'

	--Log beginning of this stored proc
	SET @ProcessStatus = 'I'
	SET @ProcessHeader = 'USPINT_T5StudentZoneSchoolWrapper'
	SET @ProcessMessage= 'Wrapper Proc - In Progress'
	Exec dbo.USPLOG_SEOProcessLog @ProcessCatID, @ProcessStatus, 0, @ProcessType, @ProcessHeader, @ProcessMessage

	--Append Staging.DWH_T5StudentInvalidAddressFromLCGMS to dbo.DWH_T5StudentInvalidAddressFromLCGMS
	SET @ProcessHeader = 'USPDWH_T5StudentSchoolZoningInvalidAddress'
	BEGIN TRY
		--Log 'BEG'
			SET @ProcessStatus = 'I';
			SET @ProcessMessage = 'Copy from Staging to dbo - Started';
			Exec dbo.USPLOG_SEOProcessLog @ProcessCatID, @ProcessStatus, 0, @ProcessType, @ProcessHeader, @ProcessMessage

		--Execute real prc
			declare @rowCountVal int = 0
			exec dbo.USPDWH_T5StudentSchoolZoningInvalidAddress @rowCount = @rowCountVal OUTPUT

		--Log 'PASS'
			SET @ProcessStatus = 'P'
			SET @ProcessMessage= 'Copy from Staging to dbo - Successful'
			Exec dbo.USPLOG_SEOProcessLog @ProcessCatID, @ProcessStatus, @rowCountVal, @ProcessType, @ProcessHeader, @ProcessMessage
	END TRY
	BEGIN CATCH
			set @ProcessOutcome = 'FAIL'
			set @ErrorMessage = ERROR_MESSAGE()
			set @ErrorMessage = case when len(@ErrorMessage) > 200 then left(@ErrorMessage, 200) else @ErrorMessage end
		--Log 'FAIL'
			SET @ProcessStatus = 'F'
			SET @ProcessMessage = 'Copy from Staging to dbo - Failed' + ' - ' + @ErrorMessage
			Exec dbo.USPLOG_SEOProcessLog @ProcessCatID, @ProcessStatus, 0, @ProcessType, @ProcessHeader, @ProcessMessage
	END CATCH

	--Build dbo.DWH_T5StudentSchoolZoning using Staging.DWH_T5StudentZoningFromLCGMS and lk_T5KZoneSchoolCrosswalk 
	SET @ProcessHeader = 'USPDWH_T5StudentSchoolZoning';
	BEGIN TRY
		--Log 'BEG'
			SET @ProcessStatus = 'I';
			SET @ProcessMessage = 'ETL to load DWH_T5StudentSchoolZoning - Started';
			Exec dbo.USPLOG_SEOProcessLog @ProcessCatID, @ProcessStatus, 0, @ProcessType, @ProcessHeader, @ProcessMessage

		--Execute real proc
			set @rowCountVal = 0
			exec USPDWH_T5StudentSchoolZoning @rowCount = @rowCountVal OUTPUT

			set @DWH_ETL_Outcome = 'PASS'

		--Log PASS
			SET @ProcessStatus = 'P'
			SET @ProcessMessage = 'ETL to load DWH_T5StudentSchoolZoning - Successful'
			Exec dbo.USPLOG_SEOProcessLog @ProcessCatID, @ProcessStatus, @rowCountVal, @ProcessType, @ProcessHeader, @ProcessMessage
	END TRY
	BEGIN CATCH
			set @DWH_ETL_Outcome = 'FAIL'
			set @ErrorMessage = ERROR_MESSAGE()
			set @ErrorMessage = case when len(@ErrorMessage) > 200 then left(@ErrorMessage, 200) else @ErrorMessage end
			set @ProcessOutcome = 'FAIL'
		--Log FAIL
			SET @ProcessStatus = 'F'
			SET @ProcessMessage = 'ETL to load DWH_T5StudentSchoolZoning - Failed' + ' - ' + @ErrorMessage
			Exec dbo.USPLOG_SEOProcessLog @ProcessCatID, @ProcessStatus, 0, @ProcessType, @ProcessHeader, @ProcessMessage
	END CATCH

	--This process is discontinued for test waves in Oct 2025-Dec 2025 and subsequent production waves
	--Accordingly, this DWH_Hist table is dropped 
	--Histry dbo.DWH_T5StudentSchoolZoning to dbo.DWH_T5StudentSchoolZoningHist
	--exec USPDWH_T5StudentSchoolZoningHist

	--Load DWH_T5StudentSchoolZoning into INT_T5StudentZoneSchool and archive INT
	SET @ProcessHeader = 'USPINT_T5StudentZoneSchool';
	IF @DWH_ETL_Outcome = 'PASS' --Do not run INT process if DWH fails
	BEGIN
		BEGIN TRY
			--Log 'BEG'
				SET @ProcessStatus = 'I';
				SET @ProcessMessage = 'ETL to load INT_T5StudentZoneSchool - Started'
				Exec dbo.USPLOG_SEOProcessLog @ProcessCatID, @ProcessStatus, 0, @ProcessType, @ProcessHeader, @ProcessMessage

			--Execute real proc
				set @rowCountVal = 0
				exec USPINT_T5StudentZoneSchool @rowCount = @rowCountVal OUTPUT

			--Log PASS
				SET @ProcessStatus = 'P'
				SET @ProcessMessage = 'ETL to load INT_T5StudentZoneSchool - Successful'
				Exec dbo.USPLOG_SEOProcessLog @ProcessCatID, @ProcessStatus, @rowCountVal, @ProcessType, @ProcessHeader, @ProcessMessage
		END TRY
		BEGIN CATCH
				set @ProcessOutcome = 'FAIL'
				set @ErrorMessage = ERROR_MESSAGE()
				set @ErrorMessage = case when len(@ErrorMessage) > 200 then left(@ErrorMessage, 200) else @ErrorMessage end

			--Log FAIL
				SET @ProcessStatus = 'F'
				SET @ProcessMessage = 'ETL to load INT_T5StudentZoneSchool - Failed' + ' - ' + @ErrorMessage
				Exec dbo.USPLOG_SEOProcessLog @ProcessCatID, @ProcessStatus, 0, @ProcessType, @ProcessHeader, @ProcessMessage
		END CATCH	

		--Populate RPT_T5InvalidHomeDistrict LCGMS Zoned District doesn't match to Register HomeDistrict
		--INT_T5StudentZoneSchool.KZonedDistrictID <> RPT_T5StudentRegister.HomeDistrict
		SET @ProcessHeader = 'USPRPT_T5InvalidHomeDistrict';
		BEGIN TRY
			--Log 'BEG'
				SET @ProcessStatus = 'I';
				SET @ProcessMessage = 'ETL to load RPT_T5InvalidHomeDistrict - Started'
				Exec dbo.USPLOG_SEOProcessLog @ProcessCatID, @ProcessStatus, 0, @ProcessType, @ProcessHeader, @ProcessMessage

			--Execute real proc
				set @rowCountVal = 0
				exec dbo.USPRPT_T5InvalidHomeDistrict @rowCount = @rowCountVal OUTPUT

			--Log PASS
				SET @ProcessStatus = 'P'
				SET @ProcessMessage = 'ETL to load RPT_T5InvalidHomeDistrict - Successful'
				Exec dbo.USPLOG_SEOProcessLog @ProcessCatID, @ProcessStatus, @rowCountVal, @ProcessType, @ProcessHeader, @ProcessMessage
		END TRY
		BEGIN CATCH
				set @ProcessOutcome = 'FAIL'
				set @ErrorMessage = ERROR_MESSAGE()
				set @ErrorMessage = case when len(@ErrorMessage) > 200 then left(@ErrorMessage, 200) else @ErrorMessage end

			--Log FAIL
				SET @ProcessStatus = 'F'
				SET @ProcessMessage = 'ETL to load RPT_T5InvalidHomeDistrict - Failed' + ' - ' + @ErrorMessage
				Exec dbo.USPLOG_SEOProcessLog @ProcessCatID, @ProcessStatus, 0, @ProcessType, @ProcessHeader, @ProcessMessage
		END CATCH	
	END

	--ProcessOutcome PASS/FAIL is used by the SSIS package to send success/fail  notification
	IF @ProcessOutcome = '' 
	BEGIN
		SET @ProcessOutcome = 'PASS' 
		SET @ProcessStatus = 'P'
		SET @ProcessHeader = 'USPINT_T5StudentZoneSchoolWrapper'
		SET @ProcessMessage= 'Wrapper Proc - Successful'
		Exec dbo.USPLOG_SEOProcessLog @ProcessCatID, @ProcessStatus, 0, @ProcessType, @ProcessHeader, @ProcessMessage
	END

	IF @ProcessOutcome = 'FAIL' 
	BEGIN
		SET @ProcessStatus = 'F'
		SET @ProcessHeader = 'USPINT_T5StudentZoneSchoolWrapper'
		SET @ProcessMessage= 'Wrapper Proc - Failed'
		Exec dbo.USPLOG_SEOProcessLog @ProcessCatID, @ProcessStatus, 0, @ProcessType, @ProcessHeader, @ProcessMessage
	END

	RETURN
END
