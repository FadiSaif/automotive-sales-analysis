-- ============================================================
-- Product Pareto (80 / 20) Analysis
-- Ranks products by revenue & profit, flags the vital few.
-- Source : gold.fact_sales × gold.dim_product
-- ============================================================

WITH product_metrics AS (
    SELECT
        p.product_key,
        p.product_name,
        p.part_category,
        p.vehicle_system,
        p.vehicle_make_model,
        p.origin_quality,

        SUM(f.line_total_sar)                                 AS revenue,
        SUM(f.line_total_sar - f.unit_cost_sar * f.quantity)  AS gross_profit,
        SUM(f.quantity)                                        AS qty_sold

    FROM      gold.fact_sales    f
    JOIN      gold.dim_product   p  ON f.product_key = p.product_key
    GROUP BY  p.product_key, p.product_name, p.part_category,
              p.vehicle_system, p.vehicle_make_model, p.origin_quality
),

ranked AS (
    SELECT
        *,

        -- Revenue Pareto
        ROW_NUMBER()  OVER (ORDER BY revenue      DESC)       AS revenue_rank,
        SUM(revenue)  OVER ()                                 AS total_revenue,
        SUM(revenue)  OVER (ORDER BY revenue DESC
                            ROWS BETWEEN UNBOUNDED PRECEDING
                            AND CURRENT ROW)                  AS cum_revenue,

        -- Profit Pareto
        ROW_NUMBER()    OVER (ORDER BY gross_profit DESC)     AS profit_rank,
        SUM(gross_profit) OVER ()                             AS total_profit,
        SUM(gross_profit) OVER (ORDER BY gross_profit DESC
                                ROWS BETWEEN UNBOUNDED PRECEDING
                                AND CURRENT ROW)              AS cum_profit
    FROM product_metrics
)

SELECT
    revenue_rank,
    product_key,
    product_name,
    part_category,
    vehicle_system,
    origin_quality,

    revenue,
    ROUND(cum_revenue   / NULLIF(total_revenue, 0) * 100, 2) AS cum_revenue_pct,
    gross_profit,
    ROUND(cum_profit    / NULLIF(total_profit, 0)  * 100, 2) AS cum_profit_pct,
    qty_sold,

    -- Classification
    CASE
        WHEN cum_revenue / NULLIF(total_revenue, 0) <= 0.80 THEN 'A — Vital Few'
        WHEN cum_revenue / NULLIF(total_revenue, 0) <= 0.95 THEN 'B — Important'
        ELSE 'C — Trivial Many'
    END                                                        AS pareto_class

FROM  ranked
ORDER BY revenue_rank;
