"""
paper_tables.py
Priority 1 of Leonel's decisions of 2026-10-05: the local tables of the
"Underground Relief" draft (May 31, 2026) rebuilt on the step 2 outputs, in
the paper's layout, plus the list of every number in the text with its old and
new value.

Reads committed outputs only (crosssample/, spatial_placebo/, tables/,
step2/window_weeks.csv) and the frozen reference. Writes output/local/paper/:
  table{1,3,5,6,7,A1,A3}.tex   booktabs tables in the PDF's layout (new values)
  table{...}.csv               the same cells
  tables_preview.md            all tables as Markdown, for review
  text_numbers.csv             every number in the text with old and new value
  figure2.{png,pdf}, figure5.{png,pdf}   copies of the regenerated figures

Self-checks: every table is also built from the frozen outputs and compared,
row by row, with the printed rows of congestion/docs/paper/Underground-relief.txt
(the one known paper typo, Table A.3 M8 donut, is allowed); every curated text
phrase must appear on its line.

Text flags (column `flag`): only when a cited estimate changes sign, or its
p-value crosses 0.05 or 0.10 (p <= threshold on one side only).

Run from anywhere:  python3 code/local/step2/paper_tables.py   (pandas, numpy)
"""
import os
import re
import shutil
import sys
import numpy as np
import pandas as pd

AQ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
REPO = os.path.dirname(AQ)
FROZEN = "/home/leonelb/data/quito-metro-eval/air_quality/frozen_2026-05-29/output/local"
NEW = os.path.join(AQ, "output", "local")
OUT = os.path.join(NEW, "paper")
PAPER = os.path.join(REPO, "congestion", "docs", "paper", "Underground-relief.txt")
for p in (FROZEN, NEW, PAPER):
    if not os.path.exists(p):
        sys.exit(f"Missing input: {p}")
os.makedirs(OUT, exist_ok=True)

with open(PAPER, encoding="utf-8", errors="replace") as fh:
    TXT = [""] + fh.read().split("\n")          # TXT[n] is line n


def norm(s):
    return s.replace("−", "-").replace("–", "-")


# ---------------------------------------------------------------- sources
POLS = ["PM25", "CO", "NO2", "SO2"]
WINS = ["pre_blackout", "donut", "full"]


def cross(base):
    return {p: pd.read_csv(os.path.join(base, "crosssample", f"CrossSample_Summary_{p}.csv"))
            .set_index(["spec", "sample"]) for p in POLS}


CS = {"old": cross(FROZEN), "new": cross(NEW)}
PL = {}
for k, base in (("old", FROZEN), ("new", NEW)):
    d = pd.read_csv(os.path.join(base, "spatial_placebo", "spatial_placebo_PM25_M8b_conformalp.csv"))
    PL[k] = d[d["sample"] == "pre_blackout"].set_index("station")
SC = {k: pd.read_csv(os.path.join(b, "tables", "descriptives_sample_construction.csv")).set_index("pollutant")
      for k, b in (("old", FROZEN), ("new", NEW))}
TL = {k: pd.read_csv(os.path.join(b, "tables", "descriptives_treatment_timeline.csv")).set_index("period")
      for k, b in (("old", FROZEN), ("new", NEW))}
WW = pd.read_csv(os.path.join(NEW, "step2", "window_weeks.csv"))


def fmt(x, d, comma=False):
    if x is None or (isinstance(x, float) and np.isnan(x)):
        return "n.a."
    r = round(float(x), d)
    if r == 0:
        r = 0.0
    return f"{r:,.{d}f}" if comma else f"{r:.{d}f}"


def cs(run, pol, spec, win, col):
    return CS[run][pol].loc[(spec, win), col]


# ---------------------------------------------------------------- table builders
# Each builder returns a list of (row_label, [cells]) for one run; cells are strings.
STATIONS6 = [("centro", "Centro", "0.61"), ("belisario", "Belisario", "0.77"), ("guamani", "Guamaní", "4.04"),
             ("cotocollao", "Cotocollao", "5.21"), ("carapungo", "Carapungo", "7.64"),
             ("loschillos", "Los Chillos", "8.62"), ("tumbaco", "Tumbaco", "9.56"),
             ("sanantonio", "San Antonio", "16.65")]
QROWS = [("Log effect", "att_log", 3), ("Percent effect", "att_pct", 1), ("Conformal p", "p_2s", 3),
         ("Pre RMSPE", "rmspe_pre", 3), ("Post RMSPE", "rmspe_post", 3), ("Post/pre RMSPE", "ratio", 2)]


def t5(run):
    rows = []
    for w in WINS:
        for lab, col, d in QROWS:
            rows.append((f"{w}|{lab}", [fmt(cs(run, "PM25", s, w, col), d) for s in ["M7", "M9", "M8", "M8b"]]))
    return rows


def t7(run):
    rows = []
    for w in WINS:
        for lab, col, d in QROWS:
            rows.append((f"{w}|{lab}", [fmt(cs(run, p, "M8b", w, col), d) for p in POLS]))
    return rows


def t6(run):
    return [(name, [dist, fmt(PL[run].loc[st, "att_pct"], 1), fmt(PL[run].loc[st, "conf_p"], 3)])
            for st, name, dist in STATIONS6]


PERIODS = ["Pre-treatment", "Period 1 (post, pre-blackout)", "Phase 3 blackout (dropped from SDID donut)",
           "Late Dec 2024 (post-outage, pre-Period 2)", "Period 2 (post, post-blackout)"]


