**Documentación de Indicadores Waze**

*Guia conceptual y metodológica*

------------------------------------------------------------------------

*Indicadores de congestion vehicular y velocidad de circulación construidos a partir de datos de Waze for Cities Program, diseñados para apoyar proyectos de evaluación de impacto y reportes de proyectos.*

**Contenido del documento**

------------------------------------------------------------------------

**1. Introducción** *Que es esta documentación y para quien.*

**2. Fuente de datos y unidades de medida** *Waze, OSM y las unidades espaciales/temporales.*

**3. Unidades geográficas y tipos de vía** *Niveles L0-L3, MR, grid H3 resolución 8 y clasificación roadtype.*

**4. Indicadores de congestión** *TCI, TCS, TCP y sus ratios.*

**5. Indicadores de velocidad** *Free-flow, jam speed, speed y ratios.*

**6. Congestión severa** *Variantes calculadas solo con los jams de severidad alta de Waze (jam_level 3 y 4).*

**7. Agregaciones temporales** *Hora, día, grupos horarios; mensual y anual.*

**8. Como interpretar los datos** *Sesgos, banderas y buenas prácticas.*

**9. Tabla resumen de variables** *Diccionario rápido por columna.\*

**1. Introducción**

------------------------------------------------------------------------

Este documento describe el conjunto de indicadores de tráfico que el equipo de SPD/SDV construye a partir de los datos del Waze for Cities Program. Los indicadores están diseñados para apoyar proyectos de evaluación de impacto del BID que requieran medir condiciones de tráfico (congestión y velocidad) de forma comparable a lo largo del tiempo y entre regiones de America Latina y el Caribe.

El procesamiento se hace en dos etapas: primero, el pipeline ‘multiplesgeos’ construye el dataset base por celda H3 y hora, a partir de las jam lines crudas. Luego, 'waze_tci_summarized_data' produce agregaciones temporales (horarias, diarias y por grupos de horas, mensuales y anuales) en varios niveles geograficos (grid H3 y divisiones administrativas L0 a L3, además de regiones metropolitanas MR).

| **PARA QUIEN ES ESTE DOCUMENTO** |
|:---|
| Personas que necesitan elegir indicadores de tráfico para una evaluación de impacto. Cada sección combina la definición conceptual, la formula con la que el indicador se calcula en el pipeline, una guía de interpretación y un ejemplo numérico. No se requiere experiencia previa con datos de Waze. |

**2. Fuente de datos y unidades de medida**

------------------------------------------------------------------------

**2.1 Fuente primaria: Waze for Cities**

------------------------------------------------------------------------

Los datos provienen del Waze for Cities Program. Waze recibe pasivamente información del tráfico mientras la aplicación esta activa en los teléfonos de sus usuarios. Cuando un punto geográfico presenta velocidades menores a las esperadas en condiciones normales, Waze crea una 'jam line': un segmento continuo de vía con velocidad reducida.

Cada jam line trae geometría, velocidad reportada, demora, longitud y nivel de severidad. Estas líneas se publican aproximadamente cada dos minutos (feed frequency = 5 min nominal en el pipeline; el número exacto de observaciones esperadas por hora es 12).

| **QUE NO MIDE WAZE** |
|:---|
| Waze observa congestión, no volumen de vehículos. Si una vía fluye sin atascos, el dato no dice cuántos autos circulan: solo dice que no hay jam. Por lo tanto, los indicadores aquí descritos son medidas de congestión y de velocidad, no de aforos. Cuando la demanda es alta la correlación con volumen es fuerte; en regímenes de flujo libre el dato no informa volumen. |

**2.2 Red vial de referencia: OSM y Waze**

------------------------------------------------------------------------

Para construir ratios de congestión necesitamos una referencia de cuanta vía existe. Usamos dos referencias alternativas:

- **OSM:** longitud de la red vial reportada por OpenStreetMap (OSM) para la celda o region.

- **Waze:** longitud derivada de Waze, calculada como la longitud agregada de todos los segmentos que alguna vez aparecieron como jam en el año (con el ajuste de que un año no puede tener menos que el máximo de los años previos).

Esto resuelve un sesgo importante: en zonas con baja penetración de Waze, OSM puede contener vías que nunca se observan en el feed, lo cual artificialmente baja los ratios. La referencia Waze ofrece una visión condicional a lo que la app efectivamente ve. En más del 99% de los casos la longitud Waze es menor que la de OSM; cuando excepcionalmente sucede lo contrario, se trunca para que no la supere.

