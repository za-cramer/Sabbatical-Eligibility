/*
-- FIS SABBATICAL RECORDS --
- Created by ZAC 04/2024
- Purpose: Extracts first and most recent sabbatical events from FIS EVENT table
- To Do:
	[x] Caputure Event AY
*/

WITH 
	fis_extract AS
		(SELECT  e.FIS_ID
		, pers.EMPLID AS EID -- Include EID AS it will JOIN TO HCM DATA.
		, e.EVENT_BEGIN_DATE
		, e.EVENT_END_DATE
		, e.POSITION_NUMBER
		, e.DEPT_ID
		, e.EVENT_JOBCLASS
		, e.EVENT_DESC
		,
		CASE 
			WHEN t.TENURE_DECISION IS NULL THEN 1
			ELSE 0
		END AS PRE_TENURE -- FLAG for no prior tenure 		
		FROM FACULTY.FIS_EVENT e
		LEFT JOIN 
			(SELECT DISTINCT
				FIS_ID, EMPLID
				FROM FACULTY.FIS_PERSON	-- EID comes from FIS_PERSON		
			) pers
			ON e.FIS_ID = pers.FIS_ID -- 1:1 MATCH 
		LEFT JOIN 
			faculty.fis_tenure t
			ON e.FIS_ID = t.FIS_ID
	ORDER BY  pers.EMPLID DESC, e.EVENT_BEGIN_DATE
	)
	,
	sabbatical AS 
		(SELECT 
		  FIS_ID
		, EID
		, ROW_NUMBER() -- Identify ROW NUMBER FOR Individual ordered BY Event DATE 
			OVER(PARTITION BY FIS_ID ORDER BY FIS_ID, EVENT_BEGIN_DATE) AS Record_Number
		, EXTRACT(MONTH FROM EVENT_BEGIN_DATE) AS EFFECTIVE_MONTH
		, EXTRACT(YEAR FROM EVENT_BEGIN_DATE)  AS EFFECTIVE_YEAR
		, EXTRACT(MONTH FROM EVENT_END_DATE)  AS EXPIRE_MONTH
		, EXTRACT(YEAR FROM EVENT_END_DATE)  AS EXPIRE_YEAR
		, CASE 
			WHEN EXTRACT(MONTH FROM EVENT_BEGIN_DATE)
				BETWEEN 1 AND 6 
				THEN 
				/* Academic Year is prior calendar year if Spring Term */
					CONCAT(CONCAT(CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE) - 1) AS VARCHAR(10))
					, ' - ')
					, 	   CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE)) AS VARCHAR(10)))
			WHEN EXTRACT(MONTH FROM EVENT_BEGIN_DATE)
				BETWEEN 7 AND 12 
				THEN 
					CONCAT(CONCAT(CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE))AS VARCHAR(10)) 
					, ' - ')
					,CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE) + 1)AS VARCHAR(10)) )
			END AS AY
		, CASE 
			WHEN EXTRACT(MONTH FROM EVENT_BEGIN_DATE)
				BETWEEN 1 AND 6 
				THEN 
				/* Academic Year Fall is prior calendar year if Spring Term */
					(EXTRACT(YEAR FROM EVENT_BEGIN_DATE) - 1)
				/* Academic Year Fall is current calendar year */
			ELSE 	(EXTRACT(YEAR FROM EVENT_BEGIN_DATE))
		  END AS AY_FALL
		, EVENT_BEGIN_DATE
		, EVENT_END_DATE
		, POSITION_NUMBER
		, DEPT_ID
		, EVENT_JOBCLASS
		, EVENT_DESC
		, PRE_TENURE
		FROM fis_extract 
		WHERE EVENT_DESC = 'Sabbatical' -- 'Sabbatical' Events IN FIS_EVENT
			AND EVENT_JOBCLASS IN ('1100', '1101', '1102', '1103') -- TTT JobCodes (Professors, Asst, & Assoc.)
		ORDER BY  EID, EVENT_BEGIN_DATE)
    ,
	last_sabbatical AS 
		(SELECT  FIS_ID
				, EID
				, Record_Number
				, EFFECTIVE_MONTH
				, EFFECTIVE_YEAR
				, EXPIRE_MONTH
				, EXPIRE_YEAR
				, AY
				, AY_FALL
				, EVENT_BEGIN_DATE
				, EVENT_END_DATE
				, POSITION_NUMBER
				, DEPT_ID
				, EVENT_JOBCLASS
				, EVENT_DESC
				, PRE_TENURE
			, 1 AS sabbatical
			FROM sabbatical
			WHERE (FIS_ID, Record_Number) IN 
				(
				SELECT FIS_ID, MAX(Record_Number)
				FROM sabbatical
				GROUP BY FIS_ID
				)
		)
