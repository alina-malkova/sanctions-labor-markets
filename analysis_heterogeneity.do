********************************************************************************
* Heterogeneity Analysis: Labor Supply Elasticity
* Testing whether effects differ by region, age, and education
********************************************************************************

clear all
set more off
cap log close
log using "output/analysis_heterogeneity_log.txt", replace text

* Load analysis sample
use "output/rlms_analysis_sample.dta", clear

* Keep primary sample period
keep if year >= 2010 & year <= 2019

di ""
di "======================================================================"
di "HETEROGENEITY ANALYSIS: LABOR SUPPLY ELASTICITY"
di "======================================================================"

********************************************************************************
* PART 1: Create heterogeneity variables
********************************************************************************

di ""
di "--- Creating heterogeneity variables ---"

* 1. Region type: Rural vs Urban/Peri-urban
* RLMS has settlement type information - use region characteristics
* Regions with high agricultural employment share = more rural
bysort region: egen region_agri_share = mean(agri) if year == 2013
bysort region: egen temp = max(region_agri_share)
replace region_agri_share = temp
drop temp

* Define rural as regions with above-median agricultural share
sum region_agri_share, detail
gen rural = (region_agri_share > r(p50)) if region_agri_share != .
label define rural_lbl 0 "Urban/Peri-urban" 1 "Rural"
label values rural rural_lbl

tab rural, m

* 2. Worker age groups (mobility proxy)
* Younger workers more mobile, older workers more tied to location
gen age_group = .
replace age_group = 1 if age >= 18 & age < 35
replace age_group = 2 if age >= 35 & age < 50
replace age_group = 3 if age >= 50 & age <= 65
label define age_lbl 1 "Young (18-34)" 2 "Middle (35-49)" 3 "Older (50-65)"
label values age_group age_lbl

* Binary: Young vs Older (mobility proxy)
gen young = (age < 40)
label define young_lbl 0 "Age 40+" 1 "Age <40"
label values young young_lbl

tab age_group, m

* 3. Education level
* Higher education = more mobile, more outside options
gen high_educ = (educ >= 4) if educ != .  // University or higher
label define educ_lbl 0 "No university" 1 "University+"
label values high_educ educ_lbl

tab high_educ, m

* Summary of heterogeneity variables for agricultural workers
di ""
di "--- Heterogeneity variable distribution (agricultural workers) ---"
preserve
keep if agri == 1
tab rural
tab age_group
tab high_educ
restore

********************************************************************************
* PART 2: Heterogeneity by Region Type (Rural vs Urban)
********************************************************************************

di ""
di "======================================================================"
di "PART 2: HETEROGENEITY BY REGION TYPE"
di "======================================================================"

* Interaction specification
gen agri_post = agri * post
gen agri_post_rural = agri * post * rural
gen agri_rural = agri * rural
gen post_rural = post * rural

* Full interaction model
reghdfe ln_wage agri_post agri_post_rural agri_rural post_rural, ///
    absorb(idind year) cluster(region)
eststo region1

* Separate regressions by region type
di ""
di "--- Rural regions ---"
reghdfe ln_wage agri_post if rural == 1, absorb(idind year) cluster(region)
eststo rural1
local b_rural = _b[agri_post]
local se_rural = _se[agri_post]

di ""
di "--- Urban/Peri-urban regions ---"
reghdfe ln_wage agri_post if rural == 0, absorb(idind year) cluster(region)
eststo urban1
local b_urban = _b[agri_post]
local se_urban = _se[agri_post]

