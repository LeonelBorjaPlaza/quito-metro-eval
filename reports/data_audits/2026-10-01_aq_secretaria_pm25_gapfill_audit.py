"""Audit of the Secretaria de Ambiente PM2.5 gap-fill file (workstream A).

Reads two raw workbooks read-only and writes aggregate CSVs next to this script:
  - gap-fill: <store>/air_quality/raw/2026-09-07_secretaria_ambiente_pm25_gapfill/
              DATOSFALTANTESPM2.5_ANALISISMETRO.xlsx (sheet Hoja1)
  - reference: air_quality/data/raw/remmaq/PM2.5.xlsx (sheet LIMPIO), the file the
              pipeline reads (01_read_and_merge.R)

Only aggregates are printed or saved (counts, shares, summary statistics, means by
hour of day). No hourly record is written. No before-and-after-December-2023
contrast is computed. Nothing is merged into any panel.

Workbooks are parsed straight from the sheet XML so that raw stored strings
(decimal precision), cell types, styles and Excel date serials are seen exactly as
stored. Both files use the 1900 date system (no date1904 flag).

Lag convention used in the alignment table: at lag L, the gap-fill value stamped t
is paired with the PM2.5.xlsx value stamped t + L. If the gap-fill file stamps an
hour by its end and PM2.5.xlsx by its beginning, the same measurement is stamped
one hour earlier in PM2.5.xlsx, and the best match appears at L = -1.

Run from the worktree root:
  python3 reports/data_audits/2026-10-01_aq_secretaria_pm25_gapfill_audit.py
"""

import collections
import datetime as dt
import hashlib
import os
import re
import zipfile
import xml.etree.ElementTree as ET

import numpy as np
import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
# Absolute path into the data store: the gap-fill file is deliberately not
# linked into the repository (air_quality/CLAUDE.md).
STORE = "/home/leonelb/data/quito-metro-eval"
GF_DIR = os.path.join(STORE, "air_quality/raw/2026-09-07_secretaria_ambiente_pm25_gapfill")
GF = os.path.join(GF_DIR, "DATOSFALTANTESPM2.5_ANALISISMETRO.xlsx")
REF = os.path.join(ROOT, "air_quality/data/raw/remmaq/PM2.5.xlsx")
PREFIX = os.path.join(HERE, "2026-10-01_aq_secretaria_pm25_gapfill_")

NS = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
STATIONS = ["BELISARIO", "CARAPUNGO", "CENTRO", "COTOCOLLAO", "EL CAMAL",
            "GUAMANI", "LOS CHILLOS", "SAN ANTONIO", "TUMBACO"]
# The eight stations the pipeline keeps (01_read_and_merge.R, stations_keep).
PIPELINE_STATIONS = [s for s in STATIONS if s != "EL CAMAL"]

W_GF = (pd.Timestamp("2025-01-13 00:00"), pd.Timestamp("2025-01-25 23:00"))
W_BEFORE = (pd.Timestamp("2024-12-30 00:00"), pd.Timestamp("2025-01-12 23:00"))
W_AFTER = (pd.Timestamp("2025-01-26 00:00"), pd.Timestamp("2025-02-08 23:00"))
# Weeks of the frozen weekly-panel gap: week starting 2025-01-13 to week starting
# 2025-02-24 (ends 2025-03-02), with one week either side, for coverage only.
W_GAPWEEKS = (pd.Timestamp("2025-01-06 00:00"), pd.Timestamp("2025-03-09 23:00"))
LAGS_ASKED = [-2, -1, 0, 1, 2]
LAGS_ALL = list(range(-6, 7))
EXCEL_EPOCH = dt.datetime(1899, 12, 30)


def out(name, df):
    path = PREFIX + name + ".csv"
    df.to_csv(path, index=False)
    print(f"saved {os.path.relpath(path, ROOT)} ({len(df)} rows)")


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def col_of(ref):
    return re.match(r"[A-Z]+", ref).group()


def decimals(s):
    """Smallest number of decimals (0-6) that reproduces the stored value."""
    x = float(s)
    for d in range(7):
        if abs(x - round(x, d)) < 1e-9:
            return d
    return 7  # 7 means more than 6 decimals


