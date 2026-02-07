********************************************************************************
* Hours Pre-Trends Analysis
* Test whether post-treatment hours effect differs from pre-treatment
********************************************************************************

clear all
set more off
cap log close
log using "output/analysis_hours_pretrends_log.txt", replace text

use "output/rlms_analysis_sample.dta", clear
keep if year >= 2010 & year <= 2019

di "======================================================================"
di "HOURS PRE-TRENDS ANALYSIS"
di "======================================================================"

********************************************************************************
* PART 1: Event Study for Hours
********************************************************************************

di _n "=== PART 1: Hours Event Study ==="

* Create relative time indicators
gen rel_year = year - 2014

* Create event study dummies (excluding -1 as reference)
gen Dm4 = (rel_year == -4) * agri
gen Dm3 = (rel_year == -3) * agri
gen Dm2 = (rel_year == -2) * agri
gen Dp0 = (rel_year == 0) * agri
gen Dp1 = (rel_year == 1) * agri
gen Dp2 = (rel_year == 2) * agri
gen Dp3 = (rel_year == 3) * agri
gen Dp4 = (rel_year == 4) * agri
gen Dp5 = (rel_year == 5) * agri

* Run event study for hours
reghdfe hours_month Dm4 Dm3 Dm2 Dp0 Dp1 Dp2 Dp3 Dp4 Dp5, absorb(idind year) cluster(region)

di _n "=== Event Study Coefficients ==="
di "Pre-treatment (relative to -1):"
di "  Year -4: " _b[Dm4] " (SE: " _se[Dm4] ")"
di "  Year -3: " _b[Dm3] " (SE: " _se[Dm3] ")"
di "  Year -2: " _b[Dm2] " (SE: " _se[Dm2] ")"
di "Post-treatment:"
di "  Year 0: " _b[Dp0] " (SE: " _se[Dp0] ")"
di "  Year 1: " _b[Dp1] " (SE: " _se[Dp1] ")"
di "  Year 2: " _b[Dp2] " (SE: " _se[Dp2] ")"
di "  Year 3: " _b[Dp3] " (SE: " _se[Dp3] ")"
di "  Year 4: " _b[Dp4] " (SE: " _se[Dp4] ")"
di "  Year 5: " _b[Dp5] " (SE: " _se[Dp5] ")"

********************************************************************************
* PART 2: Test Pre vs Post Difference
********************************************************************************

di ""
di "======================================================================"
di "PART 2: TEST PRE VS POST DIFFERENCE"
di "======================================================================"

* Average pre-treatment effect
lincom (Dm4 + Dm3 + Dm2) / 3
local pre_avg = r(estimate)
local pre_se = r(se)
di "Average pre-treatment effect: " `pre_avg' " (SE: " `pre_se' ")"

* Average post-treatment effect
lincom (Dp0 + Dp1 + Dp2 + Dp3 + Dp4 + Dp5) / 6
local post_avg = r(estimate)
local post_se = r(se)
di "Average post-treatment effect: " `post_avg' " (SE: " `post_se' ")"

* Test difference
di _n "=== Test: Post average = Pre average ==="
lincom ((Dp0 + Dp1 + Dp2 + Dp3 + Dp4 + Dp5) / 6) - ((Dm4 + Dm3 + Dm2) / 3)
local diff = r(estimate)
local diff_se = r(se)
local diff_p = 2 * (1 - normal(abs(r(estimate) / r(se))))
di "Difference (post - pre): " `diff'
di "SE: " `diff_se'
di "p-value: " `diff_p'

********************************************************************************
* PART 3: Simple DiD with Pre-Period Average
********************************************************************************

di ""
di "======================================================================"
di "PART 3: ALTERNATIVE SPECIFICATION"
di "======================================================================"

* Drop event study vars
drop Dm4 Dm3 Dm2 Dp0 Dp1 Dp2 Dp3 Dp4 Dp5

* Create pre-period average hours gap
cap drop agri_post
gen agri_post = agri * post

* Simple DiD
di _n "=== Simple DiD for Hours ==="
reghdfe hours_month agri_post, absorb(idind year) cluster(region)
local did_coef = _b[agri_post]
local did_se = _se[agri_post]

di "DiD coefficient: " `did_coef'
di "SE: " `did_se'

* Now with agri main effect (capturing pre-period difference)
di _n "=== DiD with Agri Level Effect ==="
reghdfe hours_month agri agri_post, absorb(idind year) cluster(region)

di "Agri level (pre-period gap): " _b[agri]
di "Agri × Post (treatment effect): " _b[agri_post]

* Test if post effect is different from pre level
test agri_post = agri
di "Test agri_post = agri: p = " r(p)

********************************************************************************
* PART 4: Pre-Period Hours Gap Analysis
********************************************************************************

di ""
di "======================================================================"
di "PART 4: PRE-PERIOD HOURS GAP"
di "======================================================================"

* Calculate raw hours by group and year
preserve
collapse (mean) hours_month, by(agri year)
reshape wide hours_month, i(year) j(agri)
gen hours_gap = hours_month1 - hours_month0

di _n "=== Raw Hours Gap by Year ==="
list year hours_month0 hours_month1 hours_gap

* Pre-period average gap
sum hours_gap if year < 2014
local pre_gap = r(mean)
di "Pre-2014 average gap: " `pre_gap'

