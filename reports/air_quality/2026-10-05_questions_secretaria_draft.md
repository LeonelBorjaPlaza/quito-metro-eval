# Questions for the Secretaría de Ambiente: draft, revised 2026-10-05

**Superseded on 2026-10-07.** Leonel sends shorter versions himself; what he asks is recorded in `DECISIONS.md` (2026-10-07). Kept for the record.

Not sent (Leonel's decision of 2026-10-04). This replaces the eight questions at the end of `reports/data_audits/2026-10-01_aq_secretaria_pm25_gapfill.md`. Checked by the claims-auditor twice; the second pass's corrections are in.

**Dropped, because the new data answer them:** the origin and decimals of the Los Chillos gap-fill column (old question 1) and the Los Chillos gap of January and February 2025 (old question 2). The 2026-10-04 portal download fills Los Chillos from 2025-01-06 to 2025-03-02 (1,296 of 1,344 hours), and its values equal the Secretaría's file in every one of the 311 shared hours. **Dropped as minor:** the El Camal and Guamaní interruptions of 13 to 16 January 2025 (old question 6).

**Kept:** units and reference conditions, hour convention (with the new time stamps with seconds), empty cells and flags, the Los Chillos timing (rewritten), the later gaps (updated). **Added:** differences between the two sets of files, and the exact coordinates of every monitor.

**Sources.** Counts and dates: `air_quality/output/local/diagnostics/vintage_2026-10-04/` (`coverage_new_by_month.csv`, `loschillos_pm25_lag_by_month.csv`, `timing_by_month.csv`, `vintage_compare_station_month.csv`, `vintage_ratio_by_station_year.csv`, `rs_night_check.csv`, `vintage_inventory.csv`). Coordinates: `air_quality/output/local/diagnostics/monitor_distances/` and `reports/air_quality/2026-10-01_pm25_followup.md`, section 8. The QA/QC quotation: `Marco_QAQC_REMMAQ.pdf` in the new delivery, section 7.

**Question 6 and the May files.** Leonel confirmed on 2026-10-05 that all the May 2026 files came from the REMMAQ portal, so question 6 says so. The questions are not sent; Leonel will send them himself.

**Question 8, added 2026-10-06** (Leonel's decision): the SO2 and CO hours added or dropped between the May and October 2026 files. Source: comparison of the frozen and new `hourly_panel.csv`; see `docs/known_issues.md`.

## Preguntas (en español, listas para el correo)

1. **Unidades y condiciones de referencia.** ¿Confirman que el PM2.5 está en µg/m3, y en qué unidades están el CO (¿mg/m3?), el NO2 y el SO2 (¿µg/m3?)? ¿Las concentraciones se reportan a condiciones locales (presión y temperatura de Quito) o corregidas a condiciones estándar (25 °C, 1 atm)? ¿Es igual para todas las estaciones y para todo el período 2022 a 2026?

2. **Convención horaria.** ¿La hora registrada (por ejemplo, 07:00) corresponde al inicio del promedio (07:00 a 08:00) o al final (06:00 a 07:00)? ¿Es hora local de Ecuador (UTC-5)? En los archivos que descargamos del portal el 4 de octubre de 2026, desde diciembre de 2025 algunas marcas de tiempo incluyen segundos (en el archivo de CO, hasta 33 segundos después de la hora en punto). ¿Podemos asignarlas a la hora en punto más cercana?

3. **Celdas vacías y banderas.** En los archivos del portal, las horas sin dato aparecen como celdas vacías. ¿Una celda vacía significa dato invalidado por el control de calidad, o dato no registrado (falla de equipo o de energía)? El Marco QA/QC menciona una serie "separada en datos válidos, outliers y flags de auditoría". ¿Sería posible recibir esas banderas para PM2.5, CO, NO2 y SO2 en las estaciones Belisario, Carapungo, Centro, Cotocollao, Guamaní, Los Chillos, San Antonio y Tumbaco desde diciembre de 2022?

4. **Desfase horario del PM2.5 en Los Chillos.** En el archivo de PM2.5 que descargamos del portal el 4 de octubre de 2026, a partir de finales de 2024 la serie horaria de Los Chillos aparece unas dos horas más tarde que la de las demás estaciones. Comparada con el promedio de Belisario, Carapungo, Centro, Cotocollao y Tumbaco, su correlación es máxima con un retraso de dos horas o más en 15 de los 22 meses con datos entre octubre de 2024 y agosto de 2026, mientras que entre enero de 2023 y septiembre de 2024 el retraso era de cero o una hora todos los meses. Octubre y noviembre de 2024 tienen pocos datos (período de cortes de energía); diciembre de 2024 y enero de 2025 son los primeros meses en que el desfase es claro. En la misma estación, el pico de la mañana del CO cae a las 07:00 en todos los meses con datos suficientes desde 2023 (salvo octubre de 2024, a las 06:00), y la radiación solar no muestra el desfase. ¿Hubo algún cambio en el equipo de PM2.5 de Los Chillos a finales de 2024 (analizador, toma de muestra, configuración del promedio horario o del registrador)? Si lo hubo, ¿en qué fecha?

5. **Períodos sin datos en 2025 y 2026.** En los archivos descargados el 4 de octubre de 2026:
   - Guamaní no tiene datos de ninguna variable desde mediados de junio de 2025. En agosto de 2026 vuelven PM2.5, NO2, SO2, dirección y velocidad del viento y precipitación, pero no CO, temperatura, humedad, presión ni radiación solar.
   - San Antonio casi no tiene PM2.5 desde noviembre de 2025 (103 horas en noviembre y solo 2 horas entre diciembre de 2025 y agosto de 2026).
   - Los Chillos no tiene PM2.5 en noviembre de 2025, ni entre el 9 y el 22 de marzo de 2025.
   - Centro tiene muy pocos datos de NO2 en agosto de 2025 (38 horas), noviembre de 2025 (158 horas) y diciembre de 2025 (36 horas), y ninguno en enero y febrero de 2026.
   - Tumbaco no tiene CO desde abril de 2026.
   - El Camal no tiene datos de ninguna variable desde mediados de junio de 2026.

   ¿Se trata de períodos en que las estaciones o los equipos no midieron, o existen datos que no están publicados en el portal? Si existen, ¿podrían compartirlos? ¿La estación Guamaní se trasladó o se cerró en 2025?

6. **Diferencias entre los archivos de mayo y de octubre de 2026.** Al comparar los archivos descargados del portal el 4 de octubre de 2026 con los que descargamos del mismo portal en mayo de 2026 encontramos:
   - SO2 en Belisario, Centro y El Camal (2004 a 2007) y en Carapungo y Cotocollao (2005 a 2007): los valores nuevos son, en mediana por estación y año, entre 2,2 y 13 veces los anteriores.
   - SO2 en Centro, enero a marzo de 2026: los valores nuevos son, en mediana, entre 3 y 7 por ciento menores.
   - CO en Cotocollao, noviembre y diciembre de 2025: los valores nuevos son, en mediana, entre 19 y 25 por ciento menores.
   - PM2.5 en Los Chillos: 158 horas cambiadas en noviembre de 2024 y 176 en marzo de 2025.
   - PM2.5 en Guamaní: horas que tenían dato en los archivos de mayo ya no lo tienen (132 entre diciembre de 2022 y noviembre de 2023, y 112 entre diciembre de 2023 y marzo de 2025).
   - Radiación solar, febrero de 2026: en los archivos de mayo los valores promediaban entre 1 y 2 W/m2 de día y menos de 1 W/m2 de noche en todas las estaciones con datos; en los de octubre muestran el ciclo diario normal.

   ¿Nos pueden confirmar si estos cambios son revisiones de validación, y en qué consistieron? ¿Publican un registro de las revisiones de los datos históricos?

7. **Ubicación exacta de las estaciones.** Las coordenadas que tenemos para Belisario, Centro, El Camal y Los Chillos tienen solo dos decimales de grado (unos 1,1 km). ¿Podrían enviarnos las coordenadas actuales exactas (WGS84, latitud y longitud con al menos cinco decimales, o UTM) de los monitores de cada estación (Belisario, Carapungo, Centro, Cotocollao, El Camal, Guamaní, Los Chillos, San Antonio y Tumbaco), y las fechas de cualquier traslado de estación o de equipo entre 2022 y 2026, con las coordenadas anteriores?

8. **Horas de SO2 y CO que aparecen o desaparecen entre los archivos de mayo y de octubre (diciembre de 2022 al 22 de junio de 2025).** Entre ambas descargas, ningún valor horario que existía cambió, pero aparecen horas nuevas y desaparecen otras:
   - **SO2:** 376 horas nuevas (Belisario, Carapungo, Centro, Cotocollao, Los Chillos y Tumbaco, más 2 en Guamaní) y 18 que ya no aparecen. En las horas punta de días laborables, las horas nuevas promedian entre 18 y 24 µg/m3 en la mayoría de las estaciones y unos 50 en Los Chillos, frente a 5 a 7 µg/m3 en las horas que ya existían en las mismas semanas; es decir, entre 3,3 y 3,7 veces más en Belisario, Carapungo, Centro y Cotocollao, 4,6 veces en Tumbaco y 6,8 veces en Los Chillos.
   - **CO:** 30 horas nuevas (Centro, Los Chillos y Tumbaco, entre 2023 y 2024), que en horas punta promedian alrededor del doble de las horas existentes en las mismas semanas, y 111 horas de enero a junio de 2025 que ya no aparecen (Carapungo, Cotocollao, Guamaní y Tumbaco).

   ¿Estas horas habían sido invalidadas por el control de calidad y luego se restituyeron (o, en el caso del CO de 2025, se invalidaron después)? Si es así, ¿por qué motivo, y en qué fecha se hizo la revisión?
