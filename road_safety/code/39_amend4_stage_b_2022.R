# Approved Amendment 4 corrected Stage B: January 2022 start.
# User-authorized descriptive additions only; old sensitivity reused, not refitted.
# Inputs: locked AMT crash workbook, station points and parish boundaries;
# frozen, committed geography registries from Stage A. No previous crash panels.
# Outputs: paired-start seven-row table, all-crash and descriptive pedestrian
# event figures, descriptive typology/severity table. Exact panels, fits,
# event coefficients and diagnostics stay in ignored data/derived/amendment4_stage_b_2022.
source('code/helpers.R')
suppressPackageStartupMessages(library(fixest))
setDTthreads(1); setFixest_nthreads(1)
D <- 'data/derived/amendment4_stage_b_2022'
O <- 'output/amendment4_stage_b_2022'
dir.create(D, recursive=TRUE, showWarnings=FALSE)
dir.create(O, recursive=TRUE, showWarnings=FALSE)
if (file.exists(file.path(D, 'fit_started'))) stop('Stage B was already started. Do not rerun the maker analysis.')
stopifnot(any(grepl('APPROVED by Leonel', readLines('docs/analysis_plan_amendment_4.md', n=4))))
started <- Sys.time()
START <- as.Date('2022-01-01')
old_path <- 'output/amendment4_stage_b/estimates.csv'
stopifnot(substr(system2('sha256sum',shQuote(old_path),stdout=TRUE),1,64)==
 '120e5304422d2fa40d47b0cdc3aa6b13f464860b9867744141dc723861d04e55')
inputs <- c(
  RAW_XLSX=RAW_XLSX, stations=STATIONS_GPKG, parishes=PARISH_ZIP,
  grid='output/amendment4_grid/grid_registry.csv',
  valley='output/amendment4_additions/valley_registry.csv',
  far='output/amendment4_additions/line_distance_registry.csv',
  parish_map='output/amendment4_additions/parish_cluster_map.csv',
  plan='docs/analysis_plan_amendment_4.md')
expected <- c(RAW_SHA256,
  '115f574b4f4787b53c62a069c6cf4d1ae41251d326a89256a3921f6d058ecd3f', PARISH_SHA256,
  'de819865a3f77b9a1f317464388d154aba53364b4f1b320a49db44386e868307',
  '4c5f49805cd432afeca9297cf98cd93a599de213b7d7eefc23e920e8c1299de6',
  'bac14ea820277070b33ca4023be34bd20b103d674a011ba22cf932b507f0a8a3',
  '5636e100f9326de723d99fb9eafb35455d56404192e4bb3433dd9d2fec987729',
  'bcd23c94387397b52f12f92f9f848088e284134b834a687d794b3b8c651a1b4f')
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
  lon=num(s$LONGITUD), lat=num(s$LATITUD), typology=trimws(s$`TIPOLOGÍA`), severity=trimws(s$SEVERIDAD),
  homicide=!is.na(s$FALLECIDOS) & grepl('SICARIATO', s$FALLECIDOS, fixed=TRUE))
delivery_months <- seq(as.Date('2021-01-01'), as.Date('2026-08-01'), by='month')
months <- seq(START, as.Date('2026-08-01'), by='month')
stopifnot(!anyNA(d$date), !anyNA(d$id), all(nzchar(d$id)), !anyDuplicated(d$id),
          min(d$date)==as.Date('2021-01-01'), max(d$date)==as.Date('2026-08-31'),
          all(is.finite(d$lon)), all(is.finite(d$lat)),
          all(d$lon>=-79.1 & d$lon<=-78), all(d$lat>=-.7 & d$lat<=.3),
          !anyNA(d$typology), all(nzchar(d$typology)))
d[, month:=month_start(date)]
stopifnot(setequal(unique(d$month), delivery_months))
coverage <- d[, .(has_records=.N>0L, first_day=min(date), last_day=max(date)), by=month][order(month)]
fwrite(coverage, file.path(D, 'delivery_coverage.csv'))
d <- d[homicide==FALSE & date>=START]
stopifnot(!anyNA(d$severity), all(d$severity %in% c('DAÑOS MATERIALES','LESIONADOS','FALLECIDOS')))
d[, pedestrian:=as.integer(typology=='ATROPELLO')]
typologies <- sort(unique(d$typology),method='radix')
type_columns <- sprintf('type_%02d',seq_along(typologies))
for(j in seq_along(typologies)) d[,(type_columns[j]):=as.integer(typology==typologies[j])]
d[, `:=`(severity_damage=as.integer(severity=='DAÑOS MATERIALES'),
 severity_injury_fatal=as.integer(severity %in% c('LESIONADOS','FALLECIDOS')))]
