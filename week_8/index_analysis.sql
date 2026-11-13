USE FreshSegmentsDB;

-- Index Analysis
-- The index_value is a measure which can be used to reverse calculate the average composition for Fresh Segments’ clients.
-- Average composition can be calculated by dividing the composition column by the index_value column rounded to 2 decimal places.

-- 1. What is the top 10 interests by the average composition for each month?
WITH average_composition AS (
	SELECT
		a.month_year,
		a.interest_id,
		b.interest_name,
		CAST(a.composition / a.index_value AS DECIMAL(5, 2)) AS avg_composition
	FROM interest_metrics a
	JOIN interest_map b
		ON a.interest_id = b.id
),
ranked_interests AS (
	SELECT
		month_year,
		interest_id,
		interest_name,
		avg_composition,
		RANK() OVER (PARTITION BY month_year ORDER BY avg_composition DESC) AS rn
	FROM average_composition
)
SELECT
	month_year,
	interest_name,
	avg_composition
FROM ranked_interests
WHERE rn <= 10
ORDER BY month_year, rn;


-- 2. For all of these top 10 interests - which interest appears the most often?
WITH average_composition AS (
	SELECT
		a.month_year,
		a.interest_id,
		b.interest_name,
		CAST(a.composition / a.index_value AS DECIMAL(5, 2)) AS avg_composition
	FROM interest_metrics a
	JOIN interest_map b
		ON a.interest_id = b.id
),
ranked_interests AS (
	SELECT
		month_year,
		interest_id,
		interest_name,
		avg_composition,
		RANK() OVER (PARTITION BY month_year ORDER BY avg_composition DESC) AS rn
	FROM average_composition
),
top_10 AS (
	SELECT
		month_year,
		interest_name,
		avg_composition
	FROM ranked_interests
	WHERE rn <= 10
)
SELECT 
	interest_name,
	COUNT(*) AS appearance_count
FROM top_10
GROUP BY interest_name
ORDER BY appearance_count DESC;


-- 3. What is the average of the average composition for the top 10 interests for each month?
WITH average_composition AS (
	SELECT
		a.month_year,
		a.interest_id,
		b.interest_name,
		CAST(a.composition / a.index_value AS DECIMAL(5, 2)) AS avg_composition
	FROM interest_metrics a
	JOIN interest_map b
		ON a.interest_id = b.id
),
ranked_interests AS (
	SELECT
		month_year,
		interest_id,
		interest_name,
		avg_composition,
		RANK() OVER (PARTITION BY month_year ORDER BY avg_composition DESC) AS rn
	FROM average_composition
)
SELECT
	month_year,
	CAST(AVG(avg_composition) AS DECIMAL(5,2)) AS avg_avg_composition
FROM ranked_interests
WHERE rn <= 10
GROUP BY month_year
ORDER BY month_year;


-- 4. What is the 3 month rolling average of the max average composition value from September 2018 to August 2019 
-- and include the previous top ranking interests in the same output shown below.
WITH average_composition AS (
	SELECT
		a.month_year,
		a.interest_id,
		b.interest_name,
		CAST(a.composition / a.index_value AS DECIMAL(5, 2)) AS avg_composition
	FROM interest_metrics a
	JOIN interest_map b
		ON a.interest_id = b.id
),
ranked_interests AS (
	SELECT
		month_year,
		interest_id,
		interest_name,
		avg_composition,
		RANK() OVER (PARTITION BY month_year ORDER BY avg_composition DESC) AS rn
	FROM average_composition
),
max_avg_month AS (
	SELECT
		month_year,
		interest_name,
		avg_composition
	FROM ranked_interests
	WHERE rn = 1
)
SELECT 
	month_year,
	interest_name,
	avg_composition,
	ROUND(AVG(avg_composition) OVER (
		ORDER BY month_year ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
	), 2) AS rolling_3_month_average,
	LAG(interest_name, 1) OVER (ORDER BY month_year) AS one_month_prior,
	LAG(avg_composition, 1) OVER (ORDER BY month_year) AS one_month_prior_,
	LAG(interest_name, 2) OVER (ORDER BY month_year) AS two_month_prior,
	LAG(avg_composition, 2) OVER (ORDER BY month_year) AS two_month_prior_
FROM max_avg_month
WHERE month_year >= '2018-09-01' AND month_year <= '2019-08-01'
ORDER BY month_year;


-- 5. Provide a possible reason why the max average composition might change from month to month? 
-- Could it signal something is not quite right with the overall business model for Fresh Segments?

-- There can be a number of reasons why average composition decreases each month.
-- One of the reasons can be dilution of niches interests at the start, which means that the data was skewed 
-- towards specific interests, and as more data was collected and the audience expanded, the composition
-- stabilized.
-- Another reason can be seasonal behaviours, and so some interests that have dominated for a number
-- of months, no longer have that level of impact.

-- The business model is not quite right. It currently relies on static metrics in a growing baseline. As 
-- overall user tracking expands, average composition score dilute over time. And, because clients buy segments
-- expecting stable targeting performance, this natural metric decay leads to decaying campaign results, client
-- dissatisfaction, and preventable churn.
-- The solution would be to shift to dynamic rolling baselines, which is about continuously updating reference point
-- in an automated fashion to forecast behaviour over a moving window of time.