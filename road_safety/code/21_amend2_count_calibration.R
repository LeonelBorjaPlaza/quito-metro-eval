# Full-estimator Monte Carlo runner. Reads ONLY the rebuilt pre-period inputs.
# Later outcomes are generated integer counts; no post-period source is read.
# Execution-only guard requested by Leonel: the already-running null stage keeps
# its loaded code. Its queued legacy power stage reads this guard at launch.
if(Sys.getenv("A2_CALIBRATION_MODE","pilot")=="power" &&
   Sys.getenv("A2_ALLOW_OLD_POWER","0")!="1") {
  message("Legacy power stage skipped: superseded by the approved separate coarse grid. Set A2_ALLOW_OLD_POWER=1 only to explicitly authorize the legacy schedule.")
  quit(save="no",status=0)
}
definitions<-readLines("code/15_amend2_forecasts.R")
eval(parse(text=definitions[seq_len(grep("^paths<-list",definitions)-1L)]))
source("code/amend2_full_engine.R")
data.table::setDTthreads(1);fixest::setFixest_nthreads(1)
NREP<-as.integer(Sys.getenv("A2_REPS","200"))
NPERM<-as.integer(Sys.getenv("A2_PERMUTATIONS","39"))
NCORE<-as.integer(Sys.getenv("A2_CORES","6"))
MODE<-Sys.getenv("A2_CALIBRATION_MODE","pilot")
STAGE_STARTED<-Sys.time()
stopifnot(NPERM>=39,NREP>=1)
if(MODE!="pilot")stopifnot(NREP>=200)
fingerprint_files<-c("code/13_amend2_extract.py","code/14_amend2_build.R","code/15_amend2_forecasts.R",
 "code/19_amend2_geography.R","code/20_amend2_predictors.R","code/21_amend2_count_calibration.R",
 "code/amend2_helpers.R","code/helpers.R","code/amend2_calendar.R","code/amend2_full_engine.R",
 file.path(A2_DATA,c("build.rds","controls.rds","geographic_predictors.rds")))
manifest<-c(paste("R",getRversion()),vapply(c("augsynth","fixest","data.table","sf","osqp"),function(p)paste(p,packageVersion(p)),""),system2("sha256sum",shQuote(fingerprint_files),stdout=TRUE),paste("NPERM",NPERM),
 paste("mode namespace",if(MODE=="pilot")"pilot"else"production"))
tmp<-tempfile();writeLines(manifest,tmp)
run_hash<-substr(system2("sha256sum",shQuote(tmp),stdout=TRUE),1,64)
CHECKPOINT<-file.path(A2_DATA,"full_calibration",substr(run_hash,1,20))
dir.create(CHECKPOINT,recursive=TRUE,showWarnings=FALSE)
mp<-file.path(CHECKPOINT,"manifest.txt")
if(file.exists(mp))stopifnot(identical(readLines(mp),unname(manifest)))else writeLines(manifest,mp)
writeLines(CHECKPOINT,file.path(A2_DATA,paste0("full_calibration_",if(MODE=="pilot")"pilot"else"production","_path.txt")))
set.seed(2026100501)
real_x<-copy(x);real_cc<-cc
cases<-list(corridor_all=list(oc="all_crashes",ts=A2_RINGS),
 corridor_private=list(oc="private_car_crashes",ts=A2_RINGS),
 center_all=list(oc="all_crashes",ts="historic_center"))
base_pre<-A2_MONTHS[A2_MONTHS>=as.Date("2022-01-01")]
whole<-seq(as.Date("2022-01-01"),as.Date("2026-08-01"),by="month")
whole<-whole[!(whole>=as.Date("2024-09-01")&whole<=as.Date("2024-12-01"))]

