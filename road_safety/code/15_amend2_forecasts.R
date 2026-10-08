# Forward validation only, never post-opening outcomes. Four methods on identical
# opening-aligned held-out quarters. Exact paths remain ignored, only loss ratios
# and protected diagnostics are exported. Event-calendar and inference qualifications remain explicit.
source("code/amend2_helpers.R")
suppressPackageStartupMessages(library(augsynth))
options(fixest_notes=FALSE)
fixest::setFixest_nthreads(1)
b<-readRDS(file.path(A2_DATA,"build.rds")); cc<-readRDS(file.path(A2_DATA,"controls.rds"))
donors<-b$units[family=="donor",unit]
targets<-A2_TARGETS
d<-b$crashes; assert_pre(d)
x<-cbind(b$members,d[b$members$idx]);x[,count:=1]
gp<-readRDS(file.path(A2_DATA,"geographic_predictors.rds"))
SIM_TREND<-FALSE
MODEL_OUTCOMES<-c("all_crashes","private_car_crashes","injury_fatal")
FOLDS<-as.Date(c("2023-03-01","2023-06-01","2023-09-01"))
LAMBDA<-c(.01,.1,1,10)

make_panel<-function(oc,us,mm,train=mm) {
  a<-x[unit %in% us & month %in% mm]
  if(oc=="private_car_crashes") a<-a[private==TRUE]
  if(oc=="injury_fatal") a<-a[severity=="injury_fatal"]
  # A treated type/severity/road cell with a positive count below five in a
  # complete TRAINING quarter triggers global road collapse for that fold.
  at<-a[month %in% train & !unit %in% donors]
  at[,quarter:=quarter_start(month)]
  full<-as.Date(names(which(table(quarter_start(train))==3)))
  sparse<-at[quarter %in% full,.(N=sum(count)),by=.(unit,group,severity,road_type,quarter)][,any(N>0 & N<5)]
  a[,cell:=if(sparse) paste(group,severity,sep="__") else paste(group,severity,road_type,sep="__")]
  cellnames<-if(oc=="injury_fatal") paste(c("vehicle_vehicle","pedestrian","single_vehicle","other"),"injury_fatal",sep="__") else
    as.vector(outer(c("vehicle_vehicle","pedestrian","single_vehicle","other"),c("injury_fatal","damage"),paste,sep="__"))
  if(!sparse) cellnames<-as.vector(outer(cellnames,c("city","fast"),paste,sep="__"))
  p<-merge(CJ(unit=us,cell=cellnames,month=mm),a[,.(y=sum(count)),by=.(unit,cell,month)],by=c("unit","cell","month"),all.x=TRUE)
  p[is.na(y),y:=0]
  setattr(p,"road_collapsed",sparse)
  p
}

controls_fold<-function(p,train) {
  z<-copy(cc$controls[unit %in% unique(p$unit) & month %in% unique(p$month)])
  # Fold-specific exposure shares; zero-crash units get the donor pooled share,
  # explicitly a nuisance fallback, not a volume screen.
  sh<-x[month %in% train & unit %in% unique(p$unit),.(wshare=weighted.mean(weekend,count)),by=unit]
  pool<-x[month %in% train & unit %in% donors,.(wshare=weighted.mean(weekend,count))]
  z<-merge(z,sh,by="unit",all.x=TRUE)
  z[is.na(wshare),wshare:=pool$wshare]
  z[,`:=`(rain=ifelse(coverage>=.9,observed_mm/coverage,NA_real_),
           wet=ifelse(complete_days/days>=.9,observed_rain_days/(complete_days/days),NA_real_))]
  for(nm in c("rain","wet")) {
    z[,(paste0(nm,"_missing")):=as.integer(is.na(get(nm)))]
    av<-z[month %in% train,mean(get(nm),na.rm=TRUE)]
    z[is.na(get(nm)),(nm):=av]
  }
  # Rain standardization is training-only.
  for(nm in c("rain","wet")) {
    mu<-z[month %in% train,mean(get(nm))];ss<-z[month %in% train,sd(get(nm))]
    if(!is.finite(ss)||ss==0) ss<-1
    z[,(nm):=(get(nm)-mu)/ss]
  }
  z[,`:=`(weekend_control=wshare*weekend_days,holiday_control=wshare*holiday_days,
    pico_control=pico_share*fifelse(month<as.Date("2023-04-01"),0,fifelse(month==as.Date("2023-04-01"),21/30,1)))]
  z[,.(unit,month,rain,wet,rain_missing,wet_missing,weekend_control,holiday_control,pico_control)]
}

