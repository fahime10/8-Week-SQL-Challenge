USE CliqueBaitDB;

-- Digital Analysis

-- 1. How many users are there?
SELECT COUNT(DISTINCT(user_id)) AS total_users FROM users;


-- 2. How many cookies does each user have on average?
WITH user_cookies AS (
	SELECT
		user_id,
		COUNT(cookie_id) AS cookies
	FROM users
	GROUP BY user_id
)
SELECT
	user_id,
	AVG(cookies) AS avg_cookies
FROM user_cookies
GROUP BY user_id
ORDER BY avg_cookies DESC;


-- 3. What is the unique number of visits by all users per month?
SELECT 
	DATEPART(MONTH, event_time) AS month_number,
	COUNT(DISTINCT(visit_id)) AS unique_visits
FROM events
GROUP BY DATEPART(MONTH, event_time)
ORDER BY month_number;


-- 4. What is the number of events for each event type?
SELECT	
	ei.event_name,
	COUNT(e.visit_id) AS total_events
FROM events e
LEFT JOIN event_identifier ei
ON e.event_type = ei.event_type
GROUP BY ei.event_name
ORDER BY total_events DESC;


-- 5. What is the percentage of visits which have a purchase event?
WITH total_events AS (
	SELECT COUNT(DISTINCT visit_id) AS total 
	FROM events
),
purchase_visits AS (
	SELECT COUNT(DISTINCT e.visit_id) AS purchases
	FROM events e
	JOIN event_identifier ei ON e.event_type = ei.event_type
	WHERE ei.event_name = 'Purchase'
		
)
SELECT
	CAST(100.0 * purchases / total AS DECIMAL(5, 2)) AS pct_purchase_events
FROM total_events, purchase_visits;

-- The query coould have been simpler if event_identifier = 3, but it is not best practice because 
-- event_identifiers can be easily changed, so using a more specific conditional using 
-- = 'Purchase' is better


-- 6. What is the percentage of visits which view the checkout page but do not have a purchase event?
WITH checkout_pages AS (
	SELECT e.visit_id
	FROM events e
	JOIN page_hierarchy p ON e.page_id = p.page_id
	WHERE p.page_name = 'Checkout'
),
purchase_visits AS (
	SELECT e.visit_id
	FROM events e
	JOIN event_identifier ei ON e.event_type = ei.event_type
	WHERE ei.event_name = 'Purchase'
),
checkout_minus_purchases AS (
	SELECT visit_id FROM checkout_pages
	EXCEPT
	SELECT visit_id FROM purchase_visits
)
SELECT
	CAST(
		 100.0 * (SELECT COUNT(*) FROM checkout_minus_purchases) / (SELECT COUNT(*) FROM checkout_pages) AS DECIMAL(5, 2)
		) AS pct_checkout_without_purchase;


-- 7. What are the top 3 pages by number of views?
SELECT TOP 3 
	p.page_name, 
	COUNT(e.visit_id) AS total_views
FROM events e
JOIN page_hierarchy p ON e.page_id = p.page_id
JOIN event_identifier ei ON e.event_type = ei.event_type
WHERE ei.event_name = 'Page View'
GROUP BY p.page_name
ORDER BY total_views DESC;


-- 8. What is the number of views and cart adds for each product category?
SELECT
	p.product_category,
	SUM(CASE WHEN ei.event_name = 'Page View' THEN 1 ELSE 0 END) AS total_views,
	SUM(CASE WHEN ei.event_name = 'Add to Cart' THEN 1 ELSE 0 END) AS total_cart_adds
FROM events e
JOIN page_hierarchy p ON e.page_id = p.page_id
JOIN event_identifier ei ON e.event_type = ei.event_type
WHERE p.product_category IS NOT NULL
GROUP BY p.product_category
ORDER BY total_views DESC;


-- 9. What are the top 3 products by purchases?
WITH successful_visits AS (
	SELECT DISTINCT e.visit_id
	FROM events e
	JOIN event_identifier ei ON e.event_type = ei.event_type
	WHERE ei.event_name = 'Purchase'
)
SELECT TOP 3
	p.page_name AS product_name,
	COUNT(e.visit_id) AS total_purchases
FROM events e
JOIN page_hierarchy p ON e.page_id = p.page_id
JOIN successful_visits s ON e.visit_id = s.visit_id
WHERE e.event_type = 2 AND p.product_id IS NOT NULL		-- event_type = 2 is 'Add to Cart'
GROUP BY p.page_name
ORDER BY total_purchases DESC;

-- In theory, using the conditional page_name = Confirmation should be the way to calculate successful 
-- purchases, however, this dataset does not confirm whether a product has been bought, but it works 
-- more like an event log, which means it stores snapshots of events and what page a user visited.
-- So, an assumption has to be made, which is that a user used the purchase page and adding to cart would
-- have purchased the product


-- Product Funnel Analysis
-- Using a single SQL query - create a new output table which has the following details:

