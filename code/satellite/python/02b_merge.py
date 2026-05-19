"""
02b_merge.py
============
Stage 2b of the LAC city-wide satellite pipeline: consolidate per-period Stage 2
exports into one tidy CSV per pollutant.

GEE Stage 2 scripts (`02_*_weekly.py`) write monthly (AOD) or yearly (S5P, ERA5)
CSVs to Google Drive. Once those files have been downloaded into
`data/raw/satellite/<pollutant>/`, this script stitches them into a single
analysis-ready file per pollutant at `data/processed/satellite/<pollutant>_weekly.csv`.

The merge is structural: rows are stacked, a `source_file` column is added for
provenance, and exact duplicates on (city, iso_year, iso_week) are removed
(arises naturally for AOD because per-month chunking duplicates weeks that span
month boundaries — same week, same values). No cleaning/winsorizing/imputation
happens here; those steps belong to the R-side Stage 3 (clean ERA5) and Stage 4
(build panels) scripts.

Usage
-----
Merge everything available:
    python code/satellite/python/02b_merge.py

Merge specific pollutants:
    python code/satellite/python/02b_merge.py aod
    python code/satellite/python/02b_merge.py no2 co

Inputs
------
data/raw/satellite/<pollutant>/*.csv          (any number; e.g. 52 monthly for AOD, 5-6 yearly for others)

Outputs
-------
data/processed/satellite/<pollutant>_weekly.csv   (single deduplicated file)
"""

import argparse
from pathlib import Path

import pandas as pd

# ----------------------------------------------------------------------------
# CONFIG
# ----------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parents[3]
RAW_DIR = REPO_ROOT / "data" / "raw" / "satellite"
OUT_DIR = REPO_ROOT / "data" / "processed" / "satellite"

POLLUTANTS = ['aod', 'no2', 'co', 'so2', 'era5l', 'hcho', 'ch4']


# ----------------------------------------------------------------------------
# MERGE ONE
# ----------------------------------------------------------------------------
def merge_one(pollutant: str) -> None:
    """Read all CSVs in data/raw/satellite/<pollutant>/, concat, dedupe, write."""
    in_dir = RAW_DIR / pollutant
    if not in_dir.exists():
        print(f"\n{pollutant.upper()}: directory not found at {in_dir}; skipping.")
        return

    files = sorted(in_dir.glob("*.csv"))
    if not files:
        print(f"\n{pollutant.upper()}: no CSV files found in {in_dir}; skipping.")
        return

    print(f"\n{pollutant.upper()}: found {len(files)} files")

    frames = []
    for f in files:
        try:
            df = pd.read_csv(f)
            df['source_file'] = f.name
            frames.append(df)
        except Exception as e:
            print(f"  ERROR reading {f.name}: {e}")
            continue

    if not frames:
        print(f"  {pollutant.upper()}: no readable files; nothing written.")
        return

    merged = pd.concat(frames, ignore_index=True)
    rows_raw = len(merged)

    # Detect city-id column without hardcoding (UCDB uses ID_UC_G0)
    id_col = next(
        (c for c in ['ID_UC_G0', 'ID_UC', 'city_id', 'system:index'] if c in merged.columns),
        None,
    )

    # Deduplicate on (city, iso_year, iso_week) if those columns are present.
    # Duplicates arise naturally for AOD (per-month chunking) and harmlessly when
    # the same week falls into two different files; values are identical.
    if id_col and 'iso_year' in merged.columns and 'iso_week' in merged.columns:
        dup_keys = [id_col, 'iso_year', 'iso_week']
        n_dups = merged.duplicated(subset=dup_keys).sum()
        if n_dups > 0:
            merged = merged.drop_duplicates(subset=dup_keys, keep='first') \
                           .reset_index(drop=True)
            print(f"  Dedup        : dropped {n_dups:,} duplicate rows "
                  f"on ({', '.join(dup_keys)})")

    # Summary diagnostics
    print(f"  Rows in      : {rows_raw:,}")
    print(f"  Rows out     : {len(merged):,}")
    print(f"  Columns      : {len(merged.columns)}")
    if 'iso_year' in merged.columns:
        years = sorted(merged['iso_year'].dropna().unique())
        if years:
            print(f"  Year range   : {int(years[0])} – {int(years[-1])}")
    if 'iso_week' in merged.columns and 'iso_year' in merged.columns:
        unique_weeks = merged[['iso_year', 'iso_week']].drop_duplicates()
        print(f"  Unique weeks : {len(unique_weeks):,}")
    if id_col:
        print(f"  Unique cities: {merged[id_col].nunique():,} (column: {id_col})")
    if 'coverage_ratio' in merged.columns:
        cov = merged['coverage_ratio'].dropna()
        if len(cov) > 0:
            print(f"  Coverage     : mean {cov.mean():.3f}, "
                  f"p10 {cov.quantile(0.10):.3f}, p90 {cov.quantile(0.90):.3f}")

    # Write
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out_path = OUT_DIR / f"{pollutant}_weekly.csv"
    merged.to_csv(out_path, index=False)
    print(f"  Wrote        : {out_path.relative_to(REPO_ROOT)}")


# ----------------------------------------------------------------------------
# MAIN
# ----------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description='Merge Stage 2 per-period CSVs into a single file per pollutant.'
    )
    parser.add_argument(
        'pollutants',
        nargs='*',
        default=POLLUTANTS,
        help=f'Pollutants to merge. Default: all known ({", ".join(POLLUTANTS)}).',
    )
    args = parser.parse_args()

    for p in args.pollutants:
        if p not in POLLUTANTS:
            print(f"Unknown pollutant: '{p}'. Valid: {', '.join(POLLUTANTS)}.")
            continue
        merge_one(p)

    print("\nDone.")


if __name__ == '__main__':
    main()
