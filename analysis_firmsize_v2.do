********************************************************************************
* Firm Size Heterogeneity Analysis - Using Enterprise Type Proxy
* Enterprise vs Non-Enterprise (family farms, individual operations)
********************************************************************************

clear all
set more off
cap log close
log using "output/analysis_firmsize_v2_log.txt", replace text

di "======================================================================"
di "FIRM SIZE HETEROGENEITY: ENTERPRISE VS NON-ENTERPRISE"
di "======================================================================"

use "output/rlms_analysis_sample.dta", clear
keep if year >= 2010 & year <= 2019

********************************************************************************
* PART 1: Create Firm Type Categories from Enterprise Type
********************************************************************************

di _n "=== PART 1: ENTERPRISE TYPE DISTRIBUTION ==="

* enterprise_type coding:
* 1 = "You work at an enterprise or organization" (formal employers)
* 2 = "Not an enterprise, nor an organization" (family farms, individual)
* 99999998 = Does not know

tab enterprise_type if agri == 1, m

* Create binary indicator
* Formal enterprise = likely larger agriholdings
* Non-enterprise = likely small family farms
gen formal_enterprise = (enterprise_type == 1) if enterprise_type < 99999990
gen informal_farm = (enterprise_type == 2) if enterprise_type < 99999990

di _n "=== Sample Sizes ==="
count if agri == 1 & formal_enterprise == 1
count if agri == 1 & informal_farm == 1

* Calculate percentages
qui count if agri == 1 & enterprise_type < 99999990
local total = r(N)
qui count if agri == 1 & formal_enterprise == 1
local formal_n = r(N)
qui count if agri == 1 & informal_farm == 1
local informal_n = r(N)

di _n "Formal enterprises: `formal_n' (" %4.1f `formal_n'/`total'*100 "%)"
di "Informal/family farms: `informal_n' (" %4.1f `informal_n'/`total'*100 "%)"

********************************************************************************
* PART 2: Heterogeneity Analysis
********************************************************************************

di ""
di "======================================================================"
di "PART 2: HETEROGENEITY BY ENTERPRISE TYPE"
di "======================================================================"

cap drop post agri_post
gen post = (year >= 2014)
gen agri_post = agri * post

* 2A: Interaction Model
di _n "=== 2A: Interaction Model ==="

gen agri_informal = agri * informal_farm
gen agri_informal_post = agri * informal_farm * post

quietly reghdfe ln_wage agri_post agri_informal_post, absorb(idind year) cluster(region)
di "Agri x Post (formal enterprises): " %7.4f _b[agri_post] " (SE: " %6.4f _se[agri_post] ")"
local b_formal = _b[agri_post]
local se_formal = _se[agri_post]
di "Agri x Informal x Post (additional): " %7.4f _b[agri_informal_post] " (SE: " %6.4f _se[agri_informal_post] ")"
local b_informal_add = _b[agri_informal_post]
local se_informal_add = _se[agri_informal_post]

* Implied effect for informal
local b_informal = `b_formal' + `b_informal_add'
di "Implied effect for informal farms: " %7.4f `b_informal'

* 2B: Separate Regressions
di _n "=== 2B: Separate Regressions ==="

* All agriculture
quietly reghdfe ln_wage agri_post, absorb(idind year) cluster(region)
di "All agriculture: " %7.4f _b[agri_post] " (SE: " %6.4f _se[agri_post] ")"
local b_all = _b[agri_post]
local se_all = _se[agri_post]

* Formal enterprises only
preserve
keep if formal_enterprise == 1 | agri == 0
quietly reghdfe ln_wage agri_post, absorb(idind year) cluster(region)
di "Formal enterprises only: " %7.4f _b[agri_post] " (SE: " %6.4f _se[agri_post] ")"
local b_formal_sep = _b[agri_post]
local se_formal_sep = _se[agri_post]
restore

* Informal/family farms only
preserve
keep if informal_farm == 1 | agri == 0
quietly reghdfe ln_wage agri_post, absorb(idind year) cluster(region)
di "Informal/family farms only: " %7.4f _b[agri_post] " (SE: " %6.4f _se[agri_post] ")"
local b_informal_sep = _b[agri_post]
local se_informal_sep = _se[agri_post]
restore

********************************************************************************
* PART 3: Power Analysis
********************************************************************************

di ""
di "======================================================================"
di "PART 3: POWER ANALYSIS"
di "======================================================================"

di _n "=== Sample Sizes and MDEs ==="
di ""
di "Group                        | N      | MDE (80% power)"
di "-----------------------------|--------|----------------"

count if agri == 1
local n_all = r(N)
local mde_all = 2.8 * 0.65 * sqrt(1.5) / sqrt(`n_all')
di "All agriculture              | " %6.0f `n_all' " | " %5.1f `mde_all'*100 "%"

