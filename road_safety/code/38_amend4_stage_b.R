# Approved Amendment 4 Stage B. Run once from road_safety/ after 00_setup.R.
# Inputs: locked AMT crash workbook, station points and parish boundaries;
# frozen, committed geography registries from Stage A. No previous crash panels.
# Outputs: one seven-row table and one quarterly figure. Exact panels, fits,
# event coefficients and diagnostics stay in ignored data/derived/amendment4_stage_b.
source('code/helpers.R')
suppressPackageStartupMessages(library(fixest))
setDTthreads(1); setFixest_nthreads(1)
D <- 'data/derived/amendment4_stage_b'
O <- 'output/amendment4_stage_b'
dir.create(D, recursive=TRUE, showWarnings=FALSE)
dir.create(O, recursive=TRUE, showWarnings=FALSE)
if (file.exists(file.path(D, 'fit_started'))) stop('Stage B was already started. Do not rerun the maker analysis.')
stopifnot(any(grepl('APPROVED by Leonel', readLines('docs/analysis_plan_amendment_4_original.md', n=4))))
started <- Sys.time()
inputs <- c(
  RAW_XLSX=RAW_XLSX, stations=STATIONS_GPKG, parishes=PARISH_ZIP,
  grid='output/amendment4_grid/grid_registry.csv',
  valley='output/amendment4_additions/valley_registry.csv',
  far='output/amendment4_additions/line_distance_registry.csv',
  parish_map='output/amendment4_additions/parish_cluster_map.csv',
  plan='docs/analysis_plan_amendment_4_original.md')
expected <- c(RAW_SHA256,
  '115f574b4f4787b53c62a069c6cf4d1ae41251d326a89256a3921f6d058ecd3f', PARISH_SHA256,
  'de819865a3f77b9a1f317464388d154aba53364b4f1b320a49db44386e868307',
  '4c5f49805cd432afeca9297cf98cd93a599de213b7d7eefc23e920e8c1299de6',
  'bac14ea820277070b33ca4023be34bd20b103d674a011ba22cf932b507f0a8a3',
  '5636e100f9326de723d99fb9eafb35455d56404192e4bb3433dd9d2fec987729',
  'fe1187f532aeb687c7933d0714899c7b7b4c6d3d58bc54845a54da4956daa0ee')
hashes <- vapply(inputs, function(p) substr(system2('sha256sum', shQuote(p), stdout=TRUE), 1, 64), '')
stopifnot(identical(unname(hashes), expected))
fwrite(data.table(input=unname(inputs), sha256=hashes), file.path(D, 'input_checksums.csv'))

# Load only the fixed geography before outcomes. Exact radial assignment below
# avoids the polygon approximation of a circular buffer at its outer boundary.
reg <- fread(inputs['grid']); valley <- fread(inputs['valley']); far <- fread(inputs['far'])
parish_map <- fread(inputs['parish_map'])
main_ids <- sort(reg[retained==TRUE, id])
combined_ids <- sort(union(main_ids, valley$unit))
far_ids <- sort(far[entirely_beyond2km==TRUE, unit])
stopifnot(length(main_ids)==82L, length(combined_ids)==253L, length(far_ids)==64L,
          !anyDuplicated(reg$id), !anyDuplicated(parish_map$unit), all(far_ids %in% main_ids))
centres <- st_as_sf(reg[match(combined_ids, id)], coords=c('easting','northing'), crs=CRS_UTM)
stations <- st_transform(st_zm(st_read(STATIONS_GPKG, quiet=TRUE)), CRS_UTM)
stations <- stations[order(stations$Name, method='radix'), ]
station_ids <- paste0('station_', stations$Name)
stopifnot(length(station_ids)==15L, !anyDuplicated(station_ids),
          setequal(parish_map$unit, c(station_ids, main_ids)))
par <- st_transform(st_read(paste0('/vsizip/',normalizePath(PARISH_ZIP)),quiet=TRUE), CRS_UTM)
par <- par[order(as.integer(par$dpa_parroq)), ]
dmq <- st_union(par)
assign_parish <- function(points) {
  h <- st_intersects(points, par)
  stopifnot(all(lengths(h)>0L))
  vapply(h, function(j) min(as.integer(par$dpa_parroq[j])), 1L)
}
mapping <- data.table(unit=c(station_ids, main_ids), parish=c(assign_parish(stations),
  assign_parish(centres[match(main_ids, centres$id), ])))
stopifnot(all(mapping$parish==parish_map$parish_code[match(mapping$unit,parish_map$unit)]))