**3. Unidades geográficas y tipos de vía**

------------------------------------------------------------------------

Los indicadores están disponibles en dos familias de unidades espaciales:

| **Nivel** | **Descripcion** | **Tipico para** |
|----|----|----|
| L0 | Pais (codigo OCHA/HDX). | Comparaciones internacionales. |
| L1 | Primera division administrativa (estado, departamento, provincia). | Analisis subnacional amplio. |
| L2 | Segunda division administrativa (municipio, comuna, canton). | Politicas urbanas y municipales. |
| L3 | Tercera division administrativa (parroquia, distrito). | Analisis fino dentro de una ciudad. |
| MR | Region metropolitana. | Estudios de movilidad metropolitana. |
| Grid H3 (res 8) | Celdas hexagonales de aproximadamente 0.74 km² (~460 m de lado). | Granularidad maxima; analisis espacial. |

Internamente, cada segmento de vía se mapea a celdas H3 conservando la proporción de longitud que cae dentro de cada celda. Esto permite agregar métricas ponderadas por longitud sin duplicar conteos cuando un segmento cruza varias celdas.

**3.1 Tipos de vía (roadtype)**

------------------------------------------------------------------------

Además de la dimensión espacial, todos los indicadores se publican desagregados por tipo de vía (columna roadtype). La clasificación se hace por segmento según su free-flow speed (ver sección 5.1) y cada fila del dataset lleva uno de los seis valores posibles:

| **Valor** | **Criterio (free-flow)** | **Descripcion** |
|----|----|----|
| small | \< 30 km/h | Vias chicas: calles locales y residenciales. |
| medium | 30 - 50 km/h (extremos inclusive) | Vias intermedias: colectoras y avenidas menores. |
| large | \> 50 km/h | Vias grandes: arterias principales y autopistas. |
| minor_2_levels | \< 40 km/h | Clasificacion alternativa de 2 niveles: vias menores. |
| major_2_levels | \> 40 km/h | Clasificacion alternativa de 2 niveles: vias mayores. |
| all_roadtype | Todas las vias | Agregado de todos los segmentos, sin distinguir tipo. |

La clasificación de 2 niveles se crea en el pipeline ‘multiplesgeos’ como una partición alternativa más gruesa, con un único corte en 40 km/h (parámetro lower_bound_2_levels de la configuración): minor_2_levels agrupa los segmentos con free-flow menor a 40 km/h y major_2_levels los segmentos con free-flow mayor a 40 km/h. Un segmento cuyo free-flow es exactamente 40 km/h no recibe clasificación de 2 niveles (la comparación es estricta en ambos lados), aunque sí conserva su categoría de 3 niveles (medium).

Por su parte, all_roadtype no es una categoría de velocidad sino el agregado total: el pipeline toma la unión de todos los segmentos (sin importar su tipo), la re-etiqueta como 'all_roadtype' y calcula los indicadores sobre ese conjunto completo. Es el valor a usar cuando el análisis no requiere desagregar por tipo de vía; las categorías de 3 niveles (small/medium/large) y las de 2 niveles (minor/major) son particiones de ese mismo total, y los tres bloques se publican unidos en la misma tabla.

<table style="width:92%;">
<colgroup>
<col style="width: 92%" />
</colgroup>
<thead>
<tr>
<th>roadtype (3 niveles): small si freeflow &lt; 30 km/h<br />
medium si 30 &lt;= freeflow &lt;= 50 km/h<br />
large si freeflow &gt; 50 km/h<br />
roadtype (2 niveles): minor_2_levels si freeflow &lt; 40 km/h<br />
major_2_levels si freeflow &gt; 40 km/h<br />
all_roadtype: union de todos los segmentos de la celda/region</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

| **RED VIAL POR ROADTYPE** |
|:---|
| Para los ratios por tipo de vía, la longitud de red OSM de la celda se reparte entre los roadtypes proporcionalmente a la longitud Waze observada de cada tipo (factor roadlength_adjust = longitud del roadtype / longitud total de la celda). Así, el denominador de tci_osm_ratio para 'small' es la porción de la red OSM atribuible a vías chicas, y las porciones suman la red total que usa all_roadtype. |

