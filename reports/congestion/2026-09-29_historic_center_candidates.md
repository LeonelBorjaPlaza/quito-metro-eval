# Historic center polygons for the treated unit: candidates and proposal

29 September 2026, workstream B, item B of Leonel's instructions of the same day (Amendment 2).

**Correction of 1 October 2026: areas.** The "geodesic" areas in the first version, and in the `area_ha_geodesic` column of `areas.csv`, were computed on a sphere (the s2 library), not on the WGS 84 ellipsoid, and are about 0.45 percent too large (515.47 against 513.16 ha for the Área Histórica). Every area below now names its coordinate system, from `congestion/Output/step1_amendment2/polygon_areas.csv`. SIRES-DMQ is the municipal planar projection, the one GeoQuito's own `STArea` field uses; "WGS 84 ellipsoid" is computed with an equal-area projection on that ellipsoid. `areas.csv` is left as written for the record, and so are the legend labels of `map_candidates_over_unesco.png` (1,417, 515, 374, 371 and 72 ha), which carry the spherical areas. No Waze outcome was read. Every number below comes from a file in `reports/congestion/2026-09-29_historic_center_candidates/` (named in brackets), written by the scripts copied into its `scratch_scripts/` folder. The candidate files themselves are in the scratchpad until you add them to the store.

## Proposal

- **Core (about 70 ha): the OpenStreetMap trace of the World Heritage property, way 1077782502.**
  - It measures 71.99 ha in SIRES-DMQ and 71.93 ha on the WGS 84 ellipsoid, against the official 70.43 ha (`polygon_areas.csv`).
  - 96.3 percent of it lies in the core colour of the UNESCO map, and the UNESCO map's core measures about 70.1 ha from its pixels (`unesco_map_shares.csv`).
  - Plaza Grande, San Francisco, Santo Domingo and La Compañía are inside. San Blas is outside, as it should be (`landmarks.csv`).
  - Its outline passes within 82 m of 7 of the 10 official corner intersections, and within 40 m of 5 of them. It is 137 m from the south-west corner (Chimborazo and 24 de Mayo). The tenth corner (Paredes and Morales) cannot be judged, because those streets do not meet in OSM (`core_corners_vs_osm_trace.csv`).
  - **Caveat:** it is a volunteer's tracing of the UNESCO map (changeset 123490726, July 2022, ODbL licence), not an official file. I found no official core polygon on GeoQuito. The municipality (Secretaría de Territorio or the Instituto Metropolitano de Patrimonio) may hold one. If you obtain it, it can replace this trace by amendment.
- **Wider historic center: GeoQuito's "Área Histórica Centro Histórico de Quito"** (heritage layer `patrimonio`, layer 6, feature 41).
  - It measures 513.63 ha in SIRES-DMQ, equal to GeoQuito's `STArea` field, and 513.16 ha on the WGS 84 ellipsoid, not about 375 (`polygon_areas.csv`).
  - It contains 371.2 of the roughly 375.3 ha that the UNESCO map colours as core or buffer, and all eight landmarks (`unesco_map_shares.csv`, `landmarks.csv`).
  - Its extra area lies mostly to the south, around the Panecillo. Ordinance 081-2024 (Art. 3816 a) defines the Centro Histórico as the historic core, the surrounding area, the buffer zone and an environmental protection area; the environmental area probably accounts for the extra land. The layer does not split these parts, so I cannot confirm this.
  - Measured by road length, which is what the weights use, 80.6 percent of its drivable roads lie inside the UNESCO core or buffer (`road_length_weights_summary.csv`).
  - It contains the whole core trace (`overlaps.csv`, share of O_WHC inside G_AH: 1.000).
- **Alternative for the wider area: the Centro Histórico parish** (GeoQuito, ordinance 002, already in the store).
  - It has the right size: 373.08 ha in SIRES-DMQ, from the GeoQuito parish polygon (`polygon_areas.csv`), against 375.25 ha.
  - But it contains only 269.6 of the UNESCO map's 375.3 ha of core and buffer (`unesco_map_shares.csv`).
  - It leaves out the northern barrios, including San Juan and El Tejar (`landmarks.csv`), and it reaches south to the Panecillo instead.
  - 82.4 percent of its road length lies inside the UNESCO area, about the same as the Área Histórica's 80.6 percent. It covers less of that area: about 50 km of drivable road inside the UNESCO area, against about 72 km for the Área Histórica (road length times share, both from `road_length_weights_summary.csv`).

I recommend the Área Histórica for the primary unit because it contains nearly all of the UNESCO property and buffer zone, and that is the historic center as the mechanism describes it. Its cost is the Panecillo area outside the UNESCO area. The parish matches the 375 ha figure but not the shape. The choice is yours.

## Two corrections to the reference figures

1. **375.25 ha is the core plus the buffer zone, not the buffer zone alone.** The Plan de Acción's technical document gives the core as 70.43 ha and the buffer zone as 304.82 ha in 13 barrios (lines 17795-17797 of its text as extracted by `pdftotext -layout`), and 70.43 + 304.82 = 375.25. The UNESCO map's pixels agree: about 70.1 ha of core and 305.2 ha of buffer.
2. **I found no "about 376 ha of protected built area" figure.** The same document gives 373 ha for the Centro Histórico parish (line 17328 of the same extract) and says the 375.25 ha "abarcan la parroquia Centro Histórico" (line 586).

## Candidates checked

