#!/usr/bin/env python3
"""Phase 3 of the consolidation: classify every ignored or data file in both sources.

Reads the source repositories without writing to them (git --no-optional-locks).
Writes reports/migration/03_data_map.csv with one row per file:
source, module, source_path, git_status, size_bytes, sha256, class, new_location, evidence.

Classes:
  raw          no script in the module writes it (inputs). Copied to DATA_STORE/<module>/raw/<same relative path>.
  derived      a script in the module writes it. Copied to DATA_STORE/<module>/frozen_<date>/<same relative path>.
  output       tables, figures and logs in the output folders, tracked or not. Copied to frozen_<date>/.
  delivery     a copy of one of the two new deliveries found inside a source. Stored once in the dated delivery folder.
  environment  package libraries, IDE state, shell history. Not data; not copied to the store.

Usage: python3 reports/migration/03_classify_data.py  (settings come from the environment, see settings.env)
"""
import csv
import hashlib
import os
import re
import subprocess
import sys

AQ_SRC = os.environ["AQ_SRC"]
WAZE_SRC = os.environ["WAZE_SRC"]
NEW_DATA = os.environ["NEW_DATA"]
DATA_STORE = os.environ["DATA_STORE"]
OUT = sys.argv[1] if len(sys.argv) > 1 else "reports/migration/03_data_map.csv"

FROZEN = {"air_quality": "frozen_2026-05-29", "congestion": "frozen_2026-09-17"}
AQ_DELIVERY = "air_quality/raw/2026-09-07_secretaria_ambiente_pm25_gapfill"
RS_DELIVERY = "road_safety/raw/2026-09-23_amt_siniestros"
CODE_EXT = re.compile(r"\.(R|Rmd|qmd|py|ipynb|sql|do|sh|md|tex|bib|txt|yml|yaml|json|toml)$")
DATA_EXT = re.compile(r"\.(csv|tsv|xlsx|xls|dta|sav|rds|rda|RData|parquet|feather|gpkg|shp|shx|dbf|prj|cpg|qmd|geojson|nc|tif|zip|msg|pdf|png|log)$", re.I)


def git_list(src, args, aq):
    base = ["git", "--no-optional-locks"]
    if aq:
        base += ["-c", "core.autocrlf=true", "-c", "core.filemode=false"]
    out = subprocess.run(base + ["-C", src] + args + ["-z"], check=True, capture_output=True).stdout
    return [p for p in out.decode("utf-8").split("\0") if p]


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 22), b""):
            h.update(chunk)
    return h.hexdigest()


def new_data_hashes():
    return {sha256(os.path.join(NEW_DATA, f)): f for f in os.listdir(NEW_DATA)}


# ---------------------------------------------------------------- air quality
AQ_ENV_PREFIXES = (".venv/", "renv/library/", ".Rproj.user/", ".claude/")
AQ_ENV_FILES = {".Rhistory", "code/.Rhistory", "code/satellite/.Rhistory"}
SAT_WRITERS = {
    "aod_weekly.csv": "code/satellite/python/02b_merge.py:126 writes data/processed/satellite/<pollutant>_weekly.csv",
    "co_weekly.csv": "code/satellite/python/02b_merge.py:126",
    "no2_weekly.csv": "code/satellite/python/02b_merge.py:126",
    "so2_weekly.csv": "code/satellite/python/02b_merge.py:126",
    "era5l_weekly.csv": "code/satellite/python/02b_merge.py:126 (POLLUTANTS includes era5l)",
    "era5l_cleaned.csv": "code/satellite/laptop_R/03_clean_era5.R:39,178",
    "panel_aod.csv": "code/satellite/laptop_R/04_aod_panel.R:41,269",
    "panel_co.csv": "code/satellite/laptop_R/04_co_panel.R:40,250",
    "panel_no2.csv": "code/satellite/laptop_R/04_no2_panel.R:37,247",
    "panel_so2.csv": "code/satellite/laptop_R/04_so2_panel.R:51,268",
}
LOCAL_WRITERS = {
    "hourly_panel.csv": "code/local/01_read_and_merge.R:382",
    "pm25_completepanel_peakweekly.csv": "code/local/02_build_weekly_panels.R:462",
    "CO_completepanel_peakweekly.csv": "code/local/02_build_weekly_panels.R:473",
    "NO2_completepanel_peakweekly.csv": "code/local/02_build_weekly_panels.R:484",
    "SO2_completepanel_peakweekly.csv": "code/local/02_build_weekly_panels.R:494",
}
REMMAQ_READ = {"PM2.5", "CO", "NO2", "SO2", "TMP", "HUM", "VEL", "DIR", "LLU", "RS", "PRE"}


