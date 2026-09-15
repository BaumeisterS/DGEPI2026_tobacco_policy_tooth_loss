# Can Tobacco Control Policies Prevent Tooth Loss? A Difference-in-Differences Study

Slides and analysis code for the oral presentation at the **21st Annual Meeting of the
German Society for Epidemiology (DGEpi 2026)**, Ulm, 24 September 2026 — *Causal Inference*
session.

**Sebastian-Edgar Baumeister**¹, Benjamin W. Chaffee², Birte Holtfreter³, Stefan Listl⁴

¹ Institute of Health Services Research in Dentistry, University of Münster, Germany
² University of California San Francisco, USA
³ University Medicine Greifswald, Germany
⁴ Heidelberg University Hospital, Germany

The underlying paper is in print in the *Journal of Dental Research*.

---

## What this study does

Cigarette taxes and prices reduce smoking, and smoking is the dominant modifiable cause of
periodontitis and tooth loss. Whether tobacco-control policy therefore reduces **population
tooth loss** has rarely been tested. Using the Behavioral Risk Factor
Surveillance System (BRFSS) 1995–2012 (15 cycles, N = 3,840,519, 51 states), we estimate the
effect of state cigarette tax/price and smoke-free laws on complete edentulism and loss of
≥6 teeth, with current smoking and quitting as positive controls and seat-belt use and
smoke-detector ownership as negative controls.

The talk carries a **secondary methodological aim**: benchmarking heterogeneity-robust
difference-in-differences estimators against classical two-way fixed effects in a design that
combines *staggered binary* (smoke-free laws) and *continuous* (tax/price) treatments.

**Headline findings.** Cigarette taxes and prices reduce smoking; there is no detectable
effect on tooth loss over the 1995–2012 window. The null is a limit of the design — the
plausible mediated effect (≈0.01–0.04 percentage points) lies far below the minimum
detectable effect (≈0.49 pp) — so it is an equivalence statement, not evidence of absence.

Indoor smoking bans reduced neither smoking nor tooth loss, and the **mall/grocery ban fails a
negative-control test** (smoke-detector testing, −1.17 pp; 95% CI −2.27, −0.08), so those ban
estimates are not interpreted causally. Taxes and prices pass both negative controls.

## Repository contents

```
slides/           DGEPI2026_Baumeister.pdf   the conference presentation
slides/figures/   *.R                        scripts for the two slide-only figures
code/             01–10                      the analysis pipeline (Stata, R, Python, LaTeX)
data/             README.txt                 how to obtain the public source data (none distributed)
```

The deck is 23 pages: 15 presented within the 12-minute slot, then eight backup
slides shown only if a question calls for them. The backups run B1 (what the
estimand averages over), B1a–B1c (which 2×2 comparisons exist under staggered
adoption, what TWFE does with them, and what the heterogeneity-robust families do
instead), then B2–B5 (inference with 51 clusters, survey design and weighting, the
causal graph and Δ-SWIG, and SUTVA).

`slides/figures/` holds the two figures that are not analysis output.
`estimator_comparison_r2.R` plots estimates transcribed verbatim from Tables 2–3 and
Supplementary Table 4 — it recomputes nothing. `estimator_families.R` draws a
**schematic** (not data) of which panel cells each estimator family uses as treated,
as comparison, or as the basis for an imputed Y(0). Both write their PNG next to the
script; run them with the working directory set to that folder.

**No data are distributed.** All sources are public; `data/README.txt` documents the expected
layout and where to obtain each file.

## Analysis pipeline

| Script | Purpose |
|--------|---------|
| `01_build_analysis_dataset.do` | assemble the BRFSS × policy panel |
| `02_descriptives_rollout_table1.do` | descriptives and policy roll-out |
| `03_primary_estimates.R` | primary covariate-adjusted two-way fixed-effects models |
| `04_run_robust.R`, `04a`, `04b`, `04c` | heterogeneity-robust estimators and event studies |
| `05_causal_graph.py`, `09_causal_graph_swig.tex` | causal DAG and Δ-SWIG figure |
| `06_power_analysis.R`, `07_power_figure.R` | minimum detectable effect and Monte-Carlo power |
| `08_robust_ci_cr2.R` | CR2 / Satterthwaite small-cluster inference |
| `10_continuous_dose_robust.do` | continuous-dose estimators and high-dose cohorts |

Estimators: Callaway–Sant'Anna (2021) and Sun–Abraham (2021) for group-time effects,
Borusyak–Jaravel–Spiess (2024) and Gardner two-stage (2022) for imputation; the continuous dose
is handled as high-dose cohorts following Callaway, Goodman-Bacon & Sant'Anna (2024). The
extended two-way fixed-effects (two-way Mundlak) regression of Wooldridge (2025) is reported as
a **specification check rather than a heterogeneity-robust alternative** — Wooldridge's result is
that it is algebraically equivalent to two-way fixed effects.

## Software environment

| Component | Version | Key packages |
|-----------|---------|--------------|
| Stata | 19.5 | `reghdfe`, `ftools`, `rangestat`, `did2s` |
| R | 4.6.0 | `data.table`, `haven`, `fixest`, `did`, `didimputation`, `ggplot2`, `clubSandwich` |
| Python | 3.11+ | `matplotlib` |
| LaTeX | TeX Live / TinyTeX | `tikz` |

Standard errors are clustered by state throughout. Primary estimates are covariate-adjusted
(age, sex, race/ethnicity, education, diagnosed diabetes, recent dental visit) on unweighted
individual-level data; household income is excluded because of high item nonresponse.

## Licence

Code is released under the GNU General Public License v3.0 (see `LICENSE`). The slides are
© the authors.
