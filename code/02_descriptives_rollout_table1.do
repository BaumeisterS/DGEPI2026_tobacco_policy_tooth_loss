* ===========================================================================
* JDR-26-0534 REVISION — PART 1
*   Descriptives, policy rollout, stratified Table 1, and the regression
*   backbone: lag-stratified, covariate-adjusted, region x year FE,
*   and negative-control-outcome models (TWFE via reghdfe).
*   Output: CSVs in output\  (consumed by python-docx later)
* ===========================================================================
clear all
set more off
set varabbrev off
set type double

* run Stata with this folder as the working directory
cap mkdir "output"
cap log close _all
log using "output\revision_part1.log", replace text

foreach p in reghdfe ftools {
    cap which `p'
    if _rc cap ssc install `p', replace
}

use final_smoking_analysis_dataset, clear
sort state_id year

* ---------- treatment constructions (mirror submission) ----------
by state_id (year): gen tax_base = tax_fed_state[1]
gen tax_change   = tax_fed_state - tax_base
gen byte high_tax = (tax_fed_state >= 3.00)

by state_id (year): gen price_base = price_state[1]
gen price_change   = price_state - price_base
gen byte high_price = (price_state >= 6.00)

* ever-treated (state level) for stratified Table 1 + rollout
by state_id: egen ever_high_tax  = max(high_tax)
by state_id: egen ever_rest      = max(rest)
by state_id: egen ever_mall      = max(mall)

* ---------- census region from state_abbrev ----------
gen byte region = .
replace region=1 if inlist(state_abbrev,"CT","ME","MA","NH","RI","VT","NJ","NY","PA")
replace region=2 if inlist(state_abbrev,"IL","IN","MI","OH","WI","IA","KS","MN","MO")
replace region=2 if inlist(state_abbrev,"NE","ND","SD")
replace region=3 if inlist(state_abbrev,"DE","FL","GA","MD","NC","SC","VA","DC","WV")
replace region=3 if inlist(state_abbrev,"AL","KY","MS","TN","AR","LA","OK","TX")
replace region=4 if inlist(state_abbrev,"AZ","CO","ID","MT","NV","NM","UT","WY")
replace region=4 if inlist(state_abbrev,"AK","CA","HI","OR","WA")
label define reg 1 "Northeast" 2 "Midwest" 3 "South" 4 "West"
label values region reg

* ---------- covariates (explicit missing categories preserve N) ----------
gen byte fem_c  = female
gen byte race_c = racegr
replace  race_c = 9 if missing(race_c)
gen byte edu_c  = educa
replace  edu_c  = 9 if missing(edu_c)
gen byte inc_c  = income
replace  inc_c  = 5 if missing(inc_c)
gen byte dia_c  = diabetes
replace  dia_c  = 9 if missing(dia_c)
gen byte den_c  = dentist12
replace  den_c  = 9 if missing(den_c)
global COV i.fem_c c.age c.age2 i.race_c i.edu_c i.inc_c i.dia_c i.den_c

compress

* ===========================================================================
* A. POLICY ROLLOUT — number of states with each policy by year
* ===========================================================================
preserve
    collapse (max) rest mall high_tax high_price, by(state_id year)
    collapse (sum) n_rest=rest n_mall=mall n_hightax=high_tax n_highprice=high_price ///
             (count) n_states=rest, by(year)
    export delimited "output\rollout_by_year.csv", replace
restore

preserve
    bysort state_id: keep if _n==1
    keep state_id state_name state_abbrev region first_rest_ban first_mall_ban ///
         ever_high_tax ever_rest ever_mall
    export delimited "output\state_adoption.csv", replace
restore

* ===========================================================================
* B. DESCRIPTIVES BY YEAR
* ===========================================================================
preserve
    collapse (mean) female age current_smoker quitting all_removed t6_removed ///
             tax_fed_state price_state rest mall (count) n=female, by(year)
    export delimited "output\descriptives_by_year.csv", replace
restore

* ===========================================================================
* C. STRATIFIED TABLE 1 — baseline characteristics by ever-treated status
* ===========================================================================
foreach g in ever_high_tax ever_rest ever_mall {
    preserve
        gen one=1
        collapse (mean) female age current_smoker quitting all_removed t6_removed ///
                 diabetes dentist12 (sd) age_sd=age (sum) n=one, by(`g')
        gen strata="`g'"
        rename `g' grp
        export delimited "output\table1_`g'.csv", replace
    restore
}

* ===========================================================================
* D. POSTFILE — lag-stratified, adjusted/unadjusted, neg-control, regxyear FE
* ===========================================================================
tempname P
postfile `P' str10 block str8 policy str16 outcome str8 lag byte adj ///
    double b se cil ciu n using "output\res_part1.dta", replace

* ---- helper: run reghdfe and post ----
* (inline to keep postfile scope simple)

* (D1) LAG-STRATIFIED: tooth-loss outcomes, continuous tax & price
foreach pol in tax price {
    foreach lag in c0 L1 L5 r10 {
        if "`pol'"=="tax" {
            local v tax_fed_state
            if "`lag'"=="L1"  local v tax_fed_state_lag1
            if "`lag'"=="L5"  local v tax_fed_state_lag5
            if "`lag'"=="r10" local v tax_fed_state_10y_avg
        }
        else {
            local v price_state
            if "`lag'"=="L1"  local v price_lag1
            if "`lag'"=="L5"  local v price_lag5
            if "`lag'"=="r10" local v price_10y_avg
        }
        foreach out in all_removed t6_removed {
            foreach adj in 0 1 {
                local ctrl ""
                if `adj'==1 local ctrl $COV
                cap noisily reghdfe `out' `v' `ctrl', absorb(state_id year) cluster(state_id)
                if !_rc {
                    local b=_b[`v']
                    local se=_se[`v']
                    local df=e(df_r)
                    local cr=cond(!mi(`df'),invttail(`df',0.025),1.96)
                    post `P' ("lagstrat") ("`pol'") ("`out'") ("`lag'") (`adj') ///
                        (`b') (`se') (`b'-`cr'*`se') (`b'+`cr'*`se') (e(N))
                }
            }
        }
    }
}