-- * How many times was each product viewed?
-- * How many times was each product added to cart?
-- * How many times was each product added to a cart but not purchased (abandoned)?
-- * How many times was each product purchased?
WITH product_viewed AS (
	SELECT 
		p.page_name,
		COUNT(e.visit_id) AS views
	FROM events e
	JOIN page_hierarchy p ON e.page_id = p.page_id
	JOIN event_identifier ei ON e.event_type = ei.event_type
	WHERE ei.event_name = 'Page View'
	GROUP BY p.page_name
),
product_added_cart AS (
	SELECT 
		p.page_name,
		COUNT(e.visit_id) AS products_added
	FROM events e
	JOIN page_hierarchy p ON e.page_id = p.page_id
	JOIN event_identifier ei ON e.event_type = ei.event_type
	WHERE ei.event_name = 'Add to Cart' AND p.product_id IS NOT NULL
	GROUP BY p.page_name
),
abandoned_products AS (
	SELECT 
		p.page_name,
		COUNT(e.visit_id) AS products_abandoned
	FROM events e
	JOIN page_hierarchy p ON e.page_id = p.page_id
	JOIN event_identifier ei ON e.event_type = ei.event_type
	WHERE ei.event_name = 'Add to Cart' AND p.product_id IS NOT NULL AND
		  e.visit_id NOT IN (SELECT DISTINCT e.visit_id 
							 FROM events e
							 JOIN event_identifier ei ON e.event_type = ei.event_type
							 WHERE ei.event_name = 'Purchase')
	GROUP BY p.page_name
),
purchased_products AS (
	SELECT 
		p.page_name,
		COUNT(e.visit_id) AS products_purchased
	FROM events e
	JOIN page_hierarchy p ON e.page_id = p.page_id
	JOIN event_identifier ei ON e.event_type = ei.event_type
	WHERE e.event_type = 2 AND p.product_id IS NOT NULL AND
		  e.visit_id IN (SELECT DISTINCT e.visit_id
						 FROM events e
						 JOIN event_identifier ei ON e.event_type = ei.event_type
						 WHERE ei.event_name = 'Purchase'
						 )
	GROUP BY p.page_name
)
SELECT
	pv.page_name,
	pv.views,
	pa.products_added,
	ap.products_abandoned,
	pp.products_purchased
INTO product_analysis
FROM product_viewed pv
JOIN product_added_cart pa ON pv.page_name = pa.page_name
JOIN abandoned_products ap ON pv.page_name = ap.page_name
JOIN purchased_products pp ON pv.page_name = pp.page_name;


-- Additionally, create another table which further aggregates the data for the above points 
-- but this time for each product category instead of individual products.
WITH product_viewed AS (
	SELECT 
		p.product_category,
		COUNT(e.visit_id) AS views
	FROM events e
	JOIN page_hierarchy p ON e.page_id = p.page_id
	JOIN event_identifier ei ON e.event_type = ei.event_type
	WHERE ei.event_name = 'Page View'
	GROUP BY p.product_category
),
product_added_cart AS (
	SELECT 
		p.product_category,
		COUNT(e.visit_id) AS products_added
	FROM events e
	JOIN page_hierarchy p ON e.page_id = p.page_id
	JOIN event_identifier ei ON e.event_type = ei.event_type
	WHERE ei.event_name = 'Add to Cart' AND p.product_id IS NOT NULL
	GROUP BY p.product_category
),
abandoned_products AS (
	SELECT 
		p.product_category,
		COUNT(e.visit_id) AS products_abandoned
	FROM events e
	JOIN page_hierarchy p ON e.page_id = p.page_id
	JOIN event_identifier ei ON e.event_type = ei.event_type
	WHERE ei.event_name = 'Add to Cart' AND p.product_id IS NOT NULL AND
		  e.visit_id NOT IN (SELECT DISTINCT e.visit_id 
							 FROM events e
							 JOIN event_identifier ei ON e.event_type = ei.event_type
							 WHERE ei.event_name = 'Purchase')
	GROUP BY p.product_category
),
purchased_products AS (
	SELECT 
		p.product_category,
		COUNT(e.visit_id) AS products_purchased
	FROM events e
	JOIN page_hierarchy p ON e.page_id = p.page_id
	JOIN event_identifier ei ON e.event_type = ei.event_type
	WHERE e.event_type = 2 AND p.product_id IS NOT NULL AND
		  e.visit_id IN (SELECT DISTINCT e.visit_id
						 FROM events e
						 JOIN event_identifier ei ON e.event_type = ei.event_type
						 WHERE ei.event_name = 'Purchase'
						 )
	GROUP BY p.product_category
)
SELECT
	pv.product_category,
	pv.views,
	pa.products_added,
	ap.products_abandoned,
	pp.products_purchased
INTO product_category_analysis
FROM product_viewed pv
JOIN product_added_cart pa ON pv.product_category = pa.product_category
JOIN abandoned_products ap ON pv.product_category = ap.product_category
JOIN purchased_products pp ON pv.product_category = pp.product_category;


-- Use your 2 new output tables - answer the following questions:

-- 1. Which product had the most views, cart adds and purchases?
SELECT TOP 1 * 
FROM product_analysis 
ORDER BY views DESC, products_added DESC, products_purchased DESC;

