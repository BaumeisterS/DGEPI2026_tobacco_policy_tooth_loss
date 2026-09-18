# Estimator comparison figure — tobacco tax -> tooth loss (JDR R2)
# ALL values transcribed verbatim from the R2 files; nothing recomputed.
#   TWFE (covariate-adjusted, main)  : R2 Table3.docx  (cigarette tax, current year)
#   Heterogeneity-robust estimators  : R2 supplement, Supplementary Table 4
# Units: percentage points, 95% CI.

suppressPackageStartupMessages({
  library(ggplot2); library(dplyr); library(ragg)
})
set.seed(20260806)

ink <- "#333F48"; blue <- "#00578A"; cyan <- "#009DD1"
teal <- "#006E89"; green <- "#7AB51D"; grey_ne <- "#8A9199"

d <- tibble::tribble(
  ~outcome,                ~block, ~estimator,                        ~est,  ~lo,   ~hi,   ~src,
  # ---- Loss of >=6 teeth -------------------------------------------------
  "Loss of \u22656 teeth", "cont", "TWFE",  -0.19, -0.53, 0.15,  "main",
  "Loss of \u22656 teeth", "cont", "Gardner two-stage",                -0.08, -0.26, 0.10,  "supp",
  "Loss of \u22656 teeth", "cont", "Two-way Mundlak (state-year)",          0.16, -1.10, 1.42,  "supp",
  "Loss of \u22656 teeth", "coh",  "Callaway\u2013Sant'Anna",           0.71,  0.08, 1.33,  "supp",
  "Loss of \u22656 teeth", "coh",  "BJS imputation",                   -0.20, -1.19, 0.79,  "supp",
  "Loss of \u22656 teeth", "coh",  "Sun\u2013Abraham",                   NA, NA, NA,  "supp",
  # ---- Complete edentulism ----------------------------------------------
  "Complete edentulism",   "cont", "TWFE",   0.08, -0.14, 0.31,  "main",
  "Complete edentulism",   "cont", "Gardner two-stage",                 0.04, -0.08, 0.17,  "supp",
  "Complete edentulism",   "cont", "Two-way Mundlak (state-year)",          0.20, -0.51, 0.91,  "supp",
  "Complete edentulism",   "coh",  "Callaway\u2013Sant'Anna",           0.44,  0.06, 0.81,  "supp",
  "Complete edentulism",   "coh",  "BJS imputation",                    0.28, -0.42, 0.98,  "supp",
  "Complete edentulism",  "coh",  "Sun\u2013Abraham",                   NA, NA, NA,  "supp",
  # ---- Current smoking (positive control) --------------------------------
  "Current smoking",       "cont", "TWFE",  -0.35, -0.56, -0.13, "main",
  "Current smoking",       "cont", "Gardner two-stage",                -0.09, -0.20, 0.01,  "supp",
  "Current smoking",       "cont", "Two-way Mundlak (state-year)",     -0.09, -0.76, 0.58,  "supp",
  "Current smoking",       "coh",  "Callaway\u2013Sant'Anna",           0.93, -1.76, 3.63,  "supp",
  "Current smoking",       "coh",  "Sun\u2013Abraham",                   0.67, -0.08, 1.42,  "supp",
  "Current smoking",       "coh",  "BJS imputation",                   -0.30, -0.76, 0.15,  "supp"
)
# NOTE: the Sun-Abraham high-tax rows are omitted by design choice for this slide.
# In R2 they are dashes: "the Sun-Abraham variance is undefined and the group-time
# estimator does not converge" (Suppl. Table 4 note) -- state this aloud on the slide.

est_order <- c("BJS imputation", "Sun\u2013Abraham", "Callaway\u2013Sant'Anna",
               "Two-way Mundlak (state-year)", "Gardner two-stage",
               "TWFE")

d <- d |>
  mutate(
    estimator = factor(estimator, levels = est_order),
    outcome   = factor(outcome, levels = c("Current smoking", "Loss of \u22656 teeth", "Complete edentulism")),
    block     = factor(block, levels = c("cont", "coh"),
                       labels = c("Continuous dose\nper +$1.00/pack",
                                  "High-tax cohort\n(\u2265$3.00/pack)")),
    series = case_when(
      src == "main" ~ "TWFE — covariate-adjusted, individual level",
      TRUE          ~ "Heterogeneity-robust — unadjusted, state-year panel"),
    series = factor(series, levels = c(
      "TWFE — covariate-adjusted, individual level",
      "Heterogeneity-robust — unadjusted, state-year panel"))
  )

p <- ggplot(d, aes(x = est, y = estimator, colour = series)) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = ink, linewidth = 0.45) +
  geom_errorbarh(aes(xmin = lo, xmax = hi), height = 0, linewidth = 0.95, na.rm = TRUE) +
  geom_point(size = 2.9, na.rm = TRUE) +
  facet_grid(block ~ outcome, scales = "free", space = "free_y") +
  scale_colour_manual(values = c(ink, blue), name = NULL) +
  scale_x_continuous(n.breaks = 4,
                     labels = function(x) formatC(x, format = "f", digits = 1)) +
  labs(x = "Percentage points (95% CI)", y = NULL) +
  guides(colour = guide_legend(nrow = 1,
                               override.aes = list(linewidth = 1.4, size = 3.1))) +
  theme_classic(base_size = 14) +
  theme(
    text            = element_text(colour = ink),
    axis.text       = element_text(colour = ink, size = 14),
    axis.text.y     = element_text(hjust = 0),
    axis.title.x    = element_text(colour = ink, size = 14, margin = margin(t = 9)),
    axis.line       = element_line(colour = ink, linewidth = 0.5),
    axis.ticks      = element_line(colour = ink, linewidth = 0.5),
    strip.background = element_blank(),
    strip.text.x    = element_text(colour = ink, face = "bold", size = 15,
                                   margin = margin(b = 7)),
    strip.text.y    = element_text(colour = blue, face = "bold", size = 13,
                                   angle = 0, hjust = 0, margin = margin(l = 8)),
    panel.grid.major.x = element_line(colour = "grey92", linewidth = 0.4),
    panel.spacing.x = unit(1.3, "lines"),
    panel.spacing.y = unit(1.1, "lines"),
    legend.position = "bottom",
    legend.text     = element_text(size = 13, colour = ink),
    legend.key.width = unit(1.4, "lines"),
    legend.margin   = margin(t = 4),
    plot.margin     = margin(10, 8, 6, 6)
  )

# Output goes next to this script. Run with the working directory set to
# the script's folder:  Rscript estimator_comparison_r2.R
out <- "estimator_comparison_r2.png"
ragg::agg_png(out, width = 32.0, height = 10.2, units = "cm", res = 300, background = "white")
print(p)
invisible(dev.off())
cat("written:", out, "\n")