def read_book(path):
    """Return (meta, frame). frame has ts plus, per station, value and raw string."""
    z = zipfile.ZipFile(path)
    wb = ET.fromstring(z.read("xl/workbook.xml"))
    sheets = [s.get("name") for s in wb.iter(NS + "sheet")]
    date1904 = any(p.get("date1904") in ("1", "true") for p in wb.iter(NS + "workbookPr"))
    sst = ["".join(t.text or "" for t in si.iter(NS + "t"))
           for si in ET.fromstring(z.read("xl/sharedStrings.xml")).iter(NS + "si")]
    styles = ET.fromstring(z.read("xl/styles.xml"))
    numfmts = {n.get("numFmtId"): n.get("formatCode") for n in styles.iter(NS + "numFmt")}
    cellxfs = styles.find(NS + "cellXfs")
    xf_numfmt = [x.get("numFmtId") for x in cellxfs.findall(NS + "xf")]
    names = z.namelist()
    sheet_xml_head = z.read("xl/worksheets/sheet1.xml")[:3000].decode("utf8", "replace")
    dim = re.search(r'<dimension ref="([^"]+)"', sheet_xml_head).group(1)
    tail = z.read("xl/worksheets/sheet1.xml")[-3000:].decode("utf8", "replace")
    extras = {k: (k in sheet_xml_head + tail) for k in
              ["conditionalFormatting", "dataValidations", "legacyDrawing", "mergeCells"]}
    extras["comments_part"] = any("comment" in n.lower() for n in names)
    extras["fills_beyond_default"] = len(list(styles.iter(NS + "fill"))) > 2

    header, rows, celltypes = {}, [], collections.Counter()
    with z.open("xl/worksheets/sheet1.xml") as fh:
        for _, el in ET.iterparse(fh):
            if el.tag != NS + "row":
                continue
            rnum = int(el.get("r"))
            cells = {}
            for c in el.iter(NS + "c"):
                v = c.find(NS + "v")
                cells[col_of(c.get("r"))] = (c.get("t", "n"), c.get("s", "0"),
                                             v.text if v is not None else None)
            if rnum == 1:
                for k, (t, s, v) in cells.items():
                    header[k] = sst[int(v)] if (t == "s" and v is not None) else None
            else:
                for k, (t, s, v) in cells.items():
                    celltypes[(k, t, s, v is None)] += 1
                rows.append(cells)
            el.clear()

    cols = sorted(header)
    name_of = {k: header[k] for k in cols}
    recs = []
    ts_kind = collections.Counter()
    for cells in rows:
        a = cells.get("A")
        rec = {"ts": pd.NaT}
        if a and a[2] is not None and a[0] == "n":
            x = float(a[2])
            secs = round((x - int(x)) * 86400, 3)
            rem = secs % 3600
            if abs(rem) < 0.01 or abs(rem - 3600) < 0.01:
                ts_kind["exact hour"] += 1
            elif abs(rem - 3599.999) < 0.002:
                ts_kind["XX:59:59.999"] += 1
            else:
                ts_kind["other fraction"] += 1
            t = EXCEL_EPOCH + dt.timedelta(days=x)
            rec["ts"] = pd.Timestamp(t).round("h")
        elif a and a[0] in ("s", "str", "inlineStr"):
            ts_kind["text"] += 1
        else:
            ts_kind["missing"] += 1
        for k in cols[1:]:
            nm = name_of[k]
            if nm is None:
                continue
            c = cells.get(k)
            if c is None or c[2] is None:
                rec[nm] = np.nan
                rec[nm + "__raw"] = None
                rec[nm + "__type"] = "absent"
            elif c[0] == "n":
                rec[nm] = float(c[2])
                rec[nm + "__raw"] = c[2]
                rec[nm + "__type"] = "number"
            else:
                rec[nm] = np.nan
                rec[nm + "__raw"] = sst[int(c[2])] if c[0] == "s" else c[2]
                rec[nm + "__type"] = "text_" + c[0]
        recs.append(rec)
    df = pd.DataFrame(recs)
    meta = dict(sheets=sheets, date1904=date1904, dim=dim, header=name_of,
                numfmts=numfmts, xf_numfmt=xf_numfmt, celltypes=celltypes,
                ts_kind=ts_kind, extras=extras, n_rows=len(rows), parts=names)
    return meta, df


