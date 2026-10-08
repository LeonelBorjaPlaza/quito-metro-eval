# User-approved reduced power schedule; no observed post outcomes are read.
# Null calibration remains 200 replications. Power is 100, subset checks 20.
# Leonel's final instruction cancels all power and power-confirmation jobs.
# A waiting queue reads this guard when it launches; no process is signalled.
if(Sys.getenv("A2_COARSE_MODE","power") %in% c("power","verify_power")) {
  message("Power and power-confirmation stages cancelled by Leonel: full-estimator calibration now covers null size only.")
  quit(save="no",status=0)
}
SOURCE_SHA <- "c2fcfd5cf9f91f74f6f684ad2887d1bf6faf34c7"
MODE <- Sys.getenv("A2_COARSE_MODE", "power")
NREP <- as.integer(Sys.getenv("A2_REPS", if(MODE=="power") "100" else "20"))
NCORE <- as.integer(Sys.getenv("A2_CORES", "4"))
NPERM <- 39L
stopifnot(MODE %in% c("power","verify_power","verify_trend"),
          NREP == if(MODE=="power") 100L else 20L, NCORE>=1L)
started <- Sys.time()
proc_fields <- strsplit(sub("^.*\\) ","",readLines("/proc/self/stat"))," +")[[1L]]
stopifnot(as.integer(proc_fields[17L])>=15L)
definitions <- readLines("code/15_amend2_forecasts.R")
eval(parse(text=definitions[seq_len(grep("^paths<-list",definitions)-1L)]))
source("code/amend2_full_engine.R")
data.table::setDTthreads(1); fixest::setFixest_nthreads(1)
# Extract definitions from the committed scientific source, never its scheduler.
frozen <- system2("git", c("show",paste0(SOURCE_SHA,":road_safety/code/21_amend2_count_calibration.R")),stdout=TRUE)
stopifnot(length(frozen)>180L)
NULL_PATH <- Sys.getenv("A2_NULL_PATH",readLines(file.path(A2_DATA,"full_calibration_production_path.txt")))
null_manifest <- readLines(file.path(NULL_PATH,"manifest.txt"))
# Every scientific input/package must equal the retained null run. The current
# 21 has an execution-only guard; compare its frozen committed contents instead.
sha <- function(p) substr(system2("sha256sum",shQuote(p),stdout=TRUE),1,64)
tmp <- tempfile(); writeLines(frozen,tmp)
expected <- grep("^[0-9a-f]{64}  ",null_manifest,value=TRUE)
for(line in expected) {
  p <- substring(line,67L)
  actual <- if(p=="code/21_amend2_count_calibration.R") sha(tmp) else sha(p)
  stopifnot(identical(actual,substring(line,1L,64L)))
}
packages <- vapply(c("augsynth","fixest","data.table","sf","osqp"),function(p)paste(p,packageVersion(p)),"")
stopifnot(all(c(paste("R",getRversion()),packages,"NPERM 39") %in% null_manifest))
eval(parse(text=frozen[grep("^set.seed",frozen): (grep("^gens<-",frozen)-1L)]))
# Rebuild generators from this checkout's own pre-period inputs. Preserve all
# three cases and their order so the original seed indexing remains unchanged.
gens <- lapply(cases,function(v)make_generator(v$ts,v$oc))
eval(parse(text=frozen[grep("^run_one<-",frozen):(grep("^scenarios<-",frozen)-1L)]))
null_files <- list.files(NULL_PATH,pattern="_[0-9]+[.]rds$",full.names=TRUE)
null <- rbindlist(lapply(null_files,readRDS))[effect==0]
stopifnot(!anyDuplicated(null[,.(case,scenario,trend_variant,rep)]))
gate <- null[,.(reps=.N,ids_ok=identical(sort(rep),1:200),errors=sum(nzchar(error)|is.na(reject)),size=mean(reject)),by=.(case,scenario,trend_variant)]
triggered <- gate[scenario=="continued_drift" & !trend_variant & reps==200 & ids_ok & errors==0 & size>.075,case]
required <- CJ(case=names(cases),scenario=c("stationary","serial_seasonal","continued_drift"),trend_variant=FALSE)
if(length(triggered)) required <- rbind(required,CJ(case=triggered,scenario=c("stationary","serial_seasonal","continued_drift"),trend_variant=TRUE))
checked <- merge(required,gate,by=c("case","scenario","trend_variant"),all.x=TRUE)
if(MODE=="power") {
  stopifnot(all(!is.na(checked$reps)),all(checked$reps==200),all(checked$ids_ok))
  eligible <- checked[case %in% c("corridor_all","corridor_private") & errors==0 & is.finite(size) & size<=.075,.(case,scenario,trend=trend_variant)]
  registry <- merge(eligible[,join_id:=1L],data.table(effect=c(-.25,-.20,-.15,-.10,.10,.15,.20,.25),join_id=1L),by="join_id",allow.cartesian=TRUE)[,join_id:=NULL]
} else {
  # Registry is reviewed scheduling metadata, not the maker's fitted results.
  registry <- fread(Sys.getenv("A2_REGISTRY_PATH"))
  stopifnot(identical(sort(names(registry)),sort(c("case","scenario","trend","effect"))),
            all(registry$case %in% names(cases)))
  if(MODE=="verify_power") stopifnot(all(registry$case %in% c("corridor_all","corridor_private")),all(abs(registry$effect) %in% c(.10,.15,.20,.25)))
  else stopifnot(all(registry$trend),all(registry$effect==0))
}
stopifnot(!anyDuplicated(registry),all(registry$scenario %in% c("stationary","serial_seasonal","continued_drift")),
          is.logical(registry$trend),!anyNA(registry))