-- page_name	|views	|products_added		|products_abandoned		|products_purchased
-- Oyster		|1568	|943				|217					|726


-- 2. Which product was most likely to be abandoned?
SELECT TOP 1 *
FROM product_analysis
ORDER BY products_abandoned DESC;

-- page_name		|views	|products_added		|products_abandoned		|products_purchased
-- Russian Caviar	|1563	|946				|249					|697


-- 3. Which product had the highest view to purchase percentage?
SELECT TOP 1
	page_name,
	CAST(100.0 * products_purchased  / views AS DECIMAL(5, 2)) AS pct_view_to_purchase
FROM product_analysis
ORDER BY pct_view_to_purchase DESC;

-- page_name	|pct_view_to_purchase
-- Lobster		|48.74


-- 4. What is the average conversion rate from view to cart add?
SELECT
	CAST(AVG(1.0 * products_added / views) * 100 AS DECIMAL(5, 2)) AS avg_conversion_rate_view_to_cart_add
FROM product_analysis;

-- 60.95


-- 5. What is the average conversion rate from cart add to purchase?
SELECT
	CAST(AVG(1.0 *  products_purchased / products_added) * 100 AS DECIMAL(5, 2)) AS avg_conversion_rate_cart_to_purchase
FROM product_analysis;


-- Campaigns Analysis

-- Generate a table that has 1 single row for every unique visit_id record and has the following columns:

-- * user_id
-- * visit_id
-- * visit_start_time: the earliest event_time for each visit
-- * page_views: count of page views for each visit
-- * cart_adds: count of product cart add events for each visit
-- * purchase: 1/0 flag if a purchase event exists for each visit
-- * campaign_name: map the visit to a campaign if the visit_start_time falls between the start_date and end_date
-- * impression: count of ad impressions for each visit
-- * click: count of ad clicks for each visit
-- * (Optional column) cart_products: a comma separated text value with products added to the cart sorted by the order they were added to the cart (hint: use the sequence_number)

select * from campaign_identifier
select top 5 * from events
select * from users
select * from event_identifier


WITH visit_summary AS (
	SELECT
		e.visit_id,
		u.user_id,
		MIN(e.event_time) AS visit_start_time
	FROM events e
	JOIN users u ON e.cookie_id = u.cookie_id
	GROUP BY e.visit_id, u.user_id
),
campaign_mapping AS (
	SELECT
		v.user_id,
		v.visit_id,
		v.visit_start_time,
		COALESCE(ci.campaign_name, 'No Campaign') AS campaign_name,
		SUM(CASE WHEN e.event_type = 1 THEN 1 ELSE 0 END) AS page_views,
		SUM(CASE WHEN e.event_type = 2 THEN 1 ELSE 0 END) AS cart_add,
		MAX(CASE WHEN e.event_type = 3 THEN 1 ELSE 0 END) AS purchase,
		SUM(CASE WHEN e.event_type = 4 THEN 1 ELSE 0 END) AS impression,
		SUM(CASE WHEN e.event_type = 5 THEN 1 ELSE 0 END) AS click
	FROM visit_summary v
	LEFT JOIN campaign_identifier ci ON v.visit_start_time BETWEEN ci.start_date AND ci.end_date
	JOIN events e ON e.visit_id = v.visit_id
	GROUP BY v.user_id, v.visit_id, v.visit_start_time, ci.campaign_name
)
SELECT
	*
INTO campaigns_analysis
FROM campaign_mapping;

SELECT TOP 50 * FROM campaigns_analysis

-- Insights:
SELECT 
	campaign_name,
	COUNT(visit_id) AS total_visits,
	SUM(page_views) AS total_page_views,
	SUM(cart_add) AS total_cart_adds,
	SUM(purchase) AS total_purchases,
	SUM(impression) AS total_impressions,
	SUM(click) AS total_clicks,
	CAST(100.0 * SUM(purchase) / COUNT(visit_id) AS DECIMAL(5, 2)) AS pct_purchase_visit_rate,
	CAST(100.0 * SUM(click) / SUM(impression) AS DECIMAL(5, 2)) AS pct_ad_engagement_rate
FROM campaigns_analysis
GROUP BY campaign_name
ORDER BY total_visits DESC;


-- 1. The 'Half Off - Treat Your Shellf(ish)' campaign was by far the largest traffic driver, generating
-- 2,388 total visits and 1,180 purchases, accounting for over 65% of all site visits and completed 
-- orders across the dataset.

-- 2. The 'BOGOF - Fishing For Compliments' campaign achieved the highest Click-Through Rate at
-- 84.62%.

-- 3. The No Campaign baseline achieved the highest conversion rate at 52.34%, indicating that organic
-- visitors outside promotional windows carry high buying intent and require less promotional incentive
-- to complete a purchase.

-- 4. Purchase conversion rates remained steady across all active promotions, ranging between 48% and
-- 50%, showing predictable user behaviour regardless of the specific discount offer.

-- 5. While 'BOGOF - Fishing For Compliments' drove the highest ad engagement, it yielded the lowest 
-- overall visit volume (260 visits) and conversion rate (48.85%), suggesting a need to scale its reach
-- while refining landing page conversion tactics.