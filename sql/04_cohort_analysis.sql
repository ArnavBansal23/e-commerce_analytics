-- ============================================
-- OLIST E-COMMERCE ANALYTICS
-- 04 - Cohort and Retention Analysis
-- ============================================
--
-- Objective:
-- Measure customer retention over time.
--
-- Cohort definition:
-- The month of a customer's first observed
-- delivered order in the dataset.
--
-- Activity definition:
-- A customer is active in a month if they
-- have at least one delivered order in that month.
--
-- Grain:
-- One row = one cohort and one activity month.
--
-- Retention rate:
-- Customers active in the activity month
-- divided by the original cohort size.
-- ============================================

WITH delivered_customer_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        DATE_TRUNC(
            'month',
            o.order_purchase_timestamp
        )::date AS activity_month
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),

customer_cohorts AS (
    SELECT
        customer_unique_id,
        MIN(activity_month) AS cohort_month
    FROM delivered_customer_orders
    GROUP BY customer_unique_id
),

cohort_activity AS (
    SELECT DISTINCT
        d.customer_unique_id,
        cc.cohort_month,
        d.activity_month,

        (
            (
                EXTRACT(YEAR FROM d.activity_month)
                - EXTRACT(YEAR FROM cc.cohort_month)
            ) * 12
            +
            EXTRACT(MONTH FROM d.activity_month)
            - EXTRACT(MONTH FROM cc.cohort_month)
        )::integer AS cohort_index

    FROM delivered_customer_orders d
    JOIN customer_cohorts cc
        ON d.customer_unique_id = cc.customer_unique_id
),

cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(*) AS cohort_size
    FROM customer_cohorts
    GROUP BY cohort_month
),

retention_counts AS (
    SELECT
        cohort_month,
        cohort_index,
        COUNT(DISTINCT customer_unique_id) AS active_customers
    FROM cohort_activity
    GROUP BY
        cohort_month,
        cohort_index
)

SELECT
    rc.cohort_month,
    rc.cohort_index,
    cs.cohort_size,
    rc.active_customers,

    ROUND(
        100.0 * rc.active_customers / cs.cohort_size,
        2
    ) AS retention_rate_pct

FROM retention_counts rc
JOIN cohort_sizes cs
    ON rc.cohort_month = cs.cohort_month

ORDER BY
    rc.cohort_month,
    rc.cohort_index;



    -- ============================================
-- OLIST E-COMMERCE ANALYTICS
-- 04 - Cohort and Retention Analysis
-- ============================================
--
-- Objective:
-- Track monthly repeat-purchase activity by
-- customer acquisition cohort.
--
-- Cohort:
-- Month of the first observed delivered order.
--
-- Activity:
-- At least one delivered order purchased in a month.
--
-- Retention:
-- Active customers / original cohort size * 100.
--
-- Grain:
-- One row = one cohort and one cohort month index.
-- ============================================

CREATE OR REPLACE VIEW public.vw_cohort_retention AS

WITH delivered_customer_orders AS (
    SELECT DISTINCT
        c.customer_unique_id,
        o.order_id,
        DATE_TRUNC(
            'month',
            o.order_purchase_timestamp
        )::date AS activity_month
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),

customer_cohorts AS (
    SELECT
        customer_unique_id,
        MIN(activity_month) AS cohort_month
    FROM delivered_customer_orders
    GROUP BY customer_unique_id
),

cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(*) AS cohort_size
    FROM customer_cohorts
    GROUP BY cohort_month
),

cohort_activity AS (
    SELECT DISTINCT
        d.customer_unique_id,
        cc.cohort_month,
        d.activity_month,

        (
            (EXTRACT(YEAR FROM d.activity_month)
             - EXTRACT(YEAR FROM cc.cohort_month)) * 12
            + EXTRACT(MONTH FROM d.activity_month)
            - EXTRACT(MONTH FROM cc.cohort_month)
        )::integer AS cohort_index

    FROM delivered_customer_orders d
    JOIN customer_cohorts cc
        ON d.customer_unique_id = cc.customer_unique_id
),

retention_counts AS (
    SELECT
        cohort_month,
        cohort_index,
        COUNT(DISTINCT customer_unique_id) AS active_customers
    FROM cohort_activity
    GROUP BY cohort_month, cohort_index
),

latest_activity AS (
    SELECT MAX(activity_month) AS max_activity_month
    FROM delivered_customer_orders
)

SELECT
    cs.cohort_month,
    gs.cohort_index,
    cs.cohort_size,
    COALESCE(rc.active_customers, 0) AS active_customers,

    ROUND(
        100.0 * COALESCE(rc.active_customers, 0)
        / cs.cohort_size,
        2
    ) AS retention_rate_pct

FROM cohort_sizes cs
CROSS JOIN latest_activity la

CROSS JOIN LATERAL GENERATE_SERIES(
    0,
    (
        (EXTRACT(YEAR FROM la.max_activity_month)
         - EXTRACT(YEAR FROM cs.cohort_month)) * 12
        + EXTRACT(MONTH FROM la.max_activity_month)
        - EXTRACT(MONTH FROM cs.cohort_month)
    )::integer
) AS gs(cohort_index)

LEFT JOIN retention_counts rc
    ON rc.cohort_month = cs.cohort_month
   AND rc.cohort_index = gs.cohort_index;