di ""
di "SUMMARY: Region heterogeneity"
di "  Rural regions: " %5.3f `b_rural' " (" %5.3f `se_rural' ")"
di "  Urban regions: " %5.3f `b_urban' " (" %5.3f `se_urban' ")"
di "  Difference: " %5.3f (`b_rural' - `b_urban')

********************************************************************************
* PART 3: Heterogeneity by Age (Mobility Proxy)
********************************************************************************

di ""
di "======================================================================"
di "PART 3: HETEROGENEITY BY AGE (MOBILITY PROXY)"
di "======================================================================"

* Interaction with young
gen agri_post_young = agri * post * young
gen agri_young = agri * young
gen post_young = post * young

reghdfe ln_wage agri_post agri_post_young agri_young post_young, ///
    absorb(idind year) cluster(region)
eststo age1

* Separate by age group
di ""
di "--- Young workers (age < 40) ---"
reghdfe ln_wage agri_post if young == 1, absorb(idind year) cluster(region)
eststo young1
local b_young = _b[agri_post]
local se_young = _se[agri_post]

di ""
di "--- Older workers (age 40+) ---"
reghdfe ln_wage agri_post if young == 0, absorb(idind year) cluster(region)
eststo old1
local b_old = _b[agri_post]
local se_old = _se[agri_post]

di ""
di "SUMMARY: Age heterogeneity"
di "  Young (<40): " %5.3f `b_young' " (" %5.3f `se_young' ")"
di "  Older (40+): " %5.3f `b_old' " (" %5.3f `se_old' ")"
di "  Difference: " %5.3f (`b_old' - `b_young')

* By three age groups
di ""
di "--- By age group ---"
forval g = 1/3 {
    qui reghdfe ln_wage agri_post if age_group == `g', absorb(idind year) cluster(region)
    local b = _b[agri_post]
    local se = _se[agri_post]
    local lab: label age_lbl `g'
    di "  `lab': " %5.3f `b' " (" %5.3f `se' ")"
}

********************************************************************************
* PART 4: Heterogeneity by Education
********************************************************************************

di ""
di "======================================================================"
di "PART 4: HETEROGENEITY BY EDUCATION"
di "======================================================================"

* Interaction with high education
gen agri_post_educ = agri * post * high_educ
gen agri_educ = agri * high_educ
gen post_educ = post * high_educ

reghdfe ln_wage agri_post agri_post_educ agri_educ post_educ, ///
    absorb(idind year) cluster(region)
eststo educ1

* Separate by education
di ""
di "--- No university ---"
reghdfe ln_wage agri_post if high_educ == 0, absorb(idind year) cluster(region)
eststo loeduc1
local b_lo = _b[agri_post]
local se_lo = _se[agri_post]

di ""
di "--- University+ ---"
reghdfe ln_wage agri_post if high_educ == 1, absorb(idind year) cluster(region)
eststo hieduc1
local b_hi = _b[agri_post]
local se_hi = _se[agri_post]

di ""
di "SUMMARY: Education heterogeneity"
di "  No university: " %5.3f `b_lo' " (" %5.3f `se_lo' ")"
di "  University+:   " %5.3f `b_hi' " (" %5.3f `se_hi' ")"
di "  Difference:    " %5.3f (`b_lo' - `b_hi')

********************************************************************************
* PART 5: Hours heterogeneity (test if hours effect also varies)
********************************************************************************

di ""
di "======================================================================"
di "PART 5: HOURS HETEROGENEITY"
di "======================================================================"

* Does hours increase vary by worker type?
di ""
di "--- Hours effect by region type ---"
reghdfe hours agri_post if rural == 1, absorb(idind year) cluster(region)
local h_rural = _b[agri_post]
reghdfe hours agri_post if rural == 0, absorb(idind year) cluster(region)
local h_urban = _b[agri_post]
di "  Rural: " %5.2f `h_rural' " hours/month"
di "  Urban: " %5.2f `h_urban' " hours/month"

di ""
di "--- Hours effect by age ---"
reghdfe hours agri_post if young == 1, absorb(idind year) cluster(region)
local h_young = _b[agri_post]
reghdfe hours agri_post if young == 0, absorb(idind year) cluster(region)
local h_old = _b[agri_post]
di "  Young: " %5.2f `h_young' " hours/month"
di "  Older: " %5.2f `h_old' " hours/month"

di ""
di "--- Hours effect by education ---"
reghdfe hours agri_post if high_educ == 0, absorb(idind year) cluster(region)
local h_lo = _b[agri_post]
reghdfe hours agri_post if high_educ == 1, absorb(idind year) cluster(region)
local h_hi = _b[agri_post]
di "  No university: " %5.2f `h_lo' " hours/month"
di "  University+:   " %5.2f `h_hi' " hours/month"

********************************************************************************
* PART 6: Triple-difference: Region x Age
********************************************************************************

di ""
di "======================================================================"
di "PART 6: TRIPLE INTERACTION (REGION x AGE)"
di "======================================================================"

* Most constrained group: older workers in rural areas
gen rural_old = rural * (1-young)
gen agri_post_rural_old = agri * post * rural * (1-young)

* Four-way comparison
di ""
di "--- Effect by Region x Age ---"

* Rural + Old (most constrained)
qui reghdfe ln_wage agri_post if rural == 1 & young == 0, absorb(idind year) cluster(region)
local b1 = _b[agri_post]
local se1 = _se[agri_post]
di "  Rural + Older:     " %5.3f `b1' " (" %5.3f `se1' ")"

* Rural + Young
qui reghdfe ln_wage agri_post if rural == 1 & young == 1, absorb(idind year) cluster(region)
local b2 = _b[agri_post]
local se2 = _se[agri_post]
di "  Rural + Young:     " %5.3f `b2' " (" %5.3f `se2' ")"

* Urban + Old
qui reghdfe ln_wage agri_post if rural == 0 & young == 0, absorb(idind year) cluster(region)
local b3 = _b[agri_post]
local se3 = _se[agri_post]
di "  Urban + Older:     " %5.3f `b3' " (" %5.3f `se3' ")"

* Urban + Young (most mobile)
qui reghdfe ln_wage agri_post if rural == 0 & young == 1, absorb(idind year) cluster(region)
local b4 = _b[agri_post]
local se4 = _se[agri_post]
di "  Urban + Young:     " %5.3f `b4' " (" %5.3f `se4' ")"

di ""
di "Prediction: If inelastic labor supply drives persistence,"
di "effects should be largest for least mobile workers (rural + older)"

********************************************************************************
* PART 7: Export results table
********************************************************************************

di ""
di "======================================================================"
di "PART 7: SUMMARY TABLE"
di "======================================================================"

* Create summary table
matrix results = J(8, 4, .)

* Row 1: Overall
qui reghdfe ln_wage agri_post, absorb(idind year) cluster(region)
matrix results[1,1] = _b[agri_post]
matrix results[1,2] = _se[agri_post]
qui count if e(sample)
matrix results[1,3] = r(N)
qui count if e(sample) & agri == 1
matrix results[1,4] = r(N)

* Row 2: Rural
qui reghdfe ln_wage agri_post if rural == 1, absorb(idind year) cluster(region)
matrix results[2,1] = _b[agri_post]
matrix results[2,2] = _se[agri_post]
qui count if e(sample)
matrix results[2,3] = r(N)
qui count if e(sample) & agri == 1
matrix results[2,4] = r(N)

* Row 3: Urban
qui reghdfe ln_wage agri_post if rural == 0, absorb(idind year) cluster(region)
matrix results[3,1] = _b[agri_post]
matrix results[3,2] = _se[agri_post]
qui count if e(sample)
matrix results[3,3] = r(N)
qui count if e(sample) & agri == 1
matrix results[3,4] = r(N)

* Row 4: Young
qui reghdfe ln_wage agri_post if young == 1, absorb(idind year) cluster(region)
matrix results[4,1] = _b[agri_post]
matrix results[4,2] = _se[agri_post]
qui count if e(sample)
matrix results[4,3] = r(N)
qui count if e(sample) & agri == 1
matrix results[4,4] = r(N)

* Row 5: Older
qui reghdfe ln_wage agri_post if young == 0, absorb(idind year) cluster(region)
matrix results[5,1] = _b[agri_post]
matrix results[5,2] = _se[agri_post]
qui count if e(sample)
matrix results[5,3] = r(N)
qui count if e(sample) & agri == 1
matrix results[5,4] = r(N)

* Row 6: No university
qui reghdfe ln_wage agri_post if high_educ == 0, absorb(idind year) cluster(region)
matrix results[6,1] = _b[agri_post]
matrix results[6,2] = _se[agri_post]
qui count if e(sample)
matrix results[6,3] = r(N)
qui count if e(sample) & agri == 1
matrix results[6,4] = r(N)

* Row 7: University
qui reghdfe ln_wage agri_post if high_educ == 1, absorb(idind year) cluster(region)
matrix results[7,1] = _b[agri_post]
matrix results[7,2] = _se[agri_post]
qui count if e(sample)
matrix results[7,3] = r(N)
qui count if e(sample) & agri == 1
matrix results[7,4] = r(N)

* Row 8: Rural + Older
qui reghdfe ln_wage agri_post if rural == 1 & young == 0, absorb(idind year) cluster(region)
matrix results[8,1] = _b[agri_post]
matrix results[8,2] = _se[agri_post]
qui count if e(sample)
matrix results[8,3] = r(N)
qui count if e(sample) & agri == 1
matrix results[8,4] = r(N)

matrix rownames results = "Overall" "Rural" "Urban" "Young(<40)" "Older(40+)" "NoUniv" "Univ+" "Rural+Older"
matrix colnames results = "Coefficient" "SE" "N_total" "N_agri"

matlist results, format(%9.3f)

* Export to CSV
preserve
clear
svmat results, names(col)
gen group = ""
replace group = "Overall" in 1
replace group = "Rural regions" in 2
replace group = "Urban regions" in 3
replace group = "Young (age<40)" in 4
replace group = "Older (age 40+)" in 5
replace group = "No university" in 6
replace group = "University+" in 7
replace group = "Rural + Older" in 8
order group
export delimited using "output/tables/heterogeneity_results.csv", replace
restore

di ""
di "Analysis complete!"

log close
