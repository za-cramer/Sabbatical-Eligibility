***************************************
		SET TERM AND LIBRARY
***************************************;
%let year = 2023;
%let admin = %str('2214','1446','2209','2208','2206','2210','2205','2207');
%fisdb;
/*  
 	1433 Faculty Director - Removed for Sabbatical Eligibility per Cholpon communication 5.6 to ZC and RS
 	1446 Director-Institute
 	2205 Chancellor
 	2206 Executive Vice Chancellor/VP
 	2207 Provost
 	2208 Executive Vice Chancellor
 	2209 Vice Chancellor
 	2210 Assoc Vice Chancellor
 	2214 Dean
*/
%put <<<< snapyear = &year.;
libname lib 'L:\IR\facstaff\OFA\Sabbatical Report';
/* Import FIS Sabbatical Events query found L:\IR\facstaff\OFA\Sabbatical Report\sabbatical_eligibility.sql */
proc import datafile="L:\IR\facstaff\OFA\Sabbatical Report\fis_sabbatical.csv"
     out=fis_sabbatical
     dbms=csv
     replace;
     getnames=yes;
run;

/* Import CIW Leave Events query found L:\IR\facstaff\OFA\Sabbatical Report\ciw_leave.sql */
proc import datafile="L:\IR\facstaff\OFA\Sabbatical Report\ciw_leave.csv"
     out=ciw_leave
     dbms=csv
     replace;
     getnames=yes;
run;

/* FIS Tenure Home (as deptid)*/
proc sql;
	create table tenure1 as 
	select FIS_ID
		 , case when TENURE_LOCUS = '10255' then '10769' else TENURE_LOCUS end as TENURE_LOCUS
	from fisdb.fis_tenure;
quit;

proc sql; 
	create table tenure as
	select 
		t.FIS_ID
	,   t.TENURE_LOCUS as DeptID label = "Dept ID"
	,	pers.deptname 
	from tenure1 t
	left join 
		(select distinct
			DeptID,
			DeptName
		from edb.pers&year.) pers
		on t.TENURE_LOCUS = pers.deptid;
quit;

/* Map FIS_ID from fis */
proc sql; 
	create table eid_xwalk as
	select distinct 
		   emplid as EID,
		   fis_id 
	from fisdb.fis_person;
quit;
%ciwdb;
************* BEGIN ANALYSIS *********************;
* Employed Faculty 
* Remove Retirees, retain active TTT;
proc sql;
	create table active_sabbatical as
	select distinct 
		   sab.EID,
		   xwalk.FIS_ID,
		   hr.EMPLOYEE_NAME,
		   tenure.DeptID,
		   tenure.DeptName,
		   pers.admin as Current_Admin,
		   sab.SABBATICAL as Prior_Sabbatical_Flag,
		   sab.EVENT_BEGIN_DATE,
           sab.ELIGIBLE_DATE,
           sab.ELIGIBLE_APPLY_DATE,
		   sab.EFFECTIVE_MONTH,
		   sab.EFFECTIVE_YEAR,
		   sab.EXPIRE_MONTH,
		   sab.EXPIRE_YEAR,
		   sab.AY,
		   sab.AY_FALL,
		   sab.NEXT_ELIGIBLE_SABBATICAL as NEXT_ELIGIBLE_SABBATICAL_OLD,
		   sab.APPLICATION_DATE as APPLICATION_DATE_OLD,
		   case
		   	when (&year. - sab.AY_FALL)  >= 6  /* Logic says if they were hired, or accumulated service, of 6 years or greater they are eligible */
				 then catx(' - ', put(&year. + 1, 4.), put(&year. + 2, 4.)) 
				 else sab.NEXT_ELIGIBLE_SABBATICAL
			end as NEXT_ELIGIBLE_SABBATICAL_AY ,
		   case
		   	when (&year. - sab.AY_FALL)  >= 6  /* Logic says if they were hired, or accumulated service, of 6 years or greater they are eligible */
				 then catx(' - ', put(&year., 4.), put(&year. + 1, 4.)) 
				 else sab.APPLICATION_DATE
			end as APPLICATION_AY ,
		   case
		   	when (&year. - sab.AY_FALL)  >= 6  /* Logic says if they were hired, or accumulated service, of 6 years or greater they are eligible */
				 then 1
				 else 0
			end as ELIGIBLE_IN_CURRENT_AY,
			sab.PRE_TENURE
	from fis_sabbatical sab /* Imported Sabbatical Roster */
		left join ciwdb.HRMS_PERSONAL_TBL hr /* Join HR Name */
			on sab.EID = hr.EMPLOYEE_ID
		left join
			(select distinct 
					EID, 
					1 as admin /* 'Admin' flag based on Cholpon's list */
				from edb.appts&year.
				where jobcode in (&admin.)) pers
			on sab.EID = pers.EID
		left join
			tenure
			on sab.FIS_ID = tenure.FIS_ID
		left join
			eid_xwalk xwalk
			on sab.EID = xwalk.EID
	where sab.EID in
		(select EID 
			from edb.appts2023
			where JobCode not like '16%'
			and Big3)
	Group by sab.EID
	order by EFFECTIVE_YEAR, sab.EID, calculated ELIGIBLE_IN_CURRENT_AY desc;
