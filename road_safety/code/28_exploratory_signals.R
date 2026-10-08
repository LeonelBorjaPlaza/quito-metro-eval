# EXPLORATORY geometry proxies; no observed signal-operation/outage exposure.
source('code/amend2_helpers.R');data.table::setDTthreads(1)
D<-'data/derived/exploratory_20261006';O<-'output/exploratory_20261006'
b<-readRDS(file.path(D,'exploratory_build.rds'));d<-b$crashes
par<-st_transform(st_read(paste0('/vsizip/',normalizePath(PARISH_ZIP)),quiet=TRUE),4326)
sg<-st_read('data/raw/2026-10-05_osm_ecuador_geofabrik/ecuador-220101.osm.pbf',query="SELECT * FROM points WHERE highway = 'traffic_signals'",wkt_filter=st_as_text(st_as_sfc(st_bbox(par))),quiet=TRUE)
saveRDS(sg,file.path(D,'osm_signals.rds'))
fwrite(data.table(mapped_signal_points=nrow(sg),source='2022-01-01 OSM point layer; highway=traffic_signals',status='proxy only; missing signals are not confirmed unsignalized'),file.path(O,'signal_geometry_inventory.csv'))
if(nrow(sg)){
 sg<-st_transform(sg,CRS_UTM);pts<-st_transform(st_as_sf(d[,.(lon,lat)],coords=c('lon','lat'),crs=4326),CRS_UTM)
 near<-st_nearest_feature(pts,sg);dist<-as.numeric(st_distance(pts,sg[near,],by_element=TRUE))
 d[,signal_proxy:=dist<=30 & !is.na(secundaria)&nzchar(secundaria)]
 roads<-readRDS('data/derived/amendment2/build.rds')$roads
 hit<-lengths(st_intersects(roads,st_buffer(st_union(sg),30)))>0
 signal_names<-unique(roads$nm[hit & roads$arterial]);rn<-st_nearest_feature(pts,roads)
 d[,arterial_signal_proxy:=roads$arterial[rn] & roads$nm[rn]%in%signal_names & as.numeric(st_distance(pts,roads[rn,],by_element=TRUE))<=30 & (principal%in%signal_names|secundaria%in%signal_names)]
 out<-list()
 for(proxy in c('signal_proxy','arterial_signal_proxy')){
  x<-cbind(b$members,d[b$members$idx]);x<-x[unit%in%c('corridor_0_600','distant_parishes')]
  x[,location:=ifelse(get(proxy),'Mapped signal proxy','Other/unknown signal status')]
  a<-x[,.(all_crashes=.N,injury_crashes=sum(injury),private_car_crashes=sum(private)),by=.(unit,location,month)]
  a<-merge(CJ(unit=c('corridor_0_600','distant_parishes'),location=c('Mapped signal proxy','Other/unknown signal status'),month=seq(as.Date('2021-01-01'),as.Date('2024-08-01'),by='month')),a,all.x=TRUE)
  for(nm in c('all_crashes','injury_crashes','private_car_crashes'))a[is.na(get(nm)),(nm):=0]
  raw_a<-copy(a)
  for(nm in c('all_crashes','injury_crashes','private_car_crashes')){
   a[,hide:=small_a2(raw_a[[nm]])|small_a2(raw_a$all_crashes)|small_a2(raw_a$all_crashes-raw_a[[nm]])]
   a[,hide:=any(hide),by=.(unit,month)]
   a[,(nm):=ifelse(hide,NA_real_,round5(raw_a[[nm]]))]
  }
  z<-melt(a,id.vars=c('unit','location','month'),measure.vars=c('all_crashes','injury_crashes','private_car_crashes'),variable.name='outcome',value.name='count')
  den<-z[unit=='distant_parishes',.(month,location,outcome,den=count)]
  z<-merge(z,den,by=c('month','location','outcome'));z[,ratio:=count/ifelse(den>0,den,NA_real_)];z[,proxy_definition:=proxy]
  out[[proxy]]<-z
 }
 z<-rbindlist(out);fwrite(z,file.path(O,'signal_monthly_series.csv'))
 e<-fread(file.path(O,'events.csv'));e[,date:=as.Date(date)]
 p<-ggplot(z[unit=='corridor_0_600'],aes(month,ratio,colour=location))+geom_line(na.rm=FALSE)+facet_grid(proxy_definition~outcome,scales='free_y')+
  geom_vline(data=e,aes(xintercept=date),inherit.aes=FALSE,linetype=3,colour='grey60',linewidth=.25)+geom_text(data=e,aes(x=date,y=Inf,label=code),inherit.aes=FALSE,vjust=1.3,size=2.5)+
  annotate('rect',xmin=as.Date('2023-10-27'),xmax=as.Date('2023-12-15'),ymin=-Inf,ymax=Inf,alpha=.07,fill='#d8a03c')+
  annotate('rect',xmin=as.Date('2024-01-08'),xmax=as.Date('2024-04-06'),ymin=-Inf,ymax=Inf,alpha=.06,fill='#824ca5')+
  scale_x_date(date_breaks='1 year',date_labels='%Y')+theme_minimal(base_size=10)+theme(legend.position='bottom')+
  labs(title='EXPLORATORY: mapped-signal location proxies during rationing',x=NULL,y='Corridor / distant-parish ratio',colour=NULL,
  caption='Counts rounded to 5; small/complementary categories jointly withheld. I/P/T/S/R/M/r/C/c1/c2/E: see events.csv.\nMapped signals and signal-near named arterials are incomplete geometry proxies; other locations have unknown status. No outage-hour schedule is available.')
 ggsave(file.path(O,'signal_ratios.png'),p,width=12,height=7,dpi=160);ggsave(file.path(O,'signal_ratios.pdf'),p,width=12,height=7)
}
cat('Exploratory mapped-signal proxy comparison completed; no hourly outage exposure assigned.\n')
