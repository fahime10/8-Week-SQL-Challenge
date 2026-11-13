USE FreshSegmentsDB;

-- Segment Analysis

-- 1. Using our filtered dataset by removing the interests with less than 6 months worth of data, which are the top 10 
-- and bottom 10 interests which have the largest composition values in any month_year? Only use the maximum composition 
-- value for each interest but you must keep the corresponding month_year

-- Top 10
WITH max_interest AS (
	SELECT
		a.month_year,
		a.interest_id,
		b.interest_name,
		a.composition,
		ROW_NUMBER() OVER (PARTITION BY a.interest_id ORDER BY a.composition DESC) AS rn
	FROM interest_metrics_updated a
	JOIN interest_map b
		ON a.interest_id = b.id
),
interest_peaks AS (
	SELECT
		month_year,
		interest_id,
		interest_name,
		composition AS max_composition
	FROM max_interest
	WHERE rn = 1
)
SELECT TOP 10
	month_year,
	interest_name,
	max_composition
FROM interest_peaks
ORDER BY max_composition DESC;

-- Bottom 10
WITH max_interest AS (
	SELECT
		a.month_year,
		a.interest_id,
		b.interest_name,
		a.composition,
		ROW_NUMBER() OVER (PARTITION BY a.interest_id ORDER BY a.composition DESC) AS rn
	FROM interest_metrics_updated a
	JOIN interest_map b
		ON a.interest_id = b.id
),
interest_peaks AS (
	SELECT
		month_year,
		interest_id,
		interest_name,
		composition AS max_composition
	FROM max_interest
	WHERE rn = 1
)
SELECT TOP 10
	month_year,
	interest_name,
	max_composition
FROM interest_peaks
ORDER BY max_composition;


-- 2. Which 5 interests had the lowest average ranking value?
WITH average_ranking AS (
	SELECT
		a.interest_id,
		b.interest_name,
		CAST(AVG(ranking) AS DECIMAL(10, 2)) AS avg_ranking
	FROM interest_metrics_updated a
	JOIN interest_map b
		ON a.interest_id = b.id
	GROUP BY a.interest_id, b.interest_name
)
SELECT TOP 5
	interest_name,
	avg_ranking
FROM average_ranking
ORDER BY avg_ranking;


-- 3. Which 5 interests had the largest standard deviation in their percentile_ranking value?
WITH stdev_interests AS (
	SELECT
		a.interest_id,
		b.interest_name,
		CAST(STDEV(percentile_ranking) AS DECIMAL(5, 2)) AS stdev_percentile_ranking
	FROM interest_metrics_updated a
	JOIN interest_map b
		ON a.interest_id = b.id
	GROUP BY a.interest_id, b.interest_name
)
SELECT TOP 5
	interest_name,
	stdev_percentile_ranking
FROM stdev_interests
ORDER BY stdev_percentile_ranking DESC;


-- 4. For the 5 interests found in the previous question - what was minimum and maximum percentile_ranking 
-- values for each interest and its corresponding year_month value? Can you describe what is happening for these 5 interests?
WITH stdev_interests AS (
	SELECT
		a.interest_id,
		b.interest_name,
		CAST(STDEV(percentile_ranking) AS DECIMAL(5, 2)) AS stdev_percentile_ranking
	FROM interest_metrics_updated a
	JOIN interest_map b
		ON a.interest_id = b.id
	GROUP BY a.interest_id, b.interest_name
),
top_5_stdev AS (
	SELECT TOP 5
		interest_id,
		interest_name,
		stdev_percentile_ranking
	FROM stdev_interests
	ORDER BY stdev_percentile_ranking DESC
),
ranked_percentiles AS (
	SELECT
		a.interest_id,
		c.interest_name,
		a.month_year,
		a.percentile_ranking,
		ROW_NUMBER() OVER (PARTITION BY a.interest_id ORDER BY a.percentile_ranking ASC) AS min_rn,
		ROW_NUMBER() OVER (PARTITION BY a.interest_id ORDER BY a.percentile_ranking DESC) AS max_rn
	FROM interest_metrics_updated a
	JOIN top_5_stdev c
		ON a.interest_id = c.interest_id
)
SELECT
	interest_name,
	MAX(CASE WHEN min_rn = 1 THEN percentile_ranking END) AS min_percentile_ranking,
	MAX(CASE WHEN min_rn = 1 THEN month_year END) AS min_month_year,
	MAX(CASE WHEN max_rn = 1 THEN percentile_ranking END) AS max_percentile_ranking,
	MAX(CASE WHEN max_rn = 1 THEN month_year END) AS max_month_year
FROM ranked_percentiles
GROUP BY interest_name;


-- 5. How would you describe our customers in this segment based off their composition and ranking values? 
-- What sort of products or services should we show to these customers and what should we avoid?
WITH stdev_interests AS (
	SELECT
		a.interest_id,
		b.interest_name,
		b.interest_summary,
		CAST(STDEV(percentile_ranking) AS DECIMAL(5, 2)) AS stdev_percentile_ranking
	FROM interest_metrics_updated a
	JOIN interest_map b
		ON a.interest_id = b.id
	GROUP BY a.interest_id, b.interest_name, b.interest_summary
)
SELECT TOP 5
	interest_name,
	interest_summary,
	stdev_percentile_ranking
FROM stdev_interests
ORDER BY stdev_percentile_ranking DESC;

-- Based on the interest summary, there is a pattern behind these volatile interests. Customers in this segment are 
-- spending money on attractions and accomodations, likely because they are going on holiday soon.
-- There are also niche trends, such as reading tech reviews shopping for personalized gifts.

-- For the season-specific interests, the target would be to use short-burst, high-intent campaign budget, so that investments
-- are made just before the holiday season and not throughout the year.

-- 