# Completeness precedes fitting. A missing month is never filled as a zero.
# Presence in the delivery cannot establish exhaustive AMT reporting coverage.
s <- as.data.table(readxl::read_excel(RAW_XLSX, sheet='SINIESTROS', col_types='text'))
num <- function(z) suppressWarnings(as.numeric(z))
d <- data.table(id=trimws(s$SINIESTRO), date=as.Date(num(s$FECHA), origin='1899-12-30'),
  lon=num(s$LONGITUD), lat=num(s$LATITUD), typology=trimws(s$`TIPOLOGÍA`),
  homicide=!is.na(s$FALLECIDOS) & grepl('SICARIATO', s$FALLECIDOS, fixed=TRUE))
months <- seq(as.Date('2021-01-01'), as.Date('2026-08-01'), by='month')
stopifnot(!anyNA(d$date), !anyNA(d$id), all(nzchar(d$id)), !anyDuplicated(d$id),
          min(d$date)==as.Date('2021-01-01'), max(d$date)==as.Date('2026-08-31'),
          all(is.finite(d$lon)), all(is.finite(d$lat)),
          all(d$lon>=-79.1 & d$lon<=-78), all(d$lat>=-.7 & d$lat<=.3),
          !anyNA(d$typology), all(nzchar(d$typology)))
d[, month:=month_start(date)]
stopifnot(setequal(unique(d$month), months))
coverage <- d[, .(has_records=.N>0L, first_day=min(date), last_day=max(date)), by=month][order(month)]
fwrite(coverage, file.path(D, 'delivery_coverage.csv'))
d <- d[homicide==FALSE]
d[, pedestrian:=as.integer(typology=='ATROPELLO')]
points <- st_transform(st_as_sf(d[, .(lon,lat)], coords=c('lon','lat'), crs=4326), CRS_UTM)
in_dmq <- lengths(st_intersects(points, dmq))>0L
sdist <- units::drop_units(as.matrix(st_distance(points, stations)))
# which.min resolves only exact distance ties by the sorted station-name order.
si <- apply(sdist, 1L, which.min)
nearest_distance <- sdist[cbind(seq_len(nrow(d)), si)]
cdist <- units::drop_units(as.matrix(st_distance(points, centres)))
ci <- apply(cdist, 1L, which.min)
disc_distance <- cdist[cbind(seq_len(nrow(d)),ci)]
d[, `:=`(station=station_ids[si], station_distance=nearest_distance,
          disc=ifelse(disc_distance<=500 & in_dmq, centres$id[ci], NA_character_), in_dmq=in_dmq)]
stopifnot(!any(!is.na(d$disc) & d$station_distance<1000))
saveRDS(d, file.path(D, 'assigned_crashes.rds'))

make_panel <- function(band, controls) {
  use_station <- d$in_dmq & if (band=='0-500 m') d$station_distance<500 else
    (d$station_distance>=500 & d$station_distance<1000)
  members <- rbind(d[use_station, .(id,unit=station,month,pedestrian)],
                   d[disc %in% controls, .(id,unit=disc,month,pedestrian)])
  stopifnot(!anyDuplicated(members$id))
  counts <- members[, .(all_crashes=.N, pedestrian=sum(pedestrian)), by=.(unit,month)]
  p <- merge(CJ(unit=c(station_ids,controls),month=months),counts,by=c('unit','month'),all.x=TRUE)
  for (nm in c('all_crashes','pedestrian')) set(p,which(is.na(p[[nm]])),nm,0L)
  p[, `:=`(treated=as.integer(unit %in% station_ids),post=as.integer(month>=OPENING),
           parish=mapping$parish[match(unit,mapping$unit)])]
  p[, metro_post:=treated*post]
  p[, q:=floor(((as.integer(format(month,'%Y'))-2023)*12+as.integer(format(month,'%m'))-12)/3)]
  stopifnot(nrow(p)==length(months)*(length(station_ids)+length(controls)),
            !anyNA(p[,.(all_crashes,pedestrian)]), all(p$pedestrian<=p$all_crashes))
  p
}
panels <- list(main_inner=make_panel('0-500 m',main_ids), main_outer=make_panel('500 m-1 km',main_ids),
               valley=make_panel('0-500 m',combined_ids), far=make_panel('0-500 m',far_ids))
saveRDS(panels,file.path(D,'panels.rds'))

