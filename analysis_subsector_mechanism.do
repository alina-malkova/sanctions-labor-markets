********************************************************************************
* Sub-Sector Mechanism Test: Wages in Successful vs Failed Import Substitution
*
* Based on RFSD analysis showing:
* - SUCCESS sectors (pork, poultry): +95% revenue growth, +124% rev/firm
* - FAILURE sectors (dairy, fruits): +78% revenue growth, +88% rev/firm
*
* Hypothesis: Wage effects should be concentrated in SUCCESS sectors
********************************************************************************

clear all
set more off

cd "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Working santctions"

capture mkdir "output/subsector"
log using "output/subsector/analysis_log.txt", replace text

********************************************************************************
* Load RLMS data
********************************************************************************

di "Loading RLMS data..."
use "output/rlms_analysis_sample.dta", clear

* Check if we have detailed occupation/industry codes
describe j4* occup*

********************************************************************************
* Identify agricultural sub-sectors from RLMS
********************************************************************************

di ""
di "Examining industry coding in RLMS..."

* Basic agriculture indicator
capture drop agri
gen agri = (industry == 8)
tab agri, m

* Check occupation codes for agricultural workers
tab occup08 if agri == 1, sort
tab occup if agri == 1, sort

* Look for more detailed industry coding
* Check if there are sub-industry variables
capture describe j4_2 j4_3 j40 j41
capture tab j4_2 if agri == 1

********************************************************************************
* Alternative: Use regional treatment intensity variation
* Regions with higher pork/poultry share vs dairy/fruit share
********************************************************************************

di ""
di "Loading regional sub-sector composition..."

* Import RFSD treatment intensity with sub-sector breakdown
preserve
import delimited "RFSD_data/output/rfsd_treatment_intensity.csv", clear
keep region region_std baseline_share_meat_pork baseline_share_meat_poultry ///
     baseline_share_dairy baseline_share_fruits_veg

* Create success vs failure sector shares
gen success_share = baseline_share_meat_pork + baseline_share_meat_poultry
gen failure_share = baseline_share_dairy + baseline_share_fruits_veg
gen success_minus_failure = success_share - failure_share

* High success region indicator (above median success share)
sum success_share, detail
gen high_success_region = (success_share > r(p50))

* Summary
di "Regional variation in sub-sector composition:"
sum success_share failure_share success_minus_failure

save "output/subsector/region_subsector_shares.dta", replace
restore

********************************************************************************
* Merge regional sub-sector shares with RLMS
********************************************************************************

* Need to match region names
* First, check what region variable we have
tab region if agri == 1, sort

* Load region crosswalk if available
capture merge m:1 region using "output/subsector/region_subsector_shares.dta"
if _rc != 0 {
    di "Direct merge failed, trying with region crosswalk..."

    * Create manual merge based on PSU codes
    * This will need adjustment based on actual region coding
}

********************************************************************************
* Alternative approach: Food industry vs primary agriculture
********************************************************************************

di ""
di "Alternative: Food processing vs primary agriculture"

* Food industry (j4_1 == 1) includes food processing (more pork/poultry-like)
* Primary agriculture (j4_1 == 8) is more diverse

capture drop food_industry
gen food_industry = (industry == 1)
tab food_industry year if year >= 2010

* Combined treated sector
capture drop treated_sector
gen treated_sector = (agri == 1 | food_industry == 1)
tab treated_sector year

********************************************************************************
* Test: Food processing vs primary agriculture wage effects
********************************************************************************

di ""
di "=============================================="
di "MECHANISM TEST 1: Food Processing vs Agriculture"
di "=============================================="

* Post-embargo indicator
capture drop post
gen post = (year >= 2014)

* Interaction terms
capture drop agri_post food_post
gen agri_post = agri * post
gen food_post = food_industry * post

* Regression: Compare food processing and agriculture responses
* If import substitution matters, food processing (dominated by pork/poultry)
* should show stronger effects

di "DiD: Agriculture vs Other"
reghdfe ln_wage agri_post agri post age age_sq female i.educ_cat [pw=inwgt], ///
    absorb(region) cluster(region)
estimates store agri_only

di ""
di "DiD: Food Processing vs Other"
reghdfe ln_wage food_post food_industry post age age_sq female i.educ_cat [pw=inwgt], ///
    absorb(region) cluster(region)
estimates store food_only

di ""
di "Combined: Both Agriculture and Food Processing"
reghdfe ln_wage agri_post food_post agri food_industry post ///
    age age_sq female i.educ_cat [pw=inwgt], ///
    absorb(region) cluster(region)
