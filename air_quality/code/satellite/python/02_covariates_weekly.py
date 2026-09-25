"""
02_covariates_weekly.py
========================
Stage 2 of the LAC city-wide satellite pipeline: weekly ERA5-Land covariates.

Exports per-city weekly aggregates of ERA5-Land hourly meteorology across all
LAC urban centers in the UCDB FeatureCollection. One row per (city × ISO week)
with weather state variables (means), fluxes (sums), and derived diagnostics.

Output
------
One CSV per year, written to Google Drive folder $DRIVE_FOLDER (see CONFIG).
Each row contains state means, flux sums, derived variables, and metadata:

State (means over the week's hourly observations):
  - t2m_mean              : 2-m temperature [K]
  - rh2m_mean             : 2-m relative humidity [%], derived from t2m & d2m via Magnus
  - sp_mean               : surface pressure [Pa]
  - soilT1_mean           : soil temp layer 1 [K]
  - soilW1_mean           : volumetric soil water layer 1 [m^3/m^3]
  - wind10m_speed_mean    : 10-m wind speed [m/s], hypot(u, v)
  - wind10m_dir           : 10-m wind direction [deg, meteorological]

Fluxes (sums over the week):
  - tp_week_mm            : total precipitation [mm]
  - solar_week_MJ         : surface solar radiation downwards [MJ/m^2]
  - evap_week_mm          : total evaporation [mm] (sign-flipped from native)

Derived diagnostics:
  - calm_pct              : fraction of hours with wind < 2 m/s [%]
  - rain_freq_pct         : fraction of hours with precip > 0.1 mm [%]
  - wind10m_max           : weekly max instantaneous wind speed [m/s]

How to run
----------
1. Authenticate Earth Engine (one-time per machine):
     earthengine authenticate
2. Confirm the UCDB FeatureCollection asset exists:
     projects/airquality-leonelborjaplaza/assets/ucdb_lac
3. Run:
     python code/satellite/python/02_covariates_weekly.py
4. Monitor tasks at https://code.earthengine.google.com/tasks

Notes on design decisions
-------------------------
- ISO weeks (Mon-Sun) consistent across Stage 2 for downstream joins.
- Full-week aggregation only (weekdays-only variant dropped per master file).
- Annual chunking (one task per year, ~5 total).
- Each ISO week assigned to the year of its Monday — no boundary duplication.
- ERA5-Land hourly is heavier compute than the pollutant scripts; annual chunks
  are still safe but worth monitoring task completion times.
- Drive folder versioned (_v2026) so prior outputs in GEE_LAC_ERA5L stay intact.
"""

import datetime as dt
import math

import ee

# ----------------------------------------------------------------------------
# CONFIG
# ----------------------------------------------------------------------------
EE_PROJECT  = 'airquality-leonelborjaplaza'
UCDB_ASSET  = f"projects/{EE_PROJECT}/assets/ucdb_lac"

DATASET     = 'ECMWF/ERA5_LAND/HOURLY'

DRIVE_FOLDER = 'GEE_LAC_ERA5L_v2026'

START_DATE  = dt.date(2022, 1, 1)
END_DATE    = dt.date(2026, 4, 30)

BANDS = [
    'temperature_2m',
    'dewpoint_temperature_2m',
    'surface_pressure',
    'u_component_of_wind_10m',
    'v_component_of_wind_10m',
    'total_precipitation_hourly',
    'surface_solar_radiation_downwards_hourly',
    'total_evaporation_hourly',
    'soil_temperature_level_1',
    'volumetric_soil_water_layer_1',
]

# ----------------------------------------------------------------------------
# INIT
# ----------------------------------------------------------------------------
ee.Authenticate()
ee.Initialize(project=EE_PROJECT)
fc = ee.FeatureCollection(UCDB_ASSET)

# ERA5-Land native projection (cached once for performance)
ERA5_PROJ = ee.ImageCollection(DATASET).first().select('temperature_2m').projection()