# The user approved these finite-cluster Student-t confidence intervals in
# Amendment 4. No p-values are produced or reported.
adjustment <- ssc(K.adj=TRUE,K.fixef='nonnested',G.adj=TRUE,G.df='min',t.df='min')
fits <- list(); diagnostics <- list()
run_fit <- function(p, outcome, key, event=FALSE) {
  # Let fixest remove perfect-fit zero groups and recursively induced singletons;
  # never screen units by crash volume. Record omitted units from actual fit rows.
  formula <- as.formula(paste(outcome,'~',if(event)'i(q,treated,ref=-1)'else'metro_post','| unit + month'))
  fit <- fepois(formula,data=p,fixef.rm='perfect_fit',vcov=~unit,ssc=adjustment,
                 notes=FALSE,warn=TRUE,data.save=TRUE)
  fits[[key]] <<- fit
  if (!isTRUE(fit$convStatus)) stop('PPML did not converge: ',key,'; stop for review, do not change specification.')
  used <- p[fixest::obs(fit)]
  omitted <- setdiff(unique(p$unit),unique(used$unit))
  diagnostics[[key]] <<- list(omitted_units=omitted, omitted_months=setdiff(months,unique(used$month)),
    omitted_observations=nrow(p)-nrow(used), zero_units=p[,.(zero=sum(get(outcome))==0),by=unit][zero==TRUE,unit],
    collinear_terms=fit$collin.var, converged=fit$convStatus,
    support=p[,.(events=sum(get(outcome))),by=.(treated,post)],
    fixef_removed=fit$fixef_removed)
  saveRDS(fits,file.path(D,'fits.rds'))
  saveRDS(diagnostics,file.path(D,'diagnostics.rds'))
  if (length(setdiff(months,unique(used$month))) || (length(fit$collin.var)>0))
    stop('Month or coefficient omitted in ',key,'; stop for review.')
  if (!event && !('metro_post' %in% names(coef(fit)))) stop('Post coefficient unavailable: ',key)
  fit
}
intervals <- function(fit,p,cluster='unit') {
  used <- p[fixest::obs(fit)]
  stopifnot(!anyNA(used[[cluster]]))
  G <- uniqueN(used[[cluster]])
  V <- vcov(fit,vcov=as.formula(paste0('~',cluster)),ssc=adjustment,attr=TRUE)
  df <- degrees_freedom(fit,type='t',vcov=as.formula(paste0('~',cluster)),ssc=adjustment)
  stopifnot(G>1L,df==G-1L,all(is.finite(V)), all(diag(V)>=0))
  b <- coef(fit); se <- sqrt(diag(V)); critical <- qt(.975,df)
  data.table(term=names(b),log_estimate=unname(b),log_se=unname(se),estimate_pct=100*expm1(b),
    ci_low_pct=100*expm1(b-critical*se),ci_high_pct=100*expm1(b+critical*se),
    clusters=G,df=df,units=uniqueN(used$unit),omitted_units=uniqueN(p$unit)-uniqueN(used$unit))
}
spec <- data.table(model_id=c('primary','all_outer','pedestrian_inner','pedestrian_outer','valley','far'),
  panel=c('main_inner','main_outer','main_inner','main_outer','valley','far'),
  outcome=c('all_crashes','all_crashes','pedestrian','pedestrian','all_crashes','all_crashes'),
  ring=c('0-500 m','500 m-1 km','0-500 m','500 m-1 km','0-500 m','0-500 m'),
  comparison=c('Main','Main','Main','Main','Main plus valley','Beyond 2 km of Metro line'))
writeLines(format(Sys.time(),tz='UTC'),file.path(D,'fit_started'))
rows <- list()
for (j in seq_len(nrow(spec))) {
  z <- spec[j]; p <- panels[[z$panel]]
  f <- run_fit(p,z$outcome,z$model_id)
  rows[[z$model_id]] <- cbind(z[,.(model=model_id,outcome,ring,comparison)],
    clustering='Unit',intervals(f,p)[,!'term'])
}
rows[['parish']] <- cbind(data.table(model='primary_parish',outcome='all_crashes',ring='0-500 m',
  comparison='Main',clustering='Parish'),intervals(fits[['primary']],panels$main_inner,'parish')[,!'term'])
table <- rbindlist(rows)
stopifnot(nrow(table)==7L,all(is.finite(as.matrix(table[,.(estimate_pct,ci_low_pct,ci_high_pct)]))))
fwrite(table,file.path(D,'estimates_full_precision.csv'))