,	
	next_eligible AS
	(SELECT FIS_ID
	   , EID
	   , Record_Number
	   , EFFECTIVE_MONTH
	   , EFFECTIVE_YEAR
	   , EXPIRE_MONTH
	   , EXPIRE_YEAR
	   , 
		CASE 
			-- PRE_TENURE --
			WHEN EXTRACT(MONTH FROM EVENT_BEGIN_DATE)
				BETWEEN 1 AND 6 AND PRE_TENURE = 1
				THEN 
				/* Academic Year is prior calendar year if Spring Term */
					CONCAT(CONCAT(CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE) - 1) + 7 AS VARCHAR(10))
					, ' - ')
					, 	   CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE)) + 7 AS VARCHAR(10)))		
			WHEN EXTRACT(MONTH FROM EVENT_BEGIN_DATE)
				BETWEEN 7 AND 12 AND PRE_TENURE = 1
				THEN 
					CONCAT(CONCAT(CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE))+ 7 AS VARCHAR(10)) 
					, ' - ')
					,CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE) + 1)+ 7 AS VARCHAR(10)) )
			-- POST-TENURE --	
			WHEN EXTRACT(MONTH FROM EVENT_BEGIN_DATE)
				BETWEEN 1 AND 6 AND PRE_TENURE = 0
				THEN 
				/* Academic Year is prior calendar year if Spring Term */
					CONCAT(CONCAT(CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE) - 1) +6 AS VARCHAR(10))
					, ' - ')
					, 	   CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE)) +6 AS VARCHAR(10)))
			WHEN EXTRACT(MONTH FROM EVENT_BEGIN_DATE)
				BETWEEN 7 AND 12 AND PRE_TENURE = 0
				THEN 
					CONCAT(CONCAT(CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE))+6 AS VARCHAR(10)) 
					, ' - ')
					,CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE) + 1)+6 AS VARCHAR(10)) )
		END AS AY
	, 
		CASE 
			-- PRE_TENURE --
			WHEN EXTRACT(MONTH FROM EVENT_BEGIN_DATE)
				BETWEEN 1 AND 6 AND PRE_TENURE = 1
				THEN 
				/* Academic Year is prior calendar year if Spring Term */
					CONCAT(CONCAT(CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE) - 1) +6 AS VARCHAR(10))
					, ' - ')
					, 	   CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE)) +6 AS VARCHAR(10)))		
			WHEN EXTRACT(MONTH FROM EVENT_BEGIN_DATE)
				BETWEEN 7 AND 12 AND PRE_TENURE = 1
				THEN 
					CONCAT(CONCAT(CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE))+6 AS VARCHAR(10)) 
					, ' - ')
					,CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE) + 1)+6 AS VARCHAR(10)) )
			-- POST-TENURE --			
			WHEN EXTRACT(MONTH FROM EVENT_BEGIN_DATE)
				BETWEEN 1 AND 6 AND PRE_TENURE = 0
				THEN 
				/* Academic Year is prior calendar year if Spring Term */
					CONCAT(CONCAT(CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE) - 1) +5 AS VARCHAR(10))
					, ' - ')
					, 	   CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE)) +5 AS VARCHAR(10)))
			WHEN EXTRACT(MONTH FROM EVENT_BEGIN_DATE)
				BETWEEN 7 AND 12 AND PRE_TENURE = 0
				THEN 
					CONCAT(CONCAT(CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE))+5 AS VARCHAR(10)) 
					, ' - ')
					,CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE) + 1)+5 AS VARCHAR(10)) )
		END AS APPLY_AY
	, ADD_MONTHS(EVENT_BEGIN_DATE, 12*6) AS ELIGIBLE_DATE
    , ADD_MONTHS(EVENT_BEGIN_DATE, 12*5) AS ELIGIBLE_APPLY_DATE
	, NULL AS AY_FALL
	, EVENT_BEGIN_DATE
	, EVENT_END_DATE
	, POSITION_NUMBER
	, DEPT_ID
	, EVENT_JOBCLASS
	, EVENT_DESC
	, sabbatical
	, PRE_TENURE
