********************************************************************************
* ANALYSIS: OTHER TRADABLE SECTORS (Ruble Depreciation Robustness Check)
* FAST VERSION - Uses areg instead of reghdfe
********************************************************************************

clear all
set more off

log using "output/analysis_tradable_sectors_log.txt", text replace

di "======================================================================"
di "TRADABLE SECTORS ANALYSIS: TESTING RUBLE DEPRECIATION CONFOUND"
di "======================================================================"

use "output/rlms_analysis_sample.dta", clear
keep if year >= 2010 & year <= 2019

********************************************************************************
* PART 1: Create Sector Indicators
********************************************************************************

di _n "=== CREATING SECTOR INDICATORS ==="

* Drop if already exist
cap drop manufacturing oil_gas food_processing

gen manufacturing = inlist(industry, 2, 3, 5) if industry < 99999990
gen oil_gas = (industry == 4) if industry < 99999990
gen food_processing = (industry == 1) if industry < 99999990

* Sample sizes
count if agri == 1
local n_agri = r(N)
count if manufacturing == 1
local n_mfg = r(N)
count if oil_gas == 1
local n_oil = r(N)
count if food_processing == 1
local n_food = r(N)

di "Agriculture: `n_agri'"
di "Manufacturing: `n_mfg'"
di "Oil & Gas: `n_oil'"
di "Food processing: `n_food'"

********************************************************************************
* PART 2: DiD Estimates (using areg for speed)
********************************************************************************

di ""
di "======================================================================"
di "PART 2: SECTOR-SPECIFIC DID ESTIMATES"
di "======================================================================"

* Create interaction terms
foreach v in mfg_post oil_post food_post {
    cap drop `v'
}
gen mfg_post = manufacturing * post
gen oil_post = oil_gas * post
gen food_post = food_processing * post

* Agriculture (baseline)
areg ln_wage agri_post i.year, absorb(idind) cluster(region)
di _n "Agriculture x Post: " %7.4f _b[agri_post] " (SE: " %6.4f _se[agri_post] ")"
local b_agri = _b[agri_post]
local se_agri = _se[agri_post]

* Manufacturing
areg ln_wage mfg_post i.year, absorb(idind) cluster(region)
di "Manufacturing x Post: " %7.4f _b[mfg_post] " (SE: " %6.4f _se[mfg_post] ")"
local b_mfg = _b[mfg_post]
local se_mfg = _se[mfg_post]

* Oil & Gas
areg ln_wage oil_post i.year, absorb(idind) cluster(region)
di "Oil & Gas x Post: " %7.4f _b[oil_post] " (SE: " %6.4f _se[oil_post] ")"
local b_oil = _b[oil_post]
local se_oil = _se[oil_post]

* Food Processing (also treated by embargo)
areg ln_wage food_post i.year, absorb(idind) cluster(region)
di "Food Processing x Post: " %7.4f _b[food_post] " (SE: " %6.4f _se[food_post] ")"
local b_food = _b[food_post]
local se_food = _se[food_post]

********************************************************************************
* PART 3: Summary Table
********************************************************************************

di ""
di "======================================================================"
di "PART 3: SUMMARY TABLE"
di "======================================================================"

di _n "=== Post-2014 Wage Effects by Sector ==="
di ""
di "Sector                  | Coef   | SE     | N      | Interpretation"
di "------------------------|--------|--------|--------|---------------"
di "Agriculture             | " %6.3f `b_agri' " | " %6.3f `se_agri' " | " %6.0f `n_agri' " | TREATED (embargo)"
di "Food Processing         | " %6.3f `b_food' " | " %6.3f `se_food' " | " %6.0f `n_food' " | TREATED (embargo)"
di "Manufacturing           | " %6.3f `b_mfg' " | " %6.3f `se_mfg' " | " %6.0f `n_mfg' " | Tradable (depreciation)"
di "Oil & Gas               | " %6.3f `b_oil' " | " %6.3f `se_oil' " | " %6.0f `n_oil' " | Tradable (depreciation)"

********************************************************************************
* PART 4: Interpretation
********************************************************************************

di ""
di "======================================================================"
di "PART 4: INTERPRETATION"
di "======================================================================"

di _n "KEY FINDINGS:"
di ""
di "If ruble depreciation were driving our agriculture results,"
di "we would expect other tradable sectors to show similar gains."
di ""
di "Manufacturing effect: " %4.1f `b_mfg'*100 "%"
di "Agriculture effect: " %4.1f `b_agri'*100 "%"
di ""
di "Difference (Agri - Manufacturing): " %5.3f (`b_agri' - `b_mfg')

if `b_mfg' > 0.02 {
    di ""
    di "CONCERN: Manufacturing also shows substantial positive gains,"
    di "suggesting depreciation may explain part of agricultural effect."
}
else if `b_mfg' < 0 {
    di ""
    di "SUPPORTIVE: Manufacturing shows negative/zero effect,"
    di "suggesting agricultural gains are NOT driven by depreciation alone."
}
else {
    di ""
    di "MIXED: Manufacturing shows modest effect,"
    di "cannot fully rule out depreciation as partial explanation."
}

* Save results
tempname results
postfile `results' str30 sector coef se n using "output/tables/tradable_sectors_results.dta", replace
post `results' ("Agriculture") (`b_agri') (`se_agri') (`n_agri')
post `results' ("Food Processing") (`b_food') (`se_food') (`n_food')
post `results' ("Manufacturing") (`b_mfg') (`se_mfg') (`n_mfg')
post `results' ("Oil & Gas") (`b_oil') (`se_oil') (`n_oil')
postclose `results'

use "output/tables/tradable_sectors_results.dta", clear
list, sep(0)
export delimited using "output/tables/tradable_sectors_results.csv", replace

log close
