# Shared unchanged PPML and interval calls for the corrected run and severity-only continuation.
adjustment <- ssc(K.adj=TRUE,K.fixef='nonnested',G.adj=TRUE,G.df='min',t.df='min')
run_fit <- function(p, outcome, key, event=FALSE, descriptive=FALSE) {
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
  removed_months <- setdiff(months,unique(used$month))
  zero_months <- p[,.(total=sum(get(outcome))),by=month][total==0,month]
  # Rare-category zero months have separated month FE and no information for beta.
  # This is the same PPML perfect-fit handling, not a coverage or window change.
  if ((length(removed_months) && (!descriptive || !all(removed_months %in% zero_months))) ||
      length(fit$collin.var)>0)
    stop('Unexpected month or coefficient omitted in ',key,'; stop for review.')
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
small <- function(x) x>0 & x<5
support_table <- function(p,oc,period='post') {
  p[,.(events=sum(get(oc)),complement=sum(all_crashes-get(oc))),by=c('treated',period)]
}

publish_descriptive <- function(descriptive) {
  fwrite(descriptive,file.path(D,'descriptive_full_precision.csv'))
  shown <- copy(descriptive)
  shown[,c('estimate_pct','ci_low_pct','ci_high_pct'):=lapply(.SD,round,3),.SDcols=c('estimate_pct','ci_low_pct','ci_high_pct')]
  fwrite(shown,file.path(O,'descriptive_types_severity.csv'))
  display <- shown[,.(Group=group,Category=category,
    `Estimate (%)`=ifelse(is.na(estimate_pct),status,sprintf('%.1f',estimate_pct)),
    `95% interval (%)`=ifelse(is.na(ci_low_pct),'',sprintf('%.1f to %.1f',ci_low_pct,ci_high_pct)),
    Clusters=ifelse(is.na(clusters),'',as.character(clusters)),
    `Omitted units`=ifelse(is.na(omitted_units),'',as.character(omitted_units)),
    `Omitted months`=ifelse(is.na(omitted_months),'',as.character(omitted_months)))]
  writeLines(c('# Descriptive changes by typology and severity, 0–500 m',
    '', 'January 2022–August 2026; monthly PPML against the fixed main comparison discs, with unit and month fixed effects. Pointwise 95% Student-t intervals clustered by unit. These secondary estimates are descriptive.',
    '',md_table(display),'',
    'VOLCAMIENTO: Not estimable; too few events to fit.',
    '', 'Omissions are the unchanged estimator\'s perfect-fit removals. Small pooled counts and their complements are protected; exact count panels remain local. No type is merged with another.'),
    file.path(O,'descriptive_types_severity.md'))
}
