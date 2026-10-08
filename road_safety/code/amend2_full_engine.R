# Full count-engine functions. Sourced after the real pre-only forecast definitions.
# Simulated dates are never passed to the raw-data extractor.
complete_fit<-function(oc,ts,train,hold,trend=FALSE) {
  SIM_TREND<<-trend
  us<-c(ts,donors);cal<-sort(unique(c(train,hold)))
  full<-sort(as.Date(names(which(table(quarter_start(train))==3))))
  folds<-tail(full,3)
  stopifnot(length(folds)==3)
  paths<-list();chosen<-numeric()
  fitpair<-function(tr,ho,tune=TRUE) {
    p<-make_panel(oc,us,sort(unique(c(tr,ho))),tr)
    pp<-ppml_fold(p,tr,ho,ts)
    q<-composition(copy(attr(pp,"adjusted_panel")),tr)
    tq<-sort(unique(quarter_start(tr)));hq<-sort(unique(quarter_start(ho)))
    ih<-tail(sort(as.Date(names(which(table(quarter_start(tr))==3)))),1)
    it<-tr[quarter_start(tr)<ih]
    ip<-ppml_fold(make_panel(oc,us,tr,it),it,setdiff(tr,it),ts)
    iq<-composition(copy(attr(ip,"adjusted_panel")),it)
    pr<-predictors(us,tr);ipr<-predictors(us,it)
    sc<-p[unit %in% ts & month %in% it,.(scale=sum(y)/length(it)*3),by=unit]
    losses<-vapply(LAMBDA,function(lam) {
      aa<-asc_fold(iq,sort(unique(quarter_start(it))),sort(unique(quarter_start(setdiff(tr,it)))),ts,ipr,lam,length(ts)>1)
      aa<-merge(aa[quarter==ih],sc,by="unit")
      mean(((aa$actual-aa$prediction)/pmax(aa$scale,1))^2)
    },0)
    stopifnot(all(is.finite(losses)))
    lam<-max(LAMBDA[losses<=min(losses)*1.05+1e-12])
    aa<-asc_fold(q,tq,hq,ts,pr,lam,length(ts)>1)
    pp[,quarter:=quarter_start(month)]
    pp<-pp[,.(actual=sum(actual),prediction=sum(prediction)),by=.(unit,quarter)]
    r<-rbind(pp[,method:="PPML"],aa[,.(unit,quarter,actual,prediction,method="ASCM")])
    exposure<-data.table(month=sort(unique(c(tr,ho))))[,.(months=.N),by=.(quarter=quarter_start(month))]
    r<-merge(r,exposure,by="quarter")
    r[,lambda:=lam]
    r
  }
  for(h in seq_along(folds)) {
    hs<-folds[h];tr<-train[quarter_start(train)<hs];ho<-train[quarter_start(train)==hs]
    stopifnot(length(unique(quarter_start(tr)))>=4,
      length(unique((as.integer(format(tr,"%m"))-1)%/%3))==4)
    r<-fitpair(tr,ho)
    scale<-x[unit %in% ts & month %in% tr & (oc!="private_car_crashes"|private),.(scale=sum(count)/length(tr)*3),by=unit]
    r<-merge(r[quarter==hs],scale,by="unit")
    r[,fold:=hs];paths[[h]]<-r
  }
  val<-rbindlist(paths)
  loss<-val[,.(mse=mean(((actual-prediction)/pmax(scale,1))^2)),by=method]
  winner<-if(loss[method=="ASCM",mse]<=loss[method=="PPML",mse])"ASCM" else "PPML"
  final<-fitpair(train,hold)
  list(path=final,winner=winner,loss=loss)
}

calendar_assignments<-function(cal,B,seed) {
  # Whole quarters; incomplete quarters remain fixed. Gaps never enter a block.
  dt<-data.table(month=cal,quarter=quarter_start(cal),pre=cal<as.Date("2023-12-01"))
  q<-dt[,.(n=.N,pre=all(pre),continuous=all(diff(as.integer(month))<=31)),by=quarter]
  full<-q[n==3 & continuous,quarter];np<-q[n==3 & continuous & pre,.N]
  fixed<-dt[quarter %in% q[n<3,quarter] & pre,month]
  valid<-function(tr) {
    fq<-sort(as.Date(names(which(table(quarter_start(tr))==3))))
    if(length(fq)<7)return(FALSE)
    all(vapply(tail(fq,3),function(h) {
      tt<-tr[quarter_start(tr)<as.Date(h,origin="1970-01-01")]
      iq<-sort(unique(quarter_start(tt)))
      ii<-tt[quarter_start(tt)<tail(iq,1)]
      length(iq)>=4 && length(unique((as.integer(format(ii,"%m"))-1)%/%3))==4
    },TRUE))
  }
  # The factual pre calendar must also meet the same fold support conditions.
  original<-dt[pre==TRUE,month];stopifnot(valid(original))
  set.seed(seed);assignments<-list(original);keys<-paste(original,collapse=",")
  while(length(assignments)<B+1L) {
    take<-sample(full,np);tr<-sort(c(fixed,dt[quarter %in% take,month]))
    key<-paste(tr,collapse=",")
    if(valid(tr)&&!key %in% keys) {assignments[[length(assignments)+1]]<-tr;keys<-c(keys,key)}
  }
  assignments
}

conformal_complete<-function(oc,ts,cal,assignments,trend=FALSE) {
  statistics<-numeric(length(assignments));winners<-character(length(assignments))
  for(k in seq_along(assignments)) {
    tr<-assignments[[k]];ho<-setdiff(cal,tr)
    ans<-complete_fit(oc,ts,tr,ho,trend)
    r<-ans$path[method==ans$winner]
    report_units<-if(length(ts)>1) A2_RINGS[1:2] else ts
    r<-r[unit %in% report_units,.(actual=sum(actual),prediction=sum(prediction),months=months[1]),by=quarter]
    r[,residual:=(actual-prediction)/months]
    ip<-r$quarter %in% quarter_start(tr)
    center<-weighted.mean(r$residual[ip],r$months[ip])
    scale<-sqrt(weighted.mean((r$residual[ip]-center)^2,r$months[ip]))
    stopifnot(is.finite(scale),scale>0)
    statistics[k]<-(weighted.mean(r$residual[!ip],r$months[!ip])-center)/scale
    winners[k]<-ans$winner
    # Exact decision shortcut: future ranks cannot reduce either inclusive tail.
    # It saves refits only once rejection at the fixed alpha is impossible.
    # No fitted learner is reused, and an incomplete rank is never called a p-value.
    used<-statistics[seq_len(k)];M<-length(assignments);remaining<-M-k
    upper_tail<-sum(used>=statistics[1]);lower_tail<-sum(used<=statistics[1])
    plower<-min(1,2*min(upper_tail,lower_tail)/M)
    pupper<-min(1,2*min(upper_tail+remaining,lower_tail+remaining)/M)
    if(plower>.05 && k<M) return(list(p=NA_real_,reject=FALSE,p_lower=plower,p_upper=pupper,
      permutations_used=k-1L,winner=winners[1],statistic=statistics[1],floor=2/M))
  }
  # Identity included. No estimated Gaussian standard error or Wald p-value.
  p<-min(1,2*min(mean(statistics>=statistics[1]),mean(statistics<=statistics[1])))
  list(p=p,reject=p<=.05,p_lower=p,p_upper=p,permutations_used=length(assignments)-1L,
       winner=winners[1],statistic=statistics[1],floor=2/length(statistics))
}
