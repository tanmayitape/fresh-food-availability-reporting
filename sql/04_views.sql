-- Reporting views. Availability = share of trading hours (06:00-22:00) a line was in stock.

CREATE VIEW dbo.vw_availability_store_day AS
SELECT f.dt, d.week_start, s.city_id, f.store_id,
       COUNT(*)                                          AS lines_ranged,
       SUM(CASE WHEN f.oos_hours = 16 THEN 1 ELSE 0 END) AS lines_out_all_day,
       SUM(CASE WHEN f.oos_hours > 0  THEN 1 ELSE 0 END) AS lines_with_a_gap,
       SUM(CAST(f.oos_hours AS INT))                     AS oos_hours,
       COUNT(*) * 16                                     AS trading_hours,
       SUM(f.sale_units)                                 AS sale_units
FROM dbo.fact_daily_sales AS f
JOIN dbo.dim_store AS s ON s.store_id = f.store_id
JOIN dbo.dim_date  AS d ON d.dt = f.dt
GROUP BY f.dt, d.week_start, s.city_id, f.store_id;
GO

CREATE VIEW dbo.vw_availability_city_week AS
SELECT week_start, city_id,
       COUNT(DISTINCT store_id)                                         AS stores,
       CAST(1 - 1.0 * SUM(oos_hours) / SUM(trading_hours) AS DECIMAL(6,4)) AS availability,
       SUM(lines_out_all_day)                                           AS line_days_out_all_day,
       CAST(SUM(sale_units) AS DECIMAL(14,1))                           AS sale_units
FROM dbo.vw_availability_store_day
GROUP BY week_start, city_id;
GO

CREATE VIEW dbo.vw_availability_category_week AS
SELECT d.week_start, p.management_group_id, p.first_category_id,
       COUNT(DISTINCT f.product_id)                                               AS products,
       CAST(1 - 1.0 * SUM(CAST(f.oos_hours AS INT)) / (COUNT(*) * 16) AS DECIMAL(6,4)) AS availability,
       CAST(SUM(f.sale_units) AS DECIMAL(14,1))                                   AS sale_units,
       CAST(AVG(CASE WHEN f.promo_flag = 1 THEN 1.0 ELSE 0 END) AS DECIMAL(6,4))  AS share_on_promo
FROM dbo.fact_daily_sales AS f
JOIN dbo.dim_product AS p ON p.product_id = f.product_id
JOIN dbo.dim_date    AS d ON d.dt = f.dt
GROUP BY d.week_start, p.management_group_id, p.first_category_id;
GO

-- Rough estimate of sales lost to gaps. For a day with a partial gap it scales that day's sales by the
-- hours missed; for a day out of stock all day it uses the line's average sales on fully in-stock days.
-- It assumes sales are spread evenly over the trading day, so treat it as an indication, not a forecast.
CREATE VIEW dbo.vw_lost_sales_estimate AS
WITH base AS (
    SELECT store_id, product_id, AVG(sale_units) AS avg_in_stock_units
    FROM dbo.fact_daily_sales WHERE oos_hours = 0
    GROUP BY store_id, product_id
)
SELECT f.dt, f.store_id, f.product_id, f.oos_hours, f.sale_units,
       CAST(CASE WHEN f.oos_hours = 0  THEN 0
                 WHEN f.oos_hours = 16 THEN ISNULL(b.avg_in_stock_units, 0)
                 ELSE f.sale_units * f.oos_hours / (16.0 - f.oos_hours) END AS DECIMAL(9,3)) AS est_lost_units
FROM dbo.fact_daily_sales AS f
LEFT JOIN base AS b ON b.store_id = f.store_id AND b.product_id = f.product_id;
GO

-- The lines to chase first: lowest availability in the latest full week, with the sales at stake.
CREATE VIEW dbo.vw_worst_lines_latest_week AS
WITH wk AS (
    SELECT MAX(week_start) AS week_start FROM dbo.dim_date
    WHERE week_start IN (SELECT week_start FROM dbo.dim_date GROUP BY week_start HAVING COUNT(*) = 7)
)
SELECT d.week_start, s.city_id, l.store_id, l.product_id, p.first_category_id,
       CAST(1 - SUM(CAST(l.oos_hours AS INT)) / (COUNT(*) * 16.0) AS DECIMAL(6,4)) AS availability,
       SUM(CASE WHEN l.oos_hours = 16 THEN 1 ELSE 0 END)                         AS days_out_all_day,
       CAST(SUM(l.sale_units) AS DECIMAL(9,1))                                   AS sale_units,
       CAST(SUM(l.est_lost_units) AS DECIMAL(9,1))                               AS est_lost_units
FROM dbo.vw_lost_sales_estimate AS l
JOIN dbo.dim_date    AS d ON d.dt = l.dt
JOIN wk                   ON wk.week_start = d.week_start
JOIN dbo.dim_store   AS s ON s.store_id = l.store_id
JOIN dbo.dim_product AS p ON p.product_id = l.product_id
GROUP BY d.week_start, s.city_id, l.store_id, l.product_id, p.first_category_id;
GO