FROM last_sabbatical	
	)
,
	no_sabbatical_all AS 
		(SELECT 
		  FIS_ID
		, EID
		, ROW_NUMBER()
			OVER(PARTITION BY FIS_ID ORDER BY FIS_ID, EVENT_BEGIN_DATE) AS Record_Number
		, EXTRACT(MONTH FROM EVENT_BEGIN_DATE) AS EFFECTIVE_MONTH
		, EXTRACT(YEAR FROM EVENT_BEGIN_DATE)  AS EFFECTIVE_YEAR
		, EXTRACT(MONTH FROM EVENT_END_DATE)  AS EXPIRE_MONTH
		, EXTRACT(YEAR FROM EVENT_END_DATE)  AS EXPIRE_YEAR
		, CASE 
			WHEN EXTRACT(MONTH FROM EVENT_BEGIN_DATE)
				BETWEEN 1 AND 6 
				THEN 
				/* Academic Year is prior calendar year if Spring Term */
					CONCAT(CONCAT(CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE) - 1) AS VARCHAR(10))
					, ' - ')
					, 	   CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE)) AS VARCHAR(10)))
			WHEN EXTRACT(MONTH FROM EVENT_BEGIN_DATE)
				BETWEEN 7 AND 12 
				THEN 
					CONCAT(CONCAT(CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE)) AS VARCHAR(10)) 
					, ' - ')
					,CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE) + 1)AS VARCHAR(10)) )
			END AS AY
		, CASE 
			WHEN EXTRACT(MONTH FROM EVENT_BEGIN_DATE)
				BETWEEN 1 AND 6 
				THEN 
				/* Academic Year Fall is prior calendar year if Spring Term */
					(EXTRACT(YEAR FROM EVENT_BEGIN_DATE) - 1)
				/* Academic Year Fall is current calendar year */
			ELSE 	(EXTRACT(YEAR FROM EVENT_BEGIN_DATE))
		  END AS AY_FALL
		, CASE 
			-- PRE_TENURE --
			WHEN EXTRACT(MONTH FROM EVENT_BEGIN_DATE)
				BETWEEN 1 AND 6 AND PRE_TENURE = 1
				THEN 
				/* Academic Year is prior calendar year if Spring Term */
					CONCAT(CONCAT(CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE) - 1) +7 AS VARCHAR(10))
					, ' - ')
					, 	   CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE)) +7 AS VARCHAR(10)))
			WHEN EXTRACT(MONTH FROM EVENT_BEGIN_DATE)
				BETWEEN 7 AND 12 AND PRE_TENURE = 1
				THEN 
					CONCAT(CONCAT(CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE))+7 AS VARCHAR(10)) 
					, ' - ')
					,CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE) + 1)+7 AS VARCHAR(10)) )
			WHEN EXTRACT(MONTH FROM EVENT_BEGIN_DATE)
				BETWEEN 1 AND 6 AND PRE_TENURE = 0
				THEN 
				/* Academic Year is prior calendar year if Spring Term */
					CONCAT(CONCAT(CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE) - 1) +6 AS VARCHAR(10))
					, ' - ')
					, 	   CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE)) +6 AS VARCHAR(10)))
			WHEN EXTRACT(MONTH FROM EVENT_BEGIN_DATE)
				BETWEEN 7 AND 12 AND PRE_TENURE = 0
				THEN 
					CONCAT(CONCAT(CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE))+6 AS VARCHAR(10)) 
					, ' - ')
					,CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE) + 1)+6 AS VARCHAR(10)) )
		END AS NEXT_ELIGIBLE_SABBATICAL
		, 
		CASE -- PRE_TENURE --
			WHEN EXTRACT(MONTH FROM EVENT_BEGIN_DATE)
				BETWEEN 1 AND 6 AND PRE_TENURE = 1
				THEN 
				/* Academic Year is prior calendar year if Spring Term */
					CONCAT(CONCAT(CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE) - 1) +6 AS VARCHAR(10))
					, ' - ')
					, 	   CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE)) +6 AS VARCHAR(10)))
			WHEN EXTRACT(MONTH FROM EVENT_BEGIN_DATE)
				BETWEEN 7 AND 12 AND PRE_TENURE = 1
				THEN 
					CONCAT(CONCAT(CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE))+6 AS VARCHAR(10)) 
					, ' - ')
					,CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE) + 1)+6 AS VARCHAR(10)) )	
			-- POST-TENURE --
			WHEN EXTRACT(MONTH FROM EVENT_BEGIN_DATE)
				BETWEEN 1 AND 6 AND PRE_TENURE = 0
				THEN 
				/* Academic Year is prior calendar year if Spring Term */
					CONCAT(CONCAT(CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE) - 1) +5 AS VARCHAR(10))
					, ' - ')
					, 	   CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE)) +5 AS VARCHAR(10)))
			WHEN EXTRACT(MONTH FROM EVENT_BEGIN_DATE)
				BETWEEN 7 AND 12 AND PRE_TENURE = 0
				THEN 
					CONCAT(CONCAT(CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE))+5 AS VARCHAR(10)) 
					, ' - ')
					,CAST((EXTRACT(YEAR FROM EVENT_BEGIN_DATE) + 1)+5 AS VARCHAR(10)) )
		END AS APPLY_AY
	 	, CASE 
	 		WHEN PRE_TENURE = 1 
	 			THEN ADD_MONTHS(EVENT_BEGIN_DATE, 12*7) 	 		
	 	 		ELSE ADD_MONTHS(EVENT_BEGIN_DATE, 12*6) END AS ELIGIBLE_DATE
	    , CASE 
	 		WHEN PRE_TENURE = 1 
	 			THEN ADD_MONTHS(EVENT_BEGIN_DATE, 12*6) 	 		
	 	 		ELSE ADD_MONTHS(EVENT_BEGIN_DATE, 12*5) END AS ELIGIBLE_APPLY_DATE
		, EVENT_BEGIN_DATE
		, NULL AS EVENT_END_DATE
		, POSITION_NUMBER
		, DEPT_ID
		, EVENT_JOBCLASS
		, EVENT_DESC
		, 0 AS sabbatical
		, PRE_TENURE
		FROM fis_extract 
		WHERE FIS_ID NOT IN 
			(
			SELECT DISTINCT FIS_ID FROM fis_extract WHERE EVENT_DESC = 'Sabbatical'
			)
		AND 
			EVENT_DESC = 'Appointment'
		AND 
			EVENT_JOBCLASS IN ('1100', '1101', '1102', '1103')
		ORDER BY  EID, EVENT_BEGIN_DATE)
