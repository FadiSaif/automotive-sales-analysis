-- ============================================================
-- Vehicle Model & Origin Quality Performance
-- Compares Genuine / OEM / Aftermarket across vehicle models.
-- Source : gold.fact_sales × gold.dim_product
-- ============================================================

WITH base AS (
    SELECT
        p.vehicle_make_model,
        p.origin_quality,
        p.vehicle_system,

        SUM(f.line_total_sar)                                  AS revenue,
        SUM(f.line_total_sar - f.unit_cost_sar * f.quantity)   AS gross_profit,
        SUM(f.quantity)                                         AS qty_sold,
        SUM(f.returned_quantity)                                AS qty_returned,
        COUNT(DISTINCT f.sales_order_key)                       AS order_count

    FROM      gold.fact_sales    f
    JOIN      gold.dim_product   p  ON f.product_key = p.product_key
    GROUP BY  p.vehicle_make_model, p.origin_quality, p.vehicle_system
)

SELECT
    vehicle_make_model,
    origin_quality,
    vehicle_system,

    revenue,
    gross_profit,
    ROUND((gross_profit / NULLIF(revenue, 0) * 100)::NUMERIC, 2)   AS margin_pct,

    qty_sold,
    qty_returned,
    ROUND((qty_returned / NULLIF(qty_sold, 0) * 100)::NUMERIC, 2)  AS return_rate_pct,
    order_count,

    -- Share within vehicle model
    ROUND((
        revenue / NULLIF(SUM(revenue) OVER (PARTITION BY vehicle_make_model), 0) * 100
    )::NUMERIC, 2)                                                  AS revenue_share_in_model_pct

FROM  base
ORDER BY vehicle_make_model, revenue DESC;
