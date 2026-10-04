# Provider answers on missing records, monthly averaging and road length

From Juan Camilo (IDB Geo Indicators Hub, the Waze data provider), by email to Leonel Borja Plaza. Leonel passed the text on on 2026-09-29, and it was saved here that day. The email's own date is not recorded. The text below is verbatim, in the original Spanish.

They answer the questions in section 11 of the analysis plan on absent records (question 1), monthly averaging (question 2) and the meaning of Waze road length (question 3). The question on `tc_severe_persistance_ratio` above 100 (Amendment 1) has no answer yet.

---

1. Registros faltantes en all_roadtype: Si no hay observaciones para una celda-hora, significa que Waze no reportó congestión ahí. Esto puede deberse a que efectivamente no hubo congestión o a que sí hubo congestión pero no había usuarios de Waze que la reportaran. En nuestra metodología asumimos que, cuando no hay registro, esa zona estaba en freeflow, es decir, sin congestión.
2. Cálculo mensual de tci_osm_ratio: Es el promedio sobre todos los días hábiles del mes, contando como cero los días sin jam. Para cada celda-hora calculamos el TCI como los metros congestionados sobre los metros totales de OSM en esa celda. Luego agrupamos, por ejemplo, todas las observaciones de las 9 a.m. del mes, asignamos TCI = 0 a las celdas-hora sin información, sumamos y dividimos por el número de veces que esa hora se repite en los días hábiles del mes.
3. Longitud de red Waze en roadlengths_quito: No es la red que Waze tiene mapeada. La construimos a partir de los segmentos únicos reportados: para cada mes, deduplicamos los segmentos y calculamos cuántos metros hay en cada celda. Para 2019 tomamos el valor máximo entre todos los meses del año; para 2020, el máximo entre el valor anterior y el de enero de ese año, y así sucesivamente. La longitud refleja la red acumulada observada en los reportes, no la red total mapeada por Waze.
