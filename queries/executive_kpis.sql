-- ============================================================
-- Executive KPIs — Monthly Performance Dashboard (Realized Baseline)
-- Filter : is_posted = true AND is_released = true (Realized Sales)
-- Metrics: Realized Turnover, Orders, AOV, Gross Margin %, MoM Growth, Backlog Exposure
-- Source : gold.fact_sales × gold.dim_date × gold.dim_sales_order
-- ============================================================

WITH monthly_realized AS (
    SELECT
        d.year,
        d.month,
        DATE_TRUNC('month', d.full_date)::DATE              AS month_start,

        -- Realized Revenue & Cost
        SUM(f.line_total_sar)                                AS realized_revenue,
        SUM(f.unit_cost_sar * f.quantity)                    AS realized_cogs,
        SUM(f.discount_amount_sar)                           AS total_discount,

        -- Volume
        COUNT(DISTINCT f.sales_order_key)                    AS realized_order_count,
        SUM(f.quantity)                                      AS units_sold,
        SUM(f.returned_quantity)                             AS units_returned

    FROM      gold.fact_sales       f
    JOIN      gold.dim_date         d   ON f.date_key         = d.date_key
    JOIN      gold.dim_sales_order  so  ON f.sales_order_key  = so.sales_order_key
    WHERE     so.is_posted = true 
      AND     so.is_released = true
    GROUP BY  d.year, d.month, DATE_TRUNC('month', d.full_date)
),
monthly_backlog AS (
    SELECT
        d.year,
        d.month,
        SUM(f.line_total_sar)                                AS unposted_backlog_revenue,
        COUNT(DISTINCT f.sales_order_key)                    AS backlog_order_count
    FROM      gold.fact_sales       f
    JOIN      gold.dim_date         d   ON f.date_key         = d.date_key
    JOIN      gold.dim_sales_order  so  ON f.sales_order_key  = so.sales_order_key
    WHERE     so.is_posted = false
    GROUP BY  d.year, d.month
)

SELECT
    r.month_start,
    r.year,
    r.month,

    -- Confirmed Realized KPIs
    r.realized_revenue,
    r.realized_order_count,
    ROUND((r.realized_revenue / NULLIF(r.realized_order_count, 0))::NUMERIC, 2) AS avg_order_value,
    r.units_sold,
    r.units_returned,
    ROUND((r.units_returned / NULLIF(r.units_sold, 0) * 100)::NUMERIC, 2)       AS return_rate_pct,

    -- Realized Margin
    r.realized_revenue - r.realized_cogs                                        AS gross_profit,
    ROUND(((r.realized_revenue - r.realized_cogs) / NULLIF(r.realized_revenue, 0) * 100)::NUMERIC, 2)
                                                                                AS gross_margin_pct,

    -- Month-over-Month Growth
    ROUND((
        (r.realized_revenue - LAG(r.realized_revenue) OVER (ORDER BY r.month_start))
        / NULLIF(LAG(r.realized_revenue) OVER (ORDER BY r.month_start), 0) * 100
    )::NUMERIC, 2)                                                              AS revenue_mom_growth_pct,

    -- Operational Backlog Exposure
    COALESCE(b.unposted_backlog_revenue, 0)                                     AS unposted_backlog_revenue,
    COALESCE(b.backlog_order_count, 0)                                          AS backlog_order_count

FROM  monthly_realized r
LEFT JOIN monthly_backlog b ON r.year = b.year AND r.month = b.month
ORDER BY r.month_start;
