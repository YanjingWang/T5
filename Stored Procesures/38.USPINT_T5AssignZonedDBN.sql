USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPINT_T5AssignZonedDBN]    Script Date: 4/4/2026 4:11:28 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[USPINT_T5AssignZonedDBN]
/*
Modification History:
Raji		11/20/2024			Initial Draft
Charlotte	11/22/2025			Replaced global temp tables with permanent "_WT" tables (WT = Working Table)
*/
as
BEGIN
	SET NOCOUNT ON

		--BEGIN: Zoned - Group Assignment
			drop table if exists #NSZ_Group
			select reg.StudentID, reg.StudentLanguage as Language, prt.DBNPriority as ZonedDBN
				, reg.AssignmentPriorityType, reg.AssignmentPriorityTypeID, reg.SiblingKey,
			case when reg.SiblingKey in (select SiblingKey from RPT_T5Siblings_WT) then 1 else 0 end as IsSibling,
			case when reg.AssignmentPriorityType = 'DHS' then 'Y' else 'N' end as 'IsDHS',
			reg.StudentLanguageCategory
			into #NSZ_Group
			from RPT_T5TargetStudents_WT reg
				inner join SEO_MART.dbo.RPT_T5StudentSchoolPriorities prt 
					on reg.StudentID = prt.StudentID and prt.DBNPriorityType = 'ZONEDBN' 
					and prt.DBNPrioritySequence = 1 and isnull(prt.DBNPriority, '') <> ''
			where isnull(reg.AssignedSchoolDBN, '') = ''
			--ensures random selection and priortizes Siblings -->  DHS --> All Others
			order by IsSibling desc, IsDHS desc, newid() 

			declare @asgTSNSZGroup datetime
			set @asgTSNSZGroup = getdate()
			insert into RPT_T5newAssignments_WT(StudentID, AssignedSchoolDBN, AssignmentLanguage, 
					AssignmentPriorityType, AssignmentPriorityTypeID, Notes, AssignedDateTime
					,DBNPriorityType, DBNPriorityTypeID, DBNPrioritySequence, DBNProximity )
			select reg.StudentID, g.ZonedDBN, null as AssignmentLanguage, --AssignmentLanguage wil be updated in the proc below
					reg.AssignmentPriorityType, reg.AssignmentPriorityTypeID, 
					case when reg.IsSibling = 1 then 'Sibling' else 'Non-Sibling' end  + ' -Zoned-' +
					case when reg.StudentLanguageCategory in ('POS', 'NonPOS') then 'TreatedMono' else 'Mono' end as Notes, 
					@asgTSNSZGroup
					,case when reg.StudentLanguageCategory in ('POS', 'NonPOS') then 'ZONEDBN-BiAsMono' 
						else 'ZONEDBN-Mono' 
					end as DBNPriorityType, 
					1 as DBNPriorityTypeID, 1 as DBNPrioritySequence, NULL as DBNProximity 
			--select * 
			from RPT_T5tfDBNCapacity_WT c
				inner join (
					select ZonedDBN, count(*) as cntRequiredAssignments from #NSZ_Group 
					group by ZonedDBN
				) g 
					on c.SchoolDBN = g.ZonedDBN 
				inner join #NSZ_Group reg
					on reg.ZonedDBN = g.ZonedDBN 
				where c.AvailableCapacity_CC_MonoAndBiCombo >= g.cntRequiredAssignments

			--Determine "AssignmentLanguage" and update in RPT_T5newAssignments_WT
			exec dbo.USPINT_T5AssignmentLanguageUPD @asgTSNSZGroup

			--Reduce these siblings assignments from available capacity  
			exec dbo.USPPROC_T5UpdateCapacityFromNewAssignments @asgTSNSZGroup--, 'Mono'

			update reg set AssignedSchoolDBN = n.AssignedSchoolDBN, 
				AssignmentLanguage = n.AssignmentLanguage
			from RPT_T5TargetStudents_WT reg 
				inner join RPT_T5newAssignments_WT n 
					on reg.StudentID = n.StudentID 
			where isnull(reg.AssignedSchoolDBN, '')  = ''
		--END: Zoned - Group Assignemnt

	--BEGIN: Everyhing left - Zoned - One-by-one
	declare crsNSZ cursor for --NSZ: Non-Sibling Zoned 
			select SiblingKey, cntSiblings, IsDHS from
			(
				select distinct reg.SiblingKey, isnull(s.cntSiblings, 1) as cntSiblings, 
					case when reg.AssignmentPriorityType = 'DHS' then 'Y' else 'N' end as 'IsDHS'
				from RPT_T5TargetStudents_WT reg 
					left join RPT_T5Siblings_WT s
						on reg.SiblingKey = s.SiblingKey 
				where isnull(reg.AssignedSchoolDBN, '') = ''
			) A
			order by cntSiblings desc, IsDHS desc, newid() --ensures random selection and priority to DHS over others

		declare @SiblingKeyNSZ varchar(1000), @cntSiblingsNSZ int,  @IsDHSNSZ char(1), @asgTSNSZ datetime
		open crsNSZ
		fetch next from crsNSZ into @SiblingKeyNSZ, @cntSiblingsNSZ, @IsDHSNSZ 
		while @@FETCH_STATUS = 0
		begin 
			WAITFOR DELAY '00:00:00:010' 
			--wait ensures that each assignment gets its own unique AssignedDateTime value 
			--which is essential in updating AvailableCapacity after each assignment is determined

			set @asgTSNSZ = getdate() 
			insert into RPT_T5newAssignments_WT(StudentID, AssignedSchoolDBN, AssignmentLanguage,
				AssignmentPriorityType, AssignmentPriorityTypeID, Notes, AssignedDateTime
					,DBNPriorityType, DBNPriorityTypeID, DBNPrioritySequence, DBNProximity )
			select top (@cntSiblingsNSZ) reg.StudentID, c.SchoolDBN, null as AssignmentLanguage, 
				reg.AssignmentPriorityType, reg.AssignmentPriorityTypeID, 
				case when @cntSiblingsNSZ > 1 then 'Sibling' else 'Non-Sibling' end + ' - Zoned-' + 
						case when reg.StudentLanguageCategory in ('POS', 'NonPOS') then 'TreatedMono' else 'Mono' end as Notes, @asgTSNSZ
					,'ZONEDBN' + case when reg.StudentLanguageCategory in ('POS', 'NonPOS') then '-BiAsMono' else '-Mono' end as DBNPriorityType, 
					1 as DBNPriorityTypeID, prt.DBNPrioritySequence, NULL as DBNProximity 
			from RPT_T5TargetStudents_WT reg 
				inner join  SEO_MART.dbo.RPT_T5StudentSchoolPriorities prt
					on reg.StudentID = prt.StudentID 
					and prt.DBNPriorityType = 'ZoneDBN' and isnull(prt.DBNPriority, '') <> ''
				inner join RPT_T5tfDBNCapacity_WT c 
					on c.SchoolDBN = prt.DBNPriority 
			where reg.SiblingKey = @SiblingKeyNSZ
			and c.AvailableCapacity_CC_MonoAndBiCombo >= @cntSiblingsNSZ
			order by prt.DBNPrioritySequence, c.SchoolDBN

			--Determine "AssignmentLanguage" and update in RPT_T5newAssignments_WT
			exec dbo.USPINT_T5AssignmentLanguageUPD @asgTSNSZ

			--Reduce these siblings assignments from available capacity  
			exec dbo.USPPROC_T5UpdateCapacityFromNewAssignments @asgTSNSZ--, 'Mono'

 			fetch next from crsNSZ into @SiblingKeyNSZ, @cntSiblingsNSZ, @IsDHSNSZ
		end

		close crsNSZ
		deallocate crsNSZ

		update reg set AssignedSchoolDBN = n.AssignedSchoolDBN, AssignmentLanguage = n.AssignmentLanguage 
		from RPT_T5TargetStudents_WT reg 
			inner join RPT_T5newAssignments_WT n 
				on reg.StudentID = n.StudentID 
		where isnull(reg.AssignedSchoolDBN, '')  = ''
	--END: Assigned to ZonedDBN
END
