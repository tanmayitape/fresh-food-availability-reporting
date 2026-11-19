# Power BI report: build guide

The finished report is `powerbi/fresh-food-availability-reporting.pbix` (about 10 MB). Screenshots of each
page go in `powerbi/screenshots/` so the report is visible on GitHub. Pages 1 and 2 are built; pages 3 and 4
are planned.

## 1. Connect

Apply the theme first: View > Themes > Browse for themes > `powerbi/theme.json`.

Get Data > SQL Server. Server: your instance (for example `localhost\SQLEXPRESS`). Database: `FreshRetail`.
Mode: **Import**. Select these tables, then click **Transform Data** rather than Load:

- `fact_daily_sales`
- `dim_store`
- `dim_product`
- `dim_date`
- `dq_results`

In Power Query, keep only `dt`, `store_id`, `product_id`, `sale_units`, `oos_hours` and `promo_flag` in
`fact_daily_sales`. Remove `rain_mm`, `avg_temperature`, `holiday_flag`, `discount_rate` and the
relationship columns Power Query adds from the foreign keys (`dim_date`, `dim_store`, `dim_product`, shown
as "Value"). Remove the matching `fact_daily_sales` column from each dimension. Set `oos_hours` to Whole
Number. This keeps the file near 10 MB, well under GitHub's 100 MB limit.

## 2. Model (star schema)

In Model view, check these one-to-many relationships (single direction, dimension filters fact):

| From (one) | To (many) |
|---|---|
| `dim_date[dt]` | `fact_daily_sales[dt]` |
| `dim_store[store_id]` | `fact_daily_sales[store_id]` |
| `dim_product[product_id]` | `fact_daily_sales[product_id]` |

Mark `dim_date` as the date table (Table tools > Mark as date table > `dt`). Hide the key columns on the
fact table. Leave `dq_results` unrelated.

Add a weekday sort column to `dim_date`, then sort `day_name` by it (Column tools > Sort by column):

```DAX
Day Num = WEEKDAY ( dim_date[dt], 2 )
```

## 3. Measures

Create an empty table called `_Measures` (Home > Enter data > Load). Do not call it `Measures`: the engine
reserves that name and queries cannot find the table.

The quickest way to add every measure is `powerbi/measures.dax`: open DAX query view, paste the file, run it
(F5) and click **Update model with changes**. Its check query should return Availability % 0.8012, Lines Out
All Day 181,791, Stores Below Target 433 and DQ Rows Failed 49,819, which match SQL Server. The measures are:

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

Change vs previous week = [Availability %] - [Availability % Prev Week]

Availability Target = 0.8

Stores Below Target =
COUNTROWS ( FILTER ( VALUES ( dim_store[store_id] ), [Availability %] < [Availability Target] ) )

Promo Availability % = CALCULATE ( [Availability %], fact_daily_sales[promo_flag] = TRUE () )

DQ Rows Failed =
CALCULATE ( SUM ( dq_results[rows_failed] ), dq_results[run_at] = MAX ( dq_results[run_at] ) )
```

Format the `%` measures as percentage with one decimal, and the count measures as whole numbers with a
thousands separator. Model view is the easiest place: Ctrl+click several measures and set the format once.

## 4. Pages

**Page 1 – Overview** (built: `screenshots/01-overview.png`)
- Cards: `Availability %`, `Change vs previous week` (custom format `+0.0%;-0.0%;0.0%`),
  `Stores Below Target`, `Lines Out All Day`.
- Line chart: `Availability %` by `dim_date[dt]` (the date itself, not the date hierarchy), with a dashed
  constant line at 80%. Edit interactions so the week slicer does not filter it: it keeps all 90 days.
- Bar chart: `Availability %` by `dim_store[city_id]`, Y axis set to Categorical, sorted lowest first, with
  data labels. The axis starts at zero.
- Slicers (dropdown): `dim_date[week_start]` (single select), `dim_product[management_group_id]`.
- The screenshot uses the week commencing 17 June 2024, the last full week.

**Page 2 – Category** (built: `screenshots/02-category.png`)
- Slicers: the Page 1 slicers, synced to this page (View > Sync slicers), so a week picked on one page
  applies on both.
- Matrix: rows `management_group_id` > `first_category_id`, expanded; values `Availability %`, `Gap Rate %`,
  `Sale Units`, `Promo Availability %` (renamed in the visual), sorted by availability, lowest first.
  Background colour on `Availability %`: Cell elements > fx > Field value > `Availability Colour`, applied to
  values and totals.
- Scatter: `Sale Units` (X, logarithmic scale) against `Availability %` (Y) by `first_category_id`, with a
  dashed constant line at 80% and dot colour from `Availability Colour`. Big sellers with low availability
  sit bottom right.
- `Availability Colour` returns red below `[Availability Target]`, amber within 2 points above it and green
  from there up. Use Field value, not Gradient: a gradient rescales to each week's range, so its colours
  would not mean the same thing from week to week.

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
