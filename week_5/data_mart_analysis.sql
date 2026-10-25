USE DataMartDB;

-- Data Exploration

-- 1. What day of the week is used for each week_date value?
SELECT DISTINCT(DATENAME(WEEKDAY, week_date)) AS week_day
FROM clean_weekly_sales
ORDER BY week_day;

-- Monday

-- 2. What range of week numbers are missing from the dataset?
WITH all_weeks AS (
	SELECT 1 AS week_number
	UNION ALL
	SELECT week_number + 1
	FROM all_weeks
	WHERE week_number < 52
)
SELECT week_number AS missing_week
FROM all_weeks
EXCEPT
SELECT DISTINCT week_number
FROM clean_weekly_sales
ORDER BY missing_week;


-- 3. How many total transactions were there for each year in the dataset?
SELECT calendar_year, SUM(transactions) AS total_transactions
FROM clean_weekly_sales
GROUP BY calendar_year
ORDER BY calendar_year;


-- 4. What is the total sales for each region for each month?
SELECT region, month_number, SUM(CAST(sales AS BIGINT)) AS total_sales
FROM clean_weekly_sales
GROUP BY region, month_number
ORDER BY month_number;


-- 5. What is the total count of transactions for each platform?
SELECT platform, SUM(transactions) AS number_of_transactions
FROM clean_weekly_sales
GROUP BY platform;

-- In this scenario, COUNT() is not used because the column represents
-- an aggregated group, so counting the number of rows would not
-- answer the question


-- 6. What is the percentage of sales for Retail vs Shopify for each month?
SELECT
	calendar_year,
	month_number,
	CAST(100.0 * SUM(CASE WHEN platform = 'Retail' THEN CAST(sales AS BIGINT) ELSE 0 END) / SUM(CAST(sales AS BIGINT)) AS DECIMAL(5, 2)) AS retail_sales,
	CAST(100.0 * SUM(CASE WHEN platform = 'Shopify' THEN CAST(sales AS BIGINT) ELSE 0 END) / SUM(CAST(sales AS BIGINT)) AS DECIMAL(5, 2)) AS shopify_sales
FROM clean_weekly_sales
GROUP BY calendar_year, month_number
ORDER BY calendar_year, month_number;


-- 7. What is the percentage of sales by demographic for each year in the dataset?

-- Wide format
SELECT 
    calendar_year,
    CAST(100.0 * SUM(CASE WHEN demographic = 'Couples' THEN CAST(sales AS BIGINT) ELSE 0 END) 
        / SUM(CAST(sales AS BIGINT)) AS DECIMAL(5,2)) AS couples_pct,

    CAST(100.0 * SUM(CASE WHEN demographic = 'Families' THEN CAST(sales AS BIGINT) ELSE 0 END) 
        / SUM(CAST(sales AS BIGINT)) AS DECIMAL(5,2)) AS families_pct,

    CAST(100.0 * SUM(CASE WHEN demographic = 'Unknown' THEN CAST(sales AS BIGINT) ELSE 0 END) 
        / SUM(CAST(sales AS BIGINT)) AS DECIMAL(5,2)) AS unknown_pct
FROM clean_weekly_sales
GROUP BY calendar_year
ORDER BY calendar_year;

-- Long format
SELECT 
	calendar_year,
	demographic,
	SUM(CAST(sales AS BIGINT)) AS total_sales,
	CAST(100.0 * SUM(CAST(sales AS BIGINT)) / 
		 SUM(SUM(CAST(sales AS BIGINT))) OVER (PARTITION BY calendar_year) AS DECIMAL(5, 2)
		 ) AS pct_share
FROM clean_weekly_sales
GROUP BY demographic, calendar_year
ORDER BY calendar_year;

-- The second query does not use CASE statements and lets the query itself figure out the 
-- distinct demographics


-- 8. Which age_band and demographic values contribute the most to Retail sales?
SELECT
	age_band,
	demographic,
	SUM(CAST(sales AS BIGINT)) AS total_sales,
	CAST(100.0 * SUM(CAST(sales AS BIGINT)) / 
		 SUM(SUM(CAST(sales AS BIGINT))) OVER () AS DECIMAL(5, 2)) AS pct_share
