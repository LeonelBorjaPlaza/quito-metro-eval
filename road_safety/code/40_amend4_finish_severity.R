# Authorized continuation after VOLCAMIENTO stop; no completed fit is rerun.
# Uses the maker's existing ignored panels/fits. Fresh verification uses 39 only.
source('code/helpers.R')
suppressPackageStartupMessages(library(fixest))
setDTthreads(1);setFixest_nthreads(1)
D <- 'data/derived/amendment4_stage_b_2022'
O <- 'output/amendment4_stage_b_2022'
stopifnot(file.exists(file.path(D,'fit_started')),
          !file.exists(file.path(D,'completion.txt')),
          !file.exists(file.path(D,'severity_started')))
panels <- readRDS(file.path(D,'panels.rds'))
fits <- readRDS(file.path(D,'fits.rds'))
diagnostics <- readRDS(file.path(D,'diagnostics.rds'))
p <- panels$main_inner; months <- sort(unique(p$month))
stopifnot(min(months)==as.Date('2022-01-01'),max(months)==as.Date('2026-08-01'))
source('code/amend4_2022_fit_helpers.R')
completed_names <- names(fits)
completed_fits <- fits
protected_files <- c(file.path(O,c('estimates.csv','quarterly_all_crashes.png','quarterly_pedestrian_descriptive.png')),
  file.path(D,c('estimates_full_precision.csv','quarterly_event_study.csv','panels.rds')))
hash <- function(paths) vapply(paths,function(x)substr(system2('sha256sum',shQuote(x),stdout=TRUE),1,64),'')
before <- hash(protected_files)
categories <- fread(file.path(D,'category_release_decisions.csv'))
supports <- readRDS(file.path(D,'category_support.rds'))
partial <- fread(file.path(D,'descriptive_partial.csv'))
stopifnot(nrow(partial[category=='VOLCAMIENTO'])==1L,
          setequal(partial$category,categories[group=='Typology',label]),
          all(partial$group=='Typology'),
          !any(c('descriptive_severity_damage','descriptive_severity_injury_fatal') %in% completed_names))
partial[category=='VOLCAMIENTO',status:='Not estimable']
remaining <- categories[group=='Severity']
stopifnot(setequal(remaining$outcome,c('severity_damage','severity_injury_fatal')),
          all(remaining$withheld==FALSE))
writeLines(format(Sys.time(),tz='UTC'),file.path(D,'severity_started'))
new_rows <- list()
for(j in seq_len(nrow(remaining))) {
  z <- remaining[j]; oc <- z$outcome
  ss <- support_table(p,oc)
  stopifnot(!any(small(ss$events)|small(ss$complement)),!any(ss$events==0))
  f <- run_fit(p,oc,paste0('descriptive_',oc),descriptive=TRUE)
  ci <- intervals(f,p)
  new_rows[[oc]] <- cbind(data.table(group=z$group,category=z$label,ring='0-500 m',label='Descriptive'),
    ci[,.(estimate_pct,ci_low_pct,ci_high_pct,clusters,df,units,omitted_units)],
    omitted_months=length(setdiff(months,unique(p[fixest::obs(f),month]))),
    status='Estimated; pointwise 95% interval')
}
stopifnot(identical(before,hash(protected_files)),identical(completed_fits,fits[completed_names]))
descriptive <- rbindlist(c(list(partial),new_rows),use.names=TRUE)
publish_descriptive(descriptive)
fwrite(data.table(file=protected_files,sha256_before=before,sha256_after=hash(protected_files)),
  file.path(D,'continuation_unchanged_checks.csv'))
fwrite(data.table(check=c('only severity models added','completed fit objects unchanged','existing table and figures unchanged',
  '2021 sensitivity not refitted','VOLCAMIENTO retained not estimable'),passed=TRUE),file.path(D,'continuation_checks.csv'))
capture.output(sessionInfo(),file=file.path(D,'session_info.txt'))
writeLines('Completed by severity-only continuation authorized by Leonel; no completed fit rerun.',file.path(D,'completion.txt'))
cat('Severity-only continuation complete. Completed fit objects, main table and event figures are unchanged.\n')
