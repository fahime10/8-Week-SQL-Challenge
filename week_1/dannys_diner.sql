USE DannysDinerDB;

SELECT TOP 5
  	product_id,
    product_name,
    price
FROM menu
ORDER BY price DESC;

-- 1. What is the total amount each customer spent at the restaurant?
SELECT
	*
FROM sales;

SELECT s.customer_id, SUM(m.price) AS total_spent
FROM menu m
LEFT JOIN sales s
ON m.product_id = s.product_id
GROUP BY s.customer_id;


-- 2. How many days has each customer visited the restaurant?
SELECT customer_id, COUNT(DISTINCT order_date) AS visited
FROM sales
GROUP BY customer_id;

-- DISTINCT order_date will ignore orders on the same day


-- 3. What was the first item from the menu purchased by each customer?
SELECT customer_id, MIN(order_date)
FROM sales
GROUP BY customer_id;

SELECT s.customer_id, MIN(m.product_name) AS first_item, s.order_date
FROM sales s
LEFT JOIN menu m
ON s.product_id = m.product_id
WHERE s.order_date IN (SELECT MIN(order_date)
						FROM sales
						GROUP BY customer_id)
GROUP BY s.customer_id, s.order_date;

-- MIN(m.product_name) is what allows to get one single row result. This is necessary as a customer could have
-- ordered more than one product on the same day


-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT TOP 1 m.product_name, COUNT(s.product_id) AS occurrences
FROM sales s
LEFT JOIN menu m
ON s.product_id = m.product_id 
GROUP BY s.product_id, m.product_name
ORDER BY occurrences DESC;


-- 5. Which item was the most popular for each customer?
SELECT s.customer_id, m.product_name, COUNT(s.product_id) AS occurrences
FROM sales s
LEFT JOIN menu m
ON s.product_id = m.product_id
GROUP BY s.customer_id, m.product_name
ORDER BY customer_id;

WITH item_counts AS (
	SELECT s.customer_id, m.product_name, COUNT(s.product_id) AS occurrences
	FROM sales s
	LEFT JOIN menu m
	ON s.product_id = m.product_id
	GROUP BY s.customer_id, m.product_name
),
ranked_items AS (
	SELECT customer_id, product_name, occurrences,
		   DENSE_RANK() OVER (PARTITION BY customer_id ORDER BY occurrences DESC) AS ranking
	FROM item_counts
)
SELECT customer_id, product_name, occurrences
FROM ranked_items
WHERE ranking = 1;


-- 6. Which item was purchased first by the customer after they became a member?
SELECT * FROM members;

SELECT s.customer_id, s.product_id
FROM sales s
INNER JOIN members mem
ON s.customer_id = mem.customer_id AND s.order_date >= mem.join_date;

SELECT s.customer_id, m.product_name, MIN(s.order_date) AS order_date
FROM sales s
LEFT JOIN menu m
ON s.product_id = m.product_id
INNER JOIN members mem
ON s.customer_id = mem.customer_id
WHERE s.order_date >= mem.join_date
GROUP BY s.customer_id, m.product_name;
-- The issue with this one is that GROUP BY only returns more than one item because they product names are grouped,
-- so it may be better to use a window function instead

WITH member_purchases AS(
	SELECT
		s.customer_id,
		m.product_name,
		s.order_date,
		ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.order_date) AS ranking
	FROM sales s
	JOIN menu m ON s.product_id = m.product_id
	JOIN members mem ON s.customer_id = mem.customer_id
	WHERE s.order_date >= mem.join_date
)
SELECT customer_id, product_name, order_date
FROM member_purchases
WHERE ranking = 1;


-- 7. Which item was purchased just before the customer became a member?
WITH member_purchases AS(
	SELECT
		s.customer_id,
		m.product_name,
		s.order_date,
		ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.order_date DESC) AS ranking
	FROM sales s
	JOIN menu m ON s.product_id = m.product_id
	JOIN members mem ON s.customer_id = mem.customer_id
	WHERE s.order_date <= mem.join_date
)
SELECT customer_id, product_name, order_date
FROM member_purchases
WHERE ranking = 1;
-- Only two changes where instead of using >= it is <=, and instead of ascending order, it is descending


-- 8. What is the total items and amount spent for each member before they became a member?
WITH member_purchases AS(
	SELECT
		s.customer_id,
		m.product_id,
		m.product_name,
		s.order_date,
		ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.order_date DESC) AS ranking
	FROM sales s
	JOIN menu m ON s.product_id = m.product_id
	JOIN members mem ON s.customer_id = mem.customer_id
	WHERE s.order_date <= mem.join_date
)
SELECT customer_id, product_id, product_name, order_date
FROM member_purchases;

SELECT * FROM menu;

WITH member_purchases AS(
	SELECT
		s.customer_id,
		m.product_id,
		m.product_name,
		s.order_date,
		ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.order_date DESC) AS ranking
	FROM sales s
	JOIN menu m ON s.product_id = m.product_id
	JOIN members mem ON s.customer_id = mem.customer_id
	WHERE s.order_date <= mem.join_date
)
SELECT p.customer_id, COUNT(m.product_id) AS total_items, SUM(m.price) AS total_spent
FROM member_purchases p
JOIN menu m
ON p.product_id = m.product_id
GROUP BY p.customer_id;


-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
SELECT s.customer_id, s.product_id, m.product_name, m.price,
CASE
	WHEN m.product_name = 'sushi' THEN m.price * 10 * 2
	ELSE m.price * 10
END AS points
FROM sales s
JOIN menu m
ON s.product_id = m.product_id;

SELECT s.customer_id, 
SUM(
	CASE
		WHEN m.product_name = 'sushi' THEN m.price * 10 * 2
		ELSE m.price * 10
	END) AS points
FROM sales s
JOIN menu m
ON s.product_id = m.product_id
GROUP BY customer_id;


-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, 
-- not just sushi - how many points do customer A and B have at the end of January?
SELECT s.customer_id, s.product_id
FROM sales s
INNER JOIN members mem
ON s.customer_id = mem.customer_id AND s.order_date >= mem.join_date;

SELECT s.customer_id,
SUM(
	CASE
		WHEN s.order_date BETWEEN mem.join_date AND DATEADD(DAY, 6, mem.join_date) THEN m.price * 10 * 2
		WHEN m.product_name = 'sushi' THEN m.price * 10 * 2
		ELSE m.price * 10
	END) AS points
FROM sales s
JOIN menu m
ON s.product_id = m.product_id
JOIN members mem
ON s.customer_id = mem.customer_id
GROUP BY s.customer_id;