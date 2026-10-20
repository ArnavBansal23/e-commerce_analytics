-- ============================================
-- OLIST E-COMMERCE ANALYTICS
-- 01 - Database Validation
-- ============================================
--
-- Objective:
-- Validate row counts, primary-key uniqueness,
-- and foreign-key relationships after loading
-- the cleaned data into PostgreSQL.

SELECT 'customers' AS table_name, COUNT(*) AS row_count
FROM customers

UNION ALL

SELECT 'products', COUNT(*)
FROM products

UNION ALL

SELECT 'sellers', COUNT(*)
FROM sellers

UNION ALL

SELECT 'orders', COUNT(*)
FROM orders

UNION ALL

SELECT 'order_items', COUNT(*)
FROM order_items

UNION ALL

SELECT 'payments', COUNT(*)
FROM payments

UNION ALL

SELECT 'reviews', COUNT(*)
FROM reviews;


-- ============================================
-- Foreign Key / Relationship Validation
-- ============================================
--
-- Objective:
-- Check for orphan records in child tables.
--
-- Expected result for every query:
-- 0
-- ============================================



SELECT COUNT(*) AS orphan_orders
FROM orders o
LEFT JOIN customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


SELECT COUNT(*) AS orphan_order_items
FROM order_items oi
LEFT JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;


SELECT COUNT(*) AS orphan_product_items
FROM order_items oi
LEFT JOIN products p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;


SELECT COUNT(*) AS orphan_seller_items
FROM order_items oi
LEFT JOIN sellers s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;


SELECT COUNT(*) AS orphan_payments
FROM payments p
LEFT JOIN orders o
    ON p.order_id = o.order_id
WHERE o.order_id IS NULL;


SELECT COUNT(*) AS orphan_reviews
FROM reviews r
LEFT JOIN orders o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;

-- | customer_segment            | customer_count |
-- | --------------------------- | -------------- |
-- | Recent One-Time Buyers      | 36345          |
-- | Hibernating One-Time Buyers | 22514          |
-- | Mid-Recency One-Time Buyers | 18118          |
-- | At-Risk / Lapsed High-Value | 14562          |
-- | High-Value Repeat Customers | 1389           |
-- | Potential Loyalists         | 397            |
-- | Champions                   | 33             |