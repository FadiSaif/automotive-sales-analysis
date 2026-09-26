-- ============================================================
-- Revenue Reconciliation Bridge (Dual-Baseline Waterfall)
-- Compares:
--   1. Baseline 1: Historically Realized (is_posted = true AND is_released = true)
--   2. Reconciled Backlog: Unposted Cash Orders (is_posted = false AND is_cheque = false)
--   3. Reconciled Cheques: Uncleared Cheque Orders (is_posted = false AND is_cheque = true)
--   4. Baseline 2: Corrected Total Turnover (100% Authorized Sales)
-- Source : gold.fact_sales × gold.dim_date × gold.dim_sales_order
-- ============================================================

WITH monthly_components AS (
    SELECT
        d.year,
        d.month,
        DATE_TRUNC('month', d.full_date)::DATE                               AS month_start,

        -- 1. Historically Realized Baseline
        SUM(CASE 
            WHEN so.is_posted = true AND so.is_released = true 
            THEN f.line_total_sar ELSE 0 
        END)                                                                 AS historically_realized_sar,
        COUNT(DISTINCT CASE 
            WHEN so.is_posted = true AND so.is_released = true 
            THEN so.sales_order_key 
        END)                                                                 AS historically_realized_orders,

        -- 2. Reconciled Cash Backlog
        SUM(CASE 
            WHEN so.is_posted = false AND so.is_cheque = false 
            THEN f.line_total_sar ELSE 0 
        END)                                                                 AS reconciled_cash_backlog_sar,
        COUNT(DISTINCT CASE 
            WHEN so.is_posted = false AND so.is_cheque = false 
            THEN so.sales_order_key 
        END)                                                                 AS reconciled_cash_orders,

        -- 3. Reconciled Cheque Pipeline
        SUM(CASE 
            WHEN so.is_posted = false AND so.is_cheque = true 
            THEN f.line_total_sar ELSE 0 
        END)                                                                 AS reconciled_cheque_sar,
        COUNT(DISTINCT CASE 
            WHEN so.is_posted = false AND so.is_cheque = true 
            THEN so.sales_order_key 
        END)                                                                 AS reconciled_cheque_orders,

        -- 4. Corrected Total
        SUM(f.line_total_sar)                                                AS corrected_total_sar,
        COUNT(DISTINCT so.sales_order_key)                                   AS corrected_total_orders,
        COUNT(f.fact_sales_key)                                              AS corrected_line_items,
        SUM(f.quantity)                                                      AS corrected_units_sold

    FROM      gold.fact_sales       f
    JOIN      gold.dim_date         d   ON f.date_key        = d.date_key
    JOIN      gold.dim_sales_order  so  ON f.sales_order_key = so.sales_order_key
    GROUP BY  d.year, d.month, DATE_TRUNC('month', d.full_date)
)

SELECT
    month_start,
    year,
    month,

    -- Step 1: Historical Realized Baseline
    ROUND(historically_realized_sar::NUMERIC, 2)                             AS historically_realized_sar,
    historically_realized_orders,

    -- Step 2: Backlog Reconciliation Adjustments
    ROUND(reconciled_cash_backlog_sar::NUMERIC, 2)                           AS reconciled_cash_backlog_sar,
    reconciled_cash_orders,
    ROUND(reconciled_cheque_sar::NUMERIC, 2)                                 AS reconciled_cheque_sar,
    reconciled_cheque_orders,
    ROUND((reconciled_cash_backlog_sar + reconciled_cheque_sar)::NUMERIC, 2) AS total_reconciled_backlog_sar,

    -- Step 3: Corrected Commercial Baseline
    ROUND(corrected_total_sar::NUMERIC, 2)                                   AS corrected_total_sar,
    corrected_total_orders,
    corrected_line_items,
    corrected_units_sold,

    -- Bridge Metrics: Absolute & Percentage Lift
    ROUND((corrected_total_sar - historically_realized_sar)::NUMERIC, 2)     AS absolute_backlog_lift_sar,
    ROUND((
        (corrected_total_sar - historically_realized_sar)::NUMERIC 
        / NULLIF(historically_realized_sar, 0) * 100
    )::NUMERIC, 2)                                                           AS backlog_lift_pct

FROM  monthly_components
ORDER BY month_start;
