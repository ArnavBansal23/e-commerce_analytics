-- ============================================
-- OLIST E-COMMERCE ANALYTICS
-- 03 - Customer Analysis
-- ============================================
--
-- Objective:
-- Understand customer purchasing behaviour
-- and build RFM customer segments.
--
-- Customer identity:
-- customer_unique_id
--
-- Scope:
-- Delivered orders.
--
-- RFM:
-- Recency   = Days since last purchase
-- Frequency = Number of delivered orders
-- Monetary  = Delivered merchandise value
-- ============================================

-- ============================================
-- 1. Customer RFM Metrics
-- ============================================
--
-- Objective:
-- Calculate Recency, Frequency, and Monetary
-- metrics for every unique customer.
--
-- Customer identity:
-- customer_unique_id
--
-- Scope:
-- Delivered orders only.
--
-- Definitions:
-- Recency   = Days since latest purchase
-- Frequency = Number of delivered orders
-- Monetary  = Total merchandise value
--
-- Reference date:
-- One day after the latest delivered purchase.
-- This keeps RFM meaningful for the historical dataset.
--
-- Grain:
-- One row = one unique customer.
-- ============================================

WITH customer_rfm AS(
  select
  c.customer_unique_id,
  MAX(o.order_purchase_timestamp::date) AS last_purchase_date,
  COUNT(DISTINCT o.order_id) AS frequency,
  SUM(oi.price) As monetary
  FROM orders o
  JOIN customers c
  ON o.customer_id = c.customer_id
  JOIN order_items oi
  ON o.order_id = oi.order_id
  WHERE o.order_status = 'delivered'
  GROUP BY c.customer_unique_id

),

reference_date AS(
  select
  MAX(o.order_purchase_timestamp::date) + 1 as last_snapshot_date
  FROM orders o
  WHERE o.order_status = 'delivered'
)

select
cr.customer_unique_id,
cr.last_purchase_date,
rd.last_snapshot_date,
rd.last_snapshot_date - cr.last_purchase_date AS recency_days,
cr.frequency,
ROUND(cr.monetary, 2) AS monetary

FROM customer_rfm cr
CROSS JOIN reference_date rd
ORDER BY monetary DESC


-- ============================================
-- 2. RFM Distribution Summary
-- ============================================
--
-- Objective:
-- Examine the distribution of recency,
-- frequency, and monetary value before
-- choosing scoring thresholds.
--
-- Grain:
-- One row = summary statistics for all customers.
-- ============================================

WITH customer_rfm AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp::date) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price) AS monetary
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
rfm AS (
    SELECT
        customer_unique_id,
        (DATE '2018-08-30' - last_purchase_date) AS recency_days,
        frequency,
        monetary
    FROM customer_rfm
)

select
COUNT(*) AS total_customers,

MIN(recency_days) AS min_recency_days,
ROUND(AVG(recency_days),2) AS avg_recency_days,
MAX(recency_days) AS max_recency_days,

MIN(frequency) AS min_frequency,
ROUND(AVG(frequency), 2) AS avg_frequency,
MAX(frequency) AS max_frequency,

MIN(monetary) AS min_monetary,
ROUND(AVG(monetary), 2) AS avg_monetary,
MAX(monetary) AS max_monetary

FROM rfm;

-- ============================================
-- 3. RFM Percentile Analysis
-- ============================================
--
-- Objective:
-- Identify percentile thresholds for recency
-- and monetary value before assigning RFM scores.
--
-- Recency: lower values are better.
-- Monetary: higher values are better.
-- ============================================

WITH customer_rfm AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp::date) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price) AS monetary
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

reference_date AS (
    SELECT
        MAX(order_purchase_timestamp::date) + 1 AS snapshot_date
    FROM orders
    WHERE order_status = 'delivered'
),

rfm AS (
    SELECT
        cr.customer_unique_id,
        rd.snapshot_date - cr.last_purchase_date AS recency_days,
        cr.frequency,
        cr.monetary
    FROM customer_rfm cr
    CROSS JOIN reference_date rd
)

