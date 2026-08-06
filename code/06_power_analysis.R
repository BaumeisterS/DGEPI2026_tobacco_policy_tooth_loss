# ============================================================================
# Power / minimum-detectable-effect analysis for the Reviewer-1 Type-II rebuttal.
#  (A) Design-based MDE from the REALISED cluster-robust SEs (exact).
#  (B) Monte Carlo on the actual 51-state x 15-year BRFSS design:
#      - size of the state-clustered test under the null,
#      - power curve for the primary TWFE (LPM) and the extended-TWFE/Mundlak,
#      - anchored so the null-model SE reproduces the observed adjusted SE.
#  (C) Plausibility bound: mediated policy->tooth-loss effect vs the MDE.
# ============================================================================
suppressMessages({library(haven); library(data.table); library(fixest); library(ggplot2)})
OUT<-"output/"
set.seed(20260716)

d <- as.data.table(read_dta("final_smoking_analysis_dataset.dta"))
OUTS <- c("t6_removed","all_removed","current_smoker")
P <- d[, c(lapply(.SD, function(x) mean(x, na.rm=TRUE)),
           .(n = sum(!is.na(t6_removed)))), by=.(state_id, year),
      .SDcols=c(OUTS,"tax_fed_state")]
P <- P[is.finite(t6_removed)]
setorder(P, state_id, year)
cat("state-years:", nrow(P), " states:", uniqueN(P$state_id), " years:", uniqueN(P$year), "\n")

# ---- observed adjusted cluster-robust SEs (from the primary individual-level models) ----
obsSE <- c(t6_removed=0.00174, all_removed=0.00116, current_smoker=0.00111)  # per $1, adj TWFE-LPM
obsB  <- c(t6_removed=-0.00189, all_removed=0.00084, current_smoker=-0.00346)
# modern estimators' realised SE (high-dose >=$3 cohort), from res_robust_R.csv
modSE <- tryCatch({
  rr <- fread(paste0(OUT,"res_robust_R.csv"))
  c(CS_t6  = rr[estimator=="CS"  & trt=="hightax" & outcome=="t6_removed", se][1],
    BJS_t6 = rr[estimator=="BJS" & trt=="hightax" & outcome=="t6_removed", se][1])
}, error=function(e) c(CS_t6=0.00319, BJS_t6=0.00506))

zc <- qnorm(0.975)
mde  <- function(se, pw=0.80) (zc + qnorm(pw)) * se          # 2-sided MDE at power pw
powr <- function(beta, se) pnorm(abs(beta)/se - zc) + pnorm(-abs(beta)/se - zc)

cat("\n==== (A) DESIGN-BASED MDE (per $1.00), 80% power, alpha=.05 ====\n")
tabA <- data.table(
  estimator = c("TWFE-LPM (primary): loss >=6 teeth","TWFE-LPM: edentulism","TWFE-LPM: current smoking (positive control)",
                "Callaway-Sant'Anna (>=$3 cohort): >=6 teeth","BJS imputation (>=$3 cohort): >=6 teeth"),
  se  = c(obsSE["t6_removed"],obsSE["all_removed"],obsSE["current_smoker"],modSE["CS_t6"],modSE["BJS_t6"]))
tabA[, `:=`(MDE_pp = 100*mde(se), power_at_0.35pp = powr(0.0035, se), power_at_0.04pp = powr(0.0004, se))]
print(tabA[, .(estimator, SE=round(se,5), MDE_pp=round(MDE_pp,3),
               power_035=round(power_at_0.35pp,3), power_004=round(power_at_0.04pp,3))])
fwrite(tabA, paste0(OUT,"res_power_mde.csv"))

# ---- (C) plausibility bound: mediated policy -> tooth-loss effect ----
dSmk   <- abs(obsB["current_smoker"])          # policy -> smoking prevalence, per $1  (~0.0035)
exRisk <- 0.12                                  # excess prob. of >=6-teeth loss attributable to smoking (smokers vs non), upper bound
realiz <- 0.30                                  # fraction of that excess reversible/avoidable within an 18-y window (generous)
medEff <- dSmk * exRisk * realiz
cat(sprintf("\n==== (C) Plausible mediated effect on >=6-teeth loss per $1 ~= %.4f (%.3f pp)\n",
            medEff, 100*medEff))
cat(sprintf("     vs TWFE MDE %.3f pp -> mediated effect is ~%.0fx below the MDE\n",
            100*mde(obsSE["t6_removed"]), mde(obsSE["t6_removed"])/medEff))

