* Quick timing analysis
clear all
set more off

cd "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Working santctions"

log using "output/timing/run_timing_log.txt", replace text

use "output/timing/rlms_timing_sample.dta", clear

* Variables
capture drop agri post_embargo agri_x_post
gen agri = (industry == 8)
gen post_embargo = (year == 2014 & interview_month >= 8 & interview_month <= 11)
gen agri_x_post = agri * post_embargo

* Keep 2013 and Aug-Nov 2014 only
preserve
keep if year == 2013 | (year == 2014 & interview_month >= 8 & interview_month <= 11)

di "=========================================="
di "SAMPLE: 2013 vs Aug-Nov 2014"
di "=========================================="
tab year agri

di ""
di "Mean wages:"
table year agri, stat(mean wage_month) stat(mean ln_wage) stat(count ln_wage)

di ""
di "=========================================="
di "REGRESSION RESULTS"
di "=========================================="

di ""
di "Model 1: Basic DiD (no controls)"
reg ln_wage agri_x_post agri post_embargo, cluster(region)

di ""
di "Model 2: With controls"
reg ln_wage agri_x_post agri post_embargo age age_sq female i.educ_cat, cluster(region)

di ""
di "Model 3: With region FE"
reghdfe ln_wage agri_x_post agri age age_sq female i.educ_cat, absorb(region year) cluster(region)

restore

di ""
di "=========================================="
di "FULL TIMING MODEL: 2012-2016"
di "=========================================="

* Full timing comparison
preserve
keep if year >= 2012 & year <= 2016

capture drop period agri_p*
gen period = year
replace period = 2014 if year == 2014 & interview_month >= 8 & interview_month <= 11
replace period = . if year == 2014 & interview_month < 8
replace period = . if year == 2014 & interview_month == 12
keep if period != .

gen agri_2012 = agri * (period == 2012)
gen agri_2014 = agri * (period == 2014)
gen agri_2015 = agri * (period == 2015)
gen agri_2016 = agri * (period == 2016)

di "Sample:"
tab period agri

di ""
di "Event study (ref = 2013):"
reg ln_wage agri_2012 agri_2014 agri_2015 agri_2016 agri i.period ///
    age age_sq female i.educ_cat, cluster(region)

di ""
di "=========================================="
di "INTERPRETATION"
di "=========================================="
di "agri_2012: Pre-trend (should be ~0)"
di "agri_2014: Aug-Nov 2014 effect (KEY - post-embargo, pre-crash)"
di "agri_2015: 2015 effect (post-crash)"
di "agri_2016: 2016 effect (long-run)"
di ""
di "If agri_2014 > 0, effects appeared BEFORE ruble crash"

restore

log close
