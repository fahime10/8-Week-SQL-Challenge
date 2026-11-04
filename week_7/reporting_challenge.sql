USE BalancedTreeDB;

-- Reporting Challenge

SELECT
	s.txn_id,
	s.prod_id,
	s.qty,
	s.price,
	s.discount,
	s.member,
	s.start_txn_time,
	pd.product_name,
	pd.category_id,
	pd.category_name,
	pd.segment_id,
	pd.segment_name,
	pd.style_id,
	pd.style_name
INTO #monthly_sales
FROM sales s
JOIN product_details pd
ON s.prod_id = pd.product_id
WHERE s.start_txn_time >= '2021-01-01' AND s.start_txn_time < '2021-02-01';

PRINT '--------------------------------------';
PRINT '|Section A: High Level Sales Analysis|';
PRINT '--------------------------------------';

SELECT 
	SUM(qty) AS total_quantity_sold,
	CAST(SUM(price * qty) AS DECIMAL(10, 2)) AS total_revenue,
	CAST(SUM(price * qty * (discount / 100.0)) AS DECIMAL(10, 2)) AS total_discount
FROM #monthly_sales;


PRINT '---------------------------------';
PRINT '|Section B: Transaction Analysis|';
PRINT '---------------------------------';

SELECT 
	COUNT(DISTINCT txn_id) AS unique_transactions 
FROM #monthly_sales;


-- Unique products purchased in each transaction
WITH prod_per_txn AS (
	SELECT txn_id, COUNT(DISTINCT prod_id) AS unique_products
	FROM #monthly_sales
	GROUP BY txn_id
)
SELECT
	AVG(CAST(unique_products AS FLOAT)) AS unique_products
FROM prod_per_txn;


-- 25th, 50th and 75th percentile values for the revenue per transaction
WITH all_revenue AS (
	SELECT 
		txn_id,
		CAST(SUM(price * qty * (1.0 - discount / 100.0)) AS DECIMAL(10, 2)) AS txn_revenue
	FROM #monthly_sales
	GROUP BY txn_id
)
SELECT DISTINCT
	PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY txn_revenue) OVER () AS pct_25,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY txn_revenue) OVER () AS pct_50,
	PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY txn_revenue) OVER () AS pct_75
FROM all_revenue;


-- Average discount value per transaction
WITH discount_values AS (
	SELECT 
		txn_id,
		SUM(price * qty * (discount / 100.0)) AS total_txn_discount
	FROM #monthly_sales
	GROUP BY txn_id
)
SELECT
	CAST(AVG(total_txn_discount) AS DECIMAL(10, 2)) AS avg_discount_value
FROM discount_values;


-- Percentage split of all transactions for members vs non-members
WITH all_members AS (
	SELECT
		txn_id,
		member
	FROM #monthly_sales
	GROUP BY txn_id, member
)
SELECT
	member,
	COUNT(txn_id) AS total_transactions,
	CAST(100.0 * COUNT(txn_id) / (SELECT COUNT(*) FROM all_members) AS DECIMAL(10, 2)) AS pct_customers
FROM all_members
GROUP BY member;

-- Average revenue for member transactions and non-member transactions
WITH all_members AS (
	SELECT
		txn_id,
		member,
		SUM(price * qty * (1.0 - discount / 100.0)) AS txn_revenue
	FROM #monthly_sales
	GROUP BY txn_id, member
)
SELECT
	member,
	COUNT(txn_id) AS total_transactions,
	CAST(100.0 * COUNT(txn_id) / (SELECT COUNT(*) FROM all_members) AS DECIMAL(10, 2)) AS pct_customers,
	CAST(AVG(txn_revenue) AS DECIMAL(10, 2)) AS avg_revenue
FROM all_members
GROUP BY member;


PRINT '-----------------------------';
PRINT '|Section C: Product Analysis|';
PRINT '-----------------------------';

-- Top 3 products by total revenue before discount
SELECT TOP 3 
	product_name,
	CAST(SUM(price * qty) AS DECIMAL(10, 2)) AS revenue
FROM #monthly_sales 
GROUP BY product_name
ORDER BY revenue DESC;


-- Total quantity, revenue and discount for each segment
SELECT 
	segment_id AS segment,
	SUM(qty) AS total_quantity,
	CAST(SUM(price * qty * (1.0 - (discount / 100.0))) AS DECIMAL(10, 2)) AS revenue,
	CAST(SUM(price * qty * (discount / 100.0)) AS DECIMAL(10, 2)) AS total_discount
FROM #monthly_sales
GROUP BY segment_id
ORDER BY segment_id;


-- Top selling product for each segment
WITH product_revenue AS (
	SELECT
		segment_id AS segment,
		product_name,
		CAST(SUM(price * qty * (1.0 - (discount / 100.0))) AS DECIMAL(10, 2)) AS revenue,
		ROW_NUMBER() OVER (PARTITION BY segment_id ORDER BY CAST(SUM(price * qty * (1.0 * (discount / 100.0))) AS DECIMAL(10 ,2)) DESC) AS rn
	FROM #monthly_sales
	GROUP BY segment_id, product_name
)
SELECT 
	segment,
	product_name AS top_selling,
	revenue
