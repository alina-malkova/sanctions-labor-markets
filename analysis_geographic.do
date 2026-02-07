********************************************************************************
* Geographic Heterogeneity Analysis
* Testing regional treatment intensity effects
********************************************************************************

clear all
set more off
cap log close
log using "output/analysis_geographic_log.txt", replace text

use "output/rlms_analysis_sample.dta", clear
keep if year >= 2010 & year <= 2019

di "======================================================================"
di "GEOGRAPHIC HETEROGENEITY ANALYSIS"
di "======================================================================"

* Check region variable type
describe region
tab region if _n <= 20

********************************************************************************
* PART 1: Create regional agricultural intensity from data
********************************************************************************

* Calculate regional agricultural employment share (treatment proxy)
bysort region: egen region_agri_share_2013 = mean(agri) if year == 2013
bysort region: egen region_agri_share = max(region_agri_share_2013)
drop region_agri_share_2013

* Create terciles
xtile treat_tercile = region_agri_share, nq(3)
label define tercile_lbl 1 "Low agri share" 2 "Medium" 3 "High agri share"
label values treat_tercile tercile_lbl

di _n "--- Regional agricultural share distribution ---"
sum region_agri_share, detail
tab treat_tercile

di _n "--- Sample by treatment tercile ---"
tab treat_tercile agri

********************************************************************************
* PART 2: Effects by treatment tercile
********************************************************************************

di ""
di "======================================================================"
di "PART 2: EFFECTS BY AGRICULTURAL INTENSITY TERCILE"
di "======================================================================"

cap drop agri_post
gen agri_post = agri * post

* Overall effect (baseline)
di _n "=== OVERALL ==="
reghdfe ln_wage agri_post, absorb(idind year) cluster(region)

* By treatment tercile
di _n "=== LOW AGRICULTURAL INTENSITY (Tercile 1) ==="
reghdfe ln_wage agri_post if treat_tercile == 1, absorb(idind year) cluster(region)

di _n "=== MEDIUM AGRICULTURAL INTENSITY (Tercile 2) ==="
reghdfe ln_wage agri_post if treat_tercile == 2, absorb(idind year) cluster(region)

di _n "=== HIGH AGRICULTURAL INTENSITY (Tercile 3) ==="
reghdfe ln_wage agri_post if treat_tercile == 3, absorb(idind year) cluster(region)

********************************************************************************
* PART 3: Continuous intensity specification
********************************************************************************

di ""
di "======================================================================"
di "PART 3: CONTINUOUS REGIONAL INTENSITY"
di "======================================================================"

* Standardize intensity
sum region_agri_share
gen intensity_std = (region_agri_share - r(mean)) / r(sd)

* Triple-diff: Agri × Post × Regional Intensity
gen agri_intensity_post = agri * post * intensity_std

di _n "=== TRIPLE DIFFERENCE: Agri × Post × Regional Intensity (standardized) ==="
reghdfe ln_wage agri_post agri_intensity_post, absorb(idind year) cluster(region)

********************************************************************************
* PART 4: High vs Low agricultural regions
********************************************************************************

di ""
di "======================================================================"
di "PART 4: HIGH VS LOW AGRICULTURAL REGIONS"
di "======================================================================"

* Create high/low indicator (above median)
sum region_agri_share, detail
gen high_agri_region = (region_agri_share > r(p50))

di _n "=== HIGH AGRICULTURAL REGIONS (above median) ==="
reghdfe ln_wage agri_post if high_agri_region == 1, absorb(idind year) cluster(region)

di _n "=== LOW AGRICULTURAL REGIONS (below median) ==="
reghdfe ln_wage agri_post if high_agri_region == 0, absorb(idind year) cluster(region)

* Formal interaction test
gen agri_post_high = agri_post * high_agri_region

di _n "=== INTERACTION TEST ==="
reghdfe ln_wage agri_post agri_post_high, absorb(idind year) cluster(region)

********************************************************************************
* PART 5: Regional fixed effects heterogeneity
********************************************************************************

di ""
di "======================================================================"
di "PART 5: TOP AND BOTTOM REGIONS"
di "======================================================================"

* Identify regions with highest/lowest agricultural shares
preserve
collapse (mean) region_agri_share, by(region)
gsort -region_agri_share
list in 1/10
gsort region_agri_share
list in 1/10
restore

********************************************************************************
* PART 6: Export regional summary
********************************************************************************

preserve
collapse (mean) region_agri_share (count) n_total=ln_wage (sum) n_agri=agri, by(region)
gen agri_share_pct = region_agri_share * 100
gsort -region_agri_share
export delimited using "output/tables/regional_intensity_summary.csv", replace
list region agri_share_pct n_agri n_total in 1/20
restore

di ""
di "Analysis complete!"
log close