| Code | Candidate | Source, licence | Area (ha, SIRES-DMQ; `areas.csv`, column `area_ha_sires`) | Verdict |
|---|---|---|---|---|
| O_WHC | OSM way 1077782502 "Ciudad de Quito" | OSM, ODbL; traced from UNESCO document 173425 | 71.99 | Proposed core |
| G_AH | Área Histórica Centro Histórico de Quito | GeoQuito `patrimonio` MapServer, layer 6; no licence stated | 513.63 | Proposed wider area |
| G_PARR | Centro Histórico parish, ordinance 002 | GeoQuito, in the store (road_safety) | 373.08 | Alternative wider area |
| G_PARR_REF | Same parish in "Parroquias DMQ" | GeoQuito, in the store | 373.09 | Identical to G_PARR (intersection over union 1.000) |
| O_PARR | OSM relation 89703 "Centro Histórico" (admin_level 9) | OSM, ODbL | 369.91 | Close copy of the parish (intersection over union 0.959) |
| G_PLAN | Plan de Acción del Centro Histórico boundary (`limite_plan_chq_a`) | GeoQuito | 1,412.31 | Rejected: 61 barrios, far beyond the historic center |

- **A false lead.** An ArcGIS Hub item called "Delimitación Centro Histórico" belongs to the city of Manizales, Colombia (owner `alcaldiamanizales`). It was not used.
- **The Plan de Acción story maps have no map layers.** They hold only images and PDFs.
- **The UNESCO map is a vector PDF with no geographic coordinates** (an INPC drawing, "NUCLEO CENTRAL CON ZONA DE AMORTIGUAMIENTO"). I did not digitize it. I placed it under the candidates only as a picture, by its printed 1 km grid, and counted its coloured pixels to check its areas.

## The UNESCO map's grid is offset

- **The size:** placed by its printed grid, the map's core sits 246 m east and 366 m north of the OSM trace (`unesco_map_shares.csv`).
- **Why the trace is right:** it matches the official corner streets (`core_corners_vs_osm_trace.csv`). Moved onto the map's grid, it misses the three south corners that can be judged by 304 to 448 m.
- **Not the old datum:** PSAD56 Quito TM coordinates lie south and west of SIRES-DMQ for the same point, the opposite direction (a one-off check in this session, not saved to a file).
- **What I did:** the overlay moves the picture by the measured offset and says so in its subtitle.

## Maps

- `reports/congestion/2026-09-29_historic_center_candidates/map_candidates_over_unesco.png` shows all candidates, the H3 grid, the seven-cell ring, the line, stations, monitors and landmarks, over the UNESCO map (orange core, blue buffer).
- `map_candidates_grid.png` in the same folder shows the same layers without the UNESCO picture, placed by the map's printed grid (before the offset was found).

## Road-length weights (rule B.4), prepared but not applied

- **Weights need road lines.** `roadlengths_quito.csv` gives only whole-cell totals, so the weights need OSM road lines. I fetched OSM as it stood on 2022-01-01, the start of the pre period, because plan section 3 freezes road weights at the 2022 vintage.
- **Drivable classes match the provider.** On 33 cells, they reproduce the provider's 2022 all_roadtype OSM length: 1.026 times in total, a median cell ratio of 1.005, and a correlation of 0.996. Adding service roads or footpaths overshoots (`osm_class_calibration_2022.csv`). So the provider's denominator appears to use drivable roads only; I propose the same classes for the weights.
- **Weights by unit** (`road_length_weights_summary.csv`):
  - The Área Histórica puts 71.1 percent of its weight on the seven ring cells and the rest on cells now labeled CORRIDOR (19.5 percent) and RING (9.4 percent). No REST cell is involved.
  - The core puts all its weight on four ring cells, 53.4 percent on one of them.
- **Tiny weights need a tolerance.** Clipping at a shared cell edge creates road pieces of about a billionth of a metre in neighbouring cells. Without a tolerance, those cells would join the unit and its "every cell-hour valid" rule. I propose to count a cell only if it has at least 1 m of road inside the polygon. That is an implementation rule for you to confirm.

## What your confirmation changes elsewhere

These points go into the plan amendment, and they need your decision before item D.

1. **CORRIDOR and RING lose cells.** The six CORRIDOR cells and three RING cells that the Área Histórica touches become part of the treated unit. CORRIDOR (Tier 2) and RING must drop them, and neither can serve as a donor anyway. I propose that the historic-center cells take precedence over CORRIDOR and RING.
2. **The coverage screen needs a new reference range.** It keeps donors whose 2022 jam-derived coverage lies within the range of the 14 CENTER and BELISARIO ring cells. With a polygon CENTER, the reference cells must be redefined, for example as the cells the wider unit touches plus the BELISARIO ring. Any choice changes the screened pool. It is a design choice, so I have not made it.
3. **The contrast becomes less like-for-like.** BELISARIO stays a seven-cell ring with equal weights, while CENTER becomes a road-weighted polygon. The two differ in area, in weighting and in how many cells average out noise. The difference CENTER minus BELISARIO then mixes the effect with those construction differences.

## How to add the files to the store

Run these in your own terminal from the worktree root, so the provenance notes land on this branch. The staged files are in the session scratchpad under `/tmp`, which does not survive a WSL restart, so run them soon.

```
cd /home/leonelb/projects/quito-metro-eval/.claude/worktrees/congestion-step1
RECEIVED_DATE=2026-09-29 bash scripts/add_raw_delivery.sh congestion historic_center_geography /tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/delivery/historic_center_geography/*
RECEIVED_DATE=2026-09-29 bash scripts/add_raw_delivery.sh congestion osm_roads_20220101 /tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/delivery/osm_roads_20220101/*
```

Each folder holds a `SOURCES.md` with the URL, date and licence of every file. After you run them, I will add committed symlinks from `congestion/Data/` to the two store folders and to the parish folder in `road_safety/raw/`. I will also rewrite the comparison as a repository script that reads the store.
