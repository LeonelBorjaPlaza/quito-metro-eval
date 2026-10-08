# Pre-period slope planning range only; not a Wald test or robust effect interval.
source('code/helpers.R');data.table::setDTthreads(1)
D<-'data/derived/amendment3';O<-'output/amendment3_stage_a'
f<-readRDS(file.path(D,'pre_fit_monthly_2022.rds'));g<-f$gap
months<-as.integer(format(g$date,'%Y'))*12+as.integer(format(g$date,'%m'))
t<-months-mean(months);y<-g$g;beta<-sum(t*(y-mean(y)))/sum(t*t);u<-y-mean(y)-beta*t
score<-t*u;n<-length(score);V<-sum(score*score)
for(k in 1:3)V<-V+2*(1-k/4)*sum(score[(k+1):n]*score[1:(n-k)])
se<-sqrt(max(V,0)/(sum(t*t)^2));mean_count<-mean(g$expected_TRUE)
post<-c(seq(as.Date('2023-12-01'),as.Date('2024-08-01'),by='month'),seq(as.Date('2025-01-01'),as.Date('2026-08-01'),by='month'))
postindex<-as.integer(format(post,'%Y'))*12+as.integer(format(post,'%m'))
fwrite(data.table(pre_relative_gap_slope_per_month=beta,slope_range_low=beta-2*se,slope_range_high=beta+2*se,
 pre_count_gap_slope_per_calendar_month=beta*mean_count,count_slope_range_low=(beta-2*se)*mean_count,count_slope_range_high=(beta+2*se)*mean_count,
 mean_calendar_distance_to_post=mean(postindex)-mean(months),
 interpretation='pre-period planning range +/-2 HAC slope-error, lag3; no Wald p-value or validated effect interval; breakdown awaits StageB effect'),file.path(O,'pretrend_planning_range.csv'))
cat('Pretrend planning slope/range complete; no post outcome or breakdown effect computed.\n')