def summarize_values(df, label, stations):
    rows = []
    for s in stations:
        if s not in df:
            raise KeyError(f"{label}: station column {s} not found")
        x = df[s].dropna()
        raw = df.loc[df[s].notna(), s + "__raw"]
        dec = raw.map(decimals) if len(raw) else pd.Series(dtype=int)
        runs = flat_runs(df.set_index("ts")[s])
        rows.append(dict(
            window=label, station=s, hours_in_window=len(df), n_values=len(x),
            n_missing=len(df) - len(x),
            n_text_cells=int(df[s + "__type"].str.startswith("text").sum()),
            min=x.min() if len(x) else np.nan,
            p01=x.quantile(0.01) if len(x) else np.nan,
            p05=x.quantile(0.05) if len(x) else np.nan,
            median=x.median() if len(x) else np.nan,
            mean=x.mean() if len(x) else np.nan,
            p95=x.quantile(0.95) if len(x) else np.nan,
            p99=x.quantile(0.99) if len(x) else np.nan,
            max=x.max() if len(x) else np.nan,
            n_negative=int((x < 0).sum()), n_zero=int((x == 0).sum()),
            n_ge_200=int((x >= 200).sum()), n_ge_500=int((x >= 500).sum()),
            n_sentinel_like=int(x.isin([-9999, -999, -99, -9, 999, 9999, 99999]).sum()),
            share_integer=float((x == x.round()).mean()) if len(x) else np.nan,
            modal_decimals=int(dec.mode().iloc[0]) if len(dec) else np.nan,
            max_decimals=int(dec.max()) if len(dec) else np.nan,
            n_flat_runs_ge3=runs[0], longest_flat_run=runs[1],
        ))
    return pd.DataFrame(rows)


def flat_runs(series):
    """Runs of 3+ consecutive hours with an identical non-missing value."""
    s = series.sort_index()
    s = s.reindex(pd.date_range(s.index.min(), s.index.max(), freq="h"))
    n_runs, longest, cur, prev = 0, 0, 0, None
    for v in s.values:
        if not np.isnan(v) and prev is not None and not np.isnan(prev) and v == prev:
            cur += 1
        else:
            if cur >= 3:
                n_runs += 1
            cur = 1 if not np.isnan(v) else 0
        longest = max(longest, cur)
        prev = v
    if cur >= 3:
        n_runs += 1
    return n_runs, longest


def runs_of_missing(ts_index, present):
    """Start, end and length of each run of missing hours."""
    out_rows, start, prev = [], None, None
    for t, p in zip(ts_index, present):
        if not p and start is None:
            start = t
        if p and start is not None:
            out_rows.append((start, prev))
            start = None
        prev = t
    if start is not None:
        out_rows.append((start, prev))
    return out_rows


def window(df, w):
    return df[(df.ts >= w[0]) & (df.ts <= w[1])].copy()


