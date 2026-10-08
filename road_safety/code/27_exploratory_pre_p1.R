# EXPLORATORY ONLY. User authorizes January 2021-August 2024, not amendment approval.
source('code/amend2_helpers.R')
suppressPackageStartupMessages(library(fixest))
data.table::setDTthreads(1);setFixest_nthreads(1)
D <- 'data/derived/exploratory_20261006'; O <- 'output/exploratory_20261006'
dir.create(O,recursive=TRUE,showWarnings=FALSE)
s<-fread(file.path(D,'crashes_pre.csv'),colClasses='character',na.strings='')
v<-fread(file.path(D,'vehicles_pre.csv'),colClasses='character',na.strings='')
num<-function(z)suppressWarnings(as.numeric(z))
d<-data.table(id=s$SINIESTRO,fecha=as.Date(num(s$FECHA),origin='1899-12-30'),
 minute=as.integer(round((num(s$HORA)%%1)*1440))%%1440L,lon=num(s$LONGITUD),lat=num(s$LATITUD),
 injury=num(s$LESIONADOS)>0,principal=norm_a2(s$PRINCIPAL),secundaria=norm_a2(s$SECUNDARIA),
 homicide=grepl('SICARIATO',s$FALLECIDOS,fixed=TRUE))
stopifnot(min(d$fecha)>=as.Date('2021-01-01'),max(d$fecha)<as.Date('2024-09-01'),!anyDuplicated(d$id))
d<-d[!homicide & is.finite(lon)&is.finite(lat)]
v[,private:=norm_a2(`TIPO DE VEHÍCULO`)%in%c('AUTOMOVIL','CAMIONETA') & norm_a2(`TIPO DE SERVICIO`)%in%'PARTICULAR']
vv<-v[,.(vehicles=.N,private_vehicles=sum(private)),by=.(id=SINIESTRO)]
d<-merge(d,vv,by='id',all.x=TRUE,sort=FALSE);stopifnot(!anyNA(d$vehicles),!anyNA(d$injury))
d[,`:=`(private=private_vehicles>0,month=as.Date(format(fecha,'%Y-%m-01')),hour=minute%/%60L)]
g<-readRDS('data/derived/amendment2/geography.rds')
par<-st_transform(st_read(paste0('/vsizip/',normalizePath(PARISH_ZIP)),quiet=TRUE),CRS_UTM)
line<-st_union(st_transform(st_zm(st_read(LINE_GPKG,quiet=TRUE)),CRS_UTM))
par$code<-as.integer(par$dpa_parroq);par$distant<-as.numeric(st_distance(par,line))>2000
stopifnot(sum(par$distant)==39)
ctr<-st_transform(st_read(CENTRO_GEOJSON,quiet=TRUE),CRS_UTM)
pts<-st_transform(st_as_sf(d[,.(lon,lat)],coords=c('lon','lat'),crs=4326),CRS_UTM)
h<-st_intersects(pts,par);pi<-vapply(h,function(k)if(length(k))k[which.min(par$code[k])]else NA_integer_,0L)
near<-st_nearest_feature(pts,g$entrances);dist<-as.numeric(st_distance(pts,g$entrances[near,],by_element=TRUE))
d[,`:=`(station=g$entrances$station[near],dist=dist,parish=par$code[pi],historic=lengths(st_intersects(pts,ctr))>0,
 pico=lengths(st_intersects(pts,readRDS('data/derived/amendment2/pico_zone.rds')))>0,
 ring=as.character(cut(dist,c(0,300,600,1000,2000,Inf),right=FALSE,labels=c(A2_RINGS,'beyond'))))]
d<-d[!is.na(parish)]
mem<-rbindlist(c(lapply(A2_RINGS,function(r)data.table(unit=r,idx=which(d$ring==r))),
 list(data.table(unit='corridor_0_600',idx=which(d$dist<600)),data.table(unit='historic_center',idx=which(d$historic)),
 data.table(unit='distant_parishes',idx=which(d$parish%in%par$code[par$distant]))),
 lapply(g$stations$Name,function(st)data.table(unit=paste0('station_',st),idx=which(d$station==st & d$dist<600)))))
