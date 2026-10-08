# Aggregate only simulated test decisions. Never reads observed post outcomes.
source("code/amend2_helpers.R")
NREP<-as.integer(Sys.getenv("A2_REPS","200"));stopifnot(NREP>=200)
path<-readLines(file.path(A2_DATA,"full_calibration_production_path.txt"))
files<-list.files(path,pattern="\\.rds$",full.names=TRUE)
files<-files[basename(files)!="generators.rds"]
r<-rbindlist(lapply(files,readRDS))
stopifnot(all(r$effect==0)) # Final authorized calibration is size only.
stopifnot(nrow(r)>0,!anyDuplicated(r[,.(case,scenario,trend_variant,effect,rep)]))
summary<-r[,{
  n<-.N;k<-sum(reject,na.rm=TRUE);err<-sum(nzchar(error)|is.na(reject));ph<-if(err==0)k/n else NA_real_
  list(replications=n,numerical_errors=err,replication_set_complete=identical(sort(rep),seq_len(NREP)),
    complete=identical(sort(rep),seq_len(NREP))&&err==0,
    rejection_rate=ph,mc_se=if(err==0)sqrt(ph*(1-ph)/n)else NA_real_,
    mc_lower=if(err==0)if(k==0)0 else qbeta(.025,k,n-k+1)else NA_real_,
    mc_upper=if(err==0)if(k==n)1 else qbeta(.975,k+1,n-k)else NA_real_,
    fraction_ASCM=if(err==0)mean(winner=="ASCM")else NA_real_,
    mean_reassignments=mean(permutations_used,na.rm=TRUE),worker_seconds=sum(seconds),rank_floor=unique(rank_floor))
},by=.(case,scenario,trend_variant,effect)]
setorder(summary,case,scenario,trend_variant,effect)
summary[,stage:=ifelse(effect==0,"null size","power")]
save_csv(summary,file.path(A2_OUT,"full_calibration_curves.csv"))
observed_null<-summary[effect==0]
triggered<-observed_null[scenario=="continued_drift" & trend_variant==FALSE & complete & rejection_rate>.075,case]
registry<-CJ(case=c("center_all","corridor_all","corridor_private"),scenario=c("stationary","serial_seasonal","continued_drift"),trend_variant=FALSE)
if(length(triggered))registry<-rbind(registry,CJ(case=triggered,scenario=c("stationary","serial_seasonal","continued_drift"),trend_variant=TRUE))
null<-merge(registry,observed_null,by=c("case","scenario","trend_variant"),all.x=TRUE)
null[is.na(replications),`:=`(replications=0L,numerical_errors=0L,replication_set_complete=FALSE,complete=FALSE,effect=0,stage="null size")]
null[,requested_replications:=NREP]
null[,size_gate:=fifelse(!replication_set_complete,"incomplete",fifelse(numerical_errors>0,"failed numerical gate",fifelse(rejection_rate<=.075,"pass","fail")))]
save_csv(null,file.path(A2_OUT,"full_calibration_size.csv"))
save_csv(registry[trend_variant==TRUE,.(case,scenario,trend=trend_variant,effect=0)],
         file.path(A2_OUT,"trend_verification_registry.csv"))
# No full-estimator power or MDE was run. Retain an explicit status artifact.
mde<-null[,.(case,scenario,trend_variant,status="not estimated: power cancelled by Leonel; full-estimator calibration covers size only")]
save_csv(mde,file.path(A2_OUT,"full_calibration_mde.csv"))
prototype<-fread(file.path(A2_OUT,"conditional_mde.csv"))
planning<-prototype[start==2022 & block_months==3 & method=="anchored_equal_tail" & scenario=="stationary" & direction=="fall" &
 ((unit=="corridor_0_600" & outcome %in% c("all_crashes","private_car_crashes")) | (unit=="historic_center" & outcome=="all_crashes")),
 .(outcome,unit,prototype_planning_pct=conditional_mde_pct_training_mean,
   interpretation="historical residual prototype; percentage of pre-period treated mean; not full-estimator power or a certified MDE",
   source="road_safety/output/amendment2/conditional_mde.csv")]
stopifnot(nrow(planning)==3)
save_csv(planning,file.path(A2_OUT,"prototype_planning_figures.csv"))
errors<-r[nzchar(error)|is.na(reject),.N,by=.(case,scenario,trend_variant,effect,error)]
save_csv(errors,file.path(A2_OUT,"full_calibration_errors.csv"))
if(file.exists(file.path(path,"stage_times.csv"))) {
  save_csv(fread(file.path(path,"stage_times.csv")),file.path(A2_OUT,"full_calibration_runtime.csv"))
} else {
  mt<-file.info(files)$mtime
  save_csv(data.table(mode="null",started_utc=NA_character_,finished_utc=NA_character_,wall_seconds=NA_real_,
    status="stage timing file unavailable; see execution record for process status",
    checkpoint_first_saved_utc=format(min(mt),tz="UTC",usetz=TRUE),checkpoint_last_saved_utc=format(max(mt),tz="UTC",usetz=TRUE),
    checkpoint_span_seconds=as.numeric(difftime(max(mt),min(mt),units="secs")),
    interpretation="checkpoint timestamp span is not stage wall time; worker elapsed sums are separate"),file.path(A2_OUT,"full_calibration_runtime.csv"))
}
cat("Full-estimator calibration summary written.\n")
