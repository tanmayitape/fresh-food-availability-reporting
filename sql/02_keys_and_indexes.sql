-- Run after the load: keys, foreign keys and the reporting index.

INSERT INTO dbo.dim_date (dt, week_start, day_name, is_weekend)
SELECT d.dt,
       DATEADD(DAY, -((DATEDIFF(DAY, '19000101', d.dt)) % 7), d.dt),   -- 1900-01-01 was a Monday
       DATENAME(WEEKDAY, d.dt),
       CASE WHEN (DATEDIFF(DAY, '19000101', d.dt)) % 7 >= 5 THEN 1 ELSE 0 END
FROM (SELECT DISTINCT dt FROM dbo.fact_daily_sales) AS d;
GO

ALTER TABLE dbo.fact_daily_sales
    ADD CONSTRAINT pk_fact_daily_sales PRIMARY KEY CLUSTERED (dt, store_id, product_id);
ALTER TABLE dbo.fact_daily_sales
    ADD CONSTRAINT fk_fact_store   FOREIGN KEY (store_id)   REFERENCES dbo.dim_store (store_id),
        CONSTRAINT fk_fact_product FOREIGN KEY (product_id) REFERENCES dbo.dim_product (product_id),
        CONSTRAINT fk_fact_date    FOREIGN KEY (dt)         REFERENCES dbo.dim_date (dt);
CREATE INDEX ix_fact_product_dt ON dbo.fact_daily_sales (product_id, dt) INCLUDE (store_id, sale_units, oos_hours);
GO
