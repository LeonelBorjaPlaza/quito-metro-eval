# Raw Data Sources

## REMMAQ Ground Monitoring Stations

- **Source:** Secretaria de Ambiente, Municipio de Quito (REMMAQ network)
- **URL:** https://datosambiente.quito.gob.ec (requires Ecuadorian IP; accessed via VPN)
- **Download date:** March 25, 2026
- **QA/QC documentation:** See `remmaq/Marco_QAQC_REMMAQ.pdf` in this folder

### Files downloaded

All files are .xlsx, one per variable. Each file contains hourly observations with columns for each station.

| File    | Variable              | Unit    | Used in analysis        |
|---------|-----------------------|---------|-------------------------|
| PM2.5   | Fine particulate matter | ug/m3 | Yes (outcome)           |
| CO      | Carbon monoxide       | mg/m3   | Yes (outcome)           |
| TMP     | Temperature           | C       | Yes (weather covariate) |
| HUM     | Relative humidity     | %       | Yes (weather covariate) |
| VEL     | Wind speed            | m/s     | Yes (weather covariate) |
| DIR     | Wind direction        | degrees | Yes (weather covariate) |
| LLU     | Precipitation         | mm/h    | Yes (weather covariate) |
| RS      | Solar radiation       | W/m2    | Yes (weather covariate) |
| PRE     | Atmospheric pressure  | hPa     | Yes (weather covariate) |
| NO2     | Nitrogen dioxide      | ug/m3   | No (excluded from paper)|
| O3      | Ozone                 | ug/m3   | No (excluded from paper)|
| SO2     | Sulfur dioxide        | ug/m3   | No (excluded from paper)|
| PM10    | Coarse particulate    | ug/m3   | No                      |
| IUV     | UV index              | index   | No                      |

### QA/QC applied by REMMAQ (pre-download)

The data is already validated. Key procedures (detailed in Marco_QAQC_REMMAQ.pdf):

1. **Physical range filters** per variable (e.g., PM2.5 cannot be negative, humidity 0-100%, temperature -5 to 40 C for Quito)
2. **Outlier detection:** |x - median| > 7 x MAD flags instrumental outliers (pollutants only; not applied to weather variables)
3. **Spike check:** |x - lag| > 4 x MAD AND |x - lead| > 4 x MAD flags isolated non-physical spikes
4. **Percentile trimming:** values beyond p0.5 and p99.5 flagged for instrument noise or saturation
5. **Invalidation rule:** a value is marked invalid only when 2+ criteria are met simultaneously
6. **Weather variables** receive lighter treatment: physical range limits and spike detection only (no MAD, no percentiles), with variable-specific thresholds adjusted to Quito conditions (2800 masl, equatorial)
