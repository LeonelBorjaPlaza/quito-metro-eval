# Amendment 4 comparison-unit revision: GEOGRAPHY ONLY.
# Frozen rule: docs/amendment4_grid_selection_rule.md. No crash data are read.
source('code/helpers.R');setDTthreads(1)
O<-'output/amendment4_grid';D<-'data/derived/amendment4_grid'
dir.create(O,recursive=TRUE,showWarnings=FALSE);dir.create(D,recursive=TRUE,showWarnings=FALSE)
started<-Sys.time();g<-readRDS('data/derived/amendment2/geography.rds')
r<-g$roads;stations<-g$stations[order(g$stations$Name),]
par<-st_transform(st_read(paste0('/vsizip/',normalizePath(PARISH_ZIP)),quiet=TRUE),CRS_UTM)
par$code<-as.integer(par$dpa_parroq);dmq<-st_union(par)
brt<-st_transform(st_read('data/derived/amendment4/brt_2022.geojson',quiet=TRUE),CRS_UTM);core<-st_union(brt)
# The exact fast-road definition is fixed in the rule document, not selected by
# inspecting retained disc counts or any crash outcome.
norm<-function(x){z<-toupper(iconv(x,to='ASCII//TRANSLIT'));gsub(' +',' ',trimws(gsub('[^A-Z0-9 ]',' ',z)))}
nm<-norm(r$name);ref<-ifelse(!is.na(r$other_tags)&grepl('"ref"=>"',r$other_tags),sub('.*"ref"=>"([^\"]*)".*','\\1',r$other_tags),NA_character_)
pattern<-'SIMON BOLIVAR|INTEROCEANICA|OSWALDO GUAYASAMIN|RUTA VIVA|PANAMERICANA|GENERAL RUMINAHUI|CORDOVA GALARZA|INTERVALLES|(^| )E ?35($| )'
canonical<-sub('^(AVENIDA|AV|AUTOPISTA) +','',nm)
named<-(!is.na(nm)&grepl(pattern,nm)&!grepl('^PASAJE',nm)) | (!is.na(canonical)&canonical=='MARISCAL SUCRE') | (!is.na(ref)&grepl('(^|;)\\s*E ?-?35\\s*($|;)',ref))
r$fast4<-r$highway%in%c('motorway','motorway_link','trunk','trunk_link') | (r$highway%in%c('primary','primary_link','secondary','secondary_link')&named)
r$urban4<-!r$fast4 & r$highway!='track'
stopifnot(!anyNA(r$fast4),!anyNA(r$urban4),nrow(stations)==15)
fwrite(as.data.table(st_drop_geometry(r))[,.(road_id,osm_id,name,highway,fast=fast4,urban_street=urban4)],file.path(D,'road_classification.csv'))
road_summary<-as.data.table(st_drop_geometry(r));road_summary[,length_km:=as.numeric(st_length(r))/1000]
fwrite(road_summary[,.(segments=.N,length_km=sum(length_km)),by=.(highway,fast=fast4,urban_street=urban4)],file.path(O,'road_class_summary.csv'))
# Identical nearest-station 500m footprints to the approved part of Amendment4.
vor<-st_collection_extract(st_voronoi(st_union(stations),envelope=st_as_sfc(st_bbox(st_buffer(stations,2000)))),'POLYGON')
vj<-vapply(st_intersects(stations,vor),function(i)i[1],1L)
sg<-st_sfc(lapply(seq_len(nrow(stations)),function(i)st_intersection(st_geometry(st_buffer(stations[i,],500)),vor[vj[i]])[[1]]),crs=CRS_UTM)
road_metrics<-function(geom,ids){
 hits<-st_intersects(geom,r);area<-as.numeric(st_area(geom))
 vals<-rbindlist(lapply(seq_along(geom),function(i){
  if(!length(hits[[i]]))return(data.table(total=0,urban=0,fast=0,major=0))
  sub<-r[hits[[i]],];q<-suppressWarnings(st_intersection(sub,geom[i]));len<-as.numeric(st_length(q))
  data.table(total=sum(len),urban=sum(len[q$urban4]),fast=sum(len[q$fast4]),major=sum(len[q$highway%in%c('motorway','trunk','primary','secondary')]))
 }))
 data.table(unit=ids,area_km2=area/1e6,total_road_km=vals$total/1000,urban_street_km=vals$urban/1000,fast_road_km=vals$fast/1000,
 road_km_per_km2=vals$total/area*1000,urban_street_km_per_km2=vals$urban/area*1000,
 fast_share=ifelse(vals$total>0,vals$fast/vals$total,NA_real_),major_road_share=ifelse(vals$total>0,vals$major/vals$total,NA_real_))
}
sf_metrics<-road_metrics(sg,paste0('near_',stations$Name));floor_density<-min(sf_metrics$urban_street_km_per_km2)
stopifnot(is.finite(floor_density),floor_density>0)
# Written BEFORE any grid candidate's road-density result is computed.
rule<-list(rule_document='docs/amendment4_grid_selection_rule.md',crs=CRS_UTM,grid_origin_m=c(0,0),spacing_m=1000,disc_radius_m=500,
 urban_density_floor_exact=floor_density,station_defining_floor=sf_metrics[urban_street_km_per_km2==floor_density,unit],max_fast_share=.25,
 urban_density_inclusive=TRUE,fast_share_inclusive=TRUE,geometry_only=TRUE,alternative_grids_attempted=FALSE,
 exclusions='whole disc inside DMQ; centre >1500m from every station and >1000m from 2022 Trolebus/Ecovia trunk',
 fast_definition='motorway/trunk and links OR primary/secondary and links on fixed named list/E35 ref; urban excludes fast and tracks; denominator all motor roads')
