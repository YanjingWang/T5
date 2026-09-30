USE [SEO_REPORTING]
GO

/****** Object:  View [BI].[vw_T5Dashboard_YOYReferralsSchoolDays]    Script Date: 4/6/2026 1:48:07 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE VIEW [BI].[vw_T5Dashboard_YOYReferralsSchoolDays]
AS

/****************************************************************************************************************************************************************************************************************
Object Name: dbo.[vw_T5Dashboard_YOYReferralsSchoolDays]
Sample call: select * from SEO_REPORTING.BI.[vw_T5Dashboard_YOYReferralsSchoolDays] 
Purpose: 

Date Created: MM/DD/2023

ModificatiON Details:

Author		  ModifiedDate		   Comments
Prem B		   MM/DD/2023			 Initial
Prem B		   MM/DD/2024			 Added [2023-2024]
Charlotte W.   12/23/2025            SY26. Added prior year [2024-2025] per trend
***************************************************************************************************************************************************************************************************************/

----"VIEW IS USED IN PRODUCTION"

SELECT SchoolYear, CutOff, SchoolDay AS SchoolDays
FROM
(
    SELECT
          [SchoolDay]
        , ISNULL([2022-2023], (SELECT MAX([2022-2023]) FROM [SEO_MART].[dbo].[vw_SchoolDays] WITH (NOLOCK))) AS [2022-2023]
        , ISNULL([2023-2024], (SELECT MAX([2023-2024]) FROM [SEO_MART].[dbo].[vw_SchoolDays] WITH (NOLOCK))) AS [2023-2024]
        , ISNULL([2024-2025], (SELECT MAX([2024-2025]) FROM [SEO_MART].[dbo].[vw_SchoolDays] WITH (NOLOCK))) AS [2024-2025]
    FROM [SEO_MART].[dbo].[vw_SchoolDays] WITH (NOLOCK)
    WHERE CAST([2024-2025] AS date) =
    (
        SELECT CAST(MAX([2024-2025]) AS date)
        FROM [SEO_MART].[dbo].[vw_SchoolDays] WITH (NOLOCK)
        WHERE CAST([2024-2025] AS date) <=
              (SELECT MAX(ProcessedDate)
               FROM SEO_MART.dbo.RPT_T5ReferralLinkage WITH (NOLOCK))
    )
) t
UNPIVOT
(
    CutOff FOR SchoolYear IN ([2022-2023], [2023-2024], [2024-2025])
) AS CutOffUnpivot;
GO


