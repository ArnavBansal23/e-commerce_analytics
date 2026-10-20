-- ============================================
-- OLIST E-COMMERCE ANALYTICS
-- 02 - Sales Analysis
-- ============================================
--
-- Objective:
-- Analyze completed e-commerce sales using
-- delivered orders.
--
-- Metric definitions:
-- Merchandise Sales = SUM(order_items.price)
-- for orders with order_status = 'delivered'.
--
-- Freight = SUM(order_items.freight_value)
--
-- These are kept separate because freight
-- represents a shipping charge and should not
-- automatically be treated as merchandise revenue.
-- ============================================


-- Overall delivered-order sales summary
-- Merchandise sales = SUM(order_items.price)
-- Freight is reported separately.
-- AOV = merchandise sales / delivered orders.

SELECT
COUNT(DISTINCT(o. order_id)) AS delivered_orders,
COUNT(DISTINCT (c.customer_unique_id)) AS delivered_customers,
COUNT(*) AS items_sold,
ROUND(SUM(oi.price),2) as merchandise_sales,
ROUND(SUM(oi.freight_value),2) as total_freight,
ROUND(SUM(oi.price)/ COUNT(DISTINCT(o.order_id)),2) AS avg_order_value
FROM orders o
JOIN order_items oi
ON o.order_id = oi.order_id
JOIN customers c
ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered';




-- ============================================
-- Monthly Sales Analysis
-- ============================================
--
-- Objective:
-- Analyze delivered merchandise sales over time.
--
-- Grain of result:
-- One row = one calendar month.
--
-- Merchandise Sales = SUM(order_items.price)
-- for delivered orders.
-- ============================================

select
DATE_TRUNC('month', o.order_purchase_timestamp) AS sales_month,
COUNT(DISTINCT(o. order_id)) AS delivered_orders_pm,
COUNT(DISTINCT (c.customer_unique_id)) AS delivered_customers_pm,
COUNT(*) AS items_sold_pm,
ROUND(SUM(oi.price),2) as merchandise_sales_pm,
ROUND(SUM(oi.freight_value),2) as total_freight_pm,
ROUND(SUM(oi.price)/ COUNT(DISTINCT(o.order_id)),2) AS avg_order_value_pm
FROM orders o
JOIN order_items oi
ON o.order_id = oi.order_id
JOIN Customers c
ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
ORDER BY 




-- ============================================
-- Product Category Sales Analysis
-- ============================================
--
-- Objective:
-- Analyze delivered merchandise sales by
-- product category.
--
-- Grain of result:
-- One row = one product category.
--
-- Merchandise Sales = SUM(order_items.price)
-- for delivered orders.
--
-- Missing product categories are labeled
-- as 'Unknown' so that valid transactions
-- are not excluded from the analysis.
-- ============================================

select
coalesce(p.product_category_name, 'Unknown') as product_category,
COUNT(distinct(o.order_id)) AS delivered_orders,
COUNT(*) AS items_sold,
ROUND(SUM(oi.price),2) AS merchandise_sales,
ROUND(SUM(oi.freight_value),2) AS total_freight
FROM orders o
JOIN order_items oi
ON o.order_id = oi.order_id
JOIN products p
ON oi.product_id = p.product_id
GROUP BY coalesce(p.product_category_name, 'Unknown')
ORDER BY merchandise_sales DESC


-- ============================================
-- Product Category Sales Contribution
-- ============================================
--
-- Objective:
-- Measure each product category's contribution
-- to total delivered merchandise sales.
--
-- Grain:
-- One row = one product category.
-- ============================================

WITH category_sales AS (
    SELECT
    coalesce(p.product_category_name, 'Unknown') as product_category,
    COUNT(distinct(o.order_id)) AS delivered_orders,
    COUNT(*) AS items_sold, 
    SUM(oi.price) AS merchandise_sales
    FROM orders o
    JOIN order_items oi
    ON o.order_id = oi.order_id
    JOIN products p
    ON oi.product_id = p.product_id
    GROUP BY coalesce(p.product_category_name, 'Unknown')
)


-- ============================================
-- Category Performance Analysis
-- ============================================
--
-- Objective:
-- Compare product categories using:
-- - delivered orders
-- - items sold
-- - merchandise sales
-- - average selling price per item
--
-- Grain:
-- One row = one product category.
-- ============================================


SELECT
    COALESCE(p.product_category_name, 'Unknown') AS product_category,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    COUNT(*) AS items_sold,
    ROUND(SUM(oi.price), 2) AS merchandise_sales,
    ROUND(AVG(oi.price), 2) AS avg_item_price
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
JOIN products p
    ON oi.product_id = p.product_id
WHERE o.order_status = 'delivered'
GROUP BY COALESCE(p.product_category_name, 'Unknown')
ORDER BY merchandise_sales DESC;



-- ============================================
-- Geographic Sales Analysis
-- ============================================
--
-- Objective:
-- Analyze delivered merchandise sales by
-- customer state.
--
-- Grain:
-- One row = one customer state.
--
-- Merchandise Sales = SUM(order_items.price)
-- for delivered orders.
-- ============================================

WITH state_sales AS (
    SELECT
        c.customer_state,
        COUNT(DISTINCT o.order_id) AS delivered_orders,
        COUNT(DISTINCT c.customer_unique_id) AS delivered_customers,
        COUNT(*) AS items_sold,
        SUM(oi.price) AS merchandise_sales
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    JOIN customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_state
)

SELECT
    customer_state,
    delivered_orders,
    delivered_customers,
    items_sold,
    ROUND(merchandise_sales, 2) AS merchandise_sales,
    ROUND(
        merchandise_sales
        / SUM(merchandise_sales) OVER () * 100,
        2
    ) AS sales_share_pct
FROM state_sales
ORDER BY merchandise_sales DESC;


-- ============================================
-- Repeat Customer Analysis
-- ============================================
--
-- Objective:
-- Determine how many unique customers placed
-- one delivered order versus multiple delivered
-- orders.
--
-- Customer identity:
-- customer_unique_id
--
-- Grain:
-- One row = one unique customer.
-- ============================================

WITH customer_orders AS(
    select
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS delivered_orders
    FROM orders o
    JOIN customers c
    ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)

select
COUNT(*) AS  total_unique_customers,

COUNT(*) FILTER(
    WHERE delivered_orders = 1
) AS one_time_customers,

COUNT(*) FILTER(
    WHERE delivered_orders > 1
) AS repeat_customers,

ROUND(
    100*COUNT(*) FILTER(
        WHERE delivered_orders > 1
    )/ COUNT(*), 2
) AS repeat_customer_rate_pct
FROM customer_orders

select
delivered_orders,
COUNT(*) AS customer_count
FROM customer_orders
GROUP BY delivered_orders
ORDER BY delivered_orders ASC



    
