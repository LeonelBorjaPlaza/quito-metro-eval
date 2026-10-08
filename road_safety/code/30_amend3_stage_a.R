# Amendment 3 Stage A ONLY: public geography + observed pre-period quantities.
# No P1/P2 outcome, simulation, conformal statistic or effect estimate is loaded.
source('code/amend2_helpers.R');source('code/amend2_calendar.R')
suppressPackageStartupMessages({library(fixest);library(igraph)})
data.table::setDTthreads(1);setFixest_nthreads(1)
D<-'data/derived/amendment3';O<-'output/amendment3_stage_a'
dir.create(D,recursive=TRUE,showWarnings=FALSE);dir.create(O,recursive=TRUE,showWarnings=FALSE)
b<-readRDS('data/derived/amendment2/build.rds');geo<-readRDS('data/derived/amendment2/geography.rds')
assert_pre(b$crashes)
d<-copy(b$crashes)[fecha<as.Date('2023-11-01')]
stopifnot(min(d$fecha)>=as.Date('2021-01-01'),max(d$fecha)<as.Date('2023-11-01'))
traffic<-c('CHOQUES','COLISION','ROCE','ATROPELLO','ESTRELLAMIENTO','PERDIDA DE CARRIL','VOLCAMIENTO')
d[,`:=`(H1=tipologia%in%traffic,H2=tipologia=='ATROPELLO',qoy=as.integer((as.integer(format(fecha,'%m'))-1)%/%3+1L))]
par<-b$parishes;par$unit<-paste0('parish_',par$code)
remote<-par[par$distant,];stopifnot(nrow(remote)==39)
stations<-geo$stations;stations$unit<-paste0('station_',stations$Name)
# Graph from 2022 motor-road segments, undirected because buffers are exposures,
# not traffic routes. Prefer named alignment roads; connectors are audited.
r<-geo$roads;r$nm<-norm_a2(r$name);r$length_m<-as.numeric(st_length(r))
coords<-lapply(st_geometry(r),function(g)as.matrix(g)[,1:2,drop=FALSE])
first<-do.call(rbind,lapply(coords,function(q)q[1,]));last<-do.call(rbind,lapply(coords,function(q)q[nrow(q),]))
key<-function(q)paste(sprintf('%.5f',q[,1]),sprintf('%.5f',q[,2]),sep=':')
ends<-data.table(from=key(first),to=key(last),id=seq_len(nrow(r)),length=r$length_m)
vertices<-unique(rbind(data.table(name=ends$from,x=first[,1],y=first[,2]),data.table(name=ends$to,x=last[,1],y=last[,2])))
graph<-graph_from_data_frame(as.data.frame(ends[,.(from,to,id,length)]),directed=FALSE,vertices=as.data.frame(vertices))
anchors<-st_read('data/raw/2026-10-05_osm_ecuador_geofabrik/ecuador-220101.osm.pbf',
 query="SELECT * FROM points WHERE osm_id IN ('2828952690','358107491')",quiet=TRUE)
