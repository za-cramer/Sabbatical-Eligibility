WITH 
	sabbatical AS 
		(SELECT 
		  FIS_ID
		, ROW_NUMBER()
			OVER(PARTITION BY FIS_ID ORDER BY FIS_ID) AS Faculty_Sabbatical_Number
		, EXTRACT(MONTH FROM EVENT_BEGIN_DATE) AS EFFECTIVE_MONTH
		, EXTRACT(YEAR FROM EVENT_BEGIN_DATE) AS EFFECTIVE_YEAR
		, EXTRACT(MONTH FROM EVENT_END_DATE) AS EXPIRE_MONTH
		, EXTRACT(YEAR FROM EVENT_END_DATE) AS EXPIRE_YEAR
		, EVENT_BEGIN_DATE
		, EVENT_END_DATE
		, POSITION_NUMBER
		, DEPT_ID
		, EVENT_JOBCLASS
		, EVENT_DESC
		FROM FACULTY.FIS_EVENT
		WHERE EVENT_DESC = 'Sabbatical'
		ORDER BY  FIS_ID, EVENT_BEGIN_DATE)
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
