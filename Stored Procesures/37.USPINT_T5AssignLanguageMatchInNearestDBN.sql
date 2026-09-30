USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPINT_T5AssignLanguageMatchInNearestDBN]    Script Date: 4/4/2026 4:10:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[USPINT_T5AssignLanguageMatchInNearestDBN]
	@SchoolYear char(9), @WaveID int, @WaveDate date
/*
Modification History:
Raji			11/20/2024				Initial Draft
Charlotte		11/22/2025				Replaced global temp tables with permanent tables prefixed with "_WT"
Charlotte		01/08/2026				Don't assign by languge match if capacity is not available at DBN eventhough capacity may be available at DBN-Language
*/
AS
BEGIN
	SET NOCOUNT ON

	--BEGIN: NearestDBN-LanguageMatch	
		declare crsNSNL cursor for --NSNL: Non-Sibling NearestDBN Language match
			select reg.StudentID, StudentLanguage as Language
			from RPT_T5TargetStudents_WT reg 
			where reg.StudentLanguageCategory = 'POS'
			and isnull(reg.AssignedSchoolDBN, '') = ''
			and reg.SiblingKey not in (select SiblingKey from RPT_T5Siblings_WT)
			order by reg.AssignmentPriorityType desc, newid() --ensures random selection and priority to DHS over BilingualPOS

		declare @StudentIDNSNL varchar(1000), @LanguageNSNL varchar(50), @asgTSNSNL datetime
		open crsNSNL
		fetch next from crsNSNL into @StudentIDNSNL, @LanguageNSNL
		while @@FETCH_STATUS = 0
		begin 
			WAITFOR DELAY '00:00:00:010' 
			--wait ensures that each assignment gets its own unique AssignedDateTime value 
			--which is essential in updating AvailableCapacity after each assignment is determined

			set @asgTSNSNL = getdate() 

			insert into dbo.INT_T5StudentSchoolAssignmentNearestDBN
			(
				[WaveID] 
				, [WaveDate] 
				, [StudentID] 
				, [IsSibling] 
				, [SiblingKey] 
				, [StudentCategory] 
				, [IsBilingualStudent] 
				, [StudentLanguageCode]
				, [StudentLanguage]
				, AssignmentLanguage
				, IsLanguageMatch
				, [HomeDistrict] 
				, [Latitude] 
				, [Longitude] 
				, [SchoolDBN] 
				, [AvailableCapacity] 
				, [IsAvailableCap] 
				, [DBNProximity] 
				, [ProcessedDate] 
				, [ProcessedDateTime] 
				, [SchoolYear] 
				, Notes
			)
			select @WaveID, @WaveDate, reg.StudentID, 
				0 as IsSibling, 
				reg.SiblingKey, 
				reg.AssignmentPriorityType, 
				case when reg.StudentLanguageCategory in ('POS', 'NonPOS') then 1 else 0 end as IsBilingualStudent,
				reg.StudentLanguageCode, 
				reg.StudentLanguage, 
				c.Language as AssignmentLanguage,  
				1 as IsLanguageMatch, 
				prt.HomeDistrict, 
				c.Latitude, 
				c.Longitude, 
				c.SchoolDBN, 
				c.AvailableCapacity_CC, 
				case when c.AvailableCapacity_CC >= 1 and d.AvailableCapacity_CC_MonoAndBiCombo >= 1 then 1 else 0 end as IsAvailableCap,
				--case when c.AvailableCapacity_CC >= 1 then 1 else 0 end as IsAvailableCap,
				SEO_MART.dbo.fn_GetDistance(prt.Latitude,prt.Longitude,c.Latitude,c.Longitude) as DBNProximity,
				cast(@asgTSNSNL as date) as ProcessedDate,  
				@asgTSNSNL as processedDateTime, 
				@Schoolyear,
				'NearestDBN-LangMatch-NonSiblings' as Notes
			from RPT_T5TargetStudents_WT reg 
					inner join  SEO_MART.dbo.RPT_T5StudentSchoolPriorities prt
						on reg.StudentID = prt.StudentID 
						and prt.DBNPriorityType = 'NearestDBN'
						and prt.Latitude is not null 
						and prt.Longitude is not null
					inner join RPT_T5tfDBNLanguageCapacity_WT c 
						--NOTE: Use HomeDistrict in priorityTable over Register. Priority.HomeDistrict comes from LCGMS. 
						--It overrides Register
						on c.GeographicalDistrict = prt.HomeDistrict 
						and (
								c.Language = @LanguageNSNL 
								or 
								(
									(@LanguageNSNL = 'Mandarin' and c.Language = 'Chinese(Both)')
									or
									(@LanguageNSNL = 'Cantonese' and c.Language = 'Chinese(Both)')
									or
									(@LanguageNSNL = 'Chinese' and c.Language in ('Chinese(Both)', 'Mandarin', 'Cantonese'))
								)
							)
							and c.SchoolType <> 'CSE'
							and c.SchoolDBN <> '02M347'
					inner join RPT_T5tfDBNCapacity_WT d --added 01/08/2026
						on d.SchoolDBN = c.SchoolDBN
				where reg.StudentID = @StudentIDNSNL 
				--and c.AvailableCapacity_CC >= 1

			insert into RPT_T5newAssignments_WT(StudentID, AssignedSchoolDBN, AssignmentLanguage, 
				AssignmentPriorityType, AssignmentPriorityTypeID, Notes, AssignedDateTime
			,DBNPriorityType, DBNPriorityTypeID, DBNPrioritySequence, DBNProximity )
			select top (1) StudentID, SchoolDBN, AssignmentLanguage, AssignmentPriorityType, AssignmentPriorityTypeID, 
				SiblingKey + ': Non-Sibling - Bilingual-Near', @asgTSNSNL
			,'NEARDBN-LngMatchNSib' as DBNPriorityType, 2 as DBNPriorityTypeID, null as DBNPrioritySequence, DBNProximity 
			from (
				select reg.StudentID, reg.SiblingKey, c.Language as AssignmentLanguage, c.SchoolDBN, reg.AssignmentPriorityType, reg.AssignmentPriorityTypeID, 
						SEO_MART.dbo.fn_GetDistance(prt.Latitude,prt.Longitude,c.Latitude,c.Longitude) as DBNProximity
				from RPT_T5TargetStudents_WT reg 
					inner join  SEO_MART.dbo.RPT_T5StudentSchoolPriorities prt
						on reg.StudentID = prt.StudentID 
						and prt.DBNPriorityType = 'NearestDBN'
						and prt.Latitude is not null 
						and prt.Longitude is not null
					inner join RPT_T5tfDBNLanguageCapacity_WT c 
						--NOTE: Use HomeDistrict in priorityTable over Register. Priority.HomeDistrict comes from LCGMS. 
						--It overrides Register
						on c.GeographicalDistrict = prt.HomeDistrict 
						and (
								c.Language = @LanguageNSNL 
								or 
								(
									(@LanguageNSNL = 'Mandarin' and c.Language = 'Chinese(Both)')
									or
									(@LanguageNSNL = 'Cantonese' and c.Language = 'Chinese(Both)')
									or
									(@LanguageNSNL = 'Chinese' and c.Language in ('Chinese(Both)', 'Mandarin', 'Cantonese'))
								)
							)
							and c.SchoolType <> 'CSE'
							and c.SchoolDBN <> '02M347'
					inner join RPT_T5tfDBNCapacity_WT d --added 01/08/2026
						on d.SchoolDBN = c.SchoolDBN
				where reg.StudentID = @StudentIDNSNL 
				and c.AvailableCapacity_CC >= 1
				and d.AvailableCapacity_CC_MonoAndBiCombo >= 1
			) A
			order by DBNProximity, SchoolDBN 

			--Reduce these siblings assignments from available capacity  
			exec dbo.USPPROC_T5UpdateCapacityFromNewAssignments @asgTSNSNL

 			fetch next from crsNSNL into @StudentIDNSNL, @LanguageNSNL
		end

		close crsNSNL
		deallocate crsNSNL

		update reg set AssignedSchoolDBN = n.AssignedSchoolDBN, AssignmentLanguage = n.AssignmentLanguage 
		from RPT_T5TargetStudents_WT reg 
			inner join RPT_T5newAssignments_WT n 
				on reg.StudentID = n.StudentID 
		where isnull(reg.AssignedSchoolDBN, '')  = ''

END
