USE FreshSegmentsDB;

-- Interest Analysis

-- 1. Which interests have been present in all month_year dates in our dataset?
WITH interests AS (
	SELECT
		a.interest_id,
		b.interest_name,
		a.month_year
	FROM interest_metrics a
	JOIN interest_map b
		ON a.interest_id = b.id
),
month_year_count AS (
	SELECT
		COUNT(DISTINCT month_year) AS total_months
	FROM interest_metrics
),
interest_month_year_match AS (
	SELECT 
		interest_id,
		interest_name,
		COUNT(DISTINCT month_year) AS occurrences
	FROM interests
	GROUP BY interest_id, interest_name
)
SELECT
	interest_id,
	interest_name
FROM interest_month_year_match, month_year_count
WHERE occurrences = total_months;


-- 2. Using this same total_months measure - calculate the cumulative percentage of all records starting at 14 months - 
-- which total_months value passes the 90% cumulative percentage value?
WITH interests AS (
	SELECT
		a.interest_id,
		b.interest_name,
		a.month_year
	FROM interest_metrics a
	JOIN interest_map b
		ON a.interest_id = b.id
),
interest_month_year_match AS (
	SELECT 
		interest_id,
		interest_name,
		COUNT(DISTINCT month_year) AS occurrences
	FROM interests
	GROUP BY interest_id, interest_name
),
interests_count AS (
	SELECT
		occurrences,
		COUNT(DISTINCT interest_id) AS total_interests
	FROM interest_month_year_match
	GROUP BY occurrences
),
cumulative_calc AS (
	SELECT 
		occurrences,
		total_interests,
		SUM(total_interests) OVER (ORDER BY occurrences DESC) AS cumulative_interests,
		SUM(total_interests) OVER () AS grand_total_interests
	FROM interests_count
)
SELECT
	occurrences AS total_months,
	total_interests,
	cumulative_interests,
	CAST(100.0 * cumulative_interests / grand_total_interests AS DECIMAL(5, 2)) AS pct_cumulative
FROM cumulative_calc
ORDER BY total_months DESC;

-- At 6 total_months, it exceeds 90% cumulative percentage.

-- This question is useful because it asks for a threshold of 90% to avoid noisy data.
-- Each interest represents a consumer behavioural trait, and so you want to see if people exhibit these behavours
-- month after month. This will form the sort of bedrock of your marketing strategy. Only relying on 2 months' data
-- will not be enough because they may either skew the data in the wrong direction or only show a seasonal
-- behaviour that suddenly vanishes after 2 months.
-- The reason why we start at month 14 is because it is already assumed that the behavioural traits have stabilized 
-- around the end (or most recent) data, and so it makes sense to not start at month 1 for example. At month 1, it
-- is highly likely you would introduce noisy data, "short-lived fads", and never find these results again in the more
-- recent data.


-- 3. If we were to remove all interest_id values which are lower than the total_months value we found in the previous 
-- question - how many total data points would we be removing?

-- Knowing that at 6 months, the threshold was exceeded, we would need to look at data before the 6 months

WITH interests AS (
	SELECT
		a.interest_id,
		b.interest_name,
		a.month_year
	FROM interest_metrics a
	JOIN interest_map b
		ON a.interest_id = b.id
),
interest_month_year_match AS (
	SELECT 
		interest_id,
		COUNT(DISTINCT month_year) AS occurrences
	FROM interests
	GROUP BY interest_id, interest_name
),
interests_count AS (
	SELECT
		occurrences,
		COUNT(DISTINCT interest_id) AS total_interests
	FROM interest_month_year_match
	GROUP BY occurrences
)
SELECT
	COUNT(*) AS total_out_threshold
FROM interest_metrics
WHERE interest_id IN (
	SELECT interest_id
	FROM interest_month_year_match
	WHERE occurrences < 6
);

-- 400 records


-- 4. Does this decision make sense to remove these data points from a business perspective? Use an example where there are 
-- all 14 months present to a removed interest example for your arguments - think about what it means to have less months 
-- present from a segment perspective.

-- There are benefits and drawbacks when removing these interests. The benefits are that these data may be considered noisy, and 
-- adding these may skew the data in a dashboard. The drawbacks are that these interests may represent a niche, so the data you 
-- would have deleted may have started a new trend that you have missed due to deleting that data. 
-- The filter is any trend that did not last more than 5 months would be wiped from the dataset and that can cause an oversight
-- on emerging trends that could have been consistent.


-- 5. After removing these interests - how many unique interests are there for each month?
SELECT COUNT(*) AS total_records
FROM interest_metrics;

-- 13,079 initial total records

WITH short_lived_interests AS (
	SELECT
		interest_id
	FROM interest_metrics
	GROUP BY interest_id
	HAVING COUNT(DISTINCT month_year) < 6
)
SELECT 
	COUNT(*) AS remaining_records
FROM interest_metrics
WHERE interest_id NOT IN (
	SELECT interest_id
	FROM short_lived_interests
);

-- 12,679 records, which is correct when subtracting 400 from 13,079

WITH short_lived_interests AS (
	SELECT
		interest_id
	FROM interest_metrics
	GROUP BY interest_id
	HAVING COUNT(DISTINCT month_year) < 6
)
SELECT 
	*
INTO interest_metrics_updated
FROM interest_metrics
WHERE interest_id NOT IN (
	SELECT interest_id
	FROM short_lived_interests
);