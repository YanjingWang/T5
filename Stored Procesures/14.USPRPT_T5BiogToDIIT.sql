USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPRPT_T5BiogToDIIT]    Script Date: 4/4/2026 1:52:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[USPRPT_T5BiogToDIIT]
/****************************************************************************************************************************************************************************************************************
Obje
ct Name: dbo.USPRPT_T5BiogToDIIT
Sample call: exec USPRPT_T5BiogToDIIT
Purpose: Generate weekly T5 BIOG Report consistent of wave assigned students that underwent biographical data modifications in preschool source
	This output is for DIIT processing purp
oses

Date Created: 10/15/2025

ModificatiON Details:

Author		    ModifiedDate		Comments
Charlotte W		10/15/2025			Initial
Charlotte W     01/12/2026          For WAVE portion of the script, we should ignore ActiveFlag condition. 
                                    For BIOG portion of the script, we should maintain ActiveFlag='Y' condition
***********************************************************************************************************************************
****************************************************************************/

AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ETLProcessedDateTime  datetime  = GETDATE();
    DECLARE @ETLProcessedDate      date      = CAST(@ETLProcessedDateTime AS date);

   
 declare @maxWaveIDProcessed int, @maxWaveDate date
    SELECT @maxWaveIDProcessed = MAX(WaveID) FROM SEO_MART.dbo.RPT_T5StudentAssignment
    select @maxWaveDate = WaveDate from INT_T5WaveSchedule where WaveID = @maxWaveIDProcessed

    delete from SEO_MART.dbo.RPT_T5BiogToDIIT
    
    /* Append this run */
    INSERT INTO SEO_MART.dbo.RPT_T5BiogToDIIT
    (
        NYCID,
        [Student Last name],
        [Student First name],
        [Date of Birth],
        Gender,
        [Home district],
        [House Number],
        [Street name],
        [Borough],
        [Zip Code],
        [Apt#],
        [City Name],
        [Guardian Last Name],
        [Guardian First Name],
        [Guardian Phone No],
        [Guardian Language],
        Record_Type,

        ETLProcessedDate,
        ETLProcessedDateTime
    )
    /* --- DELTA (weekly) -------------------------------------------- */
    SELECT
        SA.StudentID                                        AS [NYCID],
        SR.LastName                                         AS [Student Last name],
        SR.FirstName                                        AS [Student First name],
        CONVERT(varchar, SR.BirthDate, 112)                 AS [Date of Birth],
        SR.Gender,
        CASE WHEN LEN(SR.HomeDistrict) >= 2 THEN SR.HomeDistrict
             WHEN LEN(SR.HomeDistrict)  = 1 THEN '0' + SR.HomeDistrict
        END                                                 AS [Home district],
        SR.HouseNumber                                      AS [House Number],
        SR.Street                                           AS [Street name],
        SR.BoroughCode                                      AS [Borough],
        SR.ZipCode                                          AS [Zip Code],
        ISNULL(SR.ApartmentNumber,'')                       AS [Apt#],
        SR.CityName                                         AS [City Name],
        SR.GuardianLastName                                 AS [Guardian Last Name],
        SR.GuardianFirstName      
                          AS [Guardian First Name],
        ISNULL(SR.GuardianPhoneNumber,'')                   AS [Guardian Phone No],
        ISNULL(SR.GuardianLanguage,'EN')                    AS [Guardian Language],
        'DELTA'                    
                         AS Record_Type,
        @ETLProcessedDate,
        @ETLProcessedDateTime
    FROM SEO_MART.dbo.RPT_T5StudentAssignment AS SA WITH (NOLOCK)
    JOIN SEO_MART.dbo.RPT_T5StudentRegister   AS SR WITH (NOLOCK)
      ON SA.StudentID = SR.StudentID
    WHERE SR.BiogReportFlag = 'Y'
      AND SA.WaveID <> @maxWaveIDProcessed
      AND SA.ActiveFlag = 'Y'

    UNION ALL

    /* --- WAVE (only on wave weeks) --------------------------------- */
    SELECT
        SA.StudentID               
                         AS [NYCID],
        SR.LastName                                         AS [Student Last name],
        SR.FirstName       AS [Student First name],
        CONVERT(varchar, SR.BirthDate, 112)                 AS [Date of Birth],
  
      SR.Gender,
        CASE WHEN LEN(SR.HomeDistrict) >= 2 THEN SR.HomeDistrict
             WHEN LEN(SR.HomeDistrict)  = 1 THEN '0' + SR.HomeDistrict
        END                                                 AS [Home district],
        SR.HouseNumber                                      AS [House Number],
        SR.Street                                           AS [Street name],
        SR.BoroughCode                                      AS [Borough],
        SR.ZipCode                                          AS [Zip Code],
        ISNULL(SR.ApartmentNumber,'')                       AS [Apt#],
        SR.CityName                                         AS [City Name],
        SR.GuardianLastName                                 AS [Guardian Last Name],
        SR.GuardianFirstName                                AS [Guardian First Name],
        ISNULL(SR.GuardianPhoneNumber,'')                   AS [Guardian Phone No],
        ISNULL(SR.GuardianLanguage,'EN')                    AS [Guardian Language],
        'WAVE'                                              AS Record_Type,
        @ETLProcessedDate,
        @ETLProcessedDateTime
    FROM SEO_MART.dbo.RPT_T5StudentAssignment AS SA WITH (NOLOCK)
        INNER JOIN SEO_MART.dbo.RPT_T5StudentRegister   AS SR WITH (NOLOCK)
            ON SA.StudentID = SR.StudentID
    WHERE SA.WaveID = @maxWaveIDProcessed
      --AND SA.ActiveFlag = 'Y'
      AND cast(GETDATE() as date) = @maxWaveDate

    insert into arch.RPT_T5BiogToDIIT(
          [NYCID]
          , [Student Last name]
        , [Student First name]
        , [Date of Birth]
        , [Gender]
        , [Home district]
        , [House Number]
        , [Street name]
        , [Borough]
        , [Zip Code]
        , [Apt#]
        , [City Name]
  
      , [Guardian Last Name]
        , [Guardian First Name]
        , [Guardian Phone No]
        , [Guardian Language]
        , [Record_Type]
        , [ETLProcessedDate]
        , [ETLProcessedDateTime]
        , [ArchivedDateTime]
    )
    select 
 
         [NYCID]
        , [Student Last name]
        , [Student First name]
        , [Date of Birth]
        , [Gender]
        , [Home district]
        , [House Number]
        , [Street name]
        , [Borough]
        , [Zip Code]
        , [Apt#]
        , [City Name]
        , [Guardian Last Name]
        , [Guardian First Name]
        , [Guardian Phone No]
        , [Guardian Language]
        , [Record_Type]
        , [ETLProcessedDate]
        , [ETLProcessedDateTime]
        , [ETLProcessedDateTime]
    from dbo.RPT_T5BiogToDIIT
END
