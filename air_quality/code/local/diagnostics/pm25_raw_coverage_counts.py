"""
pm25_raw_coverage_counts.py
Workstream A. Saves raw coverage counts from PM2.5.xlsx that the PM2.5 gap
reports cite (counts only, no values):
  - hours with a value by station and month, 2024-10 to the end of the file,
    beside the calendar hours and the rows present in the file;
  - hours with a value by station and day, 2025-03-01 to 2025-03-31;
  - every run of 30 or more days with no value that overlaps 2025-01-01 to the
    end of the file: the last hour with a value before it, the first after,
    and its length in empty hours and days;
  - the largest number of decimals by station over the whole file, and the
    count of values by number of decimals (fewest decimals that reproduce the
    stored number, so noise from storing a decimal as binary does not count;
    noise from arithmetic in Excel would).

"Has a value" follows the pipeline: a numeric cell that is not negative
(01_read_and_merge.R sets negatives to NA; zeros are kept). Booleans do not
count. Duplicate hours stop the script (the pipeline would average them).

Run from air_quality/:
  python3 code/local/diagnostics/pm25_raw_coverage_counts.py > ../logs/aq_pm25_raw_coverage_counts.log 2>&1
Output: output/local/diagnostics/pm25_gap/pm25_raw_{month,day_mar2025,long_runs,decimals}.csv
"""
import os
import datetime as dt
from decimal import Decimal

import pandas as pd
import openpyxl

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))   # air_quality/
REF = os.path.join(ROOT, "data", "raw", "remmaq", "PM2.5.xlsx")
OUT = os.path.join(ROOT, "output", "local", "diagnostics", "pm25_gap")
os.makedirs(OUT, exist_ok=True)

wb = openpyxl.load_workbook(REF, read_only=True, data_only=True)
ws = wb.worksheets[0]
assert ws.title == "LIMPIO", ws.title
rows = ws.iter_rows(values_only=True)
hdr = [h.strip() if isinstance(h, str) else h for h in next(rows)]
assert str(hdr[0]).lower() == "fecha", hdr[0]
stations = hdr[1:]


def ndec(v):
    return max(0, -Decimal(repr(float(v))).normalize().as_tuple().exponent)


ts, has = [], {s: [] for s in stations}
dec_counts = {s: {} for s in stations}
n_skipped = n_negative = n_text = 0
for r in rows:
    if not isinstance(r[0], dt.datetime):
        n_skipped += 1
        continue
    ts.append(r[0])
    for i, s in enumerate(stations, start=1):
        v = r[i]
        num = isinstance(v, (int, float)) and not isinstance(v, bool)
        if num and v < 0:
            n_negative += 1
        if isinstance(v, str) and v.strip():
            n_text += 1
        ok = num and v >= 0
        has[s].append(ok)
        if ok:
            k = ndec(v)
            dec_counts[s][k] = dec_counts[s].get(k, 0) + 1
wb.close()
print(f"Rows skipped (first cell not a date): {n_skipped}; negative values: {n_negative}; "
      f"non-numeric text cells: {n_text}; data rows: {len(ts)}")

d = pd.DataFrame(has, index=pd.to_datetime(ts).round("h"))
assert not d.index.duplicated().any()
d = d.sort_index()
present = pd.Series(True, index=d.index)
full = pd.date_range(d.index.min(), d.index.max(), freq="h")
d = d.reindex(full, fill_value=False)
present = present.reindex(full, fill_value=False)

x = d.loc["2024-10-01":]
per = x.index.to_period("M")
m = x.groupby(per).sum()
m.insert(0, "rows_in_file", present.loc["2024-10-01":].groupby(per).sum())
m.insert(0, "calendar_hours", x.groupby(per).size())
m.index = m.index.astype(str)
m.to_csv(os.path.join(OUT, "pm25_raw_month.csv"), index_label="month")

day = d.loc["2025-03-01":"2025-03-31 23:00"]
dd = day.groupby(day.index.date).sum()
dd.to_csv(os.path.join(OUT, "pm25_raw_day_mar2025.csv"), index_label="date")

runs = []
start = pd.Timestamp("2025-01-01")
end_file = d.index[-1]
for s in stations:
    vals = d.index[d[s]]
    before = vals[vals < start]
    prev = before.max() if len(before) else None
    for t in list(vals[vals >= start]) + [None]:
        gap_start = prev + pd.Timedelta(hours=1) if prev is not None else d.index[0]
        gap_end = t - pd.Timedelta(hours=1) if t is not None else end_file
        empty_h = int((gap_end - gap_start) / pd.Timedelta(hours=1)) + 1 if gap_end >= gap_start else 0
        if empty_h >= 30 * 24 and gap_end >= start:
            runs.append(dict(station=s,
                             last_value_before=str(prev) if prev is not None else "none in file",
                             first_value_after=str(t) if t is not None else "none to end of file",
                             empty_hours=empty_h, empty_days=round(empty_h / 24, 1)))
        prev = t
pd.DataFrame(runs).to_csv(os.path.join(OUT, "pm25_raw_long_runs.csv"), index=False)

dec_rows = []
for s in stations:
    for k in sorted(dec_counts[s]):
        dec_rows.append(dict(station=s, decimals=k, values=dec_counts[s][k]))
dec = pd.DataFrame(dec_rows)
dec.to_csv(os.path.join(OUT, "pm25_raw_decimals.csv"), index=False)

print(m.to_string(), "\n")
print(dd.to_string(), "\n")
print(pd.DataFrame(runs).to_string(index=False), "\n")
print(dec.groupby("station").decimals.max().to_string())
