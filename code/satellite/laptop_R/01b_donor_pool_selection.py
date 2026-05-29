"""
================================================================================
DONOR POOL SELECTION FOR SYNTHETIC CONTROL — METRO DE QUITO AIR QUALITY
================================================================================
Uses GHS-UCDB R2024A (LAC subset) to compute Mahalanobis distances between 
Quito and all other LAC urban centres on theoretically motivated covariates. 
Produces trimmed donor pools at multiple thresholds.

Based on: Abadie & Vives-i-Bastida (2024), "Synthetic Controls in Action" — 
which shows that trimming the donor pool to the closest units on predictors 
reduces overfitting and post-treatment estimation error.

Authors: Leonel Borja Plaza
Date: 2025
================================================================================
"""

import pandas as pd
import numpy as np
from scipy.spatial.distance import mahalanobis
from pathlib import Path
import warnings
warnings.filterwarnings('ignore')

# ==============================================================================
# 0. PATHS
# ==============================================================================
# Repo-relative paths. Script lives at code/satellite/python/, so the repo root
# is three directories up. The GHS-UCDB Excel file is not committed (it is a
# large external dataset); place it at the path below before running.
REPO_ROOT = Path(__file__).resolve().parents[3]
UCDB_PATH = REPO_ROOT / "data" / "raw" / "ghs_ucdb" / \
    "GHS_UCDB_REGION_LATIN_AMERICA_AND_THE_CARIBBEAN_R2024A.xlsx"
OUT_DIR   = REPO_ROOT / "data" / "working"
OUT_DIR.mkdir(parents=True, exist_ok=True)

QUITO_ID = 2544

# ==============================================================================
# 1. LOAD DATA FROM MULTIPLE SHEETS
# ==============================================================================
print("=" * 70)
print("LOADING GHS-UCDB R2024A DATA")
print("=" * 70)

# --- General Characteristics ---
gc = pd.read_excel(UCDB_PATH, sheet_name='GENERAL_CHARACTERISTICS')
gc = gc.rename(columns={'GC_UCA_KM2_2025': 'area_km2',
                         'GC_POP_TOT_2025': 'population',
                         'GC_UCN_MAI_2025': 'city_name',
                         'GC_CNT_GAD_2025': 'country'})
print(f"  General Characteristics: {len(gc)} urban centres")

# --- Geography (elevation) ---
geo = pd.read_excel(UCDB_PATH, sheet_name='GEOGRAPHY',
                    usecols=['ID_UC_G0', 'GE_ELV_AVG_2025'])
geo = geo.rename(columns={'GE_ELV_AVG_2025': 'elevation_m'})

# --- Climate (bioclimatic indicators — use most recent reanalysis decade) ---
cl = pd.read_excel(UCDB_PATH, sheet_name='CLIMATE',
                   usecols=['ID_UC_G0',
                            'CL_B01_CUR_2010',   # Annual mean temp (latest reanalysis)
                            'CL_B04_CUR_2010',   # Temp seasonality
                            'CL_B07_CUR_2010',   # Temp annual range
                            'CL_B12_CUR_2010'])  # Annual precipitation
cl = cl.rename(columns={
    'CL_B01_CUR_2010': 'temp_annual_mean',
    'CL_B04_CUR_2010': 'temp_seasonality',
    'CL_B07_CUR_2010': 'temp_annual_range',
    'CL_B12_CUR_2010': 'precip_annual'
})

# --- Emissions (latest year = 2022) ---
em_cols = ['ID_UC_G0',
           'EM_NOX_TRA_2022',   # NOx from transport
           'EM_PM2_TRA_2022',   # PM2.5 from transport
           'EM_NOX_TOT_2022',   # Total NOx
           'EM_PM2_TOT_2022',   # Total PM2.5
           'EM_CO2_TRA_2022',   # CO2 from transport
           'EM_CO2_TOT_2022',   # Total CO2
           'EM_NOX_STR_2022',   # Share NOx from transport
           'EM_PM2_SEN_2022']   # Share PM2.5 from energy
