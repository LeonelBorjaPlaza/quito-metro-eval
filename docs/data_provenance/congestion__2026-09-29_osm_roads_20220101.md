# congestion: 2026-09-29_osm_roads_20220101

- Store folder: `/home/leonelb/data/quito-metro-eval/congestion/raw/2026-09-29_osm_roads_20220101`
- Received on 2026-09-29; added to the store on 2026-10-01 by leonelb
- Copied from: /tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/delivery/osm_roads_20220101/SOURCES.md /tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/delivery/osm_roads_20220101/osm_roads_2022.txt /tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/delivery/osm_roads_20220101/osm_roads_20220101.json
- Sent by or obtained from: downloaded by Claude Code (workstream B) on 2026-09-29, 18:17 America/Guayaquil, from the Overpass API (`https://overpass-api.de/api/interpreter`). The exact query is in `osm_roads_2022.txt`; `SOURCES.md` has the details.
- What it covers (period, units, variables): every OpenStreetMap way tagged `highway` in the box latitude -0.250 to -0.190, longitude -78.540 to -78.485, as the OSM database stood on 2022-01-01 00:00 UTC, with geometry and tags. Under Amendment 2, its drivable classes weight the cells of the historic-center units by road length inside the polygon. Those classes are motorway, trunk, primary, secondary, tertiary, unclassified, residential, living_street and the five link classes.
- Terms of use: Open Database Licence (ODbL) 1.0. Any map or table derived from it must carry the credit "© OpenStreetMap contributors".
- Known gaps or caveats:
  - **BELISARIO is not covered.** The box covers the historic-center candidates but not BELISARIO, whose cells lie north of latitude -0.191. BELISARIO's road weights use the provider's 2022 OSM length per cell instead (`Data/Waze/raw/roadlengths_quito.csv`).
  - **It matches the provider's road length.** On 33 cells wholly inside the box, the drivable classes give 1.026 times the provider's 2022 all_roadtype OSM length, with a median cell ratio of 1.005 (`reports/congestion/2026-09-29_historic_center_candidates/osm_class_calibration_2022.csv`).
  - **The provider's own OSM snapshot is undated.** Its date and its class filter are unknown (plan section 11).

## Files and sha256

```
f9e3ffec0e21ad51085fe1ec3e9672ca1122efb591d489f5d07ddbf6b4427274  ./SOURCES.md
4ae58e5b163b42b30b07c25316ea9c21b221c513fb17659e28ece2e3d9b859c6  ./osm_roads_2022.txt
11c6e8c4869b5626b0b34b0a85f3648085490789f6b01d82c3e7fc2123446d1e  ./osm_roads_20220101.json
```
