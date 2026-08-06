# Honest small-cluster inference (CR2 + Satterthwaite) and cumulative-exposure MDE,
# for the Reviewer-1 power/equivalence section. Addresses verification items C2, M6, M7.
suppressMessages({library(haven); library(data.table); library(clubSandwich)})
OUT <- "output/"
set.seed(20260716)

d <- as.data.table(read_dta("final_smoking_analysis_dataset.dta"))
OUTS <- c("current_smoker","all_removed","t6_removed")
DOSES <- c(tax="tax_fed_state", tax10="tax_fed_state_10y_avg",
           price="price_state", price10="price_10y_avg")
keep <- c(OUTS, unname(DOSES), "state_id","year")
P <- d[, lapply(.SD, function(x) mean(x, na.rm=TRUE)), by=.(state_id, year),
       .SDcols=setdiff(keep, c("state_id","year"))]
P[, n := d[, .N, by=.(state_id,year)]$N]
P <- P[is.finite(t6_removed) & is.finite(current_smoker)]
P[, `:=`(state=factor(state_id), yr=factor(year))]

zc <- qnorm(0.975); z8 <- qnorm(0.80)
fitone <- function(outc, dosevar){
  f <- as.formula(sprintf("%s ~ %s + state + yr", outc, dosevar))
  m <- lm(f, data=P, weights=n)
  b <- coef(m)[dosevar]
  # conventional cluster-robust (CR1, ~ feols default) and CR2 + Satterthwaite dof
  ct1 <- coef_test(m, vcov=vcovCR(m, cluster=P$state, type="CR1S"), coefs=dosevar)
  ct2 <- coef_test(m, vcov=vcovCR(m, cluster=P$state, type="CR2"), coefs=dosevar)
  se1 <- ct1$SE; se2 <- ct2$SE; df2 <- ct2$df_Satt
  tc2 <- qt(0.975, df2); t8 <- qt(0.80, df2)
  data.table(outcome=outc, dose=names(DOSES)[DOSES==dosevar],
    b_pp=100*b, se1_pp=100*se1, se2_pp=100*se2, df=df2,
    lo1=100*(b-zc*se1), hi1=100*(b+zc*se1),
    lo2=100*(b-tc2*se2), hi2=100*(b+tc2*se2),
    p2=ct2$p_Satt,
    MDE_conv=100*(zc+z8)*se1, MDE_CR2=100*(tc2+t8)*se2)
}
res <- rbindlist(lapply(names(DOSES), function(dn)
        rbindlist(lapply(OUTS, function(o) fitone(o, DOSES[[dn]])))))
setcolorder(res, c("outcome","dose","b_pp","se1_pp","lo1","hi1","MDE_conv","se2_pp","df","lo2","hi2","p2","MDE_CR2"))
num <- names(res)[sapply(res, is.numeric)]
res[, (num) := lapply(.SD, function(x) round(x,3)), .SDcols=num]
fwrite(res, paste0(OUT,"res_robust_ci.csv"))
cat("=== primary estimates: conventional vs CR2 (percentage points per $1) ===\n")
print(res[dose %in% c("tax","tax10")][order(outcome,dose)])
cat("\n=== ruling-out (CR2 95% CI bounds, pp) and MDE (pp) ===\n")
print(res[outcome %in% c("all_removed","t6_removed") & dose %in% c("tax","tax10","price10"),
          .(outcome,dose,est=b_pp,CR2_lo=lo2,CR2_hi=hi2,MDE_conv,MDE_CR2)])
cat("\n== ROBUST CI DONE ==\n")