jsonlite::write_json(rule,file.path(O,'selection_rule.json'),auto_unbox=TRUE,pretty=TRUE,digits=16)
cat('Exact station-derived rule saved before grid screening.\n')
bb<-st_bbox(dmq);xy<-CJ(easting=seq(ceiling(bb[1]/1000)*1000,floor(bb[3]/1000)*1000,by=1000),northing=seq(ceiling(bb[2]/1000)*1000,floor(bb[4]/1000)*1000,by=1000))
xy[,id:=sprintf('grid_E%d_N%d',easting,northing)]
c<-st_as_sf(xy,coords=c('easting','northing'),crs=CRS_UTM,remove=FALSE);discs<-st_buffer(c,500)
# Exact distance to boundary also guards the polygon-buffer approximation.
in_dmq<-lengths(st_covered_by(c,dmq))>0
c$inside_dmq<-in_dmq & as.numeric(st_distance(c,st_boundary(dmq)))>=500
c$clear_metro<-apply(as.matrix(st_distance(c,stations)),1,min)>1500
c$clear_brt<-as.numeric(st_distance(c,core))>1000
c$geographic_eligible<-c$inside_dmq & c$clear_metro & c$clear_brt
eligible<-which(c$geographic_eligible);cg<-st_geometry(discs)[eligible]
metrics<-road_metrics(cg,c$id[eligible])
metrics[,density_pass:=urban_street_km_per_km2>=floor_density]
metrics[,fast_share_pass:=!is.na(fast_share)&fast_share<=.25]
metrics[,retained:=density_pass & fast_share_pass]
kept<-eligible[metrics$retained];stopifnot(length(kept)>0)
centres<-c[kept,];control<-discs[kept,];control$retained<-TRUE
# Geometry and policy checks only, never crash-based selection.
stopifnot(all(lengths(st_covered_by(control,dmq))>0),all(as.numeric(st_distance(centres,core))>1000),all(apply(as.matrix(st_distance(centres,stations)),1,min)>1500))
if(nrow(centres)>1){distances<-units::drop_units(as.matrix(st_distance(centres)));diag(distances)<-Inf;stopifnot(min(distances)>=1000-.0001)}
coords<-st_coordinates(st_transform(c,4326))
registry<-merge(cbind(as.data.table(st_drop_geometry(c)),longitude=coords[,1],latitude=coords[,2]),metrics,by.x='id',by.y='unit',all.x=TRUE,sort=FALSE)
registry[is.na(retained),retained:=FALSE];fwrite(registry,file.path(O,'grid_registry.csv'))
st_write(control,file.path(O,'comparison_discs.geojson'),delete_dsn=TRUE,quiet=TRUE)
# Population is audited only AFTER selection, and cannot affect eligibility.
par$population<-g$population$pob_t[match(par$code,g$population$code)];par$area<-as.numeric(st_area(par));stopifnot(!anyNA(par$population))
pop_density<-function(geom){hits<-st_intersects(geom,par);vapply(seq_along(geom),function(i){q<-suppressWarnings(st_intersection(par[hits[[i]],],geom[i]));sum(q$population*as.numeric(st_area(q))/q$area)/as.numeric(st_area(geom[i]))*1e6},0)}
audit<-rbind(cbind(sf_metrics,group='stations'),cbind(metrics[retained==TRUE,.(unit,area_km2,total_road_km,urban_street_km,fast_road_km,road_km_per_km2,urban_street_km_per_km2,fast_share,major_road_share)],group='grid'))
audit[,population_density_approx:=round(pop_density(c(sg,st_geometry(control)))/100)*100]
fwrite(audit,file.path(O,'built_environment.csv'))
summary<-audit[,.(units=.N,median_road_density=median(road_km_per_km2),median_urban_street_density=median(urban_street_km_per_km2),minimum_urban_street_density=min(urban_street_km_per_km2),median_fast_share=median(fast_share),maximum_fast_share=max(fast_share),median_major_share=median(major_road_share),median_population_density=median(population_density_approx)),by=group]
fwrite(summary,file.path(O,'built_environment_summary.csv'))
selection<-data.table(stage=c('grid bounding box','centres within DMQ','whole discs inside DMQ','also outside Metro exclusion','also outside BRT exclusion','also density floor','also fast share cap; retained'),units=c(nrow(c),sum(in_dmq),sum(c$inside_dmq),sum(c$inside_dmq&c$clear_metro),length(eligible),sum(metrics$density_pass),length(kept)))
fwrite(selection,file.path(O,'selection_counts.csv'))
station_exclusion<-st_union(st_buffer(stations,1000));brt_exclusion<-st_buffer(core,500)
base<-ggplot()+geom_sf(data=par,fill='grey98',colour='grey80',linewidth=.15)+geom_sf(data=st_sf(geometry=brt_exclusion),fill='grey30',alpha=.20,colour=NA)+geom_sf(data=st_sf(geometry=station_exclusion),fill=NA,colour='#c24636',linewidth=.35)+geom_sf(data=st_sf(geometry=sg),fill='#c24636',alpha=.45,colour=NA)+geom_sf(data=control,fill='#147f89',alpha=.7,colour='#075761',linewidth=.2)+geom_sf(data=stations,size=.8)+theme_void()+theme(plot.title=element_text(size=12))
full<-base+coord_sf(xlim=c(bb[1],bb[3]),ylim=c(bb[2],bb[4]),expand=FALSE)+labs(title='Whole DMQ; fixed 1 km grid')
zoom_box<-st_bbox(st_union(c(st_geometry(control),st_geometry(st_buffer(stations,1000)))))
zoom<-base+coord_sf(xlim=c(zoom_box[1]-1000,zoom_box[3]+1000),ylim=c(zoom_box[2]-1000,zoom_box[4]+1000),expand=FALSE)+labs(title='Station and retained-grid areas')
png(file.path(O,'comparison_grid_map.png'),width=2200,height=1500,res=160,bg='white')
grid::grid.newpage();grid::pushViewport(grid::viewport(layout=grid::grid.layout(3,2,heights=grid::unit(c(.6,8.1,.6),'null'),widths=c(.9,1.1))))
grid::grid.text(paste('Amendment 4: ',length(kept),' retained 500 m grid discs',sep=''),vp=grid::viewport(layout.pos.row=1,layout.pos.col=1:2),gp=grid::gpar(fontsize=17))
print(full,vp=grid::viewport(layout.pos.row=2,layout.pos.col=1));print(zoom,vp=grid::viewport(layout.pos.row=2,layout.pos.col=2))
grid::grid.text('Teal: comparisons; red: station areas/1 km exclusion; grey: 2022 BRT 500 m exclusion.\nSelection uses geography only. © OpenStreetMap contributors/Geofabrik 2022; GeoQuito.',vp=grid::viewport(layout.pos.row=3,layout.pos.col=1:2),gp=grid::gpar(fontsize=10));dev.off()
saveRDS(list(stations=stations,station_geometry=sg,comparison=control,centres=centres,rule=rule),file.path(D,'geography.rds'))
seconds<-as.numeric(difftime(Sys.time(),started,units='secs'))
fwrite(data.table(check=c('geography only; no crash input','fixed1000m origin-zero grid','nonoverlapping disc interiors','whole disc DMQ/Metro/BRT exclusions','exact minimum station density applied','25percent fast cap applied','population used only for audit','no models power simulations placebos'),passed=c(TRUE,all(c$easting%%1000==0&c$northing%%1000==0),TRUE,TRUE,all(metrics[retained==TRUE,urban_street_km_per_km2]>=floor_density),all(metrics[retained==TRUE,fast_share]<=.25),TRUE,TRUE)),file.path(O,'checks.csv'))
jsonlite::write_json(list(elapsed_seconds=seconds,source_roads='2022 Geofabrik PBF via code/19_amend2_geography.R',station_geometry='unchanged station points and nearest-station partition',crash_inputs_loaded=FALSE),file.path(O,'run_metadata.json'),pretty=TRUE,auto_unbox=TRUE)
cat('Grid comparison geography complete; no crash data loaded.\n')