SELECT
    MIN(recency_days) AS min_recency,

    PERCENTILE_CONT(0.20)
        WITHIN GROUP (ORDER BY recency_days::double precision) AS recency_p20,

    PERCENTILE_CONT(0.40)
        WITHIN GROUP (ORDER BY recency_days::double precision) AS recency_p40,

    PERCENTILE_CONT(0.60)
        WITHIN GROUP (ORDER BY recency_days::double precision) AS recency_p60,

    PERCENTILE_CONT(0.80)
        WITHIN GROUP (ORDER BY recency_days::double precision) AS recency_p80,

    MAX(recency_days) AS max_recency,

    MIN(monetary) AS min_monetary,

    PERCENTILE_CONT(0.20)
        WITHIN GROUP (ORDER BY monetary::double precision) AS monetary_p20,

    PERCENTILE_CONT(0.40)
        WITHIN GROUP (ORDER BY monetary::double precision) AS monetary_p40,

    PERCENTILE_CONT(0.60)
        WITHIN GROUP (ORDER BY monetary::double precision) AS monetary_p60,

    PERCENTILE_CONT(0.80)
        WITHIN GROUP (ORDER BY monetary::double precision) AS monetary_p80,

    MAX(monetary) AS max_monetary

FROM rfm;


-- ============================================
-- 4. RFM Scoring
-- ============================================
--
-- Objective:
-- Convert raw RFM metrics into scores from 1 to 5.
--
-- Recency:
-- Lower recency receives a higher score.
--
-- Frequency:
-- Custom thresholds are used because most customers
-- have only one delivered order.
--
-- Monetary:
-- Higher merchandise value receives a higher score.
--
-- Grain:
-- One row = one unique customer.
-- ============================================

WITH customer_rfm AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp::date) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price) AS monetary
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

reference_date AS (
    SELECT
        MAX(order_purchase_timestamp::date) + 1 AS snapshot_date
    FROM orders
    WHERE order_status = 'delivered'
),

rfm AS (
    SELECT
        cr.customer_unique_id,
        rd.snapshot_date - cr.last_purchase_date AS recency_days,
        cr.frequency,
        cr.monetary
    FROM customer_rfm cr
    CROSS JOIN reference_date rd
),

rfm_scores AS (
    SELECT
        customer_unique_id,

        CASE
            WHEN recency_days <= 93 THEN 5
            WHEN recency_days <= 178 THEN 4
            WHEN recency_days <= 269 THEN 3
            WHEN recency_days <= 383 THEN 2
            ELSE 1
        END AS r_score,

        CASE
            WHEN frequency = 1 THEN 1
            WHEN frequency = 2 THEN 2
            WHEN frequency = 3 THEN 3
            WHEN frequency BETWEEN 4 AND 5 THEN 4
            ELSE 5
        END AS f_score,

        CASE
            WHEN monetary <= 39.90 THEN 1
            WHEN monetary <= 69.90 THEN 2
            WHEN monetary <= 109.90 THEN 3
            WHEN monetary <= 179.90 THEN 4
            ELSE 5
        END AS m_score

    FROM rfm
)

SELECT
    'Recency' AS metric,
    r_score AS score,
    COUNT(*) AS customer_count
FROM rfm_scores
GROUP BY r_score

UNION ALL

SELECT
    'Frequency',
    f_score,
    COUNT(*)
FROM rfm_scores
GROUP BY f_score

UNION ALL

SELECT
    'Monetary',
    m_score,
    COUNT(*)
FROM rfm_scores
GROUP BY m_score

ORDER BY metric, score;

-- ============================================
-- 5. RFM Customer Segmentation
-- ============================================
--
-- Objective:
-- Combine RFM scores and classify customers
-- into interpretable customer segments.
--
-- Grain:
-- One row per unique customer in the underlying
-- RFM dataset.
--
-- The segment definitions are project-specific
-- business rules, not universal RFM standards.
-- ============================================

WITH customer_rfm AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp::date) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price) AS monetary
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

reference_date AS (
    SELECT
        MAX(order_purchase_timestamp::date) + 1 AS snapshot_date
    FROM orders
    WHERE order_status = 'delivered'
),

base_rfm AS (
    SELECT
        cr.customer_unique_id,
        rd.snapshot_date - cr.last_purchase_date AS recency_days,
        cr.frequency,
        cr.monetary
    FROM customer_rfm cr
    CROSS JOIN reference_date rd
),

