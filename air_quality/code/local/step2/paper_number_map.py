"""
paper_number_map.py
Step 2 paper-number map (air_quality/docs/revision_plan.md 4.3): every number
printed in the local results tables of the May 31, 2026 draft (Tables 3, 5, 6,
7, A.1 and A.3; text copy congestion/docs/paper/Underground-relief.txt), with
its frozen source value (frozen_2026-05-29) and its new value (main step 2 run),
both rounded to the paper's printed precision. Text numbers and printed date
labels are listed in the step 2 report with their line numbers.

Columns:
  frozen_rounded  frozen source value at printed precision. It equals the
                  printed cell except where a note says otherwise.
  new             new value at printed precision.
  change          new minus frozen, at printed precision.
  sign_changed    from the unrounded values; empty when either is zero or
                  missing, or for quantities without a sign.
  note            definition changes and paper typos.
  paper_lines     line range of the table body in the text copy (table level,
                  not cell level; page numbers are not tracked).
Not mapped: the monitor distances of Table 6, which do not change (take them
from the paper, not from dist_corridor_km; see docs/known_issues.md).

Run from anywhere (after old_vs_new.R):  python3 code/local/step2/paper_number_map.py
Needs pandas and numpy. Output: output/local/step2/paper_number_map.csv
"""
import os
import sys
import numpy as np
import pandas as pd

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
FROZEN = "/home/leonelb/data/quito-metro-eval/air_quality/frozen_2026-05-29"
NEW = os.path.join(ROOT, "output", "local")
OUT = os.path.join(NEW, "step2", "paper_number_map.csv")
if not os.path.isdir(os.path.join(FROZEN, "output", "local")):
    sys.exit(f"Frozen reference not found: {FROZEN}/output/local")
WIN = {"pre_blackout": "Pre-disruption", "donut": "Donut", "full": "Full"}
SIGNED = ("log effect", "percent effect")
LINES = {"Table 3": "292-299", "Table 5": "640-663", "Table 6": "688-697", "Table 7": "734-756",
         "Table A.1": "1173-1178", "Table A.3": "1231-1261"}
rows = []


def missing(x):
    return x is None or (isinstance(x, float) and np.isnan(x))


def fmt(x, digits):
    return "" if missing(x) else f"{round(float(x), digits):.{digits}f}"


def add(table, where, quantity, old, new, digits, source, note=""):
    sign = ""
    if quantity in SIGNED and not missing(old) and not missing(new) and old != 0 and new != 0:
        sign = str(bool(np.sign(old) != np.sign(new)))
    change = "" if missing(old) or missing(new) else \
        fmt(round(float(new), digits) - round(float(old), digits), digits)
    rows.append(dict(table=table, location=where, quantity=quantity, frozen_rounded=fmt(old, digits),
                     new=fmt(new, digits), change=change, sign_changed=sign, note=note, source=source,
                     paper_lines=LINES[table]))


def cross(base, pol):
    return pd.read_csv(os.path.join(base, "crosssample", f"CrossSample_Summary_{pol}.csv")).set_index(["spec", "sample"])


POLS = ["PM25", "CO", "NO2", "SO2"]
old = {p: cross(os.path.join(FROZEN, "output/local"), p) for p in POLS}
new = {p: cross(NEW, p) for p in POLS}
SRC = "crosssample/CrossSample_Summary_{}.csv"
QTY = [("log effect", "att_log", 3), ("percent effect", "att_pct", 1), ("conformal p", "p_2s", 3),
       ("pre RMSPE", "rmspe_pre", 3), ("post RMSPE", "rmspe_post", 3), ("post/pre RMSPE", "ratio", 2)]

# Table 5: M7, M9, M8, M8b, three windows
for spec in ["M7", "M9", "M8", "M8b"]:
    for w in WIN:
        o, n = old["PM25"].loc[(spec, w)], new["PM25"].loc[(spec, w)]
        for q, col, d in QTY:
            add("Table 5", f"{WIN[w]} window, {spec}", q, o[col], n[col], d, SRC.format("PM25"))

# Table 7: M8b, four pollutants, three windows
for pol in POLS:
    for w in WIN:
        o, n = old[pol].loc[("M8b", w)], new[pol].loc[("M8b", w)]
        for q, col, d in QTY:
            add("Table 7", f"{WIN[w]} window, {pol}", q, o[col], n[col], d, SRC.format(pol))

