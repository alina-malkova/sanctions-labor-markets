********************************************************************************
* Simple Timing Analysis: Embargo (Aug 2014) vs. Ruble Crash (Dec 2014)
*
* Alternative specifications that don't rely on individual FE
* (which requires within-person variation)
********************************************************************************

clear all
set more off

cd "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Working santctions"

capture log close
log using "output/timing/analysis_timing_simple_log.txt", replace text

********************************************************************************
* Load prepared data
********************************************************************************

use "output/timing/rlms_timing_sample.dta", clear

* Recreate key variables
gen agri = (industry == 8)
label var agri "Agriculture sector"

gen timing_period = .
replace timing_period = 0 if year < 2014
replace timing_period = 1 if year == 2014 & interview_month < 8
replace timing_period = 2 if year == 2014 & interview_month >= 8 & interview_month <= 11
replace timing_period = 3 if year == 2014 & interview_month == 12
replace timing_period = 4 if year >= 2015

label define timing_lbl 0 "Pre-2014" 1 "Jan-Jul 2014" 2 "Aug-Nov 2014" 3 "Dec 2014" 4 "2015+"
label values timing_period timing_lbl

* Post indicator
gen post = (year >= 2014)
gen agri_post = agri * post

* Key timing indicators
gen embargo_precrash = (timing_period == 2)
gen agri_embargo_precrash = agri * embargo_precrash

gen post_crash = (timing_period >= 3)
gen agri_post_crash = agri * post_crash

********************************************************************************
* PART 1: Pooled OLS with Controls (No Individual FE)
********************************************************************************

di as text "=========================================="
di as text "PART 1: Pooled OLS with Controls"
di as text "=========================================="

eststo clear

* Model 1: Basic pooled OLS
eststo p1: reg ln_wage agri_post agri post i.year, cluster(region)

* Model 2: With demographic controls
eststo p2: reg ln_wage agri_post agri post age age_sq female i.educ_cat i.year, cluster(region)

* Model 3: Aug-Nov 2014 vs Pre-2014
preserve
keep if timing_period == 0 | timing_period == 2
eststo p3: reg ln_wage agri_embargo_precrash agri embargo_precrash ///
    age age_sq female i.educ_cat i.year, cluster(region)
di "Coefficient on Aug-Nov 2014 effect: " _b[agri_embargo_precrash]
restore

* Model 4: Full timing model
gen agri_p2 = agri * (timing_period == 2)
gen agri_p3 = agri * (timing_period == 3)
gen agri_p4 = agri * (timing_period == 4)

eststo p4: reg ln_wage agri_p2 agri_p3 agri_p4 agri i.timing_period ///
    age age_sq female i.educ_cat, cluster(region)

esttab p1 p2 p3 p4 using "output/timing/table_pooled_ols.tex", ///
    replace booktabs label ///
    title("Pooled OLS: Timing of Agricultural Wage Effects") ///
    keep(agri_post agri_embargo_precrash agri_p2 agri_p3 agri_p4 agri) ///
    stats(N r2_a, labels("Observations" "Adj. R-squared")) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    se(3) b(3)

esttab p1 p2 p3 p4 using "output/timing/table_pooled_ols.csv", ///
    replace csv label

********************************************************************************
* PART 2: Year Fixed Effects with Industry FE (Not Individual FE)
********************************************************************************

di as text "=========================================="
di as text "PART 2: Year + Industry FE"
di as text "=========================================="

eststo clear

* Model 1: Year + Industry FE
eststo y1: reghdfe ln_wage agri_post, absorb(year industry) cluster(region)

* Model 2: With controls
eststo y2: reghdfe ln_wage agri_post age age_sq female i.educ_cat, ///
    absorb(year industry) cluster(region)

* Model 3: Aug-Nov 2014 effect
preserve
keep if timing_period == 0 | timing_period == 2
eststo y3: reghdfe ln_wage agri_embargo_precrash age age_sq female i.educ_cat, ///
    absorb(year industry) cluster(region)