FROM product_revenue
WHERE rn = 1;


-- Total quantity, revenue and discount for each category
SELECT 
	category_id AS category,
	SUM(qty) AS total_quantity,
	CAST(SUM(price * qty * (1.0 - (discount / 100.0))) AS DECIMAL(10, 2)) AS revenue,
	CAST(SUM(price * qty * (discount / 100.0)) AS DECIMAL(10, 2)) AS total_discount
FROM #monthly_sales
GROUP BY category_id
ORDER BY category_id;


-- Top selling product for each category
WITH product_revenue AS (
	SELECT
		category_id AS category,
		product_name,
		CAST(SUM(price * qty * (1.0 * (discount / 100.0))) AS DECIMAL(10, 2)) AS revenue,
		ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY CAST(SUM(price * qty * (1.0 - (discount / 100.0))) AS DECIMAL(10 ,2)) DESC) AS rn
	FROM #monthly_sales
	GROUP BY category_id, product_name
)
SELECT 
	category,
	product_name AS top_selling,
	revenue
FROM product_revenue
WHERE rn = 1;


-- Percentage split of revenue by product for each segment
WITH all_products AS (
	SELECT 
		segment_id AS segment,
		prod_id,
		CAST(SUM(price * qty * (1.0 - (discount / 100))) AS DECIMAL(10, 2)) AS revenue
	FROM #monthly_sales
	GROUP BY segment_id, prod_id
),
segment_revenue AS (
	SELECT 
		segment,
		CAST(SUM(revenue) AS DECIMAL(10, 2)) AS revenue
	FROM all_products
	GROUP BY segment
)
SELECT
	segment,
	revenue,
	CAST(100.0 * revenue / (SELECT SUM(revenue) FROM segment_revenue) AS DECIMAL(10, 2)) AS pct_split
FROM segment_revenue;



-- Percentage split of revenue by segment for each category
WITH all_products AS (
	SELECT 
		category_id AS category,
		segment_id AS segment,
		CAST(SUM(price * qty * (1.0 - (discount / 100))) AS DECIMAL(10, 2)) AS revenue
	FROM #monthly_sales
	GROUP BY category_id, segment_id
)
SELECT 
	category,
	segment,
	revenue,
	CAST(100.0 * revenue / SUM(revenue) OVER (PARTITION BY category) AS DECIMAL(10, 2)) AS pct_split
FROM all_products
ORDER BY category, revenue DESC;


-- Percentage split of total revenue by category
WITH all_products AS (
	SELECT 
		category_id AS category,
		prod_id,
		CAST(SUM(price * qty * (1.0 - (discount / 100))) AS DECIMAL(10, 2)) AS revenue
	FROM #monthly_sales
	GROUP BY category_id, prod_id
),
category_revenue AS (
	SELECT 
		category,
		CAST(SUM(revenue) AS decimal(10, 2)) AS revenue
	FROM all_products
	GROUP BY category
)
SELECT
	category,
	revenue,
	CAST(100.0 * revenue / (SELECT SUM(revenue) FROM category_revenue) AS DECIMAL(10, 2)) AS pct_split
FROM category_revenue;



-- Total transaction “penetration” for each product
WITH unique_transactions AS (
	SELECT 
		prod_id,
		product_name,
		COUNT(DISTINCT txn_id) AS product_txn_count
	FROM #monthly_sales
	GROUP BY prod_id, product_name
),
total_transactions AS (
	SELECT 
		COUNT(DISTINCT txn_id) AS total_txn
	FROM #monthly_sales
)
SELECT
	ut.product_name,
	CAST(100.0 * ut.product_txn_count / tt.total_txn AS DECIMAL(10, 2)) AS pct_product_penetration
FROM unique_transactions ut, total_transactions tt
ORDER BY pct_product_penetration DESC; 


-- Most common combination of at least 1 quantity of any 3 products in a 1 single transaction
WITH unique_products AS (
	SELECT
		txn_id,
		prod_id
	FROM #monthly_sales
	GROUP BY txn_id, prod_id
),
combination AS (
	SELECT TOP 1
		t1.prod_id AS prod_1,
		t2.prod_id AS prod_2,
		t3.prod_id AS prod_3,
		COUNT(*) AS combo_count
	FROM unique_products t1
	JOIN unique_products t2
	ON t1.txn_id = t2.txn_id AND t1.prod_id < t2.prod_id
	JOIN unique_products t3
	ON t2.txn_id = t3.txn_id AND t2.prod_id < t3.prod_id
	GROUP BY t1.prod_id, t2.prod_id, t3.prod_id
	ORDER BY combo_count DESC
)
SELECT
	p1.product_name,
	p2.product_name,
	p3.product_name
FROM product_details p1
JOIN combination c
ON p1.product_id = c.prod_1
JOIN product_details p2
ON p2.product_id = c.prod_2
JOIN product_details p3 
ON p3.product_id = c.prod_3;

-- Cleanup
DROP TABLE #monthly_sales;