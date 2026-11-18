"""Load FreshRetailNet-50K into SQL Server, then run the data quality checks and build the reporting views.

Usage:  python run_pipeline.py
Set SQLSERVER_INSTANCE if your instance is not localhost\\SQLEXPRESS (Windows authentication is used).
"""
import os
import re
import time
from pathlib import Path

import pandas as pd
import pyodbc

ROOT = Path(__file__).parent
SERVER = os.environ.get("SQLSERVER_INSTANCE", r"localhost\SQLEXPRESS")
DATABASE = "FreshRetail"
PARQUET = ROOT / "data" / "train.parquet"
CHUNK = 100_000

FACT_COLS = {  # parquet column -> table column
    "dt": "dt", "store_id": "store_id", "product_id": "product_id", "sale_amount": "sale_units",
    "stock_hour6_22_cnt": "oos_hours", "discount": "discount_rate", "holiday_flag": "holiday_flag",
    "activity_flag": "promo_flag", "precpt": "rain_mm", "avg_temperature": "avg_temperature",
}
PRODUCT_COLS = ["product_id", "management_group_id", "first_category_id", "second_category_id", "third_category_id"]


def connect(database):
    return pyodbc.connect(
        f"DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={SERVER};DATABASE={database};"
        "Trusted_Connection=yes;TrustServerCertificate=yes", autocommit=True)


def run_sql_file(con, name):
    """Run a .sql file, one batch per GO separator."""
    text = (ROOT / "sql" / name).read_text(encoding="utf-8")
    for batch in re.split(r"^\s*GO\s*$", text, flags=re.M | re.I):
        if batch.strip():
            con.execute(batch)
    print(f"ran sql/{name}")


def insert(con, table, frame):
    cur = con.cursor()
    cur.fast_executemany = True
    sql = f"INSERT INTO dbo.{table} ({', '.join(frame.columns)}) VALUES ({', '.join('?' * len(frame.columns))})"
    for start in range(0, len(frame), CHUNK):
        rows = frame.iloc[start:start + CHUNK]
        cur.executemany(sql, list(rows.itertuples(index=False, name=None)))
        print(f"  {table}: {min(start + CHUNK, len(frame)):,} / {len(frame):,}", end="\r")
    print()


def main():
    t0 = time.time()
    with connect("master") as con:
        con.execute(f"IF DB_ID('{DATABASE}') IS NULL CREATE DATABASE {DATABASE}")
    con = connect(DATABASE)
    run_sql_file(con, "01_schema.sql")

    raw = pd.read_parquet(PARQUET, columns=list(FACT_COLS) + ["city_id"] + PRODUCT_COLS[1:])
    print(f"read {len(raw):,} rows from {PARQUET.name}")

    insert(con, "dim_store", raw[["store_id", "city_id"]].drop_duplicates().astype(int))
    insert(con, "dim_product", raw[PRODUCT_COLS].drop_duplicates().astype(int))

    fact = raw[list(FACT_COLS)].rename(columns=FACT_COLS)
    for col in ("sale_units", "rain_mm"):
        fact[col] = fact[col].round(3)
    fact["discount_rate"] = fact["discount_rate"].round(4)
    fact["avg_temperature"] = fact["avg_temperature"].round(2)
    fact = fact.astype({"store_id": int, "product_id": int, "oos_hours": int,
                        "holiday_flag": int, "promo_flag": int}).astype(object)
    insert(con, "fact_daily_sales", fact)

    run_sql_file(con, "02_keys_and_indexes.sql")
    run_sql_file(con, "03_data_quality_checks.sql")
    run_sql_file(con, "04_views.sql")

    print("\nData quality results:")
    for name, failed, detail in con.execute(
            "SELECT check_name, rows_failed, detail FROM dbo.dq_results ORDER BY rows_failed DESC, check_name"):
        print(f"  {'FAIL' if failed else 'ok  '} {name:<34} {failed:>8,}  {detail}")
    print(f"\ndone in {time.time() - t0:.0f}s")


if __name__ == "__main__":
    main()
