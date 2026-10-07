"""
ridership_test.py
The pre-specified test of air_quality/docs/revision_plan.md, section 3C
(approved by Leonel on 2026-10-06, to run as written on December 2023 to May
2025, the last month Metro de Quito delivered): San Francisco station's share
of monthly metro entries against Centro's monthly PM2.5 gap (M8b).

Inputs
  Metro de Quito validations (store, read-only):
    air_quality/data/metro_validaciones_2026-10-05 (committed symlink into the store)
    "Información BID.xlsx", sheet 1: monthly validations by station (15 stations)
    "punto 3 Información BID v2.xlsx": validations by day, hour, access medium and station
  Committed gaps: output/local/step2/diagnostics/gaps_M8b_full_PM25.csv (606ea82)

Steps
  1. Check that the monthly station totals equal the hourly file summed by
     station and month (reported for all rows and by the EMPRESA column).
  2. Outcome: monthly mean of the weekly gaps, weeks assigned to the month of
     their start date (the opening week, starting 2023-11-27, to December 2023),
     blackout weeks excluded, December 2023 to May 2025; October and November
     2024 have no non-blackout week and drop out, so M = 16 months.
  3. Predictor: San Francisco's share of monthly system entries (primary) and
     log San Francisco entries (secondary), from the monthly station sheet.
  4. Statistic: Spearman correlation, two-sided, sign first.
  5. Inference: (i) station placebo, San Francisco's rank among the 15 stations'
     correlations by absolute value, p = rank / 15 (smallest 1/15 = 0.067);
     (ii) cyclic shifts of the monthly ridership series against the gap series,
     M shifts including the original, p = share with |rho| >= observed
     (smallest 1/M = 1/16 = 0.0625).
  6. Decision rule (3C): supports the mechanism only if the primary correlation
     is negative and San Francisco ranks first or second most negative among
     the 15 stations.
  7. Robustness (3C): the same on month-to-month first differences. Decided
     here before computing, because 3C does not say how to difference across
     the dropped months: differences only between calendar-adjacent months
     (September 2024 to December 2024 is not differenced), so 14 differences.

Data-source check (added 2026-10-06 after step 1 found that the two files
swap some stations' totals in December 2023, January 2024 and December 2024,
including San Francisco in December 2023): the primary and secondary tests are
repeated with monthly totals taken from the hourly file. The result of record
is the monthly station sheet, the source chosen before any result was seen.

Run from anywhere:  python3 code/local/step2/ridership_test.py   (pandas, numpy, openpyxl)
Outputs (aggregates only): output/local/step2/ridership/
"""
import os
import sys
import numpy as np
import pandas as pd

AQ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
RAW = os.path.join(AQ, "data", "metro_validaciones_2026-10-05")   # committed symlink into the store
GAPS = os.path.join(AQ, "output", "local", "step2", "diagnostics", "gaps_M8b_full_PM25.csv")
OUT = os.path.join(AQ, "output", "local", "step2", "ridership")
for p in (RAW, GAPS):
    if not os.path.exists(p):
        sys.exit(f"Missing input: {p}")
os.makedirs(OUT, exist_ok=True)

# Station names: monthly sheet -> hourly file
NAMES = {"Quitumbe (Intermodal)": "Quitumbe", "Labrador (Intermodal)": "Labrador", "Iñaquito": "Iñaquito",
         "San Francisco": "San Francisco", "Recreo (Intermodal)": "El Recreo", "Moran Valverde": "Moran Valverde",
         "Universidad Central (Intermodal)": "Universidad", "Ejido": "El Ejido", "Carolina": "La Carolina",
         "Magdalena (Intermodal)": "La Magdalena", "Solanda": "Solanda", "Alameda": "La Alameda",
         "Jipijapa": "Jipijapa", "Cardenal de la Torre": "Cardenal de la Torre", "Pradera": "La Pradera"}

# ---- 1. Monthly station sheet and the totals check
m = pd.read_excel(os.path.join(RAW, "Información BID.xlsx"), sheet_name=0, header=0)
m = m[m["No."].astype(str) != "Total"].copy()
month_cols = [c for c in m.columns if isinstance(c, pd.Timestamp) or hasattr(c, "year")]
assert len(m) == 15 and len(month_cols) == 18, (len(m), len(month_cols))
assert set(m["Estación"]) == set(NAMES)
tot_col = [c for c in m.columns if str(c).strip() == "Total"]
assert len(tot_col) == 1 and (m[month_cols].sum(axis=1).values == m[tot_col[0]].values).all()
monthly = m.melt(id_vars=["Estación"], value_vars=month_cols, var_name="month", value_name="entries")
monthly["month"] = pd.to_datetime(monthly["month"]).dt.to_period("M")
monthly["station"] = monthly["Estación"].map(NAMES)

h = pd.read_excel(os.path.join(RAW, "punto 3 Información BID v2.xlsx"), sheet_name=0)
h["month"] = pd.PeriodIndex.from_fields(year=h["AÑO"], month=h["MES"], freq="M")
assert set(h["month"]) == set(monthly["month"])
assert set(h["ESTACION"]) == set(NAMES.values())
chk = monthly[["station", "month", "entries"]].copy()
hall = h.groupby(["ESTACION", "month"])["VALIDATIONS_NUM"].sum().rename("hourly_all")
chk = chk.merge(hall, left_on=["station", "month"], right_index=True, how="left")
for emp in sorted(h["EMPRESA"].unique()):
    he = h[h["EMPRESA"] == emp].groupby(["ESTACION", "month"])["VALIDATIONS_NUM"].sum().rename(f"hourly_{emp}")
    chk = chk.merge(he, left_on=["station", "month"], right_index=True, how="left")