estimates store both

* Test if coefficients are different
test agri_post = food_post

* Table
esttab agri_only food_only both using "output/subsector/mechanism_test1.rtf", replace ///
    title("Mechanism Test: Agriculture vs Food Processing") ///
    mtitles("Agriculture" "Food Processing" "Combined") ///
    keep(agri_post food_post agri food_industry) ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    note("Standard errors clustered by region")

********************************************************************************
* Test 2: Event study by sector
********************************************************************************

di ""
di "=============================================="
di "EVENT STUDY: Agriculture vs Food Processing"
di "=============================================="

* Event time
capture drop event_time
gen event_time = year - 2014

* Create interaction dummies
foreach sector in agri food_industry {
    forval t = -3/4 {
        local tname = cond(`t' < 0, "m" + string(abs(`t')), string(`t'))
        capture drop D_`sector'_`tname'
        gen D_`sector'_`tname' = `sector' * (event_time == `t')
    }
}

* Event study regression
reghdfe ln_wage D_agri_m3 D_agri_m2 D_agri_0 D_agri_1 D_agri_2 D_agri_3 D_agri_4 ///
                D_food_industry_m3 D_food_industry_m2 D_food_industry_0 ///
                D_food_industry_1 D_food_industry_2 D_food_industry_3 D_food_industry_4 ///
                agri food_industry i.year ///
                age age_sq female i.educ_cat [pw=inwgt], ///
    absorb(region) cluster(region)

* Store coefficients
matrix coef_agri = J(8,3,.)
matrix coef_food = J(8,3,.)
local row = 1
foreach t in m3 m2 m1 0 1 2 3 4 {
    if "`t'" == "m1" {
        matrix coef_agri[`row',1] = 0
        matrix coef_agri[`row',2] = 0
        matrix coef_agri[`row',3] = 0
        matrix coef_food[`row',1] = 0
        matrix coef_food[`row',2] = 0
        matrix coef_food[`row',3] = 0
    }
    else {
        capture matrix coef_agri[`row',1] = _b[D_agri_`t']
        capture matrix coef_agri[`row',2] = _se[D_agri_`t']
        capture matrix coef_agri[`row',3] = _b[D_agri_`t'] / _se[D_agri_`t']
        capture matrix coef_food[`row',1] = _b[D_food_industry_`t']
        capture matrix coef_food[`row',2] = _se[D_food_industry_`t']
        capture matrix coef_food[`row',3] = _b[D_food_industry_`t'] / _se[D_food_industry_`t']
    }
    local row = `row' + 1
}

di ""
di "Agriculture event study coefficients:"
matrix list coef_agri

di ""
di "Food processing event study coefficients:"
matrix list coef_food

********************************************************************************
* Summary statistics
********************************************************************************

di ""
di "=============================================="
di "SUMMARY STATISTICS BY SECTOR"
di "=============================================="

* Sample sizes
tab agri year if year >= 2010
tab food_industry year if year >= 2010

* Wage comparisons
table year agri, stat(mean ln_wage) stat(sd ln_wage) stat(count ln_wage)
table year food_industry, stat(mean ln_wage) stat(sd ln_wage) stat(count ln_wage)

********************************************************************************
* Save results summary
********************************************************************************

di ""
di "=============================================="
di "SUMMARY FOR PAPER"
di "=============================================="
di ""
di "This analysis tests the import substitution mechanism using"
di "Food Processing (RLMS industry code 1) as a proxy for successful"
di "import substitution sectors (pork, poultry), compared to"
di "Primary Agriculture (code 8) which is more diverse."
di ""
di "From RFSD firm-level analysis:"
di "  - SUCCESS sectors (pork, poultry): +95% revenue growth 2013-2018"
di "  - FAILURE sectors (dairy, fruits): +78% revenue growth"
di "  - Difference: 17 percentage points"
di ""
di "If the mechanism is correct, Food Processing should show"
di "stronger wage effects than Primary Agriculture."
di ""

log close

********************************************************************************
* Create figure comparing event studies
********************************************************************************

preserve
clear
set obs 8

gen event_time = _n - 4

* Agriculture coefficients (from event study above)
gen coef_agri = .
gen se_agri = .
* These would be filled from the regression output

* Food processing coefficients
gen coef_food = .
gen se_food = .

* For now, use placeholder values - fill from actual regression
* replace coef_agri = ... in 1/8
* etc.

restore

di ""
di "Analysis complete. See output/subsector/ for results."
di ""
