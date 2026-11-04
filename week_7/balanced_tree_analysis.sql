USE BalancedTreeDB;

-- High Level Sales Analysis

-- 1. What was the total quantity sold for all products?
SELECT SUM(qty) AS total_quantity_sold FROM sales;


-- 2. What is the total generated revenue for all products before discounts?
SELECT CAST(SUM(price * qty) AS DECIMAL(10, 2)) AS revenue FROM sales;


-- 3. What was the total discount amount for all products?
SELECT CAST(SUM(price * qty * (discount / 100.0)) AS DECIMAL(10, 2)) AS total_discount FROM sales;

-- This result is only about the total discount applied to all products so far, not the actual revenue



-- Transaction Analysis

-- 1. How many unique transactions were there?
SELECT COUNT(DISTINCT txn_id) AS unique_transactions FROM sales;


-- 2. What is the average unique products purchased in each transaction?
WITH prod_per_txn AS (
	SELECT txn_id, COUNT(DISTINCT prod_id) AS unique_products
	FROM sales
	GROUP BY txn_id
)
SELECT
	AVG(CAST(unique_products AS FLOAT)) AS unique_products
FROM prod_per_txn;


-- 3. What are the 25th, 50th and 75th percentile values for the revenue per transaction?
WITH all_revenue AS (
	SELECT 
		txn_id,
		CAST(SUM(price * qty * (1.0 - discount / 100.0)) AS DECIMAL(10, 2)) AS txn_revenue
	FROM sales
	GROUP BY txn_id
)
SELECT DISTINCT
	PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY txn_revenue) OVER () AS pct_25,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY txn_revenue) OVER () AS pct_50,
	PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY txn_revenue) OVER () AS pct_75
FROM all_revenue;


-- 4. What is the average discount value per transaction?
WITH discount_values AS (
	SELECT 
		txn_id,
		SUM(price * qty * (discount / 100.0)) AS total_txn_discount
	FROM sales
	GROUP BY txn_id
)
SELECT
	CAST(AVG(total_txn_discount) AS DECIMAL(10, 2)) AS avg_discount_value
FROM discount_values;


-- 5. What is the percentage split of all transactions for members vs non-members?
WITH all_members AS (
	SELECT
		txn_id,
		member
	FROM sales
	GROUP BY txn_id, member
)
SELECT
	member,
	COUNT(txn_id) AS total_transactions,
	CAST(100.0 * COUNT(txn_id) / (SELECT COUNT(*) FROM all_members) AS DECIMAL(10, 2)) AS pct_customers
FROM all_members
GROUP BY member;


-- 6. What is the average revenue for member transactions and non-member transactions?
WITH all_members AS (
	SELECT
		txn_id,
		member,
		SUM(price * qty * (1.0 - discount / 100.0)) AS txn_revenue
	FROM sales
	GROUP BY txn_id, member
)
SELECT
	member,
	COUNT(txn_id) AS total_transactions,
	CAST(100.0 * COUNT(txn_id) / (SELECT COUNT(*) FROM all_members) AS DECIMAL(10, 2)) AS pct_customers,
	CAST(AVG(txn_revenue) AS DECIMAL(10, 2)) AS avg_revenue
FROM all_members
GROUP BY member;


-- Product Analysis

-- 1. What are the top 3 products by total revenue before discount?
SELECT TOP 3 
	pd.product_name,
	CAST(SUM(s.price * s.qty) AS DECIMAL(10, 2)) AS revenue
FROM sales s
JOIN product_details pd 
ON s.prod_id = pd.product_id
GROUP BY pd.product_name
ORDER BY revenue DESC;


-- 2. What is the total quantity, revenue and discount for each segment?
SELECT 
	pd.segment_id AS segment,
	SUM(s.qty) AS total_quantity,
	CAST(SUM(s.price * s.qty * (1.0 - (s.discount / 100.0))) AS DECIMAL(10, 2)) AS revenue,
	CAST(SUM(s.price * s.qty * (s.discount / 100.0)) AS DECIMAL(10, 2)) AS total_discount
FROM sales s
JOIN product_details pd
ON s.prod_id = pd.product_id
GROUP BY segment_id
ORDER BY segment_id;


