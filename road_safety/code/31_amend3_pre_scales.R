# Stage A pre-only scale/estimability checks. No post placebo estimates or tests.
source('code/amend2_helpers.R');suppressPackageStartupMessages(library(fixest))
data.table::setDTthreads(1);setFixest_nthreads(1)
D<-'data/derived/amendment3';O<-'output/amendment3_stage_a'
a<-readRDS(file.path(D,'stage_a_build.rds'));d<-copy(a$crashes)[fecha>=as.Date('2022-01-01')]
registry<-copy(a$registry);freq<-fread(file.path(O,'main_frequency_choice.csv'))$frequency[1]
cal<-seq(as.Date('2022-01-01'),as.Date('2023-10-31'),by='day')
if(freq=='monthly')cal<-unique(as.Date(format(cal,'%Y-%m-01')))
d[,time:=if(freq=='monthly')month else fecha]
remote<-a$parishes[a$parishes$distant,]
counts<-d[parish%in%remote$code,.(H1=sum(H1),H2=sum(H2)),by=.(parish,time)]
base<-merge(CJ(parish=remote$code,time=cal),counts,by=c('parish','time'),all.x=TRUE)
for(nm in c('H1','H2'))base[is.na(get(nm)),(nm):=0L]
longrun<-function(g,L){g<-g-mean(g);n<-length(g);v<-sum(g*g)/n;for(k in seq_len(min(L,n-1)))v<-v+2*(1-k/(L+1))*sum(g[(k+1):n]*g[1:(n-k)])/n;max(v,0)}
scales<-list();H2pre_eligible<-registry$eligible_H2
for(j in which(registry$eligible_H1))for(h in c('H1','H2')){
 members<-as.integer(strsplit(registry$members[j],';')[[1]])
 p<-copy(base);p[,unit:=ifelse(parish%in%members,registry$id[j],paste0('parish_',parish))]
 p<-p[,.(H1=sum(H1),H2=sum(H2)),by=.(unit,time)]
 p[,`:=`(qoy=as.integer((as.integer(format(time,'%m'))-1)%/%3+1L),dow=as.integer(format(time,'%u')),group=ifelse(unit==registry$id[j],'Pseudo','Other'))]
 if(freq=='daily'){
  composite<-st_union(a$parishes[a$parishes$code%in%members,]);rep<-st_centroid(composite)
  mon<-st_transform(st_read('../air_quality/data/for_maps/Distancia_REMMAQ_Metro.gpkg',quiet=TRUE),CRS_UTM)
  mon$nm<-norm_a2(mon$Station);mon$nm[mon$nm=='SAN ANTONIO DE PICHINCHA']<-'SAN ANTONIO'
  avail<-unique(a$weather$station);mon<-mon[mon$nm%in%norm_a2(avail),]
  gauge<-unname(setNames(avail,norm_a2(avail))[mon$nm[st_nearest_feature(rep,mon)]])
  assign<-a$weather_assignment[unit%in%p$unit];assign<-rbind(assign,data.table(unit=registry$id[j],rain_station=gauge))
  p<-merge(p,assign,by='unit');p<-merge(p,a$weather[,.(rain_station=station,time=date,rain,missing_rain)],by=c('rain_station','time'))
  form<-as.formula(paste(h,'~rain+missing_rain|unit+time+group^qoy+unit^dow'))
 }else form<-as.formula(paste(h,'~1|unit+time+group^qoy'))
 f<-tryCatch(fepois(form,p,notes=FALSE,warn=FALSE),error=function(e)e)
 err<-'';scale<-NA_real_
 if(inherits(f,'error'))err<-conditionMessage(f)else{
  used<-obs(f);omit<-setdiff(seq_len(nrow(p)),used)
  if(any(p[[h]][omit]!=0))err<-'omitted positive-count training row'else{
   p[,mu:=0];p[used,mu:=as.numeric(f$fitted.values)]
   z<-p[,.(y=sum(get(h)),mu=sum(mu)),by=.(time,pseudo=unit==registry$id[j])]
   z<-dcast(z,time~pseudo,value.var=c('y','mu'))
   m1<-mean(z$mu_TRUE);m0<-mean(z$mu_FALSE)
   if(!is.finite(m1)||m1<=0||m0<=0)err<-'zero pre-period fitted mean'else{
    gap<-(z$y_TRUE-z$mu_TRUE)/m1-(z$y_FALSE-z$mu_FALSE)/m0
    scale<-sqrt(longrun(gap,if(freq=='daily')90L else 3L))
    if(!is.finite(scale)||scale<=0)err<-'zero/nonfinite pre-period residual scale'
   }
  }
 }
 scales[[paste(j,h)]]<-data.table(id=registry$id[j],hypothesis=h,frequency=freq,pre_scale=scale,finite_fit=err=='',diagnostic=err)
}
z<-rbindlist(scales);fwrite(z[,.(id,hypothesis,frequency,finite_fit,diagnostic)],file.path(O,'pre_placebo_scales.csv')) # Exact scales remain private local inputs.
for(h in c('H1','H2')){
 ok<-z[hypothesis==h & finite_fit,id]
 registry[,(paste0('eligible_',h)):=get(paste0('eligible_',h)) & id%in%ok]
}
fwrite(registry,file.path(O,'placebo_registry.csv'))
floors<-rbindlist(lapply(c('H1','H2'),function(h){k<-sum(registry[[paste0('eligible_',h)]]);data.table(hypothesis=h,eligible_placebos=k,raw_floor=1/(k+1),minimum_first_Holm_p=min(1,2/(k+1)),five_percent_family_rejection_attainable=k>=39)}))
floors[,minimum_joint_Holm_p:=p.adjust(raw_floor,method='holm')];fwrite(floors,file.path(O,'rank_floors.csv'))
actual<-readRDS(file.path(D,paste0('pre_fit_',freq,'_2022.rds')))$panel
form<-if(freq=='monthly')H2~1|unit+date+group^qoy else H2~rain+missing_rain|unit+date+group^qoy+unit^dow
f<-fepois(form,actual,notes=FALSE,warn=FALSE);used<-obs(f);omit<-setdiff(seq_len(nrow(actual)),used);stopifnot(all(actual$H2[omit]==0))
actual[,mu:=0];actual[used,mu:=as.numeric(f$fitted.values)]
g<-actual[,.(y=sum(H2),mu=sum(mu)),by=.(date,treated)]
g<-dcast(g,date~treated,value.var=c('y','mu'));m1<-mean(g$mu_TRUE);m0<-mean(g$mu_FALSE);stopifnot(m1>0,m0>0)
g[,gap:=(y_TRUE-mu_TRUE)/m1-(y_FALSE-mu_FALSE)/m0]
a$H2_pre_scale<-sqrt(longrun(g$gap,if(freq=='daily')90L else 3L));stopifnot(a$H2_pre_scale>0)
a$registry<-registry;a$scales<-z;saveRDS(a,file.path(D,'stage_a_build.rds'))
cat('Pre-period model scales and outcome-specific eligibility fixed; no post effects or rank tests computed.\n')
