USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPVal_T5SchoolZoningFromLCGMS]    Script Date: 4/4/2026 2:02:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[USPVal_T5SchoolZoningFromLCGMS]
	@ValidationOutcome Varchar(4) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

/********************************************************************************************************************
Sample call:   
    declare @ValidationOutcome varchar(4)
    exec dbo.USPVal_T5SchoolZoningFromLCGMS @ValidationOutcome OUTPUT
    select @ValidationOutcome

Purpose:  Validate the LCGMS zoning data available in Staging prior to 
        loading dbo.DWH_T5StudentSchoolZoning and other downstream table.
            Returns PASS/FAIL. 
        This proc also sends an email on FAIL, by including error list 
            on the email.
Date Created: 11/12/2025

Modification Details:

Author					ModifiedDate		Comments
Charlotte Wang			11/13/2025			Initial Draft
                                            (1) COUNT(Staging) + COUNT(InvalidAddr) = COUNT(Sent)
                                            (2) Echo columns match exactly: StudentID, SiblingKey, HouseNumber, Street, HouseNumberStreet, BoroughCode, ZipCode
                                            (2a) StudentID is numeric in main & error files
                                            (2b) All StudentIDs from main & error files are present in sent
                                            (2c) IsSibling ? {'True','False'} or {1 or 0} only (case-insensitive; run after StudentID checks)
                                            (3) At least one lat/long pair exists per Staging row (EX or AX)
                                            (4) ESID_NO is not null/blank        [optional – currently disabled]
                                            (5) ESID_NO is numeric                [implemented as “valid” check]
********************************************************************************************************************/

    SET @ValidationOutcome = 'FAIL'
    DECLARE @Today date = CAST(GETDATE() AS date);

	Declare 
		  @ValStatus VARCHAR(4)
		, @ValKey INT
		, @ValidationMsgs VARCHAR(500)
		, @ValHeader VARCHAR(100)
		, @IsValOverride SMALLINT
		, @IsValDone SMALLINT

	Declare 
		  @ProcessStatus CHAR(1)
		, @ProcessType varchar(30)
		, @ProcessCatID INT = 0
		, @ProcessMessage VARCHAR(500)
		, @ProcessHeader VARCHAR(100)

	--BEGIN: Log Start of Process to ProcessLog
	SET @ProcessType = 'T5-Zoning frm LCGMS'
	SET @ProcessHeader = 'USPVal_T5SchoolZoningFromLCGMS'

	SET @ProcessStatus = 'I'
	SET @ProcessMessage= 'Validation Proc - Started'
	Exec dbo.USPLOG_SEOProcessLog @ProcessCatID, @ProcessStatus, 0, @ProcessType, @ProcessHeader, @ProcessMessage
	--END: Log Start of Process to ProcessLog

	SET @ValHeader = 'Staging.DWH_T5StudentZoningFromLCGMS Validation';
	SET @ValKey = 303001;

	--get/check validation overrideID
	SET @IsValDone = 2;
	SET @IsValOverride = (
		SELECT top 1 ValOverrideID 
		FROM dbo.SEODataValidationOutcome 
		WHERE ValKey=@ValKey AND ValOverrideID=1 AND CAST(CreatedDatetime AS DATE)=@Today
        order by ValOverrideID desc
	);

    --Check for override. If checks are 'overridden' skip all validations and jump to end
	IF @IsValOverride = 1
	BEGIN
		SET @ValidationMsgs = (SELECT CONCAT(@ValHeader, ' - Overridden'));
		SET @ValStatus = 'OVERRIDE';

		--update ValOverrideID
		UPDATE dbo.SEODataValidationOutcome 
			SET ValOverrideID=@IsValDone,
				ModifiedDateTime=GETDATE(),
				ModifiedBy=SYSTEM_USER
		WHERE ValKey=@ValKey AND ValOverrideID=1 AND CAST(CreatedDatetime AS DATE)=@Today;				
		
        GOTO OverrideValidation;

	END;

	--Start validation

    --Log the beginning of the proc to SEODataValidationOutcome 
    --to allow for OVERRIDE at a later time
	SET @ValStatus = 'BEG';
	SET @ValidationMsgs = CONCAT(@ValHeader, ' - Started');
    Exec dbo.USPSEO_DataValidationOutcomeINS @ValStatus,@ValKey,@ValidationMsgs;

    /* Clear today's prior issues */
    DELETE FROM dbo.DWH_T5SchoolZoningFromLCGMS_ValidationIssues
    --WHERE ETLProcessedDate = @Today;

    /* ------------ Scope data into temp tables ------------ */
    IF OBJECT_ID('tempdb..#MainFileFromLCGMS') IS NOT NULL DROP TABLE #MainFileFromLCGMS;
    SELECT GBATID, TRIM(ISNULL(StudentID, '0')) as StudentID, 
        TRIM(ISNULL(HouseNumber, '')) as  HouseNumber,
        TRIM(ISNULL(Street, '')) as Street, 
        TRIM(isnull(HouseNumberStreet, '')) as HouseNumberStreet, 
        TRIM(isnull(HouseNumberStreet, '')) as HouseNumberStreet_Standardized, 
        TRIM(isnull(BoroughCode, '')) as BoroughCode, 
        TRIM(isnull(ZipCode, '')) as ZipCode, 
        TRIM(WA2_F1EX_Latitude) as WA2_F1EX_Latitude, 
        TRIM(WA2_F1EX_Longitude) as WA2_F1EX_Longitude, 
        TRIM(WA2_F1AX_Latitude) as WA2_F1AX_Latitude,
        TRIM(WA2_F1AX_Longitude) as WA2_F1AX_Longitude, 
        TRIM(ESID_NO) as ESID_NO, 
        TRIM(isnull(IsSibling, '')) as IsSibling, SiblingKey,
        TRIM(ISNULL(HouseNumber, '')) as HouseNumber_final, 
        TRIM(ISNULL(Street, '')) as Street_final,
        cast('' as varchar(100)) as HouseNumberStreet_final_Standardized
    INTO #MainFileFromLCGMS
    FROM Staging.DWH_T5StudentZoningFromLCGMS;

    --NOTE: Sometimes, when LCGMS Zoning file is loaded into Staging table, a few house numbers are affected by wrong conversion
    --Ex1: HouseNumber '1-15' in excel gets loaded as 'Jan 15' in the Staging table
    --Ex2: HouseNumber '11-09' in excel gets loaded as 'Nov 9' in the Staging table
    --Such bad conversion is luckily absent in the concatenated column 'HouseNumberStreet'
    --When a bad conversion is suspected, the below query helps determine the correct HouseNumber and StreetName using HouseNumberStreet
    --so that HouseNumber_final and Street_final gives proper values whether there is a bad conversion or not
    --there by their concatenation can be used to validate if LCGMS sent us the same HouseNumber + Street that we sent them
    update #MainFileFromLCGMS 
    set HouseNumber_final = CASE WHEN CHARINDEX(' ', HouseNumberStreet) > 0
                                    THEN LEFT(HouseNumberStreet, CHARINDEX(' ', HouseNumberStreet) - 1)
                                 ELSE '' END,
        Street_final =  CASE WHEN CHARINDEX(' ', HouseNumberStreet) > 0
                                THEN SUBSTRING(HouseNumberStreet, CHARINDEX(' ', HouseNumberStreet) + 1, 4000)
                             ELSE HouseNumberStreet END 
    where HouseNumber = ''  OR PATINDEX('%[A-Za-z]%', HouseNumber) > 0

    IF OBJECT_ID('tempdb..#INT_T5WaveEligibleStudents') IS NOT NULL DROP TABLE #INT_T5WaveEligibleStudents;
    SELECT SchoolYear, isnull(StudentID, 0) as StudentID, 
        case IsSibling when  0 then 'FALSE' when 1 then 'TRUE' else '' end as IsSibling, 
        SiblingKey, 
        TRIM(ISNULL(HouseNumber, '')) as HouseNumber, 
        TRIM(ISNULL(Street, '')) as Street, 
        TRIM(isnull(HouseNumberStreet, '')) as HouseNumberStreet, 
        TRIM(isnull(BoroughCode, '')) as BoroughCode, 
        TRIM(isnull(ZipCode, '')) as ZipCode,
        cast('' as varchar(100)) as HouseNumberStreet_standardized
    INTO #INT_T5WaveEligibleStudents
    FROM dbo.INT_T5WaveEligibleStudents
    WHERE WaveID is null; --Students who are sent to LCGMS

    update #INT_T5WaveEligibleStudents 
    set HouseNumberStreet_standardized = 
            UPPER(REPLACE(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                ' ' + REPLACE(REPLACE(REPLACE(
                        CONCAT(HouseNumber,' ', Street,''),
                            '–','-'),'—','-'),'  ',' ') + ' ',
                ' EAST ',  ' E '), ' WEST ',  ' W '), ' NORTH ', ' N '), ' SOUTH ', ' S '),
                ' STREET',' ST'), ' AVENUE',' AVE'), ' ROAD',' RD'), ' BOULEVARD',' BLVD'),
                ' COURT',' CT'), ' DRIVE',' DR'), ' PLACE',' PL'),
              '  ',' '),'  ',' '))

    update #MainFileFromLCGMS 
    set HouseNumberStreet_Standardized = 
            UPPER(REPLACE(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                ' ' + REPLACE(REPLACE(REPLACE(
                        HouseNumberStreet_Standardized,
                            '–','-'),'—','-'),'  ',' ') + ' ',
                ' EAST ',  ' E '), ' WEST ',  ' W '), ' NORTH ', ' N '), ' SOUTH ', ' S '),
                ' STREET',' ST'), ' AVENUE',' AVE'), ' ROAD',' RD'), ' BOULEVARD',' BLVD'),
                ' COURT',' CT'), ' DRIVE',' DR'), ' PLACE',' PL'),
              '  ',' '),'  ',' '))

    update #MainFileFromLCGMS 
    set HouseNumberStreet_final_Standardized = 
            UPPER(REPLACE(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                ' ' + REPLACE(REPLACE(REPLACE(
                        CONCAT(HouseNumber_final,' ', Street_final,''),
                            '–','-'),'—','-'),'  ',' ') + ' ',
                ' EAST ',  ' E '), ' WEST ',  ' W '), ' NORTH ', ' N '), ' SOUTH ', ' S '),
                ' STREET',' ST'), ' AVENUE',' AVE'), ' ROAD',' RD'), ' BOULEVARD',' BLVD'),
                ' COURT',' CT'), ' DRIVE',' DR'), ' PLACE',' PL'),
              '  ',' '),'  ',' '))
            
    IF OBJECT_ID('tempdb..#ErrorFileFromLCGMS') IS NOT NULL DROP TABLE #ErrorFileFromLCGMS;
    SELECT GRC, ReasonCode, GRC2, ReasonCode2, BadRecordId, 