x<-cbind(mem,d[mem$idx]); units<-c(A2_RINGS,'corridor_0_600','historic_center','distant_parishes',paste0('station_',g$stations$Name))
months<-seq(as.Date('2021-01-01'),as.Date('2024-08-01'),by='month')
outcomes<-c('all_crashes','injury_crashes','private_car_crashes')
aggregate_counts<-function(z,time){
 a<-z[,.(all_crashes=.N,injury_crashes=sum(injury),private_car_crashes=sum(private),vehicles=sum(vehicles),private_vehicles=sum(private_vehicles)),by=c('unit',time)]
 a<-merge(CJ(unit=units,tt=sort(unique(z[[time]]))),setnames(a,time,'tt'),by=c('unit','tt'),all.x=TRUE)
 for(nm in c(outcomes,'vehicles','private_vehicles'))set(a,which(is.na(a[[nm]])),nm,0L)
 a
}
a<-aggregate_counts(x,'month');setnames(a,'tt','month')
# Joint release across outcomes protects small counts and complements. A second
# station is withheld if exactly one station is hidden, blocking corridor subtraction.
released<-copy(a)
for(nm in outcomes){
 hide<-small_a2(a[[nm]]) | small_a2(a$all_crashes)
 if(nm!='all_crashes')hide<-hide|small_a2(a$all_crashes-a[[nm]])
 # If one inner ring is hidden, hide the other; the corridor/station total
 # cannot reconstruct either. Independent outer rings need no shared total.
 for(m in months){
  ix<-which(a$month==m & a$unit%in%A2_RINGS[1:2]);if(any(hide[ix]))hide[ix]<-TRUE
  ix<-which(a$month==m & grepl('^station_',a$unit))
  if(sum(hide[ix])==1){eligible<-ix[!hide[ix]&a[[nm]][ix]>=5];if(length(eligible))hide[eligible[which.min(a[[nm]][eligible])]]<-TRUE else hide[ix]<-TRUE}
 }
 released[,(nm):=ifelse(hide,NA_real_,round5(a[[nm]]))]
}
vhide<-small_a2(a$private_vehicles)|small_a2(a$vehicles-a$private_vehicles)|a$vehicles<10
released[,vehicles:=ifelse(vhide,NA_real_,round5(a$vehicles))]
released[,private_vehicles:=ifelse(vhide,NA_real_,round5(a$private_vehicles))]
released[,share_private:=ifelse(vhide,NA_real_,5*round(100*private_vehicles/pmax(vehicles,5)/5))]
long<-melt(released,id.vars=c('unit','month'),measure.vars=outcomes,variable.name='outcome',value.name='count')
den<-long[unit=='distant_parishes',.(month,outcome,den=count)]
long<-merge(long,den,by=c('month','outcome'),all.x=TRUE)
long[,ratio:=count/ifelse(den>0,den,NA_real_)]
fwrite(long,file.path(O,'monthly_series.csv'))
fwrite(released[unit%in%c('corridor_0_600','distant_parishes'),.(unit,month,vehicles,private_vehicles,share_private)],file.path(O,'private_vehicle_share.csv'))
# Dates supplied by Leonel; repository corroborates schedule-change dates and Dec15 endpoint.
events<-data.table(event=c('Inauguration (no service)','Pico y placa schedule','Passenger tests begin','Passenger tests suspended','Rationing begins','Commercial opening','Rationing ends (mid-Dec)','Exception/curfew begins','Curfew 00:00-05:00','Curfew 01:00-05:00','Exception/curfew ends'),
 date=as.Date(c('2022-12-21','2023-04-10','2023-05-02','2023-05-12','2023-10-27','2023-12-01','2023-12-15','2024-01-08','2024-01-23','2024-03-21','2024-04-06')),
 code=c('I','P','T','S','R','M','r','C','c1','c2','E'))