**4. Indicadores de congestion**

------------------------------------------------------------------------

**4.1 Traffic Congestion Intensity (TCI)**

------------------------------------------------------------------------

**Que es**

El TCI es la suma de la longitud de todas las jam lines observadas en una geografía durante una ventana temporal definida. Si las jam lines se miden cada 5 minutos durante una hora, cada jam line se cuenta hasta 12 veces (una por cada observación en la que aparezca). Por eso el TCI captura simultáneamente cuanta vía esta congestionada y cuánto tiempo dura la congestión.

**Como se calcula**

| TCI = sum(longitud de jam_lines observadas en la ventana temporal) |
|--------------------------------------------------------------------|

**Interpretación**

El TCI esta expresado en metros (o en metros·observaciones, depende del enfoque). Valores altos indican más congestión (más vía afectada y/o por mas tiempo durante esa hora). Es dificil de comparar entre geografías de distinto tamaño porque mezcla extensión y duración; para comparar, usar el TCI ratio.

| **EJEMPLO · Calculo del TCI en una celda H3** |
|:---|
| Supongamos una celda con 10 jam lines no superpuestas, cada una de 150 m, dentro de una hora. Tenemos 1.500 m de via en jam en algun momento de la hora. Si en la celda A los jams duran 20 minutos cada uno, cada jam se observa 4 veces (cada 5 min). El TCI de A es 1.500 m × 4 = 6.000. Si en la celda B duran 10 minutos, cada jam se observa 2 veces, y el TCI de B es 1.500 × 2 = 3.000. Misma extensión instantánea, pero la celda A tiene el doble de TCI porque sus jams duran más. |

**4.2 TCI ratio (OSM y Waze)**

------------------------------------------------------------------------

**Que es**

Normalización del TCI por la longitud de la red vial y el número de observaciones en la ventana. Es el indicador insignia para comparar congestión entre lugares y a lo largo del tiempo. Se expresa en porcentaje.

**Como se calcula**

<table style="width:92%;">
<colgroup>
<col style="width: 92%" />
</colgroup>
<thead>
<tr>
<th>tci_osm_ratio = TCI / (osm_roadlength × N_obs) × 100<br />
tci_waze_ratio = TCI / (waze_roadlength × N_obs) × 100<br />
donde N_obs = datetime_group / feed_frequency (p.ej. 60 / 5 = 12 obs/hora)</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

**Interpretación**

Se lee como 'porcentaje de los metros·observacion posibles que estuvieron congestionados'. Un tci_osm_ratio de 5% en una celda significa que, en promedio, el 5% de la red vial estuvo en jam durante la ventana. Es directamente comparable entre celdas y entre periodos.

| **OSM vs Waze** |
|:---|
| Usar tci_osm_ratio cuando se quiera referir el indicador a toda la red existente. Usar tci_waze_ratio cuando interese controlar por penetración de la app: este último se calcula sobre la red que efectivamente Waze ha 'visto' alguna vez ese año. En zonas con poca penetración los dos pueden divergir y el ratio Waze suele ser más alto. |

| **EJEMPLO · Calculo del TCI ratio** |
|:---|
| Tomando las celdas del ejemplo anterior: la celda A tiene TCI = 6.000 y 30.000 m de red OSM; la celda B tiene TCI = 3.000 y 25.000 m. Con 12 observaciones por hora: tci_osm_ratio(A) = 6.000 / (30.000 × 12) × 100 = 1.66%. tci_osm_ratio(B) = 3.000 / (25.000 × 12) × 100 = 1.00%. En términos absolutos A tiene el doble de TCI que B, pero ajustado por red, A es 66% más congestionada que B. |

**4.3 Traffic Congestion Spread (TCS)**

------------------------------------------------------------------------

**Que es**

El TCS es la suma de la longitud de los segmentos de vía que estuvieron en jam al menos una vez durante la ventana temporal. A diferencia del TCI, el TCS no cuenta repetidamente: si un segmento estuvo jam durante 5 minutos o durante 50, se cuenta una sola vez.

**Como se calcula**

| TCS = sum(longitud de segmentos que tuvieron al menos un jam en la ventana) |
|----|

**Interpretación**

El TCS captura la extensión geográfica de la congestión, sin importar su duración. Es útil para responder '¿qué tan extendida fue la congestión en la zona?'.

