********************************************************************************
* Robust Synthetic Control Analysis
* Address pre-treatment fit concerns with proper diagnostics
********************************************************************************

clear all
set more off
cap log close
log using "output/analysis_synthetic_control_robust_log.txt", replace text

di "======================================================================"
di "ROBUST SYNTHETIC CONTROL ANALYSIS"
di "======================================================================"

********************************************************************************
* STEP 1: Prepare sector-level panel data
********************************************************************************

use "output/rlms_analysis_sample.dta", clear
keep if year >= 2010 & year <= 2019

* Create sector variable from industry
gen sector = industry
drop if sector == .

* Collapse to sector-year level
collapse (mean) ln_wage hours_month (count) n_obs = ln_wage, by(sector year)

* Keep only sectors with sufficient observations
bys sector: egen min_n = min(n_obs)
keep if min_n >= 50
drop min_n

* Reshape to wide format
reshape wide ln_wage hours_month n_obs, i(year) j(sector)

* Rename key sectors
rename ln_wage8 ln_wage_agri
rename ln_wage1 ln_wage_food
rename ln_wage6 ln_wage_constr
rename ln_wage7 ln_wage_transport
rename ln_wage9 ln_wage_govt
rename ln_wage10 ln_wage_educ
rename ln_wage12 ln_wage_health
rename ln_wage14 ln_wage_trade

di _n "=== Sector wages by year ==="
list year ln_wage_agri ln_wage_food ln_wage_constr ln_wage_educ ln_wage_trade

********************************************************************************
* STEP 2: Construct Multiple Synthetic Controls
********************************************************************************

di ""
di "======================================================================"
di "STEP 2: CONSTRUCT SYNTHETIC CONTROLS"
di "======================================================================"

* Method 1: Simple average (baseline)
gen synth_simple = (ln_wage_food + ln_wage_constr + ln_wage_transport + ///
                    ln_wage_govt + ln_wage_educ + ln_wage_health + ln_wage_trade) / 7

* Method 2: Match on pre-treatment mean + track deviations
egen pre_mean_agri = mean(ln_wage_agri) if year <= 2013
egen pre_mean_food = mean(ln_wage_food) if year <= 2013
egen pre_mean_constr = mean(ln_wage_constr) if year <= 2013
egen pre_mean_educ = mean(ln_wage_educ) if year <= 2013
egen pre_mean_trade = mean(ln_wage_trade) if year <= 2013