def t3(run):
    rows = []
    for p in POLS:
        k = p.lower()
        per = [str(int(TL[run].loc[x, f"n_weeks_{k}"])) for x in PERIODS]
        win = []
        for w in WINS:
            r = WW[(WW.pollutant == p) & (WW.run == run) & (WW["sample"] == w)].iloc[0]
            win.append(str(int(r.weeks_pre + r.weeks_post)))
        rows.append((p, [str(int(SC[run].loc[k, "balanced_stations"]))] + per + win))
    return rows


def ta1(run):
    rows = []
    for p in POLS:
        s = SC[run].loc[p.lower()]
        rows.append((p, [str(int(s.n_stations)), fmt(s.raw_hourly_obs, 0, True), fmt(s.after_peak_hour_filter, 0, True),
                         fmt(s.after_weekday_filter, 0, True), fmt(s.balanced_obs, 0, True), fmt(s.pct_imputed, 1)]))
    return rows


A3SPECS = [("M1", "Centro + Belisario co-treated"), ("M3", "Belisario treated, Centro dropped"),
           ("M2", "Centro treated, Belisario dropped"), ("M2b", "Centro treated, Belisario retained"),
           ("M4", "Centro + Belisario co-treated"), ("M6", "Belisario treated, Centro dropped"),
           ("M5", "Centro treated, Belisario dropped"), ("M5b", "Centro treated, Belisario retained"),
           ("M7", "Centro + Belisario co-treated"), ("M9", "Belisario treated, Centro dropped"),
           ("M8", "Centro treated, Belisario dropped"), ("M8b", "Centro treated, Belisario retained")]


def ta3(run):
    rows = []
    for spec, _ in A3SPECS:
        est = [fmt(cs(run, "PM25", spec, w, "att_log"), 3) for w in WINS]
        fit = [fmt(cs(run, "PM25", spec, "pre_blackout", "rmspe_pre"), 3),
               fmt(cs(run, "PM25", spec, "pre_blackout", "ratio"), 2)]
        rows.append((spec, est + fit))
        conf = cs(run, "PM25", spec, "pre_blackout", "p_type") == "conformal"
        rows.append((spec + "|p", [f"({fmt(cs(run, 'PM25', spec, w, 'p_2s'), 3)})" if conf else "n.a." for w in WINS]))
    return rows


# ---- Block conformal p-values (step 2 diagnostics; computed for M7, M8, M8b, M9 in PM2.5 and M8b in the
# gases; not computed for M4, M5, M5b, M6, nor for SDID, which has no conformal inference)
BLK = {}
for _p in POLS:
    _b = pd.read_csv(os.path.join(NEW, "step2", "diagnostics", f"block_conformal_{_p}.csv"))
    for _, r in _b.iterrows():
        # same fit as the cross-sample table: the effect must match
        assert abs(r.att_log - cs("new", _p, r.spec, r["sample"], "att_log")) < 1e-9, (_p, r.spec, r["sample"])
        BLK[(_p, r.spec, r["sample"])] = (r.p_block, r.p_block_smallest)


def with_block(rows, cells_fn):
    """Insert a block-p row after each 'Conformal p' row (new run only)."""
    out = []
    for lab, cells in rows:
        if lab.endswith("|Conformal p"):          # relabelled "Conformal p (iid)" (Leonel, 2026-10-07)
            out.append((lab + " (iid)", cells))
        else:
            out.append((lab, cells))
        if lab.endswith("|Conformal p"):
            out.append((lab.replace("Conformal p", "Block conformal p"), cells_fn(lab.split("|")[0])))
    return out


def t5b():
    return with_block(t5("new"), lambda w: [fmt(BLK[("PM25", s_, w)][0], 3) for s_ in ["M7", "M9", "M8", "M8b"]])


def t7b():
    return with_block(t7("new"), lambda w: [fmt(BLK[(p_, "M8b", w)][0], 3) for p_ in POLS])


def ta3b():
    out = []
    for lab, cells in ta3("new"):
        out.append((lab, cells))
        if lab.endswith("|p"):
            spec = lab[:-2]
            if spec in ("M7", "M9", "M8", "M8b"):   # block p not computed for M4, M6, M5, M5b
                out.append((spec + "|b", [f"[{fmt(BLK[('PM25', spec, w)][0], 3)}]" for w in WINS]))
    return out


BLOCK_NOTE = (' Block conformal p-values use the T cyclic shifts of '
              'the weeks instead of 1,000 random permutations; they allow for serial dependence, and their smallest '
              'attainable value is 1/T (1/94 = 0.011 pre-disruption, 1/120 = 0.008 donut, 1/134 = 0.007 full). '
              'Iid conformal p-values use 1,000 random permutations; the smallest nonzero value is 0.001.')


# ---------------------------------------------------------------- self-check against the PDF text
NUM = re.compile(r"\(?-?\d[\d,]*\.?\d*\)?|n\.a\.")


def printed(line, label_regex):
    s = norm(TXT[line])
    s = re.sub(label_regex, " ", s, count=1)
    return NUM.findall(s)


def check_rows(name, frozen_rows, lines, label_regexes, allow=()):
    bad = []
    for (lab, cells), ln, rx in zip(frozen_rows, lines, label_regexes):
        got = printed(ln, rx)
        if got != cells and (name, lab) not in allow:
            bad.append((name, lab, ln, cells, got))
    return bad


bad = []
lab5 = r"^\s*(Log effect|Percent effect|Conformal p|Pre RMSPE|Post RMSPE|Post/pre RMSPE)"
bad += check_rows("Table 5", t5("old"), [644, 645, 646, 647, 648, 649, 651, 652, 653, 654, 655, 656,
                                          658, 659, 660, 661, 662, 663], [lab5] * 18)
