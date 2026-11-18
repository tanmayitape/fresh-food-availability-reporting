"""Export the weekly availability MI pack from SQL Server to Excel (one sheet per view, unformatted).

Usage:  python weekly_pack.py
Then open the workbook in Excel and run the FormatWeeklyPack macro (vba/FormatWeeklyPack.bas).
"""
from pathlib import Path

import pandas as pd

from run_pipeline import DATABASE, connect

OUT = Path(__file__).parent / "output"

SHEETS = {
    "City summary": """
        SELECT week_start, city_id, stores, availability, line_days_out_all_day, sale_units
        FROM dbo.vw_availability_city_week WHERE week_start = ? ORDER BY availability""",
    "Category summary": """
        SELECT week_start, management_group_id, first_category_id, products, availability, sale_units, share_on_promo
        FROM dbo.vw_availability_category_week WHERE week_start = ? ORDER BY availability""",
    "Worst 50 lines": """
        SELECT TOP 50 week_start, city_id, store_id, product_id, first_category_id, availability,
               days_out_all_day, sale_units, est_lost_units
        FROM dbo.vw_worst_lines_latest_week WHERE week_start = ?
        ORDER BY est_lost_units DESC""",
    "Data quality": """
        SELECT check_name, rows_failed, detail, run_at FROM dbo.dq_results
        WHERE run_at = (SELECT MAX(run_at) FROM dbo.dq_results)
        ORDER BY rows_failed DESC, check_name""",
}


def main():
    con = connect(DATABASE)
    week = con.execute("SELECT MAX(week_start) FROM dbo.vw_worst_lines_latest_week").fetchval()
    OUT.mkdir(exist_ok=True)
    path = OUT / f"Availability MI pack w-c {week}.xlsx"
    with pd.ExcelWriter(path) as xl:
        for sheet, sql in SHEETS.items():
            cur = con.execute(sql, week) if "?" in sql else con.execute(sql)
            frame = pd.DataFrame.from_records(cur.fetchall(), columns=[c[0] for c in cur.description])
            frame.to_excel(xl, sheet_name=sheet, index=False)
            print(f"{sheet}: {len(frame)} rows")
    print("wrote", path)


if __name__ == "__main__":
    main()
