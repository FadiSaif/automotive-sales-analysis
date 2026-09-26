-- ============================================================
-- Vehicle Model & Origin Quality Performance — Realized Baseline
-- Filter : is_posted = true AND is_released = true
-- Compares Genuine / OEM / Aftermarket across vehicle models.
-- Source : gold.fact_sales × gold.dim_product × gold.dim_sales_order
-- ============================================================

WITH base AS (
    SELECT
        p.vehicle_make_model,
        p.origin_quality,
        p.vehicle_system,

        SUM(f.line_total_sar)                                  AS realized_revenue,
        SUM(f.line_total_sar - f.unit_cost_sar * f.quantity)   AS realized_gross_profit,
        SUM(f.quantity)                                        AS qty_sold,
        SUM(f.returned_quantity)                               AS qty_returned,
        COUNT(DISTINCT f.sales_order_key)                      AS realized_order_count

    FROM      gold.fact_sales       f
    JOIN      gold.dim_product      p   ON f.product_key      = p.product_key
    JOIN      gold.dim_sales_order  so  ON f.sales_order_key  = so.sales_order_key
    WHERE     so.is_posted = true 
      AND     so.is_released = true
    GROUP BY  p.vehicle_make_model, p.origin_quality, p.vehicle_system
)

SELECT
    vehicle_make_model,
    origin_quality,
    vehicle_system,

    realized_revenue,
    realized_gross_profit,
    ROUND((realized_gross_profit / NULLIF(realized_revenue, 0) * 100)::NUMERIC, 2) AS margin_pct,

    qty_sold,
    qty_returned,
    ROUND((qty_returned / NULLIF(qty_sold, 0) * 100)::NUMERIC, 2)                  AS return_rate_pct,
    realized_order_count,

    -- Share within vehicle model
    ROUND((
        realized_revenue / NULLIF(SUM(realized_revenue) OVER (PARTITION BY vehicle_make_model), 0) * 100
    )::NUMERIC, 2)                                                                  AS revenue_share_in_model_pct

FROM  base
ORDER BY vehicle_make_model, realized_revenue DESC;
