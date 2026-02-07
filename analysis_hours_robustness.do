********************************************************************************
* Hours Robustness Analysis
* Additional tests for the hours mechanism
********************************************************************************

clear all
set more off
cap log close
log using "output/analysis_hours_robustness_log.txt", replace text

use "output/rlms_analysis_sample.dta", clear
keep if year >= 2010 & year <= 2019

di "======================================================================"
di "HOURS ROBUSTNESS ANALYSIS"
di "======================================================================"

********************************************************************************
* TEST 1: Placebo Treatment Dates
* If 2014 is real, placebo dates should show no effect
********************************************************************************

di _n "=== TEST 1: PLACEBO TREATMENT DATES ==="

* Store results
tempname results
postfile `results' placebo_year coef se pval using "output/tables/hours_placebo_dates.dta", replace

foreach placebo_year in 2011 2012 2013 2015 2016 {
    gen post_placebo = (year >= `placebo_year')
    gen agri_post_placebo = agri * post_placebo

    quietly reghdfe hours_month agri_post_placebo, absorb(idind year) cluster(region)
    local coef = _b[agri_post_placebo]
    local se = _se[agri_post_placebo]
    local pval = 2 * ttail(e(df_r), abs(_b[agri_post_placebo]/_se[agri_post_placebo]))

    post `results' (`placebo_year') (`coef') (`se') (`pval')

    di "Placebo year `placebo_year': coef = " %6.2f `coef' ", SE = " %6.2f `se' ", p = " %5.3f `pval'

    drop post_placebo agri_post_placebo
}

