"""
01_geometries_ucdb.py
=====================
Stage 1 of the LAC city-wide satellite pipeline.

Extracts Latin American & Caribbean urban centers from the GHS Urban Centre
Database (R2024A release) and writes a clean GeoJSON + Shapefile to disk for
upload to Google Earth Engine as a FeatureCollection asset.

When to run
-----------
This is a ONE-SHOT script. Only re-run if:
  (a) You're setting up the repo on a new machine, OR
  (b) JRC publishes a newer UCDB release and you want to use it, OR
  (c) The GEE asset `projects/airquality-leonelborjaplaza/assets/ucdb_lac`
      has been deleted.

Prerequisites
-------------
  - Raw input file at $UCDB_RAW (set env var) or default location:
      data/raw/GHS_UCDB/GHS_UCDB_REGION_LATIN_AMERICA_AND_THE_CARIBBEAN_R2024A.gpkg
    Download from:
      https://human-settlement.emergency.copernicus.eu/ghs_ucdb2024.php
  - geopandas + fiona installed

What it produces
----------------
  data/working/ucdb_lac.geojson
  data/working/ucdb_lac.shp  (+ companion .dbf, .shx, .prj, .cpg)

Next step (manual)
------------------
Upload `ucdb_lac.shp` (with companions) to your Earth Engine project as a
FeatureCollection asset at:
  projects/airquality-leonelborjaplaza/assets/ucdb_lac
"""

import os
from pathlib import Path

import pyogrio
import geopandas as gpd

# ----------------------------------------------------------------------------
# CONFIG
# ----------------------------------------------------------------------------
# Resolve the repo root from this script's location (code/satellite/python/).
REPO_ROOT = Path(__file__).resolve().parents[3]

# Allow override via environment variable in case the raw gpkg lives outside
# the repo (it's large; you may keep it elsewhere).
DEFAULT_RAW = (
    REPO_ROOT / "data" / "raw" / "GHS_UCDB"
    / "GHS_UCDB_REGION_LATIN_AMERICA_AND_THE_CARIBBEAN_R2024A.gpkg"
)
INPUT_GPKG = Path(os.environ.get("UCDB_RAW", DEFAULT_RAW))

OUTPUT_DIR = REPO_ROOT / "data" / "working"
OUTPUT_GEOJSON = OUTPUT_DIR / "ucdb_lac.geojson"
OUTPUT_SHP = OUTPUT_DIR / "ucdb_lac.shp"

# The layer inside the gpkg we want
LAYER = "GHSL_UCDB_THEME_GENERAL_CHARACTERISTICS_GLOBE_R2024A"

# Fields to keep
KEEP_FIELDS = ["ID_UC_G0", "GC_UCN_MAI_2025", "GC_CNT_GAD_2025", "geometry"]


# ----------------------------------------------------------------------------
# MAIN
# ----------------------------------------------------------------------------
def main() -> None:
    if not INPUT_GPKG.exists():
        raise FileNotFoundError(
            f"UCDB gpkg not found at {INPUT_GPKG}. "
            f"Set UCDB_RAW env var or place the file at the default path."
        )

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    print(f"Reading from: {INPUT_GPKG}")
    print(f"Available layers: {pyogrio.list_layers(str(INPUT_GPKG))}")

    gdf = gpd.read_file(INPUT_GPKG, layer=LAYER)
    gdf = gdf[KEEP_FIELDS]

    # Ensure WGS84
    if gdf.crs is None:
        print("Warning: CRS missing on input. Forcing WGS84 (EPSG:4326).")
        gdf = gdf.set_crs("EPSG:4326", allow_override=True)
    else:
        gdf = gdf.to_crs("EPSG:4326")

    # Fix invalid geometries via 0-buffer trick
    gdf["geometry"] = gdf.buffer(0)

    # Duplicate ID check (informational; UCDB IDs should be unique)
    dups = gdf[gdf.duplicated(subset="ID_UC_G0", keep=False)]
    if not dups.empty:
        print("Warning: duplicate IDs found:")
        print(dups[["ID_UC_G0", "GC_UCN_MAI_2025", "GC_CNT_GAD_2025"]].head())
    else:
        print(f"No duplicate IDs. {len(gdf)} urban centers retained.")

    # Write outputs
    gdf.to_file(OUTPUT_GEOJSON, driver="GeoJSON")
    print(f"Wrote GeoJSON: {OUTPUT_GEOJSON}")

    gdf.to_file(OUTPUT_SHP, driver="ESRI Shapefile")
    print(f"Wrote Shapefile: {OUTPUT_SHP}")

    print(
        "\nNext step: upload the shapefile (with .dbf/.shx/.prj/.cpg) to "
        "Earth Engine as a FeatureCollection asset at "
        "projects/airquality-leonelborjaplaza/assets/ucdb_lac"
    )


if __name__ == "__main__":
    main()
