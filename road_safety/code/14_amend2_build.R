# Amendment 2 build, pre-period only. Run 13_amend2_extract.py first.
# Raw records and exact panels stay in ignored data/derived/amendment2/.
# No original 01/02 build is sourced: those scripts load all dates.
source("code/amend2_helpers.R")
source("code/amend2_calendar.R")
s <- fread(file.path(A2_DATA, "crashes_pre.csv"), colClasses = "character", na.strings = "")
v <- fread(file.path(A2_DATA, "vehicles_pre.csv"), colClasses = "character", na.strings = "")
num <- function(x) suppressWarnings(as.numeric(x))
fecha <- as.Date(num(s$FECHA), origin = "1899-12-30")
minute <- as.integer(round((num(s$HORA) %% 1) * 1440)) %% 1440L
severity <- c("DAÑOS MATERIALES" = "damage", "LESIONADOS" = "injury_fatal", "FALLECIDOS" = "injury_fatal")[s$SEVERIDAD]
group <- c(CHOQUES="vehicle_vehicle",COLISION="vehicle_vehicle",ROCE="vehicle_vehicle",
           ATROPELLO="pedestrian",ESTRELLAMIENTO="single_vehicle",`PERDIDA DE CARRIL`="single_vehicle",
           VOLCAMIENTO="single_vehicle",ATIPICO="other",`CAIDA DE PASAJERO`="other")[s$`TIPOLOGÍA`]
stopifnot(!anyNA(severity), !anyNA(group), !anyDuplicated(s$SINIESTRO))
d <- data.table(crash_id=s$SINIESTRO, fecha=fecha, month=month_start(fecha),
  minute=minute, hour=minute %/% 60L, weekday=as.integer(format(fecha,"%u")),
  lon=num(s$LONGITUD),lat=num(s$LATITUD),severity=unname(severity),group=unname(group),
  tipologia=s$`TIPOLOGÍA`, principal=norm_a2(s$PRINCIPAL), secundaria=norm_a2(s$SECUNDARIA),
  sicariato=!is.na(s$FALLECIDOS) & grepl("SICARIATO",s$FALLECIDOS,fixed=TRUE))
assert_pre(d)
d <- d[sicariato == FALSE]
v[, `:=`(private=norm_a2(`TIPO DE VEHÍCULO`) %in% c("AUTOMOVIL","CAMIONETA") &
           norm_a2(`TIPO DE SERVICIO`) %in% "PARTICULAR",
         unknown=norm_a2(`TIPO DE VEHÍCULO`) %in% "NO IDENTIFICADO",
         motorcycle=norm_a2(`TIPO DE VEHÍCULO`) %in% "MOTOCICLETA",
         bus=norm_a2(`TIPO DE VEHÍCULO`) %in% "BUS")]
vv <- v[,.(n_vehicle=.N,n_private=sum(private),n_unknown=sum(unknown),
           motorcycle=any(motorcycle),bus=any(bus)),by=.(crash_id=SINIESTRO)]
d <- merge(d,vv,by="crash_id",all.x=TRUE,sort=FALSE)
stopifnot(!anyNA(d$n_vehicle),all(d$n_private <= d$n_vehicle))
d[, `:=`(private=n_private>0, pedestrian=group=="pedestrian",fall=tipologia=="CAIDA DE PASAJERO",
          weekend=weekday>=6,metro_hours=minute>=330 & minute<1380,
          peak=(minute>=360 & minute<540)|(minute>=1020 & minute<1200))]

