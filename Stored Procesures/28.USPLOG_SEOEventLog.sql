USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPLOG_SEOEventLog]    Script Date: 4/4/2026 3:56:19 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




/*=============================================================================================================================================
Object Name: dbo.USPLOG_SEOEventLog
Purpose:	It is used to track/capture activities in a long store procedure. 
Date Created: 9/23/2022

Modification Details:
Author					ModifiedDate	Comments
Christopher Agwu		9/23/2022		Initial. USPLOG_SEOEventLog
Christopher Agwu		6/12/2023		Modified to target specific event type (process) instead of using same table for all possible processes.  
================================================================================================================================================*/


ALTER PROCEDURE [dbo].[USPLOG_SEOEventLog]
(	
	@pEventType varchar(50),
	@pEventHeader varchar(150),
	@pEventMessage varchar(1500)
)	
AS

BEGIN
	Declare @ActiveEventTypes varchar(500)
	
	SET NOCOUNT ON;
	SET @ActiveEventTypes=('T5Wave,');	--add new eventtypes here with comma seperated
	
	IF CHARINDEX(@pEventType,@ActiveEventTypes)=0
	BEGIN
		RAISERROR ('EventType not found, unable to write to SEOEventLog!',16,1);		
		Return;
	END;

	IF @pEventType='T5Wave'
	BEGIN
		INSERT INTO dbo.T5WaveEventLog (EventHeader, EventMessage)
		Select @pEventHeader, @pEventMessage;
	END;
	
	--other future process event type tables go here
END


