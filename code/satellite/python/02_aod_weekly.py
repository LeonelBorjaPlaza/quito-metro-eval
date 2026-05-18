"""
02_aod_weekly.py
================
Stage 2 of the LAC city-wide satellite pipeline: weekly MODIS MAIAC AOD downloads.

Exports per-city weekly aggregates of MODIS MCD19A2 AOD across all LAC urban
centers in the UCDB FeatureCollection. One row per (city × ISO week) with band
means, derived fine_mode_aod, and QA-based pixel coverage diagnostics.

Output
------
One CSV per month, written to Google Drive folder $DRIVE_FOLDER (see CONFIG).
Each row contains:
  - iso_year, iso_week, week_start, week_end, n_obs
  - Optical_Depth_055_mean (scaled), AOD_Uncertainty_mean, FineModeFraction_mean,
    AngstromExp_470-780_mean, Column_WV_mean, fine_mode_aod_mean
  - n_valid_px, n_total_px, coverage_ratio
  - qa_note (provenance string)

How to run
----------
1. Authenticate Earth Engine on this machine (one-time per machine):
     earthengine authenticate
2. Confirm the UCDB FeatureCollection asset exists in your EE project:
     projects/airquality-leonelborjaplaza/assets/ucdb_lac
   (If not, run `01_geometries_ucdb.py` and upload as a FeatureCollection asset.)
3. Run:
     python code/satellite/python/02_aod_weekly.py
4. Monitor tasks at:
     https://code.earthengine.google.com/tasks
   Tasks run on Google's servers; your machine does not need to stay on. Total
   wall time is typically several hours to ~1 day for a full window depending
   on EE queue depth.

Notes on design decisions
-------------------------
- ISO weeks (Mon-Sun) are used consistently across all Stage 2 scripts (AOD,
  pollutants, ERA5) to enable downstream joins on (iso_year, iso_week).
- Full-week aggregation only. The weekdays-only variant present in earlier
  versions has been dropped per the pipeline decision in the master file.
- Drive folder is versioned (_v2026) so this run does not overwrite the prior
  2022-2024 outputs in `GEE_LAC_AOD_ISO`.
- QA masking retains only "best quality" MAIAC pixels:
    AOD_QA bits 0-2 == 1  (Best, retrieved successfully)
    AOD_QA bits 5-7 == 0  (No adjacent cloud detected)
  This matches the mask used in Sep 2025 and was code-reviewed at that time.
"""

import calendar
import datetime as dt

import ee

# ----------------------------------------------------------------------------
# CONFIG
# ----------------------------------------------------------------------------
EE_PROJECT  = 'airquality-leonelborjaplaza'
UCDB_ASSET  = f"projects/{EE_PROJECT}/assets/ucdb_lac"

DATASET     = 'MODIS/061/MCD19A2_GRANULES'

# Versioned Drive folder for this run. Keeps the prior run's outputs intact
# in the older `GEE_LAC_AOD_ISO` folder.
DRIVE_FOLDER = 'GEE_LAC_AOD_ISO_v2026'

# Date window. END_DATE is bounded by MAIAC latency (typically ~2 months).
START_DATE  = dt.date(2022, 1, 1)
END_DATE    = dt.date(2026, 4, 30)

# Bands retained. AOD_QA is used for masking only.
BANDS = [
    'Optical_Depth_055',
    'AOD_Uncertainty',
    'FineModeFraction',
    'AngstromExp_470-780',
    'Column_WV',
    'AOD_QA',
]

# Per-band rescaling factors (per MODIS MCD19A2 user guide).
SCALE = {
    'Optical_Depth_055':    0.001,
    'AOD_Uncertainty':      0.001,
    'FineModeFraction':     0.001,
    'AngstromExp_470-780':  0.001,
    'Column_WV':            0.0001,
    'AOD_QA':               1,          # integer flags, not scaled
}

SCALE_M = 1000  # MAIAC native ~1 km

MONTH_NAMES = {
    1: 'Jan', 2: 'Feb', 3: 'Mar',  4: 'Apr',  5: 'May',  6: 'Jun',
    7: 'Jul', 8: 'Aug', 9: 'Sep', 10: 'Oct', 11: 'Nov', 12: 'Dec'
}

# ----------------------------------------------------------------------------
# INIT
# ----------------------------------------------------------------------------
ee.Authenticate()
ee.Initialize(project=EE_PROJECT)
fc = ee.FeatureCollection(UCDB_ASSET)


# ----------------------------------------------------------------------------
# QA + SCALING + DERIVED BANDS
# ----------------------------------------------------------------------------
def apply_maiac_qa(image):
    """Keep only best-quality MAIAC pixels with no adjacent cloud."""
    qa = image.select('AOD_QA')
    best_aod  = qa.bitwiseAnd(7).eq(1)
    no_adjcld = qa.rightShift(5).bitwiseAnd(7).eq(0)
    return image.updateMask(best_aod.And(no_adjcld))