em = pd.read_excel(UCDB_PATH, sheet_name='EMISSIONS', usecols=em_cols)
em = em.rename(columns={
    'EM_NOX_TRA_2022': 'nox_transport',
    'EM_PM2_TRA_2022': 'pm25_transport',
    'EM_NOX_TOT_2022': 'nox_total',
    'EM_PM2_TOT_2022': 'pm25_total',
    'EM_CO2_TRA_2022': 'co2_transport',
    'EM_CO2_TOT_2022': 'co2_total',
    'EM_NOX_STR_2022': 'nox_transport_share',
    'EM_PM2_SEN_2022': 'pm25_energy_share'
})

# --- Infrastructure ---
infra = pd.read_excel(UCDB_PATH, sheet_name='INFRASTRUCTURES',
                      usecols=['ID_UC_G0', 'IN_ROA_DEN_2024', 'IN_CIS_TRA_2020'])
infra = infra.rename(columns={
    'IN_ROA_DEN_2024': 'road_density',
    'IN_CIS_TRA_2020': 'cisi_transport'
})

# --- GHSL (building height) ---
ghsl_cols = ['ID_UC_G0', 'GH_BUH_AVG_2020', 'GH_BPC_TOT_2020']
ghsl = pd.read_excel(UCDB_PATH, sheet_name='GHSL', usecols=ghsl_cols)
ghsl = ghsl.rename(columns={
    'GH_BUH_AVG_2020': 'avg_building_height',
    'GH_BPC_TOT_2020': 'builtup_per_capita'
})

# --- Socioeconomic ---
se_cols = ['ID_UC_G0', 'SC_GDP_AVG_2020', 'SC_SEC_HDI_2020']
se = pd.read_excel(UCDB_PATH, sheet_name='SOCIOECONOMIC', usecols=se_cols)
se = se.rename(columns={
    'SC_GDP_AVG_2020': 'gdp_avg',
    'SC_SEC_HDI_2020': 'hdi'
})

# ==============================================================================
# 2. MERGE INTO SINGLE PANEL
# ==============================================================================
print("\nMerging sheets...")
df = gc[['ID_UC_G0', 'city_name', 'country', 'area_km2', 'population']].copy()
for sheet_df in [geo, cl, em, infra, ghsl, se]:
    df = df.merge(sheet_df, on='ID_UC_G0', how='left')

print(f"  Merged dataset: {len(df)} cities x {df.shape[1]} columns")

# --- Compute derived variables ---
df['pop_density'] = df['population'] / df['area_km2']
df['log_population'] = np.log(df['population'].clip(lower=1))
df['log_area'] = np.log(df['area_km2'].clip(lower=0.1))
df['nox_per_capita'] = df['nox_total'] / df['population'].clip(lower=1)
df['pm25_per_capita'] = df['pm25_total'] / df['population'].clip(lower=1)
df['co2_per_capita'] = df['co2_total'] / df['population'].clip(lower=1)

# Compute absolute latitude from elevation (not directly in UCDB,
# but we can approximate using city coordinates if available)
# For now, we rely on climate variables as latitude proxies

# ==============================================================================
# 3. DEFINE MATCHING VARIABLE SETS
# ==============================================================================
# We define multiple variable sets to test sensitivity of donor selection.

# --- PRIMARY SET: Physical + Urban Structure ---
# Rationale: These variables determine (a) atmospheric conditions affecting
# pollutant dispersion and satellite retrieval, and (b) emission generation.
# They are all exogenous to the metro treatment.
vars_primary = [
    'elevation_m',          # Altitude → atmospheric pressure, boundary layer, retrieval
    'temp_annual_mean',     # Climate regime (strong latitude/elevation proxy)
    'temp_seasonality',     # Seasonal cycle similarity (treatment in December)
    'precip_annual',        # Precipitation → PM washout, photochemistry
    'log_population',       # City scale (log to reduce skew)
    'log_area',             # Urban footprint size → satellite aggregation
    'road_density',         # Traffic intensity proxy
    'avg_building_height',  # Urban morphology → canyon effects
]

# --- EXTENDED SET: Adds emissions profile ---
vars_extended = vars_primary + [
    'nox_per_capita',       # Emission intensity (transport-related pollutant)
    'pm25_per_capita',      # PM2.5 emission intensity
    'nox_transport_share',  # Transport share of NOx (vehicle dependence)
    'gdp_avg',              # Economic development → fleet composition
]

# --- MINIMAL SET: Only geography + climate (most exogenous) ---
vars_minimal = [
    'elevation_m',
    'temp_annual_mean',
    'precip_annual',
    'log_population',
    'log_area',
]

