USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPDWH_CLUSTERINGWORKSHEET4POSPSYCHDAYS]    Script Date: 4/4/2026 1:31:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[USPDWH_CLUSTERINGWORKSHEET4POSPSYCHDAYS]
/*

Sample call: exec USPDWH_CLUSTERINGWORKSHEET4POSPSYCHDAYS 
Purpose: This stored proc loads Clustering Worksheet from IEPConnect in order to built out RPT_POSPsychDays
		The URL for the clustering worksheet, which is a SharePoint List, is 
		https://nycdoe.sharepoint.com/sites/OFS/IEPX/Lists/IEPX%20Clustering%20Worksheet/AllItems.aspx
		For access, reach out to Purvi Dharia or Arwina 
		Export data from relevant columns of the the above URL and load into Staging table. 
		Use this stored proc to load the DWH table from Staging table

IMPORANT NOTE: 
DWH table holds historical data along with current data - all identified by using ETLProcessedDateTime
IEPX file has only about 2k rows. We load the file about 10-20 times every year. It means, the table will have 20000 to 40000 rows per year. 
Since the record count is small, we can let the table grow for 10 years without truncating. We can archive once every 10 years

Modification History:
Name		Date		Comments
Raji		1/25/2025		Initial Draft
*/
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @ETLProcessedDate date, @ETLProcessedDateTime datetime
	select @ETLProcessedDateTime = getdate()
	select @ETLProcessedDate = cast(@ETLProcessedDateTime as date)

	declare @ETLProcessedDateTime_latest datetime
	select @ETLProcessedDateTime_latest = max(ETLProcessedDateTime) 
	from STAGING.lk_IEPXClusteringWorksheet4POSPsychDays
	--select @ETLProcessedDateTime_latest

	INSERT INTO dbo.DWH_CLUSTERINGWORKSHEET4POSPSYCHDAYS(
		CLClusterCode
		, CLClusterName
		, CLClusterDistrict
		, AppointedClinician
		, CLClusterService
		, PSYClusterLanguage
		, CLClusterLanguageDelivery
		, PSYL1Schools
		, PSYL1Days
		, PSYL2Schools
		, PSYL2Days
		, PSYL3Schools
		, PSYL3Days
		, PSYL4Schools
		, PSYL4Days
		, PSYL5Schools
		, PSYL5Days
		, PSYL6Schools
		, PSYL6Days
		, PSYL7Schools
		, PSYL7Days
		, SourceFileReadDate
		, SourceFileReadDateTime
		, ETLProcessedDate
		, ETLProcessedDateTime
	)
	SELECT 
		TRIM(ISNULL([CL Cluster Code], '')),
		TRIM(ISNULL([CL Cluster Name], '')),
		TRIM(ISNULL([CL Cluster District], '')),
		TRIM(ISNULL([Appointed Clinician], '')),
		TRIM(ISNULL([Cluster Name:CL Cluster Service], '')),
		TRIM(ISNULL([PSY - Cluster Language], '')),
		TRIM(ISNULL([Cluster Name:CL Cluster Language Delivery], '')),
		TRIM(ISNULL([PSY - L1 Schools_Cleaned], '')),
		TRIM(ISNULL([PSY - L1 Days], '')),
		TRIM(ISNULL([PSY - L2 Schools_Cleaned], '')),
		TRIM(ISNULL([PSY - L2 Days], '')),
		TRIM(ISNULL([PSY - L3 Schools_Cleaned], '')),
		TRIM(ISNULL([PSY - L3 Days], '')),
		TRIM(ISNULL([PSY - L4 Schools_Cleaned], '')),
		TRIM(ISNULL([PSY - L4 Days], '')),
		TRIM(ISNULL([PSY - L5 Schools_Cleaned], '')),
		TRIM(ISNULL([PSY - L5 Days], '')),
		TRIM(ISNULL([PSY - L6 Schools_Cleaned], '')),
		TRIM(ISNULL([PSY - L6 Days], '')),
		TRIM(ISNULL([PSY - L7 Schools_Cleaned], '')),
		TRIM(ISNULL([PSY - L7 Days], '')),
		ETLProcessedDate,
		ETLProcessedDateTime,
		@ETLProcessedDate,
		@ETLProcessedDateTime
	FROM STAGING.lk_IEPXClusteringWorksheet4POSPsychDays
	where ETLProcessedDateTime = @ETLProcessedDateTime_latest
END