# ----------------------------------------------------------------------------
# DERIVED VARIABLES (per-hour)
# ----------------------------------------------------------------------------
def add_vars(img):
    """Add derived per-hour variables: RH, precip-mm, solar-MJ, evap-mm."""
    t2m = img.select('temperature_2m')
    d2m = img.select('dewpoint_temperature_2m')
    Tc, Tdc = t2m.subtract(273.15), d2m.subtract(273.15)
    es = Tc.expression('6.112*exp(17.67*T/(T+243.5))', {'T': Tc})
    e  = Tdc.expression('6.112*exp(17.67*Td/(Td+243.5))', {'Td': Tdc})
    rh    = e.divide(es).multiply(100).rename('rh2m')
    tp    = img.select('total_precipitation_hourly').multiply(1000).rename('tp_hour_mm')
    solar = img.select('surface_solar_radiation_downwards_hourly').divide(1e6).rename('solar_MJ')
    evap  = img.select('total_evaporation_hourly').multiply(-1000).rename('evap_mm')
    return img.addBands([rh, tp, solar, evap])


# ----------------------------------------------------------------------------
# ONE ISO WEEK
# ----------------------------------------------------------------------------
def process_week(start, end):
    """Aggregate ERA5-Land hourly to per-city weekly summaries."""
    coll = (ee.ImageCollection(DATASET)
              .filterBounds(fc)
              .filterDate(str(start), str(end + dt.timedelta(days=1)))
              .select(BANDS)
              .map(add_vars))

    week_size = coll.size()

    def process_with_data():
        # State variables: weekly means
        t2m_mean  = coll.select('temperature_2m').mean().rename('t2m_mean')
        rh_mean   = coll.select('rh2m').mean().rename('rh2m_mean')
        sp_mean   = coll.select('surface_pressure').mean().rename('sp_mean')
        soilT1    = coll.select('soil_temperature_level_1').mean().rename('soilT1_mean')
        soilW1    = coll.select('volumetric_soil_water_layer_1').mean().rename('soilW1_mean')

        # Fluxes: weekly sums
        tp_sum    = coll.select('tp_hour_mm').sum().rename('tp_week_mm')
        solar_sum = coll.select('solar_MJ').sum().rename('solar_week_MJ')
        evap_sum  = coll.select('evap_mm').sum().rename('evap_week_mm')

        # Wind: vector mean, then derive speed/dir
        u_mean = coll.select('u_component_of_wind_10m').mean()
        v_mean = coll.select('v_component_of_wind_10m').mean()
        wspd_mean = u_mean.hypot(v_mean).rename('wind10m_speed_mean')
        wdir_mean = v_mean.atan2(u_mean).multiply(180.0 / math.pi).add(180).rename('wind10m_dir')

        # Hourly-resolution wind for diagnostics
        wspd_inst  = coll.map(lambda im: im.select('u_component_of_wind_10m')
                                            .hypot(im.select('v_component_of_wind_10m')))
        calm_hours = wspd_inst.map(lambda im: im.lt(2)).sum()
        calm_pct   = calm_hours.divide(week_size).multiply(100).rename('calm_pct')

        rain_hours = coll.select('tp_hour_mm').map(lambda im: im.gt(0.1)).sum()
        rain_freq  = rain_hours.divide(week_size).multiply(100).rename('rain_freq_pct')

        wspd_max   = wspd_inst.max().rename('wind10m_max')

        img_final = t2m_mean.addBands([
            rh_mean, sp_mean, soilT1, soilW1,
            tp_sum, solar_sum, evap_sum,
            wspd_mean, wdir_mean,
            calm_pct, rain_freq, wspd_max,
        ])

        reduced = img_final.reduceRegions(
            collection = fc,
            reducer    = ee.Reducer.mean(),
            scale      = ERA5_PROJ.nominalScale(),
            crs        = ERA5_PROJ.crs(),
            tileScale  = 4,
        )

        def add_meta(f):
            iso_year, iso_week, _ = start.isocalendar()
            return f.set({
                'iso_year':   iso_year,
                'iso_week':   iso_week,
                'week_start': str(start),
                'week_end':   str(end),
                'n_obs':      week_size,
            })
        return reduced.map(add_meta)

    return ee.FeatureCollection(
        ee.Algorithms.If(week_size.gt(0),
                          process_with_data(),
                          ee.FeatureCollection([]))
    )


# ----------------------------------------------------------------------------
# ISO WEEK GENERATOR
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
            description    = f"ERA5L_ISO_{yr}",
            folder         = DRIVE_FOLDER,
            fileFormat     = 'CSV',
            maxVertices    = int(1e6),
        )
        task.start()
        total_exports += 1
        print(f"  Export queued: ERA5L_ISO_{yr}")

    print(f"\n{total_exports} export tasks submitted.")
    print(f"Drive folder: {DRIVE_FOLDER}")
    print("Monitor at: https://code.earthengine.google.com/tasks")


if __name__ == '__main__':
    main()
