-- ============================================================
-- Product Pareto (80 / 20) Analysis — Corrected Baseline
-- Scope  : 100% Confirmed Commercial Sales (All 18,028 Line Items)
-- Metrics: Realized vs Backlog Revenue, Total Revenue, Gross Profit, Pareto ABC
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

        -- Dual-Baseline Breakdown
        SUM(CASE 
            WHEN so.is_posted = true AND so.is_released = true 
            THEN f.line_total_sar ELSE 0 
        END)                                                                 AS historically_realized_revenue,
        SUM(CASE 
            WHEN so.is_posted = false OR so.is_released = false 
            THEN f.line_total_sar ELSE 0 
        END)                                                                 AS reconciled_backlog_revenue,
        SUM(f.line_total_sar)                                                AS total_revenue,

        -- Profitability & Volume
        SUM(f.quantity * f.unit_cost_sar)                                    AS total_cogs,
        SUM(f.line_total_sar - (f.quantity * f.unit_cost_sar))               AS total_gross_profit,
        SUM(f.quantity)                                                      AS total_qty_sold,
        SUM(f.returned_quantity)                                             AS total_qty_returned

    FROM      gold.fact_sales       f
    JOIN      gold.dim_product      p   ON f.product_key      = p.product_key
    JOIN      gold.dim_sales_order  so  ON f.sales_order_key  = so.sales_order_key
    GROUP BY  p.product_key, p.item_code, p.item_name, p.part_category,
              p.vehicle_system, p.vehicle_make_model, p.origin_quality
),

ranked AS (
    SELECT
        *,

        -- Revenue Pareto
        ROW_NUMBER()  OVER (ORDER BY total_revenue DESC)                     AS revenue_rank,
        SUM(total_revenue) OVER ()                                           AS grand_total_revenue,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC
                                 ROWS BETWEEN UNBOUNDED PRECEDING
                                 AND CURRENT ROW)                            AS cum_revenue,

        -- Profit Pareto
        ROW_NUMBER()  OVER (ORDER BY total_gross_profit DESC)                AS profit_rank,
        SUM(total_gross_profit) OVER ()                                      AS grand_total_profit,
        SUM(total_gross_profit) OVER (ORDER BY total_gross_profit DESC
                                      ROWS BETWEEN UNBOUNDED PRECEDING
                                      AND CURRENT ROW)                       AS cum_profit
    FROM product_metrics
)

SELECT
    revenue_rank,
    product_key,
    item_code,
    item_name,
    part_category,
    vehicle_system,
    vehicle_make_model,
    origin_quality,

    -- Turnover Metrics
    ROUND(historically_realized_revenue::NUMERIC, 2)                         AS historically_realized_revenue,
    ROUND(reconciled_backlog_revenue::NUMERIC, 2)                            AS reconciled_backlog_revenue,
    ROUND(total_revenue::NUMERIC, 2)                                         AS total_revenue,
    ROUND((cum_revenue / NULLIF(grand_total_revenue, 0) * 100)::NUMERIC, 2)  AS cum_revenue_pct,

    -- Margin & Cost
    ROUND(total_cogs::NUMERIC, 2)                                            AS total_cogs,
    ROUND(total_gross_profit::NUMERIC, 2)                                    AS total_gross_profit,
    ROUND((total_gross_profit / NULLIF(total_revenue, 0) * 100)::NUMERIC, 2) AS gross_margin_pct,
    ROUND((cum_profit / NULLIF(grand_total_profit, 0) * 100)::NUMERIC, 2)    AS cum_profit_pct,

    -- Quantities
    total_qty_sold,
    total_qty_returned,

    -- Pareto Classification (Revenue Basis)
    CASE
        WHEN cum_revenue / NULLIF(grand_total_revenue, 0) <= 0.80 THEN 'A - Vital Few (Top 80%)'
        WHEN cum_revenue / NULLIF(grand_total_revenue, 0) <= 0.95 THEN 'B - Important (Next 15%)'
        ELSE 'C - Trivial Many (Bottom 5%)'
    END                                                                      AS pareto_class

FROM  ranked
ORDER BY revenue_rank;