bad += check_rows("Table 7", t7("old"), [737, 738, 739, 740, 741, 742, 744, 745, 746, 747, 748, 749,
                                          751, 752, 753, 754, 755, 756], [lab5] * 18)
bad += check_rows("Table 6", t6("old"), list(range(690, 698)),
                  [r"^\s*(Centro|Belisario|Guaman\S*|Cotocollao|Carapungo|Los Chillos|Tumbaco|San Antonio)"] * 8)
bad += check_rows("Table 3", t3("old"), [296, 297, 298, 299], [r"^\s*(PM2\.5|CO|NO2|SO2)"] * 4)
bad += check_rows("Table A.1", ta1("old"), [1175, 1176, 1177, 1178], [r"^\s*(PM2\.5|CO|NO2|SO2)"] * 4)
a3lines = []
for i in range(4):
    a3lines += [1236 + 2 * i, 1237 + 2 * i]
for i in range(4):
    a3lines += [1245 + 2 * i, 1246 + 2 * i]
for i in range(4):
    a3lines += [1254 + 2 * i, 1255 + 2 * i]
a3rx = [r"^\s*M\d+b?\s+[^\d]+?(?=\s-?\d)" if j % 2 == 0 else r"^$" for j in range(24)]
bad += check_rows("Table A.3", ta3("old"), a3lines, a3rx, allow={("Table A.3", "M8")})
# The allowed A.3 M8 row must differ only in the donut cell (-0.153 built, -0.154 printed)
m8 = [c for lab, c in ta3("old") if lab == "M8"][0]
m8p = printed(1258, a3rx[20])
assert m8p == [m8[0], "-0.154"] + m8[2:] and m8[1] == "-0.153", (m8, m8p)
if bad:
    for b in bad:
        print("MISMATCH", b)
    sys.exit("Frozen tables do not reproduce the printed paper; nothing written.")
print("Frozen tables reproduce every printed row (Tables 3, 5, 6, 7, A.1, A.3; A.3 M8 donut typo allowed).")

# ---------------------------------------------------------------- writers
WLAB = {"pre_blackout": "Panel A. Pre-disruption window: Nov. 27, 2023 to Sept. 9, 2024",
        "donut": "Panel B. Donut window: excluding Sept. 16 to Dec. 16, 2024",
        "full": "Panel C. Full post-opening window: Nov. 27, 2023 to June 2025"}
WLAB7 = {"pre_blackout": "Panel A. Pre-disruption window", "donut": "Panel B. Donut window",
         "full": "Panel C. Full post-opening window"}


def tex_escape(s):
    return s.replace("%", r"\%").replace("&", r"\&")


def write_table(name, caption, header, rows, notes, panels=None, csv_cols=None):
    """rows: list of (label, cells). panels: dict first-row-index -> panel title."""
    ncol = len(header)
    lines = [r"\begin{table}[htbp]\centering", r"\begin{threeparttable}", rf"\caption{{{caption}}}",
             r"\begin{tabular}{l" + "c" * (ncol - 1) + "}", r"\toprule",
             " & ".join(header) + r" \\", r"\midrule"]
    md = [f"### {caption}", "", "| " + " | ".join(header) + " |", "|" + "---|" * ncol]
    for i, (lab, cells) in enumerate(rows):
        if panels and i in panels:
            if i > 0:
                lines.append(r"\addlinespace")
            lines.append(rf"\multicolumn{{{ncol}}}{{l}}{{\textit{{{panels[i]}}}}} \\")
            md.append(f"| **{panels[i]}** |" + " |" * (ncol - 1))
        shown = lab.split("|")[-1] if not (lab.endswith("|p") or lab.endswith("|b")) else ""
        lines.append(" & ".join([tex_escape(shown)] + cells) + r" \\")
        md.append("| " + " | ".join([shown] + cells) + " |")
    lines += [r"\bottomrule", r"\end{tabular}", r"\begin{tablenotes}\footnotesize",
              rf"\item {tex_escape(re.sub(r'\s*\[[^\]]*\]', '', notes))}", r"\end{tablenotes}",
              r"\end{threeparttable}", r"\end{table}"]
    with open(os.path.join(OUT, f"{name}.tex"), "w") as fh:
        fh.write("\n".join(lines) + "\n")
    pd.DataFrame([[lab] + cells for lab, cells in rows],
                 columns=["row"] + (csv_cols or header[1:])).to_csv(os.path.join(OUT, f"{name}.csv"), index=False)
    md += ["", f"*Notes.* {notes}", ""]
    return "\n".join(md)


preview = ["# Paper tables on the step 2 outputs (preview)", "",
           "Generated by `code/local/step2/paper_tables.py`. New values only; the frozen values and "
           "changes are in `output/local/step2/paper_number_map.csv`.", ""]

# Table 1 (local column changes; the satellite column is the paper's, unchanged)
t1 = [("Treated unit", ["REMMAQ monitoring stations, with Centro as the main treated station",
                        "Quito urban center, UCDB identifier 2544"]),
      ("Comparison pool", ["Other REMMAQ stations reporting the same pollutant",
                           "Latin American urban areas ranked by similarity to Quito"]),
      ("Geographic unit", ["Monitoring station", "UCDB urban-center polygon"]),
      ("Pollutants", ["PM2.5, CO, NO2, SO2", "AOD, CO, NO2, SO2"]),
      ("Temporal resolution", ["Weekly averages of weekday peak-hour readings",
                               "Weekly satellite retrievals, aggregated to four-week blocks for estimation"]),
      ("Pre-treatment period", ["52 weeks before the opening week", "100 weeks before the opening week"]),
      ("Post-opening windows", ["Pre-disruption, donut, and full", "Pre-disruption, donut, and full"]),
      ("Panel size before estimation",
       [f"PM2.5: {int(SC['new'].loc['pm25', 'balanced_stations'])} stations x "
        f"{int(SC['new'].loc['pm25', 'balanced_weeks'])} weeks; gases: "
        f"{int(SC['new'].loc['co', 'balanced_stations'])} stations x {int(SC['new'].loc['co', 'balanced_weeks'])} weeks",
        "Pollutant-specific balanced panels, with 227 weekly observations per city"]),
      ("Primary role", ["Main test of localized air-quality effects near the historic center",
                        "Citywide benchmark for aggregate pollution changes in Quito"])]
