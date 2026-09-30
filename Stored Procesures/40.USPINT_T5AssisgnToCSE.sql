USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPINT_T5AssisgnToCSE]    Script Date: 4/4/2026 4:17:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[USPINT_T5AssisgnToCSE]
	@AssignmentPriorityType varchar(50) = 'SpecialPopulation'
/*
--exec dbo.USPINT_T5AssisgnToCSE 'SpecialPopulation'
Modification History:
Raji		11/20/2024		Initial Draft
Charlotte	11/22/2025		Replaced global temp tables with Permanent tables having suffix "_WT" (WT=Working Table)
*/
as
begin
	declare @AssignedDateTime datetime
	set @AssignedDateTime = getdate() 

	--BEGIN: process group assignment
	insert into RPT_T5newAssignments_WT(StudentID, AssignedSchoolDBN, AssignmentLanguage,
		AssignmentPriorityType, AssignmentPriorityTypeID, Notes, AssignedDateTime
		,DBNPriorityType, DBNPriorityTypeID, DBNPrioritySequence, DBNProximity )
	select reg.StudentID, ac.SchoolDBN, 'CSE' as Langauge, reg.AssignmentPriorityType, reg.AssignmentPriorityTypeID, 
		reg.SiblingKey + ': ' + @AssignmentPriorityType + '-CSE', @AssignedDateTime,
		'CSEDBN'  as DBNPriorityType, 3 as DBNPriorityTypeID, 1 as DBNPrioritySequence, null as DBNProximity 
	from 
	(
		select SchoolDBN, AvailableCapacity_CC_MonoAndBiCombo AvailableCapacity 
		from RPT_T5tfDBNCapacity_WT
		where LocationType = 'CSE'
		and AvailableCapacity_CC_MonoAndBiCombo > 0
	) ac
	inner join 
	(
		select prt.DBNPriority, count(distinct reg.StudentID) as requiredAssignments 
		From RPT_T5TargetStudents_WT reg
			inner join SEO_MART.dbo.RPT_T5StudentSchoolPriorities prt 
				on reg.StudentID = prt.StudentID 
				and prt.DBNPriorityType = 'CSEDBN' 
				and prt.DBNPrioritySequence = 1
		where 
		isnull(reg.AssignedSchoolDBN, '') = ''
		and 
		(
			(@AssignmentPriorityType = 'SpecialPopulation' and reg.AssignmentPriorityType = 'SpecialPopulation')
			or 
			(@AssignmentPriorityType = 'LastResort') --If it's last resort, take everybody without an assignment
			or 
			(@AssignmentPriorityType = 'CSEOnlyWave') --If CSEOnlyWave, assign everybody to CSE
		)
		group by prt.DBNPriority
	) rc 
		on ac.SchoolDBN = rc.DBNPriority 
		and ac.AvailableCapacity >= rc.requiredAssignments
	inner join SEO_MART.dbo.RPT_T5StudentSchoolPriorities prt 
		on prt.DBNPriorityType = 'CSEDBN' 
		and prt.DBNPriority = ac.SchoolDBN
		and prt.DBNPrioritySequence = 1
	inner join RPT_T5TargetStudents_WT reg
		on reg.StudentID = prt.StudentID 
		and
		(
			(@AssignmentPriorityType = 'SpecialPopulation' and reg.AssignmentPriorityType = 'SpecialPopulation')
			or 
			(@AssignmentPriorityType = 'LastResort') --If it's last resort, take everybody without an assignment
			or 
			(@AssignmentPriorityType = 'CSEOnlyWave') --If CSEOnlyWave, assign everybody to CSE
		)
		and isnull(reg.AssignedSchoolDBN, '') = ''

	exec dbo.USPPROC_T5UpdateCapacityFromNewAssignments @AssignedDateTime, 'CSE'

	update reg set AssignedSchoolDBN = n.AssignedSchoolDBN, AssignmentLanguage = n.AssignmentLanguage 
	from RPT_T5TargetStudents_WT reg 
		inner join RPT_T5newAssignments_WT n 
			on reg.StudentID = n.StudentID 
	where isnull(reg.AssignedSchoolDBN, '')  = ''
	--END: process group assignment

	--BEGIN: Process one-by-one 
	declare crsCSE cursor for   
			select reg.StudentID, 
				'CSE' as Language,
				case when reg.AssignmentPriorityType = 'DHS' then 'Y' else 'N' end as 'IsDHS'
			from RPT_T5TargetStudents_WT reg 
				--left join RPT_T5Siblings_WT s
				--	on reg.SiblingKey = s.SiblingKey 
			where isnull(reg.AssignedSchoolDBN, '') = ''
			and
			(
				(@AssignmentPriorityType = 'SpecialPopulation' and reg.AssignmentPriorityType = 'SpecialPopulation')
				or 
				(@AssignmentPriorityType = 'LastResort') --If it's last resort, take everybody without an assignment
				or 
				(@AssignmentPriorityType = 'CSEOnlyWave') --If CSEOnlyWave, assign everybody to CSE
			)
			order by IsDHS desc, newid() --ensures random selection and priority to DHS over others

		declare @StudentIDCSE varchar(1000), @LanguageCSE varchar(50), @IsDHSCSE char(1), @asgTSCSE datetime
		open crsCSE
		fetch next from crsCSE into @StudentIDCSE, @LanguageCSE, @IsDHSCSE 
		while @@FETCH_STATUS = 0
		begin 
			WAITFOR DELAY '00:00:00:010' 
			--wait ensures that each assignment gets its own unique AssignedDateTime value 
			--which is essential in updating AvailableCapacity after each assignment is determined

			set @asgTSCSE = getdate() 

			declare @AssignedCSEDBN varchar(6) = '', @requiredCSEDBN char(6) = '', @CSEType varchar(10) = ''

			select top 1 @AssignedCSEDBN = c.SchoolDBN, @requiredCSEDBN = prt.DBNPriority, @CSEType = 'Main'
			from RPT_T5TargetStudents_WT reg 
				inner join SEO_MART.dbo.RPT_T5StudentSchoolPriorities prt
					on reg.StudentID = prt.StudentID 
					and prt.DBNPriorityType = 'CSEDBN' and isnull(prt.DBNPriority, '') <> ''
					and prt.DBNPrioritySequence = 1
				left join RPT_T5tfDBNCapacity_WT c 
					on c.SchoolDBN = prt.DBNPriority
					and c.LocationType = 'CSE'
					and c.AvailableCapacity_CC_MonoAndBiCombo >= 1
			where reg.StudentID = @StudentIDCSE
			
			--select '@CSEType-', @CSEType, '@AssignedCSEDBN-', @AssignedCSEDBN, '@requiredCSEDBN-', @requiredCSEDBN
			if isnull(@AssignedCSEDBN, '') = ''
			BEGIN
				--Find alternate CSE 
				Select top (1) @AssignedCSEDBN = AlternateCSEDBN, @CSEType = 'Alternate' 
				From SEO_MART.dbo.lk_T5AlternateCSE alt
					inner join RPT_T5tfDBNCapacity_WT c 
						on c.SchoolDBN = alt.AlternateCSEDBN 
						and c.LocationType = 'CSE'
				Where alt.CSEDBN = @requiredCSEDBN 
				and c.AvailableCapacity_CC_MonoAndBiCombo >= 1
				order by alt.RecID 
			END 
			
			if isnull(@AssignedCSEDBN, '') <> ''
			begin 
				insert into RPT_T5newAssignments_WT(StudentID, AssignedSchoolDBN, AssignmentLanguage,
					AssignmentPriorityType, AssignmentPriorityTypeID, Notes, AssignedDateTime
					,DBNPriorityType, DBNPriorityTypeID, DBNPrioritySequence, DBNProximity )
				select reg.StudentID, @AssignedCSEDBN, @LanguageCSE, reg.AssignmentPriorityType, reg.AssignmentPriorityTypeID, 
					@AssignmentPriorityType + '-' + case when @CSEType = 'Main' then 'CSE' else 'AlternateCSE' end, @asgTSCSE,
					case when @CSEType = 'Main' then 'CSEDBN' else 'CSEDBN-Alternate' end as DBNPriorityType,
					3 as DBNPriorityTypeID, 1 as DBNPrioritySequence, null as DBNProximity 
				from RPT_T5TargetStudents_WT reg  
				where reg.StudentID = @StudentIDCSE

				--Reduce capacity for assignment	
				exec dbo.USPPROC_T5UpdateCapacityFromNewAssignments @asgTSCSE, 'CSE'

				update RPT_T5TargetStudents_WT 
				set AssignedSchoolDBN = @AssignedCSEDBN, AssignmentLanguage = @LanguageCSE 
				where StudentID = @StudentIDCSE and isnull(AssignedSchoolDBN, '')  = ''

			end 				

 			fetch next from crsCSE into @StudentIDCSE, @LanguageCSE, @IsDHSCSE
		end

		close crsCSE
		deallocate crsCSE

	--END: Process one-by-one 

end
