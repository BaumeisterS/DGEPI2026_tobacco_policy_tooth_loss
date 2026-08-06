* Smoking IV - Tooth loss 
clear all
set more off
* run Stata with this folder as the working directory

cap which statastates
if _rc ssc install statastates
cap which rangestat
if _rc ssc install rangestat

********************************************************************************
* 1. PREPARE BRFSS DATA 
********************************************************************************
tempfile master_brfss
save `master_brfss', emptyok

local datasets 1995 1996 1997 1998 1999 2000 2001 2002 2003 2004 2005 2006 2008 2010 2012

foreach yr of local datasets {
    di "Processing BRFSS `yr'..."
    quietly {
        use "data/raw/brfss/BRFSS`yr'.dta", clear
        
        * --- Standardize Variable Names ---
        cap rename rmvteth3 rmvteeth
        cap rename lastden2 lastdent
        cap rename lastden3 lastdent
        cap rename income95 income_raw
        cap rename income2  income_raw
        cap rename _racegr2 _racegr
        cap rename _smoker3 _smoker2
        cap rename _rfsmok3 _rfsmok2
        cap rename smkdete2 smkdetec
        cap rename diabete2 diabetes
        cap rename diabete3 diabetes
        cap rename diabage2 diabage
        cap rename houssmk1 housesmk
        
        * --- Tooth loss ---
        cap confirm variable rmvteeth
        if !_rc {
            lab def rmvteeth_lbl 1 "1,5 or fewer" 2 "2,6 or more but not all" ///
                                 3 "3,all" 8 "8,none" 7 "7,don't know/not sure" 9 "9,refused", replace
            lab val rmvteeth rmvteeth_lbl
        }

        * --- Dental service use ---
        cap confirm variable lastdent
        if !_rc recode lastdent (1=1) (2/9=0), gen(dentist12)

        * --- Dental insurance ---
        cap confirm variable dentlins
        if !_rc recode dentlins (1=1) (. 2 7 9 =0)

        * --- Educational attainment ---
        recode educa (9=.a) 
        lab def educa_lbl 1 "1,no school" 2 "2,elementary" 3 "3,some high school" ///
                          4 "4,high schol graduate" 5 "5,some college or technical school" ///
                          6 "6,collegue graduate" .a ".a,refused", replace
        lab val educa educa_lbl

        * --- Income ---
        cap confirm variable income_raw
        if !_rc {
            recode income_raw (1/4=1) (5=2) (6=3) (7/8=4) (77 99=5), gen(income)
            lab def inc_lbl 1 "<25k$" 2 "25-30k$" 3 "35-50k$" 4 ">50k$" 5 "missing", replace
            lab val income inc_lbl
        }

        * --- Age, Year, Sex ---
        gen age2 = age^2
        gen brfss_yr = `yr'
        gen brfss_cycle = `yr'
        gen byear = `yr' - age
        recode sex (1=0) (2=1), gen(female)

        * --- Race ---
        cap confirm variable _racegr
        if !_rc {
            if `yr' >= 2001 recode _racegr (5=3) (3 4=4) (9=.a), gen(racegr)
            else recode _racegr (9=.a), gen(racegr)
            lab def race_lbl 1 "1,white non-hisp" 2 "2,black non-hisp" 3 "3,hispanic" 4 "4,other" .a ".a.refused", replace
            lab val racegr race_lbl
        }

        * --- Marital status ---
        recode marital (1 6=1) (2/5=0) (9=.a), gen(marital2) 

        * --- Smoking ---
        gen byte smoke = 0 if smoke100 == 2
        if `yr' >= 1996 {
            replace smoke = 1 if inlist(_smoker2, 1, 2)
            replace smoke = 2 if _smoker2 == 3 & smoke100 == 1
        }
        else {
            replace smoke = 1 if smokenow == 1 
            replace smoke = 2 if smokenow == 2 & smoke100 == 1
        }
        
        cap confirm variable smokenum
        if !_rc {
            gen cig30days = smokenum if smoke100==1 & inlist(smoke, 1)
            replace cig30days = 0 if smokenum >= 77 | smoke != 1
        }
        
        cap confirm variable regsmk
        if !_rc {
            gen age_regsmk = regsmk
            replace age_regsmk = . if regsmk < 10 | regsmk > 76
        }

        * --- Restrictions ---
        cap confirm variable housesmk
        if !_rc recode housesmk (1=2) (2=1) (. 3 4 7 9 = 0), gen(nosmoke_home)
        
        cap confirm variable smkpublc
        if !_rc {
            gen byte nosmoke_work = inlist(smkpublc, 1, 2) | inlist(smkwork, 1, 2)
        }

        * --- Alcohol ---
        cap confirm variable alcohol
        if !_rc {
            gen byte w = (alcohol < 200)
            gen byte m = (alcohol > 200 & alcohol < 777)
            
            gen byte week = mod(alcohol, 100) if w == 1
            replace week = 0 if inlist(drinkany, 2, 7, 9)
            
            gen byte month = mod(alcohol, 100) if m == 1
            replace month = 0 if inlist(month, 77, 88) | inlist(drinkany, 2, 7, 9)
            
            gen drinks_occ = nalcocc
            replace drinks_occ = 0 if inlist(nalcocc, 77, 99) | inlist(drinkany, 2, 7, 9)
            
            cap gen drinks_day = drinks_occ / week if w == 1
            cap replace drinks_day = drinks_occ / month if m == 1
            cap replace drinks_day = 0 if inlist(drinkany, 2, 7, 9)
        }

        * --- BMI ---
        if `yr' <= 1999 gen bmi = _bmi / 10
        else if `yr' == 2000 gen bmi = _bmi2 / 10
        else if `yr' == 2001 gen bmi = _bmi2 / 10000
        else if `yr' == 2002 gen bmi = _bmi2 / 100
        else if `yr' == 2003 gen bmi = _bmi3 / 100
        else if `yr' == 2012 gen bmi = _bmi5 / 100
        else gen bmi = _bmi4 / 100
        
        gen byte bmicat = 1 if bmi < 25
        replace bmicat = 2 if inrange(bmi, 25, 29.99)
        replace bmicat = 3 if bmi >= 30
        replace bmicat = . if missing(bmi)

        * --- Diabetes ---
        cap confirm variable diabetes
        if !_rc {
            if `yr' >= 2004 recode diabetes (2 3 4 = 0) (7 9 = .)
            else recode diabetes (2 3 7 9 = 0)
            
            gen diabyears = age - diabage 
            replace diabyears = 0 if diabetes == 0
        }

        * --- Seatbelt & Smoke Detector ---
        cap confirm variable seatbelt
        if !_rc recode seatbelt (1 2=1) (3/9=0)
        
        cap confirm variable smkdetec
        if !_rc recode smkdetec (1/3=1) (4/9=0)

        * --- DYNAMIC KEEP LIST ---
        local target_vars rmvteeth dentist12 dentlins educa income brfss_yr brfss_cycle byear age age2 female racegr smoke cig30days nosmoke_home nosmoke_work drinks_day bmicat diabetes diabyears seatbelt smkdetec _state age_regsmk
        
        local keep_vars ""
        foreach v of local target_vars {
            cap confirm variable `v'
            if !_rc local keep_vars "`keep_vars' `v'"
        }
        keep `keep_vars'
             
        compress
        append using `master_brfss'
        save `master_brfss', replace
    }
}

* Load completed BRFSS data
use `master_brfss', clear