make_generator<-function(ts,oc) {
  x<<-copy(real_x);cc<<-real_cc;SIM_TREND<<-FALSE
  us<-c(ts,donors)
  p<-make_panel("all_crashes",us,base_pre,base_pre)
  fit<-ppml_fold(p,base_pre,as.Date(character()),ts)
  fp<-attr(fit,"fitted_panel")
  fp[,moy:=as.integer(format(month,"%m"))]
  season<-fp[,.(mu=mean(prediction)),by=.(unit,cell,moy)]
  phi<-max(0,fp[,sum((y-prediction)^2-y)/sum(prediction^2)])
  # Mark distributions from pre-only sufficient statistics, preserving observed
  # joint private/day/hour composition within each modeled crash cell.
  a<-copy(x[unit %in% us & month %in% base_pre])
  collapsed<-attr(p,"road_collapsed")
  a[,cell:=if(collapsed)paste(group,severity,sep="__")else paste(group,severity,road_type,sep="__")]
  a[,hour_bin:=fifelse(hour<6|hour>=23,0L,fifelse(peak,1L,2L))]
  a[is.na(hour_bin),hour_bin:=3L]
  marks<-a[,.(n=sum(count)),by=.(unit,cell,group,severity,road_type,private,weekend,hour_bin,pico)]
  marks[,prob:=n/sum(n),by=.(unit,cell)]
  # Fitted zero cells remain zero; they are not deleted from estimation panels.
  stopifnot(!any(season[mu>0, !paste(unit,cell)%in%paste(marks$unit,marks$cell)]))
  # Dependence/trend diagnostics use the requested outcome, not all crashes.
  ofit<-if(oc=="all_crashes")fit else ppml_fold(make_panel(oc,us,base_pre,base_pre),base_pre,as.Date(character()),ts)
  ofp<-attr(ofit,"fitted_panel")
  q<-ofp[,.(y=sum(y),mu=sum(prediction)),by=.(unit,month)][order(unit,month)]
  q[,resid:=(y-mu)/sqrt(pmax(mu+phi*mu^2,1))]
  rho<-q[,.(r=suppressWarnings(cor(head(resid,-1),tail(resid,-1)))),by=unit]
  rho[!is.finite(r),r:=0];rho[,r:=pmax(-.5,pmin(.8,r))]
  # Continued differential trend is estimated from pre-period treated/donor gaps.
  donor<-q[unit %in% donors,.(donor=sum(y)),by=month]
  q<-merge(q,donor,by="month")
  slopes<-q[unit %in% ts,{
    tt<-as.numeric(month-min(base_pre))/365.25
    f<-lm(log((y+.5)/(donor+.5))~tt)
    list(slope=unname(coef(f)[2]))
  },by=unit]
  # Monthly controls for future dates are pre-period month-of-year resamples.
  # Actual known calendar composition is used; precipitation is synthetic.
  cal<-whole
  if(oc=="private_car_crashes")cal<-cal[cal!=as.Date("2025-10-01")]
  ctl<-real_cc$controls[unit %in% us & month %in% base_pre]
  ctl[,moy:=as.integer(format(month,"%m"))]
  # Deterministic source year before the opening; never a later observed value.
  src<-ctl[order(month),.SD[1],by=.(unit,moy)]
  simctl<-merge(CJ(unit=us,month=cal),src[,month:=NULL],by="unit",allow.cartesian=TRUE)
  simctl<-simctl[moy==as.integer(format(month,"%m"))]
  simctl[,moy:=NULL]
  for(i in seq_along(cal)) {
    mm<-cal[i];dd<-seq(mm,seq(mm,by="month",length.out=2)[2]-1,by="day")
    simctl[month==mm,`:=`(weekend_days=sum(as.integer(format(dd,"%u"))>=6),days=length(dd))]
  }
  # Holiday counts repeat pre-period month patterns, explicitly synthetic.
  simctl<-rbindlist(list(real_cc$controls[unit %in% us & month %in% base_pre],simctl[month>=as.Date("2023-12-01")]),use.names=TRUE,fill=TRUE)[order(unit,month)]
  cc<<-list(controls=simctl)
  # Evaluate the fitted pre count model at the synthetic controls. Common future
  # cell-month shocks repeat their pre month-of-year average, not post outcomes.
  extended<-ppml_fold(make_panel("all_crashes",us,cal,base_pre),base_pre,setdiff(cal,base_pre),ts)
  base<-attr(extended,"base_panel")
  common<-base[month %in% base_pre,.(shock=mean(shock)),by=.(cell,moy=as.integer(format(month,"%m")))]
  base[,moy:=as.integer(format(month,"%m"))]
  base[,shock:=NULL];base<-merge(base,common,by=c("cell","moy"))
  means<-base[,.(unit,cell,month,mu=mu_base*shock)]
  list(means=means,phi=phi,marks=marks,rho=rho,slopes=slopes,controls=simctl,cal=cal,us=us,ts=ts,oc=oc)
}