indicator_names <- c('pedestrian',type_columns,'severity_damage','severity_injury_fatal')
category_registry <- rbind(data.table(group='Typology',label=typologies,outcome=type_columns),
 data.table(group='Severity',label=c('Damage only','Injury or fatal'),outcome=c('severity_damage','severity_injury_fatal')))
fwrite(category_registry,file.path(D,'category_registry.csv'))
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
  selected_columns <- c('id','month',indicator_names)
  members <- rbind(cbind(unit=d$station[use_station],d[use_station,selected_columns,with=FALSE]),
    cbind(unit=d[disc %in% controls,disc],d[disc %in% controls,selected_columns,with=FALSE]))
  stopifnot(!anyDuplicated(members$id))
  counts <- members[,c(list(all_crashes=.N),lapply(.SD,sum)),by=.(unit,month),.SDcols=indicator_names]
  p <- merge(CJ(unit=c(station_ids,controls),month=months),counts,by=c('unit','month'),all.x=TRUE)
  for (nm in c('all_crashes',indicator_names)) set(p,which(is.na(p[[nm]])),nm,0L)
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
# Amendment 4. Automatic package p-values are ignored and never released.
source('code/amend4_2022_fit_helpers.R')
fits <- list(); diagnostics <- list()
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

# Release support concerns pooled crash cells and complements, not unit counts.
for(j in seq_len(nrow(spec))) {
  ss <- support_table(panels[[spec$panel[j]]],spec$outcome[j])
  if(any(small(ss$events)|small(ss$complement))) stop('Small main-model release cell; stop for review.')
}
public <- table[,.(model,outcome,ring,comparison,clustering,estimate_pct,ci_low_pct,ci_high_pct,clusters,df,units,omitted_units)]
public[,c('estimate_pct','ci_low_pct','ci_high_pct'):=lapply(.SD,round,3),.SDcols=c('estimate_pct','ci_low_pct','ci_high_pct')]
old <- fread(old_path)
keys <- c('model','outcome','ring','comparison','clustering')
stopifnot(identical(public[,..keys],old[,..keys]))
paired <- merge(public,old,by=keys,suffixes=c('_2022_primary','_2021_sensitivity'),sort=FALSE)
paired <- paired[match(public$model,model)]
fwrite(paired,file.path(O,'estimates.csv'))

events <- list()
for(oc in c('all_crashes','pedestrian')) for(pn in c('main_inner','main_outer')) {
  p <- panels[[pn]]; key <- paste0('event_',oc,'_',pn)
  f <- run_fit(p,oc,key,event=TRUE)
  z <- intervals(f,p)
  z[,q:=as.integer(sub('q::(-?[0-9]+):treated','\\1',term))]
  stopifnot(setequal(z$q,setdiff(unique(p$q),-1L)))
  z <- rbind(z,data.table(term='reference',log_estimate=0,log_se=NA_real_,estimate_pct=0,
    ci_low_pct=NA_real_,ci_high_pct=NA_real_,clusters=z$clusters[1],df=z$df[1],
    units=z$units[1],omitted_units=z$omitted_units[1],q=-1L))
  z[,`:=`(band=if(pn=='main_inner')'0-500 m'else'500 m-1 km',outcome=oc)]
  z[,quarter_start:=as.Date(sprintf('%04d-%02d-01',2023+(11+3*q)%/%12,(11+3*q)%%12+1))]
  z[,months_observed:=vapply(q,function(k)uniqueN(p[q==k,month]),1L)]
  ss <- support_table(p,oc,'q')
  hidden <- ss[small(events)|small(complement),unique(q)]
  # Every coefficient uses the reference quarter: protect all if it is sparse.
  if(-1L %in% hidden) hidden <- unique(z$q)
  z[,withheld:=q %in% hidden]
  events[[key]] <- z
}
event <- rbindlist(events);setorder(event,outcome,band,q)
fwrite(event,file.path(D,'quarterly_event_study.csv'))
plot_event <- function(oc,title,filename) {
  e <- copy(event[outcome==oc])
  e[withheld==TRUE,c('estimate_pct','ci_low_pct','ci_high_pct'):=NA_real_]
  # Separate segments ensure a suppressed quarter is not bridged by a line.
  e[,segment:=cumsum(withheld),by=band]
  e[,plot_date:=quarter_start+ifelse(band=='0-500 m',-7,7)]
  partial <- unique(e[months_observed<3,.(quarter_start)])
  p <- ggplot(e,aes(plot_date,estimate_pct,colour=band,group=interaction(band,segment)))+
    geom_rect(data=partial,aes(xmin=quarter_start-40,xmax=quarter_start+40,ymin=-Inf,ymax=Inf),
              inherit.aes=FALSE,fill='grey90',alpha=.7)+
    geom_hline(yintercept=0,colour='grey50',linewidth=.4)+
    geom_vline(xintercept=as.Date('2023-12-01'),linetype=2,colour='#333333')+
    geom_errorbar(aes(ymin=ci_low_pct,ymax=ci_high_pct),width=18,linewidth=.45,na.rm=TRUE)+
    geom_line(linewidth=.6,na.rm=TRUE)+geom_point(aes(shape=q==-1),size=1.9,na.rm=TRUE)+
    scale_shape_manual(values=c('FALSE'=16,'TRUE'=1),guide='none')+
    scale_colour_manual(values=c('0-500 m'='#176b82','500 m-1 km'='#b65b28'))+
    scale_x_date(date_breaks='6 months',date_labels='%b\n%Y')+
    labs(title=title,subtitle='January 2022 start; September–November 2023 reference; fixed main comparison discs',
      x=NULL,y='Relative change (%)',colour='Station distance',
      caption=paste('Monthly PPML; unit and month fixed effects; bands fitted separately. Pointwise 95% Student-t intervals, clustered by unit.',
      'Dashed: December 2023 opening. Open circles: reference. Shaded first quarter: January–February 2022 only; final June–August 2026 complete.',
      'Quarters begin in December, March, June and September. Small pooled counts and complements protected; affected points withheld.',sep='\n'))+
    theme_minimal(base_size=11)+theme(legend.position='top',panel.grid.minor=element_blank(),plot.caption=element_text(hjust=0,size=8))
  ggsave(file.path(O,filename),p,width=12,height=6.5,dpi=180,bg='white')
}
plot_event('all_crashes','Recorded crashes around Metro stations','quarterly_all_crashes.png')
plot_event('pedestrian','Pedestrian crashes around Metro stations: descriptive','quarterly_pedestrian_descriptive.png')