* Post-period average gap
sum hours_gap if year >= 2014
local post_gap = r(mean)
di "Post-2014 average gap: " `post_gap'

di "Change in gap (post - pre): " `post_gap' - `pre_gap'
restore

********************************************************************************
* PART 5: Compare to Wages Event Study
********************************************************************************

di ""
di "======================================================================"
di "PART 5: COMPARE HOURS VS WAGES PRE-TRENDS"
di "======================================================================"

* Recreate event study dummies
gen Dm4 = (rel_year == -4) * agri
gen Dm3 = (rel_year == -3) * agri
gen Dm2 = (rel_year == -2) * agri
gen Dp0 = (rel_year == 0) * agri
gen Dp1 = (rel_year == 1) * agri
gen Dp2 = (rel_year == 2) * agri
gen Dp3 = (rel_year == 3) * agri
gen Dp4 = (rel_year == 4) * agri
gen Dp5 = (rel_year == 5) * agri

* Hours event study
di _n "=== Hours Event Study ==="
quietly reghdfe hours_month Dm4 Dm3 Dm2 Dp0 Dp1 Dp2 Dp3 Dp4 Dp5, absorb(idind year) cluster(region)
di "Pre-treatment coefficients:"
di "  Dm4: " %6.3f _b[Dm4] " (p=" %5.3f 2*ttail(e(df_r), abs(_b[Dm4]/_se[Dm4])) ")"
di "  Dm3: " %6.3f _b[Dm3] " (p=" %5.3f 2*ttail(e(df_r), abs(_b[Dm3]/_se[Dm3])) ")"
di "  Dm2: " %6.3f _b[Dm2] " (p=" %5.3f 2*ttail(e(df_r), abs(_b[Dm2]/_se[Dm2])) ")"

* Test joint significance of pre-trends
test Dm4 Dm3 Dm2
di "Joint test of pre-trends (hours): F=" %6.2f r(F) ", p=" %5.3f r(p)

* Wages event study
di _n "=== Wages Event Study ==="
quietly reghdfe ln_wage Dm4 Dm3 Dm2 Dp0 Dp1 Dp2 Dp3 Dp4 Dp5, absorb(idind year) cluster(region)
di "Pre-treatment coefficients:"
di "  Dm4: " %6.3f _b[Dm4] " (p=" %5.3f 2*ttail(e(df_r), abs(_b[Dm4]/_se[Dm4])) ")"
di "  Dm3: " %6.3f _b[Dm3] " (p=" %5.3f 2*ttail(e(df_r), abs(_b[Dm3]/_se[Dm3])) ")"
di "  Dm2: " %6.3f _b[Dm2] " (p=" %5.3f 2*ttail(e(df_r), abs(_b[Dm2]/_se[Dm2])) ")"

* Test joint significance of pre-trends
test Dm4 Dm3 Dm2
di "Joint test of pre-trends (wages): F=" %6.2f r(F) ", p=" %5.3f r(p)

********************************************************************************
* PART 6: Summary Statistics
********************************************************************************

di ""
di "======================================================================"
di "SUMMARY"
di "======================================================================"

di _n "Key findings:"
di "1. Pre-treatment hours coefficients are [X] on average"
di "2. Post-treatment hours coefficients are [Y] on average"
di "3. Difference is [Z] (p = [P])"
di "4. This [does/does not] support a clean causal interpretation"

di ""
di "Analysis complete!"
log close