, 	no_sabbatical AS
	(
		SELECT * FROM no_sabbatical_all
		WHERE Record_Number = 1
		)	
,  sabbatical_final AS 
	(SELECT 
	  LAST.FIS_ID
	, LAST.EID
	, LAST.RECORD_NUMBER
	, LAST.EFFECTIVE_MONTH
	, LAST.EFFECTIVE_YEAR
	, LAST.EXPIRE_MONTH
	, LAST.EXPIRE_YEAR
	, LAST.AY
	, LAST.AY_FALL
	, NEXT.AY AS NEXT_ELIGIBLE_SABBATICAL
	, NEXT.APPLY_AY AS APPLICATION_DATE
	, NEXT.ELIGIBLE_DATE
	, NEXT.ELIGIBLE_APPLY_DATE
	, LAST.EVENT_BEGIN_DATE
	, LAST.EVENT_END_DATE
	, LAST.POSITION_NUMBER
	, LAST.DEPT_ID
	, LAST.EVENT_JOBCLASS
	, LAST.EVENT_DESC
	, LAST.SABBATICAL
	, NEXT.PRE_TENURE
FROM last_sabbatical LAST
	LEFT JOIN next_eligible NEXT
	ON LAST.fis_id = NEXT.FIS_ID
ORDER BY LAST.EID
	)
, FINAL AS 
	(SELECT *
	FROM sabbatical_final	
	UNION
	SELECT 	*
	FROM no_sabbatical)
SELECT * FROM FINAL
	;
-- EXTRACT CSV TO sabbatical.sas --