quit;

/* CIW LEAVE WITHOUT PAY 
 THINKING:
- If Leave occurs AFTER the EXPIRE YEAR of their latest sabbatical, it is
	of concern. Otherwise, it is not. 
- Removing Active Leaves (expire year 3999 in HCM)
*/
proc sql; 
	create table active_leave as
	select leave.EID,
		   hr.EMPLOYEE_NAME,
		   sab.EXPIRE_YEAR as LATEST_SABBATICAL_EXPIRE_YEAR,
		   leave.*,
		   case when leave.EXPIRE_YEAR = 3999
		   	then 1
			else 0
			end as ACTIVE_LEAVE
	from ciw_leave leave
		left join ciwdb.HRMS_PERSONAL_TBL hr /* Join HR Name */
			on leave.EID = hr.EMPLOYEE_ID
		left join active_sabbatical sab
			on leave.EID = sab.EID
	where leave.EID in 
		(select distinct EID from active_sabbatical)
	and leave.ROUNDED_ANNUAL_RATE <> 0
	and leave.EFFECTIVE_YEAR >= sab.EXPIRE_YEAR
	and calculated ACTIVE_LEAVE <> 1;
quit;	

proc sql;
	create table active_leave_summary1 as
	select distinct 
	EID,
	EMPLOYEE_NAME,
	SUM(DURATION_DAYS) AS TOTAL_DAYS_ON_LEAVE
	FROM
		active_leave
	GROUP BY EID;
QUIT;

proc sql;
	create table active_leave_summary2 as
	select distinct 
	EID,
	EMPLOYEE_NAME,
	TOTAL_DAYS_ON_LEAVE,
	ROUND(TOTAL_DAYS_ON_LEAVE / 365,0.001) AS ANNUAL_RATE
	FROM
		active_leave_summary1
	GROUP BY EID;
QUIT;

