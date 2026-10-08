# Full supplied historical OSM motor-road length for ALL DMQ parishes,
# including parishes outside the comparator registry. Public geometry only.
source("code/amend2_helpers.R")
g<-readRDS(file.path(A2_DATA,"geography.rds"))
b<-readRDS(file.path(A2_DATA,"build.rds"));assert_pre(b$crashes)
r<-g$roads;r$class<-sub("_link$","",r$highway)
p<-b$parishes
hits<-st_intersects(p,r)
classes<-sort(unique(r$class))
a<-rbindlist(parallel::mclapply(seq_len(nrow(p)),function(i) {
  rr<-suppressWarnings(st_intersection(r[hits[[i]],],st_geometry(p[i,])))
  z<-data.table(class=rr$class,length_km=as.numeric(st_length(rr))/1000)[,.(length_km=sum(length_km)),by=class]
  out<-data.table(code=p$code[i])
  for(cl in classes)out[,(paste0("road_km_",cl)):=if(cl%in%z$class)z[class==cl,length_km]else 0]
  out
},mc.cores=3L))
stopifnot(nrow(a)==nrow(p),!anyDuplicated(a$code),all(vapply(a[,!"code"],function(v)all(is.finite(v)&v>=0),TRUE)))
# Registered parish predictors must use exactly the same length definition.
gp<-readRDS(file.path(A2_DATA,"geographic_predictors.rds"))
gp<-copy(gp[startsWith(unit,"parish_")]);gp[,code:=sub("^parish_","",unit)]
m<-match(gp$code,a$code)
for(nm in paste0("road_km_",classes))stopifnot(max(abs(gp[[nm]]-a[[nm]][m]))<1e-6)
setorder(a,code)
for(nm in setdiff(names(a),"code"))set(a,j=nm,value=round(a[[nm]],5))
save_csv(a,file.path(A2_OUT,"parish_road_lengths.csv"))
cat("All-parish public road-length inventory complete.\n")
