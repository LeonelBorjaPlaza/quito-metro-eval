#!/usr/bin/env python3
"""Replication gate: compare regenerated air quality tables with their frozen copies.

Usage:
  python3 compare_outputs.py <checkout air_quality dir> <frozen dir> <run start epoch> <out prefix>

For every CSV (and text log) under output/local/ and data/processed/ in the frozen reference that a
script in the repository produces, find the regenerated file in the checkout and compare:
  - a missing file, or one older than the run start, is a FAILURE;
  - rows and columns must match (names and counts); a mismatch is a FAILURE;
  - cells are aligned by row position and column name;
  - integers must match exactly; other numbers are classed by absolute difference:
    identical (0), noise (<= 1e-6), small (<= 1e-3), material (> 1e-3);
  - p-value columns (rank-based permutation and conformal) must match exactly; any difference is material;
  - text cells must match exactly; a text cell that embeds numbers (for example donor weight strings)
    is compared number by number when its non-numeric skeleton matches;
  - one NA and one value is material.
Figures (PNG, PDF) are only checked for existence and freshness, not content.

Writes <out prefix>_files.csv (one row per file) and <out prefix>_columns.csv (one row per differing
column) and prints a summary. Reads only; never modifies either tree.
"""
import csv
import math
import os
import re
import sys

import pandas as pd

AQ, FROZEN, START, OUT = sys.argv[1], sys.argv[2], float(sys.argv[3]), sys.argv[4]

# Frozen files that no script in the repository produces (see RUNBOOK.md).
NO_PRODUCER = {
    "output/local/blackout_comparison/augsynth_vs_sdid_comparison.csv",
    "output/local/blackout_comparison/sdid_blackout_comparison.pdf",
    "output/local/blackout_comparison/sdid_blackout_comparison.png",
    "output/local/tables.zip",
    "output/local/figures/descriptives_time_series_edit.png",
    "output/local/spatial_placebo/spatial_placebo_PM25_M8b_noCentroDonor.pdf",
}
PVAL = re.compile(r"^(p_1s|p_2s|p_2s_perm|conf_p|p_val|p_value|pval)$", re.I)
NUM = re.compile(r"[-+]?(?:\d+\.\d*|\.\d+|\d+)(?:[eE][-+]?\d+)?")
ORDER = ["identical", "noise", "small", "material"]


def klass(d):
    if d == 0:
        return "identical"
    if d <= 1e-6:
        return "noise"
    if d <= 1e-3:
        return "small"
    return "material"


def is_na(s):
    return s is None or (isinstance(s, float) and math.isnan(s)) or str(s).strip() in ("", "NA", "NaN", "nan")


def to_float(s):
    try:
        return float(s)
    except (TypeError, ValueError):
        return None


def compare_cell(a, b, pcol):
    """Return (class, absolute difference or None, kind)."""
    if is_na(a) and is_na(b):
        return "identical", 0.0, "na"
    if is_na(a) or is_na(b):
        return "material", None, "na-mismatch"
    if a == b:
        return "identical", 0.0, "exact"
    fa, fb = to_float(a), to_float(b)
    if fa is not None and fb is not None:
        if math.isinf(fa) or math.isinf(fb):
            return ("identical", 0.0, "num") if fa == fb else ("material", None, "inf")
        d = abs(fa - fb)
        is_int = re.fullmatch(r"[-+]?\d+", a.strip()) and re.fullmatch(r"[-+]?\d+", b.strip())
        if is_int and d != 0:
            return "material", d, "integer"
        if pcol and d != 0:
            return "material", d, "p-value"
        return klass(d), d, "num"
    # text: compare embedded numbers if the skeleton matches
    if NUM.sub("#", a) == NUM.sub("#", b):
        na, nb = [float(x) for x in NUM.findall(a)], [float(x) for x in NUM.findall(b)]
        d = max((abs(x - y) for x, y in zip(na, nb)), default=0.0)
        return klass(d), d, "text-embedded-numbers"
    return "material", None, "text"


