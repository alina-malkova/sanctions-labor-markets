********************************************************************************
* Pre-Trends Investigation and Trend-Adjusted DiD
* Address the negative pre-trend concern
********************************************************************************

clear all
set more off
cap log close
log using "output/analysis_pretrends_adjustment_log.txt", replace text

di "======================================================================"
di "PRE-TRENDS INVESTIGATION AND ADJUSTMENT"
di "======================================================================"

use "output/rlms_analysis_sample.dta", clear
keep if year >= 2010 & year <= 2019

********************************************************************************
* PART 1: Document the Pre-Trend
********************************************************************************

di _n "=== PART 1: DOCUMENT THE PRE-TREND ==="

* Year-by-year raw wage gaps
preserve
collapse (mean) ln_wage, by(agri year)
reshape wide ln_wage, i(year) j(agri)
gen gap = ln_wage1 - ln_wage0
di _n "=== Raw Wage Gap (Agri - Non-Agri) by Year ==="
list year ln_wage0 ln_wage1 gap

* Calculate pre-trend slope
reg gap year if year <= 2013
di _n "Pre-2014 trend in gap:"
di "  Slope: " _b[year] " log points per year"
di "  SE: " _se[year]
di "  p-value: " 2*ttail(e(df_r), abs(_b[year]/_se[year]))
local pre_slope = _b[year]
restore

********************************************************************************
* PART 2: Event Study with Individual Pre-Period Coefficients
********************************************************************************

di ""
di "======================================================================"
di "PART 2: DETAILED EVENT STUDY"
di "======================================================================"

gen rel_year = year - 2014

* Create event study dummies (omit -1 as reference)
forval t = -4/-2 {
    local tpos = abs(`t')
    gen Dm`tpos' = (rel_year == `t') * agri
}
forval t = 0/5 {
    gen Dp`t' = (rel_year == `t') * agri
}

* Run event study
reghdfe ln_wage Dm4 Dm3 Dm2 Dp0 Dp1 Dp2 Dp3 Dp4 Dp5, absorb(idind year) cluster(region)

di _n "=== Pre-Treatment Coefficients (relative to t=-1) ==="
di "  t=-4 (2010): " %7.4f _b[Dm4] " (SE: " %6.4f _se[Dm4] ", p=" %5.3f 2*ttail(e(df_r), abs(_b[Dm4]/_se[Dm4])) ")"
di "  t=-3 (2011): " %7.4f _b[Dm3] " (SE: " %6.4f _se[Dm3] ", p=" %5.3f 2*ttail(e(df_r), abs(_b[Dm3]/_se[Dm3])) ")"
di "  t=-2 (2012): " %7.4f _b[Dm2] " (SE: " %6.4f _se[Dm2] ", p=" %5.3f 2*ttail(e(df_r), abs(_b[Dm2]/_se[Dm2])) ")"
di "  t=-1 (2013): [reference = 0]"

* Test for pre-trend
di _n "=== Joint Test of Pre-Treatment Coefficients ==="
test Dm4 Dm3 Dm2
di "F = " r(F) ", p = " r(p)

* Test for linear pre-trend
di _n "=== Test for Linear Pre-Trend ==="
lincom Dm4 - 2*Dm3 + Dm2
di "Linear trend test (second difference): " r(estimate) " (p = " 2*normal(-abs(r(estimate)/r(se))) ")"

drop Dm4 Dm3 Dm2 Dp0 Dp1 Dp2 Dp3 Dp4 Dp5

********************************************************************************
* PART 3: Trend-Adjusted DiD Specifications
********************************************************************************

di ""
di "======================================================================"
di "PART 3: TREND-ADJUSTED SPECIFICATIONS"
di "======================================================================"

cap drop post
gen post = (year >= 2014)
cap drop agri_post
gen agri_post = agri * post

* Specification 1: Baseline (no trend adjustment)
di _n "=== Specification 1: Baseline DiD ==="
reghdfe ln_wage agri_post, absorb(idind year) cluster(region)
local b1 = _b[agri_post]
local se1 = _se[agri_post]
di "Coefficient: " %7.4f `b1' " (SE: " %6.4f `se1' ")"

* Specification 2: Group-specific linear trends
di _n "=== Specification 2: Group-Specific Linear Trends ==="
gen agri_trend = agri * year
reghdfe ln_wage agri_post agri_trend, absorb(idind year) cluster(region)
local b2 = _b[agri_post]
local se2 = _se[agri_post]
di "Agri x Post: " %7.4f `b2' " (SE: " %6.4f `se2' ")"
di "Agri x Trend: " %7.4f _b[agri_trend] " (SE: " %6.4f _se[agri_trend] ")"

* Specification 3: Extrapolate pre-trend
di _n "=== Specification 3: Pre-Trend Extrapolation ==="
* Estimate pre-trend from 2010-2013
preserve
keep if year <= 2013
gen agri_year = agri * year
reghdfe ln_wage agri_year, absorb(idind year) cluster(region)
local pre_trend = _b[agri_year]
di "Pre-trend slope: " %7.5f `pre_trend' " log points/year"
restore

* Create counterfactual: what would gap be if trend continued?
gen years_post = max(0, year - 2013)
gen counterfactual_decline = `pre_trend' * years_post * agri

* Adjusted outcome
gen ln_wage_adjusted = ln_wage - counterfactual_decline