preview.append(write_table(
    "table1", "Table 1. Local and citywide analyses at a glance",
    ["", "Local ground-monitor analysis", "Citywide satellite analysis"], t1,
    "Local PM2.5 covers all eight monitoring stations. CO, NO2, and SO2 cover seven stations because San Antonio "
    "does not report those series. The satellite panels are balanced separately by pollutant. "
    "[Only the local panel size changes; the satellite column is copied from the paper.]"))

preview.append(write_table(
    "table3", "Table 3. Estimation samples: balanced weekly panel composition by pollutant",
    ["Pollutant", "Stations", "Pre", "P1", "Blackout", "Trans.", "P2", "pre_blackout", "donut", "full"],
    [(p.replace("PM25", "PM2.5"), c) for p, c in t3("new")],
    "Balanced weekly panels of peak-hour, weekday pollutant concentrations. Peak hours are 07:00-09:00 and "
    "17:00-19:00. The pre-treatment period contains 52 weeks for all pollutants; treatment begins in ISO 2023-W48, "
    "the week containing the December 1, 2023 opening of Quito Metro Line 1. \"Blackout\" denotes the Phase 3 "
    "power-outage and wildfire disruption weeks, which are excluded from the donut sample and occur after the "
    "pre_blackout sample ends. \"Trans.\" is the post-outage transition fortnight in late December 2024. "
    "pre_blackout equals pre-treatment plus P1; donut equals the full sample minus blackout weeks; full uses all "
    "weeks. San Antonio is unavailable for CO, NO2, and SO2 and is dropped from those panels. Short station-level "
    "gaps of up to two weeks are linearly interpolated, and San Antonio's PM2.5 series is regression-imputed where "
    "needed; these observations are filled values, not absent weeks. [Footnote a on the 7-week PM2.5 gap is "
    "removed: the 2026-10-04 REMMAQ delivery has no such gap.]"))

panels18 = {0: WLAB["pre_blackout"], 7: WLAB["donut"], 14: WLAB["full"]}
preview.append(write_table(
    "table5", "Table 5. Local PM2.5 identification sequence",
    ["", "Centro + Belisario co-treated", "Belisario treated, Centro excluded",
     "Centro treated, Belisario excluded", "Centro treated, Belisario retained"], t5b(),
    "All specifications use augmented synthetic control with station fixed effects and meteorological controls. "
    "Effects are reported in logs and percent terms. p-values are two-sided conformal p-values. The preferred "
    "specification is the final column: Centro treated, Belisario retained in the donor pool. The table is ordered "
    "to distinguish a corridor-proximity interpretation from a destination-access interpretation. Belisario is "
    "first tested as a treated station with Centro excluded; after showing no comparable effect at Belisario, the "
    "preferred specification retains Belisario as the key donor for Centro. [Note text unchanged pending the "
    "Refine response; only Panel C's end date changes.]" + BLOCK_NOTE, panels=panels18))

preview.append(write_table(
    "table6", "Table 6. Spatial placebo estimates for PM2.5",
    ["Station", "Distance (km)", "Effect (%)", "Conformal p-value"], t6("new"),
    "Entries report leave-one-station-out placebo estimates for weekly peak-hour PM2.5 in the pre-disruption "
    "window. Each row treats the listed station as if it were exposed and uses the remaining stations as the "
    "donor pool; for Belisario, Centro is also excluded from the donor pool. Effects are estimated using augmented "
    "synthetic control with station fixed effects and meteorological controls. Distance is the straight-line "
    "distance from the monitoring station to the nearest Metro Line 1 stop. The p-values are two-sided conformal "
    "p-values (1,000 random permutations; smallest nonzero value 0.001). The rank-based placebo statistic is not "
    "used as the inferential test because the local placebo sample contains only eight stations. We also do not "
    "rank stations by post-to-pre fit ratios, because with eight stations those ratios can be sensitive to a "
    "single station's pre-period noise; the conformal procedure instead uses the full sequence of prediction "
    "errors. [Changed from the paper: the Belisario donor rule in the second sentence, and the floor in the "
    "fifth. Block p-values were not computed for the placebos.]"))

preview.append(write_table(
    "table7", "Table 7. Local pollutant effects at Centro", ["", "PM2.5", "CO", "NO2", "SO2"], t7b(),
    "All columns use the preferred local specification: Centro treated, Belisario retained in the donor pool, "
    "augmented synthetic control with station fixed effects and meteorological controls. Effects are reported in "
    "logs and percent terms. p-values are two-sided conformal p-values. Panel A is the primary local window and "
    "covers the post-opening period before the late-2024 blackout and wildfire disruption, from Nov. 27, 2023 to "
    "Sept. 9, 2024. Panel B excludes the disruption weeks, Sept. 16 to Dec. 16, 2024. Panel C retains all "
    "available post-opening weeks, through June 2025 for all four pollutants. Pre RMSPE is identical across panels "
    "within each pollutant because all three windows use the same pre-treatment period. PM2.5 is available for "
    "eight stations. CO, NO2, and SO2 are available for seven stations because San Antonio does not report these "
    "pollutants." + BLOCK_NOTE, panels={0: WLAB7["pre_blackout"], 7: WLAB7["donut"], 14: WLAB7["full"]}))