ppml_fold<-function(p,train,hold,ts) {
  if(!"exposure" %in% names(p)) p[,exposure:=1]
  p<-merge(p,controls_fold(p,train),by=c("unit","month"))
  p[,`:=`(uc=paste(unit,cell),mc=paste(month,cell),
    tq=ifelse(unit %in% ts,paste(unit,(as.integer(format(month,"%m"))-1)%/%3+1),"donor"))]
  vars<-c("rain","wet","rain_missing","wet_missing","weekend_control","holiday_control","pico_control")
  if(SIM_TREND) {
    tt<-as.numeric(p$month-min(train))/365.25
    for(j in seq_along(ts)) {nm<-paste0("trend_",j);p[,(nm):=as.numeric(unit==ts[j])*tt];vars<-c(vars,nm)}
  }
  f<-fixest::fepois(as.formula(paste("y~",paste(vars,collapse="+"),"|uc+mc+tq")),data=p[month %in% train & exposure>0],offset=~log(exposure),warn=FALSE,fixef.rm="infinite_coef",notes=FALSE)
  fe<-fixest::fixef(f);co<-coef(f)
  seasonal<-unname(fe$tq[p$tq])
  absent<-unique(p$tq[is.na(seasonal)])
  # A removed all-zero seasonal FE has the proved Poisson mean-zero limit.
  # An unobserved season or a missing positive-count level is not that boundary.
  support<-p[month %in% train & exposure>0,.(observations=.N,total=sum(y)),by=tq]
  if(length(absent)) {
    ss<-support[match(absent,tq)]
    stopifnot(!anyNA(ss),all(ss$observations>0),all(ss$total==0))
    seasonal[is.na(seasonal)]<--Inf
  }
  linear<-rep(0,nrow(p))
  if(length(co)) linear<-as.numeric(as.matrix(p[,..vars][,names(co),with=FALSE])%*%co)
  stopifnot(all(is.finite(linear)))
  p[,`:=`(nuisance=seasonal+linear,nuisance_no_season=linear,
           seasonal_boundary=tq %in% absent)]
  # The full seasonal factor is retained only for the descriptive lead exercise.
  # Its zero-season boundary is explicitly undefined, never given a finite floor.
  center<-p[month %in% train,.(center=if(all(is.finite(nuisance)))mean(nuisance)else NA_real_),by=unit]
  p<-merge(p,center,by="unit",sort=FALSE)
  # Restore alignment of fixed-effect predictors after the merge.
  p[,mu_base:=exp(fe$uc[uc]+nuisance)*exposure]
  p[,control_factor:=exp(nuisance-center)]
  nscenter<-p[month %in% train,.(nscenter=mean(nuisance_no_season)),by=unit]
  p<-merge(p,nscenter,by="unit",sort=FALSE)
  p[,control_no_season:=exp(nuisance_no_season-nscenter)]
  stopifnot(all(is.finite(p$control_no_season)),all(p$control_no_season>0))
  # A separated all-zero training unit/cell has limiting prediction zero;
  # retain its rows and parish membership, do not volume-screen it away.
  zero<-p[month %in% train,.(train_total=sum(y)),by=uc]
  p<-merge(p,zero,by="uc")
  p[train_total==0,mu_base:=0]
  p[seasonal_boundary==TRUE,mu_base:=0]
  p[exposure==0,mu_base:=0]
  stopifnot(!anyNA(p$mu_base),all(is.finite(p$mu_base)))
  shock<-p[unit %in% donors,.(den=sum(mu_base),num=sum(y)),by=.(month,cell)]
  shock[,shock:=ifelse(den>0,num/den,0)]
  p<-merge(p,shock[,.(month,cell,shock)],by=c("month","cell"))
  p[,prediction:=mu_base*shock]
  out<-p[unit %in% ts,.(actual=sum(y),prediction=sum(prediction)),by=.(unit,month)]
  setattr(out,"fitted_panel",p[,.(unit,cell,month,y,prediction)])
  setattr(out,"base_panel",p[,.(unit,cell,month,mu_base,shock)])
  setattr(out,"adjusted_panel",p[,.(unit,cell,month,y,control_factor,control_no_season,exposure,seasonal_boundary)])
  out
}