reghdfe ln_wage_adjusted agri_post, absorb(idind year) cluster(region)
local b3 = _b[agri_post]
local se3 = _se[agri_post]
di "Trend-adjusted effect: " %7.4f `b3' " (SE: " %6.4f `se3' ")"
di "This represents the effect ABOVE what the pre-trend would predict"

* Specification 4: Difference-in-Difference-in-Differences with region
di _n "=== Specification 4: Triple-Difference (absorbs region-specific trends) ==="
cap drop _merge
cap merge m:1 region using "output/treatment_intensity_region.dta", keep(1 3) nogen
cap drop agri_high_post
cap gen agri_high_post = agri * high_treatment * post
cap reghdfe ln_wage agri_post agri_high_post, absorb(idind year region#c.year) cluster(region)
if _rc == 0 {
    di "Agri x Post: " %7.4f _b[agri_post]
    di "Agri x High x Post: " %7.4f _b[agri_high_post]
}
else {
    di "Triple-diff with region trends: could not estimate"
}

********************************************************************************
* PART 4: Sensitivity Analysis - How Much Pre-Trend Matters
********************************************************************************

di ""
di "======================================================================"
di "PART 4: SENSITIVITY TO PRE-TREND ASSUMPTIONS"
di "======================================================================"

* Calculate what the effect would be under different pre-trend assumptions
di _n "=== Sensitivity: Effect Under Different Pre-Trend Assumptions ==="

* Average post-period years from 2014
sum year if post == 1
local avg_post_year = r(mean) - 2013

di "Average years post-treatment: " %4.1f `avg_post_year'
di ""
di "Assumed Pre-Trend | Counterfactual Decline | Adjusted Effect"
di "--------------------|------------------------|----------------"

foreach trend in -0.02 -0.01 0 0.01 0.02 {
    local cf_decline = `trend' * `avg_post_year'
    local adj_effect = `b1' - `cf_decline'
    di %18.2f `trend' " | " %22.3f `cf_decline' " | " %14.3f `adj_effect'
}

********************************************************************************
* PART 5: Placebo Timing Tests (Detailed)
********************************************************************************

di ""
di "======================================================================"
di "PART 5: PLACEBO TIMING TESTS"
di "======================================================================"

tempname placebo
postfile `placebo' year coef se pval using "output/tables/placebo_timing_wages.dta", replace

foreach yr in 2011 2012 2013 2014 2015 2016 {
    cap drop post_placebo agri_post_placebo
    gen post_placebo = (year >= `yr')
    gen agri_post_placebo = agri * post_placebo

    quietly reghdfe ln_wage agri_post_placebo, absorb(idind year) cluster(region)
    local coef = _b[agri_post_placebo]
    local se = _se[agri_post_placebo]
    local pval = 2*ttail(e(df_r), abs(_b[agri_post_placebo]/_se[agri_post_placebo]))

    post `placebo' (`yr') (`coef') (`se') (`pval')

    di "Treatment year `yr': " %7.4f `coef' " (SE: " %6.4f `se' ", p=" %5.3f `pval' ")"
}

postclose `placebo'

* Interpret pattern
preserve
use "output/tables/placebo_timing_wages.dta", clear
list
* If 2011-2013 are negative and 2014+ positive, that's concerning
count if year < 2014 & coef < 0
local n_neg_pre = r(N)
count if year >= 2014 & coef > 0
local n_pos_post = r(N)
di _n "Pre-2014 negative coefficients: `n_neg_pre'"
di "Post-2014 positive coefficients: `n_pos_post'"
restore

********************************************************************************
* PART 6: Honest Assessment
********************************************************************************

di ""
di "======================================================================"
di "PART 6: HONEST ASSESSMENT OF IDENTIFICATION"
di "======================================================================"

di _n "KEY FINDINGS:"
di "1. Pre-trend exists: Agricultural wages were declining relative to"
di "   other sectors before 2014 (approximately " %5.3f `pre_trend' " log points/year)"
di ""
di "2. This VIOLATES strict parallel trends assumption"
di ""
di "3. However, interpretation depends on counterfactual:"
di "   - If trend would have CONTINUED: Effect is LARGER than baseline"
di "     (embargo reversed a decline, not just maintained status quo)"
di "   - If trend would have STOPPED: Effect is correctly estimated"
di "   - If trend would have REVERSED: Effect is SMALLER than baseline"
di ""
di "4. Our estimates:"
di "   - Baseline (assumes parallel trends): " %6.3f `b1'
di "   - With group trends (conservative): " %6.3f `b2'
di "   - Trend-extrapolated (liberal): " %6.3f `b3'
di ""
di "5. RECOMMENDATION: Report range of estimates and be transparent"
di "   about identification limitations."

********************************************************************************
* PART 7: Summary Table
********************************************************************************

di ""
di "======================================================================"
di "SUMMARY TABLE: SPECIFICATION SENSITIVITY"
di "======================================================================"

di ""
di "Specification                    | Coefficient |    SE    | Interpretation"
di "---------------------------------|-------------|----------|---------------"
di "Baseline DiD                     |   " %7.4f `b1' "   | " %6.4f `se1' " | Assumes parallel trends"
di "Group-specific trends            |   " %7.4f `b2' "   | " %6.4f `se2' " | Controls for differential trend"
di "Pre-trend extrapolation          |   " %7.4f `b3' "   | " %6.4f `se3' " | Assumes trend continues"

log close