check_sha_a2(PARISH_ZIP,PARISH_SHA256); check_sha_a2(ROADS_OSM,ROADS_SHA256)
check_sha_a2(CENTRO_GEOJSON,CENTRO_SHA256)
stations <- st_transform(st_zm(st_read(STATIONS_GPKG,quiet=TRUE)),CRS_UTM)
line <- st_union(st_transform(st_zm(st_read(LINE_GPKG,quiet=TRUE)),CRS_UTM))
par <- st_transform(st_read(paste0("/vsizip/",normalizePath(PARISH_ZIP)),quiet=TRUE),CRS_UTM)
par$code <- as.integer(par$dpa_parroq)
par$distant <- as.numeric(st_distance(par,line))>2000
stopifnot(sum(par$distant)==39L,all(st_is_valid(par)))
centro <- st_transform(st_read(CENTRO_GEOJSON,quiet=TRUE),CRS_UTM)
geo <- readRDS(file.path(A2_DATA,"geography.rds"))
entrances <- geo$entrances
roads <- geo$roads
legacy_roads <- st_transform(st_read(ROADS_OSM,layer="lines",quiet=TRUE),CRS_UTM)
legacy_roads$nm <- norm_a2(legacy_roads$name)
roads$nm <- norm_a2(roads$name)
stopifnot(!anyDuplicated(roads$road_id))
pts <- st_transform(st_as_sf(d[,.(lon,lat)],coords=c("lon","lat"),crs=4326),CRS_UTM)
old_near <- st_nearest_feature(pts,stations)
old_dist <- as.numeric(st_distance(pts,stations[old_near,],by_element=TRUE))
near <- st_nearest_feature(pts,entrances)
dist <- as.numeric(st_distance(pts,entrances[near,],by_element=TRUE))
old_ring <- cut(old_dist,c(0,300,600,1000,2000,Inf),right=FALSE,labels=c(A2_RINGS,"beyond_2000"))
hits <- st_intersects(pts,par)
h <- vapply(hits,function(k) if(length(k)) k[which.min(par$code[k])] else NA_integer_,0L)
d[, `:=`(station=entrances$station[near],dist_station=dist,parish=par$code[h],
          ring=as.character(cut(dist,c(0,300,600,1000,2000,Inf),right=FALSE,
                         labels=c(A2_RINGS,"beyond_2000"))),
          historic_center=lengths(st_intersects(pts,centro))>0)]
changes<-rbindlist(lapply(c(2021L,2022L),function(st) {
 keep<-!is.na(d$parish)&d$fecha>=as.Date(paste0(st,"-01-01"))
 data.table(start=st,changed_ring=sum(as.character(old_ring[keep])!=d$ring[keep]),unchanged_ring=sum(as.character(old_ring[keep])==d$ring[keep]))
}))
release_counts(changes,c("changed_ring","unchanged_ring"),"entrance_ring_changes.csv")
FAST <- "SIMON BOLIVAR|INTEROCEANICA|RUTA VIVA|PANAMERICANA|AUTOPISTA GENERAL RUMINAHUI|CORDOVA GALARZA|^E ?35$|INTERVALLES"
isfast <- function(x) !is.na(x)&grepl(FAST,x)&!grepl("^PASAJE",x)
rf <- ifelse(grepl('"ref"=>"',roads$other_tags),sub('.*"ref"=>"([^"]*)".*',"\\1",roads$other_tags),NA_character_)
fw <- isfast(roads$nm)|(!is.na(roads$nm)&grepl("^(AV|AVENIDA) OSWALDO GUAYASAMIN",roads$nm))|
      (!is.na(rf)&grepl("(^|;)\\s*E ?-?35\\s*($|;)",rf))
mw <- roads$nm %in% c("MARISCAL SUCRE","AVENIDA MARISCAL SUCRE")
d[, fast := (isfast(principal)|isfast(secundaria)) & as.numeric(st_distance(pts,st_union(roads[fw,])))<=1000 |
       (principal %in% "MARISCAL SUCRE"|secundaria %in% "MARISCAL SUCRE") & as.numeric(st_distance(pts,st_union(roads[mw,])))<=1000]
d[, road_type := fifelse(fast,"fast","city")]

# Road assignment: nearest available way, within 30 m; 15/50 m diagnostics below.
# Full motor-vehicle network, with ways split at shared vertices; grade-separated crossings are not noded.
rn <- st_nearest_feature(pts,roads)
rd <- as.numeric(st_distance(pts,roads[rn,],by_element=TRUE))
clean_st <- function(x) trimws(gsub("^(AVENIDA|AV|CALLE|AUTOPISTA) +","",x))
match_st <- function(a,b) !is.na(a)&!is.na(b)&nzchar(a)&nzchar(b)&(a==b)
gn <- clean_st(roads$nm[rn])
agree <- match_st(clean_st(d$principal),gn)|match_st(clean_st(d$secundaria),gn)
# Public geometry selection, fixed independently of crash counts: named primary/secondary
# roads intersecting 1 km line buffer, >=500 m clipped length and net N-S span >= E-W span.
clip <- suppressWarnings(st_intersection(roads[roads$highway %in% c("primary","secondary") & !is.na(roads$nm),],st_buffer(line,1000)))
ns <- lapply(split(seq_len(nrow(clip)),clip$nm),function(ix) {
  g <- st_union(clip[ix,]); bb<-st_bbox(g)
  data.table(name=clip$nm[ix[1]],length_m=as.numeric(st_length(g)),north_south=bb[4]-bb[2],east_west=bb[3]-bb[1])
})
arterial_names <- rbindlist(ns)[length_m>=500 & north_south>=east_west,name]
roads$arterial <- roads$nm %in% arterial_names & lengths(st_intersects(roads,st_buffer(line,1000)))>0
roads$station_road <- lengths(st_intersects(roads,st_union(st_buffer(entrances,300))))>0
d[, `:=`(road_id=roads$road_id[rn],road_dist=rd,road_agrees=agree,
          arterial=rd<=30 & roads$arterial[rn] & as.numeric(st_distance(pts,line))<=1000,
          station_road=rd<=30 & roads$station_road[rn] & dist_station<300)]