| **EJEMPLO · TCS de A y B** |
|:---|
| En el ejemplo del TCI, tanto A como B tienen 10 jam lines no superpuestas de 150 m. Por lo tanto el TCS de A y B es 1.500 m: la misma extensión geográfica, aunque en A los jams duraron el doble de tiempo. TCS no distingue duracion. |

**4.4 TCS ratio (OSM y Waze)**

------------------------------------------------------------------------

**Que es**

Normalización del TCS por la longitud de la red vial. Se expresa en porcentaje y representa el porcentaje de la red vial que vivió al menos un episodio de jam en la ventana.

**Como se calcula**

<table style="width:92%;">
<colgroup>
<col style="width: 92%" />
</colgroup>
<thead>
<tr>
<th>tc_spread_osm_ratio = TCS / osm_roadlength × 100<br />
tc_spread_waze_ratio = TCS / waze_roadlength × 100</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

**Interpretación**

Un valor de 5% indica que el 5% de la red vial estuvo congestionada en algún momento. Útil para distinguir entre zonas con congestión concentrada (TCS bajo, TCI alto) y zonas con congestión difusa (TCS alto, TCI moderado).

| **EJEMPLO · TCS ratio en A y B** |
|:---|
| Con 30.000 m de vía en A y 25.000 m en B: tc_spread_osm_ratio(A) = 1.500 / 30.000 × 100 = 5%; tc_spread_osm_ratio(B) = 1.500 / 25.000 × 100 = 6%. En B el porcentaje de la red afectada es mayor que en A, aun cuando los jams de A duran más. |

**4.5 Traffic Congestion Persistence (TCP)**

------------------------------------------------------------------------

**Que es**

El TCP es la razón entre TCI y TCS, normalizada por el número de observaciones. Aproxima la duración promedio de la congestión en los segmentos que efectivamente se congestionaron.

**Como se calcula**

<table style="width:92%;">
<colgroup>
<col style="width: 92%" />
</colgroup>
<thead>
<tr>
<th>tc_persistance_ratio = (TCI / TCS) / N_obs × 100<br />
= (TCI / TCS) / (datetime_group / feed_frequency) × 100</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

**Interpretación**

Se expresa como porcentaje del tiempo total observado. Un TCP de 30% significa que, en los segmentos que se congestionaron, la congestión duro en promedio el 30% de la ventana. Permite distinguir si la congestión fue puntual (TCP bajo) o crónica (TCP alto).

| **EJEMPLO · TCP de A y B** |
|:---|
| Para A: TCI = 6.000, TCS = 1.500, 12 observaciones. TCP(A) = (6.000 / 1.500) / 12 × 100 = 33.3%. Para B: TCI = 3.000, TCS = 1.500, 12 obs. TCP(B) = (3.000 / 1.500) / 12 × 100 = 16.7%. Confirma que los jams en A duraron, en promedio, el doble que en B (40 vs 20 min sobre la hora, interpretado como fracción del periodo). |

**5. Indicadores de velocidad**

------------------------------------------------------------------------

Como Waze solo observa jam speed cuando hay jams, para construir velocidades representativas necesitamos una referencia: la free-flow speed. La idea es asumir que, cuando no hay jam, los vehículos circulan a velocidad libre, y combinar ambas velocidades ponderando por el tiempo congestionado para obtener una velocidad esperada.

**5.1 Free-flow speed (avg_freeflow)**

------------------------------------------------------------------------

**Que es**

La velocidad a la que circula el tráfico sin impedimentos en cada segmento. Es una estimación mensual e invariable dentro del mes, obtenida a partir de la velocidad implícita en la variable 'delay' que reporta Waze: como el delay es el tiempo adicional frente al recorrido sin congestión, combinando la velocidad observada, el delay y la longitud del segmento se recupera la velocidad libre implícita de cada observación.

**Como se calcula**

<table style="width:92%;">
<colgroup>
<col style="width: 92%" />
</colgroup>
<thead>
<tr>
<th>Por observacion de jam: freeflow = 1 / (1/speed - delay/length) × 3.6 (m/s → km/h)<br />
Por segmento (mes): promedio ponderado por longitud de sus observaciones<br />
avg_freeflow (por celda H3 / region) = promedio ponderado por longitud sobre los segmentos</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

**Uso**

