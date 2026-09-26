-- ============================================================
-- Executive KPIs — Monthly Performance Dashboard
-- Metrics: Revenue, Orders, AOV, Gross Margin %, MoM Growth
-- Source : gold.fact_sales × gold.dim_date
-- ============================================================

WITH monthly AS (
    SELECT
        d.year,
        d.month,
        DATE_TRUNC('month', d.full_date)::DATE              AS month_start,

        -- Revenue & Cost
        SUM(f.line_total_sar)                                AS revenue,
        SUM(f.unit_cost_sar * f.quantity)                    AS total_cost,
        SUM(f.discount_amount_sar)                           AS total_discount,
        SUM(f.vat_amount_sar)                                AS total_vat,

        -- Volume
        COUNT(DISTINCT f.sales_order_key)                    AS order_count,
        SUM(f.quantity)                                      AS units_sold,
        SUM(f.returned_quantity)                              AS units_returned

    FROM      gold.fact_sales       f
    JOIN      gold.dim_date         d  ON f.date_key         = d.date_key
    GROUP BY  d.year, d.month, DATE_TRUNC('month', d.full_date)
)

SELECT
    month_start,
    year,
    month,

    -- Core KPIs
    revenue,
    order_count,
    ROUND(revenue / NULLIF(order_count, 0)::NUMERIC, 2)      AS avg_order_value,
    units_sold,
    units_returned,

    -- Margin
    revenue - total_cost                                      AS gross_profit,
    ROUND(((revenue - total_cost) / NULLIF(revenue, 0) * 100)::NUMERIC, 2)
                                                              AS gross_margin_pct,
    -- Discount intensity
    ROUND((total_discount / NULLIF(revenue, 0) * 100)::NUMERIC, 2)
                                                              AS discount_pct,

    -- Month-over-Month revenue growth (%)
    ROUND((
        (revenue - LAG(revenue) OVER (ORDER BY month_start))
        / NULLIF(LAG(revenue) OVER (ORDER BY month_start), 0) * 100
    )::NUMERIC, 2)                                            AS revenue_mom_growth_pct

FROM  monthly
ORDER BY month_start;