preview.append(write_table(
    "tableA1", "Table A.1. Local sample construction",
    ["Pollutant", "Stations", "Raw hourly", "Peak-hour", "Weekday peak-hour", "Balanced panel", "Imputed (%)"],
    [(p.replace("PM25", "PM2.5"), c) for p, c in ta1("new")],
    "The table reports non-missing observations at each step. Peak hours are 7-9 a.m. and 5-7 p.m.; weekday "
    "peak-hour observations restrict these to Monday through Friday. Balanced panel counts are station-week "
    "observations after weekly aggregation and limited imputation. All panels span 134 weeks, from the week of "
    "November 28, 2022 to the week of June 16, 2025. [Changed: the hourly counts now stop at the panels' end "
    "(week of June 16, 2025); the printed counts ran to the end of the earlier file, so part of the fall is a "
    "change of counting window.]"))

a3rows = []
CONF = dict(A3SPECS)
for lab, cells in ta3b():
    if lab.endswith("|p") or lab.endswith("|b"):
        a3rows.append((lab, cells + [""] * 2))
    else:
        a3rows.append((f"{lab} {CONF[lab]}" + ("\u2021" if lab == "M8b" else ""), cells))
preview.append(write_table(
    "tableA3", "Table A.3. Local PM2.5: full specification battery across estimators, treated-unit configurations, "
    "and windows", ["M / Configuration", "Pre-disruption\u2020", "Donut", "Full", "RMSPEpre", "Post/pre"], a3rows,
    "Each cell reports the treatment effect on log weekly peak-hour weekday PM2.5, with the two-sided p-value in "
    "parentheses beneath when valid inference is available. Every specification is re-estimated separately on each "
    "window. Rows are labeled by treated-unit configuration; the M code is retained for traceability and matches "
    "the estimation script. \u2020 Pre-disruption is the primary window, ending before the onset of the 2024 "
    "electricity-rationing and wildfire disruption. RMSPEpre is the pre-treatment root mean squared prediction "
    "error. The post-to-pre RMSPE ratio is reported for the pre-disruption window only. A ratio near or below one "
    "indicates little post-period divergence from the synthetic control, which is why the co-treated and "
    "Belisario-treated specifications are insignificant despite, in some cases, sizable point estimates. "
    "\u2021 Preferred specification: augmented synthetic control with station fixed effects, Centro treated with "
    "Belisario retained in the donor pool. This row is also the final column of the main identification table, "
    "Table 5. Panel A reports SDID point estimates only. We do not report p-values for the local SDID estimates "
    "because large-sample approximations are not credible with this small monitoring network, donor-placebo "
    "permutation inference is mechanically coarse, and conformal inference was not computed for SDID. The SDID "
    "estimates are therefore used only to assess robustness of sign and magnitude. Panels B and C use two-sided "
    "conformal inference. In Panel C, the block conformal p-value is in brackets beneath the iid p-value. "
    "Co-treated specifications pool Centro and Belisario into a single treated aggregate. Belisario-treated "
    "specifications place treatment on the more distant Belisario station and serve as placebo-style checks. "
    "All specifications condition on meteorology. The augmented synthetic control specifications adjust for "
    "meteorological covariates within the estimator. Synthetic difference-in-differences uses the "
    "meteorology-residualized log outcome. The fixed-effects distinction applies only to the augmented synthetic "
    "control panels." + BLOCK_NOTE + " [Changed from the paper: the block p-values and their description, and the "
    "floors. Block p-values were not computed for Panel B.]",
    panels={0: "Panel A. Synthetic difference-in-differences", 8: "Panel B. Augmented synthetic control, no station fixed effects",
            16: "Panel C. Augmented synthetic control with station fixed effects"}))

with open(os.path.join(OUT, "tables_preview.md"), "w") as fh:
    fh.write("\n".join(preview))

# Figures 2 and 5 were regenerated by the step 2 run; copy them under paper names
for src, dst in (("descriptives_time_series", "figure2"), ("fig_pm25_eventstudy", "figure5")):
    for ext in ("png", "pdf"):
        shutil.copyfile(os.path.join(NEW, "figures", f"{src}.{ext}"), os.path.join(OUT, f"{dst}.{ext}"))

# ---------------------------------------------------------------- text numbers
def K(kind, *a):
    return (kind,) + a


def value(key, run):
    kind = key[0]
    if kind == "cs":
        _, pol, spec, win, col = key
        return float(cs(run, pol, spec, win, col))
    if kind == "pl":
        _, st, col = key
        return float(PL[run].loc[st, col])
    if kind == "sc":
        _, pol, col = key
        return float(SC[run].loc[pol, col])
    if kind == "tl":
        _, per, pol = key
        return float(TL[run].loc[per, f"n_weeks_{pol}"])
    if kind == "range":                     # min and max of a list of keys
        vals = [value(k, run) for k in key[1]]
        return (min(vals), max(vals))
    if kind == "const":
        return key[1] if run == "old" else key[2]
    raise ValueError(key)


def show(v, digits, mode):
    if isinstance(v, tuple):
        vals = sorted(v, key=abs) if mode == "abs" else list(v)
        return " to ".join(show(x, digits, mode) for x in vals)
    if isinstance(v, str):
        return v
    if mode == "abs":
        v = abs(v)
    return fmt(v, digits, comma=(digits == 0 and abs(v) >= 1000))


def crosses(po, pn):
    return any((po <= t) != (pn <= t) for t in (0.05, 0.10))


