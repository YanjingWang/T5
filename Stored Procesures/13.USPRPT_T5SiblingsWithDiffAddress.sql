USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPRPT_T5SiblingsWithDiffAddress]    Script Date: 4/4/2026 1:50:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[USPRPT_T5SiblingsWithDiffAddress]  
/******************************************************************************************************************************************************************************
Object Name: dbo.USPRPT_T5SiblingsWithDiffAddress
Sample call: Exec dbo.USPRPT_T5SiblingsWithDiffAddress
Purpose: Identify sibling groups where Turning-5 students share the same SiblingKey but have different home addresses;
         append results into RPT_T5SiblingsWithDiffAddress for downstream consumption (SEO_T5 view can sit on top of this table).
Date Created: 10/15/2025

Author      ModifiedDate    Comments
Charlotte   10/15/2025      Initial Draft  
*****************************************************************************************************************************************************************************/
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ETLProcessedDateTime datetime = GETDATE();
    DECLARE @ETLProcessedDate     date     = CAST(@ETLProcessedDateTime AS date);

    /* NOTE: Append-only pattern ? do NOT delete from RPT table.
       You can distinguish runs via ETLProcessedDate/ETLProcessedDateTime. */

    INSERT INTO dbo.RPT_T5SiblingWithDiffAddress
    (
        StudentID, 
        SiblingKey, 
        IsSibling, 
        HouseNumber, 
        Street, 
        BoroughCode, 
        ZipCode,
        ETLProcessedDate, 
        ETLProcessedDateTime
    )
    SELECT  r.StudentID,
            r.SiblingKey,
            r.IsSibling,
            r.HouseNumber,
            r.Street,
            r.BoroughCode,
            r.ZipCode,
            @ETLProcessedDate,
            @ETLProcessedDateTime
    FROM SEO_MART.dbo.RPT_T5StudentRegister AS r WITH (NOLOCK)
    WHERE r.IsTurning5 = 1
      AND r.SiblingKey IN
      (
          SELECT s.SiblingKey
          FROM (
                SELECT DISTINCT
                       SiblingKey, IsSibling, HouseNumber, Street, BoroughCode, ZipCode
                       --ROW_NUMBER() OVER (PARTITION BY SiblingKey ORDER BY SiblingKey) AS DiffAdrID
                FROM SEO_MART.dbo.RPT_T5StudentRegister WITH (NOLOCK)
               ) AS s
          --WHERE s.DiffAdrID > 1
		  group by SiblingKey
		  having count(*) > 1
      );
END