* (D2) LAG-STRATIFIED: tooth-loss outcomes, binary bans
foreach pol in rest mall {
    foreach lag in c0 L5 cum {
        local v `pol'
        if "`lag'"=="L5"  local v `pol'_lag5
        if "`lag'"=="cum" local v years_under_`pol'_ban
        foreach out in all_removed t6_removed {
            foreach adj in 0 1 {
                local ctrl ""
                if `adj'==1 local ctrl $COV
                cap noisily reghdfe `out' `v' `ctrl', absorb(state_id year) cluster(state_id)
                if !_rc {
                    local b=_b[`v']
                    local se=_se[`v']
                    local df=e(df_r)
                    local cr=cond(!mi(`df'),invttail(`df',0.025),1.96)
                    post `P' ("lagstrat") ("`pol'") ("`out'") ("`lag'") (`adj') ///
                        (`b') (`se') (`b'-`cr'*`se') (`b'+`cr'*`se') (e(N))
                }
            }
        }
    }
}

* (D3) MAIN c0 for smoking outcomes (adjusted vs unadjusted)
foreach pol in tax price rest mall {
    if "`pol'"=="tax"   local v tax_fed_state
    if "`pol'"=="price" local v price_state
    if "`pol'"=="rest"  local v rest
    if "`pol'"=="mall"  local v mall
    foreach out in current_smoker quitting {
        foreach adj in 0 1 {
            local ctrl ""
            if `adj'==1 local ctrl $COV
            cap noisily reghdfe `out' `v' `ctrl', absorb(state_id year) cluster(state_id)
            if !_rc {
                local b=_b[`v']
                local se=_se[`v']
                local df=e(df_r)
                local cr=cond(!mi(`df'),invttail(`df',0.025),1.96)
                post `P' ("main") ("`pol'") ("`out'") ("c0") (`adj') ///
                    (`b') (`se') (`b'-`cr'*`se') (`b'+`cr'*`se') (e(N))
            }
        }
    }
}

* (D4) NEGATIVE-CONTROL outcomes (seatbelt, smoke-detector)
foreach pol in tax price rest mall {
    if "`pol'"=="tax"   local v tax_fed_state
    if "`pol'"=="price" local v price_state
    if "`pol'"=="rest"  local v rest
    if "`pol'"=="mall"  local v mall
    foreach out in seatbelt smkdetec {
        foreach adj in 0 1 {
            local ctrl ""
            if `adj'==1 local ctrl $COV
            cap noisily reghdfe `out' `v' `ctrl', absorb(state_id year) cluster(state_id)
            if !_rc {
                local b=_b[`v']
                local se=_se[`v']
                local df=e(df_r)
                local cr=cond(!mi(`df'),invttail(`df',0.025),1.96)
                post `P' ("negctrl") ("`pol'") ("`out'") ("c0") (`adj') ///
                    (`b') (`se') (`b'-`cr'*`se') (`b'+`cr'*`se') (e(N))
            }
        }
    }
}

* (D5) REGION x YEAR FE robustness (time-varying confounding)
foreach pol in tax price rest mall {
    if "`pol'"=="tax"   local v tax_fed_state
    if "`pol'"=="price" local v price_state
    if "`pol'"=="rest"  local v rest
    if "`pol'"=="mall"  local v mall
    foreach out in current_smoker quitting all_removed t6_removed {
        cap noisily reghdfe `out' `v' $COV, absorb(state_id year region#year) cluster(state_id)
        if !_rc {
            local b=_b[`v']
            local se=_se[`v']
            local df=e(df_r)
            local cr=cond(!mi(`df'),invttail(`df',0.025),1.96)
            post `P' ("regyrFE") ("`pol'") ("`out'") ("c0") (1) ///
                (`b') (`se') (`b'-`cr'*`se') (`b'+`cr'*`se') (e(N))
        }
    }
}

postclose `P'
use "output\res_part1.dta", clear
export delimited "output\res_part1.csv", replace
list, sepby(block) noobs

di "=== PART 1 COMPLETE: $S_DATE $S_TIME ==="
log close
