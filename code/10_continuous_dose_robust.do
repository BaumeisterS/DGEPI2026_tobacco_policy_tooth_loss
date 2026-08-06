* ===========================================================================
* JDR-26-0534 REVISION — continuous-dose heterogeneity-robust estimators
*   Two estimators that identify a per-$1.00 dose effect, reported alongside
*   the cohort-based robust estimators (Callaway-Sant'Anna, Sun-Abraham,
*   Borusyak-Jaravel-Spiess) in the supplementary robustness table:
*
*     A. Extended two-way fixed effects / two-way Mundlak (Wooldridge 2025)
*        pooled OLS with unit and period means of the dose, on the weighted
*        state-year panel.
*     B. Gardner (2022) two-stage difference-in-differences, identified from
*        the high-tax (>= $3.00/pack) cohort so that not-yet-treated states
*        form a valid comparison group.
*
*   Both are UNADJUSTED (no individual covariates); the covariate-adjusted
*   primary estimates come from 03_primary_estimates.R.
*   Output: output\res_continuous_dose.csv
* ===========================================================================
clear all
set more off
set varabbrev off
set type double

* run Stata with the repository root as the working directory
cap mkdir "output"
cap log close _all
log using "output\continuous_dose_robust.log", replace text

foreach p in reghdfe ftools did2s {
    cap which `p'
    if _rc cap ssc install `p', replace
}

tempname P
postfile `P' str14 estimator str8 policy str16 outcome double b se cil ciu ///
    using "output\res_continuous_dose.dta", replace

* ===========================================================================
* A. Extended TWFE / two-way Mundlak (Wooldridge 2025) — collapsed panel
* ===========================================================================
use final_smoking_analysis_dataset, clear
collapse (mean) current_smoker quitting all_removed t6_removed ///
         tax_fed_state tax_state price_state (max) rest mall (count) n=fips, ///
         by(state_id state_abbrev year)
xtset state_id year

foreach pol in tax price {
    local d = cond("`pol'"=="tax","tax_fed_state","price_state")
    foreach out in current_smoker all_removed t6_removed {
        * two-way Mundlak (CRE): pooled OLS with unit and period means of the dose
        cap drop m_unit m_time
        bysort state_id: egen m_unit = mean(`d')
        bysort year:     egen m_time = mean(`d')
        cap noisily regress `out' `d' m_unit m_time [aw=n], cluster(state_id)
        if !_rc post `P' ("CRE_Mundlak") ("`pol'") ("`out'") (_b[`d']) (_se[`d']) ///
            (_b[`d']-1.96*_se[`d']) (_b[`d']+1.96*_se[`d'])
    }
}

* ===========================================================================
* B. Gardner (2022) two-stage DiD on the full individual data
*    treatment = D_high_tax (high-tax cohort) so the comparison pool is the
*    not-yet-treated states; the second stage is the continuous dose change.
* ===========================================================================
use final_smoking_analysis_dataset, clear
capture confirm variable fips
if _rc gen fips = state_id
bysort fips (year): gen double tax_base = tax_fed_state[1]
gen double tax_change = tax_fed_state - tax_base
gen byte high_tax = (tax_fed_state >= 3.00)
by fips: egen first_high_tax = min(cond(high_tax, year, .))
gen byte D_high_tax = (first_high_tax < . & year >= first_high_tax)

foreach out in current_smoker all_removed t6_removed {
    cap noisily did2s `out', first_stage(i.fips i.year) ///
        second_stage(c.tax_change) treatment(D_high_tax) cluster(state_id)
    if !_rc post `P' ("did2s_Gardner") ("tax") ("`out'") (_b[tax_change]) (_se[tax_change]) ///
        (_b[tax_change]-1.96*_se[tax_change]) (_b[tax_change]+1.96*_se[tax_change])
}

postclose `P'

use "output\res_continuous_dose.dta", clear
* percentage-point scale, as reported in the supplementary table
foreach v in b se cil ciu {
    gen double `v'_pp = `v'*100
}
list estimator policy outcome b_pp cil_pp ciu_pp, noobs sepby(estimator)
export delimited "output\res_continuous_dose.csv", replace

log close
