# Amendment 4 proposal: public geography and pre-period descriptives ONLY.
# No model, power calculation, simulation or placebo test.
source('code/amend2_helpers.R');suppressPackageStartupMessages(library(igraph))
setDTthreads(1);O<-'output/amendment4';D<-'data/derived/amendment4'
dir.create(O,recursive=TRUE,showWarnings=FALSE);dir.create(D,recursive=TRUE,showWarnings=FALSE)
b<-readRDS('data/derived/amendment2/build.rds');assert_pre(b$crashes)
g<-readRDS('data/derived/amendment2/geography.rds');r<-g$roads;r$nm<-norm_a2(r$name)
par<-b$parishes;dmq<-st_union(par);stations<-g$stations[order(g$stations$Name),]
brt<-st_transform(st_read(file.path(D,'brt_2022.geojson'),quiet=TRUE),CRS_UTM);core<-st_union(brt)
# Independent minimum-distance check against GDAL's prepared 2022 road ways.
known<-which(as.character(brt$osm_way_id)%in%as.character(r$osm_id));stopifnot(length(known)>0)
distcheck<-vapply(known,function(j)as.numeric(st_distance(brt[j,],st_union(r[as.character(r$osm_id)==as.character(brt$osm_way_id[j]),]))),0)
stopifnot(max(distcheck)<.1)
xy<-lapply(st_geometry(r),function(q)as.matrix(q)[,1:2,drop=FALSE]);a<-do.call(rbind,lapply(xy,function(q)q[1,]));z<-do.call(rbind,lapply(xy,function(q)q[nrow(q),]))
key<-function(q)paste(sprintf('%.5f',q[,1]),sprintf('%.5f',q[,2]),sep=':')
edges<-data.table(from=key(a),to=key(z),id=seq_len(nrow(r)),length=as.numeric(st_length(r)))
v<-unique(rbind(data.table(name=edges$from,x=a[,1],y=a[,2]),data.table(name=edges$to,x=z[,1],y=z[,2])))
G<-graph_from_data_frame(as.data.frame(edges),directed=FALSE,vertices=as.data.frame(v))
near<-function(pt){q<-st_coordinates(pt)[1,1:2];v$name[which.min((v$x-q[1])^2+(v$y-q[2])^2)]}
major<-r$highway%in%c('motorway','trunk','primary','secondary','tertiary')
trace<-function(start,end,preferred){
 p<-shortest_paths(G,near(start),near(end),weights=edges$length*ifelse(preferred,.1,ifelse(major,10,50)),output='both')
 ix<-as.integer(E(G)$id[p$epath[[1]]]);nodes<-as.character(V(G)$name[p$vpath[[1]]]);stopifnot(length(ix)>0)
 q<-lapply(seq_along(ix),function(j){s<-xy[[ix[j]]];if(key(s[1,,drop=FALSE])!=nodes[j])s<-s[nrow(s):1,,drop=FALSE];s})
 q<-do.call(rbind,c(list(q[[1]]),lapply(q[-1],function(s)s[-1,,drop=FALSE])))
 list(ix=ix,preferred=preferred[ix],geometry=st_sfc(st_linestring(q),crs=CRS_UTM))
}
point<-function(lon,lat)st_transform(st_sfc(st_point(c(lon,lat)),crs=4326),CRS_UTM)
anchors<-fread('output/amendment3_stage_a/would_be_anchors.csv')
anchor<-function(n){q<-anchors[anchor==n];point(q$lon,q$lat)}
old<-fread('output/amendment3_stage_a/would_be_route_segments.csv')
paths<-list(north_prensa=trace(anchor('labrador'),anchor('ofelia'),r$road_id%in%old[corridor=='north_phase1',road_id]),north_calderon=trace(anchor('ofelia'),anchor('calderon'),r$road_id%in%old[corridor=='north_phase2',road_id]))
urban_codes<-g$population[grepl('URB',norm_a2(tipo)),code]
urban<-st_union(par[par$code%in%urban_codes,]);valley<-function(names)st_union(par[par$dpa_despar%in%names,])
make_named<-function(pattern,area,axis){
 good<-!is.na(r$nm)&grepl(pattern,r$nm)&major&lengths(st_intersects(r,area))>0
 stopifnot(any(good));ix<-which(good);ends<-rbind(a[ix,,drop=FALSE],z[ix,,drop=FALSE]);lo<-ends[which.min(ends[,axis]),];hi<-ends[which.max(ends[,axis]),]
 trace(st_sfc(st_point(lo),crs=CRS_UTM),st_sfc(st_point(hi),crs=CRS_UTM),good)
}
paths$city_mariscal<-make_named('^(AVENIDA )?MARISCAL SUCRE$',urban,2)
paths$city_eloy<-make_named('^AVENIDA ELOY ALFARO$',urban,2)
paths$city_diego<-make_named('^(AVENIDA )?DIEGO VASQUEZ DE CEPEDA$',urban,2)
paths$valley_interoceanica<-make_named('^(AVENIDA |AV |VIA )?(OSWALDO GUAYASAMIN|INTEROCEANICA)( NORTE)?$',valley(c('CUMBAYA','TUMBACO')),1)
paths$valley_ruminahui<-make_named('^(AUTOPISTA |AVENIDA )?GENERAL RUMINAHUI$',valley('CONOCOTO'),2)
paths$valley_ilalo<-make_named('^(AVENIDA )?ILALO$',valley(c('ALANGASI','LA MERCED','GUANGOPOLO')),1)
labels<-c('La Prensa: Labrador–La Ofelia','Panamericana Norte: La Ofelia–Calderón','Mariscal Sucre: western urban Quito','Eloy Alfaro: northern urban Quito','Diego Vásquez de Cepeda: La Ofelia–Carcelén','Interoceánica/Oswaldo Guayasamín: Cumbayá–Tumbaco','General Rumiñahui: Conocoto','Ilaló: Alangasí–La Merced')
route_sf<-st_sf(corridor=names(paths),label=labels,family=c(rep('planned',2),rep('city',3),rep('valley',3)),geometry=do.call(c,lapply(paths,`[[`,'geometry')))
route_registry<-rbindlist(lapply(seq_along(paths),function(i){
 q<-st_coordinates(st_transform(paths[[i]]$geometry,4326));p<-paths[[i]]
 data.table(priority=i,corridor=names(paths)[i],label=labels[i],family=route_sf$family[i],origin_lon=q[1,1],origin_lat=q[1,2],end_lon=q[nrow(q),1],end_lat=q[nrow(q),2],length_km=sum(edges$length[p$ix])/1000,connector_km=sum(edges$length[p$ix][!p$preferred])/1000)
}));fwrite(route_registry,file.path(O,'corridor_registry.csv'))
fwrite(rbindlist(lapply(names(paths),function(n){p<-paths[[n]];data.table(corridor=n,road_id=r$road_id[p$ix],name=r$name[p$ix],preferred=p$preferred,length_m=round(edges$length[p$ix],1))})),file.path(O,'corridor_segments.csv'))
# Candidate phase, traversal orientation and corridor priority are fixed geometrically.
cs<-lapply(seq_len(nrow(route_sf)),function(j){L<-as.numeric(st_length(route_sf[j,]));pos<-if(L>=1125)seq(625,L-500,by=1250)else numeric();if(!length(pos))return(NULL);pts<-st_cast(st_line_sample(st_geometry(route_sf[j,]),sample=pos/L),'POINT');st_sf(id=sprintf('C%02d_%02d',j,seq_along(pos)),corridor=route_sf$corridor[j],family=route_sf$family[j],chainage_m=pos,geometry=pts)})
candidates<-do.call(rbind,cs);discs<-st_buffer(candidates,500)
station_exclusion<-st_union(st_buffer(stations,1000));brt_exclusion<-st_buffer(core,500)
candidates$outside_dmq<-lengths(st_covered_by(discs,dmq))==0
candidates$near_metro<-apply(as.matrix(st_distance(candidates,stations)),1,min)<=1500
candidates$near_brt<-as.numeric(st_distance(candidates,core))<=1000
candidates$overlap_prior<-FALSE;keep<-integer()
for(i in seq_len(nrow(candidates))){
 if(any(unlist(st_drop_geometry(candidates[i,c('outside_dmq','near_metro','near_brt')]))))next
 if(length(keep)&&any(as.numeric(st_distance(candidates[i,],candidates[keep,]))<1000-.01))candidates$overlap_prior[i]<-TRUE else keep<-c(keep,i)
}
candidates$retained<-seq_len(nrow(candidates))%in%keep
stopifnot(length(keep)>0);control<-candidates[keep,];control_discs<-st_buffer(control,500)
stopifnot(all(lengths(st_intersects(control_discs,station_exclusion))==0),all(lengths(st_intersects(control_discs,brt_exclusion))==0),all(lengths(st_covered_by(control_discs,dmq))>0))
coord<-st_coordinates(st_transform(candidates,4326));fwrite(cbind(as.data.table(st_drop_geometry(candidates)),longitude=coord[,1],latitude=coord[,2]),file.path(O,'comparison_candidates.csv'))
fwrite(as.data.table(st_drop_geometry(candidates))[,.(candidates=.N,retained=sum(retained),outside_dmq=sum(outside_dmq),metro_exclusion=sum(near_metro),brt_exclusion=sum(near_brt),spacing_exclusion=sum(overlap_prior)),by=.(corridor,family)],file.path(O,'corridor_summary.csv'))
st_write(control_discs,file.path(O,'comparison_discs.geojson'),delete_dsn=TRUE,quiet=TRUE);st_write(route_sf,file.path(O,'corridors.geojson'),delete_dsn=TRUE,quiet=TRUE)
# Recompute nearest STATION point rather than reusing entrance distances.
d<-copy(b$crashes)[sicariato==FALSE];assert_pre(d)
pts<-st_transform(st_as_sf(d[,.(lon,lat)],coords=c('lon','lat'),crs=4326),CRS_UTM)
j<-max.col(-as.matrix(st_distance(pts,stations)),ties.method='first')
distance<-as.numeric(st_distance(pts,stations[j,],by_element=TRUE))
d[,`:=`(station4=stations$Name[j],distance4=distance)]
station_units<-rbindlist(lapply(seq_len(nrow(stations)),function(j){nm<-stations$Name[j];rbind(data.table(unit=paste0('near_',nm),family='near',idx=which(d$station4==nm & d$distance4<500)),data.table(unit=paste0('outer_',nm),family='outer',idx=which(d$station4==nm & d$distance4>=500 & d$distance4<1000)))}))
cmem<-st_intersects(pts,control_discs);ci<-lengths(cmem)>0;stopifnot(all(lengths(cmem)<=1))
mem<-rbind(station_units,data.table(unit=control$id[unlist(cmem[ci])],family='comparison',idx=which(ci)))
x<-cbind(mem,d[mem$idx]);months<-seq(as.Date('2021-01-01'),as.Date('2023-11-01'),by='month')
registry<-rbind(data.table(unit=paste0('near_',stations$Name),family='near'),data.table(unit=paste0('outer_',stations$Name),family='outer'),data.table(unit=control$id,family='comparison'))
panel<-merge(CJ(unit=registry$unit,month=months),x[,.(all=.N,pedestrian=sum(pedestrian)),by=.(unit,month)],all.x=TRUE,by=c('unit','month'))
for(nm in c('all','pedestrian'))panel[is.na(get(nm)),(nm):=0L]
panel<-merge(panel,registry,by='unit');stopifnot(nrow(panel)==nrow(registry)*length(months))
means<-panel[,.(all=sum(all),pedestrian=sum(pedestrian)),by=.(unit,family)]
for(nm in c('all','pedestrian'))means[small_a2(get(nm))|small_a2(all-get(nm)),(nm):=NA_real_]
for(nm in c('all','pedestrian'))for(fam in c('near','outer','comparison')){
 if(means[family==fam,sum(is.na(get(nm)))]==1){q<-means[family==fam&!is.na(get(nm))&get(nm)>0];if(nrow(q))means[unit==q[order(get(nm),unit),unit][1],(nm):=NA_real_]}
}
for(nm in c('all','pedestrian'))means[,(paste0(nm,'_monthly_mean')):=round(round5(get(nm))/length(months),1)]
fwrite(means[,.(unit,family,all_monthly_mean,pedestrian_monthly_mean)],file.path(O,'preperiod_means.csv'))
# Descriptive public built-environment audit; no matching or volume threshold.
vor<-st_collection_extract(st_voronoi(st_union(stations),envelope=st_as_sfc(st_bbox(st_buffer(stations,2000)))),'POLYGON')
vj<-vapply(st_intersects(stations,vor),function(i)i[1],1L)
near_geo<-st_sfc(lapply(seq_len(nrow(stations)),function(i)st_intersection(st_geometry(st_buffer(stations[i,],500)),vor[vj[i]])[[1]]),crs=CRS_UTM)
pop<-g$population;par$population<-pop$pob_t[match(par$code,pop$code)];par$area<-as.numeric(st_area(par))
geom<-c(near_geo,st_geometry(control_discs));uids<-c(paste0('near_',stations$Name),control$id)
features<-rbindlist(lapply(seq_along(geom),function(i){area<-as.numeric(st_area(geom[i]));p<-suppressWarnings(st_intersection(par,geom[i]));density<-sum(p$population*as.numeric(st_area(p))/p$area)/area*1e6
 road<-suppressWarnings(st_intersection(r,geom[i]));total<-sum(as.numeric(st_length(road)));data.table(unit=uids[i],family=if(i<=15)'near'else'comparison',area_km2=round(area/1e6,3),road_km_per_km2=round(total/area*1e6/1000,2),major_road_share=if(total>0)round(sum(as.numeric(st_length(road[road$highway%in%c('motorway','trunk','primary','secondary'),])))/total,2)else NA_real_,population_density_approx=round(density/100)*100) }))
