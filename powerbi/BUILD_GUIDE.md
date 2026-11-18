# Power BI report: build guide

Build this yourself in Power BI Desktop (about 2 hours). Save it as `powerbi/Availability.pbix` and add
screenshots of each page to `powerbi/screenshots/` so the report is visible on GitHub.

## 1. Connect

Get Data > SQL Server. Server: your instance (for example `localhost\SQLEXPRESS`). Database: `FreshRetail`.
Mode: **Import**. Select these tables:

- `fact_daily_sales`
- `dim_store`
- `dim_product`
- `dim_date`
- `dq_results`

## 2. Model (star schema)

In Model view, check these one-to-many relationships (single direction, dimension filters fact):

| From (one) | To (many) |
|---|---|
| `dim_date[dt]` | `fact_daily_sales[dt]` |
| `dim_store[store_id]` | `fact_daily_sales[store_id]` |
| `dim_product[product_id]` | `fact_daily_sales[product_id]` |

Mark `dim_date` as the date table (Table tools > Mark as date table > `dt`). Hide the key columns on the
fact table. Leave `dq_results` unrelated.

## 3. Measures

Create a table called `Measures` (Enter data, one blank column) and add:

```DAX
Trading Hours = COUNTROWS ( fact_daily_sales ) * 16

OOS Hours = SUM ( fact_daily_sales[oos_hours] )

Availability % = 1 - DIVIDE ( [OOS Hours], [Trading Hours] )

Sale Units = SUM ( fact_daily_sales[sale_units] )

Lines Out All Day = CALCULATE ( COUNTROWS ( fact_daily_sales ), fact_daily_sales[oos_hours] = 16 )

Lines With A Gap = CALCULATE ( COUNTROWS ( fact_daily_sales ), fact_daily_sales[oos_hours] > 0 )

Gap Rate % = DIVIDE ( [Lines With A Gap], COUNTROWS ( fact_daily_sales ) )

Availability % Prev Week =
CALCULATE ( [Availability %], DATEADD ( dim_date[dt], -7, DAY ) )

Availability Change (pts) = [Availability %] - [Availability % Prev Week]

Availability Target = 0.8

Stores Below Target =
COUNTROWS ( FILTER ( VALUES ( dim_store[store_id] ), [Availability %] < [Availability Target] ) )

Promo Availability % = CALCULATE ( [Availability %], fact_daily_sales[promo_flag] = TRUE () )

DQ Rows Failed =
CALCULATE ( SUM ( dq_results[rows_failed] ), dq_results[run_at] = MAX ( dq_results[run_at] ) )
```

Format the `%` measures as percentage with one decimal.

## 4. Pages

**Page 1 – Overview**
- Cards: `Availability %`, `Availability Change (pts)`, `Lines Out All Day`, `Stores Below Target`.
- Line chart: `Availability %` by `dim_date[dt]`, with a constant line at 80%.
- Bar chart: `Availability %` by `dim_store[city_id]`, sorted lowest first.
- Slicers: `dim_date[week_start]`, `dim_product[management_group_id]`.

**Page 2 – Category**
- Matrix: rows `management_group_id` > `first_category_id`; values `Availability %`, `Gap Rate %`,
  `Sale Units`, `Promo Availability %`. Conditional formatting on `Availability %` (red below 80%).
- Scatter: `Sale Units` (X) against `Availability %` (Y) by `first_category_id`. Big sellers with low
  availability sit bottom right.

**Page 3 – Store drill-down**
- Table: `store_id`, `city_id`, `Availability %`, `Lines Out All Day`, `Sale Units`; Top N filter on the
  20 lowest `Availability %`.
- Column chart: `OOS Hours` by `dim_date[day_name]` (sort the column by weekday order).
- Drill-through from Page 1's city bar to this page on `city_id`.

**Page 4 – Data quality**
- Table from `dq_results`: `check_name`, `rows_failed`, `detail`, filtered to the latest `run_at`.
- Card: `DQ Rows Failed`.

## 5. Questions to be able to answer about it

- Why 16 trading hours? (`oos_hours` counts 06:00–22:00 only.)
- Why is availability weighted by hours and not a simple count of lines with a gap?
- Why are sales shown as "units" and never as money? (The publisher normalised the quantities.)
- What would you do about the rows the data quality page flags?