rfm_scores AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,

        CASE
            WHEN recency_days <= 93 THEN 5
            WHEN recency_days <= 178 THEN 4
            WHEN recency_days <= 269 THEN 3
            WHEN recency_days <= 383 THEN 2
            ELSE 1
        END AS r_score,

        CASE
            WHEN frequency = 1 THEN 1
            WHEN frequency = 2 THEN 2
            WHEN frequency = 3 THEN 3
            WHEN frequency BETWEEN 4 AND 5 THEN 4
            ELSE 5
        END AS f_score,

        CASE
            WHEN monetary <= 39.90 THEN 1
            WHEN monetary <= 69.90 THEN 2
            WHEN monetary <= 109.90 THEN 3
            WHEN monetary <= 179.90 THEN 4
            ELSE 5
        END AS m_score

    FROM base_rfm
),

segmented_customers AS (
    SELECT
        *,
        CONCAT(r_score, f_score, m_score) AS rfm_score,

        CASE
            WHEN r_score >= 4
                 AND f_score >= 4
                 AND m_score >= 4
                THEN 'Champions'

            WHEN r_score >= 3
                 AND f_score >= 2
                 AND m_score >= 4
                THEN 'High-Value Repeat Customers'

            WHEN r_score >= 3
                 AND f_score >= 2
                THEN 'Potential Loyalists'

            WHEN r_score <= 2
                 AND (f_score >= 2 OR m_score >= 4)
                THEN 'At-Risk / Lapsed High-Value'

            WHEN r_score >= 4
                 AND f_score = 1
                THEN 'Recent One-Time Buyers'

            WHEN r_score <= 2
                 AND f_score = 1
                THEN 'Hibernating One-Time Buyers'

            ELSE 'Mid-Recency One-Time Buyers'
        END AS customer_segment

    FROM rfm_scores
)

SELECT
    customer_segment,
    COUNT(*) AS customer_count,

    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_share_pct,

    ROUND(AVG(recency_days)::numeric, 1) AS avg_recency_days,
    ROUND(AVG(frequency)::numeric, 2) AS avg_delivered_orders,
    ROUND(AVG(monetary), 2) AS avg_monetary

FROM segmented_customers
GROUP BY customer_segment
ORDER BY customer_count DESC;


-- ============================================
-- 6. Customer RFM Segmentation View
-- ============================================
-- Grain: one row per unique customer.
-- Snapshot: one day after latest delivered purchase.
-- Monetary: delivered merchandise value, not profit.
-- ============================================

CREATE OR REPLACE VIEW public.vw_customer_rfm_segments AS

WITH customer_rfm AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp::date) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price) AS monetary
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

reference_date AS (
    SELECT
        MAX(order_purchase_timestamp::date) + 1 AS snapshot_date
    FROM orders
    WHERE order_status = 'delivered'
),

base_rfm AS (
    SELECT
        cr.customer_unique_id,
        cr.last_purchase_date,
        rd.snapshot_date,
        rd.snapshot_date - cr.last_purchase_date AS recency_days,
        cr.frequency,
        cr.monetary
    FROM customer_rfm cr
    CROSS JOIN reference_date rd
),

rfm_scores AS (
    SELECT
        *,
        CASE
            WHEN recency_days <= 93 THEN 5
            WHEN recency_days <= 178 THEN 4
            WHEN recency_days <= 269 THEN 3
            WHEN recency_days <= 383 THEN 2
            ELSE 1
        END AS r_score,

        CASE
            WHEN frequency = 1 THEN 1
            WHEN frequency = 2 THEN 2
            WHEN frequency = 3 THEN 3
            WHEN frequency BETWEEN 4 AND 5 THEN 4
            ELSE 5
        END AS f_score,

        CASE
            WHEN monetary <= 39.90 THEN 1
            WHEN monetary <= 69.90 THEN 2
            WHEN monetary <= 109.90 THEN 3
            WHEN monetary <= 179.90 THEN 4
            ELSE 5
        END AS m_score
    FROM base_rfm
)

SELECT
    *,
    CONCAT(r_score, f_score, m_score) AS rfm_score,

    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4
            THEN 'Champions'

        WHEN r_score >= 3 AND f_score >= 2 AND m_score >= 4
            THEN 'High-Value Repeat Customers'

        WHEN r_score >= 3 AND f_score >= 2
            THEN 'Potential Loyalists'

        WHEN r_score <= 2 AND (f_score >= 2 OR m_score >= 4)
            THEN 'At-Risk / Lapsed High-Value'

        WHEN r_score >= 4 AND f_score = 1
            THEN 'Recent One-Time Buyers'

        WHEN r_score <= 2 AND f_score = 1
            THEN 'Hibernating One-Time Buyers'

        ELSE 'Mid-Recency One-Time Buyers'
    END AS customer_segment

FROM rfm_scores;