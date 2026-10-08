# Additional pre-period validation: involved-private-vehicle share and adjusted
# PPML quarterly leads. Sources function definitions only, never 15's execution.
lines<-readLines("code/15_amend2_forecasts.R")
eval(parse(text=lines[seq_len(grep("^paths<-list",lines)-1L)]))

share_panel<-function(us,mm,train) {
  p<-CJ(unit=us,month=mm)
  a<-x[unit %in% us & month %in% mm]
  nv<-a[,.(y=sum(n_private),exposure=sum(n_vehicle)),by=.(unit,month)]
  p<-merge(p,nv,by=c("unit","month"),all.x=TRUE)
  setnafill(p,fill=0,cols=c("y","exposure"))
  p[,cell:="aggregate_involved_vehicle_share"]
  p
}
share_q<-function(p) {
  # Same corrected ASCM adjustment as the count series; retain seasonality.
  p[,control_factor:=control_no_season]
  stopifnot(all(is.finite(p$control_factor)),all(p$control_factor>0))
  p[,quarter:=quarter_start(month)]
  q<-p[,.(actual=sum(y),den=sum(exposure),factor=if(sum(exposure)>0) sum(exposure*control_factor)/sum(exposure) else mean(control_factor)),by=.(unit,quarter)]
  # Explicit Beta(1/2,1/2) pseudo-count smoothing of the quarterly share for
  # ASCM fitting only. An unobserved share is NOT reported as observed 0 or 1.
  q[,`:=`(value=(actual+.5)/(den+1)/factor,expected=den*factor)]
  q
}
families<-c(list(rings=A2_RINGS),setNames(lapply(setdiff(A2_TARGETS,c(A2_RINGS,"corridor_0_600")),function(u)u),setdiff(A2_TARGETS,c(A2_RINGS,"corridor_0_600"))))
sp<-list();err<-list()
for(st in c(2022L,2021L)) for(fi in seq_along(FOLDS)) for(fam in names(families)) {
  ts<-families[[fam]];us<-c(ts,donors);hs<-FOLDS[fi]
  tr<-A2_MONTHS[A2_MONTHS>=as.Date(paste0(st,"-01-01")) & A2_MONTHS<hs];ho<-seq(hs,by="month",length.out=3)
  p<-share_panel(us,c(tr,ho),tr)
  pp<-tryCatch(ppml_fold(copy(p),tr,ho,ts),error=function(e)e)
  if(inherits(pp,"error")) {err[[length(err)+1]]<-data.table(start=st,fold=format(hs),family=fam,message=conditionMessage(pp));next}
  adj<-attr(pp,"adjusted_panel")
  q<-share_q(copy(adj));tq<-sort(unique(q[quarter<hs,quarter]))
  ih<-tail(tq,1);itr<-tr[quarter_start(tr)<ih]
  ip<-tryCatch(ppml_fold(share_panel(us,tr,itr),itr,setdiff(tr,itr),ts),error=function(e)e)
  if(inherits(ip,"error")) {err[[length(err)+1]]<-data.table(start=st,fold=format(hs),family=fam,message=conditionMessage(ip));next}
  iq<-share_q(copy(attr(ip,"adjusted_panel")))
  pr<-predictors(us,tr);ipr<-predictors(us,itr)
  scale<-p[unit %in% ts & month %in% itr,.(scale=sum(y)/sum(exposure)),by=unit]
  den<-p[,.(den=sum(exposure)),by=.(unit,quarter=quarter_start(month))]
  losses<-vapply(LAMBDA,function(lam) {
    z<-tryCatch(asc_fold(iq,sort(unique(iq[quarter<ih,quarter])),ih,ts,ipr,lam,length(ts)>1),error=function(e)NULL)
    if(is.null(z))return(Inf)
    z<-merge(merge(z[quarter==ih],den,by=c("unit","quarter")),scale,by="unit")
    mean(((z$actual-z$prediction)/z$den/pmax(z$scale,.01))^2)
  },0)
  if(!any(is.finite(losses))) {err[[length(err)+1]]<-data.table(start=st,fold=format(hs),family=fam,message="No finite ASCM inner share fit");next}
  lam<-max(LAMBDA[losses<=min(losses)*1.05+1e-12])
  aa<-asc_fold(q,tq,hs,ts,pr,lam,length(ts)>1)
  pp[,quarter:=quarter_start(month)];pp<-pp[,.(actual=sum(actual),prediction=sum(prediction)),by=.(unit,quarter)]
  scale<-p[unit %in% ts & month %in% tr,.(scale=sum(y)/sum(exposure)),by=unit]
  for(method in c("PPML","ASCM")) {
    z<-if(method=="PPML")pp else aa
    z<-merge(merge(z[quarter==hs],den,by=c("unit","quarter")),scale,by="unit")
    z[,`:=`(start=st,fold=format(hs),method=method)]
    sp[[length(sp)+1]]<-z
  }
  # Share benchmarks: donor pooled share and equal parish regularized shares,
  # scaled to the treated pre share. Undefined zero-exposure shares never zero-filled.
  ym<-p[,.(num=sum(y),den=sum(exposure)),by=.(unit,month)]
  trainshare<-ym[month %in% tr,.(baseline=sum(num)/sum(den)),by=unit]
  dd<-merge(ym[unit %in% donors],trainshare,by="unit")
  bench<-dd[,.(pooled=sum(num)/sum(den),equal=mean((num+.5)/(den+1))),by=month]
  for(method in c("pooled","equal")) {
    base<-bench[month %in% tr,mean(get(method))]
    z<-merge(merge(ym[unit %in% ts],trainshare,by="unit"),bench,by="month")
    z[,`:=`(prediction=den*baseline*get(method)/base,quarter=quarter_start(month))]
    z<-z[quarter==hs,.(actual=sum(num),prediction=sum(prediction),den=sum(den)),by=.(unit,quarter)]
    z<-merge(z,scale,by="unit");z[,`:=`(start=st,fold=format(hs),method=method)]
    sp[[length(sp)+1]]<-z
  }
}
sp<-rbindlist(sp,fill=TRUE)
cr<-sp[unit %in% A2_RINGS[1:2],.(actual=sum(actual),prediction=sum(prediction),den=sum(den)),by=.(quarter,start,fold,method)]
cr[,`:=`(unit="corridor_0_600",scale=NA_real_)]
# Corridor share is ratio of summed vehicle counts, never an average of ring shares.
for(st in c(2021L,2022L)) for(fi in seq_along(FOLDS)) {
  hs<-FOLDS[fi]
  baseline<-b$outcomes[unit=="corridor_0_600" & month>=as.Date(paste0(st,"-01-01")) & month<hs,sum(private_vehicles)/sum(all_vehicles)]
  cr[start==st & fold==format(hs),scale:=baseline]
}
sp<-rbind(sp,cr,fill=TRUE)
stopifnot(all(sp$den>0),all(is.finite(sp$scale)))
saveRDS(sp,file.path(A2_DATA,"share_forecast_paths.rds"))
loss<-sp[,.(normalized_rmse=sqrt(mean(((actual-prediction)/den/pmax(scale,.01))^2)),
  share_rmse_pp=100*sqrt(mean(((actual-prediction)/den)^2)),folds=.N,
  predictions_outside_unit_interval=any(prediction<0|prediction>den)),by=.(start,unit,method)]
