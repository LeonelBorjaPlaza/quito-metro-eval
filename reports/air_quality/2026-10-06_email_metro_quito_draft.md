# Borrador de correo a Metro de Quito (para que Leonel lo revise y lo envíe)

**Superseded on 2026-10-07.** Leonel sends shorter versions himself; what he asks is recorded in `DECISIONS.md` (2026-10-07). Kept for the record.

Borrador del 2026-10-06. No se ha enviado. Las cifras son totales agregados de los dos archivos entregados (`air_quality/output/local/step2/ridership/totals_check_station_month.csv`; `docs/data_provenance/air_quality__2026-10-05_metro_validaciones_dic2023_may2025.md`).

---

**Asunto:** Consultas sobre los archivos de validaciones (diciembre 2023 a mayo 2025)

Estimada Vanessa:

Muchas gracias por los archivos de validaciones que nos envió. Ya los estamos usando y nos han sido muy útiles. Al revisarlos nos surgieron tres consultas, para asegurarnos de interpretarlos correctamente.

**1. Totales por estación que no coinciden entre los dos archivos**

Comparamos el archivo mensual por estación ("Información BID.xlsx") con el archivo por día y hora ("punto 3 Información BID v2.xlsx") sumado por estación y mes. Coinciden en 250 de los 270 pares estación-mes. En 12 de los 20 restantes, las cifras parecen asignadas a estaciones distintas en uno y otro archivo; en esos meses (diciembre de 2023, enero de 2024 y diciembre de 2024) el total del sistema es el mismo en ambos archivos:

- **Diciembre de 2023: San Francisco, Labrador e Iñaquito.** Por ejemplo, San Francisco registra 389.085 validaciones en el archivo mensual y 513.260 en el archivo por hora; esta última cifra es la que el archivo mensual asigna a Labrador.
- **Diciembre de 2023: Solanda, La Alameda y La Magdalena.**
- **Enero de 2024: Jipijapa y Cardenal de la Torre.**
- **Diciembre de 2024: El Ejido y La Carolina, y en menor medida Jipijapa y Cardenal de la Torre.**

Los otros 8 son diferencias pequeñas, de 1 a 25 validaciones, en algunas estaciones de mayo y junio de 2024 y de marzo y mayo de 2025; en marzo y mayo de 2025 el total del sistema difiere en 25 y 41 validaciones.

¿Podría indicarnos cuál de los dos archivos tiene la asignación correcta por estación en esos meses?

**2. La columna "HORA"**

Su correo indica que la hora va de 1 a 24 y que, antes del 27 de marzo de 2024, los validadores contaban con un reloj de 12 horas. En el archivo, la columna HORA aparece con valores de 00:00 a 23:00 en todo el período. Antes del 27 de marzo de 2024, casi todas las validaciones (99,3 %) caen entre 01:00 y 12:00, lo que coincide con lo que usted explica.

- ¿El valor 01:00 corresponde a la validación hecha entre las 00:00 y las 01:00, o entre las 01:00 y las 02:00?
- Antes del 27 de marzo de 2024, ¿hay alguna forma de distinguir las horas de la mañana de las de la tarde?

**3. La categoría "PASAJEROS" en la columna EMPRESA**

En el archivo por hora, la columna EMPRESA tiene dos valores, "METRO" y "PASAJEROS" (este último suma 1.591.630 validaciones en todo el período).

- ¿Qué representa "PASAJEROS"?
- ¿Debe sumarse a "METRO" para obtener el total de validaciones de cada estación? Al sumar ambas, los totales coinciden con el archivo mensual en la mayoría de los meses.

Le agradezco de antemano su ayuda. Quedo atento a cualquier aclaración.

Saludos cordiales,

Leonel Borja Plaza
División de Transporte, Banco Interamericano de Desarrollo