def classify_aq(p, nd):
    """Return (class, relative store location or note, evidence)."""
    if p.startswith(AQ_ENV_PREFIXES) or p in AQ_ENV_FILES:
        return "environment", "", "package library, IDE state, local settings or shell history; not data"
    if p == ".RData":
        return "derived", None, "R workspace saved by an interactive session of the 03/04 scripts (holds df, att_weekly, m1..m9); no script needed to rebuild it"
    if p.startswith("data/traffic-accidents/") or p.startswith("data/raw/remmaq/DATOSFALTANTES") or p.startswith("data/raw/remmaq/Solicitud"):
        dest = RS_DELIVERY if p.startswith("data/traffic-accidents/") else AQ_DELIVERY
        return "delivery", dest, "copy of a new delivery found inside AQ_SRC; not read by any script"
    if p.startswith("data/raw/"):
        name = os.path.basename(p)
        if p.startswith("data/raw/remmaq/") and name.endswith(".xlsx") and name[:-5] in REMMAQ_READ:
            ev = "read by code/local/01_read_and_merge.R:129-141; no script writes data/raw/"
        elif p.startswith("data/raw/satellite/"):
            ev = "Earth Engine export read by code/satellite/python/02b_merge.py:46,57; no script writes data/raw/"
        elif p.startswith("data/raw/GHS_UCDB/"):
            ev = "external GHS-UCDB release read by code/satellite/python/01_geometries_ucdb.py:52 and laptop_R/01b_donor_pool_selection.py:32; no writer"
        else:
            ev = "no script writes data/raw/ (grep of write calls in code/)"
        return "raw", None, ev
    if p.startswith("data/for_maps/"):
        return "raw", None, "read by code/local/fig1_metro_airquality_map.R:41,66; no writer"
    if p.startswith("data/processed/satellite/"):
        name = os.path.basename(p)
        if name in SAT_WRITERS:
            return "derived", None, SAT_WRITERS[name]
        if re.match(r"panel_(aod|co|no2|so2)_balanced\.csv$", name):
            return "derived", None, "code/satellite/laptop_R/05_balance_panels.R:52,103 (also cloud_R/balance_panels_archive.R:45,107)"
        if name.endswith(".dta"):
            return "raw", None, "Stata-era file; no script in the module writes .dta (no write_dta or save in code/); classed raw by the when-in-doubt rule"
        return "raw", None, "no writer found; classed raw by the when-in-doubt rule"
    if p.startswith("data/processed/"):
        name = os.path.basename(p)
        if name in LOCAL_WRITERS:
            return "derived", None, LOCAL_WRITERS[name]
        return "raw", None, "no writer found; classed raw by the when-in-doubt rule"
    if p.startswith("data/working/"):
        name = os.path.basename(p)
        if name.startswith("ucdb_lac."):
            return "derived", None, "code/satellite/python/01_geometries_ucdb.py:59-60,106,109 writes ucdb_lac.geojson and the ucdb_lac shapefile set"
        if re.match(r"(donor_ids_top\d+|donor_pool_top\d+|donor_pool_balance_table|ucdb_donor_distances_all)\.csv$", name):
            return "derived", None, "code/satellite/laptop_R/01b_donor_pool_selection.py:34,329-397 writes it to data/working/"
        return "raw", None, "no writer found in code/ (grep for the file name); classed raw by the when-in-doubt rule"
    if p.startswith("output/"):
        return "output", None, "file in an output folder"
    return "raw", None, "no writer found; classed raw by the when-in-doubt rule"