VARIABLE_SETS = {
    'primary': vars_primary,
    'extended': vars_extended,
    'minimal': vars_minimal,
}

# ==============================================================================
# 4. COMPUTE MAHALANOBIS DISTANCES
# ==============================================================================
print("\n" + "=" * 70)
print("COMPUTING MAHALANOBIS DISTANCES TO QUITO")
print("=" * 70)

# Verify Quito is in the data
assert QUITO_ID in df['ID_UC_G0'].values, "Quito (ID=2544) not found!"
quito_row = df[df['ID_UC_G0'] == QUITO_ID].iloc[0]
print(f"\nQuito: {quito_row['city_name']}, {quito_row['country']}")
print(f"  Population: {quito_row['population']:,.0f}")
print(f"  Area: {quito_row['area_km2']:.0f} km²")
print(f"  Elevation: {quito_row['elevation_m']:.0f} m")
print(f"  Mean Temp: {quito_row['temp_annual_mean']:.1f} °C")
print(f"  Precipitation: {quito_row['precip_annual']:.0f} mm/yr")

results_all = {}

for set_name, var_list in VARIABLE_SETS.items():
    print(f"\n--- Variable set: {set_name.upper()} ({len(var_list)} vars) ---")
    print(f"  Variables: {var_list}")

    # Subset to cities with complete data on these variables
    df_complete = df.dropna(subset=var_list).copy()
    n_dropped = len(df) - len(df_complete)
    print(f"  Cities with complete data: {len(df_complete)} (dropped {n_dropped})")

    # Check Quito survived
    if QUITO_ID not in df_complete['ID_UC_G0'].values:
        print(f"  WARNING: Quito dropped due to missing data in {set_name}!")
        continue

    # Extract matching matrix (exclude Quito for covariance estimation)
    X = df_complete[var_list].values
    city_ids = df_complete['ID_UC_G0'].values

    quito_idx = np.where(city_ids == QUITO_ID)[0][0]
    x_quito = X[quito_idx]

    # Standardize using all cities (including Quito)
    mu = X.mean(axis=0)
    sigma = X.std(axis=0)
    sigma[sigma == 0] = 1  # avoid division by zero

    X_std = (X - mu) / sigma
    x_quito_std = X_std[quito_idx]

    # Compute covariance matrix from standardized data (all cities)
    cov_matrix = np.cov(X_std, rowvar=False)

    # Regularize covariance matrix (add small ridge to ensure invertibility)
    cov_matrix += np.eye(cov_matrix.shape[0]) * 1e-6
    cov_inv = np.linalg.inv(cov_matrix)

    # Compute Mahalanobis distance from Quito to every other city
    distances = np.zeros(len(df_complete))
    for i in range(len(df_complete)):
        if i == quito_idx:
            distances[i] = 0.0
        else:
            distances[i] = mahalanobis(x_quito_std, X_std[i], cov_inv)

    df_complete = df_complete.copy()
    df_complete[f'mahal_dist_{set_name}'] = distances

    # Store results
    results_all[set_name] = df_complete[['ID_UC_G0', 'city_name', 'country',
                                          'area_km2', 'population', 'elevation_m',
                                          'temp_annual_mean', 'precip_annual',
                                          f'mahal_dist_{set_name}']].copy()

    # --- Print closest cities ---
    donors = df_complete[df_complete['ID_UC_G0'] != QUITO_ID].copy()
    donors = donors.sort_values(f'mahal_dist_{set_name}')

    print(f"\n  TOP 20 CLOSEST CITIES ({set_name}):")
    print(f"  {'Rank':<5} {'City':<30} {'Country':<18} {'Pop':>12} {'Elev(m)':>8} "
          f"{'Temp':>6} {'Precip':>7} {'Dist':>8}")
    print(f"  {'-'*100}")
    for rank, (_, row) in enumerate(donors.head(20).iterrows(), 1):
        print(f"  {rank:<5} {row['city_name']:<30} {row['country']:<18} "
              f"{row['population']:>12,.0f} {row['elevation_m']:>8.0f} "
              f"{row['temp_annual_mean']:>6.1f} {row['precip_annual']:>7.0f} "
              f"{row[f'mahal_dist_{set_name}']:>8.2f}")

