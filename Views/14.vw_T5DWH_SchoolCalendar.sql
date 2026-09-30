USE [SEO_REPORTING]
GO

/****** Object:  View [BI].[vw_T5DWH_SchoolCalendar]    Script Date: 4/6/2026 1:49:49 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE view [BI].[vw_T5DWH_SchoolCalendar]
as 
/*************************************************************************************************
Object Name:		BI.vw_T5DWH_SchoolCalendar
Purpose:			Provide calculated columns needed for T5 reporting based on seo_mart.dbo.DWH_SchoolCalendar
Execute example:	select * from BI.vw_T5DWH_SchoolCalendar where CalendarDate = '2023-09-20'

Modification Details:
Author			ModifiedDate	Comments
------			------------	-------------------
SergeyG			01/30/20234		Initial
**************************************************************************************************/
--	################ Constants computed once:	#####################
	with D			as (select cast(getdate() as date) as CurrentDate)
	,	Constants	as (select CurrentDate
							, month(CurrentDate)			as CurrentDateMonth
							, DATEDIFF(day,seo_mart.dbo.fn_FiscalYearStartDate(CurrentDate), CurrentDate)+1
															as CurrentFiscalDays
							, (case when datepart(m, CurrentDate) between 1 and 6 
									then datepart(m, CurrentDate)+6
									else datepart(m, CurrentDate)-6
									end)					as CurrentFiscalMonth
							, cast(format(CurrentDate,'yyyyMM00') as varchar(8))	as CurrentYearMonthYYYYMM00
						  from D
						)
--	##################################################################
	select s.*
		--	###	T5-reporting specific columns (computed for each record):
		--
		,	c.CurrentDate, c.CurrentDateMonth, c.CurrentFiscalDays, c.CurrentFiscalMonth
		,	(case when c.CurrentYearMonthYYYYMM00 > cast(format(CalendarDate,'yyyyMM00') as varchar(8))
					then 'TRUE' else 'FALSE' end)				as CompletedMonth
		--
		,	cast(convert(char(8), CalendarDate, 112) as int)	as CalendarDateYYYYMMDD
		,	datepart(weekday, CalendarDate)-1					as DayOfWeekSunday0Number
		,	datepart(weekday, CalendarDate)						as DayOfWeekSunday1Number
		,	cast(format(CalendarDate, 'dddd')	as varchar(10))	as DayOfWeekName
		,	datepart(dd, CalendarDate)							as DayOfMonthNumber
		,	(case when datepart(m, CalendarDate) between 1 and 6 
					then datepart(m, CalendarDate)+6
					else datepart(m, CalendarDate)-6
					end)										as FiscalMonthNumber
		,	cast(
			(case when datepart(q, CalendarDate) between 1 and 2 
					then datepart(q, CalendarDate)+2
					else datepart(q, CalendarDate)-2
					end)	as varchar(1))						as FiscalQuarter
		,	cast(concat('FQ', 
			(case when datepart(q, CalendarDate) between 1 and 2 
					then datepart(q, CalendarDate)+2
					else datepart(q, CalendarDate)-2
					end)
			)	as char(3))										as FiscalQuarterFQn
		,	right(seo_mart.dbo.fn_SY(CalendarDate),4)			as FiscalYear
		,	cast('FY'+right(seo_mart.dbo.fn_SY(CalendarDate),2) as char(4))		as FiscalYearFYnn
		,	DATEDIFF(day,seo_mart.dbo.fn_FiscalYearStartDate(CalendarDate), CalendarDate)+1
																as FiscalYearDayNumber
		,	(case when format(CalendarDate, 'dddd') in ('Saturday', 'Sunday') then 1 else 0 end)
																as IsWeekendDay
		,	EOMONTH(CalendarDate)								as EndOfMonthDate
		,	cast(format(CalendarDate, 'yy-MMM')	as char(6))		as CalendarYearMonthYY_Mmm
		,	cast(datename(MONTH,CalendarDate) as varchar(10))	as CalendarMonthName
		,	cast(format(CalendarDate,'yyyyMM00') as varchar(8))	as CalendarYearMonthYYYYMM00
		,	month(CalendarDate)									as CalendarMonthNumber
		,	cast(concat('Q', datepart(q, CalendarDate), ' ', year(CalendarDate))	as char(7))	as CalendarQuarterYearQn_YYYY
		,	cast(concat(year(CalendarDate), '0', datepart(q, CalendarDate), '00')	as int)		as CalendarYearQuarterYYYY0Q00
		,	datepart(q, CalendarDate)							as CalendarQuarter
		,	datepart(week, CalendarDate)						as CalendarWeekNumber
		,	(case when format(CalendarDate, 'dddd') = 'Tuesday' then 1 else 0 end)	as IsWeeklyreportingDate
		,	year(CalendarDate)									as CalendarYearNumber
	  from seo_mart.dbo.DWH_SchoolCalendar	S
	  join Constants						C	on 1=1
	;

GO


