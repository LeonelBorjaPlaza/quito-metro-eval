# Pre-period-only inference feasibility experiment. No post-opening data loaded.
# This tests a residual-test prototype, NOT the complete PPML/ASCM estimator.
# Conditional MDEs are diagnostic; approval requires full-estimator calibration.
source("code/amend2_helpers.R")
b<-readRDS(file.path(A2_DATA,"build.rds"));assert_pre(b$crashes)
donors<-b$units[family=="donor",unit]
set.seed(20261005)
SIM_B<-300L;PERM_B<-399L
LEVELS<-c(0,.05,.10,.15,.20,.30,.40,.50,.75,1)
targets<-c(A2_RINGS,"corridor_0_600","historic_center")
outcomes<-c("all_crashes","private_car_crashes","injury_fatal")

# Blocks never cross an excluded month or a pre/P1/P2 boundary. Permutations
# exchange only equal-length blocks, retaining the real gap and sample sizes.
blocks_for<-function(calendar,pre,keep,L) {
  i<-which(keep);segment<-cumsum(c(TRUE,diff(i)>1 | diff(pre[i])!=0))
  unlist(lapply(split(i,segment),function(j) split(j,ceiling(seq_along(j)/L))),recursive=FALSE)
}
permutation_matrix<-function(blocks,N,B) {
  out<-matrix(rep(seq_len(N),B+1L),nrow=N)
  bylen<-split(seq_along(blocks),lengths(blocks))
  for(k in 2:(B+1L)) for(g in bylen) {
    perm<-g[sample.int(length(g))]
    for(j in seq_along(g)) out[blocks[[g[j]]],k]<-blocks[[perm[j]]]
  }
  out
}
generate_noise<-function(n,sigma,rho,season,drift=0) {
  z<-numeric(n+100L);ee<-rnorm(n+100L,sd=sigma*sqrt(1-rho^2))
  for(i in 2:length(z)) z[i]<-rho*z[i-1]+ee[i]
  tail(z,n)*season+drift*seq_len(n)/12
}
rows<-list();params<-list()
for(st in c(2022L,2021L)) for(oc in outcomes) for(u in targets) {
  premonths<-A2_MONTHS[A2_MONTHS>=as.Date(paste0(st,"-01-01"))]
  npre<-length(premonths)
  yy<-b$outcomes[month %in% premonths & unit %in% c(u,donors)]
  a<-yy[unit==u][order(month),get(oc)]
  c0<-yy[unit %in% donors,.(y=sum(get(oc))),by=month][order(month),y]
  gap<-a/mean(a)-c0/mean(c0)
  fit<-lm(gap~seq_along(gap));res<-resid(fit)
  sigma<-sd(res);rho<-cor(head(res,-1),tail(res,-1));rho<-max(-.5,min(.8,rho))
  slope<-unname(coef(fit)[2])*12
  params[[length(params)+1]]<-data.table(start=st,outcome=oc,unit=u,residual_sd=round(sigma,4),rho=round(rho,3),trend_per_year=round(slope,4))
  # Calendar extends past pre only synthetically. Outcomes for these dates are
  # generated below, not read. Four excluded months remain actual time gaps.
  calendar<-seq(min(premonths),as.Date("2026-08-01"),by="month")
  pre<-calendar<as.Date("2023-12-01")
  keep<-!(calendar>=as.Date("2024-09-01") & calendar<=as.Date("2024-12-01"))
  if(oc=="private_car_crashes") keep<-keep & calendar!=as.Date("2025-10-01")
  obs<-which(keep);preobs<-pre[keep];N<-length(obs)
  post<-!preobs;postn<-sum(post)
  # The prototype is a normalized residual with an intercept nuisance; seasonal
  # noise and drift are stress-tested, not claimed to be correctly removed.
  for(L in c(1L,3L,6L)) {
    blcal<-blocks_for(calendar,pre,keep,L)
    bl<-lapply(blcal,function(ii) match(ii,obs))
    perms<-permutation_matrix(bl,N,PERM_B)
    identical_allocation<-vapply(seq_len(ncol(perms)),function(k) identical(sort(perms[post,k]),which(post)),TRUE)
    identity_ties<-sum(identical_allocation)
    allocation_space<-prod(vapply(split(seq_along(bl),lengths(bl)),function(g) {
      choose(length(g),sum(vapply(bl[g],function(ii) all(preobs[ii]),TRUE)))
    },0))
    for(scenario in c("stationary","serial_seasonal","continued_drift")) {
      set.seed(20261005+st+match(oc,outcomes)*1000L+match(u,targets)*100L+L*10L+match(scenario,c("stationary","serial_seasonal","continued_drift")))
      ans<-array(0L,c(SIM_B,length(LEVELS),2L,2L),dimnames=list(NULL,NULL,c("fall","rise"),c("legacy_abs_mean","anchored_equal_tail")))
      for(bb in seq_len(SIM_B)) {
        seas<-if(scenario=="stationary") rep(1,length(calendar)) else 1+.3*sin(2*pi*seq_along(calendar)/12)
        noise<-generate_noise(length(calendar),sigma,if(scenario=="stationary") 0 else rho,seas,
          if(scenario=="continued_drift") slope else 0)[keep]
        # Full-null intercept and mean absolute-window residual statistic.
        # Adaptation anchors level to each candidate pre period and uses signed
        # equal-tail ranks. It does not pretend centering alone changes ranks.
        pn<-matrix(noise[perms],nrow=N)
        effectmask<-matrix(as.numeric(post)[perms],nrow=N)
        old0<-colMeans(pn[post,,drop=FALSE])-colMeans(pn)
        oldd<-colMeans(effectmask[post,,drop=FALSE])-colMeans(effectmask)
        new0<-colMeans(pn[post,,drop=FALSE])-colMeans(pn[preobs,,drop=FALSE])
        newd<-colMeans(effectmask[post,,drop=FALSE])-colMeans(effectmask[preobs,,drop=FALSE])
        for(di in seq_len(2)) for(k in seq_along(LEVELS)) {
          delta<-LEVELS[k]*c(-1,1)[di]
          old<-old0+delta*oldd;new<-new0+delta*newd
          pold<-mean(abs(old)>=abs(old[1])-1e-12)
          pnew<-min(1,2*min(mean(new>=new[1]-1e-12),mean(new<=new[1]+1e-12)))
          ans[bb,k,di,]<-c(pold<=.05,pnew<=.05)
        }
      }
      rate<-apply(ans,c(2,3,4),mean)
      for(di in 1:2) for(method in dimnames(ans)[[4]]) {
        rr<-rate[,di,method];size<-rr[1]
        # Prespecified pragmatic Monte Carlo gate. It is not a proof of size.
        passes<-size<=.075
        sustained<-vapply(seq_along(LEVELS)[-1],function(k) all(rr[k:length(rr)]>=.8),TRUE)
        mde<-if(passes && any(sustained)) min(LEVELS[-1][sustained]) else NA_real_
        ci<-t(vapply(round(rr*SIM_B),function(k) binom.test(k,SIM_B)$conf.int,c(0,0)))
        rows[[length(rows)+1]]<-data.table(start=st,outcome=oc,unit=u,post_months=postn,
          block_months=L,scenario,method,direction=c("fall","rise")[di],effect_pct_training_mean=100*LEVELS,
          rejection_rate=round(rr,4),null_size=round(size,4),size_gate=passes,
          power_mc_low=round(ci[,1],4),power_mc_high=round(ci[,2],4),
          conditional_mde_pct_training_mean=100*mde,simulation_draws=SIM_B,permutations=PERM_B,
          mc_rank_grid=if(method=="anchored_equal_tail") 2/(PERM_B+1) else 1/(PERM_B+1),
          identity_tie_floor=identity_ties/(PERM_B+1)*ifelse(method=="anchored_equal_tail",2,1),
          exhaustive_allocation_floor=ifelse(method=="anchored_equal_tail",2,1)/allocation_space,
          status="residual prototype only; not full-estimator power or an approved headline MDE")
      }
    }
  }
  cat("Simulated pre-period residual prototype",st,oc,u,"\n")
}
save_csv(rbindlist(params),file.path(A2_OUT,"simulation_parameters.csv"))
curves<-rbindlist(rows);save_csv(curves,file.path(A2_OUT,"simulation_curves.csv"))
mde<-unique(curves[,.(start,outcome,unit,post_months,block_months,scenario,method,direction,null_size,size_gate,
  conditional_mde_pct_training_mean,simulation_draws,permutations,mc_rank_grid,identity_tie_floor,exhaustive_allocation_floor,status)])