# Each requested category is the same model on the main inner-ring panel.
# Suppression eligibility is determined before any category-specific estimation.
p <- panels$main_inner
category_registry[,`:=`(withheld=FALSE,secondary_suppression=FALSE)]
supports <- list()
for(j in seq_len(nrow(category_registry))) {
  oc <- category_registry$outcome[j]; ss <- support_table(p,oc)
  supports[[oc]] <- ss
  category_registry[j,withheld:=any(small(ss$events)|small(ss$complement))]
}
if(sum(category_registry[group=='Typology',withheld])==1L) {
  other <- category_registry[group=='Typology' & withheld==FALSE][order(label,method='radix'),outcome][1]
  category_registry[outcome==other,`:=`(withheld=TRUE,secondary_suppression=TRUE)]
}
saveRDS(supports,file.path(D,'category_support.rds'))
fwrite(category_registry,file.path(D,'category_release_decisions.csv'))
descriptive <- list()
for(j in seq_len(nrow(category_registry))) {
  z <- category_registry[j]; oc <- z$outcome
  row <- data.table(group=z$group,category=z$label,ring='0-500 m',label='Descriptive',
    estimate_pct=NA_real_,ci_low_pct=NA_real_,ci_high_pct=NA_real_,clusters=NA_integer_,
    df=NA_integer_,units=NA_integer_,omitted_units=NA_integer_,omitted_months=NA_integer_,status='Withheld: disclosure protection')
  if(!z$withheld) {
    if(any(supports[[oc]]$events==0)) {
      if(z$label!='VOLCAMIENTO') stop('New unavailable category; ask before changing model: ',z$label)
      # Leonel explicitly authorized this unavailable row after the initial stop.
      row[,status:='Not estimable']
      descriptive[[oc]] <- row
      next
    }
    if(z$label=='ATROPELLO' && z$group=='Typology') {
      f <- fits[['pedestrian_inner']]
    } else f <- run_fit(p,oc,paste0('descriptive_',oc),descriptive=TRUE)
    ci <- intervals(f,p)
    row[,c('estimate_pct','ci_low_pct','ci_high_pct','clusters','df','units','omitted_units'):=
      ci[,.(estimate_pct,ci_low_pct,ci_high_pct,clusters,df,units,omitted_units)]]
    row[,`:=`(omitted_months=length(setdiff(months,unique(p[fixest::obs(f),month]))),
              status='Estimated; pointwise 95% interval')]
  }
  descriptive[[oc]] <- row
}
descriptive <- rbindlist(descriptive)
publish_descriptive(descriptive)
capture.output(sessionInfo(),file=file.path(D,'session_info.txt'))
fwrite(data.table(check=c('all delivery months present','input checksums match','no double counting within fit',
 'seven paired-start rows','2021 results reused without refitting','category disclosure checks applied','only requested models'),passed=TRUE),file.path(D,'checks.csv'))
writeLines(sprintf('Corrected Stage B completed in %.1f seconds.',as.numeric(difftime(Sys.time(),started,units='secs'))),file.path(D,'completion.txt'))
cat('Corrected Stage B complete; exact counts, support checks and diagnostics remain ignored.\n')
