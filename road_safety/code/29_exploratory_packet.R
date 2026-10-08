# EXPLORATORY packet from disclosure-protected plot/model outputs only.
source('code/helpers.R');O<-'output/exploratory_20261006';data.table::setDTthreads(1)
e<-fread(file.path(O,'events.csv'));e[,date:=as.Date(date)]
add_events<-function(p)p+geom_vline(data=e,aes(xintercept=date),inherit.aes=FALSE,colour='grey65',linetype=3,linewidth=.25)+geom_text(data=e,aes(x=date,y=Inf,label=code),inherit.aes=FALSE,vjust=1.2,size=2.5)+annotate('rect',xmin=as.Date('2023-10-27'),xmax=as.Date('2023-12-15'),ymin=-Inf,ymax=Inf,alpha=.07,fill='#d8a03c')+annotate('rect',xmin=as.Date('2024-01-08'),xmax=as.Date('2024-04-06'),ymin=-Inf,ymax=Inf,alpha=.06,fill='#824ca5')
cap<-'EXPLORATORY only; no inference. Small counts/complements withheld; counts rounded to 5; fitted ratio rounded to 0.005.\nI inauguration; P pico; T/S tests/suspension; R/r rationing; M opening; C/E curfew; c1/c2 schedule changes. See events.csv.'
z<-fread(file.path(O,'monthly_series.csv'));z[,month:=as.Date(month)]
f<-fread(file.path(O,'step_fitted_ratios.csv'));f[,week:=as.Date(week)]
p<-ggplot()+geom_line(data=z[unit=='corridor_0_600'],aes(month,ratio,colour='Monthly released ratio'),na.rm=FALSE)+geom_line(data=f,aes(week,ratio,colour='Simultaneous weekly step/pulse fit'),linewidth=.6)+facet_wrap(~outcome,ncol=1,scales='free_y')+scale_x_date(date_breaks='6 months',date_labels='%b %Y')+theme_minimal(base_size=10)+theme(legend.position='bottom')+labs(title='EXPLORATORY: corridor ratios and dated step/pulse fits',x=NULL,y='Corridor / pooled distant-parish ratio',colour=NULL,caption=cap)
p<-add_events(p);ggsave(file.path(O,'dated_step_shapes.png'),p,width=12,height=8,dpi=160);ggsave(file.path(O,'dated_step_shapes.pdf'),p,width=12,height=8)
if(file.exists(file.path(O,'signal_monthly_series.csv'))){
 s<-fread(file.path(O,'signal_monthly_series.csv'));s[,month:=as.Date(month)]
 p<-add_events(ggplot(s[unit=='corridor_0_600'],aes(month,count,colour=location))+geom_line(na.rm=FALSE)+facet_grid(proxy_definition~outcome,scales='free_y')+theme_minimal(base_size=10)+theme(legend.position='bottom')+scale_x_date(date_breaks='1 year',date_labels='%Y')+labs(title='EXPLORATORY: corridor crashes by mapped-signal proxy',x=NULL,y='Released crashes',colour=NULL,caption=paste(cap,'\nOther locations have unknown signal status. No hourly outage schedule available.')))
 ggsave(file.path(O,'signal_levels.png'),p,width=12,height=7,dpi=160);ggsave(file.path(O,'signal_levels.pdf'),p,width=12,height=7)
}
q<-fread(file.path(O,'quarterly_event_study.csv'))
shape<-q[q>=-8&q<0,.(pre_2022_2023_range_index=diff(range(index,na.rm=TRUE))),by=.(unit,outcome,adjusted)]
fwrite(shape,file.path(O,'pre2022_2023_lead_ranges.csv'))
# Monthly-period summaries are summaries of the released series, not raw counts.
z[,period:=fcase(month<as.Date('2022-12-01'),'Jan-Nov22',month<as.Date('2023-04-01'),'Dec22-Mar23',month<as.Date('2023-10-01'),'Apr-Sep23',month<as.Date('2023-12-01'),'Oct-Nov23',month<as.Date('2024-01-01'),'Dec23',default='Jan-Aug24')]
period<-z[unit=='corridor_0_600' & month>=as.Date('2022-01-01'),.(mean_released_ratio=round(mean(ratio,na.rm=TRUE),3),available_months=sum(is.finite(ratio))),by=.(outcome,period)]
fwrite(period,file.path(O,'corridor_period_ratios.csv'))
files<-list.files(O,pattern='[.]png$',full.names=FALSE)
writeLines(c('<!doctype html><meta charset="utf-8"><title>Exploratory road-safety plots</title><style>body{font:16px sans-serif;max-width:1300px;margin:2em auto}img{width:100%;height:auto}h2{margin-top:2em}</style><h1>EXPLORATORY: pre-period and P1 only</h1><p>Not the approved Amendment 2 analysis. Nothing September 2024 onward was loaded. All events marked; small-count suppression and rounding apply. No inference.</p>',unlist(lapply(files,function(n)c(paste0('<h2>',n,'</h2>'),paste0('<a href="',sub('[.]png$','.pdf',n),'"><img src="',n,'"></a>'))))),file.path(O,'index.html'))
cat('Exploratory plot index and release-based descriptive summaries completed.\n')