simulate_marks<-function(gen,scenario,effect,seed) {
  set.seed(seed)
  cal<-gen$cal;us<-gen$us
  dgp<-copy(gen$means)[order(unit,cell,month)]
  shocks<-CJ(unit=us,month=cal)
  shocks[,z:=0]
  if(scenario!="stationary") {
    # Additional serial/seasonal lognormal stress; a common positive floor
    # prevents fitted zero dispersion from removing the requested stress.
    # The floor is a fixed sensitivity assumption, not an estimated parameter.
    sdlog<-max(sqrt(log1p(gen$phi)),.10)/sqrt(2)
    fullcal<-seq(min(cal),max(cal),by="month")
    keep<-match(cal,fullcal)
    common<-as.numeric(arima.sim(list(ar=.4),n=length(fullcal),sd=sdlog*sqrt(1-.4^2)))
    for(u in us) {
      rr<-gen$rho[unit==u,r]
      zz<-as.numeric(arima.sim(list(ar=rr),n=length(fullcal),sd=sdlog*sqrt(1-rr^2)))
      s<-1+.25*cos(2*pi*(as.integer(format(fullcal,"%m"))-1)/12)
      latent<-(zz+common)*s-sdlog^2*s^2
      shocks[unit==u,z:=latent[keep]]
    }
  }
  dgp<-merge(dgp,shocks,by=c("unit","month"))
  dgp[,mu:=mu*exp(z)]
  # A shared cell-level gamma frailty yields NB2 counts, then marks are split.
  # Serial scenarios use their calibrated lognormal mixture instead.
  if(scenario=="stationary"&&gen$phi>0)dgp[,mu:=mu*rgamma(.N,shape=1/gen$phi,scale=gen$phi)]
  z<-merge(dgp[,.(unit,cell,month,mu)],gen$marks,by=c("unit","cell"),allow.cartesian=TRUE)
  z[,mean_count:=mu*prob]
  if(scenario=="continued_drift") {
    z<-merge(z,gen$slopes,by="unit",all.x=TRUE);z[is.na(slope),slope:=0]
    # Private-case drift applies to private marks; nonprivate marks stay at base.
    z[gen$oc!="private_car_crashes"|private,
      mean_count:=mean_count*exp(slope*as.numeric(month-as.Date("2022-12-01"))/365.25)]
  }
  treated<-if(length(gen$ts)>1)A2_RINGS[1:2] else gen$ts
  z[unit %in% treated & month>=as.Date("2023-12-01") & (gen$oc!="private_car_crashes"|private),mean_count:=mean_count*(1+effect)]
  z[,count:=qpois(runif(.N),mean_count)]
  z<-z[count>0]
  z[,`:=`(hour=fifelse(hour_bin==0L,0L,fifelse(hour_bin==1L,7L,fifelse(hour_bin==2L,12L,NA_integer_))),
    peak=fifelse(hour_bin==3L,NA, hour_bin==1L))]
  z
}

gens<-lapply(cases,function(v)make_generator(v$ts,v$oc))
saveRDS(gens,file.path(CHECKPOINT,"generators.rds"))
parameters<-rbindlist(lapply(names(gens),function(nm) {
  g<-gens[[nm]];data.table(case=nm,nb2_overdispersion=g$phi,stress_log_sd=max(sqrt(log1p(g$phi)),.10),stress_sd_floor=.10,post_months=sum(g$cal>=as.Date("2023-12-01")),pre_months=length(base_pre))
}))
save_csv(parameters,file.path(A2_OUT,"full_calibration_parameters.csv"))

