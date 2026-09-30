USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPPROC_T5UpdateCapacityFromNewAssignments]    Script Date: 4/4/2026 4:06:06 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[USPPROC_T5UpdateCapacityFromNewAssignments]
	@AssignedDateTime datetime,
	@MonoOrBiLingual	varchar(10) = 'Bi'
/*
Modification History:
Raji		11/20/2024		Initial Draft
Charlotte	11/22/2025		Replaced global temp tables with permanent tables
Raji		02/05/2026		Discontinue the update of Mono and Bilingual columns in DBN capacity table RPT_T5tfDBNCapacity_WT
							as they are not used
*/
as
begin


		--BEGIN: Handle updates to non-ASL and non-CSE locations
		--NOTE: ASL is assumed to have unlimited capacity. It doesn't need capacity management
			;with cte as (
				select AssignedSchoolDBN, 
						sum(case when AssignmentLanguage in ('English', 'NonPOS') then 0 else 1 end) as AssignedCapacity_Bilingual,
						sum(case when AssignmentLanguage in ('English', 'NonPOS') then 1 else 0 end) as AssignedCapacity_Monolingual
				from RPT_T5newAssignments_WT
				where AssignedDateTime = @AssignedDateTime
				group by AssignedSchoolDBN
			)
			update dc
			set  
				--AssignedCapacity_Bilingual = dc.AssignedCapacity_Bilingual + c.AssignedCapacity_Bilingual,
				--AssignedCapacity_Monolingual = dc.AssignedCapacity_Monolingual + c.AssignedCapacity_Monolingual,
				AssignedCapacity_MonoAndBiCombo = dc.AssignedCapacity_MonoAndBiCombo + c.AssignedCapacity_Bilingual + c.AssignedCapacity_Monolingual,
				AvailableCapacity_CC_MonoAndBiCombo =  case when dc.AvailableCapacity_CC_MonoAndBiCombo > (c.AssignedCapacity_Bilingual + c.AssignedCapacity_Monolingual)
																then dc.AvailableCapacity_CC_MonoAndBiCombo - (c.AssignedCapacity_Bilingual + c.AssignedCapacity_Monolingual)
															else  0 
														end
				--AvailableCapacity_CC_Bilingual = case when dc.AvailableCapacity_CC_Bilingual > c.AssignedCapacity_Bilingual then 
				--										dc.AvailableCapacity_CC_Bilingual - c.AssignedCapacity_Bilingual
				--									else 0 	
				--									end,
				--AvailableCapacity_CC_Monolingual = case when dc.AvailableCapacity_CC_Monolingual > c.AssignedCapacity_Monolingual then 
				--										dc.AvailableCapacity_CC_Monolingual - c.AssignedCapacity_Monolingual
				--									else 0 	
				--									end  
			from RPT_T5tfDBNCapacity_WT dc 
				inner join cte c 
					on dc.SchoolDBN = c.AssignedSchoolDBN

			if isnull(@MonoOrBiLingual, '') not in ('Mono' , 'CSE')
			begin
				;with cte as (
					select AssignedSchoolDBN, 
						case when AssignmentLanguage in ('English', 'NonPOS') then 'English' else AssignmentLanguage end as Language,
						count(*) as AssignedCapacity
					from RPT_T5newAssignments_WT
					where AssignedDateTime = @AssignedDateTime
					group by AssignedSchoolDBN, case when AssignmentLanguage in ('English', 'NonPOS') then 'English' else AssignmentLanguage end
				)
				update dc
				set  AssignedCapacity = dc.AssignedCapacity + c.AssignedCapacity,
					AvailableCapacity_CC = case when dc.AvailableCapacity_CC > c.AssignedCapacity  
													then dc.AvailableCapacity_CC - c.AssignedCapacity 
												else 0 end,
					MaxCaseAssignmentCapacity = dc.MaxCaseAssignmentCapacity
				from RPT_T5tfDBNLanguageCapacity_WT dc 
					inner join cte c 
						on dc.SchoolDBN = c.AssignedSchoolDBN
						and dc.Language = c.Language
			end 
end
