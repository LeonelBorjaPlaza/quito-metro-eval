# Independent fresh-session spot audit; reads only cleaned Parquet and vetted geography.
source("Scripts/Congestion/descriptive_helpers.R")
facts <- readRDS(file.path(out,"report_numeric_facts.rds"))
set.seed(20260918)
chosen <- facts[sample(.N,10)]
con <- connect_clean()
geo <- st_drop_geometry(readRDS("Output/Waze/inventory/cell_groups.rds"))[,c("grid_id","group")]
DBI::dbWriteTable(con,"geography",geo)
DBI::dbExecute(con,"CREATE VIEW flags AS SELECT g.grid_id,g.\"group\" grp, count(a.grid_id) ever_n,
  count(a.grid_id) FILTER (WHERE a.date BETWEEN 202201 AND 202311) pre_n
  FROM geography g LEFT JOIN all_roadtype a ON g.grid_id=a.grid_id GROUP BY g.grid_id,g.\"group\"")
DBI::dbExecute(con,"CREATE VIEW eligible AS SELECT *, pre_n/23.0 >=20 saturated FROM flags
  WHERE ever_n>0 AND (grp<>'REST' OR pre_n>0)")
one <- function(sql) as.numeric(DBI::dbGetQuery(con,sql)[[1]])
queries <- c(retained_cells="SELECT count(*) FROM eligible",never_observed="SELECT count(*) FROM flags WHERE ever_n=0",
  observed_no_pre="SELECT count(*) FROM flags WHERE ever_n>0 AND pre_n=0",
  rest_retained="SELECT count(*) FROM eligible WHERE grp='REST'",
  saturated20="SELECT count(*) FROM eligible WHERE grp='REST' AND saturated",
  threshold12="SELECT count(*) FROM eligible WHERE grp='REST' AND pre_n/23.0>=12",
  center_cells="SELECT count(*) FROM eligible WHERE grp='CENTER'",belisario_cells="SELECT count(*) FROM eligible WHERE grp='BELISARIO'",
  corridor_cells="SELECT count(*) FROM eligible WHERE grp='CORRIDOR'",ring_cells="SELECT count(*) FROM eligible WHERE grp='RING'",
  allroad_keys="SELECT count(*) FROM all_roadtype",large_keys="SELECT count(*) FROM large",
  negative_spread_keys="SELECT count(*) FROM all_roadtype WHERE tc_spread_osm_ratio<0 AND tc_spread_osm_ratio NOT IN (-998,-999)",
  gap_negative_keys="SELECT count(*) FROM all_roadtype WHERE tc_spread_osm_ratio<0 AND tc_spread_osm_ratio NOT IN (-998,-999) AND date IN (202502,202503,202504)")
chosen[, regenerated := vapply(metric,function(k) {
  if (k %in% names(queries)) return(one(queries[[k]]))
  parts <- strsplit(k,":",fixed=TRUE)[[1]]
  cond <- if(parts[1]=="REST_saturated") "e.grp='REST' AND e.saturated" else sprintf("e.grp='%s'",parts[1])
  num <- if(parts[3]=="presence") "count(a.grid_id)" else sprintf("sum(CASE WHEN a.%s IN (-998,-999) THEN NULL ELSE a.%s END)",parts[3],parts[3])
  one(sprintf("SELECT %s / (4.0 * (SELECT count(*) FROM eligible e WHERE %s))
    FROM all_roadtype a JOIN eligible e ON a.grid_id=e.grid_id
    WHERE %s AND a.date=%s AND a.hour_of_day IN (7,8,17,18)",num,cond,cond,parts[2]))
},numeric(1))]
chosen[, `:=`(absolute_difference=abs(value-regenerated),match=abs(value-regenerated)<=1e-9*pmax(1,abs(value)))]
saveRDS(chosen,file.path(out,"independent_audit.rds"))
print(chosen)
DBI::dbDisconnect(con,shutdown=TRUE)
stopifnot(all(chosen$match))
