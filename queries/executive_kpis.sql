-- ============================================================
-- Executive KPIs — Monthly Performance Dashboard (Corrected Baseline)
-- Scope  : 100% Confirmed Commercial Sales (Historically Posted + Reconciled Backlog)
-- Metrics: Corrected Turnover, Reconciled Lift, COGS, Gross Margin %, AOV, Units, Returns, MoM Growth
-- Source : gold.fact_sales × gold.dim_date × gold.dim_sales_order
-- ============================================================

WITH monthly_summary AS (
    SELECT
        d.year,
        d.month,
        DATE_TRUNC('month', d.full_date)::DATE                               AS month_start,

        -- 1. Dual-Baseline Turnover
        SUM(CASE 
            WHEN so.is_posted = true AND so.is_released = true 
            THEN f.line_total_sar ELSE 0 
        END)                                                                 AS historically_realized_turnover,
        SUM(CASE 
            WHEN so.is_posted = false OR so.is_released = false 
            THEN f.line_total_sar ELSE 0 
        END)                                                                 AS reconciled_backlog_turnover,
        SUM(f.line_total_sar)                                                AS corrected_turnover,

        -- 2. Cost & Profitability
        SUM(f.quantity * f.unit_cost_sar)                                    AS corrected_cogs,
        SUM(f.line_total_sar - (f.quantity * f.unit_cost_sar))               AS corrected_gross_margin,

        -- 3. Volume Metrics
        COUNT(DISTINCT so.sales_order_key)                                   AS total_orders,
        COUNT(f.fact_sales_key)                                              AS total_line_items,
        SUM(f.quantity)                                                      AS units_sold,
        SUM(f.returned_quantity)                                             AS units_returned

    FROM      gold.fact_sales       f
    JOIN      gold.dim_date         d   ON f.date_key        = d.date_key
    JOIN      gold.dim_sales_order  so  ON f.sales_order_key = so.sales_order_key
    GROUP BY  d.year, d.month, DATE_TRUNC('month', d.full_date)
)

SELECT
    month_start,
    year,
    month,

    -- Commercial Turnover Waterfall
    ROUND(historically_realized_turnover::NUMERIC, 2)                        AS historically_realized_turnover,
    ROUND(reconciled_backlog_turnover::NUMERIC, 2)                           AS reconciled_backlog_turnover,
    ROUND(corrected_turnover::NUMERIC, 2)                                    AS corrected_turnover,
    ROUND((
        reconciled_backlog_turnover::NUMERIC 
        / NULLIF(historically_realized_turnover, 0) * 100
    )::NUMERIC, 2)                                                           AS backlog_lift_pct,

    -- Cost of Goods Sold & Margin
    ROUND(corrected_cogs::NUMERIC, 2)                                        AS corrected_cogs,
    ROUND(corrected_gross_margin::NUMERIC, 2)                                AS corrected_gross_margin,
    ROUND((
        corrected_gross_margin::NUMERIC 
        / NULLIF(corrected_turnover, 0) * 100
    )::NUMERIC, 2)                                                           AS gross_margin_pct,

    -- Volume & Basket Performance
    total_orders,
    ROUND((corrected_turnover::NUMERIC / NULLIF(total_orders, 0))::NUMERIC, 2) AS avg_order_value_sar,
    units_sold,
    units_returned,
    ROUND((units_returned::NUMERIC / NULLIF(units_sold, 0) * 100)::NUMERIC, 2) AS return_rate_pct,

    -- Month-over-Month Growth (Corrected Turnover)
    ROUND((
        (corrected_turnover - LAG(corrected_turnover) OVER (ORDER BY month_start))
        / NULLIF(LAG(corrected_turnover) OVER (ORDER BY month_start), 0) * 100
    )::NUMERIC, 2)                                                           AS mom_turnover_growth_pct

FROM  monthly_summary
ORDER BY month_start;