FROM clean_weekly_sales
WHERE platform = 'Retail'
GROUP BY age_band, demographic
ORDER BY total_sales DESC;


-- 9. Can we use the avg_transaction column to find the average transaction size for 
-- each year for Retail vs Shopify? If not - how would you calculate it instead?
SELECT TOP 5 * FROM clean_weekly_sales;

-- The issue is that avg_transactions is already an average pre-calculated.
-- Each row represents a different volume of transactions, so averaging an
-- already averaged row value/s treats every row with equal weight, 
-- disregarding that some rows represent massive sales volume while there are
-- some that are tiny

SELECT
	calendar_year,
	platform,
	CAST(SUM(CAST(sales AS BIGINT)) * 1.0 /	SUM(transactions) AS DECIMAL(5, 2)) AS proposed_avg_transaction_size
FROM clean_weekly_sales
GROUP BY calendar_year, platform
ORDER BY calendar_year, platform;



-- Before & After Analysis
-- week_date 2020-06-15

-- 1. What is the total sales for the 4 weeks before and after 2020-06-15? 
-- What is the growth or reduction rate in actual values and percentage of sales?
WITH sales_period AS (
	SELECT
		CASE
			WHEN week_date >= '2020-05-18' AND week_date < '2020-06-15' THEN 'Before'
			WHEN week_date >= '2020-06-15' AND week_date <= '2020-07-06' THEN 'After'
		END AS period,
		CAST(sales AS BIGINT) AS sales
	FROM clean_weekly_sales
	WHERE week_date >= '2020-05-18' AND week_date <= '2020-07-06'
),
aggregated_period AS (
	SELECT
		SUM(CASE WHEN period = 'Before' THEN sales END) AS total_before_sales,
		SUM(CASE WHEN period = 'After' THEN sales END) AS total_after_sales
	FROM sales_period
)
SELECT
	total_before_sales,
	total_after_sales,
	total_after_sales - total_before_sales AS sales_change,
	CAST(100.0 * (total_after_sales - total_before_sales) / total_before_sales AS DECIMAL(5, 2)) AS pct_sales_change
FROM aggregated_period;

-- total_before_sales	|total_after_sales	|total_after_sales	|sales_change	|pct_sales_change
-- 2345878357			|2318994169			|2318994169			|-26884188		|-1.15


-- 2. What about the entire 12 weeks before and after?
WITH sales_period AS (
	SELECT
		CASE
			WHEN week_date >= '2020-03-23' AND week_date < '2020-06-15' THEN 'Before'
			WHEN week_date >= '2020-06-15' AND week_date <= '2020-08-31' THEN 'After'
		END AS period,
		CAST(sales AS BIGINT) AS sales
	FROM clean_weekly_sales
	WHERE week_date >= '2020-03-23' AND week_date <= '2020-08-31'
),
aggregated_period AS (
	SELECT
		SUM(CASE WHEN period = 'Before' THEN sales END) AS total_before_sales,
		SUM(CASE WHEN period = 'After' THEN sales END) AS total_after_sales
	FROM sales_period
)
SELECT
	total_before_sales,
	total_after_sales,
	total_after_sales - total_before_sales AS sales_change,
	CAST(100.0 * (total_after_sales - total_before_sales) / total_before_sales AS DECIMAL(5, 2)) AS pct_sales_change
FROM aggregated_period;

-- total_before_sales	|total_after_sales	|sales_change	|pct_sales_change
-- 7126273147			|6973947753			|-152325394		|-2.14


