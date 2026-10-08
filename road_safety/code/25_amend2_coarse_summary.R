# User-approved 200-null / 100-power coarse summary, superseding legacy22.
message("Coarse-power summary cancelled by Leonel: use the size-only null summary in script 22.")
quit(save="no",status=0)
# Aggregate only simulated test decisions. Never reads observed post outcomes.
source("code/amend2_helpers.R")
NREP<-200L
POWER_REPS<-100L
path<-readLines(file.path(A2_DATA,"full_calibration_production_path.txt"))
files<-list.files(path,pattern="\\.rds$",full.names=TRUE)
files<-files[basename(files)!="generators.rds"]
coarse_path<-readLines(file.path(A2_DATA,"coarse_calibration_power_path.txt"))
coarse_files<-list.files(coarse_path,pattern="_[0-9]+[.]rds$",full.names=TRUE)
r<-rbindlist(c(list(rbindlist(lapply(files,readRDS))[effect==0]),lapply(coarse_files,readRDS)))
stopifnot(nrow(r)>0,!anyDuplicated(r[,.(case,scenario,trend_variant,effect,rep)]))
summary<-r[,{
  target<-if(effect[1]==0)NREP else POWER_REPS
  n<-.N;k<-sum(reject,na.rm=TRUE);err<-sum(nzchar(error)|is.na(reject));ph<-if(err==0)k/n else NA_real_
  list(replications=n,numerical_errors=err,replication_set_complete=identical(sort(rep),seq_len(target)),
    complete=identical(sort(rep),seq_len(target))&&err==0,
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
mde<-rbindlist(lapply(seq_len(nrow(null)),function(i) {
  z<-null[i]
  rbindlist(lapply(c(-1,1),function(direction) {
    q<-summary[case==z$case & scenario==z$scenario & trend_variant==z$trend_variant & sign(effect)==direction][order(-abs(effect))]
    status<-if(z$size_gate=="fail")"no valid MDE: size screen failed" else if(z$size_gate=="failed numerical gate")"no valid MDE: fitted procedure undefined" else "incomplete calibration"
    lower<-upper<-NA_real_
    if(z$size_gate=="pass"&&nrow(q)&&all(q$replication_set_complete)&&any(!q$complete))
      status<-"no valid MDE: fitted procedure undefined at a power point"
    if(z$case=="center_all" && z$size_gate=="pass") status<-"full-estimator power not run; historical residual prototype only"
    mag<-abs(q$effect);fixed<-c(.25,.20,.15,.10)
    stopifnot(all(mag %in% fixed))
    if(z$size_gate=="pass"&&identical(mag,fixed)&&all(q$complete)) {
      qualifies<-vapply(seq_along(mag),function(j)all(q$rejection_rate[seq_len(j)]>=.8),logical(1))
      if(!any(qualifies)) {status<-"no evaluated grid threshold qualifies; 25% fails";lower<-.25}
      else {
        j<-max(which(qualifies));upper<-mag[j]
        lower<-if(j<length(mag))mag[j+1L] else 0
        status<-if(j==length(mag))"coarse-grid upper bound" else "coarse-grid threshold bracket"
      }
    }
    data.table(case=z$case,scenario=z$scenario,trend_variant=z$trend_variant,
      direction=if(direction<0)"fall"else"rise",status=status,lower_pct=100*lower,upper_pct=100*upper,
      interpretation="sustained 10/15/20/25% coarse-grid criterion; bounds are not exact continuous MDEs")
  }))
}))
save_csv(mde,file.path(A2_OUT,"full_calibration_mde.csv"))
errors<-r[nzchar(error)|is.na(reject),.N,by=.(case,scenario,trend_variant,effect,error)]
save_csv(errors,file.path(A2_OUT,"full_calibration_errors.csv"))
times<-rbindlist(lapply(c(path,coarse_path),function(p)if(file.exists(file.path(p,"stage_times.csv")))fread(file.path(p,"stage_times.csv"))else NULL),fill=TRUE)
save_csv(times,file.path(A2_OUT,"full_calibration_runtime.csv"))
cat("Full-estimator calibration summary written.\n")
