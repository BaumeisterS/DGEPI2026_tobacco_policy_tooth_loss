# ============================================================================
# FINAL analysis for the rebuilt revision: adjusted-only models, income REMOVED
# from the adjustment set. fixest on full individual data.
#  A res_final_main.csv   : RD (feols) + RR (fepois), contemporaneous & 10y-avg
#  B res_final_lag.csv    : tooth loss, 1y/5y lag doses (adjusted RD)
#  C res_final_negctrl.csv: seat-belt / smoke-detector (adjusted RD)
#  D res_final_regyr.csv  : region-by-year FE (adjusted RD)
#  E res_final_loo.csv    : leave-one-state-out, tax -> tooth loss (adjusted RD)
# ============================================================================
suppressMessages({
  for (p in c("haven","fixest","data.table"))
    if (!requireNamespace(p, quietly=TRUE)) install.packages(p, repos="https://cloud.r-project.org")
  library(haven); library(fixest); library(data.table)
})
setwd(".")
OUT <- "output/"
d <- as.data.table(read_dta("data/final_smoking_analysis_dataset.dta"))
cat("N =", nrow(d), "\n")

# census region (as in revision_part1.do)
ne <- c("CT","ME","MA","NH","RI","VT","NJ","NY","PA")
mw <- c("IL","IN","MI","OH","WI","IA","KS","MN","MO","NE","ND","SD")
so <- c("DE","FL","GA","MD","NC","SC","VA","DC","WV","AL","KY","MS","TN","AR","LA","OK","TX")
d[, region := fifelse(state_abbrev %in% ne,1L, fifelse(state_abbrev %in% mw,2L, fifelse(state_abbrev %in% so,3L,4L)))]

COV <- "age + factor(female) + factor(racegr) + factor(educa) + factor(diabetes) + factor(dentist12)"
f  <- function(o,x,fe="state_id + year") as.formula(paste0(o," ~ ",x," + ",COV," | ",fe))
row <- function(m,key,...) {
  if (is.null(m) || !(key %in% names(coef(m)))) return(NULL)
  b<-unname(coef(m)[key]); s<-unname(se(m)[key])
  data.table(..., b=b, se=s, lo=b-1.96*s, hi=b+1.96*s, p=2*pnorm(-abs(b/s)), nobs=m$nobs)
}
DOSES <- c(tax="tax_fed_state", tax10="tax_fed_state_10y_avg",
           price="price_state", price10="price_10y_avg", rest="rest", mall="mall")
OUTS  <- c("current_smoker","quitting","all_removed","t6_removed")

# ---- A: main grid ----
res <- list()
for (o in OUTS) for (k in names(DOSES)) {
  x <- DOSES[[k]]
  m1 <- tryCatch(feols (f(o,x), d, cluster=~state_id), error=function(e) NULL)
  m2 <- tryCatch(fepois(f(o,x), d, cluster=~state_id), error=function(e) NULL)
  res[[length(res)+1]] <- row(m1,x, dose=k, outcome=o, model="RD")
  res[[length(res)+1]] <- row(m2,x, dose=k, outcome=o, model="RR")
  cat("A done:",o,k,"\n")
}
fwrite(rbindlist(res), paste0(OUT,"res_final_main.csv")); cat("== A saved ==\n")

# ---- B: lag doses, tooth loss ----
res <- list()
for (o in c("all_removed","t6_removed"))
  for (x in c("tax_fed_state_lag1","tax_fed_state_lag5","price_lag1","price_lag5")) {
    m <- tryCatch(feols(f(o,x), d, cluster=~state_id), error=function(e) NULL)
    res[[length(res)+1]] <- row(m,x, dose=x, outcome=o, model="RD")
  }
fwrite(rbindlist(res), paste0(OUT,"res_final_lag.csv")); cat("== B saved ==\n")

# ---- C: negative controls ----
res <- list()
for (o in c("seatbelt","smkdetec"))
  for (k in c("tax","price","rest","mall")) {
    m <- tryCatch(feols(f(o,DOSES[[k]]), d, cluster=~state_id), error=function(e) NULL)
    res[[length(res)+1]] <- row(m,DOSES[[k]], dose=k, outcome=o, model="RD")
  }
fwrite(rbindlist(res), paste0(OUT,"res_final_negctrl.csv")); cat("== C saved ==\n")

# ---- D: region-by-year FE ----
res <- list()
for (o in OUTS) for (k in c("tax","price","rest","mall")) {
  m <- tryCatch(feols(f(o,DOSES[[k]],"state_id + region^year"), d, cluster=~state_id), error=function(e) NULL)
  res[[length(res)+1]] <- row(m,DOSES[[k]], dose=k, outcome=o, model="RD_regyr")
}
fwrite(rbindlist(res), paste0(OUT,"res_final_regyr.csv")); cat("== D saved ==\n")

# ---- E: leave-one-state-out ----
res <- list()
for (o in c("all_removed","t6_removed")) {
  mfull <- feols(f(o,"tax_fed_state"), d, cluster=~state_id)
  res[[length(res)+1]] <- row(mfull,"tax_fed_state", dose="tax", outcome=o, model="LOO_full", unit="FULL")
  for (sid in unique(d$state_id)) {
    m <- tryCatch(feols(f(o,"tax_fed_state"), d[state_id!=sid], cluster=~state_id), error=function(e) NULL)
    res[[length(res)+1]] <- row(m,"tax_fed_state", dose="tax", outcome=o, model="LOO", unit=as.character(sid))
  }
  cat("E done:",o,"\n")
}
fwrite(rbindlist(res), paste0(OUT,"res_final_loo.csv")); cat("== E saved ==\n== ALL DONE ==\n")
