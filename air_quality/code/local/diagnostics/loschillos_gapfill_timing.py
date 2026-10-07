"""
loschillos_gapfill_timing.py
Workstream A, follow-up to step 1. Does the Secretaria's gap-fill Los Chillos
PM2.5 series (2025-01-13 to 2025-01-25) look like Los Chillos's own record in
PM2.5.xlsx, the same series shifted by some hours, or something else?

The panel uses fixed clock hours in every period, so a station that always
peaks late is not a problem. Only a shift against the station's own record is.

References from PM2.5.xlsx (September to December 2024 left out, because the
power cuts changed daily patterns):
  mar2025      2025-03-01 to 2025-03-31
  q1_2024      2024-01-01 to 2024-03-31
  weeks2024    2024-01-15 to 2024-01-27, the same ISO weeks and weekdays as
               the gap-fill (Monday of week 3 to Saturday of week 4); used
               for the level comparison (c)

Checks
  a. Weekday (Mon-Fri) mean profile by hour of day; morning peak = hour of the
     maximum over 00-11, evening peak = over 12-23. Profile shift: correlation
     of the gap-fill profile at hour h with the reference profile at hour h+k
     (circular), k = -3..3; k* is the best k.
  b. Hourly correlation of Los Chillos at t with the mean of the other seven
     analysis stations at t+L, L = -3..3; L* is the best L. In both a and b, a
     best value of -2 means Los Chillos's pattern comes two hours later than
     the comparison series.
  c. Level and spread: n, mean, sd, p10, median, p90, and the ratio of the
     Los Chillos mean to the other seven stations' mean over the same hours;
     all hours and weekday peak hours (07, 08, 09, 17, 18, 19).
  d. Gap-fill Los Chillos values with more than two decimals (shortest
     round-trip text of the stored number).

Classification rule, fixed before the first run:
  "own series"    k* = 0 against both mar2025 and q1_2024, and
                  |L*(gap-fill) - L*(reference)| <= 1 for both.
  "shifted by k"  k* = the same k != 0 against both references, and
                  L*(gap-fill) - L*(reference) is within 1 of k for both.
  otherwise       "something else / unclear".
  The level comparison (c) and the decimals (d) are reported beside the
  classification and do not enter the rule.

Added after code review (reported beside the rule, not part of it):
  - a side run of a and b over -12..12 hours, with a flag when the best
    value sits on the edge of the searched range (the +-3 range of the rule
    can put the best value on its edge; -5 would be a UTC offset);
  - the profile shift of mar2025 against q1_2024, as a check of how stable
    the station's own record is;
  - "others" in every window come from PM2.5.xlsx; for the gap-fill window
    the script asserts they equal the gap-fill file's own columns, so a
    whole-file clock offset cannot pass for a Los Chillos one.
  Values are read as the pipeline reads them: negatives become missing
  (01_read_and_merge.R:249-253); non-numeric cells are counted.

Output: output/local/diagnostics/pm25_gap/loschillos_timing_*.csv
(aggregates only: hourly means by hour of day, correlations, summary stats).
Run from air_quality/:
  python3 code/local/diagnostics/loschillos_gapfill_timing.py > ../logs/aq_loschillos_timing.log 2>&1
"""
import os
import datetime as dt

import numpy as np
import pandas as pd
import openpyxl

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))   # air_quality/
# The gap-fill file is deliberately not linked into the repository
# (air_quality/CLAUDE.md), so it is read from the data store.
GF = ("/home/leonelb/data/quito-metro-eval/air_quality/raw/"
      "2026-09-07_secretaria_ambiente_pm25_gapfill/DATOSFALTANTESPM2.5_ANALISISMETRO.xlsx")
REF = os.path.join(ROOT, "data", "raw", "remmaq", "PM2.5.xlsx")
OUT = os.path.join(ROOT, "output", "local", "diagnostics", "pm25_gap")
os.makedirs(OUT, exist_ok=True)

LC = "LOS CHILLOS"
OTHERS = ["BELISARIO", "CARAPUNGO", "CENTRO", "COTOCOLLAO", "GUAMANI", "SAN ANTONIO", "TUMBACO"]
PEAK = [7, 8, 9, 17, 18, 19]
LAGS = range(-3, 4)          # the rule's range
LAGS_WIDE = range(-12, 13)   # side run
WINDOWS = {
    "gapfill_2025-01-13..25": ("gapfill", "2025-01-13", "2025-01-25"),
    "mar2025":                ("PM2.5.xlsx", "2025-03-01", "2025-03-31"),
    "q1_2024":                ("PM2.5.xlsx", "2024-01-01", "2024-03-31"),
    "weeks2024_01-15..27":    ("PM2.5.xlsx", "2024-01-15", "2024-01-27"),
}