save_csv(rbindlist(ns)[name %in% arterial_names,.(name,length_m=round(length_m,1),
  north_south_m=round(north_south,1),east_west_m=round(east_west,1),source="OSM 2022-01-01; © OpenStreetMap contributors")],
  file.path(A2_OUT,"arterial_names.csv"))

rg <- rbindlist(lapply(c(15,30,50),function(tol) rbindlist(lapply(c("all_available_roads","arterials","station_roads_300"),function(fam) {
  sel<-switch(fam,all_available_roads=rep(TRUE,nrow(d)),arterials=roads$arterial[rn] & as.numeric(st_distance(pts,line))<=1000,
              station_roads_300=roads$station_road[rn] & d$dist_station<300)
  d[road_dist<=tol & sel,.(family=fam,tolerance_m=tol,agreement_pct=release_share(sum(road_agrees),.N),matched_crashes=.N)]
}))))
release_counts(rg,"matched_crashes","road_name_agreement.csv")

# Reproduce the congestion module's approved approximate pico polygon, geometry only.
B <- legacy_roads[grepl("MORAN VALVERDE|NARCISOS|CORDOVA GALARZA|SIMON BOLIVAR|MARISCAL SUCRE",legacy_roads$nm),]
mv <- st_union(st_geometry(B[grepl("MORAN VALVERDE",B$nm),]))
sb <- st_union(st_geometry(B[grepl("SIMON BOLIVAR",B$nm),]))
xy <- st_coordinates(mv); east <- st_sfc(st_point(xy[which.max(xy[,"X"]),c("X","Y")]),crs=CRS_UTM)
C <- st_nearest_points(east,sb)
all_lines <- st_union(c(st_geometry(B),C))
refs <- st_transform(st_sfc(st_point(c(-78.4855,-0.1810)),st_point(c(-78.51209,-0.22012)),crs=4326),CRS_UTM)
zone <- NULL
for (buf in c(25,50,100,150,250)) {
  holes <- lapply(st_cast(st_union(st_buffer(all_lines,buf)),"POLYGON"),function(p)
    if(length(p)>1) lapply(p[-1],function(r) st_polygon(list(r))) else list())
  holes <- st_sfc(unlist(holes,recursive=FALSE),crs=CRS_UTM)
  hit <- if(length(holes)) which(rowSums(st_contains(holes,refs,sparse=FALSE))==2) else integer()
  if(length(hit)==1) { zone<-st_buffer(holes[hit],buf);break }
}
stopifnot(!is.null(zone))
d[, pico := lengths(st_intersects(pts,zone))>0]
saveRDS(zone,file.path(A2_DATA,"pico_zone.rds"))
save_csv(data.table(buffer_m=buf,assumed_closure_m=round(as.numeric(st_length(C)),1),
  source="congestion/Scripts/Congestion/44_redesign_zone.R; reconstructed, approximate boundary"),file.path(A2_OUT,"pico_geometry.csv"))