chk["diff_all"] = chk["hourly_all"] - chk["entries"]
chk["month"] = chk["month"].astype(str)
chk.to_csv(os.path.join(OUT, "totals_check_station_month.csv"), index=False)
n_equal = int((chk["diff_all"] == 0).sum())
print(f"Totals check: {n_equal} of {len(chk)} station-months equal (hourly file, all rows, against monthly sheet); "
      f"max abs diff {int(chk['diff_all'].abs().max())}; sum monthly {int(chk['entries'].sum())}, "
      f"sum hourly {int(chk['hourly_all'].sum())}")
for emp in sorted(h["EMPRESA"].unique()):
    print(f"  EMPRESA {emp}: total {int(chk[f'hourly_{emp}'].fillna(0).sum())}")

# ---- 2. Outcome: monthly mean gap
g = pd.read_csv(GAPS, parse_dates=["week_date"])
g = g[(~g["pre"]) & (~g["blackout"])].copy()
g["month"] = g["week_date"].dt.to_period("M")
g.loc[g["week_date"] == pd.Timestamp("2023-11-27"), "month"] = pd.Period("2023-12", "M")
g = g[(g["month"] >= pd.Period("2023-12", "M")) & (g["month"] <= pd.Period("2025-05", "M"))]
gap = g.groupby("month").agg(gap_mean=("gap", "mean"), weeks=("gap", "size"))
M = len(gap)
assert M == 16 and pd.Period("2024-10", "M") not in gap.index and pd.Period("2024-11", "M") not in gap.index

# ---- 3. Predictors for every station
wide = monthly.pivot(index="month", columns="station", values="entries").loc[gap.index]
share = wide.div(wide.sum(axis=1), axis=0)
logn = np.log(wide)


def spearman(a, b):
    return pd.Series(a).rank().corr(pd.Series(b).rank())


def tests(y, X, adjacent_only=False):
    """y: Series (months); X: DataFrame (months x stations). Returns rows per station."""
    if adjacent_only:
        idx = y.index
        keep = [i for i in range(1, len(idx)) if (idx[i] - idx[i - 1]).n == 1]
        y = pd.Series([y.iloc[i] - y.iloc[i - 1] for i in keep], index=[idx[i] for i in keep])
        X = pd.DataFrame({c: [X[c].iloc[i] - X[c].iloc[i - 1] for i in keep] for c in X.columns}, index=y.index)
    rho = {c: spearman(y.values, X[c].values) for c in X.columns}
    n = len(y)
    sf = rho["San Francisco"]
    assert np.isfinite(sf) and all(np.isfinite(list(rho.values())))
    shifts = [spearman(y.values, np.roll(X["San Francisco"].values, k)) for k in range(n)]
    p_cyc = float(np.mean([abs(s) >= abs(sf) - 1e-12 for s in shifts]))
    # ties count against San Francisco, as in the cyclic test
    absrank = 1 + sum(abs(r) >= abs(sf) - 1e-12 for c, r in rho.items() if c != "San Francisco")
    negrank = 1 + sum(r <= sf + 1e-12 for c, r in rho.items() if c != "San Francisco")
    return dict(n_months=n, rho_sf=sf, p_station=absrank / len(rho), p_station_smallest=1 / len(rho),
                sf_rank_abs=absrank, sf_rank_most_negative=negrank, p_cyclic=p_cyc, p_cyclic_smallest=1 / n,
                supports=bool(sf < 0 and negrank <= 2)), rho


hw = h.groupby(["month", "ESTACION"])["VALIDATIONS_NUM"].sum().unstack().loc[gap.index]
assert hw.notna().all().all() and (hw > 0).all().all()
hshare, hlog = hw.div(hw.sum(axis=1), axis=0), np.log(hw)

res, rhos = [], []
for src, name, X, diff in (("monthly sheet", "primary: share, levels", share, False),
                           ("monthly sheet", "secondary: log entries, levels", logn, False),
                           ("monthly sheet", "robustness: share, first differences", share, True),
                           ("monthly sheet", "robustness: log entries, first differences", logn, True),
                           ("hourly file (data-source check)", "primary: share, levels", hshare, False),
                           ("hourly file (data-source check)", "secondary: log entries, levels", hlog, False)):
    r, rho = tests(gap["gap_mean"], X, diff)
    res.append(dict(source=src, test=name, **r))
    rhos += [dict(source=src, test=name, station=c, rho=v) for c, v in rho.items()]
res = pd.DataFrame(res)
res.to_csv(os.path.join(OUT, "ridership_test_results.csv"), index=False)
pd.DataFrame(rhos).to_csv(os.path.join(OUT, "ridership_station_placebo.csv"), index=False)
series = gap.copy()
series["sf_entries"] = wide["San Francisco"]
series["system_entries"] = wide.sum(axis=1)
series["sf_share"] = share["San Francisco"]
series["sf_share_hourly_file"] = hshare["San Francisco"]
series.index = series.index.astype(str)
series.to_csv(os.path.join(OUT, "ridership_test_series.csv"))
pd.set_option("display.width", 200)
print(series.round(4).to_string())
print(res.round(4).to_string(index=False))