stopifnot(nrow(anchors)==2L)
ofelia<-st_transform(anchors[anchors$osm_id=='2828952690',],CRS_UTM)
calderon<-st_transform(anchors[anchors$osm_id=='358107491',],CRS_UTM)
labrador<-stations[stations$Name=='Labrador',];ejido<-stations[stations$Name=='El Ejido',]
rumi<-which(r$highway%in%c('motorway','trunk','primary','secondary') & grepl('(^| )GENERAL RUMINAHUI$',r$nm))
stopifnot(length(rumi)>0,nrow(ofelia)==1,nrow(calderon)==1,nrow(labrador)==1,nrow(ejido)==1)
southxy<-rbind(first[rumi,,drop=FALSE],last[rumi,,drop=FALSE]);southxy<-southxy[which.min(southxy[,2]),]
chillos<-st_sf(name='southernmost named General Rumiñahui endpoint in DMQ extract',geometry=st_sfc(st_point(southxy),crs=CRS_UTM))
node_near<-function(pt){q<-st_coordinates(pt)[1,1:2];vertices$name[which.min((vertices$x-q[1])^2+(vertices$y-q[2])^2)]}
trace<-function(a,z,pattern){
 preferred<-r$highway%in%c('motorway','trunk','primary','secondary') & grepl(pattern,r$nm)
 cost<-r$length_m*ifelse(preferred,1,ifelse(r$highway%in%c('motorway','trunk','primary','secondary'),6,30))
 path<-shortest_paths(graph,from=node_near(a),to=node_near(z),weights=cost,output='epath')$epath[[1]]
 stopifnot(length(path)>0)
 ix<-as.integer(E(graph)$id[path]);list(geometry=st_union(r[ix,]),ix=ix,preferred=preferred[ix])
}
p1<-trace(labrador,ofelia,'(DE LA PRENSA|^LA PRENSA$)')
p2<-trace(ofelia,calderon,'PANAMERICANA NORTE|GALO PLAZA LASSO')
p3<-trace(ejido,chillos,'GENERAL RUMINAHUI')
paths<-list(north_phase1=p1,north_phase2=p2,south=p3)
path_audit<-rbindlist(lapply(names(paths),function(nm){p<-paths[[nm]];data.table(corridor=nm,road_id=r$road_id[p$ix],osm_id=r$osm_id[p$ix],name=r$name[p$ix],preferred_name=p$preferred,length_m=round(r$length_m[p$ix],1))}))
fwrite(path_audit,file.path(O,'would_be_route_segments.csv'))
exclusion<-st_union(st_buffer(geo$entrances,2000))
foot<-lapply(paths,function(p)st_difference(st_buffer(p$geometry,600),exclusion))
foot$north<-st_union(c(foot$north_phase1,foot$north_phase2))
foot$south<-st_difference(foot$south,foot$north)
# Restrict crash coverage to DMQ. Proposed southern endpoint is a transparent road
# proxy; the supplied geometry is not an official extension engineering alignment.
foot<-lapply(foot,function(q)st_intersection(q,st_union(par)))
stat<-rbindlist(lapply(names(paths),function(nm){p<-paths[[nm]];data.table(corridor=nm,path_km=sum(r$length_m[p$ix])/1000,nonpreferred_connector_km=sum(r$length_m[p$ix][!p$preferred])/1000,retained_area_km2=as.numeric(sum(st_area(foot[[nm]])))/1e6)}))
fwrite(stat,file.path(O,'would_be_geometry_summary.csv'))
anchor_audit<-rbindlist(lapply(list(ofelia=ofelia,calderon=calderon,labrador=labrador,ejido=ejido,chillos=chillos),function(p){xy<-st_coordinates(st_transform(p,4326))[1,];data.table(lon=xy[1],lat=xy[2])}),idcol='anchor')
fwrite(anchor_audit,file.path(O,'would_be_anchors.csv'))
public<-st_sf(corridor=names(foot),geometry=st_sfc(lapply(foot,function(q)st_union(q)[[1]]),crs=CRS_UTM))
st_write(public,file.path(O,'would_be_corridors.geojson'),delete_dsn=TRUE,quiet=TRUE)
pp<-ggplot()+geom_sf(data=par,fill='grey97',colour='grey80',linewidth=.15)+geom_sf(data=public[public$corridor%in%c('north_phase1','north_phase2','south'),],aes(fill=corridor),alpha=.55,colour=NA)+geom_sf(data=st_sf(geometry=exclusion),fill=NA,colour='#ba3d29',linewidth=.35)+geom_sf(data=stations,shape=21,size=1.5,fill='black')+theme_void()+theme(legend.position='bottom')+labs(title='Amendment 3: would-be road-corridor proxies',subtitle='600 m buffers on 2022 OSM traces; operating-entrance exclusion shown in red',caption='Public geometry only. Northern phases share one comparator.\nSouthern Los Chillos endpoint: DMQ named-road extent proxy.\nRoads: © OpenStreetMap contributors, Geofabrik 2022 extract.')
bb<-st_bbox(st_union(c(exclusion,foot$north,foot$south)));pp<-pp+coord_sf(xlim=c(bb[1]-1500,bb[3]+1500),ylim=c(bb[2]-1500,bb[4]+1500),expand=FALSE);ggsave(file.path(O,'would_be_corridors.png'),pp,width=9,height=9,dpi=160,bg='white');ggsave(file.path(O,'would_be_corridors.pdf'),pp,width=9,height=9,bg='white')
pts<-st_transform(st_as_sf(d[,.(lon,lat)],coords=c('lon','lat'),crs=4326),CRS_UTM)
d[,`:=`(north=lengths(st_intersects(pts,foot$north))>0,south=lengths(st_intersects(pts,foot$south))>0)]
mem<-rbindlist(c(lapply(stations$Name,function(nm)data.table(unit=paste0('station_',nm),idx=which(d$station==nm & d$dist_station<600))),lapply(remote$code,function(pc)data.table(unit=paste0('parish_',pc),idx=which(d$parish==pc))),list(data.table(unit='would_be_north',idx=which(d$north)),data.table(unit='would_be_south',idx=which(d$south)))))
x<-cbind(mem,d[mem$idx]);x[,H2:=H2 & (grepl('^parish_',unit)|grepl('^would_be_',unit)|dist_station<300)]
units<-c(stations$unit,remote$unit,'would_be_north','would_be_south')
main_dates<-seq(as.Date('2022-01-01'),as.Date('2023-10-31'),by='day')
main_months<-seq(as.Date('2022-01-01'),as.Date('2023-10-01'),by='month')
# H1-based registry, inference only. Every remote parish stays in estimation.
ct<-sapply(remote$code,function(pc)tabulate(match(d[H1 & parish==pc & fecha>=as.Date('2022-01-01'),month],main_months),length(main_months)))
pass<-function(j)mean(rowSums(ct[,j,drop=FALSE]))>=3 & mean(rowSums(ct[,j,drop=FALSE])==0)<=.2
single<-which(vapply(seq_len(ncol(ct)),function(i)pass(i),TRUE));adj<-st_relate(remote,remote,pattern='F***1****')
left<-setdiff(seq_len(nrow(remote)),single);groups<-lapply(single,identity);failed<-list()
by_volume<-function(j)j[order(-colSums(ct)[j],remote$code[j])]
while(length(left)){g<-by_volume(left)[1];left<-setdiff(left,g);repeat{if(pass(g))break;nb<-intersect(unique(unlist(adj[g])),left);if(!length(nb))break;j<-by_volume(nb)[1];g<-c(g,j);left<-setdiff(left,j)};if(pass(g))groups[[length(groups)+1]]<-g else failed[[length(failed)+1]]<-g}
registry<-rbindlist(c(lapply(seq_along(groups),function(j)data.table(id=paste0('placebo_',j),members=paste(remote$code[groups[[j]]],collapse=';'),eligible_H1=TRUE)),lapply(seq_along(failed),function(j)data.table(id=paste0('ineligible_',j),members=paste(remote$code[failed[[j]]],collapse=';'),eligible_H1=FALSE))))
# H2 pre-support screen is fixed now, never based on post estimates.
registry[,eligible_H2:=vapply(strsplit(members,';'),function(codes){z<-d[H2 & parish%in%as.integer(codes)&fecha>=as.Date('2022-01-01')];nrow(z)>0 && uniqueN(z$month)>1},TRUE)&eligible_H1]
fwrite(registry,file.path(O,'placebo_registry.csv'))
floors<-rbindlist(lapply(c('H1','H2'),function(h){k<-sum(registry[[paste0('eligible_',h)]]);data.table(hypothesis=h,eligible_placebos=k,raw_floor=1/(k+1),minimum_first_Holm_p=min(1,2/(k+1)),five_percent_family_rejection_attainable=k>=39)}))
fwrite(floors,file.path(O,'rank_floors.csv'))
# Complete count panel. No volume exclusion of estimation units.
make_panel<-function(start,frequency){
 dates<-seq(as.Date(start),as.Date('2023-10-31'),by='day');cal<-data.table(date=dates)
 cal[,`:=`(month=as.Date(format(date,'%Y-%m-01')),dow=as.integer(format(date,'%u')),qoy=as.integer((as.integer(format(date,'%m'))-1)%/%3+1L),holiday=date%in%A2_HOLIDAYS)]
 if(frequency=='monthly')cal<-unique(cal[,.(date=month,qoy)])
 xx<-copy(x)[fecha>=as.Date(start)];xx[,time:=if(frequency=='daily')fecha else month]
 a<-xx[,.(H1=sum(H1),H2=sum(H2),n_all=.N),by=.(unit,date=time)]
 a<-merge(CJ(unit=units,date=cal$date),a,by=c('unit','date'),all.x=TRUE)
 for(nm in c('H1','H2','n_all'))a[is.na(get(nm)),(nm):=0]
 a<-merge(a,cal,by='date');a[,`:=`(treated=grepl('^station_',unit),group=fcase(grepl('^station_',unit),'Metro',unit=='would_be_north','North',unit=='would_be_south','South',default='Parishes'))];a
}
# Nearest gauges to fixed geographic zone representatives; no crash-based gauge choice.
ug<-readRDS('data/derived/amendment2/unit_geometry.rds')
unit_geom<-lapply(units,function(u)if(u=='would_be_north')foot$north else if(u=='would_be_south')foot$south else ug[[u]])
centres<-st_sfc(lapply(unit_geom,function(q)st_centroid(st_union(q))[[1]]),crs=CRS_UTM)
rr<-fread('data/derived/amendment2/rain_pre.csv');setnames(rr,names(rr)[1],'serial')
rr[,datetime:=as.POSIXct(round(as.numeric(serial)*24)*3600,origin='1899-12-30',tz='UTC')]
rr[,fecha:=as.Date(datetime)];rr<-rr[fecha<as.Date('2023-11-01')]
cols<-setdiff(names(rr),c('serial','datetime','fecha','ElCamal'))
rl<-melt(rr,id.vars=c('datetime','fecha'),measure.vars=cols,variable.name='station',value.name='rain');rl[,rain:=as.numeric(rain)]
ra<-rl[,.(rain=if(.N==24 && all(!is.na(rain)))sum(rain)else NA_real_,observed_hours=sum(!is.na(rain))),by=.(station,date=fecha)]
ra[,moy:=as.integer(format(date,'%m'))];ra[,climatology:=median(rain,na.rm=TRUE),by=.(station,moy)]
ra[!is.finite(climatology),climatology:=median(rain,na.rm=TRUE),by=station]
ra[,missing_rain:=as.integer(is.na(rain))];ra[is.na(rain),rain:=climatology]
mon<-st_transform(st_read('../air_quality/data/for_maps/Distancia_REMMAQ_Metro.gpkg',quiet=TRUE),CRS_UTM)
mon$rain_name<-norm_a2(mon$Station);mon$rain_name[mon$rain_name=='SAN ANTONIO DE PICHINCHA']<-'SAN ANTONIO'
mon<-mon[mon$rain_name%in%norm_a2(cols),];nm<-setNames(cols,norm_a2(cols));rn<-unname(nm[mon$rain_name[st_nearest_feature(centres,mon)]])
weather_assign<-data.table(unit=units,rain_station=rn);fwrite(weather_assign,file.path(O,'rain_assignment.csv'))
fwrite(ra[date>=as.Date('2022-01-01'),.(complete_day_share=mean(missing_rain==0)),by=station],file.path(O,'rain_coverage.csv'))
post_dates<-c(seq(as.Date('2023-12-01'),as.Date('2024-08-31'),by='day'),seq(as.Date('2025-01-01'),as.Date('2026-08-31'),by='day'))
longrun<-function(g,L){g<-g-mean(g);n<-length(g);g0<-sum(g*g)/n;v<-g0;for(k in seq_len(min(L,n-1)))v<-v+2*(1-k/(L+1))*sum(g[(k+1):n]*g[1:(n-k)])/n;max(v,0)}
precision<-list();mean_tables<-list();fit_checks<-list()
for(start in c('2022-01-01','2021-01-01'))for(freq in c('daily','monthly')){
 p<-make_panel(start,freq);p<-p[unit%in%c(stations$unit,remote$unit)]
 if(freq=='daily'){
  p<-merge(p,weather_assign,by='unit');p<-merge(p,ra[,.(rain_station=station,date,rain,missing_rain)],by=c('rain_station','date'),all.x=TRUE)
  stopifnot(!anyNA(p$rain),!anyNA(p$missing_rain))
  form<-H1~rain+missing_rain|unit+date+group^qoy+unit^dow
 }else form<-H1~1|unit+date+group^qoy
 f<-fepois(form,p,notes=FALSE,warn=FALSE)
 # Use stored in-sample fitted means: nested fixed-effect labels need not
 # provide unique out-of-sample FE decompositions. Omitted training rows may
 # receive zero only if their observed count is zero (Poisson boundary).
 used<-fixest::obs(f);stopifnot(length(used)==length(f$fitted.values))
 omitted<-setdiff(seq_len(nrow(p)),used)
 stopifnot(all(p$H1[omitted]==0))
 p[,mu:=0];p[used,mu:=as.numeric(f$fitted.values)]
 stopifnot(all(is.finite(p$mu)),all(p$mu>=0))
 gap<-p[,.(observed=sum(H1),expected=sum(mu)),by=.(date,treated)]
 gap<-dcast(gap,date~treated,value.var=c('observed','expected'));scale_t<-mean(gap$expected_TRUE);scale_c<-mean(gap$expected_FALSE);stopifnot(scale_t>0,scale_c>0)
 gap[,g:=(observed_TRUE-expected_TRUE)/scale_t-(observed_FALSE-expected_FALSE)/scale_c]
 for(L in if(freq=='daily')c(30L,90L,180L)else c(1L,3L,6L)){
  v<-longrun(gap$g,L);npre<-nrow(gap);npost<-if(freq=='daily')length(post_dates)else 29L
  se<-sqrt(v*(1/npre+1/npost));shift<-(qnorm(1-.025/2)+qnorm(.8))*se
  precision[[paste(start,freq,L)]]<-data.table(start=start,frequency=freq,lag=L,pre_periods=npre,planned_post_periods=npost,residual_variance=var(gap$g),long_run_variance=v,planning_se=se,log_shift=shift,detectable_fall_pct=100*(1-exp(-shift)),detectable_rise_pct=100*expm1(shift),default_lag=L==if(freq=='daily')90L else 3L,
   interpretation='analytical pre-residual approximation; conservative Holm planning alpha=.025, power=.8; not an inference SE or validated placebo power')
 }
 saveRDS(list(model=f,panel=p,gap=gap),file.path(D,paste0('pre_fit_',freq,'_',substr(start,1,4),'.rds')))
 fit_checks[[paste(start,freq)]]<-data.table(start=start,frequency=freq,estimation_units=uniqueN(p$unit),zero_count_units=p[,.(n=sum(H1)),by=unit][n==0,.N],nonfinite_predictions=sum(!is.finite(p$mu)),days_with_imputed_rain=if(freq=='daily')uniqueN(p[missing_rain==1,date])else NA_integer_)
}
prec<-rbindlist(precision);fwrite(prec,file.path(O,'precision_comparison.csv'));fwrite(rbindlist(fit_checks),file.path(O,'pre_fit_checks.csv'))
main<-prec[start=='2022-01-01' & default_lag];best<-main[order(log_shift,frequency=='daily')][1]
fwrite(best,file.path(O,'main_frequency_choice.csv'))
means<-merge(data.table(unit=units),x[fecha>=as.Date('2022-01-01'),.(traffic=sum(H1),pedestrian300=sum(H2)),by=unit],by='unit',all.x=TRUE,sort=FALSE)
for(nm in c('traffic','pedestrian300'))means[is.na(get(nm)),(nm):=0]
# Sparse totals and complements hidden, before rounded-total monthly means.
for(nm in c('traffic','pedestrian300'))means[small_a2(get(nm))|small_a2(traffic-get(nm)),(nm):=NA_real_]
means[,family:=fifelse(grepl('^station_',unit),'Metro',fifelse(grepl('^parish_',unit),'Distant parishes',unit))]
# Protect linked parent totals if precisely one child cell is withheld.
for(nm in c('traffic','pedestrian300'))for(fam in c('Metro','Distant parishes')){
 if(means[family==fam,sum(is.na(get(nm)))]==1L){
  candidates<-means[family==fam & !is.na(get(nm)) & get(nm)>0]
  if(nrow(candidates)){chosen<-candidates[order(get(nm),unit),unit][1];means[unit==chosen,(nm):=NA_real_]}
 }
}
for(nm in c('traffic','pedestrian300'))means[,(paste0(nm,'_monthly_mean')):=round(round5(get(nm))/22,1)]
fwrite(means[,.(unit,traffic_monthly_mean,pedestrian300_monthly_mean)],file.path(O,'preperiod_means.csv'))
# Parent totals separately; small station data receive a second suppression if needed.
agg<-x[fecha>=as.Date('2022-01-01'),.(H1=sum(H1),H2=sum(H2)),by=.(family=fifelse(grepl('^station_',unit),'Metro',fifelse(grepl('^parish_',unit),'Distant parishes',unit)))]
for(nm in c('H1','H2'))agg[small_a2(get(nm))|small_a2(H1-get(nm)),(nm):=NA_real_]
agg[,`:=`(H1_monthly_mean=round(round5(H1)/22,1),H2_monthly_mean=round(round5(H2)/22,1))]
fwrite(agg[,.(family,H1_monthly_mean,H2_monthly_mean)],file.path(O,'preperiod_family_means.csv'))
saveRDS(list(crashes=d,members=mem,station_geometry=stations,parishes=par,would_be=foot,registry=registry,groups=groups,failed=failed,weather=ra,weather_assignment=weather_assign),file.path(D,'stage_a_build.rds'))
fwrite(data.table(check=c('only observed pre-period through October2023','15stations39individualparishes','northern/southern buffers exclude2km operating entrances','no post-effect estimation','no simulations'),passed=c(max(d$fecha)<as.Date('2023-11-01'),nrow(stations)==15&&nrow(remote)==39,all(as.numeric(st_area(st_intersection(foot$north,exclusion)))<1)&&all(as.numeric(st_area(st_intersection(foot$south,exclusion)))<1),TRUE,TRUE)),file.path(O,'checks.csv'))
cat('Amendment3 StageA geography, pre-period precision and fixed placebo registry complete.\n')