# Unit memberships: disjoint ring/donor partition, plus explicitly overlapping secondary families.
members <- list()
add <- function(unit,sel,family) {
  members[[length(members)+1L]] <<- data.table(unit=unit,idx=which(sel & !is.na(d$parish)),family=family)
}
for(r in A2_RINGS) add(r,d$ring==r,"rings")
add("corridor_0_600",d$dist_station<600,"corridor")
add("historic_center",d$historic_center,"center")
add("arterials",d$arterial,"roads")
add("station_roads_300",d$station_road,"roads")
add("spillover",d$dist_station>=2000 & !d$parish %in% par$code[par$distant],"spillover")
for(pc in par$code[par$distant]) add(paste0("parish_",pc),d$parish %in% pc,"donor")
for(st in stations$Name) add(paste0("station_",st),d$station==st & d$dist_station<600,"station_profile")
for(nm in arterial_names) add(paste0("arterial_",nm),d$arterial & roads$nm[rn] %in% nm,"arterial_profile")
for(id in roads$road_id[roads$station_road]) add(id,d$station_road & d$road_id==id,"segment_profile")
mem <- rbindlist(members)
units <- unique(rbindlist(lapply(members,function(x) x[,.(unit=unique(unit),family=unique(family))])))
# Preserve units with no crashes: construct their registry independently of memberships.
units <- unique(rbind(units,data.table(unit=paste0("parish_",par$code[par$distant]),family="donor"),
  data.table(unit=A2_TARGETS,family=c(rep("rings",4),"corridor","center","roads","roads","spillover")),
  data.table(unit=paste0("station_",stations$Name),family="station_profile"),
  data.table(unit=paste0("arterial_",arterial_names),family="arterial_profile"),
  data.table(unit=roads$road_id[roads$station_road],family="segment_profile")))
stopifnot(uniqueN(units[family=="donor",unit])==39L,!anyDuplicated(mem[,.(unit,idx)]))
x <- cbind(mem,d[mem$idx])
x[, cell := paste(group,severity,road_type,sep="__")]
cells <- CJ(group=c("vehicle_vehicle","pedestrian","single_vehicle","other"),
            severity=c("injury_fatal","damage"),road_type=c("city","fast"))[,paste(group,severity,road_type,sep="__")]
p <- CJ(unit=units$unit,cell=cells,month=A2_MONTHS)
p <- merge(p,x[,.(y=.N),by=.(unit,cell,month)],all.x=TRUE,by=c("unit","cell","month"))
p[is.na(y),y:=0L]
stopifnot(sum(p[unit %in% A2_RINGS,y])==sum(!is.na(d$parish)&d$dist_station<2000))
outcomes <- c("all_crashes","injury_fatal","private_car_crashes","private_vehicles","all_vehicles","unidentified_vehicles","pedestrian","passenger_falls","motorcycle","bus")
ys <- x[,.(all_crashes=.N,injury_fatal=sum(severity=="injury_fatal"),private_car_crashes=sum(private),
  private_vehicles=sum(n_private),all_vehicles=sum(n_vehicle),unidentified_vehicles=sum(n_unknown),
  pedestrian=sum(pedestrian),passenger_falls=sum(fall),motorcycle=sum(motorcycle),bus=sum(bus)),by=.(unit,month)]
y <- merge(CJ(unit=units$unit,month=A2_MONTHS),ys,all.x=TRUE,by=c("unit","month"))
setnafill(y,fill=0L,cols=outcomes)
hr_obs <- x[!is.na(hour),.(private_car_crashes=sum(private),all_crashes=.N),by=.(unit,month,weekday_type=fifelse(weekend,"weekend","weekday"),hour)]
hr <- merge(CJ(unit=units$unit,month=A2_MONTHS,weekday_type=c("weekday","weekend"),hour=0:23),hr_obs,
            by=c("unit","month","weekday_type","hour"),all.x=TRUE)
setnafill(hr,fill=0L,cols=c("private_car_crashes","all_crashes"))
saveRDS(list(crashes=d,members=mem,units=units,stack=p,outcomes=y,hour=hr,roads=roads,parishes=par,stations=stations),file.path(A2_DATA,"build.rds"))
save_csv(units,file.path(A2_OUT,"units.csv"))

