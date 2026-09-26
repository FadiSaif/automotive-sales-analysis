-- ============================================================
-- Vehicle Model & Origin Quality Performance — Corrected Baseline
-- Scope  : 100% Confirmed Commercial Sales (All 18,028 Line Items)
-- Metrics: Realized vs Backlog Revenue, Total Revenue, Margin %, Return Rate %
-- Source : gold.fact_sales × gold.dim_product × gold.dim_sales_order
-- ============================================================

WITH base AS (
    SELECT
        p.vehicle_make_model,
        p.origin_quality,
        p.vehicle_system,

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

        -- Profitability & Quantities
        SUM(f.quantity * f.unit_cost_sar)                                    AS total_cogs,
        SUM(f.line_total_sar - (f.quantity * f.unit_cost_sar))               AS total_gross_profit,
        SUM(f.quantity)                                                      AS total_qty_sold,
        SUM(f.returned_quantity)                                             AS total_qty_returned,
        COUNT(DISTINCT so.sales_order_key)                                   AS total_orders_count

    FROM      gold.fact_sales       f
    JOIN      gold.dim_product      p   ON f.product_key      = p.product_key
    JOIN      gold.dim_sales_order  so  ON f.sales_order_key  = so.sales_order_key
    GROUP BY  p.vehicle_make_model, p.origin_quality, p.vehicle_system
)

SELECT
    vehicle_make_model,
    origin_quality,
    vehicle_system,

    -- Revenue Metrics
    ROUND(historically_realized_revenue::NUMERIC, 2)                         AS historically_realized_revenue,
    ROUND(reconciled_backlog_revenue::NUMERIC, 2)                            AS reconciled_backlog_revenue,
    ROUND(total_revenue::NUMERIC, 2)                                         AS total_revenue,
    ROUND((
        reconciled_backlog_revenue::NUMERIC 
        / NULLIF(historically_realized_revenue, 0) * 100
    )::NUMERIC, 2)                                                           AS backlog_lift_pct,

    -- Margin
    ROUND(total_gross_profit::NUMERIC, 2)                                    AS total_gross_profit,
    ROUND((total_gross_profit / NULLIF(total_revenue, 0) * 100)::NUMERIC, 2) AS margin_pct,

    -- Quantities & Returns
    total_qty_sold,
    total_qty_returned,
    ROUND((total_qty_returned / NULLIF(total_qty_sold, 0) * 100)::NUMERIC, 2) AS return_rate_pct,
    total_orders_count,

    -- Share within Vehicle Model
    ROUND((
        total_revenue / NULLIF(SUM(total_revenue) OVER (PARTITION BY vehicle_make_model), 0) * 100
    )::NUMERIC, 2)                                                           AS revenue_share_in_model_pct

FROM  base
ORDER BY vehicle_make_model, total_revenue DESC;
