# road_safety: 2026-09-25_geoquito_parroquias

- Store folder: `/home/leonelb/data/quito-metro-eval/road_safety/raw/2026-09-25_geoquito_parroquias`
- Received on 2026-09-25; added to the store on 2026-09-25 by leonelb
- Copied from: the session scratch folder of workstream C (`/tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/6c033877-b2c9-4fe4-ac20-ed61b13ed100/scratchpad/layers/boundary/geoquito_mdmq/`), where a Claude Code agent downloaded the files on 2026-09-25 at Leonel's request (Step 1 plan, decision 1: official parish boundaries, INEC or CONALI first, the Quito municipal geoportal second).
- **Sent by or obtained from:** GeoQuito, the geoportal of the Municipio del Distrito Metropolitano de Quito (ArcGIS Enterprise). All three items are owned by the portal account `soledad.anda`, created 2025-06-11 and modified 2025-08-01 (item metadata in the `item_*.json` files). The fetching agent reported the publishing organisation as the Secretaría de Hábitat y Ordenamiento Territorial; the saved metadata names only the owner account.
  - `PARROQUIAS_REF.zip`, item "Parroquias DMQ" (`6a1f9dc133a0400a9a66820f98cc5de6`). Download: `https://geoquito.quito.gob.ec/portal/sharing/rest/content/items/6a1f9dc133a0400a9a66820f98cc5de6/data`; page: `https://geoquito.quito.gob.ec/portal/home/item.html?id=6a1f9dc133a0400a9a66820f98cc5de6`.
  - `parr_urbana_ord002.zip`, item "parr_urbana_ord002" (`63b20d9e15524f7dad9e9df45c19e884`), described as "Parroquias urbanas oficiales, en base a la resolución oficial 2023 y ordenanza del DMQ 002". Download: `https://geoquito.quito.gob.ec/portal/sharing/rest/content/items/63b20d9e15524f7dad9e9df45c19e884/data`.
  - `parr_rural_conali.zip`, item "parr_rural_conali" (`ce306b3c414e40049991e68e29341c5c`), described as "Parroquias Rurales. origen de datos Conali". Download: `https://geoquito.quito.gob.ec/portal/sharing/rest/content/items/ce306b3c414e40049991e68e29341c5c/data`.
  - `item_*.json`: the portal's metadata for each item, saved at download.
- **What it covers:**
  - `PARROQUIAS_REF` (used by the pipeline): the 65 parishes of the Distrito Metropolitano de Quito as polygons in WGS 84 (EPSG:4326), fields `id`, `dpa_parroq` (INEC DPA code), `dpa_despar` (name). 32 urban parishes (codes 170101 to 170132) and 33 rural parishes (170151 and above); there is no urban or rural field, the split follows the code range. All 65 polygons are valid; total area 4,230.9 km²; no overlaps between parishes. Creation date in the embedded metadata (`PARROQUIAS_REF.shp.xml`): 2023-08-15.
  - `parr_urbana_ord002`: 32 urban parishes (Ordinance 002), EPSG:4326, fields `zonAdm_200`, `AD_ZONAL`, `dpa_parroq`, `dpa_despar`; 349.1 km².
  - `parr_rural_conali`: 33 rural parishes (CONALI origin, `DPA_ANIO` 2018), EPSG:4326, fields `DPA_PARROQ`, `DPA_DESPAR`, `DPA_CANTON`, `DPA_DESCAN`, `DPA_PROVIN`, `DPA_DESPRO`, `fcode`, `DPA_ANIO`, `A_ZONAL`; 3,836.9 km².
  - Areas computed in UTM 17S (EPSG:32717) on 2026-09-25 in this session.
- **Terms of use: not confirmed.** None of the three items carries a licence (`licenseInfo` and `accessInformation` are empty in the saved `item_*.json`). Pages to check:
  - the parish item's own page: `https://geoquito.quito.gob.ec/portal/home/item.html?id=6a1f9dc133a0400a9a66820f98cc5de6`;
  - the portal item where the fetching agent reported the only terms it found (the PUGS geodatabase, item `c5d6f9776b2547b7bc63b1984f0c904a`): `https://geoquito.quito.gob.ec/portal/home/item.html?id=c5d6f9776b2547b7bc63b1984f0c904a`. The agent quoted them as restricting use to academic, research and non-profit purposes, forbidding commercial redistribution and requiring credit to the Secretaría de Hábitat y Ordenamiento Territorial and Esri. That page was not saved, and the item ID comes from the agent's report only.
- **Known gaps or caveats:**
  - `parr_urbana_ord002` and `parr_rural_conali` do not fit together: they overlap in places and leave gaps (the claims audit measured 4.37 km² of overlap). The pipeline uses `PARROQUIAS_REF` only, which tiles the district.
  - The official INEC and CONALI downloads could not be fetched (the agent reported HTTP 403 errors and a registration form); INEC's 2012 parish layer has a single urban parish for Quito, so it cannot give urban parishes.
  - Boundaries as of the 2023 metadata date; no check against ordinances after that.

## Files and sha256

```
20012166d883a7de9800e117b159609e87bb21b29be35c341ba8bc7e782da96c  ./PARROQUIAS_REF.zip
75c6915af1b7ab89fbff7cc33dd239250af852f313afab683eed5f210f8fbe34  ./item_PARROQUIAS_REF.json
61f40b424dfb1f5a323bdf00500d46e2b86bb67be162e0e27026c8914073565f  ./item_parr_rural_conali.json
9987845943c628d7c1f430c264610edc6990c62039b070b5e5ebfeeaa5ba6402  ./item_parr_urbana_ord002.json
0a0624cea1296a102d4478934d6ef647ac02b9fbbeca4741c2aa0bf9b056fe64  ./parr_rural_conali.zip
da2f2d3c88f180a91f7927641177304428ffa336e3845d8a208922bb013d933e  ./parr_urbana_ord002.zip
```

Checked on 2026-09-25: `sha256sum -c SHA256SUMS` passes for all six files, and every checksum equals the value recorded at download in `reports/road_safety/2026-09-25_step1_report.md`.