# Release only broad-period rounded totals divided by period length, not exact monthly cells.
means <- rbindlist(lapply(c(2021,2022),function(start) {
  z<-y[month>=as.Date(paste0(start,"-01-01")),lapply(.SD,sum),by=unit,.SDcols=outcomes]
  nmonth<-sum(A2_MONTHS>=as.Date(paste0(start,"-01-01")))
  # Suppress a subset statistic when its unreported complement is small too.
  crash_subsets<-c("injury_fatal","private_car_crashes","pedestrian","passenger_falls","motorcycle","bus")
  for(nm in crash_subsets) z[small_a2(all_crashes-get(nm)),(nm):=NA_real_]
  for(nm in c("private_vehicles","unidentified_vehicles")) z[small_a2(all_vehicles-get(nm)),(nm):=NA_real_]
  z<-melt(z,id.vars="unit",variable.name="outcome",value.name="total")
  z[small_a2(total),total:=NA_real_]
  # Broad-period nested ring margins obey the same complementary release rule.
  z[, family_sparse:=any(is.na(total[unit %in% c(A2_RINGS,"corridor_0_600")])),by=outcome]
  z[unit %in% c(A2_RINGS,"corridor_0_600") & family_sparse,total:=NA_real_]
  z[,.(unit,outcome,start,months=nmonth,monthly_mean=ifelse(small_a2(total),NA_real_,round(round5(total)/nmonth,1)),
       disclosure="mean from total rounded to 5; small total/complement and nested ring margins withheld")]
}))
save_csv(means,file.path(A2_OUT,"preperiod_monthly_means.csv"))
comp <- x[,.(unknown=sum(n_unknown),private=sum(n_private),vehicles=sum(n_vehicle)),by=.(unit,year=as.integer(format(fecha,"%Y")))]
comp[, `:=`(unidentified_share_pct=release_share(unknown,vehicles),private_share_pct=release_share(private,vehicles))]
save_csv(comp[,.(unit,year,unidentified_share_pct,private_share_pct,
  disclosure="5 percentage point grid from rounded counts; small numerator/complement withheld")],file.path(A2_OUT,"vehicle_shares.csv"))

# Rain: observed monthly accumulation is distinct from a complete monthly total.
rr <- fread(file.path(A2_DATA,"rain_pre.csv"))
setnames(rr,names(rr)[1],"serial")
rr[, datetime:=as.POSIXct(round(num(serial)*24)*3600,origin="1899-12-30",tz="UTC")]
rr[, `:=`(fecha=as.Date(datetime),hour=as.integer(format(datetime,"%H")),month=month_start(as.Date(datetime)))]
assert_pre(rr)
stopifnot(!anyDuplicated(rr$datetime))
stcols<-setdiff(names(rr),c("serial","datetime","fecha","hour","month","ElCamal"))
rl<-melt(rr,id.vars=c("datetime","fecha","hour","month"),measure.vars=stcols,variable.name="station",value.name="rain")
rl[, rain:=num(rain)];stopifnot(!any(rl$rain<0,na.rm=TRUE))
rdays<-rl[,.(rain_day=if(all(!is.na(rain)) & .N==24L) as.integer(sum(rain)>0) else NA_integer_),by=.(station,month,fecha)]
rm<-rl[,.(observed_mm=sum(rain,na.rm=TRUE),observed_hours=sum(!is.na(rain)),
          metro_observed_mm=sum(rain[hour>=6 & hour<23],na.rm=TRUE),metro_observed_hours=sum(!is.na(rain[hour>=6 & hour<23]))),by=.(station,month)]
cal<-data.table(fecha=seq(as.Date("2021-01-01"),as.Date("2023-11-30"),by="day"))
cal[, `:=`(month=month_start(fecha),weekend=as.integer(format(fecha,"%u"))>=6)]
cal[,holiday:=fecha %in% A2_HOLIDAYS]
cm<-cal[,.(days=.N,weekend_days=sum(weekend),holiday_days=sum(holiday)),by=month]
rm<-merge(rm,cm,by="month")
rm<-merge(rm,rdays[,.(complete_days=sum(!is.na(rain_day)),observed_rain_days=sum(rain_day,na.rm=TRUE)),by=.(station,month)],by=c("station","month"))
rm[, `:=`(coverage=observed_hours/(24*days),total_mm=ifelse(observed_hours==24*days,observed_mm,NA_real_),
  rain_days=ifelse(complete_days==days,observed_rain_days,NA_real_),
  metro_total_mm=ifelse(metro_observed_hours==17*days,metro_observed_mm,NA_real_))]
