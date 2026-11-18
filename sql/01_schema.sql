-- Star schema for fresh food availability reporting (SQL Server).
-- Run by run_pipeline.py against the FreshRetail database.

DROP VIEW IF EXISTS dbo.vw_availability_city_week, dbo.vw_availability_category_week,
                    dbo.vw_availability_store_day, dbo.vw_worst_lines_latest_week,
                    dbo.vw_lost_sales_estimate;
DROP TABLE IF EXISTS dbo.fact_daily_sales, dbo.dim_store, dbo.dim_product, dbo.dim_date, dbo.dq_results;
GO

CREATE TABLE dbo.dim_store (
    store_id INT NOT NULL PRIMARY KEY,
    city_id  INT NOT NULL
);

CREATE TABLE dbo.dim_product (
    product_id          INT NOT NULL PRIMARY KEY,
    management_group_id INT NOT NULL,
    first_category_id   INT NOT NULL,
    second_category_id  INT NOT NULL,
    third_category_id   INT NOT NULL
);

CREATE TABLE dbo.dim_date (
    dt         DATE NOT NULL PRIMARY KEY,
    week_start DATE NOT NULL,          -- Monday of the week
    day_name   VARCHAR(10) NOT NULL,
    is_weekend BIT NOT NULL
);

-- One row per store, product and day. Trading window is 06:00-22:00 (16 hours).
CREATE TABLE dbo.fact_daily_sales (
    dt              DATE         NOT NULL,
    store_id        INT          NOT NULL,
    product_id      INT          NOT NULL,
    sale_units      DECIMAL(9,3) NOT NULL,  -- normalised units, as published
    oos_hours       TINYINT      NOT NULL,  -- out-of-stock hours between 06:00 and 22:00
    discount_rate   DECIMAL(6,4) NOT NULL,  -- 1.0 = full price, 0.9 = 10% off
    holiday_flag    BIT          NOT NULL,
    promo_flag      BIT          NOT NULL,
    rain_mm         DECIMAL(7,3) NOT NULL,
    avg_temperature DECIMAL(5,2) NOT NULL
);

CREATE TABLE dbo.dq_results (
    run_at      DATETIME2    NOT NULL,
    check_name  VARCHAR(80)  NOT NULL,
    rows_failed INT          NOT NULL,
    detail      VARCHAR(200) NOT NULL
);
GO
