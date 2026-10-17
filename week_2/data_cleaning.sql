USE PizzaRunnerDB;

SELECT TOP 5 *
FROM customer_orders;

SELECT TOP 5 *
FROM pizza_names;

SELECT TOP 5 *
FROM pizza_recipes;

SELECT TOP 5 *
FROM pizza_toppings;

SELECT TOP 5 * 
FROM runner_orders;

SELECT TOP 5 *
FROM runners;


-- Data cleaning
-- Replacing NULL with empty string in the customer_orders table
SELECT *
FROM customer_orders
WHERE order_id IS NULL OR
	  customer_id IS NULL OR
	  pizza_id IS NULL OR
	  exclusions IS NULL OR
	  extras IS NULL OR
	  order_time IS NULL or
	  exclusions = 'null' OR
	  extras = 'null';

--UPDATE customer_orders
--SET extras = '' 
--WHERE extras IS NULL OR extras = 'null';

--UPDATE customer_orders
--SET exclusions = ''
--WHERE exclusions = 'null';



CREATE OR ALTER VIEW customer_orders_cleaned AS
SELECT
    order_id,
    customer_id,
    pizza_id,
    COALESCE(
        NULLIF(LTRIM(RTRIM(exclusions)), 'null'),
        ''
    ) AS exclusions,
    COALESCE(
        NULLIF(LTRIM(RTRIM(extras)), 'null'),
        ''
    ) AS extras,
    order_time
FROM customer_orders;

SELECT *
FROM customer_orders_cleaned
WHERE order_id IS NULL OR
	  customer_id IS NULL OR
	  pizza_id IS NULL OR
	  exclusions IS NULL OR
	  extras IS NULL OR
	  order_time IS NULL or
	  exclusions = 'null' OR
	  extras = 'null';


-- Replacing nulls with empty string in cancellation column, and removed
-- records where deliveries have not been processed
SELECT *
FROM runner_orders
WHERE cancellation IS NULL OR
	  pickup_time = 'null' OR 
	  distance = 'null' OR 
	  duration = 'null' OR
	  cancellation = 'null';

--UPDATE runner_orders
--SET cancellation = ''
--WHERE cancellation IS NULL OR cancellation = 'null';

--DELETE FROM runner_orders
--WHERE pickup_time = 'null';


CREATE OR ALTER VIEW runner_orders_cleaned AS
SELECT
    order_id,
    runner_id,
    pickup_time,
    distance,
    duration,
    COALESCE(
        NULLIF(LTRIM(RTRIM(cancellation)), 'null'),
        ''
    ) AS cancellation
FROM dbo.runner_orders
WHERE pickup_time IS NOT NULL
  AND LTRIM(RTRIM(pickup_time)) <> 'null';

SELECT *
FROM runner_orders_cleaned
WHERE cancellation IS NULL OR
	  pickup_time = 'null' OR 
	  distance = 'null' OR 
	  duration = 'null' OR
	  cancellation = 'null';