def scale_and_derive(img):
    """Apply per-band scaling and add fine_mode_aod = OD_055 * FMF."""
    scaled = [
        img.select(b).multiply(s).rename(b)
        for b, s in SCALE.items()
        if b != 'AOD_QA'
    ]
    out = ee.Image.cat(scaled).addBands(img.select('AOD_QA'))
    fine_mode = (out.select('Optical_Depth_055')
                    .multiply(out.select('FineModeFraction'))
                    .rename('fine_mode_aod'))
    return out.addBands(fine_mode).copyProperties(img, img.propertyNames())


# ----------------------------------------------------------------------------
# ONE ISO WEEK
# ----------------------------------------------------------------------------
def process_week(start, end):
    """
    Aggregate MAIAC AOD to per-city means for one ISO week.

    Parameters
    ----------
    start, end : datetime.date
        Monday and Sunday bounding the ISO week.

    Returns
    -------
    ee.FeatureCollection
        One feature per UCDB urban center with the week's aggregates plus
        metadata. Empty if no MAIAC observations exist in the window.
    """
    coll_week = (ee.ImageCollection(DATASET)
                   .filterBounds(fc)
                   .filterDate(str(start), str(end + dt.timedelta(days=1)))
                   .select(BANDS))

    week_size = coll_week.size()

    def process_with_data():
        coll_masked = coll_week.map(apply_maiac_qa).map(scale_and_derive)
        img_mean = coll_masked.mean()

        native_proj = coll_week.first().select('Optical_Depth_055').projection()
        valid_count = (coll_masked.select('Optical_Depth_055')
                       .map(lambda im: ee.Image(1)
                            .updateMask(im.mask())
                            .reproject(native_proj))
                       .sum().rename('n_valid_px'))
        total_count = (coll_week.select('Optical_Depth_055')
                       .map(lambda im: ee.Image(1)
                            .updateMask(im.mask())
                            .reproject(native_proj))
                       .sum().rename('n_total_px'))

        img_final = img_mean.addBands([valid_count, total_count])
        reducer = ee.Reducer.mean().combine(ee.Reducer.sum(), sharedInputs=True)
        reduced = img_final.reduceRegions(fc, reducer, scale=SCALE_M, tileScale=16)

        def add_meta(f):
            iso_year, iso_week, _ = start.isocalendar()
            valid_sum = ee.Number(f.get('n_valid_px_sum'))
            total_sum = ee.Number(f.get('n_total_px_sum'))
            cov_ratio = ee.Algorithms.If(total_sum.gt(0),
                                          valid_sum.divide(total_sum), None)
            return f.set({
                'iso_year':       iso_year,
                'iso_week':       iso_week,
                'week_start':     str(start),
                'week_end':       str(end),
                'n_obs':          week_size,
                'valid_pixels':   valid_sum,
                'total_pixels':   total_sum,
                'coverage_ratio': cov_ratio,
                'scale_m':        SCALE_M,
                'qa_note':        'MAIAC mask: AOD_QA bits0-2==1 & bits5-7==0',
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
# DRIVER: month-by-month exports across the full window
# ----------------------------------------------------------------------------
def main():
    weeks = iso_week_starts(START_DATE, END_DATE)
    print(f"Date window: {START_DATE} to {END_DATE}")
    print(f"ISO weeks to process: {len(weeks)}")

    years = list(range(START_DATE.year, END_DATE.year + 1))
    total_exports = 0

    for yr in years:
        for mo in range(1, 13):
            month_start = dt.date(yr, mo, 1)
            month_end = dt.date(yr, mo, calendar.monthrange(yr, mo)[1])

            # Skip months entirely outside the window
            if month_end < START_DATE or month_start > END_DATE:
                continue

            print(f"\nPreparing {yr}-{mo:02d} ({MONTH_NAMES[mo]})...")

            parts = [
                process_week(wk_start, wk_end)
                for wk_start, wk_end in weeks
                if wk_start <= month_end and wk_end >= month_start
            ]
            if not parts:
                print(f"  No overlapping weeks for {yr}-{mo:02d}; skipping.")
                continue

            collection = ee.FeatureCollection(parts).flatten()

            task = ee.batch.Export.table.toDrive(
                collection     = collection,
                description    = f"AOD_ISO_{yr}_{mo:02d}_{MONTH_NAMES[mo]}",
                folder         = DRIVE_FOLDER,
                fileFormat     = 'CSV',
                maxVertices    = int(1e6),
            )
            task.start()
            total_exports += 1
            print(f"  Export queued: AOD_ISO_{yr}_{mo:02d}_{MONTH_NAMES[mo]}")

    print(f"\n{total_exports} export tasks submitted.")
    print(f"Drive folder: {DRIVE_FOLDER}")
    print("Monitor at: https://code.earthengine.google.com/tasks")


if __name__ == '__main__':
    main()