composition<-function(p,train) {
  # Fixed unit/cell baseline times comparator-only cell/month rate indices.
  # Each donor's rate denominator excludes itself; fixed numerical regularization
  # keeps zero-training cells finite. No donor parish is removed for volume.
  # Explicit corrected ASCM definition: remove finite X beta controls only.
  # Seasonal variation stays in the quarterly series. Dividing by a separated
  # treated-season factor would make the transformation undefined.
  stopifnot("control_no_season" %in% names(p))
  p[,control_factor:=control_no_season]
  stopifnot(all(is.finite(p$control_factor)),all(p$control_factor>0))
  p[,adjusted_y:=y/control_factor]
  if(!"exposure" %in% names(p)) p[,exposure:=1]
  base<-p[month %in% train,.(base=(sum(adjusted_y)+.5)/(sum(exposure)+.5)),by=.(unit,cell)]
  p<-merge(p,base,by=c("unit","cell"))
  p[,base_exposure:=base*exposure]
  city<-p[unit %in% donors,.(cy=sum(adjusted_y),cb=sum(base_exposure)),by=.(month,cell)]
  p<-merge(p,city,by=c("month","cell"))
  p[,rate:=(cy-ifelse(unit %in% donors,adjusted_y,0)+.5)/(cb-ifelse(unit %in% donors,base_exposure,0)+.5)]
  p[,expected:=base_exposure*rate*control_factor]
  p[,quarter:=quarter_start(month)]
  q<-p[,.(actual=sum(y),expected=sum(expected)),by=.(unit,quarter)]
  q[,value:=ifelse(expected>0,actual/expected,1)]
  q
}

predictors<-function(us,train) {
  # Crash composition and hour predictors are training-only; geography is fixed.
  a<-x[unit %in% us & month %in% train]
  z<-a[,.(vehshare=weighted.mean(group=="vehicle_vehicle",count),pedshare=weighted.mean(group=="pedestrian",count),
    singleshare=weighted.mean(group=="single_vehicle",count),injshare=weighted.mean(severity=="injury_fatal",count),
    peakshare=weighted.mean(peak,count,na.rm=TRUE),nightshare=weighted.mean(hour<6|hour>=23,count,na.rm=TRUE),picoshare=weighted.mean(pico,count)),by=unit]
  z<-merge(data.table(unit=us),z,by="unit",all.x=TRUE)
  for(nm in setdiff(names(z),"unit")) {
    v<-z[[nm]];v[!is.finite(v)]<-mean(v[is.finite(v)])
    z[,(nm):=v]
  }
  z<-merge(z,gp[,c("unit","population","population_density",grep("^road_km_",names(gp),value=TRUE)),with=FALSE],by="unit",all.x=TRUE)
  stopifnot(!anyNA(z))
  z
}

