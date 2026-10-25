USE DataMartDB;

-- Data cleaning steps suggested by the author of the dataset
SELECT TOP 5 * FROM weekly_sales;

-- Date format is not the usual YYYY-MM-DD, so a different method for converting
-- should be used
-- The CONVERT(DATE, {column_name}, 3) should work for formats with DD/MM/YY

SELECT
	CONVERT(DATE, week_date, 3) AS week_date,
	DATEPART(week, CONVERT(DATE, week_date, 3)) AS week_number,
	DATEPART(month, CONVERT(DATE, week_date, 3)) AS month_number,
	YEAR(CONVERT(DATE, week_date, 3)) AS calendar_year,
	region,
	platform,
	segment,
	CASE
		WHEN segment LIKE '%1' THEN 'Young Adults'
		WHEN segment LIKE '%2' THEN 'Middle Aged'
		WHEN segment LIKE '%3' OR segment LIKE '%4' THEN 'Retirees'
		ELSE 'Unknown'
	END AS age_band,
	CASE
		WHEN segment LIKE 'C%' THEN 'Couples'
		WHEN segment LIKE 'F%' THEN 'Families'
		ELSE 'Unknown'
	END AS demographic,
	customer_type,
	transactions,
	sales,
	ROUND(CAST(sales AS FLOAT) / transactions, 2) AS avg_transaction
INTO clean_weekly_sales
FROM weekly_sales;