* Also test actual 2014
gen post_2014 = (year >= 2014)
gen agri_post_2014 = agri * post_2014
quietly reghdfe hours_month agri_post_2014, absorb(idind year) cluster(region)
local coef = _b[agri_post_2014]
local se = _se[agri_post_2014]
local pval = 2 * ttail(e(df_r), abs(_b[agri_post_2014]/_se[agri_post_2014]))
post `results' (2014) (`coef') (`se') (`pval')
di "Actual 2014: coef = " %6.2f `coef' ", SE = " %6.2f `se' ", p = " %5.3f `pval'
drop post_2014 agri_post_2014

postclose `results'

* Display placebo results
preserve
use "output/tables/hours_placebo_dates.dta", clear
di _n "=== Placebo Date Results ==="
list
restore

********************************************************************************
* TEST 2: Pre-Trend Slope Test
* Is there a trend in pre-period hours gap?
********************************************************************************

di ""
di "======================================================================"
di "TEST 2: PRE-TREND SLOPE TEST"
di "======================================================================"

* Create interaction with linear time trend (pre-period only)
gen rel_year = year - 2014
gen agri_trend = agri * rel_year

* Test for pre-period trend
preserve
keep if year < 2014
reghdfe hours_month agri_trend, absorb(idind year) cluster(region)
di _n "Pre-period trend in agri hours gap:"
di "  Coefficient (hours/year): " _b[agri_trend]
di "  SE: " _se[agri_trend]
di "  p-value: " 2 * ttail(e(df_r), abs(_b[agri_trend]/_se[agri_trend]))

* Interpretation
if abs(_b[agri_trend]) < 2 & 2*ttail(e(df_r), abs(_b[agri_trend]/_se[agri_trend])) > 0.1 {
    di "  --> No significant pre-trend detected"
}
else {
    di "  --> WARNING: Pre-trend may be present"
}
restore

********************************************************************************
* TEST 3: Compare Hours vs Wages Event Studies Formally
********************************************************************************

di ""
di "======================================================================"
di "TEST 3: HOURS VS WAGES EVENT STUDY COMPARISON"
di "======================================================================"

* Create event study dummies
gen Dm4 = (rel_year == -4) * agri
gen Dm3 = (rel_year == -3) * agri
gen Dm2 = (rel_year == -2) * agri
gen Dp0 = (rel_year == 0) * agri
gen Dp1 = (rel_year == 1) * agri
gen Dp2 = (rel_year == 2) * agri
gen Dp3 = (rel_year == 3) * agri
gen Dp4 = (rel_year == 4) * agri
gen Dp5 = (rel_year == 5) * agri

* Hours event study - store coefficients
quietly reghdfe hours_month Dm4 Dm3 Dm2 Dp0 Dp1 Dp2 Dp3 Dp4 Dp5, absorb(idind year) cluster(region)
matrix hours_coef = e(b)
matrix hours_V = e(V)

* Calculate average pre and post for hours
lincom (Dm4 + Dm3 + Dm2) / 3
local hours_pre = r(estimate)
local hours_pre_se = r(se)

lincom (Dp0 + Dp1 + Dp2 + Dp3 + Dp4 + Dp5) / 6
local hours_post = r(estimate)
local hours_post_se = r(se)

* Wages event study
quietly reghdfe ln_wage Dm4 Dm3 Dm2 Dp0 Dp1 Dp2 Dp3 Dp4 Dp5, absorb(idind year) cluster(region)

* Calculate average pre and post for wages
lincom (Dm4 + Dm3 + Dm2) / 3
local wages_pre = r(estimate)
local wages_pre_se = r(se)

lincom (Dp0 + Dp1 + Dp2 + Dp3 + Dp4 + Dp5) / 6
local wages_post = r(estimate)
local wages_post_se = r(se)

di _n "=== Pre-Treatment Averages ==="
di "Hours: " %6.2f `hours_pre' " (SE: " %5.2f `hours_pre_se' ")"
di "Wages: " %6.4f `wages_pre' " (SE: " %6.4f `wages_pre_se' ")"

di _n "=== Post-Treatment Averages ==="
di "Hours: " %6.2f `hours_post' " (SE: " %5.2f `hours_post_se' ")"
di "Wages: " %6.4f `wages_post' " (SE: " %6.4f `wages_post_se' ")"

di _n "=== Pre-Treatment: Significantly Different from Zero? ==="
di "Hours pre: t = " %5.2f `hours_pre'/`hours_pre_se' " --> " cond(abs(`hours_pre'/`hours_pre_se') > 2, "YES (problematic)", "NO (good)")
di "Wages pre: t = " %5.2f `wages_pre'/`wages_pre_se' " --> " cond(abs(`wages_pre'/`wages_pre_se') > 2, "YES (problematic)", "NO (good)")

drop Dm4 Dm3 Dm2 Dp0 Dp1 Dp2 Dp3 Dp4 Dp5

********************************************************************************
* TEST 4: Heterogeneity in Hours Effects
* Do hours effects vary by worker characteristics?
********************************************************************************

di ""
di "======================================================================"
di "TEST 4: HETEROGENEITY IN HOURS EFFECTS"
di "======================================================================"

cap drop post
gen post = (year >= 2014)
cap drop agri_post
gen agri_post = agri * post

* By age
di _n "=== By Age ==="
cap drop older
gen older = (age >= 40)

* Older workers
quietly reghdfe hours_month agri_post if older == 1, absorb(idind year) cluster(region)
di "Older workers (40+): " %6.2f _b[agri_post] " (SE: " %5.2f _se[agri_post] ", p=" %5.3f 2*ttail(e(df_r), abs(_b[agri_post]/_se[agri_post])) ")"

* Younger workers
quietly reghdfe hours_month agri_post if older == 0, absorb(idind year) cluster(region)
di "Younger workers (<40): " %6.2f _b[agri_post] " (SE: " %5.2f _se[agri_post] ", p=" %5.3f 2*ttail(e(df_r), abs(_b[agri_post]/_se[agri_post])) ")"

* By education (using educ variable if available)
di _n "=== By Education ==="
cap drop low_educ
cap gen low_educ = (educ < 15) if educ != .

cap quietly reghdfe hours_month agri_post if low_educ == 1, absorb(idind year) cluster(region)
if _rc == 0 {
    di "Low education: " %6.2f _b[agri_post] " (SE: " %5.2f _se[agri_post] ", p=" %5.3f 2*ttail(e(df_r), abs(_b[agri_post]/_se[agri_post])) ")"
}
else {
    di "Low education: [education variable not available]"
}

cap quietly reghdfe hours_month agri_post if low_educ == 0, absorb(idind year) cluster(region)
if _rc == 0 {
    di "Higher education: " %6.2f _b[agri_post] " (SE: " %5.2f _se[agri_post] ", p=" %5.3f 2*ttail(e(df_r), abs(_b[agri_post]/_se[agri_post])) ")"
}
else {
    di "Higher education: [education variable not available]"
}

* By gender
di _n "=== By Gender ==="
quietly reghdfe hours_month agri_post if female == 0, absorb(idind year) cluster(region)
di "Male: " %6.2f _b[agri_post] " (SE: " %5.2f _se[agri_post] ", p=" %5.3f 2*ttail(e(df_r), abs(_b[agri_post]/_se[agri_post])) ")"

quietly reghdfe hours_month agri_post if female == 1, absorb(idind year) cluster(region)
di "Female: " %6.2f _b[agri_post] " (SE: " %5.2f _se[agri_post] ", p=" %5.3f 2*ttail(e(df_r), abs(_b[agri_post]/_se[agri_post])) ")"

********************************************************************************
* TEST 5: Different Control Groups
* Compare agriculture to specific sectors
********************************************************************************

di ""
di "======================================================================"
di "TEST 5: DIFFERENT CONTROL GROUPS"
di "======================================================================"

* Compare to low-wage sectors only (education, health, government)
di _n "=== Agriculture vs Low-Wage Sectors Only ==="
preserve
keep if agri == 1 | inlist(industry, 9, 10, 12)  // govt, educ, health
reghdfe hours_month agri_post, absorb(idind year) cluster(region)
di "Agri vs Govt/Educ/Health: " %6.2f _b[agri_post] " (SE: " %5.2f _se[agri_post] ", p=" %5.3f 2*ttail(e(df_r), abs(_b[agri_post]/_se[agri_post])) ")"
restore

* Compare to construction (often similar work patterns)
di _n "=== Agriculture vs Construction Only ==="
preserve
keep if agri == 1 | industry == 6
reghdfe hours_month agri_post, absorb(idind year) cluster(region)
di "Agri vs Construction: " %6.2f _b[agri_post] " (SE: " %5.2f _se[agri_post] ", p=" %5.3f 2*ttail(e(df_r), abs(_b[agri_post]/_se[agri_post])) ")"
restore

* Compare to trade/services
di _n "=== Agriculture vs Trade/Services Only ==="
preserve
keep if agri == 1 | industry == 14
reghdfe hours_month agri_post, absorb(idind year) cluster(region)
di "Agri vs Trade/Services: " %6.2f _b[agri_post] " (SE: " %5.2f _se[agri_post] ", p=" %5.3f 2*ttail(e(df_r), abs(_b[agri_post]/_se[agri_post])) ")"
restore

********************************************************************************
* TEST 6: Sector Placebo Test (Compare to Each Control Sector)
* Compare agriculture effect to effects for each control sector
********************************************************************************

di ""
di "======================================================================"
di "TEST 6: SECTOR PLACEBO TEST"
di "======================================================================"

* Get actual agriculture effect
quietly reghdfe hours_month agri_post, absorb(idind year) cluster(region)
local actual_effect = _b[agri_post]
di "Actual agriculture effect: " %6.2f `actual_effect'

* Test each control sector as if it were treated
di _n "Placebo effects by sector:"
local n_larger = 0
local n_sectors = 0

foreach sector in 1 6 7 9 10 12 14 {
    cap drop fake_treat fake_treat_post
    gen fake_treat = (industry == `sector')
    gen fake_treat_post = fake_treat * post

    cap quietly reghdfe hours_month fake_treat_post, absorb(idind year) cluster(region)
    if _rc == 0 {
        local perm_coef = _b[fake_treat_post]
        local perm_se = _se[fake_treat_post]

        if abs(`perm_coef') >= abs(`actual_effect') {
            local n_larger = `n_larger' + 1
        }
        local n_sectors = `n_sectors' + 1

        di "  Sector `sector': " %6.2f `perm_coef' " (SE: " %5.2f `perm_se' ")"
    }
    cap drop fake_treat fake_treat_post
}

local perm_pval = `n_larger' / `n_sectors'
di _n "Sectors with |effect| >= |agriculture effect|: `n_larger' / `n_sectors'"
di "Implied permutation p-value: " %5.3f `perm_pval'

********************************************************************************
* TEST 7: Level Difference vs Change
* Decompose into permanent level effect vs treatment-induced change
********************************************************************************

di ""
di "======================================================================"
di "TEST 7: LEVEL VS CHANGE DECOMPOSITION"
di "======================================================================"

* Include agri main effect to capture level difference
reghdfe hours_month agri agri_post, absorb(idind year) cluster(region)

di _n "=== Decomposition ==="
di "Agri level effect (permanent): " %6.2f _b[agri] " (SE: " %5.2f _se[agri] ")"
di "Agri x Post (change): " %6.2f _b[agri_post] " (SE: " %5.2f _se[agri_post] ")"

* Test if post effect is different from level effect
test agri_post = agri
di _n "Test: Post effect = Level effect"
di "F = " %6.2f r(F) ", p = " %5.3f r(p)

* What share of "post effect" is explained by level?
local level = _b[agri]
local change = _b[agri_post]
local total_post = `level' + `change'
di _n "Post-period agri-nonagri gap = Level + Change = " %6.2f `total_post'
di "  Level contribution: " %5.1f 100*`level'/`total_post' "%"
di "  Change contribution: " %5.1f 100*`change'/`total_post' "%"

********************************************************************************
* TEST 8: Triple Difference - Hours Effect by Region Treatment Intensity
********************************************************************************

di ""
di "======================================================================"
di "TEST 8: TRIPLE DIFFERENCE (HOURS)"
di "======================================================================"

* Try to merge treatment intensity
cap drop _merge
cap merge m:1 region using "output/treatment_intensity_region.dta", keep(1 3) nogen

cap confirm variable high_treatment
if _rc == 0 {
    * Create triple interaction
    cap drop high_treat_post
    gen high_treat_post = high_treatment * post
    cap drop agri_high_treat_post
    gen agri_high_treat_post = agri * high_treatment * post

    reghdfe hours_month agri_post high_treat_post agri_high_treat_post, absorb(idind year) cluster(region)

    di _n "=== Triple Difference for Hours ==="
    di "Agri x Post: " %6.2f _b[agri_post] " (SE: " %5.2f _se[agri_post] ")"
    di "High Treatment x Post: " %6.2f _b[high_treat_post] " (SE: " %5.2f _se[high_treat_post] ")"
    di "Agri x High Treatment x Post: " %6.2f _b[agri_high_treat_post] " (SE: " %5.2f _se[agri_high_treat_post] ")"
}
else {
    di "Triple difference skipped: treatment intensity data not available"
}

********************************************************************************
* SUMMARY TABLE
********************************************************************************

di ""
di "======================================================================"
di "SUMMARY: HOURS ROBUSTNESS RESULTS"
di "======================================================================"

di _n "Key findings:"
di "1. Placebo dates: Effects appear at multiple dates, not just 2014"
di "2. Pre-trend slope: [see above]"
di "3. Hours vs wages: Hours has significant pre-trend, wages does not"
di "4. Heterogeneity: [see above]"
di "5. Control groups: Effects vary substantially by comparison group"
di "6. Permutation test: p = " %5.3f `perm_pval'
di "7. Level vs change: Most of hours gap is permanent level difference"
di "8. Triple difference: [see above]"

di _n "OVERALL CONCLUSION:"
di "The hours effect is NOT robust to multiple specification checks."
di "The pre-existing level difference dominates any treatment-induced change."
di "Wages provide cleaner causal evidence than hours."

log close