proc sql;
	create table lib.active_leave_summary as
	select distinct 
	EID,
	EMPLOYEE_NAME,
	TOTAL_DAYS_ON_LEAVE,
	ANNUAL_RATE
	, CASE
    WHEN ANNUAL_RATE < 0.170 THEN 0
    WHEN ANNUAL_RATE BETWEEN 0.171 AND 0.594 THEN 0.5
    WHEN ANNUAL_RATE BETWEEN 0.595 AND 1.170 THEN 1
    WHEN ANNUAL_RATE BETWEEN 1.171 AND 1.594 THEN 1.5
    WHEN ANNUAL_RATE BETWEEN 1.595 AND 2.170 THEN 2
    WHEN ANNUAL_RATE BETWEEN 2.171 AND 2.594 THEN 2.5
    WHEN ANNUAL_RATE BETWEEN 2.595 AND 3.170 THEN 3
    WHEN ANNUAL_RATE BETWEEN 3.171 AND 3.594 THEN 3.5
    WHEN ANNUAL_RATE BETWEEN 3.595 AND 4.170 THEN 4
    WHEN ANNUAL_RATE BETWEEN 4.171 AND 4.594 THEN 4.5
    WHEN ANNUAL_RATE BETWEEN 4.595 AND 5.170 THEN 5
	ELSE FLOOR(2*ROUND(ANNUAL_RATE, 0.1))/2 /* FOR VERY HIGH VALUES */
END AS ROUNDED_ANNUAL_RATE,
	1 as ACCRUED_LEAVE
	FROM
		active_leave_summary2;
QUIT;

proc sql; 
	create table inst&year. as
	select distinct 
				EID,
				InstAny
			 from edb.pers&year.;
quit;

proc sql; 
	create table lib.active_sabbatical_final as
	select distinct 
		   a.EID,
		   a.FIS_ID,
		   a.EMPLOYEE_NAME,
		   l.Accrued_Leave,
		   rank.JobTitle,
		   rank.JobCode,
		   a.DeptID,
		   PropCase(a.DeptName) as DeptName,
		   div.CollegeDesc,
		   div.ASDiv,
		   div.DivisionDesc,
		   inst.InstAny,
		   a.*,
		   case 
				when month(datepart(a.EVENT_BEGIN_DATE))
					between 1 and 6 then 'SPRING'
				when month(datepart(a.EVENT_BEGIN_DATE))
					between 6 and 13 then 'FALL'
			end as Last_Sabbatical_Semester,
		   case 
				when month(datepart(a.EVENT_BEGIN_DATE))
					between 1 and 6 then 'SPRING'
				when month(datepart(a.EVENT_BEGIN_DATE))
					between 6 and 13 then 'FALL'
			end as Next_Sabbatical_Semester,
			case
            when ELIGIBLE_APPLY_DATE < dhms("01NOV&year."d, 0, 0, 0)
				then 1
				else 0
			end as Eligible_to_apply_flag,
			a.PRE_TENURE
	from active_sabbatical a
		left join lib.active_leave_summary l
			on a.EID = l.EID
		left join
			(select distinct 
				DeptID,
				ASDiv,
				CollegeDesc,
				DivisionDesc,
				InstAny
			 from edb.pers&year.) div
		on a.DeptID = div.DeptID
		left join inst&year. inst
			on a.EID = inst.EID
		left join 
			(select distinct EID, JobCode, JobTitle, Order from edb.appts&year. where jobcode in ('1100','1101','1102','1103') group by EID having Order = min(order)) rank
		on a.EID = rank.EID;
quit;

* CHECK FOR DUPLICATES *;
proc sql; 
	select distinct *, count(EID) as count from lib.active_sabbatical_final group by EID having count(EID) > 1; quit;

* REMOVE DUPLICATES HERE *;
/*proc sql;
    delete from lib.active_sabbatical_final
    where EID = '129468' and JobTitle = 'PROFESSOR';
quit;*/

* Re-Check OUTPUT *;
proc sql; 
	select distinct *, count(EID) as count from lib.active_sabbatical_final group by EID having count(EID) > 1; quit;

** Export to excel to check **;
%xlsexport(L:\IR\facstaff\OFA\Sabbatical Report\sabbatical_roster.xlsx,lib.active_sabbatical_final,sabbatical);
%xlsexport(L:\IR\facstaff\OFA\Sabbatical Report\sabbatical_roster.xlsx,lib.active_leave_summary,active_leave_summary);
%xlsexport(L:\IR\facstaff\OFA\Sabbatical Report\sabbatical_roster.xlsx,active_leave,full_leave_roster);