# ==============================================================================
# 5. CREATE DONOR POOLS AT MULTIPLE THRESHOLDS
# ==============================================================================
print("\n" + "=" * 70)
print("CREATING DONOR POOLS AT MULTIPLE THRESHOLDS")
print("=" * 70)

# Use EXTENDED variable set as the main specification.
# (00_helpers.R sorts the donor file by rank_extended, so the production
# pipeline trims on the 12-variable extended set, not primary.)
main_set = 'extended'
dist_col = f'mahal_dist_{main_set}'
main_df = results_all[main_set].copy()
main_df = main_df[main_df['ID_UC_G0'] != QUITO_ID].sort_values(dist_col)

thresholds = [50, 100, 150, 200]   # matches N_DONORS_LIST in run scripts (plus Inf=all)

for n in thresholds:
    pool = main_df.head(n)
    print(f"\n  --- Top {n} donor pool ---")
    print(f"  Distance range: [{pool[dist_col].min():.2f}, {pool[dist_col].max():.2f}]")
    print(f"  Elevation range: [{pool['elevation_m'].min():.0f}, {pool['elevation_m'].max():.0f}] m")
    print(f"  Population range: [{pool['population'].min():,.0f}, {pool['population'].max():,.0f}]")
    print(f"  Countries: {pool['country'].nunique()} "
          f"({', '.join(pool['country'].value_counts().head(5).index.tolist())}...)")

# ==============================================================================
# 6. EXPORT RESULTS
# ==============================================================================
print("\n" + "=" * 70)
print("EXPORTING RESULTS")
print("=" * 70)

# --- 6a. Full distance table (all cities, all variable sets) ---
export_df = df[['ID_UC_G0', 'city_name', 'country', 'area_km2', 'population',
                'elevation_m', 'temp_annual_mean', 'temp_seasonality',
                'temp_annual_range', 'precip_annual', 'log_population',
                'log_area', 'road_density', 'avg_building_height',
                'nox_per_capita', 'pm25_per_capita', 'nox_transport_share',
                'gdp_avg', 'hdi', 'pop_density']].copy()

for set_name, res_df in results_all.items():
    dist_col_name = f'mahal_dist_{set_name}'
    export_df = export_df.merge(
        res_df[['ID_UC_G0', dist_col_name]],
        on='ID_UC_G0', how='left'
    )

# Add rank columns
for set_name in results_all.keys():
    dist_col_name = f'mahal_dist_{set_name}'
    rank_col = f'rank_{set_name}'
    # Rank excluding Quito (Quito gets rank 0)
    mask = export_df['ID_UC_G0'] != QUITO_ID
    export_df.loc[mask, rank_col] = export_df.loc[mask, dist_col_name].rank(method='min')
    export_df.loc[export_df['ID_UC_G0'] == QUITO_ID, rank_col] = 0

export_df = export_df.sort_values('mahal_dist_primary', na_position='last')

out_full = OUT_DIR / "ucdb_donor_distances_all.csv"
export_df.to_csv(out_full, index=False)
print(f"  Full distance table: {out_full}")

# --- 6b. Individual donor pool CSVs (ID lists for R/Stata scripts) ---
main_dist = f'mahal_dist_{main_set}'
donors_sorted = export_df[export_df['ID_UC_G0'] != QUITO_ID].sort_values(main_dist)

for n in thresholds:
    pool = donors_sorted.head(n)
    out_pool = OUT_DIR / f"donor_pool_top{n}.csv"
    pool[['ID_UC_G0', 'city_name', 'country', 'population', 'elevation_m',
          main_dist]].to_csv(out_pool, index=False)
    print(f"  Donor pool (top {n}): {out_pool}")

# --- 6c. ID-only list for easy import into R ---
for n in thresholds:
    pool_ids = donors_sorted.head(n)['ID_UC_G0'].values
    out_ids = OUT_DIR / f"donor_ids_top{n}.csv"
    pd.DataFrame({'ID_UC_G0': pool_ids}).to_csv(out_ids, index=False)
    print(f"  ID list (top {n}): {out_ids}")

# --- 6d. Quito's covariate values for reference ---
quito_export = export_df[export_df['ID_UC_G0'] == QUITO_ID]
out_quito = OUT_DIR / "quito_covariates.csv"
quito_export.to_csv(out_quito, index=False)
print(f"  Quito covariates: {out_quito}")