restore

* Model 4: Full timing
eststo y4: reghdfe ln_wage agri_p2 agri_p3 agri_p4 age age_sq female i.educ_cat, ///
    absorb(year industry) cluster(region)

esttab y1 y2 y3 y4 using "output/timing/table_year_industry_fe.tex", ///
    replace booktabs label ///
    title("Year + Industry FE: Timing Effects") ///
    keep(agri_post agri_embargo_precrash agri_p2 agri_p3 agri_p4) ///
    stats(N r2_a, labels("Observations" "Adj. R-squared")) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    se(3) b(3)

esttab y1 y2 y3 y4 using "output/timing/table_year_industry_fe.csv", ///
    replace csv label

********************************************************************************
* PART 3: Repeated Cross-Section DiD
********************************************************************************

di as text "=========================================="
di as text "PART 3: Repeated Cross-Section DiD"
di as text "=========================================="

* This is the cleanest test: compare agri vs non-agri workers
* in 2013 vs Oct-Nov 2014

preserve

* Keep only 2013 and Aug-Nov 2014
keep if year == 2013 | (year == 2014 & interview_month >= 8 & interview_month <= 11)

gen post_embargo = (year == 2014)
gen agri_x_post = agri * post_embargo

di "=== SAMPLE SIZES ==="
tab year agri

di "=== MEAN WAGES ==="
table year agri, stat(mean ln_wage) stat(mean wage_month) stat(count ln_wage)

eststo clear

* Basic DiD
eststo cs1: reg ln_wage agri_x_post agri post_embargo, cluster(region)
di "Basic DiD coefficient: " _b[agri_x_post]

* With controls
eststo cs2: reg ln_wage agri_x_post agri post_embargo ///
    age age_sq female i.educ_cat, cluster(region)
di "DiD with controls: " _b[agri_x_post]

* With region FE
eststo cs3: reghdfe ln_wage agri_x_post agri post_embargo ///
    age age_sq female i.educ_cat, absorb(region) cluster(region)
di "DiD with region FE: " _b[agri_x_post]