fwrite(events,file.path(O,'events.csv'))
labels<-c(ring_0_300='0-300 m',ring_300_600='300-600 m',ring_600_1000='600-1,000 m',ring_1000_2000='1,000-2,000 m',corridor_0_600='Corridor 0-600 m',historic_center='Historic centre',distant_parishes='39 pooled distant parishes')
cap<-paste('EXPLORATORY; no inference. Counts rounded to 5; small counts and complements withheld. Ratios use released counts.\nI inauguration; P pico; T/S tests start/suspension; R/r rationing start/end; M service; C/E curfew start/end; c1/c2 schedule changes.')
mark<-function(p,lo=as.Date('2021-01-01'),hi=as.Date('2024-08-31')){
 e<-events[date>=lo & date<=hi]
 p+geom_vline(data=e,aes(xintercept=date),inherit.aes=FALSE,colour='#777777',linetype=3,linewidth=.25)+
 geom_text(data=e,aes(x=date,y=Inf,label=code),inherit.aes=FALSE,vjust=1.2,colour='#333333',size=2.3)+
 annotate('rect',xmin=as.Date('2023-10-27'),xmax=as.Date('2023-12-15'),ymin=-Inf,ymax=Inf,fill='#d8a03c',alpha=.065)+
 annotate('rect',xmin=as.Date('2024-01-08'),xmax=as.Date('2024-04-06'),ymin=-Inf,ymax=Inf,fill='#824ca5',alpha=.06)
}
style<-theme_minimal(base_size=10)+theme(panel.grid.minor=element_blank(),strip.text=element_text(size=9),plot.caption=element_text(size=7,hjust=0),legend.position='bottom')
saveplot<-function(p,name,w=12,h=10){ggsave(file.path(O,paste0(name,'.png')),p,width=w,height=h,dpi=160);ggsave(file.path(O,paste0(name,'.pdf')),p,width=w,height=h)}
z<-long[unit%in%names(labels)];z[,area:=factor(labels[unit],levels=labels)]
saveplot(mark(ggplot(z,aes(month,count))+geom_line(na.rm=FALSE,colour='#195f8d')+facet_grid(area~outcome,scales='free_y')+scale_x_date(date_breaks='1 year',date_labels='%Y')+labs(title='EXPLORATORY: monthly crash levels, January 2021-August 2024',x=NULL,y='Released crashes',caption=cap)+style),'monthly_levels',h=14)
saveplot(mark(ggplot(z[unit!='distant_parishes'],aes(month,ratio))+geom_line(na.rm=FALSE,colour='#195f8d')+facet_grid(area~outcome,scales='free_y')+scale_x_date(date_breaks='1 year',date_labels='%Y')+labs(title='EXPLORATORY: treated-unit / pooled-distant-parish ratios',x=NULL,y='Count ratio',caption=cap)+style),'monthly_ratios',h=12)
for(oc in outcomes){
 q<-long[grepl('^station_',unit)&outcome==oc & month>=as.Date('2022-01-01')&month<=as.Date('2023-12-01')]
 q[,area:=sub('^station_','',unit)]
 saveplot(mark(ggplot(q,aes(month,ratio))+geom_line(colour='#195f8d',na.rm=FALSE)+facet_wrap(~area,ncol=3,scales='free_y')+scale_x_date(date_breaks='6 months',date_labels='%b %Y')+labs(title=paste('EXPLORATORY: station 0-600 m ratios,',oc),x=NULL,y='Station / distant parish ratio',caption=paste(cap,'\nBlanks include complementary station suppression; stations assigned by nearest entrance.'))+style,lo=as.Date('2022-01-01'),hi=as.Date('2024-08-31')),paste0('station_ratios_',oc),h=14)
}
sh<-released[unit%in%c('corridor_0_600','distant_parishes')]
saveplot(mark(ggplot(sh,aes(month,share_private,colour=unit))+geom_line(na.rm=FALSE)+scale_colour_manual(values=c('#b45309','#195f8d'),labels=labels[c('corridor_0_600','distant_parishes')])+scale_x_date(date_breaks='6 months',date_labels='%b %Y')+labs(title='EXPLORATORY: private-car share of involved vehicles',x=NULL,y='Released share (%)',colour=NULL,caption=paste(cap,'\nAll vehicle rows form denominator, including NO IDENTIFICADO; shares rounded to 5 percentage points.'))+style),'private_vehicle_share',h=5)
# Exact internal weekly counts: point-estimate step comparisons, no p-values or SE.
x[,week:=fecha-as.integer(format(fecha,'%u'))+1L]
wx<-aggregate_counts(x,'week');setnames(wx,'tt','week')
cal<-data.table(fecha=seq(as.Date('2021-01-01'),as.Date('2024-08-31'),by='day'))
cal[,week:=fecha-as.integer(format(fecha,'%u'))+1L]
cal[,`:=`(inaug=as.numeric(fecha>=as.Date('2022-12-21')),pico_step=as.numeric(fecha>=as.Date('2023-04-10')),
 tests=as.numeric(fecha>=as.Date('2023-05-02')&fecha<=as.Date('2023-05-11')),
 ration=as.numeric(fecha>=as.Date('2023-10-27')&fecha<=as.Date('2023-12-15')),
 opening=as.numeric(fecha>=as.Date('2023-12-01')),
 curfew=as.numeric(fecha>=as.Date('2024-01-08')&fecha<=as.Date('2024-04-06')),
 c1=as.numeric(fecha>=as.Date('2024-01-23')&fecha<=as.Date('2024-04-06')),
 c2=as.numeric(fecha>=as.Date('2024-03-21')&fecha<=as.Date('2024-04-06')))]