-- 3. How do the sale metrics for these 2 periods before and after compare with the previous years in 2018 and 2019?
WITH sales_period AS (
	SELECT
		calendar_year,
		CASE
			WHEN week_number BETWEEN 13 AND 24 THEN 'Before'
			WHEN week_number BETWEEN 25 AND 36 THEN 'After'
		END AS period,
		CAST(sales AS BIGINT) AS sales
	FROM clean_weekly_sales
	WHERE week_number BETWEEN 13 AND 36
),
aggregated_period AS (
	SELECT
		calendar_year,
		SUM(CASE WHEN period = 'Before' THEN sales END) AS total_before_sales,
		SUM(CASE WHEN period = 'After' THEN sales END) AS total_after_sales
	FROM sales_period
	GROUP BY calendar_year
)
SELECT
	calendar_year,
	total_before_sales,
	total_after_sales,
	total_after_sales - total_before_sales AS sales_change,
	CAST(100.0 * (total_after_sales - total_before_sales) / total_before_sales AS DECIMAL(5, 2)) AS pct_sales_change
FROM aggregated_period
ORDER BY calendar_year;

-- calendar_year	|total_before_sales	|total_after_sales	|sales_change	|pct_sales_change
-- 2018				|6396562317			|6500818510			|104256193		|1.63
-- 2019				|6883386397			|6862646103			|-20740294		|-0.30
-- 2020				|7126273147			|6973947753			|-152325394		|-2.14


-- Bonus Question
-- Which areas of the business have the highest negative impact in sales metrics performance in 2020 for the 12 week before and after period?
-- * region
-- * platform
-- * age_band
-- * demographic
-- * customer_type

-- Do you have any further recommendations for Danny’s team at Data Mart or any interesting insights based off this analysis?

WITH sales_period AS (
	SELECT
		region,
		CASE
			WHEN week_number BETWEEN 13 AND 24 THEN 'Before'
			WHEN week_number BETWEEN 25 AND 36 THEN 'After'
		END AS period,
		CAST(sales AS BIGINT) AS sales
	FROM clean_weekly_sales
	WHERE week_number BETWEEN 13 AND 36
),
aggregated_period AS (
	SELECT
		region,
		SUM(CASE WHEN period = 'Before' THEN sales END) AS total_before_sales,
		SUM(CASE WHEN period = 'After' THEN sales END) AS total_after_sales
	FROM sales_period
	GROUP BY region
)
SELECT
	region,
	total_before_sales,
	total_after_sales,
	total_after_sales - total_before_sales AS sales_change,
	CAST(100.0 * (total_after_sales - total_before_sales) / total_before_sales AS DECIMAL(5, 2)) AS pct_sales_change
FROM aggregated_period
ORDER BY pct_sales_change;

-- region			|total_before_sales		|total_after_sales	|sales_change	|pct_sales_change
-- ASIA				|4613242689				|4551927271			|-61315418		|-1.33
-- OCEANIA			|6698586333				|6640244793			|-58341540		|-0.87
-- CANADA			|1244662705				|1234025206			|-10637499		|-0.85
-- USA				|1967554887				|1960297502			|-7257385		|-0.37
-- SOUTH AMERICA	|611056923				|608981392			|-2075531		|-0.34
-- AFRICA			|4942976910				|4997516159			|54539249		|1.10
-- EUROPE			|328141414				|344420043			|16278629		|4.96


WITH sales_period AS (
	SELECT
		platform,
		CASE
			WHEN week_number BETWEEN 13 AND 24 THEN 'Before'
			WHEN week_number BETWEEN 25 AND 36 THEN 'After'
		END AS period,
		CAST(sales AS BIGINT) AS sales
	FROM clean_weekly_sales
	WHERE week_number BETWEEN 13 AND 36
),
aggregated_period AS (
	SELECT
		platform,
		SUM(CASE WHEN period = 'Before' THEN sales END) AS total_before_sales,
		SUM(CASE WHEN period = 'After' THEN sales END) AS total_after_sales
	FROM sales_period
	GROUP BY platform
)
SELECT
	platform,
	total_before_sales,
	total_after_sales,
	total_after_sales - total_before_sales AS sales_change,
	CAST(100.0 * (total_after_sales - total_before_sales) / total_before_sales AS DECIMAL(5, 2)) AS pct_sales_change
FROM aggregated_period
ORDER BY pct_sales_change;

-- platform		|total_before_sales		|total_after_sales		|sales_change	|pct_sales_change
-- Retail		|19886040272			|19768576165			|-117464107		|-0.59
-- Shopify		|520181589				|568836201				|48654612		|9.35