count if agri == 1 & formal_enterprise == 1
local n_formal = r(N)
local mde_formal = 2.8 * 0.65 * sqrt(1.5) / sqrt(`n_formal')
di "Formal enterprises           | " %6.0f `n_formal' " | " %5.1f `mde_formal'*100 "%"

count if agri == 1 & informal_farm == 1
local n_informal = r(N)
local mde_informal = 2.8 * 0.65 * sqrt(1.5) / sqrt(`n_informal')
di "Informal/family farms        | " %6.0f `n_informal' " | " %5.1f `mde_informal'*100 "%"

********************************************************************************
* PART 4: Summary Table
********************************************************************************

di ""
di "======================================================================"
di "PART 4: SUMMARY TABLE"
di "======================================================================"

* Store results
tempname results
postfile `results' str35 group coef se n mde using "output/tables/firmsize_v2_results.dta", replace

post `results' ("All agriculture") (`b_all') (`se_all') (`n_all') (`mde_all')
post `results' ("Formal enterprises (88%)") (`b_formal_sep') (`se_formal_sep') (`n_formal') (`mde_formal')
post `results' ("Informal/family farms (12%)") (`b_informal_sep') (`se_informal_sep') (`n_informal') (`mde_informal')

postclose `results'

* Display results
use "output/tables/firmsize_v2_results.dta", clear
di _n "=== Firm Type Heterogeneity Results ==="
list, sep(0)

* Export
export delimited using "output/tables/firmsize_v2_results.csv", replace

********************************************************************************
* PART 5: Interpretation
********************************************************************************

di ""
di "======================================================================"
di "PART 5: INTERPRETATION"
di "======================================================================"

di _n "KEY FINDINGS:"
di ""
di "1. Enterprise type provides a proxy for firm formality:"
di "   - 88% of agricultural workers report working at 'enterprises'"
di "   - 12% report 'not an enterprise' (likely family farms, informal)"
di ""
di "2. Results by enterprise type:"
di "   - Formal enterprises: " %5.3f `b_formal_sep' " (SE: " %5.3f `se_formal_sep' ")"
di "   - Informal/family: " %5.3f `b_informal_sep' " (SE: " %5.3f `se_informal_sep' ")"
di ""
di "3. Power considerations:"
di "   - Formal enterprises (N=" %0.0f `n_formal' "): MDE = " %4.1f `mde_formal'*100 "%"
di "   - Informal farms (N=" %0.0f `n_informal' "): MDE = " %4.1f `mde_informal'*100 "%"
di ""
di "4. CAVEATS:"
di "   - This is a PROXY for firm size, not actual employee counts"
di "   - 'Enterprise' vs 'not enterprise' may capture formality, not size"
di "   - Large agriholdings would be 'enterprises' but so would medium farms"
di "   - Small family farms may report as 'not enterprise'"
di ""
di "5. Hypothesis (from RFSD firm-level evidence):"
di "   - Large agriholdings captured protection rents as profits"
di "   - Workers may not have seen wage gains at large firms"
di "   - Small/informal farms may have had more wage pass-through"
di "   - But our proxy cannot cleanly test this"

log close
