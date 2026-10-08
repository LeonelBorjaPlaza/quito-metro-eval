# Public road length and census predictors. No post-period outcomes.
source("code/amend2_helpers.R")
g<-readRDS(file.path(A2_DATA,"geography.rds"))
b<-readRDS(file.path(A2_DATA,"build.rds"));assert_pre(b$crashes)
ug<-readRDS(file.path(A2_DATA,"unit_geometry.rds"))
par<-b$parishes;par$population<-g$population$pob_t[match(par$code,g$population$code)]
par$area_km2<-as.numeric(st_area(par))/1e6
stopifnot(!anyNA(par$population),all(par$area_km2>0))
save_csv(as.data.table(st_drop_geometry(par))[,.(code,population,area_km2,density=population/area_km2)],file.path(A2_OUT,"parish_population.csv"))
roads<-g$roads
roads$class<-sub("_link$","",roads$highway)
classes<-sort(unique(roads$class))
district<-st_union(par)
regions<-st_sf(unit=names(ug),geometry=do.call(c,lapply(ug,st_union)))
regions<-suppressWarnings(st_intersection(regions,district))
stopifnot(!anyDuplicated(regions$unit),setequal(regions$unit,names(ug)))
# Build spatial indexes once, rather than rescan the national network per unit.
road_hits<-st_intersects(regions,roads)
par_hits<-st_intersects(regions,par)
cat("Spatial candidate indexes prepared for",nrow(regions),"units.\n")
out<-rbindlist(parallel::mclapply(seq_len(nrow(regions)),function(i) {
  u<-regions$unit[i];region<-st_geometry(regions[i,])
  area<-sum(as.numeric(st_area(region)))/1e6
  stopifnot(area>0)
  h<-par_hits[[i]]
  pieces<-suppressWarnings(st_intersection(par[h,],region))
  pp<-sum(pieces$population*as.numeric(st_area(pieces))/1e6/pieces$area_km2)
  # Intersection allocation is only a predictor, never a crash exposure offset.
  r<-roads[road_hits[[i]],]
  r<-suppressWarnings(st_intersection(r,region))
  rr<-data.table(class=r$class,length_km=as.numeric(st_length(r))/1000)[,.(length_km=sum(length_km)),by=class]
  z<-data.table(unit=u,population=pp,population_density=pp/area,area_km2=area,
    population_method=if(startsWith(u,"parish_")) "parish census total" else "uniform parish-area intersection approximation; predictor only")
  for(cl in classes) z[,(paste0("road_km_",cl)):=if(cl %in% rr$class) rr[class==cl,length_km] else 0]
  z
},mc.cores=6L,mc.preschedule=TRUE))
saveRDS(out,file.path(A2_DATA,"geographic_predictors.rds"))
save_csv(copy(out)[,lapply(.SD,function(v)if(is.numeric(v))round(v,5)else v)],file.path(A2_OUT,"geographic_predictors.csv"))
cat("Complete geometry and population predictors prepared.\n")