TRIM(isnull(StudentID, '0')) as StudentID, IsSibling,
            SiblingKey, HouseNumber, Street, HouseNumberStreet, BoroughCode, ZipCode
    INTO #ErrorFileFromLCGMS
    FROM Staging.DWH_T5StudentInvalidAddressFromLCGMS;

    /* ------------ Rule 1: Accounting check ------------ */
    DECLARE @cntMain int, @cntSent int, @cntError int;
    SELECT @cntMain = COUNT(*) FROM #MainFileFromLCGMS;
    SELECT @cntSent    = COUNT(*) FROM #INT_T5WaveEligibleStudents;
    SELECT @cntError = COUNT(*) FROM #ErrorFileFromLCGMS;

    IF (@cntMain + @cntError) <> @cntSent
    BEGIN
        INSERT INTO dbo.DWH_T5SchoolZoningFromLCGMS_ValidationIssues
            (ETLProcessedDate, IssueCode, IssueDescription, IssueContent)
        VALUES
            (@Today, 'COUNT MISMATCH',
             'LCGMS SENT AND RECEIVED COUNTS DO NOT MATCH',
             CONCAT('SENT: ', @cntSent, '; RECEIVED: ', @cntMain + @cntError, '(MAIN=', @cntMain, '; ERROR=', @cntError, ')'));
    END;

    /* ------------ Rule 2a: StudentID numeric (main & error files) ------------ */
    INSERT INTO dbo.DWH_T5SchoolZoningFromLCGMS_ValidationIssues
        (ETLProcessedDate, IssueCode, IssueDescription, IssueContent)
    SELECT @Today, 'BAD STUDENTID', 'StudentID is not numeric in LCGMS MAIN file',
           CONCAT('StudentID=', m.StudentID)
    FROM #MainFileFromLCGMS m
    WHERE TRY_CONVERT(int, m.StudentID) IS NULL;

    INSERT INTO dbo.DWH_T5SchoolZoningFromLCGMS_ValidationIssues
        (ETLProcessedDate, IssueCode, IssueDescription, IssueContent)
    SELECT @Today, 'BAD STUDENTID', 'StudentID is not numeric in LCGMS ERROR file',
           CONCAT('StudentID=', e.StudentID)
    FROM #ErrorFileFromLCGMS e
    WHERE TRY_CONVERT(int, e.StudentID) IS NULL;

    /* ------------ Rule 2b: All StudentIDs from main & error exist in sent ------------ */
    INSERT INTO dbo.DWH_T5SchoolZoningFromLCGMS_ValidationIssues
        (ETLProcessedDate, IssueCode, IssueDescription, IssueContent)
    SELECT @Today, 'MISMATCH STUDENTID', 'StudentID in LCGMS MAIN file is not in SENT file',
           CONCAT('StudentID=', m.StudentID)
    FROM 
    (
        select cast(StudentID as int) as StudentID from #MainFileFromLCGMS 
        where TRY_CONVERT(int, StudentID) is not null
    ) m
        LEFT JOIN #INT_T5WaveEligibleStudents i ON i.StudentID = m.StudentID
    WHERE i.StudentID IS NULL

    INSERT INTO dbo.DWH_T5SchoolZoningFromLCGMS_ValidationIssues
        (ETLProcessedDate, IssueCode, IssueDescription, IssueContent)
    SELECT @Today, 'MISMATCH StudentID', 'StudentID from LCGMS ERROR file is not in SENT',
           CONCAT('StudentID=', e.StudentID)
    FROM 
    (
        select cast(StudentID as int) as StudentID from #ErrorFileFromLCGMS 
        where TRY_CONVERT(int, StudentID) is not null
    ) e 
    LEFT JOIN #INT_T5WaveEligibleStudents i ON i.StudentID = e.StudentID
    WHERE i.StudentID IS NULL

    /* ------------ Rule 2: Echo columns with robust HouseNumber/Street handling ------------ */
    INSERT INTO dbo.DWH_T5SchoolZoningFromLCGMS_ValidationIssues
        (ETLProcessedDate, IssueCode, IssueDescription, IssueContent)
    SELECT @Today, 'MISMATCH HouseNumber-Street', 'HouseNumber-Street is mismatched between LCGMS MAIN file and SENT file',
           CONCAT('StudentID=', i.StudentID, '; LCGMS: ', m.HouseNumberStreet_final_standardized, ', SENT: ', i.HouseNumberStreet_standardized)
    FROM 
    (
        SELECT *
        FROM #MainFileFromLCGMS
        WHERE TRY_CONVERT(int, StudentID) IS NOT NULL
    ) m
        INNER JOIN #INT_T5WaveEligibleStudents i
            ON m.StudentID = i.StudentID
    where i.HouseNumberStreet_standardized <> m.HouseNumberStreet_final_standardized
    and i.HouseNumberStreet_standardized <> m.HouseNumberStreet_Standardized

    INSERT INTO dbo.DWH_T5SchoolZoningFromLCGMS_ValidationIssues
        (ETLProcessedDate, IssueCode, IssueDescription, IssueContent)
    SELECT @Today, 'MISMATCH ZipCode', 'ZipCode is mismatched between LCGMS MAIN file and SENT file',
           CONCAT('StudentID=', i.StudentID, '; LCGMS: ', m.ZipCode, ', SENT: ', i.ZipCode)
    from
    (
        select * from  #MainFileFromLCGMS
        WHERE TRY_CONVERT(int, StudentID) IS NOT NULL
    ) m
        inner join #INT_T5WaveEligibleStudents i 
            on m.StudentID = i.StudentID 
    WHERE i.ZipCode <> m.ZipCode --THEN 'ZipCode' END AS diff_ZipCode

    INSERT INTO dbo.DWH_T5SchoolZoningFromLCGMS_ValidationIssues
        (ETLProcessedDate, IssueCode, IssueDescription, IssueContent)
    SELECT @Today, 'MISMATCH BoroughCode', 'BoroughCode is mismatched between LCGMS MAIN file and SENT file',
           CONCAT('StudentID=', i.StudentID, '; LCGMS: ', m.BoroughCode, ', SENT: ', i.BoroughCode)
    from (
        select * from  #MainFileFromLCGMS
        WHERE TRY_CONVERT(int, StudentID) IS NOT NULL
    ) m
        inner join #INT_T5WaveEligibleStudents i 
            on m.StudentID = i.StudentID 
    WHERE i.BoroughCode <> m.BoroughCode 

    INSERT INTO dbo.DWH_T5SchoolZoningFromLCGMS_ValidationIssues
        (ETLProcessedDate, IssueCode, IssueDescription, IssueContent)
    SELECT @Today, 'MISMATCH SiblingKey', 'SiblingKey is mismatched between LCGMS MAIN file and SENT file',
           CONCAT('StudentID=', i.StudentID, '; LCGMS: ', m.SiblingKey, ', SENT: ', i.SiblingKey)
    from (
        select * from  #MainFileFromLCGMS
        WHERE TRY_CONVERT(int, StudentID) IS NOT NULL
    ) m
        inner join #INT_T5WaveEligibleStudents i 
            on m.StudentID = i.StudentID 
    WHERE i.SiblingKey <> m.SiblingKey

    /* ------------ Rule 2c: IsSibling domain check ------------ */
    INSERT INTO dbo.DWH_T5SchoolZoningFromLCGMS_ValidationIssues
        (ETLProcessedDate, IssueCode, IssueDescription, IssueContent)
    SELECT @Today, 'BAD IsSibling', 'IsSibling is neither True nor False in LCGMS MAIN file',
           CONCAT('StudentID=', m.StudentID, '; IsSibling=', m.IsSibling)
    FROM #MainFileFromLCGMS m
    WHERE  m.IsSibling = ''
       OR UPPER(m.IsSibling) NOT IN ('TRUE','FALSE');

    INSERT INTO dbo.DWH_T5SchoolZoningFromLCGMS_ValidationIssues
        (ETLProcessedDate, IssueCode, IssueDescription, IssueContent)
    SELECT @Today, 'MISMATCH IsSibling', 'IsSibling is mismatched between LCGMS MAIN file and SENT file',
           CONCAT('StudentID=', i.StudentID, '; LCGMS: ', m.IsSibling, ', SENT: ', i.IsSibling)
    from (
        select * from  #MainFileFromLCGMS
        WHERE TRY_CONVERT(int, StudentID) IS NOT NULL
    ) m
        inner join #INT_T5WaveEligibleStudents i 
            on m.StudentID = i.StudentID 
    WHERE ISNULL(i.IsSibling,'') <> ISNULL(m.IsSibling,'') 

    --INSERT INTO dbo.DWH_T5SchoolZoningFromLCGMS_ValidationIssues
    --    (ETLProcessedDate, IssueCode, IssueDescription, IssueContent)
    --SELECT @Today, 'ISSIBLING_INVALID_ERROR', 'IsSibling must be True or False (ERROR file)',
    --       CONCAT('StudentID=', CAST(e.StudentID AS varchar(100)), '; IsSibling=', ISNULL(CAST(e.IsSibling AS varchar(50))))
    --FROM #ErrorFileFromLCGMS e
    --WHERE  NULLIF(LTRIM(RTRIM(CAST(e.IsSibling AS varchar(50)))), '') IS NULL
    --   OR UPPER(LTRIM(RTRIM(CAST(e.IsSibling AS varchar(50))))) NOT IN ('TRUE','FALSE');

    --INSERT INTO dbo.DWH_T5SchoolZoningFromLCGMS_ValidationIssues
    --    (ETLProcessedDate, IssueCode, IssueDescription, IssueContent)
    --SELECT @Today, 'BAD IsSibling', 'IsSibling must be 0 or 1 in INT_T5WaveEligibleStudents table)',
    --       CONCAT('StudentID=', i.StudentID, '; IsSibling=', i.IsSibling)
    --FROM #INT_T5WaveEligibleStudents i
    --WHERE i.IsSibling not in ('TRUE', 'FALSE');

    /* ------------ Rule 3: At least one non-null lat/long pair per staging row ------------ */
    INSERT INTO dbo.DWH_T5SchoolZoningFromLCGMS_ValidationIssues
        (ETLProcessedDate, IssueCode, IssueDescription, IssueContent)
    SELECT
        @Today, 'MISSING LATITUDE LONGITUDE',
        'No valid lat/long pair found (neither EX nor AX present) in LCGMS Main file',
        CONCAT('StudentID=', s.StudentID)
    FROM #MainFileFromLCGMS s
    WHERE (
        s.WA2_F1EX_Latitude = '' AND 
        s.WA2_F1EX_Longitude = '' AND
        s.WA2_F1AX_Latitude = '' AND
        s.WA2_F1AX_Longitude = ''
    ) --NOTE: TRY_CONVERT(FLOAT, '') is 0. When all are blanks, 
    OR (
        s.WA2_F1EX_Latitude = '0' AND 
        s.WA2_F1EX_Longitude = '0' AND
        s.WA2_F1AX_Latitude = '0' AND
        s.WA2_F1AX_Longitude = '0'
    )
    --below condition won't catch it. Hence above condition is added
    or 
    NOT (
         (TRY_CONVERT(float, s.WA2_F1EX_Latitude) IS NOT NULL
      AND  TRY_CONVERT(float, s.WA2_F1EX_Longitude) IS NOT NULL)
      OR
         (TRY_CONVERT(float, s.WA2_F1AX_Latitude) IS NOT NULL
      AND  TRY_CONVERT(float, s.WA2_F1AX_Longitude) IS NOT NULL)
    );

    /* ------------ Rule 5: ESID_NO numeric/valid ------------ */
    INSERT INTO dbo.DWH_T5SchoolZoningFromLCGMS_ValidationIssues
        (ETLProcessedDate, IssueCode, IssueDescription, IssueContent)
    SELECT
        @Today, 'BAD ESID_NO', 'ESID_NO is not valid in LCGMS Main File',
        CONCAT('StudentID=', s.StudentID, '; ESID_NO=', CAST(s.ESID_NO AS varchar(100)))
    FROM #MainFileFromLCGMS s
    WHERE ISNUMERIC(ISNULL(ESID_NO, '')) = 0 OR ESID_NO = '0';

    /* ------------ Outcome + email ------------ */
    DECLARE @IssueCount int;
    SELECT @IssueCount = COUNT(*)
    FROM dbo.DWH_T5SchoolZoningFromLCGMS_ValidationIssues
    WHERE ETLProcessedDate = @Today;

    if @IssueCount = 0
    BEGIN
        SET @ValidationOutcome = 'PASS'
        SET @ValStatus = 'PASS'
    END
    ELSE 
    BEGIN
        SET @ValStatus = 'FAIL'
    END

    IF @IssueCount > 0
    BEGIN
        DECLARE @EmailTo        varchar(400) 
        DECLARE @EmailCC         varchar(800) 
        DECLARE @FromAddress    varchar(200) = 'LCGMS-Zoning@schools.nyc.gov';
        DECLARE @Subject        varchar(200) = 'FAIL: LCGMS School Zoning Validation';
        DECLARE @Body           nvarchar(max);
        DECLARE @TableHtml      nvarchar(max);

        select @EmailTo = LookupValue
        from SEO_MART.dbo.lk_SEOBusinessRules 
        where LookupCategory = 'T5Wave' and LookupName = 'T5LCGMSZoningValidationEmailTo'

        select @EmailCC = LookupValue
        from SEO_MART.dbo.lk_SEOBusinessRules 
        where LookupCategory = 'T5Wave' and LookupName = 'T5LCGMSZoningValidationEmailCC'

        SET @TableHtml =
        N'<table border="1" cellpadding="4" cellspacing="0">'
        + N'<tr><th style="text-align:left;">Issue Code</th>'
        + N'<th style="text-align:left;">Issue Description</th>'
        + N'<th style="text-align:left;">Detail</th></tr>'
        + CAST((
            SELECT
                (SELECT v.IssueCode        AS "td" FOR XML PATH(''), TYPE),
                (SELECT v.IssueDescription AS "td" FOR XML PATH(''), TYPE),
                (SELECT v.IssueContent     AS "td" FOR XML PATH(''), TYPE)
            FROM dbo.DWH_T5SchoolZoningFromLCGMS_ValidationIssues v
            WHERE v.ETLProcessedDate = @Today
            ORDER BY IssueCode
            FOR XML PATH('tr'), ELEMENTS
        ) AS nvarchar(max))
        + N'</table>';

        SET @Body = N'<html><body>'
                 + N'<p style="font-family:Tahoma;">Hello,</p>'
                 + N'<p style="font-family:Tahoma;">Validation failed for LCGMS School Zoning file. '
                 + N'Please review the issue list below (' + CONVERT(varchar(10), @Today, 120) + N').</p>'
                 + @TableHtml
                 + N'<p style="font-family:Tahoma;">Thanks.</p>'
                 + N'</body></html>';

        EXEC msdb.dbo.sp_send_dbmail
             @recipients      = @EmailTo,
             @copy_recipients = @EmailCC,
             @from_address    = @FromAddress,
             @subject         = @Subject,
             @body            = @Body,
             @body_format     = 'HTML',
             @importance      = 'Normal';
    END;

	--Write final validation outcome--	
	OverrideValidation:
	IF @ValStatus='FAIL'
	BEGIN        
        SET @ValidationMsgs = Concat(@ValHeader, ' - Failed. View table DWH_T5SchoolZoningFromLCGMS_ValidationIssues');

		Exec dbo.USPSEO_DataValidationOutcomeINS @ValStatus,@ValKey,@ValidationMsgs;
	END
	ELSE IF @ValStatus='PASS'
	BEGIN
		SET @ValidationMsgs=Concat(@ValHeader, ' - Successful')
		Exec dbo.USPSEO_DataValidationOutcomeINS @ValStatus,@ValKey,@ValidationMsgs;
	END
    ELSE IF @ValStatus='OVERRIDE'
	BEGIN
		SET @ValidationMsgs=Concat(@ValHeader, ' - Overridden')
		Exec dbo.USPSEO_DataValidationOutcomeINS @ValStatus,@ValKey,@ValidationMsgs;
	END

    --BEGIN: Log Process Completion to ProcessLog
    IF @ValStatus = 'FAIL' 
    BEGIN
        SET @ProcessStatus = 'F'
	    SET @ProcessMessage= 'Validation Proc Failed. Check DWH_T5SchoolZoningFromLCGMS_ValidationIssues'
    END 
    ELSE IF @ValStatus = 'PASS'
    BEGIN
        SET @ProcessStatus = 'P'
	    SET @ProcessMessage= 'Validation Proc - Passed. No errors found.'
    END 
    ELSE IF @ValStatus = 'OVERRIDE'
    BEGIN
        SET @ProcessStatus = 'O'
	    SET @ProcessMessage= 'Validation Proc - Overridden'
    END 

	Exec dbo.USPLOG_SEOProcessLog @ProcessCatID, @ProcessStatus, 0, @ProcessType, @ProcessHeader, @ProcessMessage
    --END: Log Process Completion to ProcessLog
    
    RETURN 
END
