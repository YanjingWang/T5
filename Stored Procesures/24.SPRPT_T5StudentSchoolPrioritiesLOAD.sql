USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPRPT_T5StudentSchoolPrioritiesLOAD]    Script Date: 4/4/2026 2:46:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
  
/*===============================================================================================================================================================  
Object Name: dbo.USPRPT_T5StudentSchoolPrioritiesLOAD  
Purpose: Executes USPRPT_T5StudentSchoolPrioritiesINS to populate   
   T5 Eligible students school priorities for wave processing.   
Date Created: 2/24/2023  
  
Modification Details:  
Author     ModifiedDate  Comments  
Christopher Agwu  3/15/2023   Initial   
Christopher Agwu  03/27/2023   Adding priority #6 per MIS-9043  
Christopher Agwu  04/26/2023   Modified code for newly restructured assignment priorities 1-7  
Christopher Agwu  05/11/2023   Modification to expand ASL students population per meeting with Alan.  
           ASL to include (SR.GuardianLanguage='SX' or AssessmentBilLangCode='SX')  
Christopher Agwu  06/23/2023   Added 6/23/2023. To find and update students/siblings with different categories and assignment priorities.  
           These siblings data will be updated with sibling with highest priority so their data is consistent for assignment  
Christopher Agwu  08/08/2023   Changed Charter students identification logic from %84X% to 84% per Ariel loggied in JIRA ticket MIS-9043  
Christopher Agwu  10/27/2023   Add new student category (CSETrueInitial). See JIRA ticket MIS-10050  
Christopher Agwu  10/31/2023   RPT_T5SR Students with differnet homedistrict, GuardianLanguage or address not matching students in JHZoning tbl resulting to students  
           not categorized correctly and not assigned to DBN.   
           Added (AND SR.HouseNumber=ES.HouseNumber) condition to (INTO #T5WaveStudents) create table  
Christopher Agwu  11/3/2023   Several siblings with different Assignment priorities got categorized to lower priorities.  
           Siblings with different priorities should be categorized to higher assignment priorites in RPT_T5SSP.  
           See JIRA ticket MIS-10087 for details. Completed 11/06/2023  
Christopher Agwu  11/7/2023   Student Eligibility data not matching JH INT_T5StudentZoneSchool data due to differences in   
           (HouseNumber,Street,CityName,Borough,Zipcode,HomeDistrict).  
           Will remove HouseNumber,Street,CityName,Borough,Zipcode JOIN and join only by StudentIS  
           See JIRA ticket MIS-10102  
Christopher Agwu  12/19/2023   Student HomeDistrict value should be sourced from JimHall zonning dataset instead of RPT_T5SSP table.  
           This is bcos JH has changed some students HomeDistrict hence will be needed to correctly process the student NEARESTDBN process  
           when required. See JIRA Ticket MIS-10313  
Christopher Agwu  03/05/2024   Modify HomeDistrict script to include CASE KZonedDistrictID. See JIRA ticket MIS-10707  
Christopher Agwu  05/17/2024   ASL is excluded whrb process CSEONLY wave. Add ASL process during CSEONLY process so ASL pop can be assigned to ASLDBN. Ticket MIS-11203  
Christopher Agwu  07/12/2024   Added code to lookup active waveid and remove code to start Wave processing from this SP. MIS-11231  
Christopher Agwu  10/22/2024   Move Archive code to bottom of SP - USPRPT_T5StudentSchoolPrioritiesLOAD to conform with SEOMart archiving process. MIS-12174  
           Add code to write end-of-process. MIS-12174  
Christopher Agwu  02/05/2025   Added SchoolYear to Archive table   
Christopher Agwu  05/01/2025   Add new DBNPriority Type for T5 Manual Wave Assignment and integrate Manual Wave process. MIS-13180  
Christopher Agwu  05/14/2025   Added filter to remove records without ReturnValueT5IEPTeam per meeting with Raji, Ariel. MIS-13180  
Christopher Agwu  10/30/2025   Removed FORMART Function due to change of HomeDistrict and KZoneDistrict data type from INT to Varchar(2). MIS-14450
=====================================================================================================================================================================================*/  
  
  
ALTER PROCEDURE [dbo].[USPRPT_T5StudentSchoolPrioritiesLOAD]  
   
