# Offline public input preparation; no crash outcomes read here.
source("code/amend2_helpers.R")
osm_dir<-"data/raw/2026-10-05_osm_ecuador_geofabrik"
census_dir<-"data/raw/2026-10-05_census2022_parroquias"
old<-file.path(osm_dir,"ecuador-220101.osm.pbf")
current<-file.path(osm_dir,"ecuador-latest.osm.pbf")
check_sha_a2(old,"ebd20f7063490591e4155004305a40bc02888d8fa7a7ff5f5474a20bbff9d535")
check_sha_a2(current,"dd36b220e3051f29f2af1547ffb6df58defbfd4bbf0c085e2e18cf4da48925ef")
cp<-file.path(census_dir,"poblacion_parroquias_todas_dmq_censo2022.csv")
check_sha_a2(cp,"612e2a174b0d4ef64fcc8833d5a06627dd0e601dba68cfa970d1c4569b04536b")
par<-st_transform(st_read(paste0("/vsizip/",normalizePath(PARISH_ZIP)),quiet=TRUE),CRS_UTM)
stations<-st_transform(st_zm(st_read(STATIONS_GPKG,quiet=TRUE)),CRS_UTM)
box<-st_as_text(st_as_sfc(st_bbox(st_transform(par,4326))))
ent<-st_read(current,query="SELECT * FROM points WHERE other_tags LIKE '%\"railway\"=>\"subway_entrance\"%'",wkt_filter=box,quiet=TRUE)
ent<-st_transform(ent,CRS_UTM)
dm<-units::drop_units(as.matrix(st_distance(ent,stations)));near<-max.col(-dm,ties.method="first")
ent$station<-stations$Name[near];ent$distance_m<-dm[cbind(seq_len(nrow(ent)),near)]
ent$second_station_m<-apply(dm,1,function(v)sort(v)[2])
# Association uses geometry; names are retained for a station-by-station audit.
stopifnot(all(ent$distance_m<500),all(ent$second_station_m-ent$distance_m>300),!anyDuplicated(ent$osm_id))
ent$source<-"mapped subway entrance; current Geofabrik extract"
use<-ent[,c("osm_id","station","distance_m","second_station_m","source")]
missing<-setdiff(stations$Name,ent$station)
for(nm in missing) {
  f<-st_sf(osm_id=NA_character_,station=nm,distance_m=0,second_station_m=NA_real_,
    source="station point fallback; no mapped subway entrance",geometry=st_geometry(stations[stations$Name==nm,]))
  names(f)[names(f)==attr(f,"sf_column")]<-attr(use,"sf_column")
  st_geometry(f)<-attr(use,"sf_column")
  use<-rbind(use,f)
}
ea<-as.data.table(st_drop_geometry(ent))[,.(station,osm_id,name,distance_m=round(distance_m,1),
  second_station_m=round(second_station_m,1),source)]
save_csv(ea,file.path(A2_OUT,"entrance_associations.csv"))
sa<-data.table(station=stations$Name)
sa<-merge(sa,ea[,.(mapped_entrances=.N,max_association_distance_m=max(distance_m)),by=station],all.x=TRUE,by="station")
sa[is.na(mapped_entrances),mapped_entrances:=0L]
sa[,geometry_used:=ifelse(mapped_entrances>0,"current mapped entrances","station point fallback; no mapped entrance")]
save_csv(sa,file.path(A2_OUT,"station_geometry.csv"))
allroads<-st_transform(st_read(old,query="SELECT * FROM lines WHERE highway IS NOT NULL",wkt_filter=box,quiet=TRUE),CRS_UTM)
classes<-c("motorway","motorway_link","trunk","trunk_link","primary","primary_link","secondary","secondary_link",
 "tertiary","tertiary_link","unclassified","residential","living_street","service","road","track")
save_csv(as.data.table(st_drop_geometry(allroads))[,.(ways=.N,included=highway[1]%in%classes),by=highway],file.path(A2_OUT,"road_class_inventory.csv"))
roads<-allroads[allroads$highway %in% classes,]
roads<-roads[lengths(st_intersects(roads,st_union(par)))>0,]
# Split OSM ways at shared vertices, not geometric crossings on bridges/tunnels.
xy<-st_coordinates(roads)
vertices<-data.table(way=xy[,"L1"],x=xy[,"X"],y=xy[,"Y"])
vertices[,key:=paste(sprintf("%.5f",x),sprintf("%.5f",y))]
junction<-vertices[,.(ways=uniqueN(way)),by=key][ways>1,key]
parts<-list();owner<-integer();ids<-character();counter<-0L
for(i in seq_len(nrow(roads))) {
  v<-vertices[way==i];cut<-sort(unique(c(1L,which(v$key %in% junction),nrow(v))))
  if(length(cut)<2)next
  for(j in seq_len(length(cut)-1L)) {
    coords<-as.matrix(v[cut[j]:cut[j+1],.(x,y)])
    if(nrow(unique(coords))<2)next
    counter<-counter+1L;parts[[counter]]<-st_linestring(coords);owner[counter]<-i
    ids[counter]<-paste0("way_",roads$osm_id[i],"_seg_",j)
  }
}
segments<-st_sf(st_drop_geometry(roads)[owner,],geometry=st_sfc(parts,crs=CRS_UTM))
segments$road_id<-ids;stopifnot(!anyDuplicated(ids))
pop<-fread(cp);pop[,code:=as.integer(dpa_parroq)]
stopifnot(!anyDuplicated(pop$code),setequal(pop$code,as.integer(par$dpa_parroq)))
saveRDS(list(entrances=use,stations=stations,roads=segments,population=pop),file.path(A2_DATA,"geography.rds"))
save_csv(data.table(input=c("2022 roads","current entrances","census"),sha256=c(
 "ebd20f7063490591e4155004305a40bc02888d8fa7a7ff5f5474a20bbff9d535",
 "dd36b220e3051f29f2af1547ffb6df58defbfd4bbf0c085e2e18cf4da48925ef",
 "612e2a174b0d4ef64fcc8833d5a06627dd0e601dba68cfa970d1c4569b04536b")),file.path(A2_OUT,"new_input_checksums.csv"))
cat("Offline geography prepared.\n")