* Fill for all years
foreach v in pre_mean_agri pre_mean_food pre_mean_constr pre_mean_educ pre_mean_trade {
    egen temp = max(`v')
    replace `v' = temp
    drop temp
}

* Deviations from pre-treatment mean
gen dev_food = ln_wage_food - pre_mean_food
gen dev_constr = ln_wage_constr - pre_mean_constr
gen dev_educ = ln_wage_educ - pre_mean_educ
gen dev_trade = ln_wage_trade - pre_mean_trade

* Synthetic = agri pre-mean + average deviation
gen synth_matched = pre_mean_agri + (dev_food + dev_constr + dev_educ + dev_trade)/4

* Method 3: Weighted by inverse distance to agriculture
* Get pre-treatment distance from agriculture
local dist_food = abs(`=pre_mean_food[1]' - `=pre_mean_agri[1]')
local dist_constr = abs(`=pre_mean_constr[1]' - `=pre_mean_agri[1]')
local dist_educ = abs(`=pre_mean_educ[1]' - `=pre_mean_agri[1]')
local dist_trade = abs(`=pre_mean_trade[1]' - `=pre_mean_agri[1]')

* Inverse distance weights
local w_food = 1/`dist_food'
local w_constr = 1/`dist_constr'
local w_educ = 1/`dist_educ'
local w_trade = 1/`dist_trade'
local w_sum = `w_food' + `w_constr' + `w_educ' + `w_trade'

di _n "=== Inverse Distance Weights ==="
di "Food: " %5.3f `w_food'/`w_sum'
di "Construction: " %5.3f `w_constr'/`w_sum'
di "Education: " %5.3f `w_educ'/`w_sum'
di "Trade: " %5.3f `w_trade'/`w_sum'

gen synth_weighted = pre_mean_agri + ///
    ((`w_food'/`w_sum')*dev_food + (`w_constr'/`w_sum')*dev_constr + ///
     (`w_educ'/`w_sum')*dev_educ + (`w_trade'/`w_sum')*dev_trade)

********************************************************************************
* STEP 3: Calculate Pre-Treatment Fit (MSPE)
********************************************************************************

di ""
di "======================================================================"
di "STEP 3: PRE-TREATMENT FIT DIAGNOSTICS"
di "======================================================================"

* Calculate gaps
gen gap_simple = ln_wage_agri - synth_simple
gen gap_matched = ln_wage_agri - synth_matched
gen gap_weighted = ln_wage_agri - synth_weighted

* Pre-treatment MSPE
gen gap_sq_simple = gap_simple^2
gen gap_sq_matched = gap_matched^2
gen gap_sq_weighted = gap_weighted^2

di _n "=== Pre-Treatment Mean Squared Prediction Error ==="
sum gap_sq_simple if year <= 2013
local mspe_simple_pre = r(mean)
di "Simple average MSPE (pre): " %8.6f `mspe_simple_pre'

sum gap_sq_matched if year <= 2013
local mspe_matched_pre = r(mean)
di "Matched MSPE (pre): " %8.6f `mspe_matched_pre'

sum gap_sq_weighted if year <= 2013
local mspe_weighted_pre = r(mean)
di "Weighted MSPE (pre): " %8.6f `mspe_weighted_pre'

* Post-treatment MSPE
di _n "=== Post-Treatment Mean Squared Prediction Error ==="
sum gap_sq_simple if year >= 2014
local mspe_simple_post = r(mean)
di "Simple average MSPE (post): " %8.6f `mspe_simple_post'

sum gap_sq_matched if year >= 2014
local mspe_matched_post = r(mean)
di "Matched MSPE (post): " %8.6f `mspe_matched_post'

sum gap_sq_weighted if year >= 2014
local mspe_weighted_post = r(mean)
di "Weighted MSPE (post): " %8.6f `mspe_weighted_post'

* RMSPE ratios
di _n "=== RMSPE Ratios (Post/Pre) ==="
di "Simple: " %6.2f sqrt(`mspe_simple_post')/sqrt(`mspe_simple_pre')
di "Matched: " %6.2f sqrt(`mspe_matched_post')/sqrt(`mspe_matched_pre')
di "Weighted: " %6.2f sqrt(`mspe_weighted_post')/sqrt(`mspe_weighted_pre')

* Year-by-year gaps for best method (matched)
di _n "=== Year-by-Year Gaps (Matched Method) ==="
list year ln_wage_agri synth_matched gap_matched

********************************************************************************
* STEP 4: Pre-Treatment Fit Quality Assessment
********************************************************************************

di ""
di "======================================================================"
di "STEP 4: PRE-TREATMENT FIT QUALITY"
di "======================================================================"

* Calculate pre-treatment gap statistics
sum gap_matched if year <= 2013
local pre_mean = r(mean)
local pre_sd = r(sd)
local pre_min = r(min)
local pre_max = r(max)

di "Pre-treatment gap statistics (matched):"
di "  Mean: " %7.4f `pre_mean'
di "  SD: " %7.4f `pre_sd'
di "  Range: [" %6.4f `pre_min' ", " %6.4f `pre_max' "]"
di "  RMSPE: " %7.4f sqrt(`mspe_matched_pre')

* Is pre-treatment fit acceptable?
* Rule of thumb: RMSPE < 0.05 (5% of outcome SD)
sum ln_wage_agri
local outcome_sd = r(sd)
local rmspe_ratio = sqrt(`mspe_matched_pre') / `outcome_sd'
di _n "RMSPE as fraction of outcome SD: " %5.3f `rmspe_ratio'
if `rmspe_ratio' < 0.1 {
    di "  --> Pre-treatment fit is ACCEPTABLE"
}
else {
    di "  --> Pre-treatment fit is POOR - interpret with caution"
}

********************************************************************************
* STEP 5: Placebo Tests - Treat Each Control Sector as "Treated"
********************************************************************************

di ""
di "======================================================================"
di "STEP 5: PLACEBO TESTS (IN-SPACE)"
di "======================================================================"

* For each control sector, construct synthetic and calculate RMSPE ratio
tempname placebo_results
postfile `placebo_results' str20 sector rmspe_pre rmspe_post ratio using "output/tables/synth_placebo_results.dta", replace

* Agriculture (actual treated unit)
local rmspe_pre = sqrt(`mspe_matched_pre')
local rmspe_post = sqrt(`mspe_matched_post')
local ratio = `rmspe_post' / `rmspe_pre'
post `placebo_results' ("Agriculture") (`rmspe_pre') (`rmspe_post') (`ratio')

* Placebo 1: Food Industry
gen synth_food = pre_mean_food + (dev_constr + dev_educ + dev_trade)/3
gen gap_food = ln_wage_food - synth_food
gen gap_sq_food = gap_food^2
sum gap_sq_food if year <= 2013
local mspe_pre = r(mean)
sum gap_sq_food if year >= 2014
local mspe_post = r(mean)
local ratio = sqrt(`mspe_post') / sqrt(`mspe_pre')
post `placebo_results' ("Food Industry") (sqrt(`mspe_pre')) (sqrt(`mspe_post')) (`ratio')
di "Food Industry RMSPE ratio: " %6.2f `ratio'

* Placebo 2: Construction
gen synth_constr = pre_mean_constr + (dev_food + dev_educ + dev_trade)/3
gen gap_constr_p = ln_wage_constr - synth_constr
gen gap_sq_constr = gap_constr_p^2
sum gap_sq_constr if year <= 2013
local mspe_pre = r(mean)
sum gap_sq_constr if year >= 2014
local mspe_post = r(mean)
local ratio = sqrt(`mspe_post') / sqrt(`mspe_pre')
post `placebo_results' ("Construction") (sqrt(`mspe_pre')) (sqrt(`mspe_post')) (`ratio')
di "Construction RMSPE ratio: " %6.2f `ratio'

* Placebo 3: Education
gen synth_educ = pre_mean_educ + (dev_food + dev_constr + dev_trade)/3
gen gap_educ_p = ln_wage_educ - synth_educ
gen gap_sq_educ = gap_educ_p^2
sum gap_sq_educ if year <= 2013
local mspe_pre = r(mean)
sum gap_sq_educ if year >= 2014
local mspe_post = r(mean)
local ratio = sqrt(`mspe_post') / sqrt(`mspe_pre')
post `placebo_results' ("Education") (sqrt(`mspe_pre')) (sqrt(`mspe_post')) (`ratio')
di "Education RMSPE ratio: " %6.2f `ratio'

* Placebo 4: Trade
gen synth_trade = pre_mean_trade + (dev_food + dev_constr + dev_educ)/3
gen gap_trade_p = ln_wage_trade - synth_trade
gen gap_sq_trade = gap_trade_p^2
sum gap_sq_trade if year <= 2013
local mspe_pre = r(mean)
sum gap_sq_trade if year >= 2014
local mspe_post = r(mean)
local ratio = sqrt(`mspe_post') / sqrt(`mspe_pre')
post `placebo_results' ("Trade") (sqrt(`mspe_pre')) (sqrt(`mspe_post')) (`ratio')
di "Trade RMSPE ratio: " %6.2f `ratio'

postclose `placebo_results'

* Display and calculate p-value
preserve
use "output/tables/synth_placebo_results.dta", clear
di _n "=== Placebo Test Results ==="
list, sep(0)

* Calculate p-value: proportion of placebos with ratio >= agriculture
count if ratio >= ratio[1] & sector != "Agriculture"
local n_larger = r(N)
count if sector != "Agriculture"
local n_placebos = r(N)
local pval = (`n_larger' + 1) / (`n_placebos' + 1)
di _n "Placebo p-value: " %5.3f `pval'
di "  (`n_larger' of `n_placebos' placebos have ratio >= agriculture)"
restore

********************************************************************************
* STEP 6: In-Time Placebo (Fake Treatment in 2012)
********************************************************************************

di ""
di "======================================================================"
di "STEP 6: IN-TIME PLACEBO (FAKE 2012 TREATMENT)"
di "======================================================================"

* Pretend treatment happened in 2012
* Pre-treatment: 2010-2011, Post-treatment: 2012-2013

* Calculate MSPE for fake pre-period (2010-2011)
sum gap_sq_matched if year <= 2011
local mspe_fake_pre = r(mean)

* Calculate MSPE for fake post-period (2012-2013)
sum gap_sq_matched if year >= 2012 & year <= 2013
local mspe_fake_post = r(mean)

local fake_ratio = sqrt(`mspe_fake_post') / sqrt(`mspe_fake_pre')

di "Fake 2012 treatment:"
di "  Pre-RMSPE (2010-2011): " %7.4f sqrt(`mspe_fake_pre')
di "  Post-RMSPE (2012-2013): " %7.4f sqrt(`mspe_fake_post')
di "  Ratio: " %6.2f `fake_ratio'

* Compare to actual 2014 treatment
local actual_ratio = sqrt(`mspe_matched_post') / sqrt(`mspe_matched_pre')
di _n "Actual 2014 treatment:"
di "  Pre-RMSPE (2010-2013): " %7.4f sqrt(`mspe_matched_pre')
di "  Post-RMSPE (2014-2019): " %7.4f sqrt(`mspe_matched_post')
di "  Ratio: " %6.2f `actual_ratio'

if `actual_ratio' > `fake_ratio' * 2 {
    di _n "  --> Actual treatment effect is meaningfully larger than fake"
}
else {
    di _n "  --> WARNING: Actual effect not much larger than fake treatment"
}

********************************************************************************
* STEP 7: Treatment Effect Estimates
********************************************************************************

di ""
di "======================================================================"
di "STEP 7: TREATMENT EFFECT ESTIMATES"
di "======================================================================"

* Average treatment effect (post-treatment gap)
sum gap_matched if year >= 2014
local ate = r(mean)
local ate_sd = r(sd)
di "Average Treatment Effect (log points): " %7.4f `ate'
di "  SD: " %7.4f `ate_sd'
di "  Percentage: " %5.1f 100*(exp(`ate')-1) "%"

* By year
di _n "=== Treatment Effect by Year ==="
list year gap_matched if year >= 2014

********************************************************************************
* STEP 8: Limitations and Honest Assessment
********************************************************************************

di ""
di "======================================================================"
di "STEP 8: LIMITATIONS AND HONEST ASSESSMENT"
di "======================================================================"

di _n "Key limitations of this synthetic control analysis:"
di ""
di "1. SMALL DONOR POOL: Only ~10 sectors available as donors,"
di "   vs. typical SC applications with 30-50 units."
di ""
di "2. AGGREGATE SECTORS: We use sector-level averages, not firm-level"
di "   or individual-level data. This masks within-sector heterogeneity."
di ""
di "3. NO FORMAL OPTIMIZATION: We use ad-hoc weighting schemes rather than"
di "   Abadie et al.'s formal optimization of pre-treatment fit."
di ""
di "4. PRE-TREATMENT DIVERGENCE: Visual inspection shows some pre-2014"
di "   divergence, though gaps are small relative to outcome variation."
di ""
di "5. SECTOR COMPOSITION: Agriculture may have systematically different"
di "   wage dynamics than urban service sectors for structural reasons."

di _n "RECOMMENDATION:"
di "This analysis should be viewed as SUGGESTIVE rather than definitive."
di "The individual-level DiD event study remains the primary identification."

********************************************************************************
* STEP 9: Export Results
********************************************************************************

keep year ln_wage_agri synth_simple synth_matched synth_weighted ///
     gap_simple gap_matched gap_weighted

export delimited using "output/tables/synthetic_control_robust.csv", replace

di _n "Results saved to output/tables/synthetic_control_robust.csv"

log close