events <- list()
for (pn in c('main_inner','main_outer')) {
  p <- panels[[pn]]; key <- paste0('event_',pn)
  f <- run_fit(p,'all_crashes',key,event=TRUE)
  z <- intervals(f,p)
  z[,q:=as.integer(sub('q::(-?[0-9]+):treated','\\1',term))]
  stopifnot(setequal(z$q,setdiff(unique(p$q),-1L)))
  z <- rbind(z,data.table(term='reference',log_estimate=0,log_se=NA_real_,estimate_pct=0,
    ci_low_pct=NA_real_,ci_high_pct=NA_real_,clusters=z$clusters[1],df=z$df[1],
    units=z$units[1],omitted_units=z$omitted_units[1],q=-1L))
  z[,band:=if(pn=='main_inner')'0-500 m'else'500 m-1 km']
  z[,quarter_start:=as.Date(sprintf('%04d-%02d-01',2023+(11+3*q)%/%12,(11+3*q)%%12+1))]
  z[,months_observed:=vapply(q,function(k)uniqueN(p[q==k,month]),1L)]
  events[[pn]] <- z
}
event <- rbindlist(events);setorder(event,band,q)
fwrite(event,file.path(D,'quarterly_event_study.csv'))

# Release only pooled model effects, never local/monthly counts or invertible
# count means. Protect a sparse pooled outcome or complement before releasing.
for (j in seq_len(nrow(spec))) {
  p <- panels[[spec$panel[j]]]; oc <- spec$outcome[j]
  support <- p[,.(n=sum(get(oc)),complement=sum(all_crashes-get(oc))),by=.(treated,post)]
  if (any(support$n %in% 1:4) || any(support$complement %in% 1:4)) stop('Small pooled release cell; ask before release.')
}
for (p in panels[c('main_inner','main_outer')]) {
  support <- p[,.(n=sum(all_crashes)),by=.(treated,q)]
  if (any(support$n %in% 1:4)) stop('Small event-study release cell; ask before release.')
}
public <- table[,.(model,outcome,ring,comparison,clustering,estimate_pct,ci_low_pct,ci_high_pct,clusters,df,units,omitted_units)]
public[,c('estimate_pct','ci_low_pct','ci_high_pct'):=lapply(.SD,round,3),.SDcols=c('estimate_pct','ci_low_pct','ci_high_pct')]
fwrite(public,file.path(O,'estimates.csv'))
partial <- unique(event[months_observed<3,.(quarter_start)])
event[,plot_date:=quarter_start+ifelse(band=='0-500 m',-7,7)]
p <- ggplot(event,aes(plot_date,estimate_pct,colour=band,group=band))+
  geom_rect(data=partial,aes(xmin=quarter_start-40,xmax=quarter_start+40,ymin=-Inf,ymax=Inf),
            inherit.aes=FALSE,fill='grey90',alpha=.7)+
  geom_hline(yintercept=0,colour='grey50',linewidth=.4)+
  geom_vline(xintercept=as.Date('2023-12-01'),linetype=2,colour='#333333')+
  geom_errorbar(aes(ymin=ci_low_pct,ymax=ci_high_pct),width=18,linewidth=.45,na.rm=TRUE)+
  geom_line(linewidth=.6)+geom_point(aes(shape=q==-1),size=1.9)+
  scale_shape_manual(values=c('FALSE'=16,'TRUE'=1),guide='none')+
  scale_colour_manual(values=c('0-500 m'='#176b82','500 m-1 km'='#b65b28'))+
  scale_x_date(date_breaks='6 months',date_labels='%b\n%Y')+
  labs(title='Recorded crashes around Metro stations',
       subtitle='Quarterly changes relative to September–November 2023 and the fixed main comparison discs',
       x=NULL,y='Relative change (%)',colour='Station distance',
       caption=paste('Monthly PPML with unit and month fixed effects; bands estimated separately. Pointwise 95% Student-t intervals, clustered by unit.',
       'Dashed line: opening, December 2023. Open circles: reference quarter. Shaded first quarter contains January–February 2021 only.',
       'Quarters start in December, March, June and September; the final June–August 2026 quarter is complete.',sep='\n'))+
  theme_minimal(base_size=11)+theme(legend.position='top',panel.grid.minor=element_blank(),
                                  plot.caption=element_text(hjust=0,size=8))
ggsave(file.path(O,'quarterly_event_study.png'),p,width=12,height=6.5,dpi=180,bg='white')
capture.output(sessionInfo(),file=file.path(D,'session_info.txt'))
fwrite(data.table(check=c('all delivery months present','input checksums match','no double counting within fit',
 'specified seven rows','pooled release cells protected','no alternative specifications'),passed=TRUE),file.path(D,'checks.csv'))
writeLines(sprintf('Stage B completed in %.1f seconds.',as.numeric(difftime(Sys.time(),started,units='secs'))),file.path(D,'completion.txt'))
cat('Stage B complete. Released seven-row table and quarterly figure; exact panels and diagnostics remain ignored.\n')
