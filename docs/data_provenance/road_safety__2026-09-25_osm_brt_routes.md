# road_safety: 2026-09-25_osm_brt_routes

- Store folder: `/home/leonelb/data/quito-metro-eval/road_safety/raw/2026-09-25_osm_brt_routes`
- Received on 2026-09-25; added to the store on 2026-09-25 by leonelb
- Copied from: the session scratch folder of workstream C (`/tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/6c033877-b2c9-4fe4-ac20-ed61b13ed100/scratchpad/layers/brt/`), where a Claude Code agent downloaded the file on 2026-09-25 at Leonel's request (Step 1 plan, decision 5: flag donors crossed by the Trolebús or Ecovía corridors). No official municipal route layer was reachable, so OpenStreetMap was used as the fallback.
- **Sent by or obtained from:** OpenStreetMap, through the Overpass API (`https://overpass-api.de/api/interpreter`, POST with the query in `overpass_query.txt`). Data snapshot: `osm_base` 2026-09-25T05:02:20Z (file header). Relation pages: `https://www.openstreetmap.org/relation/<id>`.
- **What it covers:** route relations (`type=route`, `route` bus or trolleybus) inside the box latitude -0.45 to 0.10, longitude -78.65 to -78.30, whose `network` is Metrobus-Q or whose `operator` is TROLEBUS, ECOVIA, CENTRAL NORTE, SUR ORIENTAL or SUR OCCIDENTAL, with all their member ways and nodes (OSM XML, WGS 84). Read with the GDAL OSM driver, layer `multilinestrings`: 175 relations (170 bus, 5 trolleybus). By `network`: Metrobus-Q 95, none 80. By `operator`: "Empresa Publica Metropolitana de Pasajeros de Quito" 94, CENTRAL NORTE 32, TROLEBUS 26, ECOVIA 16, SUR ORIENTAL 6, none 1. The trunk corridors (Trolebús, Ecovía, Central Norte MetroBus) are a subset; feeder routes and the Sur Oriental routes must be filtered out before the corridors are used as a BRT flag.
- **Terms of use:** Open Database License (ODbL). Credit: "© OpenStreetMap contributors". The file header states: "The data included in this document is from www.openstreetmap.org. The data is made available under ODbL."
- **Known gaps or caveats:**
  - Community-edited data, not an official source; route geometry and tagging depend on OSM contributors (the fetching agent reported last edits to the trunk relations between 2020-12 and 2026-04).
  - The fetching agent found gaps in several trunk relations (merged geometries break into 2 to 10 pieces) and no trunk relation for the Corredor Sur Occidental.
  - Where the two directions of a route run on different streets, both are present.
  - A snapshot of 2026-09-25: it shows the network after the metro opened, not as it was before December 2023.

## Files and sha256

```
84f498abf2e60350d894ce498a69f7a028a142682d3f131067240ecda7dcc1fd  ./osm_quito_brt_routes_20260925.osm
7c99efc5c2bec2852075595ae49385832bd830a11e093c13d6aab1b3d97a6e2e  ./overpass_query.txt
```

Checked on 2026-09-25: `sha256sum -c SHA256SUMS` passes for both files, and both checksums equal the values recorded at download in `reports/road_safety/2026-09-25_step1_report.md`.
