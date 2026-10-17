USE PizzaRunnerDB;

-- Pricing and Ratings

-- 1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - 
-- how much money has Pizza Runner made so far if there are no delivery fees?
SELECT SUM(
	CASE 
		WHEN CAST(pn.pizza_name AS VARCHAR(100)) = 'Meatlovers' THEN 12
		ELSE 10
	END
) AS revenue
FROM customer_orders_cleaned c
INNER JOIN pizza_names pn
ON c.pizza_id = pn.pizza_id;


-- 2. What if there was an additional $1 charge for any pizza extras?
-- * Add cheese is $1 extra
SELECT (
	SELECT SUM(
		CASE
			WHEN CAST(pn.pizza_name AS VARCHAR(100)) = 'Meatlovers' THEN 12
			ELSE 10
		END
	) FROM customer_orders_cleaned c
	INNER JOIN pizza_names pn ON c.pizza_id = pn.pizza_id
) +
(
	SELECT SUM(
		CASE
			WHEN CAST(pt.topping_name AS VARCHAR(100)) = 'Cheese' THEN 1
			ELSE 0
		END
	)
	FROM customer_orders_cleaned c
	CROSS APPLY string_split(c.extras, ',') AS s
	INNER JOIN pizza_toppings pt ON TRIM(s.value) = pt.topping_id
	WHERE TRIM(s.value) <> ''
	  AND TRIM(s.value) <> 'null'
	  AND s.value IS NOT NULL
) AS total_revenue;


SELECT (
	SELECT SUM(
		CASE
			WHEN CAST(pn.pizza_name AS VARCHAR(100)) = 'Meatlovers' THEN 12
			ELSE 10
		END
	) FROM customer_orders_cleaned c
	INNER JOIN pizza_names pn ON c.pizza_id = pn.pizza_id
) +
(
	SELECT COUNT(s.value)
	FROM customer_orders_cleaned c
	CROSS APPLY string_split(c.extras, ',') AS s
	WHERE TRIM(s.value) <> ''
	  AND TRIM(s.value) <> 'null'
	  AND s.value IS NOT NULL
) AS total_revenue;


-- 3. The Pizza Runner team now wants to add an additional ratings system that allows customers to rate 
-- their runner, how would you design an additional table for this new dataset - 
-- generate a schema for this new table and insert your own data for ratings for each successful 
-- customer order between 1 to 5.
DROP TABLE IF EXISTS runner_rating;
CREATE TABLE runner_rating(
	runner_rating_id INTEGER,
	customer_id INTEGER,
	runner_id INTEGER,
	order_id INTEGER,
	rating INTEGER,
	rating_time DATETIME
);

-- While customer_id can also be found in the customer_orders using the order_id, it would make
-- future queries faster and easier to write when using other aggregate functions that include 
-- customer preferences in runners

INSERT INTO runner_rating (runner_rating_id, customer_id, runner_id, order_id, rating, rating_time)
VALUES 
    (1, 101, 1, 1, 5, '2020-01-01 19:10:00'),
    (2, 101, 1, 2, 4, '2020-01-01 20:00:00'),
    (3, 102, 1, 3, 5, '2020-01-03 01:00:00'),
    (4, 103, 2, 4, 3, '2020-01-04 14:00:00'),
    (5, 104, 3, 5, 4, '2020-01-08 22:00:00'),
    (6, 105, 2, 7, 5, '2020-01-08 22:30:00'),
    (7, 102, 2, 8, 2, '2020-01-10 01:00:00'),
    (8, 104, 1, 10, 5, '2020-01-11 19:30:00');


-- 4. Using your newly generated table - can you join all of the information together to form a table which has 
-- the following information for successful deliveries?
-- * customer_id
-- * order_id
-- * runner_id
-- * rating
-- * order_time
-- * pickup_time
-- * Time between order and pickup
-- * Delivery duration
-- * Average speed
-- * Total number of pizzas
SELECT 
	co.customer_id, 
	ro.order_id, 
	ro.runner_id, 
	rr.rating, 
	co.order_time, 
	ro.pickup_time,
	DATEDIFF(MINUTE, co.order_time, ro.pickup_time) AS time_diff_order_pickup, 
	ro.duration, 
	ROUND(CAST(NULLIF(REPLACE(REPLACE(ro.distance, 'km', ''), 'null', ''), '') AS FLOAT) / 
	CAST(NULLIF(REPLACE(REPLACE(REPLACE(REPLACE(ro.duration, 'minutes', ''), 'minute', ''), 'mins', ''), 'null', ''), '') AS FLOAT), 2) AS avg_speed,
	COUNT(co.pizza_id) AS total_pizzas
FROM runner_orders_cleaned ro
INNER JOIN customer_orders_cleaned co
ON ro.order_id = co.order_id
INNER JOIN runner_rating rr
ON ro.order_id = rr.order_id
GROUP BY 
	co.customer_id, 
	ro.order_id, 
	ro.runner_id, 
	rr.rating, 
	co.order_time, 
	ro.pickup_time,
	ro.duration,
	ro.distance;


-- 5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each 
-- runner is paid $0.30 per kilometre traveled - how much money does Pizza Runner have left over after these deliveries?
select * from runner_orders_cleaned;

SELECT (
	SELECT SUM(
		CASE
			WHEN CAST(pn.pizza_name AS VARCHAR(100)) = 'Meatlovers' THEN 12
			ELSE 10
		END
	) 
	FROM customer_orders_cleaned c
	INNER JOIN pizza_names pn
	ON c.pizza_id = pn.pizza_id
) - 
(
	SELECT SUM(CAST(NULLIF(REPLACE(REPLACE(distance, 'km', ''), 'null', ''), '') AS FLOAT) * 0.3)
	FROM runner_orders_cleaned
) AS profit;