fwrite(features,file.path(O,'built_environment.csv'))
fs<-merge(features,as.data.table(st_drop_geometry(control))[,.(unit=id,group=family)],by='unit',all.x=TRUE);fs[family=='near',group:='stations']
fwrite(fs[,.(units=.N,median_road_density=median(road_km_per_km2),median_major_share=median(major_road_share),median_population_density=median(population_density_approx)),by=group],file.path(O,'built_environment_summary.csv'))
bb<-st_bbox(st_union(c(st_geometry(control_discs),st_geometry(st_buffer(stations,1000)))))
map<-ggplot()+geom_sf(data=par,fill='grey98',colour='grey82',linewidth=.15)+geom_sf(data=route_sf,aes(colour=family),linewidth=.45,alpha=.65)+geom_sf(data=st_sf(geometry=brt_exclusion),fill='grey45',alpha=.16,colour=NA)+geom_sf(data=st_buffer(stations,1000),fill=NA,colour='#b43327',linewidth=.3)+geom_sf(data=st_buffer(stations,500),fill='#b43327',alpha=.3,colour=NA)+geom_sf(data=control_discs,aes(fill=family),alpha=.7,colour='#17647a',linewidth=.3)+geom_sf(data=stations,size=.9)+coord_sf(xlim=c(bb[1]-1200,bb[3]+1200),ylim=c(bb[2]-1200,bb[4]+1200),expand=FALSE)+theme_void()+theme(legend.position='bottom')+labs(title='Amendment 4: proposed equal-radius comparison areas',subtitle='500 m discs; Metro 1 km exclusion (red), 2022 BRT 500 m exclusion (grey)',caption='1.25 km along-road candidate spacing; at least 1 km between retained centres.\nWhole discs retained or rejected; AMT coverage restricted to DMQ.\n© OpenStreetMap contributors, Geofabrik 2022; GeoQuito parish boundaries.',colour='Corridor',fill='Disc group')
ggsave(file.path(O,'comparison_map.png'),map,width=10,height=10,dpi=160,bg='white')
saveRDS(list(panel=panel,registry=registry,comparison=control_discs,stations=stations,crashes=d,assignment=mem),file.path(D,'pre_only.rds'))
fwrite(data.table(check=c('outcomes January2021-November2023 only','no post outcomes or model','no volume screen','equal500m comparison discs','whole discs beyond Metro1km and BRT500m','all discs inside DMQ','PBF roadways agree with GDAL minimum distances','no power simulations or placebos'),passed=c(max(d$fecha)<OPENING,TRUE,TRUE,TRUE,TRUE,TRUE,max(distcheck)<.1,TRUE)),file.path(O,'checks.csv'))
cat('Amendment4 proposal map and protected pre-period audit complete; no estimation.\n')
