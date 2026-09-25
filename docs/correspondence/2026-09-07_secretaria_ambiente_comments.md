# Comments from the Secretaría de Ambiente on the air quality draft

- **From:** María Valeria Díaz, Secretaría de Ambiente, Municipio de Quito, on 2026-09-04. Forwarded to Leonel by Vanessa Rodríguez, Directora de Investigación y Cooperación, Metro de Quito, on 2026-09-07.
- **Context:** On 2026-08-20 Leonel sent the working draft to Vanessa for the Secretaría, asking above all for comments on how the monitoring station data are used. He noted that the draft was not ready for official circulation and that a congestion analysis and crash data might be added later.
- **Attachment:** `DATOSFALTANTESPM2.5_ANALISISMETRO.xlsx`, hourly PM2.5 from 2025-01-13 00:00 to 2025-01-25 23:00 for nine stations, El Camal included. Stored in the air quality raw store; see `docs/data_provenance/`.

## The three comments

1. **PM2.5 in January and February 2025.** The draft reports a gap of several weeks for all stations. These data exist in REMMAQ, so we should check whether the break arose in the download or in processing. This differs from the 2024 power cuts, when some stations did lose data.
2. **Belisario.** It is an important station in the comparison group, and the precision of the result changes when it is excluded. Show more clearly how much weight it has in the synthetic control, or add a simple sensitivity. She does not suggest removing it, only strengthening the robustness of the result.
3. **Interpretation.** The PM2.5 result at Centro is interesting and holds across several specifications. The data show a reduction relative to the counterfactual after the Metro opened, but by themselves they cannot establish that it comes from people leaving their cars. NO2 and CO show no matching signal. It would be more prudent to describe the result as consistent with changes in mobility and accessibility in the Centro Histórico, and to leave modal substitution as one possible explanation.

## Where each comment is handled

- Comments 1 and 2: workstream A (air quality revision).
- Comment 3: paper text, drafted outside this repository, informed by workstreams B (congestion) and C (road safety).