mon<-st_transform(st_read("../air_quality/data/for_maps/Distancia_REMMAQ_Metro.gpkg",quiet=TRUE),CRS_UTM)
mon$rain_name<-norm_a2(mon$Station);mon$rain_name[mon$rain_name=="SAN ANTONIO DE PICHINCHA"]<-"SAN ANTONIO"
rain_names<-norm_a2(stcols);mon<-mon[mon$rain_name %in% rain_names,]
stnames<-setNames(stcols,rain_names)
# Every registry unit gets a geometric representative, including zero-crash units.
# Ring geometry is the union of station buffers, differenced into nonoverlapping bands.
circle<-function(r) st_union(st_buffer(entrances,r))
ug<-list(ring_0_300=circle(300),ring_300_600=st_difference(circle(600),circle(300)),
  ring_600_1000=st_difference(circle(1000),circle(600)),ring_1000_2000=st_difference(circle(2000),circle(1000)),
  corridor_0_600=circle(600),historic_center=st_union(centro),
  arterials=st_intersection(st_buffer(st_union(roads[roads$arterial,]),30),st_buffer(line,1000)),
  station_roads_300=st_intersection(st_buffer(st_union(roads[roads$station_road,]),30),circle(300)),
  spillover=st_difference(st_union(par[!par$distant,]),circle(2000)))
for(pc in par$code[par$distant]) ug[[paste0("parish_",pc)]]<-st_geometry(par[par$code==pc,])
# Nearest-entrance Voronoi cells preserve station-profile membership footprints.
vor<-st_collection_extract(st_voronoi(st_union(st_geometry(entrances))))
vowner<-st_nearest_feature(suppressWarnings(st_centroid(vor)),entrances)
for(st in stations$Name) ug[[paste0("station_",st)]]<-st_intersection(st_union(vor[entrances$station[vowner]==st]),circle(600))
for(nm in arterial_names) ug[[paste0("arterial_",nm)]]<-st_intersection(st_buffer(st_union(roads[roads$arterial & roads$nm %in% nm,]),30),st_buffer(line,1000))
for(id in roads$road_id[roads$station_road]) ug[[id]]<-st_intersection(st_buffer(st_geometry(roads[roads$road_id==id,]),30),circle(300))
stopifnot(setequal(names(ug),units$unit))
rep_points<-do.call(c,lapply(ug,function(g) suppressWarnings(st_centroid(st_union(g)))))
ctr<-data.table(unit=names(ug))
cp<-st_sf(unit=names(ug),geometry=rep_points)
ctr[,rain_station:=unname(stnames[mon$rain_name[st_nearest_feature(cp,mon)]])]
exposure<-x[month>=as.Date("2022-01-01"),.(weekend_share=mean(weekend)),by=unit]
geoexp<-data.table(unit=names(ug),pico_share=vapply(ug,function(g) {
  dim<-st_dimension(g)[1]
  if(dim==0) return(as.numeric(lengths(st_intersects(g,zone))>0))
  measure<-if(dim==2) st_area else st_length
  as.numeric(sum(measure(suppressWarnings(st_intersection(g,zone))))/sum(measure(g)))
},0))
exposure<-merge(geoexp,exposure,by="unit",all.x=TRUE)
saveRDS(ug,file.path(A2_DATA,"unit_geometry.rds"))
controls<-merge(CJ(unit=units$unit,month=A2_MONTHS),ctr[,.(unit,rain_station)],by="unit",all.x=TRUE)
controls<-merge(controls,rm,by.x=c("rain_station","month"),by.y=c("station","month"),all.x=TRUE)
controls<-merge(controls,exposure,by="unit",all.x=TRUE)
controls[,pico_step:=pico_share * fifelse(month<as.Date("2023-04-01"),0,fifelse(month==as.Date("2023-04-01"),21/30,1))]
saveRDS(list(rain=rm,calendar=cm,controls=controls),file.path(A2_DATA,"controls.rds"))
save_csv(rm,file.path(A2_OUT,"rain_coverage.csv")) # meteorology is non-confidential
save_csv(ctr[,.(unit,rain_station)],file.path(A2_OUT,"rain_assignment.csv"))
save_csv(data.table(input=c("entrances","complete local streets","population density 2022","holiday calendar","enforcement road dates","Metro works dates"),
  status=c("current mapped entrances with audited station fallbacks","full 2022 motor-vehicle street segments","2022 parish totals; non-parish area allocation approximation","pre-period dates coded; full post calendar requires verification","missing device/road log","missing site opening/reinstatement log")),file.path(A2_OUT,"data_gaps.csv"))
writeLines(c(trimws(capture.output(sessionInfo()), which="right"),"Allowed outcomes: 2021-01-01 through 2023-11-30 only"),file.path(A2_OUT,"build_session.txt"))
cat("Amendment 2 pre-period build complete. Exact counts remain local and ignored.\n")
