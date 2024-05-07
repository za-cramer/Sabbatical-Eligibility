***************************************
		SET TERM AND LIBRARY
***************************************;
%let year = 2023;
%let first_year = %eval(&year. - 10);
%let pending_events = %str('Leave Paid' 'Admin Appt' 'Leave Without Pay' 'Sabbatical');
%let omitted_jobs = %str('1300','1448','1452','1453','1454','1455','1456','1601');
%let ttt = %str('1100','1101','1102','1103', '1202', '1202', '1203');
%let jobs = %str('1100','1101','1102','1103', '1202', '1202', '1203'); * Added Clinical (11/30/23);
/* Admin Job Codes per Roster Definitions File Linked Above */
%let admin = %str('2214','1446','2209','2208','2206','2210','2205','2207');
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

%put <<<< snapyear = &year. || first_year = &first_year.;

libname lib 'L:\IR\facstaff\OFA\Sabbatical Report';

%include 'L:\IR\facstaff\OFA\Retention Dashboard\bi-annual_appts.sas'; 

/* Import FIS Sabbatical Events query found L:\IR\facstaff\OFA\Sabbatical Report\sabbatical_eligibility.sql */
proc import datafile="L:\IR\facstaff\OFA\Sabbatical Report\fis_sabbatical.csv"
     out=fis_sabbatical
     dbms=csv
     replace;
     getnames=yes;
run;
proc contents data = fis_sabbatical; run;

/* Import CIW Leave Events query found L:\IR\facstaff\OFA\Sabbatical Report\ciw_leave.sql */
proc import datafile="L:\IR\facstaff\OFA\Sabbatical Report\ciw_leave.csv"
     out=ciw_leave
     dbms=csv
     replace;
     getnames=yes;
run;
proc contents data = ciw_leave; run;

************* BEGIN ANALYSIS *********************;
* Employed Faculty 
* Remove Retirees, retain active TTT;
%ciwdb;
proc sql;
	create table active_sabbatical as
	select sab.EID,
		   hr.EMPLOYEE_NAME,
		   pers.admin as Current_Admin,
		   sab.SABBATICAL as Prior_Sabbatical_Flag,
		   sab.EFFECTIVE_MONTH,
		   sab.EFFECTIVE_YEAR,
		   sab.EXPIRE_MONTH,
		   sab.EXPIRE_YEAR,
		   sab.AY,
		   sab.AY_FALL,
		   sab.NEXT_ELIGIBLE_SABBATICAL as NEXT_ELIGIBLE_SABBATICAL_OLD,
		   case
		   	when (&year. - sab.AY_FALL)  >= 6  /* Logic says if they were hired, or accumulated service, of 6 years or greater they are eligible */
				 then catx(' - ', put(&year., 4.), put(&year. + 1, 4.)) 
				 else sab.NEXT_ELIGIBLE_SABBATICAL
			end as NEXT_ELIGIBLE_SABBATICAL 
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
	where sab.EID in
		(select 
			distinct EID 
			from edb.appts&year.
		 where JobCode not like '16%'
			and Big3)
	order by EFFECTIVE_YEAR;
quit;
			
