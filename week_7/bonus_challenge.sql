USE BalancedTreeDB;

-- Bonus Challenge
-- Use a single SQL query to transform the product_hierarchy and product_prices datasets to the product_details table.
-- Hint: you may want to consider using a recursive CTE to solve this problem!

WITH product_tree AS (
	SELECT 
		id AS category_id,
		CAST(level_text AS VARCHAR(200)) AS category_name,
		CAST(NULL AS INT) AS segment_id,
		CAST(NULL AS VARCHAR(200)) AS segment_name,
		CAST(NULL AS INT) AS style_id,
		CAST(NULL AS VARCHAR(200)) AS style_name,
		id,
		parent_id
	FROM product_hierarchy
	WHERE parent_id IS NULL
	UNION ALL 
	SELECT 
		pt.category_id,
		pt.category_name,
		CASE WHEN pt.segment_id IS NULL THEN ph.id ELSE pt.segment_id END,
		CASE WHEN pt.segment_id IS NULL THEN ph.level_text ELSE PT.segment_name END,
		CASE WHEN pt.segment_id IS NOT NULL AND pt.style_id IS NULL THEN ph.id ELSE pt.style_id END,
		CASE WHEN pt.segment_id IS NOT NULL AND pt.style_id IS NULL THEN ph.level_text ELSE pt.style_name END,
		ph.id,
		ph.parent_id
	FROM product_tree pt
	JOIN product_hierarchy ph
		ON pt.id = ph.parent_id
),
cleaned_products AS (
	SELECT
		id,
		style_name + ' ' + segment_name + ' - ' + category_name AS product_name,
		category_id,
		segment_id,
		style_id,
		category_name,
		segment_name,
		style_name
	FROM product_tree
	WHERE style_id IS NOT NULL AND
		  segment_id IS NOT NULL AND
		  category_id IS NOT NULL
),
products_and_prices AS (
	SELECT
		pp.product_id,
		pp.price,
		cp.product_name,
		cp.category_id,
		cp.segment_id,
		cp.style_id,
		cp.category_name,
		cp.segment_name,
		cp.style_name
	FROM cleaned_products cp
	JOIN product_prices pp
		ON pp.id = cp.id
)
SELECT
	*
INTO bonus_challenge
FROM products_and_prices;


------------------------------------------------------------------------------------------
SELECT * FROM product_details
EXCEPT 
SELECT * FROM bonus_challenge
UNION ALL 
SELECT * FROM bonus_challenge
EXCEPT 
SELECT * FROM product_details;

-- This query returns no rows, which means the bonus challenge has been successfully
-- completed
------------------------------------------------------------------------------------------