M8B = lambda w, c: K("cs", "PM25", "M8b", w, c)
# (line, phrase as printed, quantity, key, digits, mode, p_key)
CUR = [
    (21, "0.130 log points", "M8b PM2.5 pre-disruption, log effect", M8B("pre_blackout", "att_log"), 3, "abs", M8B("pre_blackout", "p_2s")),
    (22, "12.2 percent", "M8b PM2.5 pre-disruption, percent", M8B("pre_blackout", "att_pct"), 1, "abs", M8B("pre_blackout", "p_2s")),
    (23, "nearly unchanged when later post-opening weeks are added", "M8b PM2.5 donut, percent (cited as nearly unchanged)", M8B("donut", "att_pct"), 1, "abs", M8B("donut", "p_2s")),
    (24, "only station with a statistically significant negative", "Spatial placebo: Centro p (M8b)", K("pl", "centro", "conf_p"), 3, "signed", K("pl", "centro", "conf_p")),
    (89, "about 12 percent", "M8b PM2.5 pre-disruption, percent", M8B("pre_blackout", "att_pct"), 0, "abs", M8B("pre_blackout", "p_2s")),
    (91, "unchanged when later post-opening weeks are added", "M8b PM2.5 donut, percent (cited as nearly unchanged)", M8B("donut", "att_pct"), 1, "abs", M8B("donut", "p_2s")),
    (94, "only station with a statistically significant negative", "Spatial placebo: Centro p (M8b)", K("pl", "centro", "conf_p"), 3, "signed", K("pl", "centro", "conf_p")),
    (210, "116 weeks", "PM2.5 balanced weeks (Table 1)", K("sc", "pm25", "balanced_weeks"), 0, "signed", None),
    (211, "134 weeks", "Gas balanced weeks (Table 1)", K("sc", "co", "balanced_weeks"), 0, "signed", None),
    (274, "March 2025", "PM2.5 panel end (data section)", K("const", "March 2025", "June 2025"), 0, "label", None),
    (274, "116 balanced station-weeks", "PM2.5 balanced weeks per station", K("sc", "pm25", "balanced_weeks"), 0, "signed", None),
    (275, "134 balanced station-weeks", "Gas balanced weeks per station", K("sc", "co", "balanced_weeks"), 0, "signed", None),
    (282, "3.0 percent of PM2.5", "PM2.5 imputed share (%)", K("sc", "pm25", "pct_imputed"), 1, "signed", None),
    (282, "1.0 percent of CO", "CO imputed share (%)", K("sc", "co", "pct_imputed"), 1, "signed", None),
    (282, "0.7 percent of NO2", "NO2 imputed share (%)", K("sc", "no2", "pct_imputed"), 1, "signed", None),
    (289, "1.3 percent of SO2", "SO2 imputed share (%)", K("sc", "so2", "pct_imputed"), 1, "signed", None),
    (301, "52 weeks", "Pre-treatment weeks (Table 3 note)", K("tl", "Pre-treatment", "pm25"), 0, "signed", None),
    (310, "7-week interior gap, from the week of January 13 to the week of February 24, 2025", "Table 3 footnote a (PM2.5 gap)", K("const", "7-week gap", "no gap: footnote obsolete"), 0, "label", None),
    (311, "January 6, 2025", "Table 3 footnote a (gap dates)", K("const", "January 6, 2025", "obsolete"), 0, "label", None),
    (312, "March 3, 2025", "Table 3 footnote a (gap dates)", K("const", "March 3, 2025", "obsolete"), 0, "label", None),
    (595, "0.130 log points", "M8b PM2.5 pre-disruption, log effect", M8B("pre_blackout", "att_log"), 3, "signed", M8B("pre_blackout", "p_2s")),
    (596, "0.132 log points", "M8b PM2.5 donut, log effect", M8B("donut", "att_log"), 3, "signed", M8B("donut", "p_2s")),
    (614, "17.0 percent", "M8 PM2.5 pre-disruption, percent", K("cs", "PM25", "M8", "pre_blackout", "att_pct"), 1, "abs", K("cs", "PM25", "M8", "pre_blackout", "p_2s")),
    (615, "14.2 percent", "M8 PM2.5 donut, percent", K("cs", "PM25", "M8", "donut", "att_pct"), 1, "abs", K("cs", "PM25", "M8", "donut", "p_2s")),
    (619, "12.2 percent", "M8b PM2.5 pre-disruption, percent", M8B("pre_blackout", "att_pct"), 1, "abs", M8B("pre_blackout", "p_2s")),
    (620, "0.011", "M8b PM2.5 pre-disruption, conformal p", M8B("pre_blackout", "p_2s"), 3, "signed", M8B("pre_blackout", "p_2s")),
    (621, "12.4 percent", "M8b PM2.5 donut, percent", M8B("donut", "att_pct"), 1, "abs", M8B("donut", "p_2s")),
    (621, "15.1", "M8b PM2.5 full, percent", M8B("full", "att_pct"), 1, "abs", M8B("full", "p_2s")),
    (625, "0.129", "M8b PM2.5 pre RMSPE", M8B("pre_blackout", "rmspe_pre"), 3, "signed", None),
    (625, "0.185 to 0.205", "Pre RMSPE of M7, M9, M8", K("range", [K("cs", "PM25", s, "pre_blackout", "rmspe_pre") for s in ("M7", "M9", "M8")]), 3, "signed", None),
    (626, "1.98", "M8b PM2.5 post/pre RMSPE, pre-disruption", M8B("pre_blackout", "ratio"), 2, "signed", None),
    (657, "Mar. 2025", "Table 5 Panel C end date", K("const", "Mar. 2025", "June 2025"), 0, "label", None),
    (676, "only station", "Spatial placebo: Centro p (M8b)", K("pl", "centro", "conf_p"), 3, "signed", K("pl", "centro", "conf_p")),
    (677, "12.2 percent", "Spatial placebo: Centro percent", K("pl", "centro", "att_pct"), 1, "abs", K("pl", "centro", "conf_p")),
    (678, "0.012", "Spatial placebo: Centro p", K("pl", "centro", "conf_p"), 3, "signed", K("pl", "centro", "conf_p")),
    (679, "8.5 percent", "Spatial placebo: Belisario percent (new donor rule)", K("pl", "belisario", "att_pct"), 1, "signed", K("pl", "belisario", "conf_p")),
    (683, "approaching conventional significance is Cotocollao", "Spatial placebo: Cotocollao p", K("pl", "cotocollao", "conf_p"), 3, "signed", K("pl", "cotocollao", "conf_p")),
    (709, "0.785", "Spatial placebo: Tumbaco p", K("pl", "tumbaco", "conf_p"), 3, "signed", K("pl", "tumbaco", "conf_p")),
    (720, "falls significantly in every window", "M8b PM2.5 donut p", M8B("donut", "p_2s"), 3, "signed", M8B("donut", "p_2s")),
    (720, "falls significantly in every window", "M8b PM2.5 full p", M8B("full", "p_2s"), 3, "signed", M8B("full", "p_2s")),
    (722, "0.089", "M8b NO2 pre RMSPE", K("cs", "NO2", "M8b", "pre_blackout", "rmspe_pre"), 3, "signed", None),
    (722, "1.02", "M8b NO2 post/pre RMSPE, pre-disruption", K("cs", "NO2", "M8b", "pre_blackout", "ratio"), 2, "signed", None),
    (725, "1.000", "M8b CO conformal p (all windows; pre shown)", K("cs", "CO", "M8b", "pre_blackout", "p_2s"), 3, "signed", K("cs", "CO", "M8b", "pre_blackout", "p_2s")),
    (727, "close to zero and statistically insignificant", "M8b SO2 pre-disruption, percent", K("cs", "SO2", "M8b", "pre_blackout", "att_pct"), 1, "signed", K("cs", "SO2", "M8b", "pre_blackout", "p_2s")),
    (729, "13.1 percent", "M8b SO2 donut, percent", K("cs", "SO2", "M8b", "donut", "att_pct"), 1, "signed", K("cs", "SO2", "M8b", "donut", "p_2s")),
    (729, "0.055", "M8b SO2 donut, conformal p", K("cs", "SO2", "M8b", "donut", "p_2s"), 3, "signed", K("cs", "SO2", "M8b", "donut", "p_2s")),
    (729, "10.0", "M8b SO2 full, percent", K("cs", "SO2", "M8b", "full", "att_pct"), 1, "signed", K("cs", "SO2", "M8b", "full", "p_2s")),
    (764, "Mar. 2025", "Table 7 note: PM2.5 end date", K("const", "Mar. 2025", "June 2025"), 0, "label", None),
    (779, "9.5 percent", "M5b PM2.5 pre-disruption, percent", K("cs", "PM25", "M5b", "pre_blackout", "att_pct"), 1, "abs", K("cs", "PM25", "M5b", "pre_blackout", "p_2s")),
    (779, "10.1 percent", "M5b PM2.5 donut, percent", K("cs", "PM25", "M5b", "donut", "att_pct"), 1, "abs", K("cs", "PM25", "M5b", "donut", "p_2s")),
    (780, "13.3 percent", "M5b PM2.5 full, percent", K("cs", "PM25", "M5b", "full", "att_pct"), 1, "abs", K("cs", "PM25", "M5b", "full", "p_2s")),
    (780, "all significant", "M5b PM2.5 donut p", K("cs", "PM25", "M5b", "donut", "p_2s"), 3, "signed", K("cs", "PM25", "M5b", "donut", "p_2s")),
    (780, "all significant", "M5b PM2.5 full p", K("cs", "PM25", "M5b", "full", "p_2s"), 3, "signed", K("cs", "PM25", "M5b", "full", "p_2s")),
    (785, "14.3 to 20.7 percent", "M2b (SDID) percent across windows (magnitudes)", K("range", [K("cs", "PM25", "M2b", w, "att_pct") for w in WINS]), 1, "abs", None),
    (785, "14.5 percent", "M2b (SDID) pre-disruption, percent", K("cs", "PM25", "M2b", "pre_blackout", "att_pct"), 1, "abs", None),
    (861, "12 percent", "M8b PM2.5 pre-disruption, percent (conclusion)", M8B("pre_blackout", "att_pct"), 0, "abs", M8B("pre_blackout", "p_2s")),
    (1046, "0.130 log points (p = 0.011)", "Figure 5 note: pre-disruption log effect", M8B("pre_blackout", "att_log"), 3, "signed", M8B("pre_blackout", "p_2s")),
    (1046, "0.132 log points (p = 0.041)", "Figure 5 note: donut log effect", M8B("donut", "att_log"), 3, "signed", M8B("donut", "p_2s")),
    (1046, "(p = 0.041)", "Figure 5 note: donut p", M8B("donut", "p_2s"), 3, "signed", M8B("donut", "p_2s")),
    (1047, "0.164 log points (p = 0.006)", "Figure 5 note: full log effect", M8B("full", "att_log"), 3, "signed", M8B("full", "p_2s")),
    (1047, "(p = 0.006)", "Figure 5 note: full p", M8B("full", "p_2s"), 3, "signed", M8B("full", "p_2s")),
    (1048, "only 6 PM2.5 weeks", "Figure 5 note: Period 2 PM2.5 weeks", K("tl", "Period 2 (post, post-blackout)", "pm25"), 0, "signed", None),
    (1048, "13 Jan", "Figure 5 note: PM2.5 gap dates", K("const", "gap 13 Jan to 24 Feb 2025", "no gap: sentence obsolete"), 0, "label", None),
    (1049, "24 Feb 2025, so the panel jumps from the week of 6 Jan 2025 to the week of 3 Mar 2025", "Figure 5 note: PM2.5 gap dates", K("const", "gap dates", "obsolete"), 0, "label", None),
    (1050, "the series in early 2025 marks this gap", "Figure 5 note: gap sentence", K("const", "gap", "obsolete"), 0, "label", None),
    (1181, "116 weeks", "Table A.1 note: PM2.5 weeks", K("sc", "pm25", "balanced_weeks"), 0, "signed", None),
    (1218, "only one that combines", "Appendix A.2: M8b donut p", M8B("donut", "p_2s"), 3, "signed", M8B("donut", "p_2s")),
    (1218, "only one that combines", "Appendix A.2: M5b donut p", K("cs", "PM25", "M5b", "donut", "p_2s"), 3, "signed", K("cs", "PM25", "M5b", "donut", "p_2s")),
]
SIGNED_KINDS = ("att_log", "att_pct")