asc_fold<-function(q,trainq,holdq,ts,pred,lambda,multi=FALSE) {
  us<-c(ts,donors);q<-copy(q[unit %in% us & quarter %in% c(trainq,holdq)])
  ids<-setNames(seq_along(us),us)
  q[,`:=`(id=unname(ids[unit]),time=match(quarter,c(trainq,holdq)),trt=as.integer(unit %in% ts & quarter %in% holdq))]
  q<-merge(q,pred,by="unit",all.x=TRUE)
  covs<-setdiff(names(pred),"unit")
  covs<-covs[vapply(q[,..covs],function(v) sd(v)>1e-10,TRUE)]
  fm<-as.formula(paste("value~trt",if(length(covs)) paste("|",paste(covs,collapse="+")) else ""))
  if(multi) {
    f<-suppressMessages(multisynth(fm,id,time,as.data.frame(q),lambda=lambda,nu=.5,fixedeff=TRUE,scm=TRUE))
    # Reconstruct unit-specific counterfactuals from the package object; predict()
    # also adds an average column, which must not be mistaken for the first ring.
    cf<-sapply(seq_along(ts),function(j) {
      ui<-match(ids[[ts[j]]],f$data$units)
      if(is.list(f$y0hat)) as.numeric(f$y0hat[[j]][ui,]+crossprod(f$weights[,j],f$residuals[[j]])) else
        as.numeric(f$y0hat[ui,]+crossprod(f$weights[,j],f$residuals))
    })
    order_units<-f$data$units[is.finite(f$data$trt)]
    stopifnot(identical(as.integer(order_units),as.integer(ids[ts])))
  } else {
    f<-suppressMessages(augsynth(fm,id,time,as.data.frame(q),progfunc="Ridge",scm=TRUE,fixedeff=TRUE,lambda=lambda))
    cf<-matrix(as.numeric(predict(f)),ncol=1)
  }
  rbindlist(lapply(seq_along(ts),function(j) {
    z<-q[unit==ts[j]][order(time)]
    z[,.(unit,quarter,actual,expected,prediction=cf[,j]*expected)]
  }))
}