if(MODE!="verify_trend" && nrow(registry)) stopifnot(all(registry[,.(ok=identical(sort(effect),c(-.25,-.20,-.15,-.10,.10,.15,.20,.25))),by=.(case,scenario,trend)]$ok))
setorder(registry,case,scenario,trend,effect)
registry_file <- tempfile(); fwrite(registry,registry_file)
manifest <- c(paste("source",SOURCE_SHA),paste("mode",MODE),paste("replications",NREP),
              paste("null_manifest_sha256",sha(file.path(NULL_PATH,"manifest.txt"))),
              paste("runner_sha256",sha("code/24_amend2_coarse_power.R")),
              packages,paste("registry_sha256",sha(registry_file)))
writeLines(manifest,tmp); run_hash <- sha(tmp)
CHECKPOINT <- file.path(A2_DATA,"coarse_calibration",substr(run_hash,1,20))
dir.create(CHECKPOINT,recursive=TRUE,showWarnings=FALSE)
writeLines(manifest,file.path(CHECKPOINT,"manifest.txt"))
writeLines(CHECKPOINT,file.path(A2_DATA,paste0("coarse_calibration_",MODE,"_path.txt")))
fwrite(registry,file.path(CHECKPOINT,"registry.csv"))
if(MODE=="power") {
  fwrite(checked,file.path(CHECKPOINT,"null_gates.csv"))
  fwrite(required[trend_variant==TRUE,.(case,scenario,trend=trend_variant,effect=0)],file.path(CHECKPOINT,"trend_verification_registry.csv"))
}
saveRDS(gens,file.path(CHECKPOINT,"generators.rds"))
jobs <- merge(registry[,join_id:=1L],data.table(rep=seq_len(NREP),join_id=1L),by="join_id",allow.cartesian=TRUE)[,join_id:=NULL]
setorder(jobs,case,scenario,trend,effect,rep)
if(nrow(jobs)) run_jobs(jobs) else message("No size-qualified corridor cells: no valid power run or MDE is available.")
fwrite(data.table(mode=MODE,started_utc=format(started,tz="UTC",usetz=TRUE),finished_utc=format(Sys.time(),tz="UTC",usetz=TRUE),wall_seconds=as.numeric(difftime(Sys.time(),started,units="secs")),run_hash=run_hash),file.path(CHECKPOINT,"stage_times.csv"))
cat("Coarse calibration complete. All requested points were run; no descending-grid stopping.\n")
