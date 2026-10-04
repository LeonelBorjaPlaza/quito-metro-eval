# congestion: 2026-09-29_historic_center_geography

- Store folder: `/home/leonelb/data/quito-metro-eval/congestion/raw/2026-09-29_historic_center_geography`
- Received on 2026-09-29; added to the store on 2026-10-01 by leonelb
- Copied from: /tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/delivery/historic_center_geography/SOURCES.md /tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/delivery/historic_center_geography/area_historica_chq.geojson /tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/delivery/historic_center_geography/item_89b77d62749a457b9bafb87cfd1478f9.json /tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/delivery/historic_center_geography/item_979cde91eb6440d6bab77bd01a72ea1e.json /tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/delivery/historic_center_geography/item_eec3e769cb4b4bc3a6a27eb85d722d2a.json /tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/delivery/historic_center_geography/limite_plan_chq_a.geojson /tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/delivery/historic_center_geography/limite_plan_chq_a.zip /tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/delivery/historic_center_geography/ord_081_2024.pdf /tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/delivery/historic_center_geography/osm_chq.osm /tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/delivery/historic_center_geography/osm_landmarks1.json /tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/delivery/historic_center_geography/osm_landmarks2.json /tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/delivery/historic_center_geography/osm_streets.json /tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/delivery/historic_center_geography/pachq_doc_tecnico.pdf /tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/delivery/historic_center_geography/pat6.json /tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/delivery/historic_center_geography/pat6_attrs.json /tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/delivery/historic_center_geography/patrimonio_ms.json /tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/delivery/historic_center_geography/unesco_173425_map.pdf /tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/delivery/historic_center_geography/whc_way_history.xml
- Sent by or obtained from: downloaded by Claude Code (workstream B) on 2026-09-29, 18:03 to 18:20 America/Guayaquil, from public web sources without login. Per-file URLs are in the delivery's `SOURCES.md`.
- What it covers (period, units, variables):
  - the candidate polygons for the historic center, compared in `reports/congestion/2026-09-29_historic_center_candidates.md`: GeoQuito feature 41 (Área Histórica), the Plan de Acción boundary, and the OSM World Heritage outline and parish relation;
  - the OSM landmark and street extracts used for the checks;
  - the UNESCO map of the inscribed property (document 173425, 2019);
  - the Plan de Acción technical document and Ordinance 081-2024.

  Under Amendment 2, the OSM World Heritage outline (way 1077782502) defines the secondary, descriptive core unit.
- Terms of use:
  - GeoQuito files: public DMQ services and documents, no licence stated. Cite "Municipio del Distrito Metropolitano de Quito, GeoQuito".
  - OpenStreetMap files (`osm_chq.osm`, `whc_way_history.xml`, `osm_landmarks1.json`, `osm_landmarks2.json`, `osm_streets.json`): Open Database Licence (ODbL) 1.0. Any map or table derived from them must carry the credit "© OpenStreetMap contributors".
  - `unesco_173425_map.pdf`: © UNESCO. **UNESCO's terms of use have not been checked.** Before any figure containing the map image leaves the repository, its terms must be checked. That includes `reports/congestion/2026-09-29_historic_center_candidates/map_candidates_over_unesco.png`.
- Known gaps or caveats:
  - **The core outline is volunteer-traced.** OSM way 1077782502 was traced from the UNESCO map by a volunteer in 2022 (changeset 123490726); it is not an official file.
  - **The UNESCO map's printed grid is offset** from SIRES-DMQ by about 246 m east and 366 m north (`docs/known_issues.md`).
  - **Feature 41 is delivered twice.** `area_historica_chq.geojson` is byte-identical to `quito_historic_area.geojson` in `congestion/raw/2026-09-29_centro_historico_poligono/` (sha256 `9d9af32f…4435`). The code reads the copy in that delivery, and both deliveries are cited.
  - **The OSM files are snapshots of 2026-09-29.** The OSM outline can change after that date.

## Files and sha256

```
a3adfa35f2a2269fdc1d103bc1e01534445af6b0c5996b70cd3a665cc2e5a820  ./SOURCES.md
9d9af32f74ffc832d060d38f5d0c6e638e496923edbea5d730dc9afcb52f4435  ./area_historica_chq.geojson
436c4229da94b65cb863b132574def3eb07c87f6cd991eecfa3fbc5f07f710c7  ./item_89b77d62749a457b9bafb87cfd1478f9.json
83ed7a6ff6860cdaadd84d86aa4fceca23098498b62d652dc205356de1fe633f  ./item_979cde91eb6440d6bab77bd01a72ea1e.json
57cd2f161e4694a518b9c2abb89b9cad9402d0af4c333591d0268a5efe09d378  ./item_eec3e769cb4b4bc3a6a27eb85d722d2a.json
e0b8228aee87e47185d80dd3ac621506bdda94944a6673ef351387f91eedff4e  ./limite_plan_chq_a.geojson
5f4b2e19a187fb16bb5783fd3559c5f900314c0ad928a1ca3ebfdb4015447801  ./limite_plan_chq_a.zip
51870636d51f72fa96b993af0bc310dde68fcc00085c7cc4e621d817952865a2  ./ord_081_2024.pdf
dcc795186e604bb8d6aa1ef282a322c973064648ce496f3bee2d7cf3b49f880e  ./osm_chq.osm
2ad5d18209c8b1d912d6256bf2c98c3f6d3e564d9813b538d49d2e8ab5c3a46a  ./osm_landmarks1.json
75698dd55f0bc13e61ca14353e74b8aaba947b718cad1651c0ae296ca2eb6e86  ./osm_landmarks2.json
e79915e28efb41ebc3705ac6bca4a656dc2662b78b9d0ebd6c2b7dcb31bf537a  ./osm_streets.json
a83a51b38cbb0199359ab1dbb33ac1897ab360c3fe0e6d570e68f7d578e6e380  ./pachq_doc_tecnico.pdf
21baf197c5f29e01db7f843c66e8fa6aed5bcdaf9e66baea9143edc716816820  ./pat6.json
daa3417e97e8a78c109b432164ad32e91c11e3814ca60dbf375f4504a61d14aa  ./pat6_attrs.json
8e34ba807dcd4be253261b63fbab034c0da7c30ecbc8d2b3fe0a68ad01114014  ./patrimonio_ms.json
24250379cf0049775bf7296f237af8043f9036468514e22e46e87f6aec7726bc  ./unesco_173425_map.pdf
4c644cc8c137bf3c2c14083a5ddce072b062cf9353952986987098584b51f37a  ./whc_way_history.xml
```
