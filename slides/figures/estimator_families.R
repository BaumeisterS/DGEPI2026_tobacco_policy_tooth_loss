# Which cells does each estimator family actually compare?
# A schematic for the DGEpi 2026 deck, slide 6.
#
# Nothing here is data: it is a stylised 6-state x 8-year panel with staggered
# adoption, used only to show WHICH cells each family treats as treated, as
# comparison, or as the basis for an imputed Y(0). Labelled as a schematic on
# the slide so it is never mistaken for results.

suppressPackageStartupMessages({
  library(ggplot2); library(dplyr); library(tidyr); library(ragg)
})

ink   <- "#333F48"
blue  <- "#00578A"   # treated / post
cyan  <- "#009DD1"   # comparison cells actually used
grey  <- "#C9CFD3"   # present but not used by this family
amber <- "#B8860B"

states <- paste0("S", 1:6)
years  <- 1:8
# adoption year per state; S5 and S6 never adopt (never-treated)
adopt  <- c(S1 = 3, S2 = 4, S3 = 6, S4 = 7, S5 = Inf, S6 = Inf)

grid <- expand.grid(state = states, year = years, stringsAsFactors = FALSE) |>
  mutate(
    g       = adopt[state],
    treated = year >= g
  )

# --- role of each cell under each family ----------------------------------
# Group-time (Callaway-Sant'Anna): for cohort g = 6 (S3), post cells are the
# treated contrast; comparison = not-yet-treated cells in the same periods.
gt <- grid |>
  mutate(
    role = case_when(
      state == "S3" & year >= 6                    ~ "[1] treated cohort, g = 6",
      !treated & year >= 5                         ~ "[1] clean comparison",
      TRUE                                         ~ "[1] not used by this family"
    ),
    panel = "1. Group-time ATT\nCallaway-Sant'Anna, Sun-Abraham"
  )

# Imputation (BJS / Gardner): fit Y(0) on ALL untreated cells, then predict
# into every treated cell and average the residuals.
imp <- grid |>
  mutate(
    role = case_when(
      !treated ~ "[2] untreated cells: fit Y(0)",
      TRUE     ~ "[2] treated cells: impute Y(0), average residuals"
    ),
    panel = "2. Imputation\nBorusyak-Jaravel-Spiess, Gardner"
  )

# Pooled TWFE / two-way Mundlak: every cell enters one regression.
pool <- grid |>
  mutate(
    role  = "[3] every cell, one regression, no clean/contaminated split",
    panel = "3. Pooled TWFE / two-way Mundlak\nWooldridge"
  )

d <- bind_rows(gt, imp, pool) |>
  mutate(
    panel = factor(panel, levels = c(
      "1. Group-time ATT\nCallaway-Sant'Anna, Sun-Abraham",
      "2. Imputation\nBorusyak-Jaravel-Spiess, Gardner",
      "3. Pooled TWFE / two-way Mundlak\nWooldridge")),
    role = factor(role, levels = c(
      "[1] treated cohort, g = 6", "[1] clean comparison", "[1] not used by this family",
      "[2] untreated cells: fit Y(0)", "[2] treated cells: impute Y(0), average residuals",
      "[3] every cell, one regression, no clean/contaminated split"))
  )

pal <- c(
  "[1] treated cohort, g = 6"          = blue,
  "[1] clean comparison"                = cyan,
  "[1] not used by this family"                   = grey,
  "[2] untreated cells: fit Y(0)"                       = cyan,
  "[2] treated cells: impute Y(0), average residuals" = blue,
  "[3] every cell, one regression, no clean/contaminated split"     = blue
)

# a thin outline marks cells that are treated in reality, whatever the family does
p <- ggplot(d, aes(x = year, y = state, fill = role)) +
  geom_tile(colour = "white", linewidth = 1.1) +
  geom_tile(data = filter(d, treated), fill = NA, colour = ink,
            linewidth = 0.5, linetype = "solid") +
  facet_wrap(~ panel, nrow = 1) +
  scale_fill_manual(values = pal, name = NULL,
                    guide = guide_legend(ncol = 2, byrow = FALSE)) +
  scale_x_continuous(breaks = years, expand = c(0, 0)) +
  scale_y_discrete(limits = rev(states), expand = c(0, 0)) +
  labs(x = "Period", y = NULL,
       caption = "Schematic, not data. Outlined cells are treated in reality; fill shows the role each family gives them. S5-S6 never adopt.") +
  theme_minimal(base_size = 15) +
  theme(
    text             = element_text(colour = ink),
    axis.text        = element_text(colour = ink, size = 13),
    axis.title.x     = element_text(colour = ink, size = 13, margin = margin(t = 6)),
    strip.text       = element_text(colour = ink, face = "bold", size = 14,
                                    lineheight = 1.15, margin = margin(b = 8)),
    panel.grid       = element_blank(),
    panel.spacing    = unit(1.5, "lines"),
    legend.position  = "bottom",
    legend.text      = element_text(size = 13, colour = ink),
    legend.key.size  = unit(0.95, "lines"),
    plot.caption     = element_text(colour = "#58585A", size = 11, hjust = 0,
                                    margin = margin(t = 10)),
    plot.margin      = margin(6, 8, 4, 6)
  )

# Output goes next to this script. Run with the working directory set to
# the script's folder:  Rscript estimator_families.R
out <- "estimator_families.png"
ragg::agg_png(out, width = 30, height = 11.6, units = "cm", res = 300, background = "white")
print(p)
invisible(dev.off())
cat("written:", out, "\n")