def compare_csv(fa, fb):
    """fa frozen, fb regenerated."""
    A = pd.read_csv(fa, dtype=str, keep_default_na=False)
    B = pd.read_csv(fb, dtype=str, keep_default_na=False)
    res = {"rows_frozen": len(A), "rows_new": len(B), "cols_frozen": len(A.columns), "cols_new": len(B.columns)}
    cols = []
    if list(A.columns) != list(B.columns) or len(A) != len(B):
        res["structure"] = "MISMATCH"
        res["missing_cols"] = ";".join(c for c in A.columns if c not in B.columns)
        res["extra_cols"] = ";".join(c for c in B.columns if c not in A.columns)
    else:
        res["structure"] = "same"
    common = [c for c in A.columns if c in B.columns]
    n = min(len(A), len(B))
    worst = "identical"
    maxd = 0.0
    for c in common:
        pcol = bool(PVAL.match(c))
        cw, cmax, ndiff, kinds, example = "identical", 0.0, 0, set(), ""
        for i in range(n):
            k, d, kind = compare_cell(A[c].iat[i], B[c].iat[i], pcol)
            if k != "identical":
                ndiff += 1
                kinds.add(kind)
                if ORDER.index(k) > ORDER.index(cw):
                    cw = k
                if d is not None:
                    cmax = max(cmax, d)
                if not example:
                    example = f"row {i + 2}: frozen={A[c].iat[i][:60]!r} new={B[c].iat[i][:60]!r}"
        if ndiff:
            cols.append({"column": c, "p_value_column": pcol, "cells_differing": ndiff, "class": cw,
                         "max_abs_diff": cmax, "kinds": ";".join(sorted(kinds)), "first_example": example})
        if ORDER.index(cw) > ORDER.index(worst):
            worst = cw
        maxd = max(maxd, cmax)
    if res["structure"] != "same":
        worst = "material"
    res["class"] = worst
    res["max_abs_diff"] = maxd
    return res, cols


def main():
    files, colrows = [], []
    for root, _, names in os.walk(FROZEN):
        for nme in names:
            full = os.path.join(root, nme)
            rel = os.path.relpath(full, FROZEN)
            if not (rel.startswith("output/local/") or rel.startswith("data/processed/") or rel.startswith("output/maps/")):
                continue
            if rel.startswith("data/processed/satellite/"):
                continue
            row = {"file": rel, "status": "", "class": "", "max_abs_diff": "", "rows_frozen": "", "rows_new": "",
                   "cols_frozen": "", "cols_new": "", "structure": "", "note": ""}
            if rel in NO_PRODUCER:
                row.update(status="not regenerable", note="no script in the repository writes this file")
                files.append(row)
                continue
            new = os.path.join(AQ, rel)
            if not os.path.exists(new):
                row.update(status="FAIL", note="expected file not produced by this run")
                row["class"] = "missing"
                files.append(row)
                continue
            if os.path.getmtime(new) < START:
                row.update(status="FAIL", note="file older than the run start")
                row["class"] = "stale"
                files.append(row)
                continue
            if rel.endswith(".csv") or rel.endswith(".txt"):
                if rel.endswith(".txt"):
                    same = open(full, encoding="utf-8", errors="replace").read().replace("\r\n", "\n") == \
                        open(new, encoding="utf-8", errors="replace").read().replace("\r\n", "\n")
                    row.update(status="compared", note="text log compared line by line (CRLF ignored)",
                               **{"class": "identical" if same else "differs (see diff)"})
                else:
                    res, cols = compare_csv(full, new)
                    row.update(status="compared", **{k: v for k, v in res.items() if k in row})
                    for c in cols:
                        colrows.append({"file": rel, **c})
                    if res.get("structure") != "same":
                        row["note"] = f"missing cols: {res.get('missing_cols', '')}; extra cols: {res.get('extra_cols', '')}"
            else:
                row.update(status="produced", note="figure or binary; existence and freshness only", **{"class": "n/a"})
            files.append(row)
    files.sort(key=lambda r: r["file"])
    with open(OUT + "_files.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(files[0].keys()))
        w.writeheader()
        w.writerows(files)
    with open(OUT + "_columns.csv", "w", newline="") as f:
        fields = ["file", "column", "p_value_column", "cells_differing", "class", "max_abs_diff", "kinds", "first_example"]
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(colrows)
    from collections import Counter
    print(Counter((r["status"], r["class"]) for r in files))
    for r in files:
        if r["status"] in ("FAIL",) or r["class"] in ("material", "small", "differs (see diff)"):
            print(f"{r['status']:10s} {r['class']:10s} {str(r['max_abs_diff'])[:10]:>10s}  {r['file']}  {r['note']}")


if __name__ == "__main__":
    main()
