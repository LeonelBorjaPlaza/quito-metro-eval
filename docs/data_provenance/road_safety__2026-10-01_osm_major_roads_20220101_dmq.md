# road_safety: 2026-10-01_osm_major_roads_20220101_dmq

- **Store folder:** `/home/leonelb/data/quito-metro-eval/road_safety/raw/2026-10-01_osm_major_roads_20220101_dmq`. The module reaches it through its committed symlink `road_safety/data/raw` (constant `ROADS_OSM` in `road_safety/code/helpers.R`).
- **Received and added:** received on 2026-10-01; added to the store on 2026-10-01 by leonelb.
- **Copied from:** the session scratch folder of workstream C (`/tmp/claude-1000/-home-leonelb-projects-quito-metro-eval--claude-worktrees-road-safety-plan/6c033877-b2c9-4fe4-ac20-ed61b13ed100/scratchpad/roads2022/`). A Claude Code agent downloaded both files there on 2026-10-01, at Leonel's request (decision of 2026-10-01, `docs/correspondence/2026-09-27_road_safety_design_decisions.md`).
- **Sent by or obtained from:** OpenStreetMap, through the Overpass API (`https://overpass-api.de/api/interpreter`, a POST with the query in `overpass_query.txt`).
  - The query asks for the database **as it stood on 2022-01-01 00:00 UTC** (an attic query, `[date:"2022-01-01T00:00:00Z"]`).
  - The file header records the server state at download: `osm_base` 2026-10-01T13:05:51Z.
  - Way pages: `https://www.openstreetmap.org/way/<id>`.
- **How it was fetched:** one query for the full box. The first attempt returned HTTP 504 (gateway timeout); the retry, minutes later, returned the complete file. The box was **not** split into tiles.
- **What it covers (period, units, variables):**
  - **Ways:** every way tagged `highway` = motorway, trunk, primary or secondary, or their `_link` variants, that intersects the bounding box of the Distrito Metropolitano de Quito: latitude -0.591 to 0.256, longitude -78.948 to -78.170 (the extent of the GeoQuito parish polygons, `road_safety/raw/2026-09-25_geoquito_parroquias`).
  - **Nodes and format:** all their nodes, as OSM XML in WGS 84.
  - **Counts:**
    - 6,259 ways: motorway 224, motorway_link 84, trunk 986, trunk_link 231, primary 2,391, primary_link 401, secondary 1,799, secondary_link 143.
    - 82.6 percent of the ways carry a `name`.
    - 39,810 nodes. Ways that cross the box edge come back whole, so nodes reach latitude -0.627 to 0.276 and longitude -79.116 to -78.140.
    - Read with the GDAL OSM driver, layer `lines`: 6,259 features, the same class counts.
  - **Date check:** the latest way timestamp in the file is 2021-12-29T19:07:25Z, consistent with the attic date.
  - **Fast roads:** every road named in `road_safety/code/01_build.R`'s fast-road list appears (Simón Bolívar, Interoceánica, Ruta Viva, Panamericana Norte and Sur, Autopista General Rumiñahui, Manuel Córdova Galarza, Intervalles), and so does Av. Mariscal Sucre. Four ways are named plain "MARISCAL SUCRE".
- **Purpose:**
  - **Placebo corridors** for the gradient design (`road_safety/code/08_gradient.R`, rule in its header; motorway, trunk and primary only).
  - **A check of the name-based fast-road flag** against road geometry, including the "MARISCAL SUCRE" matches outside the urban expressway (for example in Conocoto; `docs/known_issues.md`).
- **Replaces:** a 2026-09-27 snapshot of current OSM (motorway, trunk and primary over a smaller box, latitude -0.45 to 0.10, longitude -78.65 to -78.30). It was never added to the store and has been dropped.
- **Not to be confused with:** `congestion/raw/2026-09-29_osm_roads_20220101/`. That layer has all highway classes on the same date, but only over a central box (latitude -0.250 to -0.190, longitude -78.540 to -78.485), for the congestion module's road-length weights.
- **Terms of use:**
  - Open Database License (ODbL 1.0).
  - Any use, table or map derived from it must carry the credit **"© OpenStreetMap contributors"**.
  - The file header states: "The data included in this document is from www.openstreetmap.org. The data is made available under ODbL."
- **Known gaps or caveats:**
  - Community-edited data, not an official source.
  - Road classes and names are as contributors had entered them by 2022-01-01. 17.4 percent of the ways have no name.
  - Name variants differ: "AVENIDA SIMON BOLIVAR" and "SIMON BOLIVAR"; "VIA INTEROCEANICA" and "AVENIDA INTEROCEANICA".
  - Tertiary and smaller roads are not included.

## Files and sha256

```
40c80333e13e39c7ad47f170eb4c4ff8e6e5268dd2630547435a83718ad1c72c  ./osm_major_roads_20220101_dmq.osm
53706f5e14f7da5731f5d5f2ecb1765d7e41254f5baa28f08b7abbce1509bfd4  ./overpass_query.txt
```

Checked on 2026-10-01: both stored files' sha256 equal the values recorded at download (in the scratch folder, before the store copy) and the store's `SHA256SUMS`.