di "Formatting BRFSS State Data & Recoding Variables..."
quietly {
    keep if age >= 18

    * Current Smoker
    gen byte current_smoker = 1 if smoke == 1
    replace current_smoker = 0 if smoke ==0 | smoke == 2  
    lab var current_smoker "current smoking"
    
    * Quitting
    gen byte quitting = 1 if smoke == 2
    replace quitting = 0 if smoke == 1
	replace quitting = 0 if smoke == 0
	    lab var quitting "quit smoking"

    * All Teeth Removed
    gen byte all_removed = 1 if rmvteeth == 3
    replace all_removed = 0 if inlist(rmvteeth, 1, 2, 7, 8, 9)
    lab var all_removed "all vs <5 removed"

    * >= 6 Teeth Removed
    gen byte t6_removed = 1 if inlist(rmvteeth, 2, 3)
    replace t6_removed = 0 if inlist(rmvteeth, 1, 7, 8, 9)
    lab var t6_removed ">=6 vs <6 removed"
    * =====================================================================

    rename _state fips
    statastates, fips(fips)
    drop _merg*
    replace state_name = strupper(state_name)

    clonevar year = brfss_yr
    recast int year 
    
    compress
    tempfile compiled_brfss
    save `compiled_brfss'
}

di "========================================================"
di "      TOOTH LOSS RECIFICATIONS VERIFICATION             "
di "========================================================"
tab2 rmvteeth all_removed, miss
tab2 rmvteeth t6_removed, miss


********************************************************************************
* 2. PREPARE MACRO POLICY PANEL (STATE-YEAR LEVEL)
********************************************************************************
di "Preparing Policy & Tax Data..."

* --- INFLATION (CPI) ---
clear
input year cpi
1980 82.4 
1981 90.9 
1982 96.5 
1983 99.6 
1984 103.9 
1985 107.6
1986 109.6 
1987 113.6 
1988 118.3 
1989 124.0 
1990 130.7 
1991 136.2
1992 140.3 
1993 144.5 
1994 148.2 
1995 152.4 
1996 156.9 
1997 160.5
1998 163.0 
1999 166.6 
2000 172.2 
2001 177.1 
2002 179.9 
2003 184.0
2004 188.9 
2005 195.3 
2006 201.6 
2007 207.342 
2008 215.303
2009 214.537 
2010 218.056 
2011 224.939 
2012 229.594 
2013 232.957
2014 236.736 
2015 237.017 
2016 240.007 
2017 245.120 
2018 251.107 
2019 255.657
end
sort year
tempfile cpi_data
save `cpi_data'

* --- TOBACCO TAX ---
import delimited "data/raw/tax/The_Tax_Burden_on_Tobacco__1970-2019_20240607.csv", clear
keep if inlist(submeasuredesc, "Average Cost per pack", "Federal and State Tax per pack", "State Tax per pack")

g price_state = data_value if submeasuredesc=="Average Cost per pack"
g tax_fed_state = data_value if submeasuredesc=="Federal and State Tax per pack"
g tax_state = data_value if submeasuredesc=="State Tax per pack"
g state_name = strupper(locationdesc)
rename locationabbr state_abbrev

collapse (max) price_state tax_fed_state tax_state, by(state_abbrev state_name year)
fillin state_abbrev year
drop _fillin

* Fill missing state_name robustly (using _N avoids sorting errors)
bysort state_abbrev (state_name): replace state_name = state_name[_N] if missing(state_name)

* Impute and enforce non-declining rule
gen neg_year = -year
foreach var in price_state tax_fed_state tax_state {
    bysort state_abbrev (year): replace `var' = max(`var', `var'[_n-1]) if !missing(`var'[_n-1])
    bysort state_abbrev (neg_year): replace `var' = `var'[_n-1] if missing(`var') 
}
drop neg_year

* Merge CPI & adjust
sort year
merge m:1 year using `cpi_data', keep(3) nogen
su cpi if year==2012, meanonly
local cpi2012 = r(mean)
foreach var in price_state tax_fed_state tax_state {
    replace `var' = `var' * (`cpi2012' / cpi)
}

keep state_abbrev state_name year price_state tax_fed_state tax_state
drop if state_name == "" | state_name == "NATIONAL"
sort state_name year
tempfile tax_data
save `tax_data'

* --- RESTAURANT BANS ---
import excel "data/raw/bans/Table_9078.xls", sheet("Sheet1") firstrow clear
destring Year, gen(year)
g state_name = strtrim(strupper(LocationDescription))
gen byte rest = inlist(Value, "Designated Areas", "Designated Smoking Area", "Designated Smoking Areas", "Separate Ventilated Areas", "Banned")
collapse (max) rest, by(state_name year)

fillin state_name year
drop _fillin

gen neg_year = -year
bysort state_name (year): replace rest = max(rest, rest[_n-1]) if !missing(rest[_n-1])
bysort state_name (neg_year): replace rest = rest[_n-1] if missing(rest) 
replace rest = 0 if missing(rest)
drop neg_year

sort state_name year
tempfile rest_data
save `rest_data'

* --- MALL BANS ---
import excel "data/raw/bans/Table_3207.xls", sheet("Sheet1") firstrow clear
destring Year, gen(year)
g state_name = strtrim(strupper(LocationDescription))
gen byte mall = inlist(Value, "Designated Areas", "Designated Smoking Area", "Separate Ventilated Areas", "Banned")
collapse (max) mall, by(state_name year)

fillin state_name year
drop _fillin

gen neg_year = -year
bysort state_name (year): replace mall = max(mall, mall[_n-1]) if !missing(mall[_n-1])
bysort state_name (neg_year): replace mall = mall[_n-1] if missing(mall) 
replace mall = 0 if missing(mall)
drop neg_year

sort state_name year
tempfile mall_data
save `mall_data'

* --- MERGE ALL POLICIES TOGETHER & GENERATE LAGS ---
use `tax_data', clear
sort state_name year
merge 1:1 state_name year using `rest_data', keep(1 3) nogen
merge 1:1 state_name year using `mall_data', keep(1 3) nogen

replace rest = 0 if missing(rest)
replace mall = 0 if missing(mall)

egen state_id = group(state_name)

* Find start years for bans
bysort state_name: egen first_rest_ban = min(cond(rest == 1, year, .))
replace first_rest_ban = 0 if missing(first_rest_ban) 

bysort state_name: egen first_mall_ban = min(cond(mall == 1, year, .))
replace first_mall_ban = 0 if missing(first_mall_ban)

* Declare panel data and Enforce Time Sort
xtset state_id year

* Lags 
gen price_lag1         = L1.price_state
gen tax_fed_state_lag1 = L1.tax_fed_state
gen tax_state_lag1     = L1.tax_state

gen price_lag5         = L5.price_state
gen tax_fed_state_lag5 = L5.tax_fed_state
gen tax_state_lag5     = L5.tax_state
gen rest_lag5          = L5.rest
gen mall_lag5          = L5.mall

* Cumulative policy exposure 
bysort state_id (year): gen years_under_rest_ban = sum(rest)
bysort state_id (year): gen years_under_mall_ban = sum(mall)

* 10-year rolling averages 
rangestat (mean) price_10y_avg         = price_state,   interval(year -9 0) by(state_id)
rangestat (mean) tax_fed_state_10y_avg = tax_fed_state, interval(year -9 0) by(state_id)
rangestat (mean) tax_state_10y_avg     = tax_state,     interval(year -9 0) by(state_id)

sort state_name year
tempfile master_policy
save `master_policy'


********************************************************************************
* 3. FINAL MERGE (BRFSS + MACRO POLICY PANEL)
********************************************************************************
di "Executing final merge to individual level data..."

use `compiled_brfss', clear
sort state_name year

* Merge macro variables into micro data
merge m:1 state_name year using `master_policy'
keep if _merge == 3
drop _merge

compress
label data "brfss1995-2012+tax_price+bans+lags"
save data/final_smoking_analysis_dataset.dta, replace 

di "Finished successfully. View tables below:"

********************************************************************************
* 4. VIEW POLICY ROLLOUT & FINAL SUMMARIES
********************************************************************************
preserve
    collapse (max) rest mall, by(state_name year)

    di ""
    di "========================================================"
    di "      RESTAURANT BANS BY STATE AND YEAR (0=No, 1=Yes)   "
    di "========================================================"
    tabdisp state_name year, cell(rest)

    di ""
    di "========================================================"
    di "      MALL/GROCERY BANS BY STATE AND YEAR (0=No, 1=Yes) "
    di "========================================================"
    tabdisp state_name year, cell(mall)
restore

su year* age price_state tax_state *_lag* *_10y_avg years_under*
tab1 brfss_cycle, m