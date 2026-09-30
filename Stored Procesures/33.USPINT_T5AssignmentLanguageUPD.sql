USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPINT_T5AssignmentLanguageUPD]    Script Date: 4/4/2026 4:05:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[USPINT_T5AssignmentLanguageUPD]
	@AssignedDateTime datetime
/*
Modification History:

Charlotte			11/22/2025		Replaced global temp tables with permanent tables
*/
AS
BEGIN

	SET NOCOUNT ON

	--Find DBNs-and-Langauges where capacity is available
	--Within each DBN, rank languages per the ranking in RPT_T5tfDBNLanguageCapacity_WT
	--For example, if a school 06M008 has 2 Enlighs capacity and 6 Spanish capacity, rank Enlighs as 1 and Spanish as 2
	--Language with lowest rank gets used up for "Mono" or "BiAsMono" assignments
	--For the above DBN 06M008, if we make 5 'Mono' and 'BiAsMono' assignments to 06M008, 2 students will get 'English' psychologist and 3 students will get Spanish psychologist
	drop table if exists #AvailableCountsByDBNandLanguage
	select c.SchoolDBN, c.Language, c.AvailableCapacity_CC as AvailableCnt, 
		row_number() over(partition by c.SchoolDBN order by MonoAssignmentRank) as rnk  
	into #AvailableCountsByDBNandLanguage
	from RPT_T5tfDBNLanguageCapacity_WT c
		inner join RPT_T5languageRankToAssignAsMono_WT r 
			on c.Language = r.Language 
	where c.AvailableCapacity_CC > 0

	declare @loopCounter int = 1, @NumberOfLoops int 
	select @NumberOfLoops = max(rnk) from #AvailableCountsByDBNandLanguage

	while @loopCounter <= @NumberOfLoops
	begin
		;with cte as (
			select AssignedSchoolDBN, count(*) as CountToBeAssigned 
			from RPT_T5newAssignments_WT 
			where isnull(AssignmentLanguage, '') = ''  and AssignedDateTime = @AssignedDateTime
			group by AssignedSchoolDBN
		),
		cteStudents as (
			select asg.StudentID, asg.AssignedSchoolDBN, ROW_NUMBER() over(partition by asg.AssignedSchoolDBN order by isnull(rnk.MonoAssignmentRank, 999) asc, asg.StudentID) as studentDBNRnk
			from RPT_T5newAssignments_WT asg
				inner join RPT_T5StudentLanguage_WT sl 
					on asg.StudentID = sl.StudentID 
				left join RPT_T5languageRankToAssignAsMono_WT rnk
					on sl.Language = rnk.Language
			where isnull(AssignmentLanguage, '') = '' and AssignedDateTime = @AssignedDateTime
		)
		update t 
		set AssignmentLanguage = ac.Language  
		from RPT_T5newAssignments_WT t
			inner join cte c on t.AssignedSchoolDBN = c.AssignedSchoolDBN 
			inner join cteStudents cs 
				on t.AssignedSchoolDBN = cs.AssignedSchoolDBN 
				and t.StudentId = cs.StudentID 
			inner join #AvailableCountsByDBNandLanguage ac 
				on t.AssignedSchoolDBN = ac.SchoolDBN 
				and ac.rnk = @loopCounter
		where cs.studentDBNRnk <= (case when c.CountToBeAssigned <= ac.AvailableCnt then c.CountToBeAssigned
							else ac.AvailableCnt end)  

		set @loopCounter = @loopCounter + 1
	end

END