Sirve como denominador en todos los ratios de velocidad y como sustituto del comportamiento no congestionado al construir la velocidad promedio. También se usa para clasificar los segmentos por tipo de vía (roadtype): small (\<30 km/h), medium (30-50 km/h) y large (\>50 km/h), además de la clasificación de 2 niveles y el agregado all_roadtype descritos en la sección 3.1.

| **EJEMPLO · Free-flow en una via urbana** |
|:---|
| Una avenida principal cuyos segmentos tienen velocidades de flujo libre implícitas entre 55 y 65 km/h obtiene un avg_freeflow del orden de 60 km/h. Si durante el dia el jam_speedkmh medido en la celda baja a 18 km/h, la referencia libre sigue siendo 60 km/h y los ratios se calculan respecto a ese valor. |

**5.2 Jam speed (jam_speedkmh)**

------------------------------------------------------------------------

**Que es**

Velocidad promedio observada por Waze en condiciones de jam. Es el promedio de la velocidad reportada en los eventos de jam detectados en la red de la celda o región durante la ventana.

**Como se calcula**

| jam_speedkmh = promedio(velocidad_reportada_en_jam_events) |
|------------------------------------------------------------|

**Interpretación**

Es la velocidad efectiva cuando ocurre congestión. No depende de cuánto tiempo dure el jam: solo informa que tan lento circulan los vehículos cuando están en jam.

**5.3 Jam speed ratio (jam_speed_ratio)**

------------------------------------------------------------------------

**Que es**

Razón entre la velocidad observada en jam y la free-flow speed, expresada en porcentaje. Cuantifica que tan severa es la congestión cuando ocurre, sin importar la duración.

**Como se calcula**

<table style="width:92%;">
<colgroup>
<col style="width: 92%" />
</colgroup>
<thead>
<tr>
<th>jam_speed_ratio = (jam_speedkmh / avg_freeflow) × 100<br />
(con salvaguarda: si el ratio cae entre 100 y 101 por ruido, se fija en 100)</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

**Interpretación**

Un jam_speed_ratio de 40% significa que en condiciones de jam los vehículos circulan al 40% de la velocidad libre. Valores cercanos a 100% indican jams muy leves; valores cercanos a 0 indican jams severos.

| **EJEMPLO · Jam speed ratio en hora pico** |
|:---|
| En una celda con avg_freeflow = 50 km/h y jam_speedkmh promedio en hora pico de 15 km/h, jam_speed_ratio = 15 / 50 × 100 = 30%. En la misma celda en horario nocturno con jam_speedkmh = 45 km/h, jam_speed_ratio = 90%. Es decir, los jams del nocturno (cuando ocurren) son leves. |

**5.4 Speed (speed)**

------------------------------------------------------------------------

**Que es**

Velocidad promedio esperada en la celda y la hora. Como no hay observación directa de velocidad cuando no hay jam, se construye como una combinación lineal entre la velocidad de jam y la free-flow, ponderada por el porcentaje del tiempo congestionado (tci_osm_ratio).

**Como se calcula**

| speed = jam_speedkmh × (tci_osm_ratio / 100) + avg_freeflow × (1 - tci_osm_ratio / 100) |
|----|

En palabras: durante la fracción del tiempo en jam se asume jam_speedkmh; durante el resto, free-flow.

**Interpretación**

Es la mejor aproximación a 'que velocidad promedio vería un viajero genérico en esa celda y hora'. Mas comparable temporalmente que jam_speedkmh porque incorpora cuanto duro la congestión.

| **EJEMPLO · Speed con 20% del tiempo en jam** |
|:---|
| avg_freeflow = 50 km/h, jam_speedkmh = 20 km/h, tci_osm_ratio = 20%. speed = 20 × 0.20 + 50 × 0.80 = 4 + 40 = 44 km/h. La velocidad esperada es 44 km/h, mas alta que el jam_speedkmh porque la mayor parte del tiempo la circulacion fue libre. |

**5.5 Speed ratio (speed_ratio / t_speed_ratio)**

------------------------------------------------------------------------

**Que es**

Razón entre la velocidad esperada y la free-flow, en porcentaje. Indica cuan cerca esta la circulación promedio de su velocidad libre teórica.

**Como se calcula**

| speed_ratio = speed / avg_freeflow × 100 |
|------------------------------------------|

**Interpretación**

