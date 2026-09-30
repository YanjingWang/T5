USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPINT_T5UpdateNoAssignmentReason]    Script Date: 4/4/2026 3:01:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
EXEC dbo.USPINT_T5UpdateNoAssignmentReason
    @SchoolYear = '2025-2026',
    @WaveID     = 1
*/
ALTER PROC [dbo].[USPINT_T5UpdateNoAssignmentReason]
    @SchoolYear char(9),
    @WaveID     int
AS

/***************************************************************************************************
Object Name: USPINT_T5UpdateNoAssignmentReason
Sample call: EXEC dbo.USPINT_T5UpdateNoAssignmentReason @SchoolYear = '2025-2026', @WaveID     = 1
Purpose: 
Created By:
Date Created: 

ModificatiON Details:

Author					ModifiedDate		Comments
Charlotte Wang			12/29/2025			MIS-14591 (https://seoanalytics.atlassian.net/browse/MIS-14591)
                                            Change DWH_T5StudentInvalidAddress references to DWH_T5StudentInvalidAddressFromLCGMS



********************************************************************************************************/
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------------------------
    -- 0) Exclusions: Students correctly assigned to their zoned DBN
    -------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#AssignedAtZoned') IS NOT NULL DROP TABLE #AssignedAtZoned;

    SELECT DISTINCT s.StudentID
    INTO #AssignedAtZoned
    FROM  SEO_MART.dbo.RPT_T5newAssignments_WT s
    INNER JOIN SEO_MART.dbo.INT_T5StudentZoneSchool zs
        ON zs.StudentID  = s.StudentID
       AND zs.SchoolYear = @SchoolYear
    WHERE 1 = 1
      AND ISNULL(zs.KZonedESDBN,'') <> ''
      AND s.AssignedSchoolDBN = zs.KZonedESDBN;

    -------------------------------------------------------------------------
    -- 0b) STOP table: enforce the "stop" behavior in your flow
    -------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#StopStudents') IS NOT NULL DROP TABLE #StopStudents;
    CREATE TABLE #StopStudents (StudentID int NOT NULL PRIMARY KEY);

    INSERT INTO #StopStudents(StudentID)
    SELECT StudentID FROM #AssignedAtZoned;

    -------------------------------------------------------------------------
    -- 1) Cache reason texts
    -------------------------------------------------------------------------
    DECLARE @RID1  varchar(500),
            @RID2  varchar(500),
            @RID3  varchar(500),
            @RID4  varchar(500),
            @RID5  varchar(500),
            @RID7  varchar(500),
            @RID12 varchar(500);

    SELECT @RID1  = CONCAT('RID1-',  NoAssignmtReasonsDesc) FROM dbo.lk_T5NoAssignmentReasons WHERE NoAssignmtReasonsID = 1;
    SELECT @RID2  = CONCAT('RID2-',  NoAssignmtReasonsDesc) FROM dbo.lk_T5NoAssignmentReasons WHERE NoAssignmtReasonsID = 2;
    SELECT @RID3  = CONCAT('RID3-',  NoAssignmtReasonsDesc) FROM dbo.lk_T5NoAssignmentReasons WHERE NoAssignmtReasonsID = 3;
    SELECT @RID4  = CONCAT('RID4-',  NoAssignmtReasonsDesc) FROM dbo.lk_T5NoAssignmentReasons WHERE NoAssignmtReasonsID = 4;
    SELECT @RID5  = CONCAT('RID5-',  NoAssignmtReasonsDesc) FROM dbo.lk_T5NoAssignmentReasons WHERE NoAssignmtReasonsID = 5;
    SELECT @RID7  = CONCAT('RID7-',  NoAssignmtReasonsDesc) FROM dbo.lk_T5NoAssignmentReasons WHERE NoAssignmtReasonsID = 7;
    SELECT @RID12 = CONCAT('RID12-', NoAssignmtReasonsDesc) FROM dbo.lk_T5NoAssignmentReasons WHERE NoAssignmtReasonsID = 12;

    -------------------------------------------------------------------------
    -- HomeCSE helper (CSEDBN seq = 1) for ALL downstream logic
    -------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#HomeCSE') IS NOT NULL DROP TABLE #HomeCSE;

    SELECT prt.StudentID, prt.DBNPriority AS HomeCSE
    INTO #HomeCSE
    FROM SEO_MART.dbo.RPT_T5StudentSchoolPriorities prt
    WHERE prt.SchoolYear          = @SchoolYear
      AND prt.WaveID              = @WaveID
      AND prt.DBNPriorityType     = 'CSEDBN'
      AND prt.DBNPrioritySequence = 1;

    -------------------------------------------------------------------------
    -- SpecialPopulation students temp table (FIX for your error)
    -------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#SpecialPop') IS NOT NULL DROP TABLE #SpecialPop;

    SELECT DISTINCT p.StudentID
    INTO #SpecialPop
    FROM SEO_MART.dbo.RPT_T5StudentSchoolPriorities p
    WHERE p.SchoolYear = @SchoolYear
      AND p.WaveID     = @WaveID
      AND p.AssignmentPriorityType = 'SpecialPopulation';

    -------------------------------------------------------------------------
    -- ASL students: display NULL and stop
    -- NOTE: Uncomment/adjust predicate to match your real ASL flag/field.
    -------------------------------------------------------------------------
    /*
    INSERT INTO #StopStudents(StudentID)
    SELECT DISTINCT tgt.StudentID
    FROM dbo.RPT_T5TargetStudents_T5_WT tgt
    LEFT JOIN #StopStudents st ON st.StudentID = tgt.StudentID
    WHERE st.StudentID IS NULL
      AND tgt.AssignmentSetting = 'ASL';
    */

    -------------------------------------------------------------------------
    -- SpecialPopulation:
    --   If Assigned = HomeCSE  -> NULL (stop)
    --   Else                  -> RID3 (AltDBN) and stop
    -------------------------------------------------------------------------
    INSERT INTO #StopStudents(StudentID)
    SELECT s.StudentID
    FROM SEO_MART.dbo.RPT_T5newAssignments_WT s
    JOIN #SpecialPop sp ON sp.StudentID = s.StudentID
    JOIN #HomeCSE   hc ON hc.StudentID = s.StudentID
    LEFT JOIN #StopStudents st ON st.StudentID = s.StudentID
    WHERE 1 = 1
      AND st.StudentID IS NULL
      AND s.AssignedSchoolDBN = hc.HomeCSE;

    UPDATE tgt
    SET DBNNoAssignmentReasons =
        CASE
            WHEN ISNULL(LTRIM(RTRIM(tgt.DBNNoAssignmentReasons)), '') = ''
                THEN ' || ' + @RID3
            WHEN tgt.DBNNoAssignmentReasons LIKE '%RID3%'
                THEN tgt.DBNNoAssignmentReasons
            ELSE tgt.DBNNoAssignmentReasons + '; ' + ' || ' + @RID3
        END
    FROM dbo.RPT_T5TargetStudents_WT tgt
    JOIN SEO_MART.dbo.RPT_T5newAssignments_WT s
      ON s.StudentID  = tgt.StudentID
    JOIN #SpecialPop sp ON sp.StudentID = s.StudentID
    JOIN #HomeCSE  hc  ON hc.StudentID = s.StudentID
    LEFT JOIN #StopStudents st ON st.StudentID = tgt.StudentID
    WHERE st.StudentID IS NULL
      AND s.AssignedSchoolDBN <> hc.HomeCSE;

    INSERT INTO #StopStudents(StudentID)
    SELECT DISTINCT sp.StudentID
    FROM #SpecialPop sp
    LEFT JOIN #StopStudents st ON st.StudentID = sp.StudentID
    WHERE st.StudentID IS NULL;

    -------------------------------------------------------------------------
    -- Prev assigned siblings => RID5 and stop
    -------------------------------------------------------------------------
    UPDATE tgt
    SET DBNNoAssignmentReasons =
        CASE
            WHEN ISNULL(LTRIM(RTRIM(tgt.DBNNoAssignmentReasons)), '') = ''
                THEN ' || ' + @RID5
            WHEN tgt.DBNNoAssignmentReasons LIKE '%RID5%'
                THEN tgt.DBNNoAssignmentReasons
            ELSE tgt.DBNNoAssignmentReasons + '; ' + ' || ' + @RID5
        END
    FROM dbo.RPT_T5TargetStudents_WT tgt
    INNER JOIN dbo.RPT_T5newAssignments_WT n
        ON n.StudentID = tgt.StudentID
    LEFT JOIN #StopStudents st ON st.StudentID = tgt.StudentID
    WHERE st.StudentID IS NULL
      AND n.DBNPriorityType IN ('SIBLINGDBN');

    INSERT INTO #StopStudents(StudentID)
    SELECT DISTINCT n.StudentID
    FROM dbo.RPT_T5newAssignments_WT n
    LEFT JOIN #StopStudents st ON st.StudentID = n.StudentID
    WHERE st.StudentID IS NULL
      AND n.DBNPriorityType IN ('SIBLINGDBN');

    -------------------------------------------------------------------------
    -- InvalidAddresses:
    --   Always RID7; if Assigned <> HomeCSE also RID3; stop
    -------------------------------------------------------------------------
    UPDATE tgt
    SET DBNNoAssignmentReasons =
        CASE
            WHEN ISNULL(LTRIM(RTRIM(tgt.DBNNoAssignmentReasons)), '') = ''
                THEN @RID7
            WHEN tgt.DBNNoAssignmentReasons LIKE '%RID7%'
                THEN tgt.DBNNoAssignmentReasons
            ELSE tgt.DBNNoAssignmentReasons + '; ' + @RID7
        END
    FROM dbo.RPT_T5TargetStudents_WT tgt
    INNER JOIN (SELECT DISTINCT StudentID FROM SEO_MART.dbo.DWH_T5StudentInvalidAddressFromLCGMS) ia
        ON ia.StudentID = tgt.StudentID
    LEFT JOIN #StopStudents st ON st.StudentID = tgt.StudentID
    WHERE st.StudentID IS NULL;

    UPDATE tgt
    SET DBNNoAssignmentReasons =
        CASE
            WHEN tgt.DBNNoAssignmentReasons LIKE '%RID3%'
                THEN tgt.DBNNoAssignmentReasons
            ELSE tgt.DBNNoAssignmentReasons + '; ' + ' || ' + @RID3
        END
    FROM dbo.RPT_T5TargetStudents_WT tgt
    JOIN SEO_MART.dbo.RPT_T5newAssignments_WT s
      ON s.StudentID  = tgt.StudentID
    JOIN (SELECT DISTINCT StudentID FROM SEO_MART.dbo.DWH_T5StudentInvalidAddressFromLCGMS) ia
      ON ia.StudentID = tgt.StudentID
    JOIN #HomeCSE hc
      ON hc.StudentID = tgt.StudentID
    LEFT JOIN #StopStudents st ON st.StudentID = tgt.StudentID
    WHERE st.StudentID IS NULL
      AND s.AssignedSchoolDBN <> hc.HomeCSE;

    INSERT INTO #StopStudents(StudentID)
    SELECT DISTINCT ia.StudentID
    FROM (SELECT DISTINCT StudentID FROM SEO_MART.dbo.DWH_T5StudentInvalidAddressFromLCGMS) ia
    LEFT JOIN #StopStudents st ON st.StudentID = ia.StudentID
    WHERE st.StudentID IS NULL;

    -------------------------------------------------------------------------
    -- Non-zoned regions (KZonedESDBN IS NULL):
    --   RID12 always; if ends in CSE => RID2; if assigned <> HomeCSE => RID3; stop
    -------------------------------------------------------------------------
    UPDATE tgt
    SET DBNNoAssignmentReasons =
        CASE
            WHEN ISNULL(LTRIM(RTRIM(tgt.DBNNoAssignmentReasons)), '') = ''
                THEN @RID12
            WHEN tgt.DBNNoAssignmentReasons LIKE '%RID12%'
                THEN tgt.DBNNoAssignmentReasons
            ELSE @RID12 + '; ' + tgt.DBNNoAssignmentReasons
        END
    FROM dbo.RPT_T5TargetStudents_WT tgt
    INNER JOIN SEO_MART.dbo.INT_T5StudentZoneSchool zs
        ON zs.StudentID  = tgt.StudentID
       AND zs.SchoolYear = @SchoolYear
    LEFT JOIN #StopStudents st ON st.StudentID = tgt.StudentID
    WHERE st.StudentID IS NULL
      AND zs.KZonedESDBN IS NULL;

    UPDATE tgt
    SET DBNNoAssignmentReasons =
        CASE
            WHEN tgt.DBNNoAssignmentReasons LIKE '%RID2%'
                THEN tgt.DBNNoAssignmentReasons
            ELSE tgt.DBNNoAssignmentReasons + '; ' + ' || ' + @RID2
        END
    FROM dbo.RPT_T5TargetStudents_WT tgt
    JOIN SEO_MART.dbo.RPT_T5newAssignments_WT s
      ON s.StudentID  = tgt.StudentID
    left join RPT_T5tfDBNCapacity_WT dbn on s.AssignedSchoolDBN = dbn.SchoolDBN 
    JOIN SEO_MART.dbo.INT_T5StudentZoneSchool zs
      ON zs.StudentID  = tgt.StudentID
     AND zs.SchoolYear = @SchoolYear
    LEFT JOIN #StopStudents st ON st.StudentID = tgt.StudentID
    WHERE st.StudentID IS NULL
      AND zs.KZonedESDBN IS NULL
      AND dbn.SchoolType = 'CSE';

    UPDATE tgt
    SET DBNNoAssignmentReasons =
        CASE
            WHEN tgt.DBNNoAssignmentReasons LIKE '%RID3%'
                THEN tgt.DBNNoAssignmentReasons
            ELSE tgt.DBNNoAssignmentReasons + '; ' + ' || ' + @RID3
        END
    FROM dbo.RPT_T5TargetStudents_WT tgt
    JOIN SEO_MART.dbo.RPT_T5newAssignments_WT s
      ON s.StudentID  = tgt.StudentID
    left join RPT_T5tfDBNCapacity_WT dbn on s.AssignedSchoolDBN = dbn.SchoolDBN 
    JOIN SEO_MART.dbo.INT_T5StudentZoneSchool zs
      ON zs.StudentID  = tgt.StudentID
     AND zs.SchoolYear = @SchoolYear
    JOIN #HomeCSE hc
      ON hc.StudentID = tgt.StudentID
    LEFT JOIN #StopStudents st ON st.StudentID = tgt.StudentID
    WHERE st.StudentID IS NULL
      AND zs.KZonedESDBN IS NULL
      AND dbn.SchoolType = 'CSE'
      AND s.AssignedSchoolDBN <> hc.HomeCSE;

    INSERT INTO #StopStudents(StudentID)
    SELECT DISTINCT zs.StudentID
    FROM SEO_MART.dbo.INT_T5StudentZoneSchool zs
    LEFT JOIN #StopStudents st ON st.StudentID = zs.StudentID
    WHERE zs.SchoolYear = @SchoolYear
      AND zs.KZonedESDBN IS NULL
      AND st.StudentID IS NULL;

    -------------------------------------------------------------------------
    -- Bilingual: RID4 for NEARDBN-LngMatch... then stop
    -------------------------------------------------------------------------
    UPDATE tgt
    SET DBNNoAssignmentReasons =
        CASE
            WHEN ISNULL(LTRIM(RTRIM(tgt.DBNNoAssignmentReasons)), '') = ''
                THEN ' || ' + @RID4
            WHEN tgt.DBNNoAssignmentReasons LIKE '%RID4%'
                THEN tgt.DBNNoAssignmentReasons
            ELSE tgt.DBNNoAssignmentReasons + '; ' + ' || ' + @RID4
        END
    FROM dbo.RPT_T5TargetStudents_WT tgt
    INNER JOIN dbo.RPT_T5newAssignments_WT n
        ON n.StudentID = tgt.StudentID
    LEFT JOIN #StopStudents st ON st.StudentID = tgt.StudentID
    WHERE st.StudentID IS NULL
      AND n.DBNPriorityType IN ('NEARDBN-LngMatchNSib','NEARDBN-LngMatchSib');

    INSERT INTO #StopStudents(StudentID)
    SELECT DISTINCT n.StudentID
    FROM dbo.RPT_T5newAssignments_WT n
    LEFT JOIN #StopStudents st ON st.StudentID = n.StudentID
    WHERE st.StudentID IS NULL
      AND n.DBNPriorityType IN ('NEARDBN-LngMatchNSib','NEARDBN-LngMatchSib');

    -------------------------------------------------------------------------
    -- Monolingual/general zoned capacity: RID1 for NEAR-Mono / NEAR-BiAsMono then stop
    -------------------------------------------------------------------------
    UPDATE tgt
    SET DBNNoAssignmentReasons =
        CASE
            WHEN ISNULL(LTRIM(RTRIM(tgt.DBNNoAssignmentReasons)), '') = ''
                THEN ' || ' + @RID1
            WHEN tgt.DBNNoAssignmentReasons LIKE '%RID1%'
                THEN tgt.DBNNoAssignmentReasons
            ELSE tgt.DBNNoAssignmentReasons + '; ' + ' || ' + @RID1
        END
    FROM dbo.RPT_T5TargetStudents_WT tgt
    INNER JOIN dbo.RPT_T5newAssignments_WT n
        ON n.StudentID = tgt.StudentID
    LEFT JOIN #StopStudents st ON st.StudentID = tgt.StudentID
    WHERE st.StudentID IS NULL
      AND n.DBNPriorityType IN ('NEAR-Mono', 'NEAR-BiAsMono');

    INSERT INTO #StopStudents(StudentID)
    SELECT DISTINCT n.StudentID
    FROM dbo.RPT_T5newAssignments_WT n
    LEFT JOIN #StopStudents st ON st.StudentID = n.StudentID
    WHERE st.StudentID IS NULL
      AND n.DBNPriorityType IN ('NEAR-Mono', 'NEAR-BiAsMono');

    ------------------------------------------------------------------------- 
    -- Multi-Zoned ZONEDBN logic (apply only if not stopped)
    -------------------------------------------------------------------------
    ;WITH MultiZoned AS
    (
        SELECT
              s.StudentID
            , COUNT(DISTINCT p.DBNPriority) AS ZonedCnt
            , MAX(CASE WHEN p.DBNPriority = s.AssignedSchoolDBN THEN 1 ELSE 0 END) AS HasZonedMatch
            , MAX(CASE WHEN isnull(ts.StudentLanguageCategory, '') in ('POS', 'NonPOS') THEN 1 ELSE 0 END) AS IsBilingual
        FROM  SEO_MART.dbo.RPT_T5newAssignments_WT s
        JOIN  SEO_MART.dbo.RPT_T5StudentSchoolPriorities p
              ON p.StudentID       = s.StudentID
             AND p.DBNPriorityType = 'ZONEDBN'
             AND p.DBNPriority     IS NOT NULL
        inner join RPT_T5TargetStudents_WT ts on s.StudentID = ts.StudentID 
        GROUP BY s.StudentID
        HAVING COUNT(DISTINCT p.DBNPriority) >= 1
           AND MAX(CASE WHEN p.DBNPriority = s.AssignedSchoolDBN THEN 1 ELSE 0 END) = 0
    )
    UPDATE tgt
    SET DBNNoAssignmentReasons =
        CASE
            WHEN tgt.DBNNoAssignmentReasons IS NOT NULL
                THEN tgt.DBNNoAssignmentReasons
            ELSE
                CASE WHEN mz.IsBilingual = 1
                     THEN ' || ' + @RID4
                     ELSE ' || ' + @RID1
                END
        END
    FROM dbo.RPT_T5TargetStudents_WT tgt
    JOIN MultiZoned mz ON mz.StudentID = tgt.StudentID
    LEFT JOIN #StopStudents st ON st.StudentID = tgt.StudentID
    WHERE st.StudentID IS NULL;

    -------------------------------------------------------------------------
    -- CSE tail logic: ensure RID1 + RID2 (+ RID3 when Assigned <> HomeCSE)
    -------------------------------------------------------------------------
    UPDATE tgt
    SET DBNNoAssignmentReasons =
        (CASE
            WHEN ISNULL(LTRIM(RTRIM(tgt.DBNNoAssignmentReasons)), '') = ''
                THEN ' || ' + @RID1
            ELSE tgt.DBNNoAssignmentReasons
         END)
        + CASE
            WHEN ISNULL(LTRIM(RTRIM(tgt.DBNNoAssignmentReasons)), '') <> ''
                 AND tgt.DBNNoAssignmentReasons NOT LIKE '%RID1%'
                THEN '; ' + ' || ' + @RID1
            ELSE ''
          END
        + CASE
            WHEN tgt.DBNNoAssignmentReasons NOT LIKE '%RID2%'
                THEN '; ' + ' || ' + @RID2
            ELSE ''
          END
        + CASE
            WHEN hc.HomeCSE IS NOT NULL
             AND s.AssignedSchoolDBN <> hc.HomeCSE
             AND tgt.DBNNoAssignmentReasons NOT LIKE '%RID3%'
                THEN '; ' + ' || ' + @RID3
            ELSE ''
          END
    FROM dbo.RPT_T5TargetStudents_WT tgt
    JOIN SEO_MART.dbo.RPT_T5newAssignments_WT s
      ON s.StudentID  = tgt.StudentID
    LEFT JOIN #HomeCSE hc ON hc.StudentID = tgt.StudentID
    LEFT JOIN #StopStudents st ON st.StudentID = tgt.StudentID
    left join RPT_T5tfDBNCapacity_WT dbn on s.AssignedSchoolDBN = dbn.SchoolDBN 
    WHERE st.StudentID IS NULL
      AND dbn.SchoolType = 'CSE'
      AND (
            tgt.DBNNoAssignmentReasons LIKE '%RID1%'
         OR tgt.DBNNoAssignmentReasons LIKE '%RID4%'
          );

    -------------------------------------------------------------------------
    -- Prefix reasons with KZonedESDBN for “zoned” cases
    -------------------------------------------------------------------------
    ;WITH DistinctZoned AS
    (
        SELECT DISTINCT
            s.StudentID,
            zs.KZonedESDBN
        FROM SEO_MART.dbo.RPT_T5newAssignments_WT s
        INNER JOIN SEO_MART.dbo.INT_T5StudentZoneSchool zs
            ON zs.StudentID  = s.StudentID
           AND zs.SchoolYear = @SchoolYear
        WHERE 1 = 1 
          AND ISNULL(s.AssignedSchoolDBN, '') <> ISNULL(zs.KZonedESDBN, '')
    ),
    Zoned AS
    (
        SELECT StudentID, STRING_AGG(KZonedESDBN, ',') AS KZonedDBNs
        FROM DistinctZoned
        GROUP BY StudentID
    )
    UPDATE tgt
    SET DBNNoAssignmentReasons =
        CASE
            WHEN tgt.DBNNoAssignmentReasons LIKE '% - RID%'
                THEN tgt.DBNNoAssignmentReasons
            ELSE z.KZonedDBNs + ' - ' + tgt.DBNNoAssignmentReasons
        END
    FROM dbo.RPT_T5TargetStudents_WT tgt
    INNER JOIN Zoned z ON z.StudentID = tgt.StudentID
    WHERE ISNULL(LTRIM(RTRIM(tgt.DBNNoAssignmentReasons)), '') <> ''
      AND (
            tgt.DBNNoAssignmentReasons LIKE '%RID1%'
         OR tgt.DBNNoAssignmentReasons LIKE '%RID2%'
         OR tgt.DBNNoAssignmentReasons LIKE '%RID3%'
         OR tgt.DBNNoAssignmentReasons LIKE '%RID4%'
         OR tgt.DBNNoAssignmentReasons LIKE '%RID5%'
          )
      AND tgt.DBNNoAssignmentReasons NOT LIKE '%RID7%'
      AND tgt.DBNNoAssignmentReasons NOT LIKE '%RID12%';
END
