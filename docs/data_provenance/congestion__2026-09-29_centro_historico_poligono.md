# congestion: 2026-09-29_centro_historico_poligono

- Store folder: `/home/leonelb/data/quito-metro-eval/congestion/raw/2026-09-29_centro_historico_poligono`
- Received on 2026-09-29; added to the store on 2026-09-30 by leonelb
- Copied from: /tmp/chq/Quito_historic_center_GIS/README.md /tmp/chq/Quito_historic_center_GIS/boundary_preview.png /tmp/chq/Quito_historic_center_GIS/quito_historic_area.cpg /tmp/chq/Quito_historic_center_GIS/quito_historic_area.dbf /tmp/chq/Quito_historic_center_GIS/quito_historic_area.geojson /tmp/chq/Quito_historic_center_GIS/quito_historic_area.prj /tmp/chq/Quito_historic_center_GIS/quito_historic_area.shp /tmp/chq/Quito_historic_center_GIS/quito_historic_area.shx /tmp/chq/Quito_historic_center_GIS/source_layer_metadata.json /tmp/chq/Quito_historic_center_GIS/source_native_geometry.json
- Sent by or obtained from: downloaded by Leonel Borja Plaza on 2026-09-29 from GeoQuito, the Municipio del Distrito Metropolitano de Quito's public map service. Source: `web_reference_dmot/patrimonio/MapServer/6` ("Área histórica y patrimonial"), feature OBJECTID 41, "Área Histórica Centro Histórico de Quito", categoria "Área Histórica". The query URL is in the delivery's `README.md`.
- What it covers (period, units, variables): one polygon, the municipal historic area of the Centro Histórico, as published in the live service. It comes as GeoJSON and as a shapefile in WGS 84 (EPSG:4326), plus the native ArcGIS geometry in SIRES-DMQ and the layer metadata. The polygon is undated: the metadata give no adoption date or period of validity. Ordinance 081-2024 (Art. 3816 a) describes the Centro Histórico as the historic core, surrounding area, buffer zone and environmental protection area (copy in the `historic_center_geography` delivery). Since Amendment 2 of the congestion plan (2026-09-29), this polygon defines CENTER.
- Terms of use: public service, no licence stated by the portal item (`licenseInfo` null). Cite as "Municipio del Distrito Metropolitano de Quito, GeoQuito".
- Known gaps or caveats:
  - **Same polygon as the other delivery.** `quito_historic_area.geojson` is byte-identical to `area_historica_chq.geojson` in `congestion/raw/2026-09-29_historic_center_geography/` (both sha256 `9d9af32f…4435`), which Claude Code downloaded the same day. The code reads this delivery's copy, and both deliveries are cited.
  - **Areas.** The README gives 513.6341 ha in SIRES-DMQ (the source `STArea`) and 513.1635 ha geodesic on the WGS 84 ellipsoid. The congestion code recomputes both (`congestion/Output/step1_amendment2/polygon_areas.csv`).
  - **One wording slip in the README.** It says UNESCO lists a 375.25 ha buffer zone. The Plan de Acción's technical document gives the core as 70.43 ha and the buffer zone as 304.82 ha, so 375.25 ha is the two together (`reports/congestion/2026-09-29_historic_center_candidates.md`). The README is read-only and stays as delivered.

## Files and sha256

```
1ec94f4fab707709ce3dff050581e817ac9378196c1cd70d443ad4dcc7a504c4  ./README.md
3f671f192661745f8ccb563a97e1175f8d4abab434e5d8c4b89a1afd761bee93  ./boundary_preview.png
3ad3031f5503a4404af825262ee8232cc04d4ea6683d42c5dd0a2f2a27ac9824  ./quito_historic_area.cpg
ca97c66f82c4da6e2591ff82529c0edf1903df6841e94960336bd6142459e830  ./quito_historic_area.dbf
9d9af32f74ffc832d060d38f5d0c6e638e496923edbea5d730dc9afcb52f4435  ./quito_historic_area.geojson
a02a27b1d1982c8516d83398e85a3c8b1aef1713c13ef4d84d7bde17430c07c4  ./quito_historic_area.prj
d3b2e08464f382f04f40ce73b0a5dd01704048e7d5f535ae50d602015d600979  ./quito_historic_area.shp
fcd02343d1b8f605e2b6e21d251d522e27c86d220ef069f674807878ad0f1658  ./quito_historic_area.shx
32d71434c507d79571cf702b8ca88670913a0bf44a9fde085a670cb4a06dbf0a  ./source_layer_metadata.json
41cda748396878f49fe25843489857e74c981b1ffef06fdeb7228f3bf71a24b9  ./source_native_geometry.json
```
