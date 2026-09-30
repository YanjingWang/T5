USE [SEO_MART]
GO
/****** Object:  StoredProcedure [dbo].[USPINT_T5DetermineStudentLanguage]    Script Date: 4/4/2026 3:58:15 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[USPINT_T5DetermineStudentLanguage]
/*
Modification History:
Raji			11/20/2024				Initial Draft
Charlotte		11/22/2025				Replaced global temp tables with permanent tables prefixed with "_WT"
*/
as
BEGIN
	SET NOCOUNT ON 
	delete from RPT_T5StudentLanguage_WT
	insert into RPT_T5StudentLanguage_WT(
		StudentID
		, Language
		, LanguageCategory
		, LanguageCode
	)
	select StudentID, case when isnull(AssessmentBilLangCode, '') <> '' then 
						case AssessmentBilLangCode 
							when 'AR' then 'Arabic'			when 'CH' then 'Chinese'			when 'CE' then 'Chinese'	
							when 'CS' then 'Chinese'		when 'CN' then 'Cantonese'			when 'HA' then 'HAITIAN CREOLE'
							when 'HI' then 'HINDI'			when 'KO' then 'KOREAN'				when 'MN' then 'Mandarin'
							when 'SP' then 'SPANISH'		when 'UD' then 'URDU'				when 'RU' then 'Russian'
							when 'EN' then 'English'		when 'ZZ' then 'ZZ'				else isnull(alk.Description, AssessmentBilLangCode)
							end
					when isnull(AssessmentBilLangCode, '') = '' and isnull(GuardianLanguage, '') <> '' then 
						case GuardianLanguage 
							when 'AR' then 'Arabic'			when 'CH' then 'Chinese'			when 'CE' then 'Chinese'	
							when 'CS' then 'Chinese'		when 'CN' then 'Cantonese'			when 'HA' then 'HAITIAN CREOLE'
							when 'HI' then 'HINDI'			when 'KO' then 'KOREAN'				when 'MN' then 'Mandarin'
							when 'SP' then 'SPANISH'		when 'UD' then 'URDU'				when 'RU' then 'Russian'
							when 'EN' then 'English'		when 'ZZ' then 'ZZ'				else isnull(glk.Description, GuardianLanguage)
							end	
					else 'English'
				end as 'Language',
			case when isnull(AssessmentBilLangCode, '') <> '' then 
						case when AssessmentBilLangCode in ('AR', 'CH', 'CE', 'CS', 'CN', 'HA', 'HI', 'KO', 'MN', 'SP', 'UD', 'RU')
								then 'POS'
							when AssessmentBilLangCode = 'EN' then 'English'
							else 'NonPOS' 
						end 
					when isnull(AssessmentBilLangCode, '') = '' and isnull(GuardianLanguage, '') <> '' then 
						case when GuardianLanguage in ('AR', 'CH', 'CE', 'CS', 'CN', 'HA', 'HI', 'KO', 'MN', 'SP', 'UD', 'RU')
								then 'POS'
							when GuardianLanguage = 'EN' then 'English'
							else 'NonPOS' 
						end 
					else 'English' 
				end as 'LanguageCategory',
			case when isnull(AssessmentBilLangCode, '') <> '' then AssessmentBilLangCode 
					else isnull(GuardianLanguage, '') 
			end as 'LanguageCode'			
	from SEO_MART.dbo.RPT_T5StudentRegister reg
		left join SEO_MART.dbo.lk_LanguageCodes alk
			on alk.Code = reg.AssessmentBilLangCode and alk.SourceName = 'CAP'
		left join SEO_MART.dbo.lk_LanguageCodes glk
			on glk.Code = reg.GuardianLanguage and glk.SourceName = 'CAP'
	
END