wcal<-cal[,lapply(.SD,mean),by=week,.SDcols=c('inaug','pico_step','tests','ration','opening','curfew','c1','c2')]
steps<-list(); fits<-list()
for(oc in outcomes){
 p<-merge(wx[unit%in%c('corridor_0_600','distant_parishes')],wcal,by='week')
 p[,treated:=as.numeric(unit=='corridor_0_600')]
 terms<-c('inaug','pico_step','tests','ration','opening','curfew','c1','c2')
 for(nm in terms)p[,(paste0('t_',nm)):=treated*get(nm)]
 f<-fepois(as.formula(paste(oc,'~',paste(paste0('t_',terms),collapse='+'),'|unit+week')),p,notes=FALSE,warn=FALSE)
 cf<-coef(f);steps[[oc]]<-data.table(outcome=oc,event=sub('t_','',names(cf)),ratio_change_pct=5*round(100*expm1(cf)/5),scope='exploratory simultaneous weekly step/pulse point estimates; no inference')
 p[,pred:=as.numeric(predict(f,newdata=p,type='response'))]
 fits[[oc]]<-dcast(p,week~unit,value.var='pred')[,.(week,outcome=oc,ratio=corridor_0_600/distant_parishes)]
}
fwrite(rbindlist(steps),file.path(O,'event_step_estimates.csv'))
fitseries<-rbindlist(fits);fitseries[,ratio:=.005*round(ratio/.005)]
fwrite(fitseries,file.path(O,'step_fitted_ratios.csv'))
# Quarterly ring event study: opening-aligned three-month blocks, Sep-Nov23 reference.
# Remaining-pico coefficient relies on within-quarter April transition variation.
cal[,month:=as.Date(format(fecha,'%Y-%m-01'))]
mcal<-cal[,lapply(.SD,mean),by=month,.SDcols='pico_step']
qidx<-function(m){yr<-as.integer(format(m,'%Y'));mo<-as.integer(format(m,'%m'));floor(((yr-2023)*12+mo-12)/3)}
a[,q:=qidx(month)]
expo<-x[fecha<as.Date('2023-12-01'),.(pico_exposure=mean(pico)),by=unit]
# Drop whole Monday-Sunday weeks intersecting the dated rationing interval.
y<-x[!week%in%seq(as.Date('2023-10-23'),as.Date('2023-12-11'),by='week')]
b<-aggregate_counts(y,'month');setnames(b,'tt','month');b[,q:=qidx(month)]
keptcal<-cal[!week%in%seq(as.Date('2023-10-23'),as.Date('2023-12-11'),by='week')]
kdays<-keptcal[,.N,by=month];setnames(kdays,'N','days')
es<-list();diagnostics<-list()
for(r in A2_RINGS)for(oc in outcomes)for(adjust in c(FALSE,TRUE)){
 p<-copy(if(adjust)b else a)[unit%in%c(r,'distant_parishes')]
 p<-merge(p,if(adjust)keptcal[,.(pico_step=mean(pico_step)),by=month]else mcal,by='month')
 p<-merge(p,expo,by='unit');p[,treated:=as.integer(unit==r)]
 p[,pico_control:=pico_exposure*pico_step]
 if(adjust){p<-merge(p,kdays,by='month');p[,ln_days:=log(days)]}else p[,ln_days:=0]
 form<-as.formula(paste(oc,'~i(q,treated,ref=-1)',if(adjust)'+pico_control'else'','|unit+month'))
 f<-fepois(form,p,offset=~ln_days,notes=FALSE,warn=FALSE)
 cf<-coef(f);ix<-grepl('^q::',names(cf));qq<-as.integer(sub('q::(-?[0-9]+):.*','\\1',names(cf)[ix]))
 z<-data.table(unit=r,outcome=oc,adjusted=adjust,q=qq,index=5*round(100*exp(cf[ix])/5))
 z<-rbind(z,data.table(unit=r,outcome=oc,adjusted=adjust,q=-1L,index=100))
 # Quarter-level count support; sparse models/cells are withheld, not displayed.
 support<-p[,.(n=sum(get(oc)),other=sum(all_crashes-get(oc))),by=.(unit,q)]
 bad<-support[small_a2(n)|small_a2(other),unique(q)]
 z[q%in%bad,index:=NA_real_]
 es[[paste(r,oc,adjust)]]<-z
 diagnostics[[paste(r,oc,adjust)]]<-z[q<0 & q!=-1,.(unit=r,outcome=oc,adjusted=adjust,pre_lead_rms_index=sqrt(mean((index-100)^2,na.rm=TRUE)),pre_lead_range_index=diff(range(index,na.rm=TRUE)))]
}
es<-rbindlist(es)
# Month arithmetic without package dependencies.
es[,date:=as.Date(sprintf('%04d-%02d-01',2023+(11+3*q)%/%12,(11+3*q)%%12+1))]
es[,model:=ifelse(adjusted,'Pico step + rationing weeks omitted','Unit and month FE only')]
fwrite(es,file.path(O,'quarterly_event_study.csv'));fwrite(rbindlist(diagnostics),file.path(O,'lead_shape_diagnostics.csv'))
saveplot(mark(ggplot(es,aes(date,index,colour=model))+geom_hline(yintercept=100,colour='grey60')+geom_line()+geom_point(size=.8)+facet_grid(unit~outcome,scales='free_y')+scale_x_date(date_breaks='1 year',date_labels='%Y')+labs(title='EXPLORATORY: quarterly PPML shapes against distant parishes',x=NULL,y='Relative count index (Sep-Nov 2023 = 100)',colour=NULL,caption=paste(cap,'\nNo standard errors/CIs. Blocks align to December opening; first/last blocks partial. Rationing omissions also alter the reference block.'))+style),'quarterly_event_study',h=10)
# Save exact structures only in ignored local intermediates.
saveRDS(list(crashes=d,members=mem,monthly=a,weekly=wx),file.path(D,'exploratory_build.rds'))
fwrite(data.table(check=c('maximum observed month August2024','only39distantparishes','all released positive counts at least5','no inference columns'),passed=c(max(d$fecha)<as.Date('2024-09-01'),sum(par$distant)==39,all(long$count[!is.na(long$count)]==0|long$count[!is.na(long$count)]>=5),TRUE)),file.path(O,'checks.csv'))
cat('Exploratory series, step fits, PPML shapes and plots completed; no simulations or inference.\n')