# Table A.3: full battery, log effect and p by window; RMSPE pre and post/pre (pre-disruption)
TYPO = "Paper prints -0.154 here; Table 5 prints -0.153 from the same source value (typo in Table A.3)."
for spec in ["M1", "M3", "M2", "M2b", "M4", "M6", "M5", "M5b", "M7", "M9", "M8", "M8b"]:
    for w in WIN:
        o, n = old["PM25"].loc[(spec, w)], new["PM25"].loc[(spec, w)]
        add("Table A.3", f"{spec}, {WIN[w]}", "log effect", o["att_log"], n["att_log"], 3, SRC.format("PM25"),
            TYPO if (spec, w) == ("M8", "donut") else "")
        if o["p_type"] == n["p_type"] == "conformal":
            add("Table A.3", f"{spec}, {WIN[w]}", "conformal p", o["p_2s"], n["p_2s"], 3, SRC.format("PM25"))
    o, n = old["PM25"].loc[(spec, "pre_blackout")], new["PM25"].loc[(spec, "pre_blackout")]
    add("Table A.3", f"{spec}", "RMSPE pre", o["rmspe_pre"], n["rmspe_pre"], 3, SRC.format("PM25"))
    add("Table A.3", f"{spec}", "post/pre RMSPE (pre-disruption)", o["ratio"], n["ratio"], 2, SRC.format("PM25"))

# Table 6: spatial placebo (M8b), pre-disruption window
PSRC = "spatial_placebo/spatial_placebo_PM25_M8b_conformalp.csv"
po = pd.read_csv(os.path.join(FROZEN, "output/local", PSRC))
pn = pd.read_csv(os.path.join(NEW, PSRC))
po = po[po["sample"] == "pre_blackout"].set_index("station")
pn = pn[pn["sample"] == "pre_blackout"].set_index("station")
BEL = "New donor rule: Centro removed from Belisario's pool, so the change is not due to the data alone."
for st in po.index:
    note = BEL if st == "belisario" else ""
    add("Table 6", st, "percent effect", po.loc[st, "att_pct"], pn.loc[st, "att_pct"], 1, PSRC, note)
    add("Table 6", st, "conformal p", po.loc[st, "conf_p"], pn.loc[st, "conf_p"], 3, PSRC, note)

# Table 3: stations, weeks by period and weeks by window
TL = "tables/descriptives_treatment_timeline.csv"
to = pd.read_csv(os.path.join(FROZEN, "output/local", TL)).set_index("period")
tn = pd.read_csv(os.path.join(NEW, TL)).set_index("period")
PERIODS = {"Pre": "Pre-treatment", "P1": "Period 1 (post, pre-blackout)",
           "Blackout": "Phase 3 blackout (dropped from SDID donut)",
           "Trans.": "Late Dec 2024 (post-outage, pre-Period 2)", "P2": "Period 2 (post, post-blackout)"}
SC = "tables/descriptives_sample_construction.csv"
so = pd.read_csv(os.path.join(FROZEN, "output/local", SC)).set_index("pollutant")
sn = pd.read_csv(os.path.join(NEW, SC)).set_index("pollutant")
ww = pd.read_csv(os.path.join(NEW, "step2", "window_weeks.csv"))
for pol in POLS:
    k = pol.lower()
    add("Table 3", pol, "stations", so.loc[k, "balanced_stations"], sn.loc[k, "balanced_stations"], 0, SC)
    for lab, per in PERIODS.items():
        note = "Frozen P2 excludes the 7-week gap of Table 3 footnote a." if (pol, lab) == ("PM25", "P2") else ""
        add("Table 3", pol, f"{lab} weeks", to.loc[per, f"n_weeks_{k}"], tn.loc[per, f"n_weeks_{k}"], 0, TL, note)
    for w in WIN:
        o = ww[(ww.pollutant == pol) & (ww.run == "old") & (ww["sample"] == w)].iloc[0]
        n = ww[(ww.pollutant == pol) & (ww.run == "new") & (ww["sample"] == w)].iloc[0]
        add("Table 3", pol, f"{w} weeks", o.weeks_pre + o.weeks_post, n.weeks_pre + n.weeks_post, 0,
            "step2/window_weeks.csv")

# Table A.1: sample construction
DEF = ("Counting window changed: new counts stop at the June 2025 cut (11_descriptives.R), so most of the "
       "change is definitional, not a change in the sample.")
for pol in POLS:
    k = pol.lower()
    for q, col, d, note in [("stations", "n_stations", 0, ""), ("raw hourly", "raw_hourly_obs", 0, DEF),
                            ("peak-hour", "after_peak_hour_filter", 0, DEF),
                            ("weekday peak-hour", "after_weekday_filter", 0, DEF),
                            ("balanced panel", "balanced_obs", 0, ""), ("imputed (%)", "pct_imputed", 1, ""),
                            ("weeks", "balanced_weeks", 0, "")]:
        add("Table A.1", pol, q, so.loc[k, col], sn.loc[k, col], d, SC, note)

df = pd.DataFrame(rows)
df.to_csv(OUT, index=False)
changed = (df.change != "") & (pd.to_numeric(df.change, errors="coerce") != 0)
print(df.groupby("table").size().to_string())
print("rows:", len(df), " changed:", int(changed.sum()), " sign changes:", int((df.sign_changed == "True").sum()))