-- 3. What is the top selling product for each segment?
WITH product_revenue AS (
	SELECT
		pd.segment_id AS segment,
		pd.product_name,
		CAST(SUM(s.price * s.qty * (1.0 - (s.discount / 100.0))) AS DECIMAL(10, 2)) AS revenue,
		ROW_NUMBER() OVER (PARTITION BY pd.segment_id ORDER BY CAST(SUM(s.price * s.qty * (1.0 * (s.discount / 100.0))) AS DECIMAL(10 ,2)) DESC) AS rn
	FROM sales s
	JOIN product_details pd
	ON s.prod_id = pd.product_id
	GROUP BY pd.segment_id, pd.product_name
)
SELECT 
	segment,
	product_name AS top_selling,
	revenue
FROM product_revenue
WHERE rn = 1;


-- 4. What is the total quantity, revenue and discount for each category?
SELECT 
	pd.category_id AS category,
	SUM(s.qty) AS total_quantity,
	CAST(SUM(s.price * s.qty * (1.0 - (s.discount / 100.0))) AS DECIMAL(10, 2)) AS revenue,
	CAST(SUM(s.price * s.qty * (s.discount / 100.0)) AS DECIMAL(10, 2)) AS total_discount
FROM sales s
JOIN product_details pd
ON s.prod_id = pd.product_id
GROUP BY category_id
ORDER BY category_id;


-- 5. What is the top selling product for each category?
WITH product_revenue AS (
	SELECT
		pd.category_id AS category,
		pd.product_name,
		CAST(SUM(s.price * s.qty * (1.0 * (s.discount / 100.0))) AS DECIMAL(10, 2)) AS revenue,
		ROW_NUMBER() OVER (PARTITION BY pd.category_id ORDER BY CAST(SUM(s.price * s.qty * (1.0 - (s.discount / 100.0))) AS DECIMAL(10 ,2)) DESC) AS rn
	FROM sales s
	JOIN product_details pd
	ON s.prod_id = pd.product_id
	GROUP BY pd.category_id, pd.product_name
)
SELECT 
	category,
	product_name AS top_selling,
	revenue
FROM product_revenue
WHERE rn = 1;


-- 6. What is the percentage split of revenue by product for each segment?
WITH all_products AS (
	SELECT 
		pd.segment_id AS segment,
		s.prod_id,
		CAST(SUM(s.price * s.qty * (1.0 - (s.discount / 100))) AS DECIMAL(10, 2)) AS revenue
	FROM sales s
	JOIN product_details pd
	ON s.prod_id = pd.product_id
	GROUP BY pd.segment_id, s.prod_id
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



-- 7. What is the percentage split of revenue by segment for each category?
WITH all_products AS (
	SELECT 
		pd.category_id AS category,
		pd.segment_id AS segment,
		CAST(SUM(s.price * s.qty * (1.0 - (s.discount / 100))) AS DECIMAL(10, 2)) AS revenue
	FROM sales s
	JOIN product_details pd
	ON s.prod_id = pd.product_id
	GROUP BY pd.category_id, pd.segment_id
)
SELECT 
	category,
	segment,
	revenue,
	CAST(100.0 * revenue / SUM(revenue) OVER (PARTITION BY category) AS DECIMAL(10, 2)) AS pct_split
FROM all_products
ORDER BY category, revenue DESC;


-- 8. What is the percentage split of total revenue by category?
WITH all_products AS (
	SELECT 
		pd.category_id AS category,
		s.prod_id,
		CAST(SUM(s.price * s.qty * (1.0 - (discount / 100))) AS DECIMAL(10, 2)) AS revenue
	FROM sales s
	JOIN product_details pd
	ON s.prod_id = pd.product_id
	GROUP BY pd.category_id, s.prod_id
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



-- 9. What is the total transaction “penetration” for each product? 
-- (hint: penetration = number of transactions where at least 1 quantity of a product was purchased divided by total number of transactions)
WITH unique_transactions AS (
	SELECT 
		s.prod_id,
		pd.product_name,
		COUNT(DISTINCT s.txn_id) AS product_txn_count
	FROM sales s
	JOIN product_details pd
	ON s.prod_id = pd.product_id
	GROUP BY s.prod_id, pd.product_name
),
total_transactions AS (
	SELECT 
		COUNT(DISTINCT txn_id) AS total_txn
	FROM sales
)
SELECT
	ut.product_name,
	CAST(100.0 * ut.product_txn_count / tt.total_txn AS DECIMAL(10, 2)) AS pct_product_penetration
FROM unique_transactions ut, total_transactions tt
ORDER BY pct_product_penetration DESC; 


-- 10. What is the most common combination of at least 1 quantity of any 3 products in a 1 single transaction?
WITH unique_products AS (
	SELECT
		txn_id,
		prod_id
	FROM sales
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