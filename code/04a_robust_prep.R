# Prep: collapse once, cache panel as RDS, init result CSVs, print Ns.
suppressMessages({library(data.table); library(haven)})
setwd("."); OUT<-"output/"
d <- as.data.table(read_dta("data/final_smoking_analysis_dataset.dta"))
OUTS <- c("current_smoker","quitting","all_removed","t6_removed")
cat("FULL", nrow(d), "\n"); for (o in OUTS) cat(o, sum(!is.na(d[[o]])), "\n")
pol <- d[, lapply(.SD, mean, na.rm=TRUE), by=.(state_id,year), .SDcols=c("tax_fed_state","price_state","rest","mall")]
agg <- d[, c(lapply(.SD, function(x) mean(x, na.rm=TRUE)), .(n=.N)), by=.(state_id,year), .SDcols=OUTS]
P <- merge(agg, pol, by=c("state_id","year")); setorder(P, state_id, year)
fy <- function(ind,yr){w<-which(ind==1); if(length(w)) min(yr[w]) else 0L}
P[, g_hightax  := fy(as.integer(tax_fed_state>=3), year), by=state_id]
P[, g_highprice:= fy(as.integer(price_state>=6),  year), by=state_id]
P[, g_rest := fy(rest, year), by=state_id]
P[, g_mall := fy(mall, year), by=state_id]
saveRDS(P, paste0(OUT,"panel_R.rds"))
cat("estimator,trt,outcome,att,se,lo,hi\n", file=paste0(OUT,"res_robust_R.csv"))
cat("estimator,trt,outcome,et,att,se\n", file=paste0(OUT,"es_R.csv"))
cat("PREP DONE\n")