rows = []
covered = {}
for ln, phrase, qty, key, d, mode, pkey in CUR:
    if norm(phrase) not in norm(TXT[ln]):
        sys.exit(f"Phrase not found on line {ln}: {phrase!r} | {TXT[ln]!r}")
    covered.setdefault(ln, []).append(norm(phrase))
    o, n = value(key, "old"), value(key, "new")
    so, sn = show(o, d, mode), show(n, d, mode)
    sign_change = (key[0] in ("cs", "pl") and key[-1] in SIGNED_KINDS and np.sign(o) != np.sign(n))
    pcross = False
    if pkey is not None:
        po, pn = value(pkey, "old"), value(pkey, "new")
        pcross = crosses(po, pn)
    reason = "; ".join([r for r, b in (("sign changes", sign_change),
                                       (f"p crosses 0.05 or 0.10 ({po:.3f} to {pn:.3f})" if pkey else "", pcross)) if b])
    rows.append(dict(line=ln, section="", phrase=phrase, quantity=qty, old=so, new=sn,
                     changed=so != sn, flag=bool(sign_change or pcross), flag_reason=reason,
                     status="mapped to a step 2 output", source=str(key)))

# Every other number in the text (tables, map labels and references excluded)
SECTIONS = [(1, 43, "Title and abstract"), (44, 127, "1 Introduction"), (128, 166, "2 Institutional background"),
            (167, 225, "3.1 Treatment timing (and Table 1)"), (226, 320, "3.2 Local data"),
            (321, 400, "3.3 Satellite data"), (401, 577, "4 Empirical strategy"), (578, 590, "5 Results"),
            (591, 632, "5.1 Local PM2.5"), (633, 717, "5.2 Spatial placebo"), (718, 788, "5.3 Local pollutants"),
            (789, 854, "5.4 Satellite"), (855, 925, "6 Conclusion"), (926, 1055, "Figure notes"),
            (1171, 1286, "Appendix")]