AS  
  
Declare @ProcessedDate Date,@MaxArchiveDate Datetime, @YEAR1900 Date,@Today Datetime;  
DECLARE @EventHeader VARCHAR(150), @EventType VARCHAR(50);  
DECLARE @EventMessage VARCHAR(1500);   
  
Declare @CatID1ASL SMALLINT, @CatID2TopBottom SMALLINT, @CatID3D75 SMALLINT, @CatID4Charter SMALLINT, @CatID5DV SMALLINT;  
Declare @CatID6CSETInitial SMALLINT, @CatID7DHS SMALLINT, @CatID8BLInPOS SMALLINT, @CatID9BLNotPOS SMALLINT,@CatID10MonoL SMALLINT;  
Declare @StudentCategoryDesc Varchar(50), @StudentCategoryID SMALLINT  
  
BEGIN  
   
 SET @YEAR1900 = '1900-01-01';  
 SET @Today=getdate();  
 SET @ProcessedDate=getdate();  
   
 --Added 07/12/2024 MIS-11231  
 --Get waveid for this process  
 DECLARE @WaveID INT,@WaveDate Date, @WaveCount INT, @WaveDesc VARCHAR(150), @CSEOnlyFlag VARCHAR(1)  
  
 SET @WaveID=0  
 SET @CSEOnlyFlag=NULL  
 Select @WaveID=WaveID,@WaveDate=WaveDate,@WaveDesc=WaveDescription,@CSEOnlyFlag=CSEOnlyFlag from dbo.INT_T5WaveSchedule Where WaveStatus='I';  
 SET @EventType='T5Wave';  
 SET @EventHeader=CONCAT('Wave ',CONVERT(VARCHAR,@WaveID),' Process - USPRPT_T5StudentSchoolPrioritiesLOAD');  
  
 IF @WaveID=0  
 BEGIN  
  SET @EventMessage='Invalid Wave ID: 0, process cannot continue.'  
  EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;  
  RAISERROR(@EventMessage, 16, 1);  
  RETURN;  
 END;    
 SET @EventMessage='Start process Wave: ' + Convert(varchar,@WaveID) + ' - T5StudentSchoolPrioritiesLOAD.';  
 EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;  
   
  
 Declare @TotSC INT, @nxt INT  
 SET @TotSC=(Select count(*) From dbo.lk_T5SpecialCategories)  
 SET @nxt=1  
  
 WHILE (@nxt<=@TotSC)  
 BEGIN  
  Select @StudentCategoryID=StudentCategoryID,@StudentCategoryDesc=StudentCategoryDesc from dbo.lk_T5SpecialCategories Where StudentCategoryID=@nxt;  
  IF(@StudentCategoryDesc LIKE '%ASL%') SET @CatID1ASL=@StudentCategoryID;  
  IF(@StudentCategoryDesc LIKE '%Top%') SET @CatID2TopBottom=@StudentCategoryID;  
  IF(@StudentCategoryDesc LIKE '%D75%') SET @CatID3D75=@StudentCategoryID;  
  IF(@StudentCategoryDesc LIKE '%Charter%') SET @CatID4Charter=@StudentCategoryID;  
  IF(@StudentCategoryDesc LIKE '%DV%') SET @CatID5DV=@StudentCategoryID;  
  IF(@StudentCategoryDesc LIKE '%TrueI%') SET @CatID6CSETInitial=@StudentCategoryID;  
  IF(@StudentCategoryDesc LIKE '%DHS%') SET @CatID7DHS=@StudentCategoryID;  
  IF(@StudentCategoryDesc LIKE '%InPOS%') SET @CatID8BLInPOS=@StudentCategoryID;  
  IF(@StudentCategoryDesc LIKE '%NotPOS%') SET @CatID9BLNotPOS=@StudentCategoryID;  
  IF(@StudentCategoryDesc LIKE '%Mono%') SET @CatID10MonoL=@StudentCategoryID;   
  SET @nxt=@nxt+1;  
 END;  
  
  
 --clear table for new data  
 Truncate Table dbo.RPT_T5StudentSchoolPriorities;   
 ----------------------------------------------------------------------------------------  
  
 --Merge JH HomeDistrict with RPT_T5SR--12/19/2023 MIS-10313  
 DROP TABLE IF EXISTS #T5SRTemp;  
  
 --Create temp table - Added 05/01/2025  
 Select SR.*,CAST(NULL as varchar(2)) as ZHomeDistrict,CAST(NULL as varchar(20)) as NewHomeDistrict INTO #T5SRTemp  
 From dbo.RPT_T5StudentRegister SR Where 1=0;  
  
 IF @CSEOnlyFlag='M' --Manual Wave Assignment - Added 05/01/2025  
 BEGIN  
  INSERT INTO #T5SRTemp  
  Select SR.*,MA.HomeDistrict,(MA.HomeDistrict) as NewHomeDistrict    
  From dbo.RPT_T5StudentRegister SR  
  INNER JOIN (select StudentID,HomeDistrict from dbo.DWH_T5ManualWaveSchoolDBN Where WaveID=@WaveID and ReturnValueT5IEPTeam IS NOT NULL) MA  
  ON MA.StudentID=SR.StudentID  
  where SR.IsTurning5=1 and SR.WaveProcessedDate is NUll;   
 END  
 ELSE  
 BEGIN  
  INSERT INTO #T5SRTemp  
  Select SR.*, Z.ZHomeDistrict,  
  CASE WHEN ISNULL(Z.ZHomeDistrict,'0')='0' THEN SR.HomeDistrict  
  WHEN SR.HomeDistrict=Z.ZHomeDistrict THEN SR.HomeDistrict   
  ELSE Z.ZHomeDistrict END as NewHomeDistrict  
  From dbo.RPT_T5StudentRegister SR   
  LEFT JOIN (Select Distinct StudentID,Case When KZonedDistrictID IS NULL THEN HomeDistrict ELSE KZonedDistrictID End as ZHomeDistrict From dbo.INT_T5StudentZoneSchool) Z --(MIS-10707)  
  ON Z.StudentID=SR.StudentID  
  where SR.IsTurning5=1 and SR.WaveProcessedDate is nUll;  
 END;  
  
 --Get CSEDBN(s)  
 If OBJECT_ID ('Tempdb..#CSEDBN') is not null  
  Drop table #CSEDBN;  
  
 Select SchoolDBN,LocationCode,RIGHT(LocationCode,2) as CSECode   
 INTO #CSEDBN  
 From dbo.RPT_Locations Where LEFT(LocationCode,3) = 'CS0' OR LEFT(LocationCode,3)='CS1';  
 --------------------------------------------------------------------------------------------  
  
 --Added 11/06/2023--  
 --Get Unique student reg data  
 If OBJECT_ID('Tempdb..#tblStudentsByCats') IS NOT NULL  
  Drop Table #tblStudentsByCats;  
  
 --Rank students category/priority records in order of siblings higher priorities/categories    
 Select ROW_NUMBER() OVER (PARTITION BY T1.SiblingKey ORDER BY T1.StudentCatPriorityID) as CatPriorityIDRank,  
 T1.* INTO #tblStudentsByCats from (  
  Select CASE    
  WHEN (SR.ATSPrekSchoolDBN = '02M047' OR SR.GuardianLanguage='SX' OR SR.AssessmentBilLangCode='SX')  THEN @CatID1ASL  
  WHEN SR.ATSPrekSchoolDBN = '02M347' THEN @CatID1ASL  
  WHEN (SR.IsTop=1 OR SR.IsBottom=1) THEN @CatID2TopBottom  
  WHEN SR.D75Flag='Y' THEN @CatID3D75  
  WHEN SR.ATSPrekSchoolDBN LIKE '84%' THEN @CatID4Charter  
  WHEN SR.DHSDVFlag='DV' THEN @CatID5DV  
  WHEN SR.IsCSETrueInitial=1 THEN @CatID6CSETInitial  
  WHEN SR.DHSDVFlag='DHS' THEN @CatID7DHS  
  WHEN SR.IsBilingual=1 AND SR.IsPOSLanguage=1 THEN @CatID8BLInPOS  
  WHEN SR.IsBilingual=1 AND SR.IsPOSLanguage=0 THEN @CatID9BLNotPOS  
  WHEN SR.IsBilingual=0 THEN @CatID10MonoL  
  ELSE 0  
  END StudentCatPriorityID,  
  ES.StudentID,SR.SiblingKey,SR.IsSibling,SR.IsTop,SR.IsBottom,ES.IsTurning5,  
  SR.CSE,SR.ATSPrekSchoolDBN,SR.CaseType,SR.GuardianLanguage,SR.AssessmentBilLangCode,SR.NewHomeDistrict as HomeDistrict,SR.D75Flag,  
  SR.D75PhysicalDBN,SR.DHSDVFlag,SR.IsNoNameStreet,    
  SR.IsCSETrueInitial,SR.IsBilingual,SR.IsPOSLanguage,  
  SR.HouseNumber,SR.Street,SR.BoroughCode,SR.ZipCode,ES.WaveProcessedDate     
  FROM dbo.INT_T5WaveEligibleStudents ES  
  INNER JOIN dbo.#T5SRTemp SR   
  ON SR.StudentID=ES.StudentID  
  AND SR.HouseNumber=ES.HouseNumber    
  Where ES.IsTurning5=1 and ES.WaveProcessedDate IS NULL  
 ) T1;  
   
  
 --Updated 11/06/2023--  
 --Get all elig students and siblings records  
 If OBJECT_ID('Tempdb..#T5StudentRegisterElig') IS NOT NULL  
  Drop Table #T5StudentRegisterElig;  
   
 select DISTINCT SR.StudentCatPriorityID, CA.StudentID,  
  SR.SiblingKey,SR.IsSibling,SR.IsTop,SR.IsBottom,SR.IsTurning5,  
  SR.CSE, SR.ATSPrekSchoolDBN,SR.CaseType,SR.GuardianLanguage, SR.AssessmentBilLangCode,SR.HomeDistrict,SR.D75Flag,  
  SR.D75PhysicalDBN,SR.DHSDVFlag,SR.IsNoNameStreet,    
  SR.IsCSETrueInitial,SR.IsBilingual,SR.IsPOSLanguage,  
  SR.HouseNumber,SR.Street,SR.BoroughCode,SR.ZipCode,SR.WaveProcessedDate   
  INTO #T5StudentRegisterElig  
 From (Select * from #tblStudentsByCats Where CatPriorityIDRank=1) SR  
 CROSS APPLY (select DISTINCT StudentID from dbo.INT_T5WaveEligibleStudents where SiblingKey=SR.SiblingKey) CA;   
  
  
 --Get students eligible for T5wave  
 --Updated 11/06/2023--  
 If OBJECT_ID('Tempdb..#T5WaveStudents') IS NOT NULL  
  Drop Table #T5WaveStudents;  
  
 --NEW CODE--  
 Select SR.StudentCatPriorityID, ES.StudentID, SR.SiblingKey,SR.IsSibling,(SR.IsTop+SR.IsBottom) AS IsTopBottom,  
 CSS.SchoolDBN AS CSESchoolDBN,SR.CSE,  
 SR.ATSPrekSchoolDBN,   
 CASE WHEN SR.StudentCatPriorityID=@CatID1ASL THEN '02M347' ELSE NULL END ASLDBN,  
 SR.CaseType,SR.GuardianLanguage, SR.AssessmentBilLangCode,SR.HomeDistrict,SR.D75Flag,  
 CASE WHEN SR.StudentCatPriorityID=@CatID3D75 THEN SR.D75PhysicalDBN ELSE NULL END as D75PhysicalDBN,  
 SR.DHSDVFlag,SR.IsNoNameStreet,   
 CASE WHEN SR.StudentCatPriorityID=@CatID4Charter THEN 'Y' ELSE 'N' END CharterFlag,  
 SR.IsCSETrueInitial,  
 SR.IsBilingual,SR.IsPOSLanguage,  
 SR.HouseNumber,SR.Street,SR.BoroughCode,SR.ZipCode,  
 @WaveID as WaveID,  
 @WaveDate as WaveDate,  
 @ProcessedDate as ProcessedDate  
 INTO #T5WaveStudents   
 FROM dbo.INT_T5WaveEligibleStudents ES  
 INNER JOIN #T5StudentRegisterElig SR   
 ON SR.StudentID=ES.StudentID  
 AND SR.HouseNumber=ES.HouseNumber  
 INNER JOIN #CSEDBN CSS  
 ON CSS.CSECode=SR.CSE  
 Where ES.IsTurning5=1 and ES.WaveProcessedDate IS NULL;  
 --------------------------------------------------------------------------------------------------  
  
 --Get T5Wave Eligible Population and their ZONE SCHOOLS  
 --Create temp table and get it ready for use. Added 5/1/2025  
 DROP TABLE IF EXISTS #SSPDataSet;  
  
 Select WS.StudentID,WS.SiblingKey,WS.IsSibling,WS.IsTopBottom,NULL as DBNPriority, WS.CSESchoolDBN,WS.CSE,WS.ATSPrekSchoolDBN,WS.ASLDBN,WS.CaseType,  
 WS.GuardianLanguage,WS.AssessmentBilLangCode,WS.HomeDistrict,WS.D75Flag,WS.IsNoNameStreet,WS.D75PhysicalDBN,WS.DHSDVFlag,WS.CharterFlag,  
 WS.IsCSETrueInitial, WS.IsBilingual as IsBilingualStudent,WS.IsPOSLanguage,CAST(NULL as INT) as IsBilingualDBN, CAST(NULL as Varchar(9)) as KZonedESDBN,  
 CAST(NULL as float) as DBNProximity,CAST(NULL as float) as Latitude,CAST(NULL as float) as Longitude,WS.WaveID,WS.WaveDate,WS.ProcessedDate  
 INTO #SSPDataSet  
 From #T5WaveStudents WS  
 Where 1=0;  
   
 IF @CSEOnlyFlag='M' --manual wave assignment. Added 5/1/2025  
 BEGIN  
  INSERT INTO #SSPDataSet  
  Select WS.StudentID,WS.SiblingKey,WS.IsSibling,WS.IsTopBottom,NULL as DBNPriority, WS.CSESchoolDBN,WS.CSE,WS.ATSPrekSchoolDBN,WS.ASLDBN,WS.CaseType,  
  WS.GuardianLanguage,WS.AssessmentBilLangCode,WS.HomeDistrict,WS.D75Flag,WS.IsNoNameStreet,WS.D75PhysicalDBN,WS.DHSDVFlag,WS.CharterFlag,  
  WS.IsCSETrueInitial, WS.IsBilingual as IsBilingualStudent,WS.IsPOSLanguage,V.IsBilingualPsych as IsBilingualDBN,MW.KZonedESDBN,  
  NULL as DBNProximity,  
  NULL as Latitude,  
  NULL as Longitude,  
  WS.WaveID,  
  WS.WaveDate,  
  WS.ProcessedDate    
  From #T5WaveStudents WS  
  INNER JOIN (Select StudentID, (ReturnValueT5IEPTeam) as KZonedESDBN From dbo.DWH_T5ManualWaveSchoolDBN Where WaveID=@WaveID and ReturnValueT5IEPTeam IS NOT NULL) MW  
  ON MW.StudentID=WS.StudentID    
  LEFT JOIN dbo.vwRPT_T5CaseAssignmentCapacity V  
  ON V.SchoolDBN=MW.KZonedESDBN;  
 END  
 ELSE  
 BEGIN  
  INSERT INTO #SSPDataSet  
  Select WS.StudentID,WS.SiblingKey,WS.IsSibling,WS.IsTopBottom,NULL as DBNPriority, WS.CSESchoolDBN,WS.CSE,WS.ATSPrekSchoolDBN,WS.ASLDBN,WS.CaseType,WS.GuardianLanguage,  
  WS.AssessmentBilLangCode,WS.HomeDistrict,WS.D75Flag,WS.IsNoNameStreet,WS.D75PhysicalDBN,WS.DHSDVFlag,WS.CharterFlag,WS.IsCSETrueInitial, WS.IsBilingual as IsBilingualStudent,WS.IsPOSLanguage,V.IsBilingualPsych as IsBilingualDBN,  
  JH.KZonedESDBN,  
  dbo.fn_GetDistance(JH.Latitude,JH.Longitude,V.Latitude,V.Longitude) as DBNProximity,  
  JH.Latitude,  
  JH.Longitude,  
  WS.WaveID,  
  WS.WaveDate,  
  WS.ProcessedDate    
  From #T5WaveStudents WS  
  LEFT JOIN dbo.INT_T5StudentZoneSchool JH  
  ON JH.StudentID=WS.StudentID  
  /*Commented 11/7/2023 so Student Elig data can match JH file irrespective of address differences. MIS-10102  
  AND JH.Street=WS.Street  
  AND JH.BoroughCode=WS.BoroughCode  
  AND JH.ZipCode=WS.ZipCode  
  */  
  LEFT JOIN dbo.vwRPT_T5CaseAssignmentCapacity V  
  ON V.SchoolDBN=JH.KZonedESDBN;  
 END;  
 ----------------------------------------------------------------------------------------------------  
  
 --Below must be executed in this order--   
 IF @CSEOnlyFlag='N'  
 BEGIN  
  --AssignPriority #1  
  Exec dbo.USPRPT_T5StudentSchoolPrioritiesINS 'ASL';  
  
  --AssignPriority #2 - Special Population  
  Exec dbo.USPRPT_T5StudentSchoolPrioritiesINS 'TopBottom';   
  Exec dbo.USPRPT_T5StudentSchoolPrioritiesINS 'D75';  
  Exec dbo.USPRPT_T5StudentSchoolPrioritiesINS 'Charter';  
  Exec dbo.USPRPT_T5StudentSchoolPrioritiesINS 'DV';  
  Exec dbo.USPRPT_T5StudentSchoolPrioritiesINS 'CSETrueInitial';    
  
  --AssignPriority #3 - Siblings no dataset required. Only filtered at assignment process  
  
  --AssignPriority #4  
  Exec dbo.USPRPT_T5StudentSchoolPrioritiesINS 'DHS';  
  --AssignPriority #5  
  Exec dbo.USPRPT_T5StudentSchoolPrioritiesINS 'BilingualInPOS';  
  --AssignPriority #6  
  Exec dbo.USPRPT_T5StudentSchoolPrioritiesINS 'BilingualNotPOS';  
  --AssignPriority #7  
  Exec dbo.USPRPT_T5StudentSchoolPrioritiesINS 'Monolingual';  
  
  --DBNPriorities placeholders  
  Exec dbo.USPRPT_T5StudentSchoolPrioritiesINS 'NEARESTDBN';  
  Exec dbo.USPRPT_T5StudentSchoolPrioritiesINS 'CSEDBN';   
 END;  
  
 --load cse dbn only priorities  
 IF @CSEOnlyFlag='Y'  
 BEGIN  
  --AssignPriority #1 Added 5/17/2024. MIS-11203  
  Exec dbo.USPRPT_T5StudentSchoolPrioritiesINS 'ASL';  
  
  Exec dbo.USPRPT_T5StudentSchoolPrioritiesINS 'CSEONLY';   
 END;  
  
 --Added 5/1/2025 manual wave assignment  
 IF @CSEOnlyFlag='M'  
 BEGIN  
  Exec dbo.USPRPT_T5StudentSchoolPrioritiesINS 'MWADBN';   
 END;  
   
 ---------------------------------------------------------------------------------------------------  
  
 --Format DBN sequence numbers--  
 Select S.*,ROW_NUMBER() OVER (Partition by SiblingKey,AssignmentPriorityType,DBNPriorityType Order by DBNProximity) as DBNSeqNum   
 INTO #DBNSeqNumTbl  
 From (  
  Select DISTINCT SiblingKey,AssignmentPriorityType,DBNPriority,DBNPriorityType, DBNProximity  
  From dbo.RPT_T5StudentSchoolPriorities  
  Where ISNULL(DBNPriority,'N')<>'N'  
 ) S;  
  
 ---UPDATE DBNPrioritySeqeunce  
 UPDATE SP  
 SET SP.DBNPrioritySequence=SEQ.DBNSeqNum  
 From dbo.RPT_T5StudentSchoolPriorities SP  
 INNER JOIN #DBNSeqNumTbl SEQ  
 ON SEQ.SiblingKey=SP.SiblingKey  
 AND SEQ.AssignmentPriorityType=SP.AssignmentPriorityType  
 AND SEQ.DBNPriority=SP.DBNPriority  
 AND SEQ.DBNPriorityType=SP.DBNPriorityType;  
  
  
 --Archive data-- Moved here as last action 10-22-2024 MIS-12174  
 --We'll not check for last archive if process is rerun, old archive will be removed manually.  
 /*SET @MaxArchiveDate =  
 (    
  SELECT CASE WHEN MAX(ArchiveDate) IS NULL THEN @YEAR1900 ELSE MAX(ArchiveDate) END  
  FROM arch.RPT_T5StudentSchoolPriorities  
 );  
--------Archive only once in a day. This avoid multiple archive of same last wave data in case of procedure rerun.    
 IF @MaxArchiveDate < CAST(@Today as DATE)  
 BEGIN  
 */  
  
   INSERT INTO arch.RPT_T5StudentSchoolPriorities  
  (  
   StudentID,  
   SiblingKey,  
   IsSibling,  
   StudentCategory,  
   AssignmentPriorityType,  
   AssignmentPriorityTypeID,  
   DBNPriority,  
   DBNPrioritySequence,  
   DBNPriorityType,  
   DBNPriorityTypeID,  
   DBNProximity,  
   HomeDistrict,  
   AssignmentSetting,  
   IsBilingualStudent,  
   IsPOSLanguage,  
   IsBilingualDBN,  
   Latitude,  
   Longitude,  
   WaveID,  
   WaveDate,  
   ProcessedDate,  
   ArchiveDate,  
   SchoolYear  
   )  
  SELECT    
   StudentID,   
   SiblingKey,  
   IsSibling,  
   StudentCategory,  
   AssignmentPriorityType,  
   AssignmentPriorityTypeID,  
   DBNPriority,  
   DBNPrioritySequence,  
   DBNPriorityType,  
   DBNPriorityTypeID,  
   DBNProximity,  
   HomeDistrict,  
   AssignmentSetting,  
   IsBilingualStudent,  
   IsPOSLanguage,  
   IsBilingualDBN,  
   Latitude,  
   Longitude,  
   WaveID,  
   WaveDate,  
   ProcessedDate,  
   @Today,  
   SchoolYear  
  FROM dbo.RPT_T5StudentSchoolPriorities;  
 --END;  
  
  
 SET @EventMessage='End of T5StudentSchoolPrioritiesLOAD process. Wave: ' + Convert(varchar,@WaveID);  
 EXEC dbo.USPLOG_SEOEventLog  @EventType,@EventHeader, @EventMessage;  
  
 --end-of-process  
END;  
  