WITH sales_period AS (
	SELECT
		age_band,
		CASE
			WHEN week_number BETWEEN 13 AND 24 THEN 'Before'
			WHEN week_number BETWEEN 25 AND 36 THEN 'After'
		END AS period,
		CAST(sales AS BIGINT) AS sales
	FROM clean_weekly_sales
	WHERE week_number BETWEEN 13 AND 36
),
aggregated_period AS (
	SELECT
		age_band,
		SUM(CASE WHEN period = 'Before' THEN sales END) AS total_before_sales,
		SUM(CASE WHEN period = 'After' THEN sales END) AS total_after_sales
	FROM sales_period
	GROUP BY age_band
)
SELECT
	age_band,
	total_before_sales,
	total_after_sales,
	total_after_sales - total_before_sales AS sales_change,
	CAST(100.0 * (total_after_sales - total_before_sales) / total_before_sales AS DECIMAL(5, 2)) AS pct_sales_change
FROM aggregated_period
ORDER BY pct_sales_change;

-- age_band		|total_before_sales		|total_after_sales		|sales_change	|pct_sales_change
-- Unknown		|8191628826				|8146983408				|-44645418		|-0.55
-- Middle Aged	|3276892347				|3269748622				|-7143725		|-0.22
-- Young Adults	|2290835366				|2285973456				|-4861910		|-0.21
-- Retirees		|6646865322				|6634706880				|-12158442		|-0.18


WITH sales_period AS (
	SELECT
		demographic,
		CASE
			WHEN week_number BETWEEN 13 AND 24 THEN 'Before'
			WHEN week_number BETWEEN 25 AND 36 THEN 'After'
		END AS period,
		CAST(sales AS BIGINT) AS sales
	FROM clean_weekly_sales
	WHERE week_number BETWEEN 13 AND 36
),
aggregated_period AS (
	SELECT
		demographic,
		SUM(CASE WHEN period = 'Before' THEN sales END) AS total_before_sales,
		SUM(CASE WHEN period = 'After' THEN sales END) AS total_after_sales
	FROM sales_period
	GROUP BY demographic
)
SELECT
	demographic,
	total_before_sales,
	total_after_sales,
	total_after_sales - total_before_sales AS sales_change,
	CAST(100.0 * (total_after_sales - total_before_sales) / total_before_sales AS DECIMAL(5, 2)) AS pct_sales_change
FROM aggregated_period
ORDER BY pct_sales_change;

-- demographic	|total_before_sales		|total_after_sales	|sales_change	|pct_sales_change
-- Unknown		|8191628826				|8146983408			|-44645418		|-0.55
-- Couples		|5608866131				|5592341420			|-16524711		|-0.29
-- Families		|6605726904				|6598087538			|-7639366		|-0.12


WITH sales_period AS (
	SELECT
		customer_type,
		CASE
			WHEN week_number BETWEEN 13 AND 24 THEN 'Before'
			WHEN week_number BETWEEN 25 AND 36 THEN 'After'
		END AS period,
		CAST(sales AS BIGINT) AS sales
	FROM clean_weekly_sales
	WHERE week_number BETWEEN 13 AND 36
),
aggregated_period AS (
	SELECT
		customer_type,
		SUM(CASE WHEN period = 'Before' THEN sales END) AS total_before_sales,
		SUM(CASE WHEN period = 'After' THEN sales END) AS total_after_sales
	FROM sales_period
	GROUP BY customer_type
)
SELECT
	customer_type,
	total_before_sales,
	total_after_sales,
	total_after_sales - total_before_sales AS sales_change,
	CAST(100.0 * (total_after_sales - total_before_sales) / total_before_sales AS DECIMAL(5, 2)) AS pct_sales_change
FROM aggregated_period
ORDER BY pct_sales_change;

-- customer_type	|total_before_sales		|total_after_sales	|sales_change	|pct_sales_change
-- Existing			|10168877642			|10117367239		|-51510403		|-0.51
-- Guest			|7630353739				|7595150744			|-35202995		|-0.46
-- New				|2606990480				|2624894383			|17903903		|0.69