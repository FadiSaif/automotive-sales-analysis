-- ============================================================
-- Pareto Analysis by Part Category — Realized Baseline
-- Filter : is_posted = true AND is_released = true
-- Source : gold.fact_sales × gold.dim_product × gold.dim_sales_order
-- ============================================================

WITH
    RankedProfit AS (
        SELECT
            p.part_category,
            SUM(s.quantity * (s.unit_price_sar - s.unit_cost_sar)) AS net_profit
        FROM
            gold.fact_sales s
            JOIN gold.dim_product p ON s.product_key = p.product_key
            JOIN gold.dim_sales_order so ON s.sales_order_key = so.sales_order_key
        WHERE
            so.is_posted = true 
            AND so.is_released = true
            AND p.part_category NOT IN (
                'Unspecified / Placeholder',
                'Other Parts & Accessories'
            )
        GROUP BY
            p.part_category
    ),
    CumulativeProfit AS (
        SELECT
            part_category,
            net_profit,
            SUM(net_profit) OVER (
                ORDER BY
                    net_profit DESC
            ) AS running_total_profit,
            SUM(net_profit) OVER () AS total_overall_profit
        FROM
            RankedProfit
    )
SELECT
    part_category AS "ITEM NAME",
    TO_CHAR (net_profit, 'FM9,999,999.00') AS "NET PROFIT",
    TO_CHAR (running_total_profit, 'FM9,999,999.00') AS "CUMULATIVE PROFIT",
    TO_CHAR (
        (running_total_profit / total_overall_profit) * 100,
        'FM990.00'
    ) || '%' AS "CUMULATIVE PROFIT %",
    CASE
        WHEN (running_total_profit / total_overall_profit) <= 0.80 THEN 'Class A (Top 80%)'
        WHEN (running_total_profit / total_overall_profit) <= 0.95 THEN 'Class B (Next 15%)'
        ELSE 'Class C (Bottom 5%)'
    END AS "PARETO ABC CLASS"
FROM
    CumulativeProfit
ORDER BY
    net_profit DESC;