# ==============================================================================
# 7. BALANCE TABLE (Quito vs. donor pool means at each threshold)
# ==============================================================================
print("\n" + "=" * 70)
print("COVARIATE BALANCE: QUITO vs DONOR POOL MEANS")
print("=" * 70)

balance_vars = ['elevation_m', 'temp_annual_mean', 'temp_seasonality',
                'precip_annual', 'population', 'area_km2', 'road_density',
                'avg_building_height', 'nox_per_capita', 'pm25_per_capita',
                'gdp_avg', 'hdi']

quito_vals = export_df[export_df['ID_UC_G0'] == QUITO_ID][balance_vars].iloc[0]

balance_rows = []
for var in balance_vars:
    row = {'Variable': var, 'Quito': quito_vals[var]}
    # All LAC cities mean
    row['All_LAC_mean'] = export_df[export_df['ID_UC_G0'] != QUITO_ID][var].mean()
    row['All_LAC_std'] = export_df[export_df['ID_UC_G0'] != QUITO_ID][var].std()
    # Standardized difference vs all LAC
    if row['All_LAC_std'] > 0:
        row['StdDiff_AllLAC'] = (row['Quito'] - row['All_LAC_mean']) / row['All_LAC_std']
    else:
        row['StdDiff_AllLAC'] = np.nan

    for n in thresholds:
        pool_ids = donors_sorted.head(n)['ID_UC_G0'].values
        pool_data = export_df[export_df['ID_UC_G0'].isin(pool_ids)]
        pool_mean = pool_data[var].mean()
        pool_std = pool_data[var].std()
        row[f'Top{n}_mean'] = pool_mean
        if row['All_LAC_std'] > 0:
            row[f'StdDiff_Top{n}'] = (row['Quito'] - pool_mean) / row['All_LAC_std']
        else:
            row[f'StdDiff_Top{n}'] = np.nan
    balance_rows.append(row)

balance_df = pd.DataFrame(balance_rows)
out_balance = OUT_DIR / "donor_pool_balance_table.csv"
balance_df.to_csv(out_balance, index=False)
print(f"\nBalance table saved: {out_balance}")

# Print balance summary
print(f"\n{'Variable':<25} {'Quito':>12} {'All LAC':>12} {'StdDiff':>8} | "
      f"{'Top50':>12} {'StdDiff':>8} {'Top100':>12} {'StdDiff':>8}")
print("-" * 115)
for _, row in balance_df.iterrows():
    q = row['Quito']
    fmt = '.0f' if abs(q) > 100 else '.2f' if abs(q) > 1 else '.4f'
    print(f"{row['Variable']:<25} {q:>12{fmt}} {row['All_LAC_mean']:>12{fmt}} "
          f"{row['StdDiff_AllLAC']:>8.2f} | "
          f"{row.get('Top50_mean', np.nan):>12{fmt}} "
          f"{row.get('StdDiff_Top50', np.nan):>8.2f} "
          f"{row.get('Top100_mean', np.nan):>12{fmt}} "
          f"{row.get('StdDiff_Top100', np.nan):>8.2f}")

# ==============================================================================
# 8. SUMMARY
# ==============================================================================
print("\n" + "=" * 70)
print("SUMMARY")
print("=" * 70)
print(f"""
Total LAC urban centres in UCDB: {len(df)}
Quito ID: {QUITO_ID}

Variable sets used for distance computation:
  - Primary ({len(vars_primary)} vars): elevation, climate, urban structure
  - Extended ({len(vars_extended)} vars): + emissions, GDP
  - Minimal ({len(vars_minimal)} vars): geography + climate only

Donor pools exported at thresholds: {thresholds}

Files saved to: {OUT_DIR}
  - ucdb_donor_distances_all.csv    (all cities with distances)
  - donor_pool_topN.csv             (city details for each pool)
  - donor_ids_topN.csv              (ID-only for R/Stata import)
  - donor_pool_balance_table.csv    (covariate balance diagnostics)
  - quito_covariates.csv            (Quito's values for reference)

NEXT STEPS:
  1. Review balance table — check StdDiff < 0.25 for key variables
  2. In R: load donor_ids_topN.csv and filter your satellite panel
  3. Run SDID/AugSynth with trimmed pool — compare to full pool results
  4. Report ATT sensitivity across pool sizes (Table in paper)
""")

print("Done!")
