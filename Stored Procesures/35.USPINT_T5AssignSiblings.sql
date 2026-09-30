USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPINT_T5AssignSiblings]    Script Date: 4/4/2026 4:07:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[USPINT_T5AssignSiblings]
	@SchoolYear char(9), @WaveID int, @WaveDate date
/*
Modification History:
Raji			11/20/2024				Initial Draft
Charlotte		11/22/2025				Replaced global temp tables with permanent tables prefixed with "_WT"
Charlotte       01/08/2026              When assigning by DBN+Language capacity, also require DBN total capacity (RPT_T5tfDBNCapacity_WT)
*/
AS
BEGIN
	SET NOCOUNT ON 

	--BEGIN: Assign siblings where none of the siblings are previously assigned ---

	--In the TargetPopulation, siblings can have differnt languages but have same AssignmentPriorityType
	/*
	KHUSENOVANODIRA11214	2	NonPOS	Russian
	PEREZKAREN11221	2	English	SPANISH
	REYNOSOCAROLINE11434	2	English	SPANISH
	VIVASDANIELA11365	2	English	SPANISH
	*/
	--select SiblingKey, count(*), min(language), max(Language), min(AssignmentPriorityType), max(AssignmentPriorityType)
	--from RPT_T5TargetStudents_WT
	--where AssignedSchoolDBN = ''
	--group by SiblingKey 
	--having count(*) > 1 and min(language) <> max(Language)

	--Siblings have same AssignmentPriorityType
	--select SiblingKey, count(*), min(language), max(Language), min(AssignmentPriorityType), max(AssignmentPriorityType)
	--from RPT_T5TargetStudents_WT
	--where AssignedSchoolDBN = ''
	--group by SiblingKey 
	--having count(*) > 1 and min(AssignmentPriorityType) <> max(AssignmentPriorityType)

	--If siblings have different languages, give priority to bilingualPOS over monolingual 
	--If the siblings have different bilingaulPOS then use the language that is most common  
	drop table if exists RPT_T5Siblings_WT
	;with sibLang as 
	(
		select SiblingKey, StudentID,
			StudentLanguage as Language, 
			case StudentLanguage when 'SPANISH' then 1			when 'Russian' then 2 			when 'Mandarin' then 3 
						when 'Arabic' then 4			when 'Cantonese' then 5 		when 'HAITIAN CREOLE' then 6
						when 'URDU' then 7				when 'KOREAN' then 8			when 'HINDI' then 9
						when 'Chinese' then 10			when 'English' then 11			 else 12
			end as langPriority
		from RPT_T5TargetStudents_WT 
	)
	select sib.SiblingKey, sib.cntSiblings, sib.AssignmentPriorityType, 

	--Since, we don't know the rules applied to compute AssignmentPriorityType for siblings with different languages, 
	--let's make sure AssignmentPriorityTpye and sibLanguage align
	case when sib.AssignmentPriorityType = 'DHS' then 
				case when slang.sibLanguage in (
				'Arabic', 'Chinese', 'Cantonese', 'HAITIAN CREOLE', 'HINDI'	, 'KOREAN', 'Mandarin','SPANISH', 'URDU', 'Russian' 
						, 'English' 
					)	then slang.sibLanguage 
				else 'NonPOS' 
			end
		when sib.AssignmentPriorityType = 'BilingualInPOS'  
			and slang.sibLanguage in (
				'Arabic', 'Chinese', 'Cantonese', 'HAITIAN CREOLE', 'HINDI'	, 'KOREAN', 'Mandarin','SPANISH', 'URDU', 'Russian' )
			then slang.sibLanguage 
		when sib.AssignmentPriorityType = 'Monolingual' then 'English'
		when sib.AssignmentPriorityType = 'BilingualNotPOS' then 'NonPOS'
		else 
			slang.sibLanguage 
		end as sibLanguage
	into RPT_T5Siblings_WT
	from 
	(
		select SiblingKey, count(*) as cntSiblings, 
			--All siblings are supposed to have the same AssignmentPriorityType. We get same result with min or max
			max(AssignmentPriorityType) as AssignmentPriorityType
		from RPT_T5TargetStudents_WT 
		where isnull(AssignedSchoolDBN, '') = ''
		group by SiblingKey
		having count(*) > 1
	)  sib 
		inner join (
			select s.SiblingKey, min(s.Language) as sibLanguage
			from sibLang s  
				inner join (	
					select SiblingKey, min(LangPriority) as highLangPriority from sibLang group by SiblingKey 
					) sp 
				on s.SiblingKey = sp.SiblingKey
				and s.LangPriority = sp.highLangPriority 
			group by s.SiblingKey
		) slang 
			on sib.SiblingKey = slang.SiblingKey

		--********************BEGIN: Siblings wo Prior Assignment and who are Bilingual in a POS language
			declare crsr cursor for 
				select SiblingKey, cntSiblings, sibLanguage from RPT_T5Siblings_WT 
				where sibLanguage not in ('English', 'NonPOS')
				order by AssignmentPriorityType desc, newid() --ensures random selection

			--BEGIN: Assigned to ZonedDBN-LanguageMatch
				declare @SiblingKey varchar(1000), @cntSiblings int, @sibLanguage  varchar(50), @asgTS datetime
				open crsr
				fetch next from crsr into @SiblingKey, @cntSiblings, @sibLanguage 
				while @@FETCH_STATUS = 0
				begin 
					WAITFOR DELAY '00:00:00:010' 
					--wait ensures that each assignment gets its own unique AssignedDateTime value 
					--which is essential in updating AvailableCapacity after each assignment is determined

					set @asgTS = getdate() 
					insert into RPT_T5newAssignments_WT(StudentID, AssignedSchoolDBN, AssignmentLanguage, 
						AssignmentPriorityType, AssignmentPriorityTypeID, Notes, AssignedDateTime
						,DBNPriorityType, DBNPriorityTypeID, DBNPrioritySequence, DBNProximity 
						)

					select top (@cntSiblings) reg.StudentID, c.SchoolDBN, c.Language as AssignmentLanguage, 
					   reg.AssignmentPriorityType, reg.AssignmentPriorityTypeID, 
						'Siblings wo Prior Assignment - Bilingual-Zoned', @asgTS
						,'ZONEDBN-LngMatchSib' as DBNPriorityType, 1 as DBNPriorityTypeID, prt.DBNPrioritySequence, NULL as DBNProximity 
					from RPT_T5TargetStudents_WT reg 
						inner join  SEO_MART.dbo.RPT_T5StudentSchoolPriorities prt
							on reg.StudentID = prt.StudentID 
							and prt.DBNPriorityType = 'ZoneDBN' and isnull(prt.DBNPriority, '') <> ''
						inner join RPT_T5tfDBNLanguageCapacity_WT c 
							on c.SchoolDBN = prt.DBNPriority 
							and (
								c.Language = @sibLanguage
								or 
								(@sibLanguage = 'Cantonese' and c.Language = 'Chinese(Both)')
								or 
								(@sibLanguage = 'Mandarin' and c.Language = 'Chinese(Both)')
								or 
								(@sibLanguage = 'Chinese' and c.Language in ('Chinese(Both)', 'Mandarin', 'Cantonese'))
								)
						--01/08/2026: also require DBN total capacity
						inner join dbo.RPT_T5tfDBNCapacity_WT dc
							on dc.SchoolDBN = c.SchoolDBN
					where reg.SiblingKey = @SiblingKey 
					and c.AvailableCapacity_CC >= @cntSiblings 
					and dc.AvailableCapacity_CC_MonoAndBiCombo >= 1
					order by prt.DBNPrioritySequence, c.SchoolDBN

					--Reduce these siblings assignments from available capacity  
					exec dbo.USPPROC_T5UpdateCapacityFromNewAssignments @asgTS

 					fetch next from crsr into @SiblingKey, @cntSiblings, @sibLanguage 
				end

				close crsr
				deallocate crsr

				update reg set AssignedSchoolDBN = n.AssignedSchoolDBN, AssignmentLanguage = n.AssignmentLanguage 
				from RPT_T5TargetStudents_WT reg 
					inner join RPT_T5newAssignments_WT n 
						on reg.StudentID = n.StudentID 
				where isnull(reg.AssignedSchoolDBN, '')  = ''
			--END: Assigned to ZonedDBN-LanguageMatch

			--BEGIN: Assigned to NearestDBN-LanguageMatch
				declare crsrN cursor for 
				select s.SiblingKey, cntSiblings, sibLanguage, s.AssignmentPriorityType from RPT_T5Siblings_WT s
				where s.sibLanguage not in ('English', 'NonPOS')
				and exists (select 1 from RPT_T5TargetStudents_WT reg where s.SiblingKey = reg.SiblingKey and isnull(reg.AssignedSchoolDBN, '') = '')
				order by s.AssignmentPriorityType desc, newid() --ensures random selection

				declare @SiblingKeyN varchar(1000), @cntSiblingsN int, @sibLanguageN  varchar(50), @asgTSN datetime, @AssignmentPriorityTypeN varchar(30)
				open crsrN
				fetch next from crsrN into @SiblingKeyN, @cntSiblingsN, @sibLanguageN, @AssignmentPriorityTypeN
				while @@FETCH_STATUS = 0
				begin 
					WAITFOR DELAY '00:00:00:010' 
					--wait ensures that each assignment gets its own unique AssignedDateTime value 
					--which is essential in updating AvailableCapacity after each assignment is determined

					set @asgTSN = getdate() 

					insert into SEO_MART.dbo.INT_T5StudentSchoolAssignmentNearestDBN
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
						, [ProcessedDate] 
						, [ProcessedDateTime] 
						, [SchoolYear]
						, Notes
					)
					select @WaveID, @WaveDate, reg.StudentID, 
						case when @cntSiblingsN = 1 then 0 else 1 end as IsSibling, 
						reg.SiblingKey, reg.AssignmentPriorityType,
						case when reg.StudentLanguageCategory in ('POS', 'NonPOS') then 1 else 0 end as IsBilingualStudent,
						reg.StudentLanguageCode, reg.StudentLanguage,  1 as IsLanguageMatch, 
						prt.HomeDistrict, c.Latitude, c.Longitude, c.SchoolDBN, c.AvailableCapacity_CC, 
						case when c.AvailableCapacity_CC >= @cntSiblingsN and dc.AvailableCapacity_CC_MonoAndBiCombo >= @cntSiblingsN then 1 else 0 end as IsAvailableCap,
						--case when c.AvailableCapacity_CC >= @cntSiblingsN then 1 else 0 end as IsAvailableCap,
						SEO_MART.dbo.fn_GetDistance(prt.Latitude,prt.Longitude,c.Latitude, c.Longitude) as DBNProximity, 
						cast(@asgTSN as date) as ProcessedDate,  @asgTSN as processedDateTime, @Schoolyear
						, 'NearestDBN-LangMatch-Siblings' as Notes
					from RPT_T5TargetStudents_WT reg 
						inner join  SEO_MART.dbo.RPT_T5StudentSchoolPriorities prt
							on reg.StudentID = prt.StudentID 
							and prt.DBNPriorityType = 'NEARESTDBN' 
							and prt.Latitude is not null 
							and prt.Longitude is not null
						inner join RPT_T5tfDBNLanguageCapacity_WT c 
							--NOTE: Use HomeDistrict in priorityTable over Register. Priority.HomeDistrict comes from LCGMS. It overrides Register
							on c.GeographicalDistrict=prt.HomeDistrict 
							and (
								c.Language = @sibLanguageN
								or 
								(@sibLanguageN = 'Cantonese' and c.Language = 'Chinese(Both)')
								or 
								(@sibLanguageN = 'Mandarin' and c.Language = 'Chinese(Both)')
								or 
								(@sibLanguageN = 'Chinese' and c.Language in ('Chinese(Both)', 'Mandarin', 'Cantonese'))
								)

							and c.SchoolType <> 'CSE'
							and c.SchoolDBN <> '02M347'
						--01/08/2026: also require DBN total capacity
						inner join dbo.RPT_T5tfDBNCapacity_WT dc
							on dc.SchoolDBN = c.SchoolDBN
					where reg.SiblingKey = @SiblingKeyN 
					--and c.AvailableCapacity_CC >= @cntSiblingsN 

					insert into RPT_T5newAssignments_WT(StudentID, AssignedSchoolDBN, AssignmentLanguage, 
						AssignmentPriorityType, AssignmentPriorityTypeID, Notes, AssignedDateTime
						,DBNPriorityType, DBNPriorityTypeID, DBNPrioritySequence, DBNProximity 
						)
					--get student proximity to schools in the homedistrict 
					select top (@cntSiblingsN) 
						StudentID, SchoolDBN, Language as AssignmentLanguage, AssignmentPriorityType, AssignmentPriorityTypeID,
						': Siblings wo Prior Assignment - Bilingual-Near', @asgTSN
						,'NEARDBN-LngMatchSib' as DBNPriorityType, 2 as DBNPriorityTypeID, 1 as DBNPrioritySequence, DBNProximity 
						--,DBNProximity
					from (
						select reg.StudentID, c.SchoolDBN, c.Language, reg.AssignmentPriorityType, reg.AssignmentPriorityTypeID, 
							SEO_MART.dbo.fn_GetDistance(prt.Latitude,prt.Longitude,c.Latitude,c.Longitude) as DBNProximity
						from RPT_T5TargetStudents_WT reg 
							inner join  SEO_MART.dbo.RPT_T5StudentSchoolPriorities prt
								on reg.StudentID = prt.StudentID 
								and prt.DBNPriorityType = 'NEARESTDBN' 
								and prt.Latitude is not null 
								and prt.Longitude is not null
							inner join RPT_T5tfDBNLanguageCapacity_WT c 
								--NOTE: Use HomeDistrict in priorityTable over Register. Priority.HomeDistrict comes from LCGMS. It overrides Register
								on c.GeographicalDistrict=prt.HomeDistrict 
								and (
									c.Language = @sibLanguageN
									or 
									(@sibLanguageN = 'Cantonese' and c.Language = 'Chinese(Both)')
									or 
									(@sibLanguageN = 'Mandarin' and c.Language = 'Chinese(Both)')
									or 
									(@sibLanguageN = 'Chinese' and c.Language in ('Chinese(Both)', 'Mandarin', 'Cantonese'))
								)
								and c.SchoolType <> 'CSE'
								and c.SchoolDBN <> '02M347'
							--01/08/2026: also require DBN total capacity
							inner join dbo.RPT_T5tfDBNCapacity_WT dc
								on dc.SchoolDBN = c.SchoolDBN
						where reg.SiblingKey = @SiblingKeyN 
						and c.AvailableCapacity_CC >= @cntSiblingsN 
						and dc.AssignedCapacity_MonoAndBiCombo >= @cntSiblingsN
					) A
					order by DBNProximity, SchoolDBN

					--Reduce these siblings assignments from available capacity  
					exec dbo.USPPROC_T5UpdateCapacityFromNewAssignments @asgTSN

 					fetch next from crsrN into @SiblingKeyN, @cntSiblingsN, @sibLanguageN, @AssignmentPriorityTypeN 
				end

				close crsrN
				deallocate crsrN

				update reg set AssignedSchoolDBN = n.AssignedSchoolDBN, AssignmentLanguage = n.AssignmentLanguage 
				from RPT_T5TargetStudents_WT reg 
					inner join RPT_T5newAssignments_WT n 
						on reg.StudentID = n.StudentID 
				where isnull(reg.AssignedSchoolDBN, '')  = ''
			--END: Assigned to NearestDBN-LanguageMatch
		--END: Siblings wo Prior Assignment and who are Bilingual in a POS language***************************
END