SKIP = [(253, 262), (293, 299), (341, 348), (640, 663), (688, 697), (734, 756), (824, 835), (870, 880),
        (926, 970), (1001, 1040), (1056, 1170), (1173, 1178), (1187, 1202), (1231, 1261)]
SAT = [(98, 106), (198, 215), (321, 400), (540, 567), (789, 854), (895, 901), (986, 1000), (1184, 1212)]
TOK = re.compile(r"(?<![\w.\-])-?\d+(?:,\d{3})*(?:\.\d+)?")


def section(ln):
    for a, b, s in SECTIONS:
        if a <= ln <= b:
            return s
    return ""


for r in rows:
    r["section"] = section(r["line"])
for ln in range(1, len(TXT)):
    if any(a <= ln <= b for a, b in SKIP):
        continue
    s = norm(TXT[ln])
    if re.fullmatch(r"\s*\d+\s*", s):                  # page numbers and bare footnote markers
        continue
    rest = s
    for ph in covered.get(ln, []):
        rest = rest.replace(ph, " ")
    for tok in TOK.findall(rest):
        sat = any(a <= ln <= b for a, b in SAT)
        rows.append(dict(line=ln, section=section(ln), phrase=s.strip()[:90], quantity=tok, old=tok, new=tok,
                         changed=False, flag=False, flag_reason="",
                         status=("unchanged: satellite part, not re-run" if sat else
                                 "unchanged: not a step 2 output (setting, design constant, date, method or citation)"),
                         source=""))

tn = pd.DataFrame(rows).sort_values(["line"], kind="stable")
tn.to_csv(os.path.join(OUT, "text_numbers.csv"), index=False)
mapped = tn[tn.status == "mapped to a step 2 output"]
print(f"text_numbers.csv: {len(tn)} rows; mapped {len(mapped)}, changed {int(mapped.changed.sum())}, "
      f"flagged {int(tn.flag.sum())}")
print(mapped[mapped.flag][["line", "phrase", "quantity", "old", "new", "flag_reason"]].to_string(index=False))
# For review: unmapped tokens in the local-results sections
loc = tn[(tn.status != "mapped to a step 2 output") &
         tn.section.isin(["Title and abstract", "3.2 Local data", "5.1 Local PM2.5", "5.2 Spatial placebo",
                          "5.3 Local pollutants", "Figure notes", "Appendix"])]
print("\nUnmapped numbers in local sections (should be constants, dates or citations):")
print(loc[["line", "quantity", "phrase"]].to_string(index=False))
