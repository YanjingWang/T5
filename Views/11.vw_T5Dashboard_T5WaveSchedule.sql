USE [SEO_REPORTING]
GO

/****** Object:  View [BI].[vw_T5Dashboard_T5WaveSchedule]    Script Date: 4/6/2026 1:44:59 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE VIEW [BI].[vw_T5Dashboard_T5WaveSchedule]
/****************************************************************************************************************************************************************************************************************
Object Name: [SEO_REPORTING].[BI].[vw_T5Dashboard_T5WaveSchedule]

Sample call: select * from [SEO_REPORTING].[BI].[vw_T5Dashboard_T5WaveSchedule]

Purpose: Wave schedule details.

Date Created: 03/05/2024

Modification Details: 

Author		        ModifiedDate		Comments
Prem Boompagh		04/01/2021			Initial
Ariel H				01/26/2026			Add ManualWaveFlag + Replace NULLs for BI formatting. BI displays NULL as blank.
Charlotte Wang      03/09/2026          Updated PostWaveInactivatedCnt logic to exclude all ModifiedReasons containing 'Reassignment'
***************************************************************************************************************************************************************************************************************/
AS
SELECT 
    CASE 
        WHEN a.[WaveID] < 1 THEN '-' 
        ELSE CAST(a.WaveID AS VARCHAR) 
    END AS WaveID,
    WaveDate,
    CASE 
        WHEN ProcessedDate = '2025-10-08' THEN '-' 
        ELSE CAST(ProcessedDate AS VARCHAR) 
    END AS ProcessedDate,
    CASE 
        WHEN a.[WaveID] < 1 THEN '-' 
        ELSE CSEOnlyFlag 
    END AS ManualWaveFlag,
    CASE 
        WHEN a.[WaveID] < 1 THEN '-'
        WHEN WaveActualCount IS NULL THEN 'TBD'
        ELSE CAST(WaveActualCount AS VARCHAR)
    END AS WaveActualCnt,
    CASE 
        WHEN a.[WaveID] < 1 THEN '-'
        WHEN WaveActualCount IS NULL THEN 'TBD'
        ELSE CAST(ISNULL(PostWaveInactivatedCnt, 0) AS VARCHAR)
    END AS PostWaveInactivatedCnt,
    WaveDescription,
    ReportingSchoolYear
FROM seo_mart.dbo.INT_T5WaveSchedule a WITH (NOLOCK)
LEFT JOIN 
(
    SELECT 
        WaveID,
        COUNT(*) AS PostWaveInactivatedCnt
    FROM SEO_MART.dbo.RPT_T5StudentAssignment WITH (NOLOCK)
    WHERE ActiveFlag = 'N'						-- Inactivated
        AND ModifiedReasons IS NOT NULL			-- Only students with an inactivation and no corresponding activation will have a modified reason
        AND ModifiedReasons NOT LIKE '%Reassignment%'
    GROUP BY WaveID
) b
    ON a.WaveID = b.WaveID
GO


