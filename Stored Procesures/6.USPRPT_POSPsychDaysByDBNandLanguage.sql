USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPRPT_POSPsychDaysByDBNandLanguage]    Script Date: 4/4/2026 1:39:02 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER   PROC [dbo].[USPRPT_POSPsychDaysByDBNandLanguage]
AS
/*
Sample call: exec dbo.USPRPT_POSPsychDaysByDBNandLanguage
Purpose: This stored proc creates RPT_POSPsychDaysByDBNandLanguage by rolling up RPT_POSPsychDaysDetail by DBN and Language
		
IMPORTANT NOTE: The number of psychologist days for all types of schools, 
including High Schoolss, Middle Schools, Junior-High are loaded into this table.
In order to exclude high schools for KIP Assignment by setting NumOfPsycDays to 0, then manipulation should happen 
at vw_T5Capacity level not in the main table 

Modification History:
Name        Date        Comments
Raji        01/25/2025  Initial Draft
*/
BEGIN
    SET NOCOUNT ON;

    DECLARE @ETLProcessedDate date, @ETLProcessedDateTime datetime;
    SELECT @ETLProcessedDateTime = GETDATE();
    SELECT @ETLProcessedDate = CAST(@ETLProcessedDateTime AS date);

    TRUNCATE TABLE dbo.RPT_POSPsychDaysByDBNandLanguage;

    INSERT INTO dbo.RPT_POSPsychDaysByDBNandLanguage(
          SchoolDBN
        , D75Site 
        , Language
        , IsBilingualPsych
        , POSPsychDays
        , ETLProcessedDate
        , ETLProcessedDateTime
    )
    SELECT 
          LEFT(SchoolDBN, 6) AS SchoolDBN
        , CASE 
            WHEN CHARINDEX('@', SchoolDBN, 1) > 0 
                 THEN RIGHT(SchoolDBN, LEN(SchoolDBN) - CHARINDEX('@', SchoolDBN, 1)) 
            ELSE '' 
          END AS D75Site
        , Language
        , CASE WHEN LanguageFlag = 'M' THEN 0 ELSE 1 END AS IsBilingualPsych
        , CAST(SUM(ISNULL(POSPsychDaysInDBN, 0)) AS numeric(10,2)) AS POSPsychDays
        , @ETLProcessedDate
        , @ETLProcessedDateTime
    FROM dbo.RPT_POSPSYCHDAYSDetail
    WHERE ETLProcessedDateTime = (SELECT MAX(ETLProcessedDateTime) FROM dbo.RPT_POSPSYCHDAYSDetail)
    GROUP BY SchoolDBN, Language, LanguageFlag;

    --archive
    INSERT INTO arch.RPT_POSPsychDaysByDBNandLanguage(
          SchoolDBN
        , D75Site
        , Language
        , IsBilingualPsych
        , POSPsychDays
        , ETLProcessedDate
        , ETLProcessedDateTime
        , ArchivedDate
        , ArchivedDateTime	
    )
    SELECT
          SchoolDBN
        , D75Site
        , Language
        , IsBilingualPsych
        , POSPsychDays
        , ETLProcessedDate
        , ETLProcessedDateTime
        , @ETLProcessedDate       AS ArchivedDate
        , @ETLProcessedDateTime   AS ArchivedDateTime	
    FROM dbo.RPT_POSPsychDaysByDBNandLanguage;

END