def main():
    # ---------------------------------------------------------------- inventory
    print("== Inventory")
    sums = {}
    with open(os.path.join(GF_DIR, "SHA256SUMS")) as fh:
        for line in fh:
            h, p = line.rstrip("\n").split("  ", 1)
            sums[os.path.normpath(p)] = h
    manifest = {}
    with open(os.path.join(STORE, "MANIFEST.sha256")) as fh:
        for line in fh:
            h, p = line.rstrip("\n").split("  ", 1)
            manifest[p] = h
    inv = []
    for rel, h_exp in sums.items():
        p = os.path.join(GF_DIR, rel)
        h = sha256(p)
        inv.append(dict(file=rel, folder="gapfill delivery", bytes=os.path.getsize(p),
                        sha256=h, expected_from="SHA256SUMS", expected=h_exp,
                        match=h == h_exp))
    ref_real = os.path.realpath(REF)
    h = sha256(ref_real)
    key = os.path.relpath(ref_real, STORE)
    inv.append(dict(file="PM2.5.xlsx", folder="air_quality/data/raw/remmaq",
                    bytes=os.path.getsize(ref_real), sha256=h,
                    expected_from="MANIFEST.sha256", expected=manifest.get(key),
                    match=h == manifest.get(key)))
    inv = pd.DataFrame(inv)
    print(inv[["file", "bytes", "match"]].to_string(index=False))

    gm, g = read_book(GF)
    rm, r = read_book(REF)
    # Fail loudly if a station header does not match exactly in either file
    for lab, d in (("gapfill", g), ("PM2.5.xlsx", r)):
        missing = set(STATIONS) - set(d.columns)
        assert not missing, f"{lab}: station columns not found: {sorted(missing)}"
    struct = []
    for lab, m, d in (("gapfill", gm, g), ("PM2.5.xlsx", rm, r)):
        fmt_a = sorted({(s, m["xf_numfmt"][int(s)]) for (k, t, s, _), n in m["celltypes"].items() if k == "A"})
        struct.append(dict(
            file=lab, sheets=";".join(m["sheets"]), date1904=m["date1904"], dimension=m["dim"],
            data_rows=m["n_rows"], header_cells=len(m["header"]),
            header=";".join(str(v) for v in m["header"].values()),
            empty_header_cells=sum(v is None for v in m["header"].values()),
            units_row=False if d.ts.notna().all() else "check",
            first_ts=str(d.ts.min()), last_ts=str(d.ts.max()),
            distinct_ts=d.ts.nunique(), duplicate_ts=int(d.ts.duplicated().sum()),
            expected_hours_in_span=int((d.ts.max() - d.ts.min()) / pd.Timedelta("1h")) + 1,
            ts_storage=";".join(f"{k}={v}" for k, v in m["ts_kind"].items()),
            ts_number_format=";".join(f"style{s}:numFmt{f}={m['numfmts'].get(f, 'builtin')}" for s, f in fmt_a),
            station_cell_types=";".join(sorted({f"{t}" for (k, t, s, _), n in m["celltypes"].items() if k != "A"})),
            station_styles=";".join(sorted({f"style{s}:numFmt{m['xf_numfmt'][int(s)]}" for (k, t, s, _), n in m["celltypes"].items() if k != "A"})),
            comments_part=m["extras"]["comments_part"],
            conditional_formatting=m["extras"]["conditionalFormatting"],
            data_validation=m["extras"]["dataValidations"],
            colour_fills=m["extras"]["fills_beyond_default"],
        ))
    struct = pd.DataFrame(struct)
    out("inventory", pd.concat([inv, struct], axis=0, ignore_index=True))
    print(struct.T.to_string())

    # ----------------------------------------------------- reference timeline
    print("\n== PM2.5.xlsx timeline gaps (missing timestamp rows)")
    rts = r.ts.dropna().sort_values().reset_index(drop=True)
    step = rts.diff()
    gaps = pd.DataFrame({"gap_after": rts.shift(1)[step > pd.Timedelta("1h")],
                         "resumes_at": rts[step > pd.Timedelta("1h")]})
    gaps["missing_hours"] = ((gaps.resumes_at - gaps.gap_after) / pd.Timedelta("1h") - 1).astype(int)
    gaps["first_missing"] = gaps.gap_after + pd.Timedelta("1h")
    gaps["last_missing"] = gaps.resumes_at - pd.Timedelta("1h")
    gaps = gaps[["first_missing", "last_missing", "missing_hours"]]
    out("pm25xlsx_timeline_gaps", gaps)
    print(f"{len(gaps)} gaps in the row sequence; total missing hours {gaps.missing_hours.sum()}")
    # Rows that exist but where all nine stations are empty, in the gap weeks window
    rw = window(r, W_GAPWEEKS)
    allempty = rw[STATIONS].isna().all(axis=1)
    print(f"Gap-weeks window {W_GAPWEEKS[0].date()} to {W_GAPWEEKS[1].date()}: "
          f"{len(rw)} timestamp rows, {int(allempty.sum())} with all stations empty")

    # ---------------------------------------------------------------- coverage
    print("\n== Coverage")
    gw = window(g, W_GF)
    rgw = window(r, W_GF)
    spine = pd.DataFrame({"ts": pd.date_range(W_GF[0], W_GF[1], freq="h")})
    gsp = spine.merge(gw, on="ts", how="left")
    rsp = spine.merge(rgw, on="ts", how="left")
    cov_day, cov_hour, joint, miss = [], [], [], []
    for s in STATIONS:
        gp = gsp[s].notna()
        rp = rsp[s].notna()
        for day, grp in gsp.groupby(gsp.ts.dt.date):
            cov_day.append(dict(file="gapfill", station=s, date=str(day), hours_with_value=int(grp[s].notna().sum()), hours=len(grp)))
        for day, grp in rsp.groupby(rsp.ts.dt.date):
            cov_day.append(dict(file="PM2.5.xlsx", station=s, date=str(day), hours_with_value=int(grp[s].notna().sum()), hours=len(grp)))
        for hr, grp in gsp.groupby(gsp.ts.dt.hour):
            cov_hour.append(dict(file="gapfill", station=s, hour_of_day=hr, days_with_value=int(grp[s].notna().sum()), days=len(grp)))
        for hr, grp in rsp.groupby(rsp.ts.dt.hour):
            cov_hour.append(dict(file="PM2.5.xlsx", station=s, hour_of_day=hr, days_with_value=int(grp[s].notna().sum()), days=len(grp)))
        joint.append(dict(station=s, in_pipeline=s in PIPELINE_STATIONS, hours=len(spine),
                          gapfill_hours=int(gp.sum()), gapfill_share=round(gp.mean(), 3),
                          pm25xlsx_hours=int(rp.sum()), pm25xlsx_share=round(rp.mean(), 3),
                          both=int((gp & rp).sum()), gapfill_only=int((gp & ~rp).sum()),
                          pm25xlsx_only=int((~gp & rp).sum()), neither=int((~gp & ~rp).sum())))
        for a, b in runs_of_missing(gsp.ts, gp):
            miss.append(dict(file="gapfill", station=s, first_missing=str(a), last_missing=str(b),
                             hours=int((b - a) / pd.Timedelta("1h")) + 1))
    cov_day, cov_hour = pd.DataFrame(cov_day), pd.DataFrame(cov_hour)
    joint, miss = pd.DataFrame(joint), pd.DataFrame(miss)
    out("coverage_station_day", cov_day)
    out("coverage_station_hour", cov_hour)
    out("coverage_joint", joint)
    out("gapfill_missing_runs", miss)
    print(joint.to_string(index=False))
    print(miss.groupby("station").agg(runs=("hours", "size"), hours=("hours", "sum"), longest=("hours", "max")).to_string())
    print(cov_day.pivot_table(index=["file", "station"], columns="date", values="hours_with_value").to_string())


    # Weekday peak hours (7, 8, 9, 17, 18, 19; 02_build_weekly_panels.R:59-61), the
    # hours that enter the weekly outcome, by station and ISO week, both files.
    peak = []
    for f, d in (("gapfill", gsp), ("PM2.5.xlsx", rsp)):
        dd = d[(d.ts.dt.weekday < 5) & d.ts.dt.hour.isin([7, 8, 9, 17, 18, 19])].copy()
        dd["week_start"] = (dd.ts - pd.to_timedelta(dd.ts.dt.weekday, unit="D")).dt.normalize()
        for s in STATIONS:
            for w0, grp in dd.groupby("week_start"):
                peak.append(dict(file=f, station=s, week_start=str(w0.date()),
                                 weekday_peak_hours=len(grp), with_value=int(grp[s].notna().sum())))
    peak = pd.DataFrame(peak)
    out("weekday_peak_hour_coverage", peak)
    print(peak.pivot_table(index=["file", "station"], columns="week_start", values="with_value").to_string())

    # Weekly coverage of PM2.5.xlsx around the frozen-panel gap (coverage only)
    wk = window(r, W_GAPWEEKS)
    wsp = pd.DataFrame({"ts": pd.date_range(W_GAPWEEKS[0], W_GAPWEEKS[1], freq="h")}).merge(wk, on="ts", how="left")
    wsp["week_start"] = (wsp.ts - pd.to_timedelta(wsp.ts.dt.weekday, unit="D")).dt.normalize()
    wcov = []
    for s in STATIONS:
        for w0, grp in wsp.groupby("week_start"):
            wcov.append(dict(station=s, week_start=str(w0.date()), hours=len(grp),
                             timestamp_rows_in_file=int(grp["BELISARIO__type"].notna().sum()) if "BELISARIO__type" in grp else 0,
                             hours_with_value=int(grp[s].notna().sum())))
    wcov = pd.DataFrame(wcov)
    out("pm25xlsx_weekly_coverage_gapweeks", wcov)
    print(wcov.pivot_table(index="station", columns="week_start", values="hours_with_value").to_string())

    # ------------------------------------------------------------------ values
    print("\n== Values")
    vals = pd.concat([
        summarize_values(gw, "gapfill 2025-01-13..25", STATIONS),
        summarize_values(rgw, "PM2.5.xlsx 2025-01-13..25", STATIONS),
        summarize_values(window(r, W_BEFORE), "PM2.5.xlsx 2024-12-30..2025-01-12", STATIONS),
        summarize_values(window(r, W_AFTER), "PM2.5.xlsx 2025-01-26..02-08", STATIONS),
        summarize_values(window(r, (pd.Timestamp("2023-01-01 00:00"), pd.Timestamp("2023-01-31 23:00"))),
                         "PM2.5.xlsx 2023-01 (pre-period)", STATIONS),
    ], ignore_index=True)
    out("values_by_station", vals.round(3))
    print(vals[["window", "station", "n_values", "min", "median", "mean", "p99", "max",
                "n_negative", "n_zero", "n_ge_500", "n_sentinel_like", "modal_decimals",
                "max_decimals", "n_flat_runs_ge3", "longest_flat_run"]].round(2).to_string(index=False))

    # Decimal precision: gap-fill by station; PM2.5.xlsx by year, pooled over stations
    dec_rows = []
    for s in STATIONS:
        raw = g.loc[g[s].notna(), s + "__raw"]
        for d, n in raw.map(decimals).value_counts().sort_index().items():
            dec_rows.append(dict(file="gapfill", group=s, decimals=d, n=int(n)))
    rr = r.copy()
    rr["year"] = rr.ts.dt.year
    for yr, grp in rr.groupby("year"):
        cnt = collections.Counter()
        for s in STATIONS:
            cnt.update(grp.loc[grp[s].notna(), s + "__raw"].map(decimals).tolist())
        for d, n in sorted(cnt.items()):
            dec_rows.append(dict(file="PM2.5.xlsx", group=f"year {yr}, all stations", decimals=d, n=int(n)))
    dec = pd.DataFrame(dec_rows)
    out("decimals", dec)
    print(dec.pivot_table(index=["file", "group"], columns="decimals", values="n", fill_value=0).to_string())

    # Copy-paste check: identical values between pairs of gap-fill station columns
    pairs = []
    for i, a in enumerate(STATIONS):
        for b in STATIONS[i + 1:]:
            m = g[a].notna() & g[b].notna()
            pairs.append(dict(a=a, b=b, paired=int(m.sum()),
                              share_identical=round(float((g.loc[m, a] == g.loc[m, b]).mean()), 3) if m.any() else np.nan))
    pairs = pd.DataFrame(pairs)
    print("max share of identical values between two gap-fill stations:", pairs.share_identical.max())
    out("gapfill_column_pairs", pairs)

    # ---------------------------------------------------- lag alignment
    print("\n== Lag alignment (gap-fill at t vs PM2.5.xlsx at t + L)")
    rser = r.set_index("ts")
    lag_rows = []
    for s in STATIONS:
        gs = gw.set_index("ts")[s].dropna()
        g_dec = int(gw.loc[gw[s].notna(), s + "__raw"].map(decimals).mode().iloc[0]) if len(gs) else 1
        r_dec = int(window(r, (W_BEFORE[0], W_AFTER[1])).pipe(lambda d: d.loc[d[s].notna(), s + "__raw"]).map(decimals).mode().iloc[0])
        prec = min(g_dec, r_dec)
        for L in LAGS_ALL:
            rv = rser[s].reindex(gs.index + pd.Timedelta(hours=L))
            rv.index = gs.index
            m = rv.notna()
            a, b = gs[m], rv[m]
            n = int(m.sum())
            d = a - b
            lag_rows.append(dict(
                station=s, lag_hours=L, requested_lag=L in LAGS_ASKED, paired_hours=n,
                compare_decimals=prec,
                share_equal=round(float((a.round(prec) == b.round(prec)).mean()), 4) if n else np.nan,
                share_within_0_5=round(float((d.abs() <= 0.5).mean()), 4) if n else np.nan,
                mean_signed_diff=round(float(d.mean()), 3) if n else np.nan,
                mean_abs_diff=round(float(d.abs().mean()), 3) if n else np.nan,
                ratio_of_means=round(float(a.mean() / b.mean()), 3) if n and b.mean() else np.nan,
                correlation=round(float(np.corrcoef(a, b)[0, 1]), 4) if n > 2 and a.std() > 0 and b.std() > 0 else np.nan,
            ))
    lag = pd.DataFrame(lag_rows)
    out("lag_alignment", lag)
    print(lag[lag.requested_lag].to_string(index=False))
    print("Best lag by correlation, lags -6..+6:")
    if lag.correlation.notna().any():
        print(lag.dropna(subset=["correlation"]).loc[lambda d: d.groupby("station").correlation.idxmax()][["station", "lag_hours", "paired_hours", "correlation", "share_equal"]].to_string(index=False))

    # ---------------------------------------------------- diurnal profiles
    print("\n== Diurnal profiles (mean by hour of day)")
    prof_rows = []
    sources = [("gapfill", "2025-01-13..25", gw),
               ("PM2.5.xlsx", "2025-01-13..25", rgw),
               ("PM2.5.xlsx", "2024-12-30..2025-01-12", window(r, W_BEFORE)),
               ("PM2.5.xlsx", "2025-01-26..02-08", window(r, W_AFTER))]
    for f, lab, d in sources:
        for wd_lab, mask in (("all days", d.ts.dt.weekday >= 0), ("weekdays", d.ts.dt.weekday < 5)):
            dd = d[mask]
            for s in STATIONS:
                grp = dd.groupby(dd.ts.dt.hour)[s]
                for hr in range(24):
                    x = grp.get_group(hr).dropna() if hr in grp.groups else pd.Series(dtype=float)
                    prof_rows.append(dict(file=f, window=lab, days=wd_lab, station=s, hour_of_day=hr,
                                          n=len(x), mean=round(x.mean(), 3) if len(x) else np.nan))
    prof = pd.DataFrame(prof_rows)
    out("diurnal_profiles", prof)
    peaks = []
    for (f, lab, dlab, s), grp in prof.groupby(["file", "window", "days", "station"]):
        grp = grp.set_index("hour_of_day")["mean"]
        if grp.notna().sum() < 20:
            peaks.append(dict(file=f, window=lab, days=dlab, station=s, hours_with_mean=int(grp.notna().sum())))
            continue
        mo, ev = grp.loc[4:11], grp.loc[14:23]
        peaks.append(dict(file=f, window=lab, days=dlab, station=s, hours_with_mean=int(grp.notna().sum()),
                          morning_peak_hour=int(mo.idxmax()), morning_peak_mean=round(mo.max(), 2),
                          evening_peak_hour=int(ev.idxmax()), evening_peak_mean=round(ev.max(), 2),
                          daily_min_hour=int(grp.idxmin()), daily_min_mean=round(grp.min(), 2),
                          overall_mean=round(grp.mean(), 2)))
    peaks = pd.DataFrame(peaks)
    out("diurnal_peaks", peaks)
    print(peaks[peaks.days == "all days"].to_string(index=False))

    # Circular shift of the gap-fill profile against the neighbouring REMMAQ profiles
    shift_rows = []
    for ref_lab in ("2024-12-30..2025-01-12", "2025-01-26..02-08"):
        for s in STATIONS:
            gp = prof[(prof.file == "gapfill") & (prof.days == "all days") & (prof.station == s)].set_index("hour_of_day")["mean"]
            rp = prof[(prof.file == "PM2.5.xlsx") & (prof.window == ref_lab) & (prof.days == "all days") & (prof.station == s)].set_index("hour_of_day")["mean"]
            if gp.notna().sum() < 24 or rp.notna().sum() < 24:
                shift_rows.append(dict(reference_window=ref_lab, station=s, note="profile incomplete"))
                continue
            row = dict(reference_window=ref_lab, station=s)
            for L in LAGS_ALL:
                # gap-fill hour h against reference hour h + L (same sign as the lag table)
                rv = rp.reindex([(h + L) % 24 for h in range(24)]).values
                row[f"corr_lag_{L:+d}"] = round(float(np.corrcoef(gp.values, rv)[0, 1]), 4)
            cand = {L: row[f"corr_lag_{L:+d}"] for L in LAGS_ALL}
            row["best_lag"] = max(cand, key=cand.get)
            shift_rows.append(row)
    shift = pd.DataFrame(shift_rows)
    out("diurnal_shift", shift)
    print(shift[["reference_window", "station", "best_lag"] + [f"corr_lag_{L:+d}" for L in LAGS_ASKED]].to_string(index=False))

    # ------------------------------------------- timing within each file
    # Each station's hourly series at t against the mean of the other stations
    # at t + L. A best lag of L = -k means the station's series trails the
    # others by k hours: its pattern appears k hours later (for example, a
    # logger clock running k hours fast, or a real delay).
    print("\n== Timing against the other stations in the same file")
    W_JAN23 = (pd.Timestamp("2023-01-01 00:00"), pd.Timestamp("2023-01-31 23:00"))
    xs_rows = []
    for f, lab, d in [("gapfill", "2025-01-13..25", gw),
                      ("PM2.5.xlsx", "2024-12-30..2025-01-12", window(r, W_BEFORE)),
                      ("PM2.5.xlsx", "2023-01-01..31 (pre-period)", window(r, W_JAN23))]:
        dd = d.set_index("ts")[STATIONS]
        dd = dd.reindex(pd.date_range(dd.index.min(), dd.index.max(), freq="h"))
        for s in STATIONS:
            others = dd.drop(columns=s).mean(axis=1, skipna=True)
            row = dict(file=f, window=lab, station=s, n_values=int(dd[s].notna().sum()))
            best, bestc = None, -2
            for L in LAGS_ALL:
                o = others.shift(-L)  # value of the others at t + L
                m = dd[s].notna() & o.notna()
                c = float(np.corrcoef(dd[s][m], o[m])[0, 1]) if m.sum() > 24 else np.nan
                row[f"corr_lag_{L:+d}"] = round(c, 4) if not np.isnan(c) else np.nan
                if not np.isnan(c) and c > bestc:
                    best, bestc = L, c
            row["best_lag"] = best
            row["paired_hours_lag0"] = int((dd[s].notna() & others.notna()).sum())
            xs_rows.append(row)
    xs = pd.DataFrame(xs_rows)
    out("timing_vs_other_stations", xs)
    print(xs[["file", "window", "station", "n_values", "best_lag"] + [f"corr_lag_{L:+d}" for L in (-3, -2, -1, 0, 1, 2, 3)]].to_string(index=False))

    # Diurnal profile of Los Chillos in January 2023 (pre-period) as a reference shape
    j = window(r, W_JAN23)
    lc = []
    for s in STATIONS:
        grp = j.groupby(j.ts.dt.hour)[s]
        for hr in range(24):
            x = grp.get_group(hr).dropna() if hr in grp.groups else pd.Series(dtype=float)
            lc.append(dict(file="PM2.5.xlsx", window="2023-01-01..31 (pre-period)", days="all days",
                           station=s, hour_of_day=hr, n=len(x), mean=round(x.mean(), 3) if len(x) else np.nan))
    lc = pd.DataFrame(lc)
    out("diurnal_profiles_jan2023", lc)
    for s in ["LOS CHILLOS", "TUMBACO", "CENTRO"]:
        g1 = lc[lc.station == s].set_index("hour_of_day")["mean"]
        if g1.notna().sum() >= 20:
            print(f"Jan 2023 {s}: morning peak {int(g1.loc[4:11].idxmax())}, evening peak {int(g1.loc[14:23].idxmax())}, min {int(g1.idxmin())}, n per hour min {lc[lc.station == s].n.min()}")


if __name__ == "__main__":
    main()