# ============================ (B) Monte Carlo on the real design ============================
# calibrate a state-year outcome-noise SD so the null-model cluster-robust SE == observed SE.
sim_one <- function(outcome, beta, sigma_u, mundlak=FALSE){
  pp <- P[, .(state_id, year, n, tax=tax_fed_state)]
  base <- mean(P[[outcome]]); a_s <- P[, .(fe=mean(get(outcome))-base), by=state_id]
  l_t  <- P[, .(fe=mean(get(outcome))-base), by=year]
  pp <- merge(merge(pp, a_s, by="state_id"), l_t, by="year", suffixes=c(".s",".t"))
  taxc <- pp$tax - mean(pp$tax)
  mu   <- base + pp$fe.s + pp$fe.t + beta*taxc + rnorm(nrow(pp), 0, sigma_u)
  # cell mean = latent prob + tiny binomial sampling noise (n huge -> negligible)
  pp$y <- pmin(pmax(mu,0.001),0.999) + rnorm(nrow(pp), 0, sqrt(pmax(mu*(1-mu),1e-4)/pp$n))
  f <- if (mundlak) y ~ tax + txbar_s + txbar_t | state_id + year else y ~ tax | state_id + year
  if (mundlak){ pp[, txbar_s:=mean(tax), by=state_id]; pp[, txbar_t:=mean(tax), by=year] }
  m <- feols(f, data=pp, weights=~n, cluster=~state_id, notes=FALSE)
  ct <- coeftable(m)["tax",]; c(est=ct[1], se=ct[2], rej=as.numeric(abs(ct[1]/ct[2])>zc))
}
# calibrate sigma_u for t6 so median null SE ~ observed
calib <- function(outcome, target){
  g <- seq(0.002, 0.030, by=0.002); best<-g[1]; bd<-Inf
  for (s in g){ ses <- replicate(60, sim_one(outcome,0,s)["se.Std. Error"]); d<-abs(median(ses)-target); if(d<bd){bd<-d;best<-s} }
  best
}
cat("\n==== (B) Monte Carlo: calibrating state-year noise SD ====\n")
sig_t6  <- calib("t6_removed",  obsSE["t6_removed"]);  cat("sigma_u (>=6 teeth)  =", round(sig_t6,4), "\n")
sig_ed  <- calib("all_removed", obsSE["all_removed"]); cat("sigma_u (edentulism) =", round(sig_ed,4), "\n")

REP <- 800
grid <- c(0, 0.0005, 0.001, 0.0015, 0.002, 0.0025, 0.0035, 0.005, 0.0075, 0.010)  # RD per $1
run_curve <- function(outcome, sigma_u, mundlak=FALSE){
  rbindlist(lapply(grid, function(b){
    R <- replicate(REP, sim_one(outcome,b,sigma_u,mundlak))
    data.table(outcome=outcome, model=if(mundlak)"Mundlak" else "TWFE", beta_pp=100*b,
               power=mean(R["rej",]), meanSE=mean(R["se.Std. Error",]))
  }))
}
cat("running power curves (REP =", REP, ") ...\n")
curves <- rbindlist(list(
  run_curve("t6_removed",  sig_t6, FALSE),
  run_curve("t6_removed",  sig_t6, TRUE),
  run_curve("all_removed", sig_ed, FALSE)))
fwrite(curves, paste0(OUT,"res_power_curve.csv"))
cat("\n==== power curve (>=6 teeth) ====\n"); print(curves[outcome=="t6_removed"])
cat("size under null (beta=0):\n"); print(curves[beta_pp==0, .(outcome,model,size=round(power,3))])

# ---- MDE-at-80% read off the simulated curve ----
mde80 <- curves[, {i<-which(power>=0.8)[1]; .(MDE80_pp=if(is.na(i)) NA else beta_pp[i])}, by=.(outcome,model)]
cat("\nsimulated MDE at 80% power (pp):\n"); print(mde80)

# ---- figure ----
cur <- curves[outcome=="t6_removed"]
cur[, Estimator := factor(model, levels=c("TWFE","Mundlak"),
      labels=c("TWFE (primary)","Extended TWFE / Mundlak"))]
g <- ggplot(cur, aes(beta_pp, power, colour=Estimator)) +
  geom_hline(yintercept=0.8, linetype="dashed", colour="grey50") +
  geom_hline(yintercept=0.05, linetype="dotted", colour="grey60") +
  geom_line(linewidth=0.8) + geom_point(size=1.6) +
  geom_vline(xintercept=100*medEff, linetype="dotdash", colour="#b03030") +
  annotate("text", x=100*medEff+0.02, y=0.35, hjust=0, size=3, colour="#b03030",
           label="plausible mediated\neffect (~0.04 pp)") +
  annotate("text", x=0.35, y=0.9, hjust=0, size=3, colour="#1b7837",
           label="smoking first-stage\n(|effect| 0.35 pp, detected)") +
  scale_x_continuous("True effect on loss of >=6 teeth (pp per $1.00 tax)") +
  scale_y_continuous("Power (Pr reject H0 at 5%)", limits=c(0,1)) +
  scale_colour_manual(values=c("#1f4e79","#d95f02")) +
  labs(title="Statistical power of the difference-in-differences design",
       subtitle="Monte Carlo on the actual 51-state x 15-year BRFSS panel; state-clustered inference") +
  theme_bw(base_size=10) + theme(legend.position="bottom", plot.title=element_text(face="bold"))
ggsave(paste0(OUT,"figR_power.png"), g, width=7.2, height=5, dpi=160)
cat("\nsaved figR_power.png\n== POWER ANALYSIS DONE ==\n")