run_one<-function(job) {
  nm<-job$case;scenario<-job$scenario;rep<-job$rep;effect<-job$effect;trend<-job$trend
  key<-paste(nm,scenario,if(trend)"trend"else"base",sprintf("%+.3f",effect),rep,sep="_")
  path<-file.path(CHECKPOINT,paste0(key,".rds"))
  if(file.exists(path))return(readRDS(path))
  started<-proc.time()[3]
  seed<-20261005L+match(nm,names(gens))*100000L+match(scenario,c("stationary","serial_seasonal","continued_drift"))*10000L+rep
  g<-gens[[nm]]
  x<<-simulate_marks(g,scenario,effect,seed);cc<<-list(controls=g$controls)
  assignments<-calendar_assignments(g$cal,NPERM,seed+300000L)
  fit<-tryCatch(conformal_complete(g$oc,g$ts,g$cal,assignments,trend),error=function(e)e)
  ans<-data.table(case=nm,scenario=scenario,trend_variant=trend,effect=effect,rep=rep,
    p=if(inherits(fit,"error"))NA_real_ else fit$p,
    reject=if(inherits(fit,"error"))NA else fit$reject,
    p_lower=if(inherits(fit,"error"))NA_real_ else fit$p_lower,
    p_upper=if(inherits(fit,"error"))NA_real_ else fit$p_upper,
    permutations_used=if(inherits(fit,"error"))NA_integer_ else fit$permutations_used,
    winner=if(inherits(fit,"error"))NA_character_ else fit$winner,
    error=if(inherits(fit,"error"))conditionMessage(fit) else "",seconds=proc.time()[3]-started,
    permutations=NPERM,rank_floor=2/(NPERM+1L))
  saveRDS(ans,paste0(path,".tmp"));file.rename(paste0(path,".tmp"),path)
  ans
}
run_jobs<-function(jobs) {
  res<-parallel::mclapply(split(jobs,seq_len(nrow(jobs))),function(j) {
    zz<-run_one(j);cat(format(Sys.time()),zz$case,zz$scenario,zz$trend_variant,zz$effect,zz$rep,zz$error,"\n");zz
  },mc.cores=NCORE,mc.preschedule=FALSE,mc.set.seed=FALSE)
  rbindlist(res)
}
scenarios<-c("stationary","serial_seasonal","continued_drift")
if(MODE=="pilot") {
  jobs<-CJ(case=names(cases),scenario="stationary",rep=1L,effect=0,trend=c(FALSE,TRUE))
  print(run_jobs(jobs));quit(save="no")
}
if(MODE=="null") {
  jobs<-CJ(case=names(cases),scenario=scenarios,rep=seq_len(NREP),trend=FALSE);jobs[,effect:=0]
  baseline<-run_jobs(jobs)
  gate<-baseline[scenario=="continued_drift",.(reps=.N,errors=sum(nzchar(error)),size=mean(reject)),by=case]
  failing<-gate[reps==NREP & errors==0 & size>.075,case]
  if(length(failing)) {
    jobs<-CJ(case=failing,scenario=scenarios,rep=seq_len(NREP),trend=TRUE);jobs[,effect:=0]
    run_jobs(jobs)
  }
} else if(MODE=="power") {
  files<-list.files(CHECKPOINT,pattern="\\.rds$",full.names=TRUE)
  files<-files[!grepl("generators",files)]
  null<-rbindlist(lapply(files,readRDS))[effect==0]
  gate<-null[,.(reps=.N,ids_ok=identical(sort(rep),seq_len(NREP)),errors=sum(nzchar(error)),size=mean(reject)),by=.(case,scenario,trend_variant)]
  eligible<-gate[reps==NREP & ids_ok & errors==0 & size<=.075]
  # Fixed grid. No valid MDE is claimed outside the size-qualified scenarios.
  if(nrow(eligible)) {
    active<-merge(eligible[,.(case,scenario,trend=trend_variant,join_id=1L)],data.table(direction=c(-1,1),join_id=1L),by="join_id",allow.cartesian=TRUE)[,join_id:=NULL]
    for(magnitude in c(.9,.75,.5,.3,.15)) {
      if(!nrow(active))break
      jobs<-merge(active[,join_id:=1L],data.table(rep=seq_len(NREP),join_id=1L),by="join_id",allow.cartesian=TRUE)[,join_id:=NULL]
      jobs[,effect:=direction*magnitude]
      zz<-run_jobs(jobs)
      pass<-zz[,.(reps=.N,errors=sum(nzchar(error)),power=mean(reject)),by=.(case,scenario,trend=trend_variant,direction=sign(effect))]
      active<-pass[reps==NREP & errors==0 & power>=.8,.(case,scenario,trend,direction)]
    }
  } else cat("No size-qualified cells; no valid MDE power runs.\n")
} else stop("Unknown A2_CALIBRATION_MODE")
stage<-data.table(mode=MODE,started_utc=format(STAGE_STARTED,tz="UTC",usetz=TRUE),finished_utc=format(Sys.time(),tz="UTC",usetz=TRUE),wall_seconds=as.numeric(difftime(Sys.time(),STAGE_STARTED,units="secs")),run_hash=run_hash)
fwrite(stage,file.path(CHECKPOINT,"stage_times.csv"),append=file.exists(file.path(CHECKPOINT,"stage_times.csv")))
cat("Checkpointed count calibration stage complete.\n")