# ---------------------------------------------------------------- congestion
def classify_waze(p):
    if p.startswith("Output/Waze/_environment/"):
        return "environment", "", "project-local R library, package archives and duckdb h3 extension; not data"
    if p.startswith("Data/Waze/raw/"):
        return "raw", None, "Waze delivery read by Scripts/Congestion/inventory_helpers.R:12-14 and 00_orient.R:55-56; no writer"
    if p.startswith("Data/spatial/"):
        return "raw", None, "read by Scripts/Congestion/inventory_helpers.R:63-65, 02_descriptives.R:116-118, 00_orient.R:41-44; no writer"
    if p.startswith("Data/Waze/parquet/"):
        return "derived", None, "Scripts/Congestion/02_prepare_blocks.R:21 (COPY ... TO the deduplicated blocks and manifest)"
    if p == "reports/waze_sample.csv":
        return "derived", None, "Scripts/Congestion/01_inventory.R:173 (500 record-level rows sampled from the raw delivery)"
    if p.startswith("docs/paper/"):
        return "raw", None, "copy of the air quality paper and its output tables; no script in congestion writes it"
    if p.startswith("Output/"):
        return "output", None, "file in an output folder"
    return "raw", None, "no writer found; classed raw by the when-in-doubt rule"


def rows_for(src, module, aq, nd):
    tracked = set(git_list(src, ["ls-files"], aq))
    ignored = set(git_list(src, ["ls-files", "--others", "--ignored", "--exclude-standard"], aq))
    untracked = set(git_list(src, ["ls-files", "--others", "--exclude-standard"], aq))
    cand = []
    for p in sorted(ignored):
        cand.append((p, "ignored"))
    for p in sorted(untracked):
        if p.startswith("output/") or not CODE_EXT.search(p):
            cand.append((p, "untracked"))
    for p in sorted(tracked):
        if p.startswith(("data/", "Data/", "output/", "Output/", "docs/paper/")) or DATA_EXT.search(p):
            if not p.endswith(".gitkeep") and (p.startswith(("data/raw/", "Data/")) or not p.endswith(".md")):
                cand.append((p, "tracked"))
    env_totals = {}
    rows = []
    for p, st in cand:
        full = os.path.join(src, p)
        if not os.path.isfile(full):
            continue
        size = os.path.getsize(full)
        klass, loc, ev = classify_aq(p, nd) if aq else classify_waze(p)
        if klass == "environment":
            top = "/".join(p.split("/")[:2]) + "/" if "/" in p else p
            if p.startswith(("renv/library/", "Output/Waze/_environment/")):
                top = "/".join(p.split("/")[:3]) + "/"
            n, s, e = env_totals.get(top, (0, 0, ev))
            env_totals[top] = (n + 1, s + size, ev)
            continue
        h = sha256(full)
        if klass == "delivery":
            if h in nd:
                loc_full = f"{DATA_STORE}/{loc}/{nd[h]}"
                ev += f"; byte-identical to NEW_DATA/{nd[h]}, so stored once from NEW_DATA"
            else:
                loc_full = f"{DATA_STORE}/{loc}/copy_found_in_AQ_SRC/{os.path.basename(p)}"
                ev += "; differs from every NEW_DATA file, so kept as an extra copy in the delivery folder"
        elif klass == "raw":
            loc_full = f"{DATA_STORE}/{module}/raw/{p}"
        else:
            loc_full = f"{DATA_STORE}/{module}/{FROZEN[module]}/{p}"
        rows.append([src, module, p, st, size, h, klass, loc_full, ev])
    for top, (n, s, ev) in sorted(env_totals.items()):
        rows.append([src, module, top + f" ({n} files)", "ignored", s, "", "environment", "not copied to the store", ev])
    return rows


def main():
    nd = new_data_hashes()
    rows = rows_for(AQ_SRC, "air_quality", True, nd) + rows_for(WAZE_SRC, "congestion", False, nd)
    with open(OUT, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["source", "module", "source_path", "git_status", "size_bytes", "sha256", "class", "new_location", "evidence"])
        w.writerows(rows)
    counts = {}
    for r in rows:
        k = (r[1], r[6])
        n, s = counts.get(k, (0, 0))
        counts[k] = (n + 1, s + int(r[4]))
    for (m, c), (n, s) in sorted(counts.items()):
        print(f"{m:12s} {c:12s} {n:6d} rows {s / 1e9:8.3f} GB")


if __name__ == "__main__":
    main()
