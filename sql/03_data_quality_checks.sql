-- Data quality checks. Each check writes one row to dbo.dq_results; rows_failed = 0 means it passed.
-- Run by run_pipeline.py after every load, before any report is produced.

DECLARE @now DATETIME2 = SYSDATETIME();

INSERT INTO dbo.dq_results (run_at, check_name, rows_failed, detail)
SELECT @now, 'duplicate_store_product_day', COUNT(*), 'More than one row for a store, product and day'
FROM (SELECT 1 AS x FROM dbo.fact_daily_sales GROUP BY dt, store_id, product_id HAVING COUNT(*) > 1) AS d;

INSERT INTO dbo.dq_results
SELECT @now, 'negative_sales', COUNT(*), 'sale_units below zero'
FROM dbo.fact_daily_sales WHERE sale_units < 0;

INSERT INTO dbo.dq_results
SELECT @now, 'oos_hours_out_of_range', COUNT(*), 'oos_hours outside 0-16 (trading window is 16 hours)'
FROM dbo.fact_daily_sales WHERE oos_hours > 16;

INSERT INTO dbo.dq_results
SELECT @now, 'discount_zero_or_negative', COUNT(*), 'discount_rate <= 0 would mean the product was free'
FROM dbo.fact_daily_sales WHERE discount_rate <= 0;

INSERT INTO dbo.dq_results
SELECT @now, 'discount_above_full_price', COUNT(*), 'discount_rate > 1 means a price above full price'
FROM dbo.fact_daily_sales WHERE discount_rate > 1;

INSERT INTO dbo.dq_results
SELECT @now, 'sales_on_full_day_out_of_stock', COUNT(*), 'Units sold on a day flagged out of stock for all 16 hours'
FROM dbo.fact_daily_sales WHERE oos_hours = 16 AND sale_units > 0;

INSERT INTO dbo.dq_results
SELECT @now, 'incomplete_series', COUNT(*), 'Store-product lines without a row for every date in the data'
FROM (SELECT 1 AS x FROM dbo.fact_daily_sales GROUP BY store_id, product_id
      HAVING COUNT(*) <> (SELECT COUNT(DISTINCT dt) FROM dbo.fact_daily_sales)) AS s;

INSERT INTO dbo.dq_results
SELECT @now, 'missing_dates', DATEDIFF(DAY, MIN(dt), MAX(dt)) + 1 - COUNT(DISTINCT dt), 'Calendar days with no data between first and last date'
FROM dbo.fact_daily_sales;

INSERT INTO dbo.dq_results
SELECT @now, 'store_without_sales', COUNT(*), 'Stores in dim_store with no fact rows'
FROM dbo.dim_store AS s WHERE NOT EXISTS (SELECT 1 FROM dbo.fact_daily_sales AS f WHERE f.store_id = s.store_id);
GO
