USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPRPT_T5WaveAssignmentsToDIIT]    Script Date: 4/4/2026 4:41:13 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[USPRPT_T5WaveAssignmentsToDIIT]
/**********************************************************************************************************************************************************************************************************
******
Object Name: dbo.USPRPT_T5WaveAssignmentsToDIIT
Sample call: exec USPRPT_T5WaveAssignmentsToDIIT
Purpose: Generate weekly T5 WAVE Report consistent of student assignment details from current week's wave
	This output is for DIIT processing purposes

    THis proc is called by the "Assignment finalization job" that usually runs on Friday

Date Created: 10/15/2025

ModificatiON Details:

Author		    ModifiedDate		Comments
Charlotte W		10/15/2025			Initial
***********************************************
****************************************************************************************************************************************************************/
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ETLProcessedDateTime  datetime  = GETDATE();
    DECLARE @ETLProcessedDate      date      = CAST(@ETLProcessedDateTime AS date);

    --trunate, load and archive

    delete from SEO_MART.dbo.RPT_T5WaveAssignmentsToDIIT
    
    INSERT INTO SEO_MART.dbo.RPT_T5WaveAssignmentsToDIIT
    (
        NYCID,
        [Language],
        [Location],
        [Is the Process Open],
        [Additional location Admin School DBN],
        [T5 Initial or T5 ReEval],
        [Date of Referral],
        ETLProcessedDate,
        ETLProcessedDateTime
    )
    SELECT DISTINCT
           SA.StudentID                                         AS NYCID,
           ISNULL(SA.GuardianLanguage,'EN')                     AS [Language],
           SA.Location                                          AS [Location],
           'Open'                                               AS [Is the Process Open],
           SA.T5IEPTeam                                         AS [Additional location Admin School DBN],
           SA.CaseType                                          AS [T5 Initial or T5 ReEval],
           CONVERT(varchar, DATEADD(day, 1, SA.WaveDate), 120)  AS [Date of Referral],
           @ETLProcessedDate,
           @ETLProcessedDateTime
    FROM SEO_MART.dbo.RPT_T5StudentAssignment AS SA
    WHERE SA.WaveID IN (SELECT MAX(WaveID) FROM SEO_MART.dbo.RPT_T5StudentAssignment)
      AND SA.ActiveFlag = 'Y'


    INSERT INTO SEO_MART.arch.RPT_T5WaveAssignmentsToDIIT
    (
        NYCID,
        [Language],
        [Location],
        [Is the Process Open],
        [Additional location Admin School DBN],
        [T5 Initial or T5 ReEval],
        [Date of Referral],
        ETLProcessedDate,
        ETLProcessedDateTime,
        ArchivedDateTime
    )
    SELECT DISTINCT
           NYCID,
           [Language],
           [Location],
           [Is the Process Open],
           [Additional location Admin School DBN],
           [T5 Initial or T5 ReEval],
           [Date of Referral],
           @ETLProcessedDate,
           @ETLProcessedDateTime,
           @ETLProcessedDateTime
    FROM SEO_MART.dbo.RPT_T5WaveAssignmentsToDIIT 
    
END
