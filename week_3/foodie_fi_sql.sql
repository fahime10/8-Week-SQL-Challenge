USE FoodieFiDB;

SELECT * FROM plans;

SELECT TOP 10 * FROM subscriptions;

-- If the plan_id is 4, the start_date is considered the end date instead.
-- The assumption is that if a customer churns mid-way in their subscription,
-- a new record is created to indicate they are no longer a customer from that
-- specific "start_date"


-- Data Analysis Questions
-- 1. How many customers has Foodie-Fi ever had?
SELECT COUNT(DISTINCT customer_id) AS total_customers
FROM subscriptions;


-- 2. What is the monthly distribution of trial plan start_date values for our dataset - 
-- use the start of the month as the 'group by' value
SELECT 
	DATEFROMPARTS(YEAR(start_date), MONTH(start_date), 1) AS month_start,
	COUNT(customer_id) AS trial_count
FROM subscriptions
WHERE plan_id = 0
GROUP BY DATEFROMPARTS(YEAR(start_date), MONTH(start_date), 1)
ORDER BY month_start;


-- 3. What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of 
-- events for each plan_name
SELECT p.plan_id, p.plan_name, COUNT(p.plan_id) AS occurrences
FROM subscriptions s
JOIN plans p
ON s.plan_id = p.plan_id
WHERE start_date > '2020-12-31'
GROUP BY p.plan_id, p.plan_name
ORDER BY p.plan_id;


-- 4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
WITH total_customers AS (
	SELECT COUNT(DISTINCT customer_id) AS total
	FROM subscriptions
),
churned_customers AS (
	SELECT COUNT(DISTINCT customer_id) AS churn
	FROM subscriptions
	WHERE plan_id = 4
)
SELECT 
	c.churn AS customer_churn,
	CAST(100.0 * c.churn / t.total AS DECIMAL(5, 1)) AS pct_churn
FROM churned_customers c
CROSS JOIN total_customers t;


-- 5. How many customers have churned straight after their initial free trial - 
-- what percentage is this rounded to the nearest whole number?
WITH next_plans AS (
	SELECT 
		customer_id,
		plan_id,
		LEAD(plan_id) OVER(PARTITION BY customer_id ORDER BY start_date) AS next_plan_id
	FROM subscriptions
),
total_customers AS (
	SELECT COUNT(DISTINCT customer_id) AS total
	FROM subscriptions
)
SELECT 
	COUNT(n.customer_id) AS direct_churn_count,
	CAST(100.0 * COUNT(n.customer_id) / t.total AS DECIMAL(5, 0)) AS pct_churn
FROM next_plans n
CROSS JOIN total_customers t
WHERE n.plan_id = 0 AND n.next_plan_id = 4
GROUP BY t.total;


-- 6. What is the number and percentage of customer plans after their initial free trial?
WITH next_plans AS (
	SELECT 
		customer_id,
		plan_id,
		LEAD(plan_id) OVER(PARTITION BY customer_id ORDER BY start_date) AS next_plan_id
	FROM subscriptions
),
total_customers AS (
	SELECT COUNT(DISTINCT customer_id) AS total
	FROM subscriptions
)
SELECT 
	p.plan_name,
	COUNT(n.customer_id) AS customer_count,
	CAST(100.0 * COUNT(n.customer_id) / t.total AS DECIMAL(5, 0)) AS pct_plan
FROM next_plans n
CROSS JOIN total_customers t
JOIN plans p
ON p.plan_id = n.next_plan_id
WHERE n.plan_id = 0
GROUP BY t.total, p.plan_name;


-- 7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
WITH lastest_plans AS (
	SELECT
		s.customer_id,
		p.plan_name,
		ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.start_date DESC) AS ranking
	FROM subscriptions s
	JOIN plans p ON s.plan_id = p.plan_id
	WHERE s.start_date <= '2020-12-31'
	GROUP BY s.customer_id, p.plan_name, s.start_date
),
total_customers AS (
	SELECT COUNT(DISTINCT customer_id) AS total
	FROM subscriptions
)
SELECT 
	l.plan_name,
	COUNT(l.customer_id) AS customer_count,
	CAST(100.0 * COUNT(l.customer_id) / t.total AS DECIMAL(5, 0)) AS pct_plan
FROM lastest_plans l
CROSS JOIN total_customers t
WHERE ranking = 1
GROUP BY l.plan_name, t.total;


-- 8. How many customers have upgraded to an annual plan in 2020?
SELECT COUNT(DISTINCT customer_id) AS customer_count
FROM subscriptions
WHERE 
	start_date >= '2020-01-01' AND 
	start_date <= '2020-12-31' AND
	plan_id = 3;


-- 9. How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
WITH trial_date AS (
	SELECT customer_id, start_date
	FROM subscriptions
	WHERE plan_id = 0
),
annual_date AS (
	SELECT customer_id, start_date
	FROM subscriptions
	WHERE plan_id = 3
)
SELECT 
	AVG(DATEDIFF(DAY, t.start_date, a.start_date)) AS avg_days_to_change
FROM annual_date a
JOIN trial_date t ON a.customer_id = t.customer_id;


-- 10. Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
WITH trial_date AS (
	SELECT customer_id, start_date
	FROM subscriptions
	WHERE plan_id = 0
),
annual_date AS (
	SELECT customer_id, start_date
	FROM subscriptions
	WHERE plan_id = 3
),
customer_upgrade AS (
	SELECT 
		a.customer_id AS customer_id,
		DATEDIFF(DAY, t.start_date, a.start_date) AS days
	FROM annual_date a
	JOIN trial_date t ON a.customer_id = t.customer_id
)
SELECT 
	COUNT(customer_id) AS customer_count,
	CASE
		WHEN days <= 30 THEN '0-30 days'
		WHEN days <= 60 THEN '31-60 days'
		WHEN days <= 90 THEN '61-90 days'
		ELSE '90+ days'
	END AS day_range
FROM customer_upgrade
GROUP BY 
	CASE
		WHEN days <= 30 THEN '0-30 days'
		WHEN days <= 60 THEN '31-60 days'
		WHEN days <= 90 THEN '61-90 days'
		ELSE '90+ days'
	END
ORDER BY MIN(days);


-- 11. How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
WITH next_plans AS (
	SELECT 
		customer_id,
		plan_id,
		LEAD(plan_id) OVER (PARTITION BY customer_id ORDER BY start_date) AS next_plan_id
	FROM subscriptions
)
SELECT 
	COUNT(customer_id) AS downgraded_plan_count
FROM next_plans
WHERE plan_id = 2 AND next_plan_id = 1;