paths<-list();tunes<-list();errors<-list();sparsity<-list()
families<-c(list(rings=A2_RINGS),setNames(lapply(setdiff(targets,c(A2_RINGS,"corridor_0_600")),function(t)t),setdiff(targets,c(A2_RINGS,"corridor_0_600"))))
for(start in c(2022L,2021L)) for(oc in MODEL_OUTCOMES) for(fi in seq_along(FOLDS)) {
  hstart<-FOLDS[fi];train<-A2_MONTHS[A2_MONTHS>=as.Date(paste0(start,"-01-01")) & A2_MONTHS<hstart]
  hold<-seq(hstart,by="month",length.out=3)
  for(fam in names(families)) {
    ts<-families[[fam]];us<-c(ts,donors);p<-make_panel(oc,us,c(train,hold),train)
    sparsity[[length(sparsity)+1]]<-data.table(start,outcome=oc,fold=format(hstart),family=fam,road_collapsed=attr(p,"road_collapsed"))
    scale<-p[unit %in% ts & month %in% train,.(scale=sum(y)/length(train)*3),by=unit]
    pp<-tryCatch(ppml_fold(copy(p),train,hold,ts),error=function(e)e)
    if(inherits(pp,"error")) {
      errors[[length(errors)+1]]<-data.table(start,oc,fold=format(hstart),family=fam,method="PPML",message=conditionMessage(pp))
    } else {
      adjp<-attr(pp,"adjusted_panel")
      pp[,quarter:=quarter_start(month)]
      pp<-pp[,.(actual=sum(actual),prediction=sum(prediction)),by=.(unit,quarter)]
      pp[,method:="PPML"];paths[[length(paths)+1]]<-merge(pp,scale,by="unit")[,`:=`(start=start,outcome=oc,fold=format(hstart))]
    }
    if(inherits(pp,"error")) next # no unmatched-covariate comparison or silent fallback
    q<-composition(copy(adjp),train);tq<-sort(unique(q[quarter<hstart,quarter]));hq<-hstart
    pr<-predictors(us,train)
    # Inner forward quarter tunes ridge. Rebuild adjustment/predictors inside it.
    ih<-tail(tq,1);itrain<-train[quarter_start(train)<ih]
    ipp<-tryCatch(ppml_fold(make_panel(oc,us,train,itrain),itrain,setdiff(train,itrain),ts),error=function(e)e)
    if(inherits(ipp,"error")) {
      errors[[length(errors)+1]]<-data.table(start,oc,fold=format(hstart),family=fam,method="ASCM inner controls",message=conditionMessage(ipp))
      next
    }
    iq<-composition(copy(attr(ipp,"adjusted_panel")),itrain);ipr<-predictors(us,itrain)
    inner_scale<-p[unit %in% ts & month %in% itrain,.(scale=sum(y)/length(itrain)*3),by=unit]
    losses<-vapply(LAMBDA,function(lam) {
      fit<-tryCatch(asc_fold(iq,sort(unique(iq[quarter<ih,quarter])),ih,ts,ipr,lam,length(ts)>1),error=function(e)NULL)
      if(is.null(fit)) return(Inf)
      r<-merge(fit[quarter==ih],inner_scale,by="unit")
      mean(((r$actual-r$prediction)/pmax(r$scale,1))^2)
    },0)
    lam<-if(any(is.finite(losses))) max(LAMBDA[losses<=min(losses)*1.05+1e-12]) else NA_real_
    tunes[[length(tunes)+1]]<-data.table(start,outcome=oc,fold=format(hstart),family=fam,lambda=LAMBDA,inner_loss=losses,selected=LAMBDA %in% lam)
    aa<-if(is.finite(lam)) tryCatch(asc_fold(q,tq,hq,ts,pr,lam,length(ts)>1),error=function(e)e) else simpleError("No finite inner ASCM fit")
    if(inherits(aa,"error")) errors[[length(errors)+1]]<-data.table(start,oc,fold=format(hstart),family=fam,method="ASCM",message=conditionMessage(aa))
    else {
      aa[,method:="ASCM"];paths[[length(paths)+1]]<-merge(aa,scale,by="unit")[,`:=`(start=start,outcome=oc,fold=format(hstart))]
    }
    # Pooled and equal weights on raw counts normalized by fold training means.
    ym<-p[,.(y=sum(y)),by=.(unit,month)]
    base<-ym[month %in% train,.(mu=mean(y)),by=unit]
    ym<-merge(ym,base,by="unit")
    # 0.5-count regularization preserves every donor even with zero training volume.
    bench<-ym[unit %in% donors,.(pooled=sum(y)/sum(mu),equal=mean((y+.5)/(mu+.5))),by=month]
    for(meth in c("pooled","equal")) {
      zz<-merge(ym[unit %in% ts],bench,by="month")
      zz[,`:=`(prediction=mu*get(meth),quarter=quarter_start(month))]
      zz<-zz[,.(actual=sum(y),prediction=sum(prediction)),by=.(unit,quarter)]
      zz[,method:=meth];paths[[length(paths)+1]]<-merge(zz,scale,by="unit")[,`:=`(start=start,outcome=oc,fold=format(hstart))]
    }
  }
  cat("Completed forecast fold",start,oc,format(hstart),"\n")
}
paths<-rbindlist(paths,fill=TRUE)
corr<-paths[unit %in% A2_RINGS[1:2],.(actual=sum(actual),prediction=sum(prediction),scale=sum(scale)),by=.(quarter,method,start,outcome,fold)]
corr[,unit:="corridor_0_600"]
paths<-rbind(paths,corr,fill=TRUE);paths[,heldout:=quarter==as.Date(fold)]
saveRDS(paths,file.path(A2_DATA,"forecast_paths.rds"))
save_csv(rbindlist(tunes),file.path(A2_OUT,"penalty_tuning.csv"))
save_csv(rbindlist(sparsity),file.path(A2_OUT,"sparsity_decisions.csv"))
err<-if(length(errors)) rbindlist(errors) else data.table(start=integer(),oc=character(),fold=character(),family=character(),method=character(),message=character())
save_csv(err,file.path(A2_OUT,"forecast_failures.csv"))
loss<-paths[heldout==TRUE,.(normalized_rmse=sqrt(mean(((actual-prediction)/pmax(scale,1))^2)),folds=.N),by=.(start,outcome,unit,method)]
save_csv(copy(loss)[,normalized_rmse:=round(normalized_rmse,4)],file.path(A2_OUT,"forecast_comparison.csv"))
sel<-dcast(loss[method %in% c("PPML","ASCM") & folds==length(FOLDS)],start+outcome+unit~method,value.var="normalized_rmse")
sel<-merge(CJ(start=c(2021L,2022L),outcome=MODEL_OUTCOMES,unit=targets),sel,all.x=TRUE,by=c("start","outcome","unit"))
sel[,winner:=ifelse(is.na(ASCM)|is.na(PPML),"unresolved",ifelse(ASCM<=PPML,"ASCM","PPML"))]
# Joint ring selection, equal weight over normalized ring losses and held-out folds.
joint<-paths[heldout==TRUE & unit %in% A2_RINGS & method %in% c("PPML","ASCM"),
  .(mse=mean(((actual-prediction)/pmax(scale,1))^2)),by=.(start,outcome,method)]
