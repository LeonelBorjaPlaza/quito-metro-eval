"""
02_so2_weekly.py
================
Stage 2 of the LAC city-wide satellite pipeline: weekly Sentinel-5P SO2 downloads.

Exports per-city weekly aggregates of Sentinel-5P TROPOMI SO2 (offline product)
across all LAC urban centers in the UCDB FeatureCollection. One row per
(city × ISO week) with band means and QA-based pixel coverage diagnostics.

Output
------
One CSV per year, written to Google Drive folder $DRIVE_FOLDER (see CONFIG).
Each row contains:
  - iso_year, iso_week, week_start, week_end, n_obs
  - SO2_column_number_density_mean, SO2_column_number_density_amf_mean,
    SO2_slant_column_number_density_mean, cloud_fraction_mean,
    absorbing_aerosol_index_mean
  - n_valid_px, n_total_px, coverage_ratio
  - cloud_threshold, qa_note

Role in the paper
-----------------
SO2 is used as a placebo / falsification outcome. SO2 sources in cities are
predominantly industrial (power plants, smelters, heavy fuel), not passenger
transit, so a credible identification of the metro's effect on traffic-related
pollutants (AOD, CO, NO2) should NOT show up on SO2. A null SO2 effect supports
the causal interpretation of the primary results.

How to run
----------
1. Authenticate Earth Engine (one-time per machine):
     earthengine authenticate
2. Confirm the UCDB FeatureCollection asset exists:
     projects/airquality-leonelborjaplaza/assets/ucdb_lac
3. Run:
     python code/satellite/python/02_so2_weekly.py
4. Monitor tasks at https://code.earthengine.google.com/tasks

Notes on design decisions
-------------------------
- ISO weeks (Mon-Sun) consistent across Stage 2 for downstream joins.
- Full-week aggregation only.
- Annual chunking (one task per year, ~5 total).
- Cloud mask: cloud_fraction < 0.7 (matches NO2 and the prior canonical run).
- Drive folder versioned (_v2026) so prior outputs in GEE_LAC_SO2 stay intact.
"""

import datetime as dt

import ee

# ----------------------------------------------------------------------------
# CONFIG
# ----------------------------------------------------------------------------
EE_PROJECT  = 'airquality-leonelborjaplaza'
UCDB_ASSET  = f"projects/{EE_PROJECT}/assets/ucdb_lac"

DATASET     = 'COPERNICUS/S5P/OFFL/L3_SO2'

DRIVE_FOLDER = 'GEE_LAC_SO2_v2026'

START_DATE  = dt.date(2022, 1, 1)
END_DATE    = dt.date(2026, 4, 30)

BANDS = [
    'SO2_column_number_density',
    'SO2_column_number_density_amf',
    'SO2_slant_column_number_density',
    'absorbing_aerosol_index',
    'cloud_fraction',
]

CLOUD_THRESHOLD = 0.7
SCALE_M = 3500
REF_BAND = 'SO2_column_number_density'

# ----------------------------------------------------------------------------
# INIT
# ----------------------------------------------------------------------------
ee.Authenticate()
ee.Initialize(project=EE_PROJECT)
fc = ee.FeatureCollection(UCDB_ASSET)


# ----------------------------------------------------------------------------
# QA mask
# ----------------------------------------------------------------------------
def apply_qa(image):
    """Keep pixels with low cloud fraction."""
    return image.updateMask(image.select('cloud_fraction').lt(CLOUD_THRESHOLD))


# ----------------------------------------------------------------------------
# ONE ISO WEEK
# ----------------------------------------------------------------------------
def process_week(start, end):
    """Aggregate Sentinel-5P SO2 to per-city means for one ISO week."""
    coll_week = (ee.ImageCollection(DATASET)
                   .filterBounds(fc)
                   .filterDate(str(start), str(end + dt.timedelta(days=1)))
                   .select(BANDS))

    week_size = coll_week.size()

    def process_with_data():
        coll_masked = coll_week.map(apply_qa)
        img_mean = coll_masked.mean()

        native_proj = coll_week.first().select(REF_BAND).projection()
        valid_count = (coll_masked.select(REF_BAND)
                       .map(lambda im: ee.Image(1)
                            .updateMask(im.mask())
                            .reproject(native_proj))
                       .sum().rename('n_valid_px'))
        total_count = (coll_week.select(REF_BAND)
                       .map(lambda im: ee.Image(1)
                            .updateMask(im.mask())
                            .reproject(native_proj))
                       .sum().rename('n_total_px'))

        img_final = img_mean.addBands([valid_count, total_count])
        reducer = ee.Reducer.mean().combine(ee.Reducer.sum(), sharedInputs=True)
        reduced = img_final.reduceRegions(fc, reducer, scale=SCALE_M, tileScale=4)

        def add_meta(f):
            iso_year, iso_week, _ = start.isocalendar()
            valid_sum = ee.Number(f.get('n_valid_px_sum'))
            total_sum = ee.Number(f.get('n_total_px_sum'))
            cov_ratio = ee.Algorithms.If(total_sum.gt(0),
                                          valid_sum.divide(total_sum), None)
            return f.set({
                'iso_year':        iso_year,
                'iso_week':        iso_week,
                'week_start':      str(start),
                'week_end':        str(end),
                'n_obs':           week_size,
                'valid_pixels':    valid_sum,
                'total_pixels':    total_sum,
                'coverage_ratio':  cov_ratio,
                'scale_m':         SCALE_M,
                'cloud_threshold': CLOUD_THRESHOLD,
                'qa_note':         f'cloud_fraction<{CLOUD_THRESHOLD}',
            })
        return reduced.map(add_meta)

    return ee.FeatureCollection(
        ee.Algorithms.If(week_size.gt(0),
                          process_with_data(),
                          ee.FeatureCollection([]))
    )


# ----------------------------------------------------------------------------
# ISO WEEK GENERATOR (shared across Stage 2 scripts)
# ----------------------------------------------------------------------------
def iso_week_starts(start, end):
    """Generate (Monday, Sunday) pairs for every ISO week intersecting [start, end]."""
    cur = start - dt.timedelta(days=start.weekday())
    out = []
    while cur <= end:
        out.append((cur, cur + dt.timedelta(days=6)))
        cur += dt.timedelta(weeks=1)
    return out


# ----------------------------------------------------------------------------
# DRIVER: one task per calendar year
# ----------------------------------------------------------------------------
def main():
    weeks = iso_week_starts(START_DATE, END_DATE)
    print(f"Date window: {START_DATE} to {END_DATE}")
    print(f"ISO weeks to process: {len(weeks)}")

    years = sorted({wk_start.year for wk_start, _ in weeks})
    total_exports = 0

    for yr in years:
        year_weeks = [(s, e) for s, e in weeks if s.year == yr]
        if not year_weeks:
            continue

        print(f"\nPreparing {yr}: {len(year_weeks)} weeks...")
        parts = [process_week(s, e) for s, e in year_weeks]
        collection = ee.FeatureCollection(parts).flatten()

        task = ee.batch.Export.table.toDrive(
            collection     = collection,
            description    = f"SO2_ISO_{yr}",
            folder         = DRIVE_FOLDER,
            fileFormat     = 'CSV',
            maxVertices    = int(1e6),
        )
        task.start()
        total_exports += 1
        print(f"  Export queued: SO2_ISO_{yr}")

    print(f"\n{total_exports} export tasks submitted.")
    print(f"Drive folder: {DRIVE_FOLDER}")
    print("Monitor at: https://code.earthengine.google.com/tasks")


if __name__ == '__main__':
    main()
