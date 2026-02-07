********************************************************************************
* Heterogeneity Analysis: Labor Supply Elasticity (Simplified)
********************************************************************************

clear all
set more off
cap log close
log using "output/analysis_heterogeneity_log.txt", replace text

use "output/rlms_analysis_sample.dta", clear
keep if year >= 2010 & year <= 2019

di "======================================================================"
di "HETEROGENEITY ANALYSIS"
di "======================================================================"

* Create variables (drop if exists)
cap drop agri_post
gen agri_post = agri * post

* Rural: regions with above-median agricultural share
cap drop region_agri_share rural
bysort region: egen region_agri_share = mean(agri) if year == 2013
bysort region: egen temp = max(region_agri_share)
replace region_agri_share = temp
drop temp
sum region_agri_share, detail
gen rural = (region_agri_share > r(p50)) if region_agri_share != .

* Age
cap drop young
gen young = (age < 40)

* Education - use median split
cap drop high_educ
sum educ, detail
gen high_educ = (educ > r(p50)) if educ != .

di ""
di "--- Sample sizes ---"
tab rural agri
tab young agri  
tab high_educ agri

********************************************************************************
* REGRESSIONS
********************************************************************************

di ""
di "======================================================================"
di "MAIN RESULTS BY SUBGROUP"
di "======================================================================"

* Overall
di _n "=== OVERALL ==="
reghdfe ln_wage agri_post, absorb(idind year) cluster(region)

* By region type
di _n "=== RURAL REGIONS ==="
reghdfe ln_wage agri_post if rural == 1, absorb(idind year) cluster(region)

di _n "=== URBAN REGIONS ==="
reghdfe ln_wage agri_post if rural == 0, absorb(idind year) cluster(region)

* By age
di _n "=== YOUNG (age < 40) ==="
reghdfe ln_wage agri_post if young == 1, absorb(idind year) cluster(region)

di _n "=== OLDER (age >= 40) ==="
reghdfe ln_wage agri_post if young == 0, absorb(idind year) cluster(region)

* By education
di _n "=== LOWER EDUCATION ==="
reghdfe ln_wage agri_post if high_educ == 0, absorb(idind year) cluster(region)

di _n "=== HIGHER EDUCATION ==="
reghdfe ln_wage agri_post if high_educ == 1, absorb(idind year) cluster(region)

* Most constrained: rural + older
di _n "=== RURAL + OLDER (most constrained) ==="
reghdfe ln_wage agri_post if rural == 1 & young == 0, absorb(idind year) cluster(region)

* Most mobile: urban + young
di _n "=== URBAN + YOUNG (most mobile) ==="
reghdfe ln_wage agri_post if rural == 0 & young == 1, absorb(idind year) cluster(region)

********************************************************************************
* HOURS EFFECTS
********************************************************************************

di ""
di "======================================================================"
di "HOURS EFFECTS BY SUBGROUP"
di "======================================================================"

di _n "=== HOURS: RURAL ==="
reghdfe hours agri_post if rural == 1, absorb(idind year) cluster(region)

di _n "=== HOURS: URBAN ==="
reghdfe hours agri_post if rural == 0, absorb(idind year) cluster(region)

di _n "=== HOURS: OLDER ==="
reghdfe hours agri_post if young == 0, absorb(idind year) cluster(region)

di _n "=== HOURS: YOUNG ==="
reghdfe hours agri_post if young == 1, absorb(idind year) cluster(region)

di ""
di "Analysis complete!"
log close
