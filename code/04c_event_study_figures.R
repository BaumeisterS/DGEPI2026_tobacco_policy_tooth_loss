# Event-study figures from es_R.csv (prefer CS; fall back to SA where CS absent).
suppressMessages({library(data.table); library(ggplot2)})
setwd("."); OUT<-"output/"
ES <- fread(paste0(OUT,"es_R.csv"))
LAB <- c(hightax="High tax (>=$3)", highprice="High price (>=$6)", rest="Restaurant ban", mall="Mall/grocery ban")
OLAB<- c(current_smoker="Current smoking", quitting="Quitting", all_removed="Edentulism", t6_removed="Loss of >=6 teeth")
base <- function(dat,title,nm,wf){
  dat[, period:=ifelse(et<0,"Pre-treatment","Post-treatment")]
  g <- ggplot(dat, aes(et,att,color=period)) +
    geom_hline(yintercept=0,linetype="dashed",color="grey40") +
    geom_vline(xintercept=-0.5,linetype="dotted",color="grey60") +
    geom_pointrange(aes(ymin=att-1.96*se,ymax=att+1.96*se),size=0.3) + wf +
    scale_color_manual(values=c("Pre-treatment"="#1b7837","Post-treatment"="#d95f02")) +
    labs(title=title,x="Years relative to adoption",y="Probability",color=NULL) +
    theme_bw(base_size=9)+theme(legend.position="bottom",strip.background=element_rect(fill="grey92"),
      plot.title=element_text(face="bold"))
  ggsave(paste0(OUT,nm),g,width=8.5,height=7,dpi=160); cat("fig",nm,nrow(dat),"\n")
}
# Fig 1: behavioral outcomes, all 4 treatments (CS), 4x2 grid
d1 <- ES[estimator=="CS" & outcome %in% c("current_smoker","quitting") & et>=-5 & et<=6 & abs(se)<0.5]
d1[, Outcome:=factor(OLAB[outcome],levels=OLAB[c("current_smoker","quitting")])]
d1[, Policy :=factor(LAB[trt],levels=LAB)]
base(d1,"Callaway-Sant'Anna event studies: smoking outcomes","figR_es_behavior.png",
     facet_grid(Outcome~Policy, scales="free_y"))
# Fig 2: tooth-loss outcomes, high-tax cohort (the estimable cohort), CS
d2 <- ES[estimator=="CS" & trt=="hightax" & outcome %in% c("all_removed","t6_removed") & et>=-5 & et<=6 & abs(se)<0.5]
d2[, Outcome:=factor(OLAB[outcome],levels=OLAB[c("all_removed","t6_removed")])]
d2[, Policy :=factor("High tax (>=$3)")]
base(d2,"Callaway-Sant'Anna event studies: tooth loss (high-tax cohort)","figR_es_toothloss.png",
     facet_grid(Outcome~Policy, scales="free_y"))
cat("FIG DONE\n")
