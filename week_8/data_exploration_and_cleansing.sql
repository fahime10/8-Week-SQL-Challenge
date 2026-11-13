USE FreshSegmentsDB;

-- Data Exploration and Cleansing

-- 1. Update the interest_metrics table by modifying the month_year column to be a 
-- date data type with the start of the month

ALTER TABLE interest_metrics
ALTER COLUMN month_year DATE;
-- This throws an error as it is unable to convert from string to date


ALTER TABLE interest_metrics
DROP COLUMN month_year;

ALTER TABLE interest_metrics
ADD month_year DATE;

UPDATE interest_metrics
SET month_year = CAST(
	CAST(_year AS VARCHAR(4)) + '-' +
	RIGHT('0' + CAST(_month AS VARCHAR(2)), 2) + '-01'
	AS DATE
);


-- 2. What is count of records in the interest_metrics for each month_year value sorted in 
-- chronological order (earliest to latest) with the null values appearing first?
SELECT
	DISTINCT month_year,
	COUNT(*) AS occurrences
FROM interest_metrics
GROUP BY month_year
ORDER BY month_year;


-- 3. What do you think we should do with these null values in the interest_metrics?

-- There a number of options to go with. The best practice is to use a WHERE clause that would 
-- filter out the NULLs or, given the nature of the analysis using time, delete the NULLs.
-- It would be preferable to create a backup table instead, and delete the NULLs afterwards

SELECT * 
INTO interest_metrics_old
FROM interest_metrics;

DELETE FROM interest_metrics
WHERE month_year IS NULL;

-- 1,194 rows removed


-- 4. How many interest_id values exist in the interest_metrics table but not in the 
-- interest_map table? What about the other way around?
SELECT 
	COUNT(DISTINCT a.interest_id) AS total_id_not_in_interest_map
FROM interest_metrics a
WHERE NOT EXISTS (
	SELECT 1
	FROM interest_map b
	WHERE b.id = a.interest_id
);


SELECT 
	COUNT(DISTINCT b.id) AS total_id_not_in_interest_metrics
FROM interest_map b
WHERE NOT EXISTS (
	SELECT 1
	FROM interest_metrics a
	WHERE a.interest_id = b.id
);


-- 5. Summarise the id values in the interest_map by its total record count in this table
SELECT
	b.id,
	b.interest_name,
	COUNT(a.interest_id) AS occurrences
FROM interest_map b
LEFT JOIN interest_metrics a
ON b.id = a.interest_id
GROUP BY b.id, b.interest_name
ORDER BY occurrences DESC;


-- 6. What sort of table join should we perform for our analysis and why? Check your logic by checking the 
-- rows where interest_id = 21246 in your joined output and include all columns from interest_metrics 
-- and all columns from.interest_map except from the id column.
SELECT * 
FROM interest_metrics
WHERE interest_id = 21246;

SELECT * 
FROM interest_map
WHERE id = 21246;

-- On question 4, it was found that every interest ID in interest_metrics matched every ID in interest_map.
-- However, when running the query the other way round, it was found that 7 IDs did not match in the 
-- interest_metrics. So, the specific join that should be used is an INNER JOIN because it will filter out
-- those 7 IDs from which data cannot be gathered in this analysis


-- 7. Are there any records in your joined table where the month_year value is before the created_at value from the 
-- interest_map table? Do you think these values are valid and why?
SELECT 
	a.month_year,
	COUNT(a.interest_id) AS occurrences
FROM interest_metrics a
JOIN interest_map b
	ON a.interest_id = b.id
WHERE a.month_year < b.created_at
GROUP BY a.month_year
ORDER BY a.month_year;

SELECT TOP 20
	a.month_year,
	b.created_at,
	a.interest_id,
	b.interest_name
FROM interest_metrics a
JOIN interest_map b
	ON a.interest_id = b.id
WHERE a.month_year < b.created_at;

-- These records are valid for a number of reasons. 
-- When the month_year column was created, the actual day was unknown and it was assumed to use
-- the first of each month was a good base. The interest_metrics table is an aggregate of results,
-- likely for a dashboard, and that could be a reason why there is no day mentioned.
-- If a specific date was required, then the best action would have been to extract the data from 
-- created_at column, and copied it into the interest_metrics table.