ss<-dcast(loss[method %in% c("PPML","ASCM") & folds==length(FOLDS)],start+unit~method,value.var="normalized_rmse")
ss<-merge(CJ(start=c(2021L,2022L),unit=A2_TARGETS),ss,by=c("start","unit"),all.x=TRUE)
ss[,winner:=ifelse(is.na(ASCM)|is.na(PPML),"unresolved",ifelse(ASCM<=PPML,"ASCM","PPML"))]
for(st in c(2021L,2022L)) {
  joint<-sp[start==st & unit %in% A2_RINGS & method %in% c("ASCM","PPML"),.(mse=mean(((actual-prediction)/den/pmax(scale,.01))^2)),by=method]
  complete<-loss[start==st & unit %in% A2_RINGS & method %in% c("ASCM","PPML") & folds==length(FOLDS),.N]==2L*length(A2_RINGS)
  ss[start==st & unit %in% c(A2_RINGS,"corridor_0_600"),winner:=if(complete) {
    if(joint[method=="ASCM",mse]<=joint[method=="PPML",mse]) "ASCM (joint rings)" else "PPML (joint rings)"
  } else "unresolved"]
}
ss[,`:=`(ASCM=round(ASCM,4),PPML=round(PPML,4),status="provisional; ASCM quarterly Beta-half share smoothing; complete road/population predictors; event inputs unresolved")]
save_csv(ss,file.path(A2_OUT,"share_headline_selection.csv"))
save_csv(copy(loss)[,`:=`(normalized_rmse=round(normalized_rmse,4),share_rmse_pp=round(share_rmse_pp,2))],file.path(A2_OUT,"share_forecast_comparison.csv"))
save_csv(if(length(err)) rbindlist(err) else data.table(start=integer(),fold=character(),family=character(),message=character()),file.path(A2_OUT,"share_forecast_failures.csv"))

