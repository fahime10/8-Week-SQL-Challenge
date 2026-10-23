USE DataBankDB;

-- Customer Nodes Exploration

-- 1. How many unique nodes are there on the Data Bank system?
SELECT DISTINCT node_id 
FROM customer_nodes
ORDER BY node_id;


-- 2. What is the number of nodes per region?
SELECT region_id, COUNT(DISTINCT node_id) AS node_id
FROM customer_nodes
GROUP BY region_id
ORDER BY region_id;


-- 3. How many customers are allocated to each region?
SELECT region_id, COUNT(DISTINCT customer_id) AS customers
FROM customer_nodes
GROUP BY region_id
ORDER BY region_id;


-- 4. How many days on average are customers reallocated to a different node?
WITH node_days AS (
	SELECT 
		customer_id,
		node_id,
		DATEDIFF(DAY, start_date, end_date) as days_in_node
	FROM customer_nodes
	WHERE end_date != '9999-12-31'
)
SELECT 
	AVG(CAST(days_in_node AS FLOAT)) AS avg_allocation_days
FROM node_days;


-- 5. What is the median, 80th and 95th percentile for this same reallocation days metric for each region?
WITH node_days AS (
	SELECT 
		customer_id,
		node_id,
		DATEDIFF(DAY, start_date, end_date) as days_in_node
	FROM customer_nodes
	WHERE end_date != '9999-12-31'
)
SELECT DISTINCT 
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_in_node) OVER () AS median_days,
	PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY days_in_node) OVER () AS percentile_80,
	PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY days_in_node) OVER () AS percentile_90
FROM node_days;



-- Customer Transactions

-- 1. What is the unique count and total amount for each transaction type?
SELECT txn_type, COUNT(*) AS unique_count, SUM(txn_amount) AS total_amount
FROM customer_transactions
GROUP BY txn_type;


-- 2. What is the average total historical deposit counts and amounts for all customers?
WITH customer_deposits AS (
	SELECT
		customer_id,
		COUNT(*) AS total_deposit_count,
		SUM(txn_amount) AS total_deposit_amount
	FROM customer_transactions
	WHERE txn_type = 'deposit'
	GROUP BY customer_id
)
SELECT
	AVG(CAST(total_deposit_count AS FLOAT)) AS avg_total_deposit_count,
	AVG(total_deposit_amount) AS avg_total_deposit_amount
FROM customer_deposits;


-- 3. For each month - how many Data Bank customers make more than 1 deposit and 
-- either 1 purchase or 1 withdrawal in a single month?
WITH monthly_data AS (
	SELECT 
		customer_id, 
		MONTH(txn_date) AS month,
		COUNT(
			CASE 
				WHEN txn_type = 'deposit' THEN 1
			END
		) AS deposit_count,
		COUNT(
			CASE 
				WHEN txn_type = 'purchase' THEN 1
			END
		) AS purchase_count,
		COUNT(
			CASE 
				WHEN txn_type = 'withdrawal' THEN 1
			END
		) AS withdrawal_count
	FROM customer_transactions
	GROUP BY customer_id, MONTH(txn_date)
)
SELECT 
	month,
	COUNT(DISTINCT customer_id) AS customer_count
FROM monthly_data
WHERE deposit_count > 1 AND (purchase_count > 0 OR withdrawal_count > 0)
GROUP BY month
ORDER BY month;

-- Not having the ELSE statement in the CASE statement will apply a null value,
-- and the final result will ignore any null values


-- 4. What is the closing balance for each customer at the end of the month?
WITH customer_monthly_change AS (
	SELECT 
		customer_id,
		MONTH(txn_date) AS month,
		SUM(
			CASE 
				WHEN txn_type = 'deposit' THEN txn_amount
				ELSE -txn_amount
			END
		) AS net_monthly_amount
	FROM customer_transactions
	GROUP BY customer_id, MONTH(txn_date)
)
SELECT
	customer_id,
	month,
	SUM(net_monthly_amount) OVER (PARTITION BY customer_id ORDER BY month) AS closing_balance
FROM customer_monthly_change
ORDER BY customer_id, month;


-- 5. What is the percentage of customers who increase their closing balance by more than 5%?
WITH customer_monthly_change AS (
	SELECT 
		customer_id,
		MONTH(txn_date) AS month,
		SUM(
			CASE 
				WHEN txn_type = 'deposit' THEN txn_amount
				ELSE -txn_amount
			END
		) AS net_monthly_amount
	FROM customer_transactions
	GROUP BY customer_id, MONTH(txn_date)
),
closing_balances AS (
	SELECT
		customer_id,
		month,
		SUM(net_monthly_amount) OVER (PARTITION BY customer_id ORDER BY month) AS closing_balance
	FROM customer_monthly_change
),
balance_check AS (
	SELECT 
		customer_id,
		month,
		CASE 
			WHEN (closing_balance) > (LAG(closing_balance, 1) OVER (PARTITION BY customer_id ORDER BY month) * 1.05) THEN 1
			ELSE 0
		END AS result
	FROM closing_balances
)
SELECT
	ROUND((SUM(CAST(result AS FLOAT)) / COUNT(customer_id)) * 100.0, 2) AS pct_balance_above_5_pct
FROM balance_check;