# air_quality: 2026-10-05_metro_validaciones_dic2023_may2025

- Store folder: `/home/leonelb/data/quito-metro-eval/air_quality/raw/2026-10-05_metro_validaciones_dic2023_may2025`
- Received on 2026-10-05; added to the store on 2026-10-05 by leonelb
- Copied from: /home/leonelb/staging/metro_validaciones/Información BID.xlsx /home/leonelb/staging/metro_validaciones/correo_vanessa_rodriguez.txt /home/leonelb/staging/metro_validaciones/punto 3 Información BID v2.xlsx
- **Sent by or obtained from.** Vanessa Rodríguez E., Metro de Quito, by email to Leonel Borja Plaza (`correo_vanessa_rodriguez.txt`, which summarizes the email).
- **What it covers.** Metro Line 1 validations (entries) from December 2023 to May 2025, 18 months:
  - `Información BID.xlsx`, sheet "Validaciones Dic 2023-Mayo 2025": monthly validations by station, 15 stations, with station and month totals.
  - `Información BID.xlsx`, sheet "Validac x Tipo Tarifa": monthly validations by fare type (base USD 0.45, reduced USD 0.22, preferential).
  - `punto 3 Información BID v2.xlsx`: validations by day, hour (column HORA), access medium (city card, ID card, anonymous QR, digital QR) and station, 149,487 rows. It also has an EMPRESA column, METRO or PASAJEROS, whose meaning is not documented.
  - Units: number of validations.
- **Terms of use.** Not confidential: Leonel's message of 2026-10-06. The email itself does not address terms.
- **Known gaps or caveats.**
  - **Hours.** The email says HORA is the real hour of validation, from 1 to 24, and that before 2024-03-27 the validators had no UTC setting and counted on a 12-hour clock (hours 1 to 12, no AM/PM).
    - **The file's labels.** HORA is labelled 00:00 to 23:00 in both periods.
    - **What the data show.** Before 2024-03-27, 99.3 percent of validations fall at 01:00 to 12:00 and almost none after 13:00. From 2024-03-27 they spread from 05:00 to 23:00. That is consistent with the email: the early hours are on a 12-hour clock, folded into 01:00 to 12:00.
    - **Consequence.** Any hourly use before 2024-03-27 is ambiguous; monthly totals are unaffected.
    - **Not asked.** Leonel decided on 2026-10-07 to ask Metro de Quito only about the station labels; hourly data are not used.
  - **The two files disagree on some station totals** (checked 2026-10-06, `air_quality/output/local/step2/ridership/totals_check_station_month.csv`, from `code/local/step2/ridership_test.py`). 250 of 270 station-months are equal.
    - **Swapped labels.** Most differences look like station labels swapped between the files; in these months the values are permuted and the system total is unchanged:
      - December 2023: San Francisco, Labrador and Iñaquito permuted. San Francisco is 389,085 in the monthly sheet and 513,260 in the hourly file.
      - December 2023: Solanda, La Alameda and La Magdalena partly permuted.
      - January 2024: Jipijapa and Cardenal de la Torre.
      - December 2024: El Ejido and La Carolina, plus Jipijapa and Cardenal de la Torre (168).
    - **Small differences.** Other cells differ by 1 to 25 validations, and the March and May 2025 system totals by 25 and 41.
    - **Overall.** The grand totals are 84,303,630 (monthly sheet) and 84,303,614 (hourly file).
    - **Which file is right is not known.** To ask Metro de Quito.
  - **Station names differ between the two files**; the mapping is in `ridership_test.py`.
  - **EMPRESA.** The hourly file splits validations between METRO (82,711,984) and PASAJEROS (1,591,630). PASAJEROS is passengers and is summed with METRO (Leonel, 2026-10-07); the station-month comparison above uses both.

## Files and sha256

```
a738f62e5865235a189dcd5bfe21f5031494d23547cc9676163417324543c87e  ./Información BID.xlsx
23ff9d0174ac4ff4f96602d172b2f9b907041b0971ba990d5e4f3ca2ed5ffc01  ./correo_vanessa_rodriguez.txt
a8a5c3c39eef90737c193d1d709a7cc82bd4112bd1353eb6de47dcc295f67dba  ./punto 3 Información BID v2.xlsx
```

All three pass `SHA256SUMS` (checked 2026-10-06).
