/*
-- FIS SABBATICAL RECORDS --
- Created by ZAC 04/2024
- Purpose: Extracts first and most recent sabbatical events from FIS EVENT table
- To Do:
	[x] Caputure Event AY

*/

WITH 
	sabbatical AS 
		(SELECT 
		  e.FIS_ID
		, pers.EMPLID AS EID
		, ROW_NUMBER()
			OVER(PARTITION BY e.FIS_ID ORDER BY e.FIS_ID) AS Faculty_Sabbatical_Number
		, CAST(EXTRACT(MONTH FROM e.EVENT_BEGIN_DATE) AS VARCHAR(10)) AS EFFECTIVE_MONTH
		, CAST(EXTRACT(YEAR FROM e.EVENT_BEGIN_DATE) AS VARCHAR(10)) AS EFFECTIVE_YEAR
		, CAST(EXTRACT(MONTH FROM e.EVENT_END_DATE) AS VARCHAR(10))  AS EXPIRE_MONTH
		, CAST(EXTRACT(YEAR FROM e.EVENT_END_DATE) AS VARCHAR(10)) AS EXPIRE_YEAR
		, CASE 
			WHEN EXTRACT(MONTH FROM e.EVENT_BEGIN_DATE)
				BETWEEN 1 AND 5 
				THEN 
				/* Academic Year is prior calendar year if Spring Term */
					CONCAT(CONCAT(CAST((EXTRACT(YEAR FROM e.EVENT_BEGIN_DATE) - 1) AS VARCHAR(10))
					, ' - ')
					, 	   CAST((EXTRACT(YEAR FROM e.EVENT_BEGIN_DATE)) AS VARCHAR(10)))
			WHEN EXTRACT(MONTH FROM e.EVENT_BEGIN_DATE)
				BETWEEN 6 AND 12 
				THEN 
					CONCAT(CONCAT(CAST((EXTRACT(YEAR FROM e.EVENT_BEGIN_DATE))AS VARCHAR(10)) 
					, ' - ')
					,CAST((EXTRACT(YEAR FROM e.EVENT_BEGIN_DATE) + 1)AS VARCHAR(10)) )
			END AS AY
		, e.EVENT_BEGIN_DATE
		, e.EVENT_END_DATE
		, e.POSITION_NUMBER
		, e.DEPT_ID
		, e.EVENT_JOBCLASS
		, e.EVENT_DESC
		FROM FACULTY.FIS_EVENT e
		LEFT JOIN 
			(SELECT DISTINCT
				FIS_ID, EMPLID
				FROM FACULTY.FIS_PERSON				
			) pers
			ON e.FIS_ID = pers.FIS_ID
		WHERE e.EVENT_DESC = 'Sabbatical'
		ORDER BY  pers.EMPLID, e.EVENT_BEGIN_DATE)
	 ,	
     first_sabbatical AS 
     	(SELECT *
		    FROM sabbatical
			WHERE (FIS_ID, Faculty_Sabbatical_Number) IN (
				SELECT FIS_ID, MIN(Faculty_Sabbatical_Number)
				FROM sabbatical
				GROUP BY FIS_ID
		)
		)
    ,
	last_sabbatical AS 
		(SELECT *
			FROM sabbatical
			WHERE (FIS_ID, Faculty_Sabbatical_Number) IN (
					SELECT FIS_ID, MAX(Faculty_Sabbatical_Number)
					FROM sabbatical
					GROUP BY FIS_ID
		)
		)
SELECT * FROM last_sabbatical
UNION
SELECT * FROM first_sabbatical

;

		
