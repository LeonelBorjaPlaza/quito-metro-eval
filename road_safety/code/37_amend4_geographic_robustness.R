# Requested Amendment4 robustness definitions: GEOGRAPHY ONLY, no outcomes.
source('code/helpers.R');setDTthreads(1)
O<-'output/amendment4_additions';D<-'data/derived/amendment4_additions'
dir.create(O,recursive=TRUE,showWarnings=FALSE);dir.create(D,recursive=TRUE,showWarnings=FALSE)
a<-readRDS('data/derived/amendment4_grid/geography.rds');main<-a$comparison;stations<-a$stations
reg<-fread('output/amendment4_grid/grid_registry.csv')
par<-st_transform(st_read(paste0('/vsizip/',normalizePath(PARISH_ZIP)),quiet=TRUE),CRS_UTM)
par$code<-as.integer(par$dpa_parroq);par<-par[order(par$code),]
line<-st_union(st_transform(st_zm(st_read(LINE_GPKG,quiet=TRUE)),CRS_UTM))
centres<-st_as_sf(reg,coords=c('easting','northing'),crs=CRS_UTM,remove=FALSE)
# Lowest DPA code resolves boundary membership, fixed before any outcome load.
assign_parish<-function(points){h<-st_intersects(points,par);stopifnot(all(lengths(h)>0));vapply(h,function(j)min(par$code[j]),1L)}
valley_names<-c('CUMBAYA','TUMBACO','CONOCOTO','ALANGASI','LA MERCED')
vpar<-par[par$dpa_despar%in%valley_names,];stopifnot(nrow(vpar)==5)
# Valley membership is by centre; retain whole discs and original exclusions.
in_valley<-lengths(st_intersects(centres,st_union(vpar)))>0
reg[,valley_selected:=in_valley & geographic_eligible & !is.na(fast_share) & fast_share<=.25]
valley<-st_buffer(centres[reg$valley_selected,],500)
valley$parish_code<-assign_parish(centres[reg$valley_selected,])
valley$parish_name<-par$dpa_despar[match(valley$parish_code,par$code)]
valley$added_to_main<-!valley$id%in%main$id
combined_ids<-union(main$id,valley$id)
combined<-st_buffer(centres[match(combined_ids,reg$id),],500)
combined$main_comparison<-combined$id%in%main$id
combined$valley_comparison<-combined$id%in%valley$id
# A full500m disc wholly beyond2km requires centre-line distance >2500m.
main_centres<-centres[match(main$id,reg$id),]
centre_line_dist<-as.numeric(st_distance(main_centres,line))
far<-main[centre_line_dist>2500,]
stopifnot(nrow(main)==82,nrow(valley)>0,nrow(far)>0,all(as.numeric(st_distance(far,line))>2000))
# Freeze one parish per unit; no splitting count cells or changing fixed effects.
unit_map<-rbind(data.table(unit=paste0('station_',stations$Name),kind='station',parish_code=assign_parish(stations)),data.table(unit=main$id,kind='main_disc',parish_code=assign_parish(main_centres)))
unit_map[,parish_name:=par$dpa_despar[match(parish_code,par$code)]]
valley_map<-data.table(unit=valley$id,parish_code=valley$parish_code,parish_name=valley$parish_name,already_main=!valley$added_to_main)
far_map<-data.table(unit=main$id,centre_line_distance_m=centre_line_dist,entirely_beyond2km=centre_line_dist>2500)
fwrite(unit_map,file.path(O,'parish_cluster_map.csv'));fwrite(valley_map,file.path(O,'valley_registry.csv'));fwrite(far_map,file.path(O,'line_distance_registry.csv'))
counts<-data.table(item=c('main comparison discs','valley discs all eligible','valley discs already in main','valley additional discs','main plus valley unique discs','main discs wholly beyond2km line','parish clusters main primary: stations plus discs','parish clusters comparisons only'),number=c(nrow(main),nrow(valley),sum(!valley$added_to_main),sum(valley$added_to_main),length(combined_ids),nrow(far),uniqueN(unit_map$parish_code),uniqueN(unit_map[kind=='main_disc',parish_code])))
fwrite(counts,file.path(O,'geography_counts.csv'))
fwrite(valley_map[,.(discs=.N,additional=sum(!already_main)),by=.(parish_code,parish_name)],file.path(O,'valley_counts_by_parish.csv'))
st_write(valley[,c('id','parish_code','parish_name','added_to_main')],file.path(O,'valley_discs.geojson'),delete_dsn=TRUE,quiet=TRUE)
st_write(far[,c('id')],file.path(O,'beyond2km_discs.geojson'),delete_dsn=TRUE,quiet=TRUE)
# Public map shows all valley discs, duplicates retained once in the fit.
focus<-st_bbox(st_union(c(st_geometry(main),st_geometry(valley),st_geometry(st_buffer(stations,1000)))))
p<-ggplot()+geom_sf(data=par,fill='grey98',colour='grey80',linewidth=.15)+geom_sf(data=vpar,fill='#f5dfaa',alpha=.25,colour='#b48a31',linewidth=.4)+geom_sf(data=main,fill='#147f89',alpha=.65,colour=NA)+geom_sf(data=valley,aes(colour=added_to_main),fill=NA,linewidth=.45)+scale_colour_manual(values=c('FALSE'='#147f89','TRUE'='#ba682e'),labels=c('FALSE'='already in main','TRUE'='additional valley disc'))+geom_sf(data=st_sf(geometry=st_buffer(line,2000)),fill=NA,colour='#727272',linetype='dashed',linewidth=.3)+geom_sf(data=stations,colour='#b32a23',size=1.2)+coord_sf(xlim=c(focus[1]-1000,focus[3]+1000),ylim=c(focus[2]-1000,focus[4]+1000),expand=FALSE)+theme_void()+theme(legend.position='bottom')+labs(title='Amendment 4: fixed-grid valley robustness',subtitle=sprintf('Main 82; valley %d (%d additional); unique combined %d',nrow(valley),sum(valley$added_to_main),length(combined_ids)),colour=NULL,caption='Shaded parishes: Cumbayá, Tumbaco, Conocoto, Alangasí, La Merced. Dashed: Metro line 2 km buffer.\nWhole discs retain original DMQ/Metro/BRT exclusions and 25% fast cap; valley density floor removed.\nGeography only. © OpenStreetMap contributors/Geofabrik 2022; GeoQuito.')
ggsave(file.path(O,'valley_grid_map.png'),p,width=10,height=10,dpi=160,bg='white')
saveRDS(list(main=main,valley=valley,combined=combined,far=far,parish_map=unit_map,stations=stations,line=line),file.path(D,'geography.rds'))
fwrite(data.table(check=c('main82 unchanged','same fixedgrid/exclusions/fast cap for valley','no valley density floor','combineddeduplicated','far discs entirely beyond2km line','parish mapping complete','no crash inputs or models'),passed=c(nrow(main)==82,all(reg[valley_selected==TRUE,geographic_eligible & fast_share<=.25]),TRUE,length(combined_ids)==nrow(main)+sum(valley$added_to_main),all(as.numeric(st_distance(far,line))>2000),all(!is.na(unit_map$parish_code)),TRUE)),file.path(O,'checks.csv'))
cat('Robustness geography fixed; no crash inputs loaded or model run.\n')