Valores cercanos a 100% indican condiciones de flujo libre; valores menores reflejan mayor presión del tráfico. Es la métrica más intuitiva para reportar 'cuánto cuesta la congestión' en términos de velocidad.

| **EJEMPLO · Speed ratio del ejemplo anterior** |
|:---|
| Con speed = 44 km/h y avg_freeflow = 50 km/h: speed_ratio = 44 / 50 × 100 = 88%. En promedio, los vehículos en esa celda y hora se mueven al 88% de su velocidad libre. |

**6. Indicadores de congestion severa**

------------------------------------------------------------------------

Waze asigna a cada jam un nivel de severidad (jam_level) según qué tanto se reduce la velocidad respecto a las condiciones normales de la vía. Además de los indicadores calculados con todos los jams, los pipelines computan versiones 'severas' considerando únicamente los jams cuyo nivel de severidad reportado por Waze es 3 o 4 (jam_level IN (3, 4)).

| **Indicador** | **Version severa** | **Que mide** |
|----|----|----|
| TCI / tci_osm_ratio | severe_tci / tci_severe_osm_ratio | Intensidad de jams muy lentos. |
| TCI / tci_waze_ratio | severe_tci / tci_severe_waze_ratio | Idem, normalizando por red Waze. |
| TCS / tc_spread | tc_severe_spread | Extension de la red con jams muy lentos. |
| TCS ratio (OSM/Waze) | tc_severe_spread_osm_ratio / tc_severe_spread_waze_ratio | Porcentaje de red con jam severo. |
| TCP | tc_severe_persistance_ratio | Duracion media de jams severos. |

| **PROPIEDAD UTIL** |
|:---|
| Por construcción, los ratios severos son siempre menores o iguales a los totales: los jams severos son un subconjunto del total. Usar las versiones severas cuando el interés del estudio sea capturar congestión realmente disruptiva (no solo lentitud moderada). |

**7. Agregaciones temporales**

------------------------------------------------------------------------

Todos los indicadores se entregan agregados a varios niveles temporales. La elección del nivel depende del tipo de pregunta y de la cantidad de observaciones disponibles en la celda o región.

**7.1 Perfiles horarios (hourly)**

------------------------------------------------------------------------

Promedios por hora del día (0 a 23) calculados sobre todos los días del periodo. Útil para analizar el ciclo diario de congestión, identificar horas pico y comparar perfiles entre regiones.

**7.2 Promedio diario (daily)**

------------------------------------------------------------------------

Promedio del indicador a lo largo del día, agregado en el periodo. Indicado para comparaciones puntuales entre días o entre subperiodos.

**7.3 Grupos de horas (group hours)**

------------------------------------------------------------------------

Promedios por bloque horario, definidos en el pipeline como:

| **Grupo** | **Rango horario** | **Etiqueta** |
|-----------|-------------------|--------------|
| hg_1      | 06:00 - 10:00     | AM peak      |
| hg_2      | 10:00 - 15:00     | Midday       |
| hg_3      | 15:00 - 21:00     | PM peak      |
| hg_4      | 21:00 - 06:00     | Night        |

Estos grupos son útiles cuando se quieren reportar resultados resumidos sin perder el ciclo diario completo (un tradeoff entre granularidad y simplicidad).

**7.4 Ventanas: mensual y anual**

------------------------------------------------------------------------

Tanto los perfiles horarios como los diarios y los de grupos de horas se ofrecen en dos ventanas: mensual (un valor por mes para cada hora/dia/grupo) y anual (un valor por año). También existen variantes que separan días hábiles de fines de semana (parametros start_day / end_day en el pipeline).

| **REGLA PRACTICA** |
|:---|
| Para evaluaciones de impacto que comparen un antes y un después, las agregaciones mensuales por hora suelen ser la combinación más potente: permiten controlar por estacionalidad, comparar hora-a-hora y construir series temporales suficientemente largas. |

**8. Como interpretar los datos**

------------------------------------------------------------------------

**8.1 Sesgo por penetración de Waze**

------------------------------------------------------------------------

La cantidad de jams reportada depende de cuantos usuarios haya en la zona. Una caída en el indicador puede reflejar menos congestión o menos usuarios. Esto es especialmente relevante en periodos como la pandemia, en zonas rurales o en comparaciones entre ciudades con penetración muy distinta. Usar el ratio Waze ayuda parcialmente; también recomendamos controlar por proxies de actividad.