def read_book(path):
    ws = openpyxl.load_workbook(path, read_only=True, data_only=True).worksheets[0]
    rows = ws.iter_rows(values_only=True)
    hdr = [h.strip() if isinstance(h, str) else h for h in next(rows)]
    need = [LC] + OTHERS
    missing = [s for s in need if s not in hdr]
    assert not missing, f"{os.path.basename(path)}: station columns not found: {missing}"
    idx = {s: hdr.index(s) for s in need}
    recs, n_text, n_neg = [], {s: 0 for s in need}, {s: 0 for s in need}
    for r in rows:
        if not isinstance(r[0], dt.datetime):
            continue
        rec = {"ts": r[0]}
        for s, i in idx.items():
            v = r[i]
            if isinstance(v, str) and v.strip():
                n_text[s] += 1
            if isinstance(v, (int, float)) and v < 0:
                n_neg[s] += 1
            # negatives to missing, as 01_read_and_merge.R:249-253
            rec[s] = float(v) if isinstance(v, (int, float)) and v >= 0 else np.nan
        recs.append(rec)
    print(f"{os.path.basename(path)}: non-numeric text cells {sum(n_text.values())}, "
          f"negative values set to missing {sum(n_neg.values())}")
    d = pd.DataFrame(recs)
    d["ts"] = pd.to_datetime(d["ts"]).dt.round("h")
    assert not d["ts"].duplicated().any()
    return d.set_index("ts").sort_index()


books = {"gapfill": read_book(GF), "PM2.5.xlsx": read_book(REF)}

# The other seven stations in the gap-fill file must equal PM2.5.xlsx there,
# so that "others" are on the same clock in every window.
_g = books["gapfill"][OTHERS]
_r = books["PM2.5.xlsx"][OTHERS].reindex(_g.index)
assert _g.isna().equals(_r.isna()) and np.allclose(_g.fillna(0), _r.fillna(0), atol=0), \
    "gap-fill other-station columns differ from PM2.5.xlsx"
print("Other seven stations in the gap-fill file equal PM2.5.xlsx at lag 0: True")


def window(name):
    """Los Chillos from the window's source; the other seven always from PM2.5.xlsx."""
    src, a, b = WINDOWS[name]
    full = pd.date_range(pd.Timestamp(a), pd.Timestamp(b) + pd.Timedelta(hours=23), freq="h")
    d = books["PM2.5.xlsx"].reindex(full).copy()
    d[LC] = books[src][LC].reindex(full)
    return d


def weekday_profile(s):
    s = s[s.index.dayofweek < 5]
    g = s.groupby(s.index.hour)
    return g.mean().reindex(range(24)), g.count().reindex(range(24), fill_value=0)


# ---- a. profiles and peaks
prof_rows, peak_rows, profiles = [], [], {}
for name in WINDOWS:
    d = window(name)
    lc_p, lc_n = weekday_profile(d[LC])
    ot_p, _ = weekday_profile(d[OTHERS].mean(axis=1, skipna=True))
    profiles[name] = lc_p
    for h in range(24):
        prof_rows.append(dict(window=name, hour=h, loschillos_mean=round(lc_p[h], 3),
                              loschillos_n=int(lc_n[h]), others7_mean=round(ot_p[h], 3)))
    pk = lambda p, hrs: int(p.loc[hrs].idxmax()) if p.loc[hrs].notna().any() else None
    peak_rows.append(dict(window=name,
                          loschillos_values=int(d[LC].notna().sum()),
                          loschillos_weekdays_with_data=int(d[LC][d.index.dayofweek < 5].resample("D").count().gt(0).sum()),
                          lc_morning_peak=pk(lc_p, range(0, 12)), lc_evening_peak=pk(lc_p, range(12, 24)),
                          others7_morning_peak=pk(ot_p, range(0, 12)), others7_evening_peak=pk(ot_p, range(12, 24))))
pd.DataFrame(prof_rows).to_csv(os.path.join(OUT, "loschillos_timing_profiles.csv"), index=False)
peaks = pd.DataFrame(peak_rows)
peaks.to_csv(os.path.join(OUT, "loschillos_timing_peaks.csv"), index=False)

def best(cors, rng):
    """Argmax over unrounded correlations; flag a best value on the range edge."""
    assert all(np.isfinite(list(cors.values()))), "non-finite correlation"
    b = max(rng, key=lambda x: cors[x])
    return b, b in (min(rng), max(rng))


def profile_shift(g, r, rng):
    return {k: float(np.corrcoef(g.values, r.reindex([(h + k) % 24 for h in range(24)]).values)[0, 1])
            for k in rng}


shift_rows = []
pairs = [("gapfill_2025-01-13..25", "mar2025"), ("gapfill_2025-01-13..25", "q1_2024"),
         ("mar2025", "q1_2024")]            # last pair: stability of the station's own record
for src, ref in pairs:
    row = dict(series=src, reference=ref)
    c = profile_shift(profiles[src], profiles[ref], LAGS)
    row.update({f"corr_k{k:+d}": round(v, 4) for k, v in c.items()})
    row["best_k"], row["best_k_at_edge"] = best(c, LAGS)
    cw = profile_shift(profiles[src], profiles[ref], LAGS_WIDE)
    row["wide_best_k"], row["wide_best_k_at_edge"] = best(cw, LAGS_WIDE)
    row["wide_best_k_corr"] = round(cw[row["wide_best_k"]], 4)
    shift_rows.append(row)