* With region x year FE (absorbs post_embargo)
eststo cs4: reghdfe ln_wage agri_x_post agri ///
    age age_sq female i.educ_cat, absorb(region#year) cluster(region)
di "DiD with region x year FE: " _b[agri_x_post]

esttab cs1 cs2 cs3 cs4 using "output/timing/table_cross_section_did.tex", ///
    replace booktabs label ///
    title("Cross-Section DiD: 2013 vs. Aug-Nov 2014") ///
    mtitles("Basic" "+Controls" "+Region FE" "+Region x Year FE") ///
    keep(agri_x_post agri post_embargo) ///
    coeflabels(agri_x_post "Agriculture $\times$ Post-Embargo" ///
               agri "Agriculture" post_embargo "Post-Embargo (Aug-Nov 2014)") ///
    stats(N r2_a, labels("Observations" "Adj. R-squared")) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    se(3) b(3) ///
    addnotes("Sample: 2013 + Aug-Nov 2014 interviews only." ///
             "This compares agricultural vs. other workers before vs. after embargo," ///
             "but BEFORE the December 2014 ruble crash.")

esttab cs1 cs2 cs3 cs4 using "output/timing/table_cross_section_did.csv", ///
    replace csv label

restore

********************************************************************************
* PART 4: Compare Effects Before vs. After Crash
********************************************************************************

di as text "=========================================="
di as text "PART 4: Before vs. After Crash Comparison"
di as text "=========================================="

* Test: Is the effect in Aug-Nov 2014 different from effect in 2015+?

preserve

* Keep 2013, Aug-Nov 2014, and 2015
keep if year == 2013 | (year == 2014 & interview_month >= 8 & interview_month <= 11) | year == 2015

gen period = 0 if year == 2013
replace period = 1 if year == 2014  // Aug-Nov 2014 (post-embargo, pre-crash)
replace period = 2 if year == 2015  // Post-crash

gen agri_aug_nov = agri * (period == 1)
gen agri_2015 = agri * (period == 2)

di "=== SAMPLE SIZES ==="
tab period agri

eststo clear

* Both effects
eststo both: reg ln_wage agri_aug_nov agri_2015 agri i.period ///
    age age_sq female i.educ_cat, cluster(region)

di ""
di "=== KEY COMPARISON ==="
di "Effect in Aug-Nov 2014 (pre-crash):  " _b[agri_aug_nov] " (SE: " _se[agri_aug_nov] ")"
di "Effect in 2015 (post-crash):         " _b[agri_2015] " (SE: " _se[agri_2015] ")"

* Test if coefficients are equal
test agri_aug_nov = agri_2015
di "Test H0: Aug-Nov 2014 effect = 2015 effect"
di "F-statistic: " r(F)
di "P-value: " r(p)

restore

********************************************************************************
* PART 5: Summary Statistics for Paper
********************************************************************************

di as text "=========================================="
di as text "PART 5: Summary Statistics"
di as text "=========================================="

* Raw wage comparison
di "=== RAW WAGE COMPARISON ==="
di ""
di "Period                | Agri Mean | Other Mean | Agri-Other | N(Agri)"
di "----------------------|-----------|------------|------------|--------"

foreach yr in 2012 2013 {
    preserve
    keep if year == `yr'
    qui sum wage_month if agri == 1
    local agri_mean = r(mean)
    local n_agri = r(N)
    qui sum wage_month if agri == 0
    local other_mean = r(mean)
    local diff = `agri_mean' - `other_mean'
    di "`yr' (pre-embargo)   | " %9.0f `agri_mean' " | " %10.0f `other_mean' " | " %10.0f `diff' " | " %6.0f `n_agri'
    restore
}

* Aug-Nov 2014
preserve
keep if year == 2014 & interview_month >= 8 & interview_month <= 11
qui sum wage_month if agri == 1
local agri_mean = r(mean)
local n_agri = r(N)
qui sum wage_month if agri == 0
local other_mean = r(mean)
local diff = `agri_mean' - `other_mean'
di "Aug-Nov 2014 (KEY)   | " %9.0f `agri_mean' " | " %10.0f `other_mean' " | " %10.0f `diff' " | " %6.0f `n_agri'
restore

* Dec 2014
preserve
keep if year == 2014 & interview_month == 12
qui sum wage_month if agri == 1
local agri_mean = r(mean)
local n_agri = r(N)
qui sum wage_month if agri == 0
local other_mean = r(mean)
local diff = `agri_mean' - `other_mean'
di "Dec 2014 (crash)     | " %9.0f `agri_mean' " | " %10.0f `other_mean' " | " %10.0f `diff' " | " %6.0f `n_agri'
restore

foreach yr in 2015 2016 {
    preserve
    keep if year == `yr'
    qui sum wage_month if agri == 1
    local agri_mean = r(mean)
    local n_agri = r(N)
    qui sum wage_month if agri == 0
    local other_mean = r(mean)
    local diff = `agri_mean' - `other_mean'
    di "`yr' (post-crash)    | " %9.0f `agri_mean' " | " %10.0f `other_mean' " | " %10.0f `diff' " | " %6.0f `n_agri'
    restore
}

********************************************************************************
* CLOSE
********************************************************************************

di as text "=========================================="
di as text "Analysis Complete"
di as text "=========================================="
di ""
di "Key outputs:"
di "  - table_pooled_ols.tex: Pooled OLS results"
di "  - table_year_industry_fe.tex: Year + Industry FE results"
di "  - table_cross_section_did.tex: Cross-section DiD (KEY)"
di ""
di "The cross-section DiD compares:"
di "  - Treatment: Agriculture workers"
di "  - Control: Other workers"
di "  - Pre: 2013"
di "  - Post: Aug-Nov 2014 (after embargo, BEFORE crash)"
di ""

log close