**8.2 Flag de comportamiento anomalo (flag_corr_type)**

------------------------------------------------------------------------

El pipeline marca observaciones potencialmente problematicas con un codigo:

| **Codigo** | **Significado** |
|----|----|
| 0 | Observacion correcta. |
| 1 | osm_roadlength \< 150 m y TCI ratio \> 100% (red muy corta, ratio truncado a -998). |
| 2 | osm_roadlength = 0 (no se puede calcular ratio; valores -999). |
| 3 | TCI ratio \> 100% sobre red \>= 150 m (truncado a 100). |
| 4 | jam_speedkmh \> avg_freeflow (atipico). |
| 5 | Persistencia \> 100% (truncada a 100). |

Para análisis estándar, filtrar por flag_corr_type = 0 evita la mayoría de outliers y celdas con poca red. Las tablas summarized aplican este filtro por defecto.

**8.3 Valores centinela: -998 y -999**

------------------------------------------------------------------------

-999 indica que la longitud de la red de referencia era 0 (no hay vías para normalizar). -998 indica que la red existente es muy corta (\<150 m) y produce un ratio matemáticamente mayor a 100, lo cual no tiene sentido físico. Ambos deben tratarse como missing y removerse antes de cualquier promedio.

**8.4 Buenas practicas para evaluacion de impacto**

------------------------------------------------------------------------

**•** Usar tci_osm_ratio (o severo) como indicador principal de congestion; usar speed_ratio para velocidad.

**•** Preferir agregaciones horarias-mensuales para series temporales con suficiente potencia.

**•** Controlar por roadtype cuando el tratamiento puede afectar diferencialmente vias chicas vs grandes.

**•** Complementar con los indicadores severos cuando interese capturar congestion disruptiva.

**•** Trabajar a nivel de grid H3 si se requiere una unidad espacial homogenea; usar L1-L3/MR para reportes administrativos.

**9. Tabla resumen de variables**

------------------------------------------------------------------------

Listado rápido de las columnas que aparecen en el dataset final (tablas summarized). Las columnas con sufijo \_waze_ratio existen únicamente en las tablas summarized; el dataset base gridwise_tci usa la referencia OSM.

| **Columna** | **Tipo** | **Descripcion** |
|----|----|----|
| datetime_group | timestamp | Inicio de la ventana temporal (hora redondeada). |
| region_slug / region_type | string | Identificador y nivel geografico (L0..L3, MR, grid). |
| grid_id | string (H3) | Identificador H3 resolucion 8. |
| roadtype | categorical | small / medium / large / all_roadtype (y agrupaciones 2-levels). |
| osm_roadlength | metros | Longitud de la red vial en OSM para la celda. |
| avg_freeflow | km/h | Velocidad libre estimada (referencia 1-2 am). |
| jam_speedkmh / avg_jam_speedkmh | km/h | Velocidad observada en jams. |
| jam_speed_ratio | % | jam_speedkmh / avg_freeflow × 100. |
| speed | km/h | Velocidad esperada (ponderacion por tci_osm_ratio). |
| speed_ratio / t_speed_ratio | % | speed / avg_freeflow × 100. |
| tci | metros·obs | Suma de longitudes de jams en la ventana. |
| severe_tci | metros·obs | TCI restringido a jams con velocidad \< 40% del free-flow. |
| tci_osm_ratio / tci_waze_ratio | % | TCI normalizado por red (OSM o Waze). |
| tci_severe_osm_ratio / tci_severe_waze_ratio | % | Idem para severos. |
| tc_spread / tc_severe_spread | metros | Longitud de segmentos con al menos un jam (TCS). |
| tc_spread_osm_ratio / tc_spread_waze_ratio | % | TCS normalizado por red. |
| tc_severe_spread_osm_ratio / tc_severe_spread_waze_ratio | % | TCS severo normalizado. |
| tc_persistance_ratio | % | (TCI / TCS) / N_obs × 100. Duracion media del jam. |
| tc_severe_persistance_ratio | % | Persistencia para jams severos. |
| flag_corr_type | int | Codigo de calidad (0 = correcta). Ver seccion 8.2. |
| hour_of_day | 0-23 | Hora del dia. |
| day_of_week_number | 1-7 | Dia de la semana. |
| month_number / year_number | int | Mes y año del periodo. |

*BID · SPD / SDV · Datos waze*