save_csv(mde,file.path(A2_OUT,"conditional_mde.csv"))

# Placebo-only composites: old adjacency/volume algorithm on all distant parishes.
# Estimation donors above are never screened or merged.
par<-b$parishes[b$parishes$distant,];codes<-par$code
precr<-b$crashes
counts<-sapply(codes,function(pc) tabulate(match(precr[parish %in% pc,month],A2_MONTHS),length(A2_MONTHS)))
pass<-function(j) mean(rowSums(counts[,j,drop=FALSE]))>=3 & mean(rowSums(counts[,j,drop=FALSE])==0)<=.2
singles<-which(vapply(seq_along(codes),function(j)pass(j),TRUE))
adj<-st_relate(par,par,pattern="F***1****")
left<-setdiff(seq_along(codes),singles);groups<-lapply(singles,function(i)i);failed<-list()
order_volume<-function(j) j[order(-colSums(counts)[j],codes[j])]
while(length(left)) {
  g<-order_volume(left)[1];left<-setdiff(left,g)
  repeat {
    if(pass(g)) break
    nb<-intersect(unique(unlist(adj[g])),left)
    if(!length(nb)) break
    add<-order_volume(nb)[1];g<-c(g,add);left<-setdiff(left,add)
  }
  if(pass(g)) groups[[length(groups)+1]]<-g else failed[[length(failed)+1]]<-g
}
comps<-rbindlist(c(lapply(seq_along(groups),function(j) data.table(composite=paste0("placebo_",j),members=paste(codes[groups[[j]]],collapse=";"),eligible=TRUE)),
 lapply(seq_along(failed),function(j)data.table(composite=paste0("ineligible_",j),members=paste(codes[failed[[j]]],collapse=";"),eligible=FALSE))))
save_csv(comps,file.path(A2_OUT,"placebo_composites.csv"))
saveRDS(list(groups=lapply(groups,function(g)codes[g]),failed=lapply(failed,function(g)codes[g])),file.path(A2_DATA,"composites.rds"))
cat("Inference prototype and placebo-only composites complete.\n")
