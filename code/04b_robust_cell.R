# One (treatment,outcome) cell: CS + SA + BJS, appended to CSVs. Isolated process
# so a segfault in att_gt cannot take down the other cells.
args <- commandArgs(trailingOnly=TRUE); tn<-args[1]; o<-args[2]
suppressMessages({library(did); library(fixest); library(didimputation); library(data.table)})
setwd("."); OUT<-"output/"
P <- readRDS(paste0(OUT,"panel_R.rds"))
gcol <- c(hightax="g_hightax",highprice="g_highprice",rest="g_rest",mall="g_mall")[[tn]]
dd <- P[!is.na(get(o)), .(state_id,year,gg=get(gcol),y=get(o),n)]
ovf<-paste0(OUT,"res_robust_R.csv"); esf<-paste0(OUT,"es_R.csv")
wov<-function(est,a,s) if(is.finite(a)&&is.finite(s)&&abs(s)<1)
  cat(sprintf("%s,%s,%s,%.6f,%.6f,%.6f,%.6f\n",est,tn,o,a,s,a-1.96*s,a+1.96*s),file=ovf,append=TRUE)
wes<-function(est,et,a,s){ok<-is.finite(et)&is.finite(a)&is.finite(s)&abs(s)<1
  if(any(ok)) cat(paste(sprintf("%s,%s,%s,%d,%.6f,%.6f",est,tn,o,as.integer(et[ok]),a[ok],s[ok]),collapse="\n"),"\n",file=esf,append=TRUE)}
# BJS and SA first (stable; captured even if att_gt segfaults the process afterwards)
try({bj<-did_imputation(data=as.data.frame(dd),yname="y",gname="gg",tname="year",idname="state_id",wname="n")
 wov("BJS",bj$estimate[1],bj$std.error[1])},silent=TRUE)
try({dd[,coh:=ifelse(gg==0,10000L,as.integer(gg))]
 sa<-feols(y~sunab(coh,year)|state_id+year,dd,weights=~n)
 ag<-summary(sa,agg="ATT")$coeftable; wov("SA",ag[1,1],ag[1,2])
 ct<-sa$coeftable; et<-suppressWarnings(as.numeric(sub(".*::(-?[0-9]+).*","\\1",rownames(ct)))); wes("SA",et,ct[,1],ct[,2])},silent=TRUE)
try({cs<-att_gt(yname="y",tname="year",idname="state_id",gname="gg",weightsname="n",data=dd,
   control_group="notyettreated",allow_unbalanced_panel=TRUE,base_period="universal",
   est_method="reg",bstrap=TRUE,cband=FALSE)
 sm<-aggte(cs,type="simple",na.rm=TRUE); wov("CS",sm$overall.att,sm$overall.se)
 dy<-aggte(cs,type="dynamic",na.rm=TRUE); wes("CS",dy$egt,dy$att.egt,dy$se.egt)},silent=TRUE)
cat("CELL DONE",tn,o,"\n")
