# Clean power figure for the Reviewer-1 rebuttal (reads res_power_curve.csv).
suppressMessages({library(data.table); library(ggplot2)})
OUT<-"output/"
cur <- fread(paste0(OUT,"res_power_curve.csv"))[outcome=="t6_removed"]
cur[, Estimator := factor(model, levels=c("TWFE","Mundlak"),
      labels=c("TWFE / extended-TWFE (primary)","Two-way Mundlak (secondary)"))]

# plausible mediated-effect band (0.013 pp point bound; 0.04 pp conservative benchmark)
med_lo <- 0.013; med_hi <- 0.04
mde_analytic <- 0.49          # analytic MDE (pp) at 80% power for >=6-teeth TWFE

g <- ggplot(cur, aes(beta_pp, power, colour=Estimator, shape=Estimator)) +
  annotate("rect", xmin=med_lo, xmax=med_hi, ymin=0, ymax=1, alpha=0.10, fill="#b03030") +
  geom_hline(yintercept=0.80, linetype="dashed", colour="grey45") +
  geom_hline(yintercept=0.05, linetype="dotted", colour="grey55") +
  geom_vline(xintercept=mde_analytic, linetype="longdash", colour="#1f4e79", linewidth=0.4) +
  geom_line(linewidth=0.8) + geom_point(size=1.9) +
  annotate("text", x=med_hi+0.015, y=0.62, hjust=0, size=2.9, colour="#b03030",
           label="Largest plausible mediated\npolicy-> tooth-loss effect\n(~0.01-0.04 pp): power ~ 0.05") +
  annotate("text", x=mde_analytic+0.02, y=0.30, hjust=0, size=2.9, colour="#1f4e79",
           label="MDE ~ 0.49 pp\n(80% power)") +
  annotate("text", x=0.52, y=0.90, hjust=0, size=2.9, colour="#1b7837",
           label="Smoking first-stage effect (0.35 pp)\ndetected at 0.88 power in its own outcome") +
  scale_x_continuous("True effect on loss of >= 6 teeth (percentage points per $1.00 combined tax)",
                     breaks=c(0,0.04,0.25,0.49,0.75,1.0)) +
  scale_y_continuous("Power  (Pr[ reject H0 : tau = 0 ]  at 5%)", limits=c(0,1),
                     breaks=seq(0,1,0.2)) +
  scale_colour_manual(values=c("#1f4e79","#d95f02")) +
  labs(title="Statistical power of the difference-in-differences design",
       subtitle="Monte Carlo (800 reps) on the actual 51-state x 15-year BRFSS panel; state-clustered inference") +
  theme_bw(base_size=10) +
  theme(legend.position="bottom", legend.title=element_blank(),
        plot.title=element_text(face="bold"), plot.subtitle=element_text(size=8.5))
ggsave(paste0(OUT,"figR_power.png"), g, width=7.4, height=5.0, dpi=200)
ggsave(paste0(OUT,"figR_power.tif"), g, width=7.4, height=5.0, dpi=300, compression="lzw")
cat("saved figR_power.png / .tif\n")