# Adjusted pre-period event-study diagnostic. Freeze the full-pre nuisance factors,
# then fit unit/cell, month/cell and treated opening-quarter fixed effects.
# Seasonality is thus a first-stage pre-only estimate; no standard errors claimed.
lead<-list();lead_errors<-list()
for(st in c(2022L,2021L)) for(oc in MODEL_OUTCOMES) for(fam in names(families)) {
  ts<-families[[fam]];us<-c(ts,donors);tr<-A2_MONTHS[A2_MONTHS>=as.Date(paste0(st,"-01-01"))]
  p<-make_panel(oc,us,tr,tr);pf<-ppml_fold(p,tr,as.Date(character()),ts)
  z<-attr(pf,"adjusted_panel")
  z[,`:=`(uc=paste(unit,cell),mc=paste(month,cell),quarter=quarter_start(month))]
  z[,zq:=ifelse(unit %in% ts,paste(unit,quarter),"donor")]
  for(adjustment in c("full_pre_seasonality","no_treated_seasonality")) {
  z[,offset_factor:=if(adjustment=="full_pre_seasonality")control_factor else control_no_season]
  if(any(!is.finite(z$offset_factor)|z$offset_factor<=0)) {
    lead_errors[[length(lead_errors)+1]]<-data.table(start=st,outcome=oc,family=fam,adjustment=adjustment,
      message="Undefined nuisance offset; complete family diagnostic withheld, no rows dropped or zero-filled")
    next
  }
  f<-fixest::fepois(y~1|uc+mc+zq,data=z,offset=~log(offset_factor),fixef.rm="infinite_coef",warn=FALSE)
  fe<-fixest::fixef(f)
  z[,fit_current:=exp(fe$uc[uc]+fe$mc[mc]+fe$zq[zq])*offset_factor]
  z[,fit_reference:=exp(fe$uc[uc]+fe$mc[mc]+fe$zq[paste(unit,as.Date("2023-09-01"))])*offset_factor]
  z[is.na(fit_current),fit_current:=0];z[is.na(fit_reference),fit_reference:=0]
  for(u in c(ts,if(fam=="rings") "corridor_0_600" else character())) {
    members<-if(u=="corridor_0_600")A2_RINGS[1:2] else u
    qfit<-z[unit %in% members,.(current=sum(fit_current),reference=sum(fit_reference),nmonths=uniqueN(month)),by=quarter][order(quarter)]
    qs<-qfit$quarter;lg<-log(qfit$current/qfit$reference)
    # Joint disclosure guard for relevant outcomes and their complements.
    safe<-b$outcomes[unit==u & month %in% tr,
      .(all=sum(all_crashes),private=sum(private_car_crashes),injury=sum(injury_fatal)),by=.(quarter=quarter_start(month))]
    safe<-safe[,all(all>=5 & !small_a2(private) & !small_a2(all-private) & !small_a2(injury) & !small_a2(all-injury))]
    if(safe) lead[[length(lead)+1]]<-data.table(start=st,outcome=oc,unit=u,quarter=qs,nmonths=qfit$nmonths,
      partial_quarter=qfit$nmonths<3,adjustment=adjustment,
      log_lead=round(lg,4),lead_pct=round(100*expm1(lg),1),
      status="pre-period adjusted PPML diagnostic; frozen first-stage seasonality; no standard errors")
  }
  }
}
save_csv(if(length(lead_errors))rbindlist(lead_errors)else data.table(start=integer(),outcome=character(),family=character(),adjustment=character(),message=character()),file.path(A2_OUT,"adjusted_lead_failures.csv"))
lead<-guard_ring_paths(rbindlist(lead),c("start","outcome","adjustment"))
save_csv(lead,file.path(A2_OUT,"adjusted_preperiod_leads.csv"))
flat<-lead[,.(early_change=log_lead[quarter==as.Date("2023-06-01")]-log_lead[quarter==as.Date("2023-03-01")],
  late_change=log_lead[quarter==as.Date("2023-09-01")]-log_lead[quarter==as.Date("2023-06-01")]),by=.(start,outcome,unit,adjustment)]
flat[,flattens_2023:=abs(late_change)<abs(early_change)]
save_csv(flat,file.path(A2_OUT,"adjusted_drift_flattening.csv"))
cat("Private-share forecasts and adjusted pre-period PPML leads completed.\n")
