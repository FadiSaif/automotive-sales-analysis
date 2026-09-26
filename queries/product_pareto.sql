-- ============================================================
-- Product Pareto (80 / 20) Analysis — Realized Baseline
-- Filter : is_posted = true AND is_released = true
-- Ranks products by realized revenue & gross profit.
-- Source : gold.fact_sales × gold.dim_product × gold.dim_sales_order
-- ============================================================

WITH product_metrics AS (
    SELECT
        p.product_key,
        p.item_code,
        p.item_name,
        p.part_category,
        p.vehicle_system,
        p.vehicle_make_model,
        p.origin_quality,

        SUM(f.line_total_sar)                                 AS realized_revenue,
        SUM(f.line_total_sar - f.unit_cost_sar * f.quantity)  AS realized_gross_profit,
        SUM(f.quantity)                                       AS qty_sold

    FROM      gold.fact_sales       f
    JOIN      gold.dim_product      p   ON f.product_key      = p.product_key
    JOIN      gold.dim_sales_order  so  ON f.sales_order_key  = so.sales_order_key
    WHERE     so.is_posted = true 
      AND     so.is_released = true
    GROUP BY  p.product_key, p.item_code, p.item_name, p.part_category,
              p.vehicle_system, p.vehicle_make_model, p.origin_quality
),

ranked AS (
    SELECT
        *,

        -- Revenue Pareto
        ROW_NUMBER()  OVER (ORDER BY realized_revenue DESC)   AS revenue_rank,
        SUM(realized_revenue) OVER ()                         AS total_revenue,
        SUM(realized_revenue) OVER (ORDER BY realized_revenue DESC
                                    ROWS BETWEEN UNBOUNDED PRECEDING
                                    AND CURRENT ROW)          AS cum_revenue,

        -- Profit Pareto
        ROW_NUMBER()    OVER (ORDER BY realized_gross_profit DESC) AS profit_rank,
        SUM(realized_gross_profit) OVER ()                         AS total_profit,
        SUM(realized_gross_profit) OVER (ORDER BY realized_gross_profit DESC
                                        ROWS BETWEEN UNBOUNDED PRECEDING
                                        AND CURRENT ROW)           AS cum_profit
    FROM product_metrics
)

SELECT
    revenue_rank,
    product_key,
    item_code,
    item_name,
    part_category,
    vehicle_system,
    origin_quality,

    realized_revenue,
    ROUND((cum_revenue   / NULLIF(total_revenue, 0) * 100)::NUMERIC, 2) AS cum_revenue_pct,
    realized_gross_profit,
    ROUND((cum_profit    / NULLIF(total_profit, 0)  * 100)::NUMERIC, 2) AS cum_profit_pct,
    qty_sold,

    -- Pareto Classification
    CASE
        WHEN cum_revenue / NULLIF(total_revenue, 0) <= 0.80 THEN 'A - Vital Few (Top 80%)'
        WHEN cum_revenue / NULLIF(total_revenue, 0) <= 0.95 THEN 'B - Important (Next 15%)'
        ELSE 'C - Trivial Many (Bottom 5%)'
    END                                                                  AS pareto_class

FROM  ranked
ORDER BY revenue_rank;