shift = pd.DataFrame(shift_rows)
shift.to_csv(os.path.join(OUT, "loschillos_timing_profile_shift.csv"), index=False)

# ---- b. lagged correlation with the other seven stations
def lag_corrs(lc, others, rng):
    out, n = {}, {}
    for L in rng:
        o = others.shift(-L)              # others at t + L
        ok = lc.notna() & o.notna()
        n[L] = int(ok.sum())
        out[L] = float(np.corrcoef(lc[ok], o[ok])[0, 1])
    return out, n


lag_rows = []
for name in ("gapfill_2025-01-13..25", "mar2025", "q1_2024"):
    d = window(name)
    lc = d[LC]
    others = d[OTHERS].mean(axis=1, skipna=True)
    row = dict(window=name, mean_others_stations_per_hour=round(float(d[OTHERS].notna().sum(axis=1).mean()), 2))
    c, n = lag_corrs(lc, others, LAGS)
    for L in LAGS:
        row[f"n_L{L:+d}"] = n[L]
        row[f"corr_L{L:+d}"] = round(c[L], 4)
    row["best_L"], row["best_L_at_edge"] = best(c, LAGS)
    cw, _ = lag_corrs(lc, others, LAGS_WIDE)
    row["wide_best_L"], row["wide_best_L_at_edge"] = best(cw, LAGS_WIDE)
    row["wide_best_L_corr"] = round(cw[row["wide_best_L"]], 4)
    lag_rows.append(row)
lags = pd.DataFrame(lag_rows)
lags.to_csv(os.path.join(OUT, "loschillos_timing_lags.csv"), index=False)

# ---- c. level and spread
lvl_rows = []
for name in WINDOWS:
    d = window(name)
    for hours, mask in (("all hours", np.ones(len(d), bool)),
                        ("weekday peak hours", (d.index.dayofweek < 5) & d.index.hour.isin(PEAK))):
        x = d.loc[mask, LC].dropna()
        o = d.loc[mask, OTHERS].mean(axis=1, skipna=True)[x.index]
        lvl_rows.append(dict(window=name, hours=hours, n=len(x), mean=round(x.mean(), 2),
                             sd=round(x.std(), 2), p10=round(x.quantile(.1), 2),
                             median=round(x.median(), 2), p90=round(x.quantile(.9), 2),
                             others7_mean_same_hours=round(o.mean(), 2),
                             ratio_lc_to_others7=round(x.mean() / o.mean(), 3)))
lvl = pd.DataFrame(lvl_rows)
lvl.to_csv(os.path.join(OUT, "loschillos_timing_levels.csv"), index=False)

# ---- d. decimals
def ndec(v):
    t = repr(float(v))
    if "e" in t or "E" in t:
        return np.nan                     # scientific notation: not counted
    return len(t.split(".")[1].rstrip("0")) if "." in t else 0

dec_rows = []
for name in WINDOWS:
    x = window(name)[LC].dropna()
    n = x.map(ndec)
    dec_rows.append(dict(window=name, values=len(x), more_than_2_decimals=int((n > 2).sum()),
                         max_decimals=int(n.max()) if len(n) else None))
dec = pd.DataFrame(dec_rows)
dec.to_csv(os.path.join(OUT, "loschillos_timing_decimals.csv"), index=False)

# ---- classification, by the rule in the header
gL = int(lags.set_index("window").loc["gapfill_2025-01-13..25", "best_L"])
_g = shift[shift.series == "gapfill_2025-01-13..25"].set_index("reference")
ks = {r: int(_g.loc[r, "best_k"]) for r in ("mar2025", "q1_2024")}
dL = {r: gL - int(lags.set_index("window").loc[r, "best_L"]) for r in ("mar2025", "q1_2024")}
if all(k == 0 for k in ks.values()) and all(abs(v) <= 1 for v in dL.values()):
    verdict = "own series"
elif len(set(ks.values())) == 1 and list(ks.values())[0] != 0 and \
        all(abs(dL[r] - ks[r]) <= 1 for r in ks):
    verdict = f"shifted by {list(ks.values())[0]} hours"
else:
    verdict = "something else / unclear"
cls = pd.DataFrame([dict(best_k_mar2025=ks["mar2025"], best_k_q1_2024=ks["q1_2024"],
                         best_L_gapfill=gL, dL_vs_mar2025=dL["mar2025"], dL_vs_q1_2024=dL["q1_2024"],
                         verdict=verdict)])
cls.to_csv(os.path.join(OUT, "loschillos_timing_verdict.csv"), index=False)

pd.set_option("display.width", 200)
for t in (peaks, shift, lags, lvl, dec, cls):
    print(t.to_string(index=False), "\n")
