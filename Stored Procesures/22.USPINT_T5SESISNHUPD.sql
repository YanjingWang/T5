USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPINT_T5SESISNHUPD]    Script Date: 4/4/2026 2:39:42 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[USPINT_T5SESISNHUPD]
AS
     BEGIN
         SET XACT_ABORT ON;
         SET NOCOUNT ON;

/**************************************************************************************************************************************************
Object Name: dbo.USPINT_T5SESISNHUPD
Sample call: Exec USPINT_T5SESISNHUPD
Purpose: It is used to Inactivate the NH students who have gone through wave in SEO_MART.
Date Created: 01/17/2020

Modification Details:

Author					ModifiedDate		Comments
Pangajam Subburaja							Initial Draft
Pangajam Subburaja		11/30/2020			Rollover as per 2.0 standards
Christopher Agwu		01/12/2024			Update ModifiedReason in RPT_T5StudentAssignment
											Update IsTurning5=0, ModifiedReason in RPT_T5StudentRegister tables. JIRA Ticket MIS-10368
Christopher Agwu		01/16/2024			Add code to execute T5 CaseAssignmentCapacityTracker. See JIRA Tikcet MIS-9344
Christopher Agwu        02/20/2026          Add code to capture changed Inactive students records and write to T5Bizlog table MIS-14887
***************************************************************************************************************************************************/

/*********Inactivated the ineligible NH kids who are processed in wave to filter inactivated kids from tracking reports******/

		Declare @Today Date
		
		Set @Today=getdate();

		
		Exec dbo.USPT5_T5CaseAssignmentCapacityTracker 'Before','InactiveSESISNHStudent';		--Added 1/16/2024

         UPDATE tgt
           SET
               tgt.ActiveFlag ='N',
			   --tgt.T5RecordSource=db.ReasonForInactivation,	--commented 1/12/2024
			   tgt.ModifiedDate=@Today,
			   tgt.ModifiedReasons=db.ReasonForInactivation
         FROM dbo.[RPT_T5StudentAssignment] tgt
              JOIN dbo.[DWH_T5SESISInactiveNHKids] db 
			  ON(db.StudentID = tgt.StudentID 
			  AND db.SchoolYear=tgt.SchoolYear
			  )
			  /**** Pick active kids and inactivate NH reported kids who are already processed/assigned in wave ****/
              WHERE tgt.ActiveFlag = 'Y'
              AND db.ProcessedDate IS NULL;

			  	
	--Added 1/12/2024--
	--Set IsTurning5=0 in RPT_T5STudentRegister for the deactivated studentid--
	UPDATE SR
	SET SR.IsTurning5=0,
	SR.ModifiedDate=@Today,
	SR.ModifiedReasons=DS.ReasonForInactivation
	FROM dbo.RPT_T5StudentRegister SR
	INNER JOIN dbo.DWH_T5SESISInactiveNHKids DS
	ON DS.StudentID=SR.StudentID
	AND DS.SchoolYear=SR.SchoolYear
	Where DS.ProcessedDate IS NULL;

	--capture changed rec for log
	EXEC dbo.USPLOG_T5BusinessFilesLog 'InActiveSESISNHStudent';  --2/20/2026

	--Update T5SESISInactiveNHKids table
         UPDATE dbo.[DWH_T5SESISInactiveNHKids]
           SET ProcessedDate = GETDATE()
         WHERE ProcessedDate IS NULL;

   
	  Exec dbo.USPT5_T5CaseAssignmentCapacityTracker 'After','InactiveSESISNHStudent';		--Added 1/16/2024
    END;	 


