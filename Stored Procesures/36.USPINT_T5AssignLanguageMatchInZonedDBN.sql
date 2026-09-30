USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPINT_T5AssignLanguageMatchInZonedDBN]    Script Date: 4/4/2026 4:08:55 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[USPINT_T5AssignLanguageMatchInZonedDBN]
/*
Modification History:
Raji		11/20/2024			Initial Draft
Charlotte	11/22/2025			Replaced global temp tables with permanent tables prefixed with "_WT" (WT = Working Table)
Charlotte	01/08/2026			Check DBN capacity in addition to DBN-Language capacity when assigning by language match
*/
as
BEGIN
	set nocount on
			
	--BEGIN: ZonedDBN-LanguageMatch - Group Assignemnt
		drop table if exists #NSZL_Group
		select reg.StudentID, 
				reg.StudentLanguage as Language, 
				prt.DBNPriority as ZonedDBN,
				reg.AssignmentPriorityType, 
				reg.AssignmentPriorityTypeID, 
				reg.SiblingKey
		into #NSZL_Group
		from RPT_T5TargetStudents_WT reg
			inner join SEO_MART.dbo.RPT_T5StudentSchoolPriorities prt 
				on reg.StudentID = prt.StudentID 
				and prt.DBNPriorityType = 'ZONEDBN' 
				and prt.DBNPrioritySequence = 1 
				and isnull(prt.DBNPriority, '') <> ''
		where reg.StudentLanguageCategory = 'POS' --not in ('English', 'NonPOS')
		and isnull(reg.AssignedSchoolDBN, '') = ''
		and reg.SiblingKey not in (select SiblingKey from RPT_T5Siblings_WT)
		order by reg.AssignmentPriorityType desc, newid() --ensures random selection and priority to DHS over BilingualPOS

		declare @asgTSNSZLGroup datetime
		set @asgTSNSZLGroup = getdate()

		;with cteDBNLang as (
			select ZonedDBN, Language, count(*) as cntRequiredAssignments_DBNLang from #NSZL_Group 
			group by ZonedDBN, Language 
		),
		cteDBN as (
			select ZonedDBN, sum(cntRequiredAssignments_DBNLang) as cntRequiredAssignments_DBN 
			from cteDBNLang 
			group by ZonedDBN
		)
		insert into RPT_T5newAssignments_WT(StudentID, AssignedSchoolDBN, AssignmentLanguage, 
				AssignmentPriorityType, AssignmentPriorityTypeID, Notes, AssignedDateTime
				,DBNPriorityType, DBNPriorityTypeID, DBNPrioritySequence, DBNProximity 
				)
		select reg.StudentID, dl.ZonedDBN, reg.Language, reg.AssignmentPriorityType, reg.AssignmentPriorityTypeID, 
				reg.SiblingKey + ': NonSibling - Bilingual-Zoned', @asgTSNSZLGroup
				,'ZONEDBN-LngMatch' as DBNPriorityType, 1 as DBNPriorityTypeID, 1 as DBNPrioritySequence, null as DBNProximity 
		--select * 
		from #NSZL_Group reg 
			inner join dbo.RPT_T5tfDBNLanguageCapacity_WT c
				on c.SchoolDBN = reg.ZonedDBN 
				and c.Language = reg.Language
			INNER JOIN dbo.RPT_T5tfDBNCapacity_WT dc
				ON dc.SchoolDBN = reg.ZonedDBN
			inner join cteDBNLang dl
				on reg.ZonedDBN = dl.ZonedDBN 
				and reg.Language = dl.Language
			inner join cteDBN d
				on reg.ZonedDBN = d.ZonedDBN
			where c.AvailableCapacity_CC >= dl.cntRequiredAssignments_DBNLang
			and dc.AvailableCapacity_CC_MonoAndBiCombo >= d.cntRequiredAssignments_DBN

			--Reduce these siblings assignments from available capacity  
			exec dbo.USPPROC_T5UpdateCapacityFromNewAssignments @asgTSNSZLGroup

			update reg 
			set AssignedSchoolDBN = n.AssignedSchoolDBN, 
				AssignmentLanguage = n.AssignmentLanguage 
			from RPT_T5TargetStudents_WT reg 
				inner join RPT_T5newAssignments_WT n 
					on reg.StudentID = n.StudentID 
			where isnull(reg.AssignedSchoolDBN, '')  = ''
	--END: ZonedDBN-LanguageMatch - Group Assignemnt

	--BEGIN: ZonedDBN-LanguageMatch - One-by-one
	declare crsNSZL cursor for --NSZL: Non-Sibling Zoned Language match
			select reg.StudentID, StudentLanguage as Language
			from RPT_T5TargetStudents_WT reg 
			where reg.StudentLanguageCategory = 'POS'
			and isnull(reg.AssignedSchoolDBN, '') = ''
			and reg.SiblingKey not in (select SiblingKey from RPT_T5Siblings_WT)
			order by reg.AssignmentPriorityType desc, newid() --ensures random selection and priority to DHS over BilingualPOS

		declare @StudentIDNSZL varchar(1000), @LanguageNSZL varchar(50), @asgTSNSZL datetime
		open crsNSZL
		fetch next from crsNSZL into @StudentIDNSZL, @LanguageNSZL
		while @@FETCH_STATUS = 0
		begin 
			WAITFOR DELAY '00:00:00:010' 
			--wait ensures that each assignment gets its own unique AssignedDateTime value 
			--which is essential in updating AvailableCapacity after each assignment is determined

			set @asgTSNSZL = getdate() 
			insert into RPT_T5newAssignments_WT(
					StudentID, 
					AssignedSchoolDBN, 
					AssignmentLanguage,
					AssignmentPriorityType, 
					AssignmentPriorityTypeID, 
					Notes, 
					AssignedDateTime,
					DBNPriorityType, 
					DBNPriorityTypeID, 
					DBNPrioritySequence, 
					DBNProximity 
				)
			select top (1) reg.StudentID, 
					c.SchoolDBN, 
					c.Language, 
					reg.AssignmentPriorityType, 
					reg.AssignmentPriorityTypeID, 
					reg.SiblingKey + ': Non-Sibling - Bilingual-Zoned', 
					@asgTSNSZL,
					'ZONEDBN-LngMatch' as DBNPriorityType, 
					1 as DBNPriorityTypeID, 
					prt.DBNPrioritySequence, 
					NULL as DBNProximity 
			from RPT_T5TargetStudents_WT reg 
				inner join  SEO_MART.dbo.RPT_T5StudentSchoolPriorities prt
					on reg.StudentID = prt.StudentID 
					and prt.DBNPriorityType = 'ZoneDBN' 
					and isnull(prt.DBNPriority, '') <> ''
				inner join RPT_T5tfDBNLanguageCapacity_WT c 
					on c.SchoolDBN = prt.DBNPriority 
					and (
							c.Language = @LanguageNSZL 
							or 
							(
								(@LanguageNSZL = 'Mandarin' and c.Language = 'Chinese(Both)')
								or
								(@LanguageNSZL = 'Cantonese' and c.Language = 'Chinese(Both)')
								or
								(@LanguageNSZL = 'Chinese' and c.Language in ('Chinese(Both)', 'Mandarin', 'Cantonese'))
							)
						)
				inner join RPT_T5tfDBNCapacity_WT d
					on d.SchoolDBN = c.SchoolDBN
			where reg.StudentID = @StudentIDNSZL 
			and c.AvailableCapacity_CC >= 1
			and d.AvailableCapacity_CC_MonoAndBiCombo >= 1
			order by prt.DBNPrioritySequence, c.SchoolDBN

			--Reduce these siblings assignments from available capacity  
			exec dbo.USPPROC_T5UpdateCapacityFromNewAssignments @asgTSNSZL

 			fetch next from crsNSZL into @StudentIDNSZL, @LanguageNSZL
		end

		close crsNSZL
		deallocate crsNSZL

		update reg set AssignedSchoolDBN = n.AssignedSchoolDBN, AssignmentLanguage = n.AssignmentLanguage 
		from RPT_T5TargetStudents_WT reg 
			inner join RPT_T5newAssignments_WT n 
				on reg.StudentID = n.StudentID 
		where isnull(reg.AssignedSchoolDBN, '')  = ''
	--END: Assigned to ZonedDBN-LanguageMatch-One-by-One
END
