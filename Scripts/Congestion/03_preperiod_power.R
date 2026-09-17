# Rough design calibration, not power for a fitted estimator. No post-opening values enter.
source("Scripts/Congestion/descriptive_helpers.R")
power_dir <- "Output/Waze/planning"
dir.create(power_dir, recursive = TRUE, showWarnings = FALSE)
con <- connect_clean()
# Read only 2022-Jan through 2023-Nov values from Parquet, including the eligibility screen.
raw_pre <- as.data.table(DBI::dbGetQuery(con,"SELECT grid_id,date::INTEGER date,hour_of_day,
  CASE WHEN tci_osm_ratio IN (-998,-999) THEN NULL ELSE tci_osm_ratio END tci_osm_ratio
  FROM all_roadtype WHERE date BETWEEN 202201 AND 202311"))
geo <- as.data.table(st_drop_geometry(readRDS("Output/Waze/inventory/cell_groups.rds")))
counts <- raw_pre[,.(pre_slots=.N/23),by=grid_id]
flags <- merge(geo[,.(grid_id,group)],counts,by="grid_id")
ids <- flags[group=="CENTER" | (group=="REST" & pre_slots>=20)]
pd <- sort(unique(raw_pre$date))
stopifnot(length(pd)==23,max(pd)==202311)
cm <- merge(CJ(grid_id=ids$grid_id,date=pd),raw_pre[hour_of_day %in% c(7,8,17,18),.(value=sum(tci_osm_ratio)/4),by=.(grid_id,date)],
            by=c("grid_id","date"),all.x=TRUE)
cm[is.na(value),value:=0]
cm <- merge(cm,ids,by="grid_id")
mean_series <- dcast(cm[,.(value=mean(value)),by=.(group,date)],date~group,value.var="value")
r <- mean_series$CENTER-mean_series$REST
center_mean <- mean(mean_series$CENTER)
noise_sd <- sd(r)
set.seed(20260919)
B <- 10000L
H <- 9L
T0 <- length(r)
draw_blocks <- function(x,n,L) {
  starts <- sample.int(length(x),ceiling(n/L),replace=TRUE)
  ix <- as.vector(t(outer(starts,0:(L-1),"+")))
  x[(ix[seq_len(n)]-1L) %% length(x)+1L]
}
find_mde <- function(errors) {
  critical <- unname(quantile(abs(errors),.95,type=8))
  # Empirical two-sided rejection after a constant downward shift; 0.001 pp resolution.
  deltas <- seq(0,max(1,critical+quantile(abs(errors),.999)+1),by=.001)
  p <- vapply(deltas,function(delta) mean(abs(errors-delta)>critical),numeric(1))
  c(critical95=critical,mde80=deltas[which(p>=.8)[1]],null_rejection=mean(abs(errors)>critical))
}
boot <- rbindlist(lapply(c(1L,3L,6L),function(L) {
  errors <- replicate(B,{
    z <- draw_blocks(r-mean(r),T0+H,L)
    mean(tail(z,H))-mean(head(z,T0))
  })
  ans <- find_mde(errors)
  data.table(method=paste0("Circular blocks L=",L),draws=B,noise_sd=noise_sd,
    critical95=ans[["critical95"]],mde80=ans[["mde80"]],null_rejection=ans[["null_rejection"]])
}))
# Spatial calibration: each saturated REST cell versus the other saturated cells.
# Baseline 2022; fake opening January 2023; validation January-September 2023 only.
donors <- cm[group=="REST"]
donors[, other_mean:=(sum(value)-value)/(.N-1),by=date]
donors[, residual:=value-other_mean]
placebos <- donors[,.(baseline=mean(residual[date<=202212]),
  training_sd=sd(residual[date<=202212]),validation=mean(residual[date>=202301 & date<=202309])),by=grid_id]
placebos[,shift:=validation-baseline]
center_train_sd <- sd(r[mean_series$date<=202212])
placebos <- placebos[is.finite(training_sd) & training_sd>0]
placebos[, center_scaled_shift:=shift/training_sd*center_train_sd]
ans <- find_mde(placebos$center_scaled_shift)
spatial <- data.table(method="Donor-cell historical placebos, CENTER-noise scaled",draws=nrow(placebos),noise_sd=center_train_sd,
  critical95=ans[["critical95"]],mde80=ans[["mde80"]],null_rejection=ans[["null_rejection"]])
result <- rbind(boot,spatial)
result[,mde_percent_of_pre_mean:=100*mde80/center_mean]
normal_iid <- (qnorm(.975)+qnorm(.8))*noise_sd*sqrt(1/H+1/T0)
saveRDS(list(table=result,center_pre_mean=center_mean,residual_sd=noise_sd,normal_iid_mde=normal_iid,
  pre_dates=pd,placebos=placebos,pre_series=mean_series,seed=20260919,session=sessionInfo()),file.path(power_dir,"preperiod_power.rds"))
writeLines(c("# Pre-only rough power calibration","",sprintf("CENTER combined-peak pre mean: %.6f percentage points. CENTER minus saturated REST residual SD: %.6f. Independent-normal reference MDE: %.6f pp.",center_mean,noise_sd,normal_iid),"",
  md_table(result),"",
  "No outcome dated December 2023 or later is read. Each bootstrap generates a hypothetical 23-month baseline and nine-month evaluation from centered pre residuals. Circular blocks of length 1, 3 and 6 preserve different amounts of serial dependence. The 95th percentile of absolute null errors sets a two-sided critical value; constant negative shifts in increments of 0.001 pp find 80 percent simulated rejection.","",
  "The spatial exercise holds out January-September 2023 against a 2022 baseline for each saturated donor cell versus the mean of the others. It rescales each historical shift by its 2022 residual SD and CENTER's 2022 residual SD. These are dependent one-cell placebos, not interchangeable seven-cell treatment assignments. They provide a stress calibration, not a valid randomization test. No post-opening effect is fitted.","",
  "All calculations use a simple equal-donor benchmark, not optimized synthetic-control weights. Short pre support, trends, selected coverage, overlapping spatial shocks, and a contiguous nine-month simulation for a noncontiguous P2 limit transfer. These numbers are rough planning bounds, not achieved power or a promise for the eventual estimator."),"reports/waze_preperiod_power.md")
DBI::dbDisconnect(con,shutdown=TRUE)
print(result)
