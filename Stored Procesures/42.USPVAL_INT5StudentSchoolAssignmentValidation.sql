USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPVAL_INT5StudentSchoolAssignmentValidation]    Script Date: 4/4/2026 4:22:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/************************************************************************************************************************************************************************
Object Name: USPVAL_INT5StudentSchoolAssignmentValidation
Purpose:	This procedure validates INT_T5StudentSchoolAssignment data load per BRD
Date Created: 10/09/2024

Modification Details:
Author				ModifiedDate		Comments
Christopher Agwu	10/09/2024			Initial version
Christopher Agwu	01/10/2025			Replace validation #9 RPT_T5SR with INT_T5WaveStudentsEligibility. This is bcos Elig students SR migth be diff in INT_WaveElig.
Charlotte Wang      10/28/2025          #Charlotte: (1) Add overall check that all students in RPT_T5StudentSchoolPriorities (current wave) made it into INT_T5SSA (with counts).
                                        #Charlotte: (2) Simplify SSP checks to only verify StudentCategory ↔ AssignedSchoolDBN location correctness (with counts).
                                        #Charlotte: (3) Keep siblings / over-assignment checks; comment out detailed category property tests (E27, E28, E29, E32, E34, E35–E39).
Charlotte Wang		12/03/2025			Fixed validation for Charter students. Before Validation was looking for assignment to ATSSchoolDBN. 
										Charter students are assigned to CSEs. so, I changed validation to look for CSE assignment.
Charlotte Wang		02/13/2025			Charter added a few validations
										1. Check D75 and DV are assigned to CSEs
										2. Check StudentCategory and AssignmentPriorityType align in INT_T5SSA
										3. Accept Sibling assignments to previously-overassigned-DBNs.
											Non-Sibling assignments to previously-overassigned-DBNs are a failure
										4. Capture over assignments resulting from current wave
Charlotte Wang      03/17/2026          Log DBN / DBN-Language over-assignment detail for validation notifications (#9 and #10).
***************************************************************************************************************************************************************************/
ALTER PROCEDURE [dbo].[USPVAL_INT5StudentSchoolAssignmentValidation]
AS
BEGIN
	SET NOCOUNT ON;

	Declare 
		  @SourceCNT INT
		, @DestCNT INT
		, @T5BDYear INT
		, @Today DATE
		, @IsValDone SMALLINT
		, @IsValOverride SMALLINT
		, @WaveID INT
		, @MsgModifier VARCHAR(50)
		, @ValStatus VARCHAR(4)
		, @ValKey INT
		, @ValidationMsgs VARCHAR(2000)   -- Charlotte: grow buffer
		, @ValHeader VARCHAR(120)
        , @MissingInSSA INT               -- Charlotte: counts for new checks
        , @ASLWrong INT
        , @CSETrueWrong INT
        , @TopBottomWrong INT
        , @CharterWrong INT

		, @OverAssignDBNCnt int
		, @OverAssignINTTotal int
		, @OverAssignOverageSum int
		, @D75Wrong INT
        , @DVWrong INT
        , @CatMapWrong INT
        , @HasWarn BIT
        , @WarnMsg VARCHAR(1000)
		, @DBNDetailMsg VARCHAR(MAX)
		, @DBNLangDetailMsg VARCHAR(MAX);


	SET @Today = GETDATE();
	SET @ValHeader='INT_T5StudentSchoolAssignment Validation.';
	SET @ValKey=147001;
	SET @ValStatus='BEG';
	SET @ValidationMsgs = CONCAT('Starting ', @ValHeader);
	SET @WaveID = (SELECT WaveID FROM dbo.INT_T5WaveSchedule WHERE WaveStatus='I');

	--get/check validation overrideID
	SET @IsValDone = 2;
	SET @IsValOverride = (
		SELECT ValOverrideID
		FROM dbo.SEODataValidationOutcome
		WHERE ValKey=@ValKey AND ValOverrideID=1 AND CAST(CreatedDatetime AS DATE)=@Today
	);

	IF @IsValOverride = 1
	BEGIN
		SET @ValHeader = @ValHeader + ' - Overridden - ';
		SET @ValStatus = 'OVERRIDE';

		UPDATE dbo.SEODataValidationOutcome 
			SET ValOverrideID=@IsValDone,
			    ModifiedDateTime=GETDATE(),
			    ModifiedBy=SYSTEM_USER
		WHERE ValKey=@ValKey AND ValOverrideID=1 AND CAST(CreatedDatetime AS DATE)=@Today;				
		GOTO OverrideValidation;
	END;

	--Start validation
	EXEC dbo.USPSEO_DataValidationOutcomeINS @ValStatus, @ValKey, @ValidationMsgs;
	SET @ValidationMsgs = '';

	/* ----------------------------------------------------------------------------------------------------
	   Charlotte: NEW OVERALL CHECK — “All SSP students made it into INT_T5SSA”
	   Definition:
	    - Universe = RPT_T5StudentSchoolPriorities for the current Wave (@WaveID)
	    - Must exist in INT_T5StudentSchoolAssignment for the same Wave (@WaveID)
	   FAIL if any are missing; include count in message.
	   ---------------------------------------------------------------------------------------------------- */
	SELECT @MissingInSSA = COUNT(*)
	FROM dbo.RPT_T5StudentSchoolPriorities SSP
	WHERE SSP.WaveID = @WaveID
	  AND NOT EXISTS (
			SELECT 1
			FROM dbo.INT_T5StudentSchoolAssignment SSA
			WHERE SSA.WaveID = SSP.WaveID
			  AND SSA.StudentID = SSP.StudentID
	  );

	IF ISNULL(@MissingInSSA,0) > 0
	BEGIN
		SET @ValStatus='FAIL';
		SET @ValidationMsgs = CONCAT(@ValidationMsgs,
			'1: ', @MissingInSSA, ' student(s) found in RPT_T5StudentSchoolPriorities but missing in INT_T5StudentSchoolAssignment for WaveID=', @WaveID, '. '
		);
	END;

    /* ----------------------------------------------------------------------------------------------------
       Charlotte: NEW VALIDATION — StudentCategory ↔ AssignmentPriorityType mapping
       Source of truth for D75/DV/Charter is SSA.StudentCategory (INT_T5StudentSchoolAssignment)
       Mapping provided:
          D75              -> SpecialPopulation
          DV               -> SpecialPopulation
          Charter          -> SpecialPopulation
          CSETrueInitial   -> SpecialPopulation
          TopBottom        -> SpecialPopulation
          DHS              -> DHS
          ASL              -> ASL
          Monolingual      -> Monolingual
          BilingualNotPOS  -> BilingualNotPOS
          BilingualInPOS   -> BilingualInPOS
       FAIL if any mismatch.
       ---------------------------------------------------------------------------------------------------- */

    SELECT
        @CatMapWrong = COUNT(*)
    FROM dbo.INT_T5StudentSchoolAssignment SSA WITH (NOLOCK)
    WHERE SSA.WaveID = @WaveID
	and 
	(
		ISNULL(SSA.StudentCategory,'') = ''
		OR
		ISNULL(SSA.AssignmentPriorityType,'') = ''
		OR
		NOT 
		(
			(
				SSA.StudentCategory in ('D75', 'DV', 'Charter', 'CSETrueInitial', 'TopBottom' )
				and SSA.AssignmentPriorityType = 'SpecialPopulation' 
			)
			OR
			SSA.StudentCategory = SSA.AssignmentPriorityType
		)
	)

    IF ISNULL(@CatMapWrong,0) > 0
    BEGIN
        SET @ValStatus='FAIL';
        SET @ValidationMsgs = CONCAT(@ValidationMsgs,
            '1M: ', @CatMapWrong, ' row(s) have StudentCategory ↔ AssignmentPriorityType mismatch in INT_T5StudentSchoolAssignment. '
        );
    END;

	/* ----------------------------------------------------------------------------------------------------
	   Charlotte: NEW SIMPLIFIED CATEGORY↔ASSIGNMENT LOCATION CHECKS
	   For students present in both SSP and SSA (current wave):
	     - ASL           → AssignedSchoolDBN must be '02M347'
	     - CSETrueInitial→ must be a CSE placement (we treat as AssignedSchoolDBN LIKE '%CS%' OR SchoolDBNType='CSE')
	     - TopBottom     → same “CSE” rule as above
	     - Charter       → AssignedSchoolDBN LIKE '84%'
	   Notes:
	     • If your schema has a reliable SchoolDBNType, we check it, otherwise we fallback to DBN pattern.
	     • You can extend this map with more categories later if needed.
	   FAIL per category with counts.
	   ---------------------------------------------------------------------------------------------------- */
	;WITH BothSides AS (
		SELECT 
			SSP.StudentID,
			SSP.StudentCategory,
			SSA.AssignedSchoolDBN,
			SSA.SchoolDBNType   -- nullable in some schemas; used if available
		FROM dbo.RPT_T5StudentSchoolPriorities SSP
		INNER JOIN dbo.INT_T5StudentSchoolAssignment SSA
			ON SSA.WaveID = SSP.WaveID
		   AND SSA.StudentID = SSP.StudentID
		WHERE SSP.WaveID = @WaveID
	)
	SELECT
		@ASLWrong = SUM(CASE WHEN StudentCategory='ASL' 
		                      AND ISNULL(AssignedSchoolDBN,'') <> '02M347' THEN 1 ELSE 0 END),
		@CSETrueWrong = SUM(CASE WHEN StudentCategory='CSETrueInitial'
		                          AND NOT (
		                              ISNULL(SchoolDBNType,'') = 'CSE'
		                              OR ISNULL(AssignedSchoolDBN,'') LIKE '%CS%'
		                          ) THEN 1 ELSE 0 END),
		@TopBottomWrong = SUM(CASE WHEN StudentCategory='TopBottom'
		                            AND NOT (
		                                ISNULL(SchoolDBNType,'') = 'CSE'
		                                OR ISNULL(AssignedSchoolDBN,'') LIKE '%CS%'
		                            ) THEN 1 ELSE 0 END),
		@CharterWrong = SUM(CASE WHEN StudentCategory='Charter'
		                           AND NOT (
		                                ISNULL(SchoolDBNType,'') = 'CSE'
		                                OR ISNULL(AssignedSchoolDBN,'') LIKE '%CS%'
		                            ) THEN 1 ELSE 0 END),

        -- D75 categories are driven from SSA.StudentCategory per request
        @D75Wrong = SUM(CASE WHEN ISNULL(StudentCategory,'') = 'D75'
                                AND NOT (
                                    ISNULL(SchoolDBNType,'') = 'CSE'
                                    OR ISNULL(AssignedSchoolDBN,'') LIKE '%CS%'
                                ) THEN 1 ELSE 0 END),
        -- DV categories are driven from SSA.StudentCategory per request
        @DVWrong = SUM(CASE WHEN ISNULL(StudentCategory,'') = 'DV'
                                AND NOT (
                                    ISNULL(SchoolDBNType,'') = 'CSE'
                                    OR ISNULL(AssignedSchoolDBN,'') LIKE '%CS%'
                                ) THEN 1 ELSE 0 END)
	FROM BothSides;

	IF ISNULL(@ASLWrong,0) > 0
	BEGIN
		SET @ValStatus='FAIL';
		SET @ValidationMsgs = CONCAT(@ValidationMsgs,
			'2: ', @ASLWrong, ' ASL student(s) not assigned to 02M347. '
		);
	END;

	IF ISNULL(@CSETrueWrong,0) > 0
	BEGIN
		SET @ValStatus='FAIL';
		SET @ValidationMsgs = CONCAT(@ValidationMsgs,
			'3: ', @CSETrueWrong, ' CSETrueInitial student(s) not assigned to a CSE DBN (type=CSE or DBN LIKE ''%CS%''). '
		);
	END;

	IF ISNULL(@TopBottomWrong,0) > 0
	BEGIN
		SET @ValStatus='FAIL';
		SET @ValidationMsgs = CONCAT(@ValidationMsgs,
			'4: ', @TopBottomWrong, ' TopBottom student(s) not assigned to a CSE DBN (type=CSE or DBN LIKE ''%CS%''). '
		);
	END;

	IF ISNULL(@CharterWrong,0) > 0
	BEGIN
		SET @ValStatus='FAIL';
		SET @ValidationMsgs = CONCAT(@ValidationMsgs,
			'5: ', @CharterWrong, ' Charter student(s) not assigned to a CSE DBN (type=CSE or DBN LIKE ''%CS%''). '
		);
	END;

    IF ISNULL(@D75Wrong,0) > 0
    BEGIN
        SET @ValStatus='FAIL';
        SET @ValidationMsgs = CONCAT(@ValidationMsgs,
            '6: ', @D75Wrong, ' D75 student(s) not assigned to a CSE DBN (required). Notify business users. '
        );
    END;

    IF ISNULL(@DVWrong,0) > 0
    BEGIN
        SET @ValStatus='FAIL';
        SET @ValidationMsgs = CONCAT(@ValidationMsgs,
            '7: ', @DVWrong, ' DV student(s) not assigned to a CSE DBN (required). Notify business users. '
        );
    END;

	/* ----------------------------------------------------------------------------------------------------
	   Charlotte: SIMPLIFICATION — Comment out detailed category property checks (kept for history)
	   E27, E28, E29, E32, E34, E35–E39
	   ---------------------------------------------------------------------------------------------------- */

	/*
	--Test-E27-- ... (commented out by Charlotte on 2025-10-28)
	--Test-E28-- ... (commented out by Charlotte on 2025-10-28)
	--Test-E29-- ... (commented out by Charlotte on 2025-10-28)
	--Test-E32-- ... (commented out by Charlotte on 2025-10-28)
	--Test-E34-- ... (commented out by Charlotte on 2025-10-28)
	--Test-E35-- ... (commented out by Charlotte on 2025-10-28)
	--Test-E37-- ... (commented out by Charlotte on 2025-10-28)
	--Test-E39-- ... (commented out by Charlotte on 2025-10-28)
	*/

	--Test E42 (keep): Siblings group assigned consistently; counts per sibling group should match across SR/SSP/SSA
	;WITH tSSA AS (
		SELECT SiblingKey AS SSASiblingKey, AssignedSchoolDBN AS SSAAssignedSchoolDBN, COUNT(*) AS SSAcnt
		FROM dbo.INT_T5StudentSchoolAssignment
		WHERE IsSibling=1 AND WaveID=@WaveID
		GROUP BY SiblingKey, AssignedSchoolDBN
	),	
	tSSP AS (				
		SELECT SiblingKey AS SSPSiblingKey, COUNT(DISTINCT StudentID) AS SSPcnt
		FROM dbo.RPT_T5StudentSchoolPriorities
		WHERE IsSibling=1 AND WaveID=@WaveID
		GROUP BY SiblingKey
	),
	tSR AS (		
		SELECT SiblingKey AS SRSiblingKey, COUNT(*) AS SRcnt
		FROM dbo.INT_T5WaveEligibleStudents
		WHERE IsSibling=1 AND IsTurning5=1 AND WaveProcessedDate IS NULL
		GROUP BY SiblingKey
	)
	SELECT tSR.SRSiblingKey, tSR.SRcnt, tSSP.SSPcnt, tSSA.SSAcnt,	
	       CASE WHEN tSR.SRcnt=tSSP.SSPcnt AND tSR.SRcnt=tSSA.SSAcnt THEN 1 ELSE 0 END AS IsMatch
	INTO #tblF
	FROM tSR
	INNER JOIN tSSP ON tSSP.SSPSiblingKey = tSR.SRSiblingKey
	INNER JOIN tSSA ON tSSA.SSASiblingKey = tSR.SRSiblingKey;
	
	SET @SourceCNT = (SELECT COUNT(*) FROM #tblF WHERE IsMatch=0);
	IF (@SourceCNT<>0)
	BEGIN
		SET @ValStatus='FAIL';
		SET @ValidationMsgs = CONCAT(@ValidationMsgs,
			'8: ', @SourceCNT, ' sibling group(s) have inconsistent counts across SR/SSP/SSA. '
		)
	END;

	--Test F59 (keep): Over-assignments due to KIP assignment
	--BEGIN: We should not assign to those DBNs that had 
	--overassignment prior to the current wave, except for Sibling assignments
	drop table if exists #WaveAssignments_into_PreviouslyOverAssignedDBNs
	SELECT curr.AssignedSchoolDBN, 
		curr.[Assigned During Current Wave],
		prev.CaseAssignmentCapacity as 'Total Capacity Prior to Wave', 
		prev.AssignedCapacity as 'Assigned Capaity Prior to Wave'
	INTO #WaveAssignments_into_PreviouslyOverAssignedDBNs
	FROM (
		select AssignedSchoolDBN, count(*) as 'Assigned During Current Wave'
		from dbo.INT_T5StudentSchoolAssignment curr
		where WaveID = 7
		and DBNPriorityType <> 'SIBLINGDBN'
		group by AssignedSchoolDBN
	) curr
	inner join
		--previously over-assigned DBNs
		(
			SELECT 
				a.SchoolDBN,
				--a.schoolType,
				a.CaseAssignmentCapacity,
				a.AssignedCapacity
				--(a.AssignedCapacity - a.CaseAssignmentCapacity) AS OverAssigned,
				--a.availablecapacity,
				--a.ProcessedDate
			FROM dbo.vwRPT_T5CaseAssignmentCapacity a WITH(NOLOCK)
			WHERE a.CaseAssignmentCapacity < a.AssignedCapacity
		) prev
		on curr.AssignedSchoolDBN = prev.SchoolDBN

	drop table if exists #WaveAssignments_into_PreviouslyOverAssignedDBNLangs
	SELECT curr.AssignedSchoolDBN, 
		curr.AssignmentLanguage, 
		curr.[Assigned During Current Wave],
		prev.CaseAssignmentCapacity as 'Total Capacity Prior to Wave', 
		prev.AssignedCapacity as 'Assigned Capaity Prior to Wave'
	INTO #WaveAssignments_into_PreviouslyOverAssignedDBNLangs
	FROM (
		select AssignedSchoolDBN, AssignmentLanguage, count(*) as 'Assigned During Current Wave'
		from dbo.INT_T5StudentSchoolAssignment curr
		where WaveID = 7
		and DBNPriorityType <> 'SIBLINGDBN'
		group by AssignedSchoolDBN, AssignmentLanguage
	) curr
	inner join
		--previously over-assigned DBN-Languages
		(
			SELECT 
				a.SchoolDBN,
				a.Language,
				a.CaseAssignmentCapacity,
				a.AssignedCapacity
			FROM dbo.vwRPT_T5CaseAssignmentCapacityByDBNAndLanguage a WITH(NOLOCK)
			WHERE a.CaseAssignmentCapacity < a.AssignedCapacity
		) prev
	on curr.AssignedSchoolDBN = prev.SchoolDBN
	and curr.AssignmentLanguage = prev.Language

	set @SourceCNT = 0

	SELECT @SourceCNT = SUM([Assigned During Current Wave])
	FROM #WaveAssignments_into_PreviouslyOverAssignedDBNs
	
	IF ISNULL(@SourceCNT,0) <> 0
	BEGIN

		SET @ValStatus='FAIL';

		SET @DBNDetailMsg = NULL;
		SET @DBNLangDetailMsg = NULL;

		SELECT @DBNDetailMsg =
			STUFF((
				SELECT '; DBN=' + P.AssignedSchoolDBN
					 + '(Total=' + CAST(P.[Total Capacity Prior to Wave] AS VARCHAR(20))
					 + ',UsedBefore=' + CAST(P.[Assigned Capaity Prior to Wave] AS VARCHAR(20))
					 + ',Wave=' + CAST(P.[Assigned During Current Wave] AS VARCHAR(20))
					 + ',Over=' + CAST(P.[Total Capacity Prior to Wave] - (p.[Assigned Capaity Prior to Wave] + p.[Assigned During Current Wave]) AS VARCHAR(20)) + ')'
				FROM #WaveAssignments_into_PreviouslyOverAssignedDBNs P
				FOR XML PATH(''), TYPE
			).value('.','varchar(max)'),1,2,'');

		SELECT @DBNLangDetailMsg =
			STUFF((
				SELECT '; DBN=' + L.AssignedSchoolDBN
					 + ',Lang=' + ISNULL(NULLIF(L.[Language],''),'NA')
					 + '(Total=' + CAST(L.[Total Capacity Prior to Wave] AS VARCHAR(20))
					 + ',UsedBefore=' + CAST(L.[Assigned Capaity Prior to Wave] AS VARCHAR(20))
					 + ',Wave=' + CAST(L.[Assigned During Current Wave] AS VARCHAR(20))
					 + ',Over=' + CAST((L.[Total Capacity Prior to Wave] - (L.[Assigned Capaity Prior to Wave] + L.[Assigned During Current Wave])) AS VARCHAR(20)) + ')'
				FROM #WaveAssignments_into_PreviouslyOverAssignedDBNLangs L
				FOR XML PATH(''), TYPE
			).value('.','varchar(max)'),1,2,'');

		SET @ValidationMsgs = CONCAT(@ValidationMsgs,
			'9: Wave ', CAST(@WaveID AS VARCHAR), ' current wave assignments to Prior-Overassigned-DBNs total = ', @SourceCNT, '. ',
			CASE WHEN ISNULL(@DBNDetailMsg,'')<>'' THEN CONCAT('DBN Level[',@DBNDetailMsg,']. ') ELSE '' END,
			CASE WHEN ISNULL(@DBNLangDetailMsg,'')<>'' THEN CONCAT('DBN-Language Level[',@DBNLangDetailMsg,']. ') ELSE '' END
		);

	END;
	--END: We should not assign to those DBNs that had 
	--overassignment prior to the current wave, except for Sibling assignments
		
	--BEGIN: Current Wave leads to overassignment
    /* ----------------------------------------------------------------------------------------------------
	   Charlotte (MIS-14916): NEW CAPACITY VALIDATION (matches manual pre-run check)
	     - Compare INT assigned count (current run) + vwRPT_T5CaseAssignmentCapacity.AssignedCapacity
	       against CaseAssignmentCapacity
	     - Do at overall AssignedSchoolDBN level
	     - Exclude DBNPriorityType = 'SIBLINGDBN' (siblings can be assigned regardless of capacity)
	   Notes:
	     - vwRPT_T5CaseAssignmentCapacity.AssignedCapacity is "not refreshed w/INT assignments until after RPT run",
	       so we explicitly add the INT counts here.
	     - This is intentionally scoped to DBNs where INT has assignments (AssignedINT_cnt > 0), same as manual query.
	     - This does NOT attempt to exclude over-assignments due to reassignment or post-assignment POS days decrease,
	       because those conditions are not represented in INT_T5SSA. The manual check's key intent (pre-RPT refresh
	       combined total) is implemented here.
       ---------------------------------------------------------------------------------------------------- */
    IF OBJECT_ID('tempdb..#OverAssignedPop') IS NOT NULL DROP TABLE #OverAssignedPop;

	SELECT
        c.SchoolDBN,
        c.CaseAssignmentCapacity,
        c.AssignedCapacity,
        c.AssignedINT_cnt,
        c.TotalAssigned,
        (c.TotalAssigned - c.CaseAssignmentCapacity) AS OverAssignedByTotal
    INTO #OverAssignedPop
    FROM
    (
        SELECT
            a.SchoolDBN,
            a.CaseAssignmentCapacity,
            a.AssignedCapacity,
            ISNULL(b.AssignedINT_cnt,0) AS AssignedINT_cnt,
            (a.AssignedCapacity + ISNULL(b.AssignedINT_cnt,0)) AS TotalAssigned
        FROM dbo.vwRPT_T5CaseAssignmentCapacity a WITH(NOLOCK)
        JOIN
        (
            SELECT
                AssignedSchoolDBN,
                COUNT(*) AS AssignedINT_cnt
            FROM dbo.INT_T5StudentSchoolAssignment WITH(NOLOCK)
            WHERE WaveID = @WaveID
              AND DBNPriorityType <> 'SIBLINGDBN'
            GROUP BY AssignedSchoolDBN
        ) b
            ON a.SchoolDBN = b.AssignedSchoolDBN
    ) c
    WHERE c.TotalAssigned > c.CaseAssignmentCapacity
      AND c.AssignedINT_cnt > 0
    ORDER BY c.SchoolDBN;

    SELECT
        @OverAssignDBNCnt   = COUNT(*),
        @OverAssignINTTotal = ISNULL(SUM(AssignedINT_cnt),0),
        @OverAssignOverageSum = ISNULL(SUM(CASE WHEN TotalAssigned > CaseAssignmentCapacity
                                                THEN (TotalAssigned - CaseAssignmentCapacity)
                                                ELSE 0 END),0)
    FROM #OverAssignedPop;

	IF OBJECT_ID('tempdb..#OverAssignedPopLang') IS NOT NULL 
	DROP TABLE #OverAssignedPopLang;
	SELECT
		C.SchoolDBN AS DBN,
		C.[Language],
		C.CaseAssignmentCapacity AS TotalCapacity,
		C.AssignedCapacity AS AssignedCountBeforeWave,
		b.AssignedINT_cnt,
		(C.AssignedCapacity + b.AssignedINT_cnt) AS TotalAssigned,
		((C.AssignedCapacity + b.AssignedINT_cnt) - C.CaseAssignmentCapacity) AS OverAssignmentCount
	INTO #OverAssignedPopLang
	FROM dbo.vwRPT_T5CaseAssignmentCapacityByDBNAndLanguage C WITH(NOLOCK)
	INNER JOIN
        (
            SELECT
                AssignedSchoolDBN, AssignmentLanguage,
                COUNT(*) AS AssignedINT_cnt
            FROM dbo.INT_T5StudentSchoolAssignment WITH(NOLOCK)
            WHERE WaveID = @WaveID
              AND DBNPriorityType <> 'SIBLINGDBN'
            GROUP BY AssignedSchoolDBN, AssignmentLanguage
        ) b
            ON C.SchoolDBN = b.AssignedSchoolDBN
		   AND TRIM(ISNULL(b.AssignmentLanguage, '')) = TRIM(ISNULL(C.[Language],''))
	WHERE (C.AssignedCapacity + b.AssignedINT_cnt) > C.CaseAssignmentCapacity

    IF ISNULL(@OverAssignDBNCnt,0) > 0
    BEGIN

		SET @DBNDetailMsg = NULL;
		SET @DBNLangDetailMsg = NULL;

		SELECT @DBNDetailMsg =
			STUFF((
				SELECT '; DBN=' + P.SchoolDBN
					 + '(Total=' + CAST(P.CaseAssignmentCapacity AS VARCHAR(20))
					 + ',UsedBefore=' + CAST(P.AssignedCapacity AS VARCHAR(20))
					 + ',Wave=' + CAST(P.AssignedINT_cnt AS VARCHAR(20))
					 + ',Over=' + CAST(P.OverAssignedByTotal AS VARCHAR(20)) + ')'
				FROM #OverAssignedPop P
				FOR XML PATH(''), TYPE
			).value('.','varchar(max)'),1,2,'');

		SELECT @DBNLangDetailMsg =
			STUFF((
				SELECT '; DBN=' + L.DBN
					 + ',Lang=' + ISNULL(NULLIF(L.[Language],''),'NA')
					 + '(Total=' + CAST(L.TotalCapacity AS VARCHAR(20))
					 + ',UsedBefore=' + CAST(L.AssignedCountBeforeWave AS VARCHAR(20))
					 + ',Wave=' + CAST(L.AssignedINT_cnt AS VARCHAR(20))
					 + ',Over=' + CAST(L.OverAssignmentCount AS VARCHAR(20)) +')'
				FROM #OverAssignedPopLang L
				FOR XML PATH(''), TYPE
			).value('.','varchar(max)'),1,2,'');

        SET @ValStatus='FAIL';
        SET @ValidationMsgs = CONCAT(@ValidationMsgs,
            '10: Capacity over-assignment detected from current wave. Over-capacity DBNs=', @OverAssignDBNCnt,
            ', INT assigned (excl SIBLINGDBN)=', @OverAssignINTTotal,
            ', total OverAssignments=', @OverAssignOverageSum, '. ',
			CASE WHEN ISNULL(@DBNDetailMsg,'')<>'' THEN CONCAT('DBN Level[',@DBNDetailMsg,']. ') ELSE '' END,
			CASE WHEN ISNULL(@DBNLangDetailMsg,'')<>'' THEN CONCAT('DBN-Language Level[',@DBNLangDetailMsg,']. ') ELSE '' END
        );

    END;
	--END: Current Wave leads to overassignment

--Write final validation outcome---------------------------------------------------------------------------------	
OverrideValidation:
	IF @ValStatus='FAIL'
	BEGIN
		SET @ValidationMsgs = CONCAT(@ValHeader,' - ***Validation Errors!*** ', @ValidationMsgs);
		EXEC dbo.USPSEO_DataValidationOutcomeINS @ValStatus, @ValKey, @ValidationMsgs;
		RAISERROR (@ValidationMsgs,16,1);		
	END
	ELSE
	BEGIN
		SET @ValStatus='PASS';
		SET @ValidationMsgs = CONCAT(@ValHeader, ' Successful.');
		EXEC dbo.USPSEO_DataValidationOutcomeINS @ValStatus, @ValKey, @ValidationMsgs;
	END;	
END;