for(st in c(2021L,2022L)) for(oc in MODEL_OUTCOMES) {
  j<-joint[start==st & outcome==oc]
  complete<-loss[start==st & outcome==oc & unit %in% A2_RINGS & method %in% c("ASCM","PPML") & folds==length(FOLDS),.N]==length(A2_RINGS)*2L
  if(complete && all(c("ASCM","PPML") %in% j$method)) sel[start==st & outcome==oc & unit %in% c(A2_RINGS,"corridor_0_600"),
    winner:=if(j[method=="ASCM",mse]<=j[method=="PPML",mse]) "ASCM (joint rings)" else "PPML (joint rings)"]
  else sel[start==st & outcome==oc & unit %in% c(A2_RINGS,"corridor_0_600"),winner:="unresolved"]
}
sel[,`:=`(ASCM=round(ASCM,4),PPML=round(PPML,4))]
sel[,status:="complete road/population predictors; enforcement/works unresolved; not approval to estimate"]
save_csv(sel,file.path(A2_OUT,"headline_selection.csv"))

# Descriptive quarterly leads of the raw gap against pooled distant parishes.
# No standard errors. These are drift diagnostics, not evidence of parallel trends.
dr<-list()
for(st in c(2022L,2021L)) for(oc in MODEL_OUTCOMES) {
  mm<-A2_MONTHS[A2_MONTHS>=as.Date(paste0(st,"-01-01"))]
  yy<-copy(b$outcomes[month %in% mm & unit %in% c(targets,donors)])
  yy[,value:=get(oc)]
  c0<-yy[unit %in% donors,.(c=sum(value)),by=month];c0[,c:=c/mean(c)]
  z<-merge(yy[unit %in% targets],c0,by="month")
  z[,idx:=value/mean(value),by=unit];z[,`:=`(gap=idx-c,quarter=quarter_start(month))]
  q<-z[,.(gap=mean(gap),nmonths=.N,total=sum(value)),by=.(unit,quarter)][nmonths==3]
  q[,lead:=gap-gap[quarter==as.Date("2023-09-01")],by=unit]
  q[,`:=`(start=st,outcome=oc)]
  # Withhold the whole unit/outcome path if any displayed quarter is sparse.
  complementary<-b$outcomes[month %in% mm & unit %in% targets,
    .(private=sum(private_car_crashes),nonprivate=sum(all_crashes-private_car_crashes),
      injury=sum(injury_fatal),damage=sum(all_crashes-injury_fatal)),by=.(unit,quarter=quarter_start(month))]
  safe_units<-complementary[,.(safe=all(!small_a2(private)&!small_a2(nonprivate)&!small_a2(injury)&!small_a2(damage))),by=unit][safe==TRUE,unit]
  q[,safe:=all(total>=5) & unit[1] %in% safe_units,by=unit]
  dr[[length(dr)+1]]<-q[safe==TRUE,.(start,outcome,unit,quarter,lead_pct=round(100*lead,1))]
}
dr<-guard_ring_paths(rbindlist(dr),c("start","outcome"))
save_csv(dr,file.path(A2_OUT,"preperiod_quarterly_leads.csv"))
flat<-dr[,.(early_2023_gap_change=lead_pct[quarter==as.Date("2023-06-01")]-lead_pct[quarter==as.Date("2023-03-01")],
  late_2023_gap_change=lead_pct[quarter==as.Date("2023-09-01")]-lead_pct[quarter==as.Date("2023-06-01")]),by=.(start,outcome,unit)]
flat[,flattens_2023:=abs(late_2023_gap_change)<abs(early_2023_gap_change)]
save_csv(flat,file.path(A2_OUT,"drift_flattening.csv"))
cat("Forecast and drift diagnostics complete; no post-opening effect estimated.\n")
