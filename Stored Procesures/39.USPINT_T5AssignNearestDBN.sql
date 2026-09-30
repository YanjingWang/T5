USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPINT_T5AssignNearestDBN]    Script Date: 4/4/2026 4:16:05 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[USPINT_T5AssignNearestDBN]
	@SchoolYear char(9), @WaveID int, @WaveDate date
/*
Modification History:
Raji			11/20/2024			Initial Draft
Charlotte		11/22/2025			Replaced global temp tables with permanent tables
*/
as
BEGIN
	SET NOCOUNT ON

	declare crsNSN cursor for --NSN: Non-Sibling NearestDBN  
			select SiblingKey, cntSiblings, IsDHS
			from (
				select distinct reg.SiblingKey, isnull(s.cntSiblings, 1) as cntSiblings, 
					case when reg.AssignmentPriorityType = 'DHS' then 'Y' else 'N' end as 'IsDHS'  
				from RPT_T5TargetStudents_WT reg 
					left join RPT_T5Siblings_WT s
						on reg.SiblingKey = s.SiblingKey 
				where isnull(reg.AssignedSchoolDBN, '') = ''
				--and reg.SiblingKey = 'JOHNSTYASIA11203'
			) A
			order by cntSiblings desc, IsDHS desc, newid() --ensures random selection and priority to Siblings--> DHS --> Others

		declare @SiblingKeyNSN varchar(1000), @cntSiblingsNSN int, @IsDHSNSN char(1), @asgTSNSN datetime
		open crsNSN
		fetch next from crsNSN into @SiblingKeyNSN, @cntSiblingsNSN, @IsDHSNSN
		while @@FETCH_STATUS = 0
		begin 
			WAITFOR DELAY '00:00:00:010' 
			--wait ensures that each assignment gets its own unique AssignedDateTime value 
			--which is essential in updating AvailableCapacity after each assignment is determined

			set @asgTSNSN = getdate() 

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
				, IsLanguageMatch
				, [HomeDistrict] 
				, [Latitude] 
				, [Longitude] 
				, [SchoolDBN] 
				, [AvailableCapacity] 
				, [IsAvailableCap] 
				, [DBNProximity] 
				--, [Language] 
				, [ProcessedDate] 
				, [ProcessedDateTime] 
				, [SchoolYear]
				, Notes
			)
			select @WaveID, @WaveDate, reg.StudentID, 
					case when @cntSiblingsNSN > 1 then 1 else 0  end as IsSibling, 
				reg.SiblingKey, reg.AssignmentPriorityType, 
				case when reg.StudentLanguageCategory in ('POS', 'NonPOS') then 1 else 0 end as IsBilingualStudent,
				reg.StudentLanguageCode, reg.StudentLanguage,  0 as IsLanguageMatch, 
				prt.HomeDistrict, c.Latitude, c.Longitude, c.SchoolDBN, c.AvailableCapacity_CC_MonoAndBiCombo, 
				case when c.AvailableCapacity_CC_MonoAndBiCombo >= @cntSiblingsNSN then 1 else 0 end as IsAvailableCap,
				SEO_MART.dbo.fn_GetDistance(prt.Latitude,prt.Longitude,c.Latitude,c.Longitude) as DBNProximity,  
				cast(@asgTSNSN as date) as ProcessedDate,  @asgTSNSN as processedDateTime, @Schoolyear
				, 'NearestDBN-' + case when reg.StudentLanguageCategory in ('POS', 'NonPOS') then 'TreatedAsMono' else 'Mono' end as  Notes
			from RPT_T5TargetStudents_WT reg 
					inner join  SEO_MART.dbo.RPT_T5StudentSchoolPriorities prt
						on reg.StudentID = prt.StudentID 
						and prt.DBNPriorityType = 'NearestDBN'
						and prt.Latitude is not null 
						and prt.Longitude is not null
					inner join RPT_T5tfDBNCapacity_WT c 
						--NOTE: Use HomeDistrict in priorityTable over Register. Priority.HomeDistrict comes from LCGMS. 
						--It overrides Register
						on c.GeographicalDistrict = prt.HomeDistrict 
						and c.SchoolType <> 'CSE'
						and c.SchoolDBN <> '02M347'
				where reg.SiblingKey = @SiblingKeyNSN 
				--and c.AvailableCapacity_CC_MonoAndBiCombo >= @cntSiblingsNSN

			insert into RPT_T5newAssignments_WT(StudentID, AssignedSchoolDBN, AssignmentLanguage,
				AssignmentPriorityType, AssignmentPriorityTypeID, Notes, AssignedDateTime
					,DBNPriorityType, DBNPriorityTypeID, DBNPrioritySequence, DBNProximity )
			select top (@cntSiblingsNSN) StudentID, SchoolDBN, null as AssignmentLanguage, 
					AssignmentPriorityType, AssignmentPriorityTypeID, 
					case when @cntSiblingsNSN > 1 then 'Sibling' else 'Non-Sibling' end + ' -NearestDBN-' +
					
					case when A.StudentLanguageCategory in ('POS', 'NonPOS') then 'TreatedMono' else 'Mono' end as Notes
					
					, @asgTSNSN
					,'NEAR' + (case when A.StudentLanguageCategory in ('POS', 'NonPOS') then '-BiAsMono' else '-Mono' end)  as DBNPriorityType, 
					2 as DBNPriorityTypeID, null as DBNPrioritySequence, DBNProximity 
			from (
				select reg.StudentID, reg.SiblingKey, c.SchoolDBN, reg.AssignmentPriorityType, reg.AssignmentPriorityTypeID, 
						SEO_MART.dbo.fn_GetDistance(prt.Latitude,prt.Longitude,c.Latitude,c.Longitude) as DBNProximity,
						reg.StudentLanguageCategory
				from RPT_T5TargetStudents_WT reg 
					inner join  SEO_MART.dbo.RPT_T5StudentSchoolPriorities prt
						on reg.StudentID = prt.StudentID 
						and prt.DBNPriorityType = 'NearestDBN'
						and prt.Latitude is not null 
						and prt.Longitude is not null
					inner join RPT_T5tfDBNCapacity_WT c 
						--NOTE: Use HomeDistrict in priorityTable over Register. Priority.HomeDistrict comes from LCGMS. 
						--It overrides Register
						on c.GeographicalDistrict = prt.HomeDistrict 
						and c.SchoolType <> 'CSE'
						and c.SchoolDBN <> '02M347'
				where reg.SiblingKey = @SiblingKeyNSN 
				and c.AvailableCapacity_CC_MonoAndBiCombo >= @cntSiblingsNSN
			) A
			order by DBNProximity, SchoolDBN 

			exec dbo.USPINT_T5AssignmentLanguageUPD @asgTSNSN

			--Reduce these siblings assignments from available capacity  
			exec dbo.USPPROC_T5UpdateCapacityFromNewAssignments @asgTSNSN--, 'Mono'

 			fetch next from crsNSN into @SiblingKeyNSN, @cntSiblingsNSN, @IsDHSNSN
		end

		close crsNSN
		deallocate crsNSN

		update reg set AssignedSchoolDBN = n.AssignedSchoolDBN, AssignmentLanguage = n.AssignmentLanguage
		from RPT_T5TargetStudents_WT reg 
			inner join RPT_T5newAssignments_WT n 
				on reg.StudentID = n.StudentID 
		where isnull(reg.AssignedSchoolDBN, '')  = ''

END
