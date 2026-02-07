********************************************************************************
* Synthetic Control Analysis for Agriculture Sector
* Construct synthetic "agriculture" from weighted control sectors
* Test whether real agriculture diverges post-2014
********************************************************************************

clear all
set more off
cap log close
log using "output/analysis_synthetic_control_log.txt", replace text

di "======================================================================"
di "SYNTHETIC CONTROL ANALYSIS"
di "======================================================================"

********************************************************************************
* STEP 1: Prepare sector-level panel data
********************************************************************************

use "output/rlms_analysis_sample.dta", clear
keep if year >= 2010 & year <= 2019

* Check what industry variable is available
describe industry agri

* Create sector variable from industry
gen sector = industry
label define sector_lbl 1 "Food Industry" 2 "Machine Constr" 3 "Military" ///
    4 "Oil/Gas" 5 "Heavy Industry" 6 "Construction" 7 "Transport" ///
    8 "Agriculture" 9 "Government" 10 "Education" 11 "Science" ///
    12 "Health" 13 "Army/Police" 14 "Trade/Services" 15 "Finance" 16 "Other"
label values sector sector_lbl

* Drop missing sectors
drop if sector == .

* Collapse to sector-year level
collapse (mean) ln_wage hours_month age female ///
         (count) n_obs = ln_wage, by(sector year)

di _n "=== Sector-Year Panel ==="
list sector year ln_wage n_obs if year == 2013

* Reshape to wide format for synthetic control
reshape wide ln_wage hours_month age female n_obs, i(year) j(sector)

* Rename for clarity (industry codes: 8=agri, 1=food, 6=constr, 7=transport, 9=govt, 10=educ, 12=health, 14=trade)
rename ln_wage8 ln_wage_agri
rename ln_wage1 ln_wage_food
rename ln_wage6 ln_wage_constr
rename ln_wage7 ln_wage_transport
rename ln_wage9 ln_wage_govt
rename ln_wage10 ln_wage_educ
rename ln_wage12 ln_wage_health
rename ln_wage14 ln_wage_trade

* Also rename other sectors if they exist (might not all exist)
cap rename ln_wage2 ln_wage_machine
cap rename ln_wage5 ln_wage_heavy

di _n "=== Pre-Treatment Wages (2013) ==="
list year ln_wage_agri ln_wage_food ln_wage_constr ln_wage_govt ln_wage_trade if year == 2013

********************************************************************************
* STEP 2: Construct Synthetic Control Weights
* Match on pre-2014 wage levels
********************************************************************************

di ""
di "======================================================================"
di "STEP 2: CONSTRUCT SYNTHETIC CONTROL WEIGHTS"
di "======================================================================"

* Calculate pre-treatment means (2010-2013)
preserve
keep if year <= 2013

collapse (mean) ln_wage_agri ln_wage_food ln_wage_machine ln_wage_heavy ///
                ln_wage_constr ln_wage_transport ln_wage_govt ln_wage_educ ///
                ln_wage_health ln_wage_trade

* Agriculture pre-treatment mean
local agri_pre = ln_wage_agri[1]
di "Agriculture pre-treatment mean: " `agri_pre'

* Calculate distance from agriculture for each sector
gen dist_food = abs(ln_wage_food - ln_wage_agri)
gen dist_machine = abs(ln_wage_machine - ln_wage_agri)
gen dist_heavy = abs(ln_wage_heavy - ln_wage_agri)
gen dist_constr = abs(ln_wage_constr - ln_wage_agri)
gen dist_transport = abs(ln_wage_transport - ln_wage_agri)
gen dist_govt = abs(ln_wage_govt - ln_wage_agri)
gen dist_educ = abs(ln_wage_educ - ln_wage_agri)
gen dist_health = abs(ln_wage_health - ln_wage_agri)
gen dist_trade = abs(ln_wage_trade - ln_wage_agri)

di _n "=== Distance from Agriculture (pre-treatment) ==="
list dist_food dist_constr dist_govt dist_educ dist_trade

* Pre-treatment sector means
local pre_food = ln_wage_food[1]
local pre_machine = ln_wage_machine[1]
local pre_heavy = ln_wage_heavy[1]
local pre_constr = ln_wage_constr[1]
local pre_transport = ln_wage_transport[1]
local pre_govt = ln_wage_govt[1]
local pre_educ = ln_wage_educ[1]
local pre_health = ln_wage_health[1]
local pre_trade = ln_wage_trade[1]
restore

********************************************************************************
* STEP 3: Simple Synthetic Control (weighted average)
* Use inverse-distance weighting based on pre-treatment wage levels
********************************************************************************

di ""
di "======================================================================"
di "STEP 3: CONSTRUCT SYNTHETIC AGRICULTURE"
di "======================================================================"

* Method 1: Simple average of all control sectors
gen synth_simple = (ln_wage_food + ln_wage_constr + ln_wage_transport + ///
                    ln_wage_govt + ln_wage_educ + ln_wage_health + ln_wage_trade) / 7

* Method 2: Weighted by similarity to agriculture
* Use sectors closest to agriculture in pre-treatment wages
* Agriculture is low-wage, so give more weight to other low-wage sectors

* Calculate pre-treatment adjustment factor
gen pre_period = (year <= 2013)

* Method 3: Match exactly on pre-2013 mean, then track
* Synthetic = agriculture mean + (weighted control deviation from their mean)
egen synth_mean_food = mean(ln_wage_food) if year <= 2013
egen synth_mean_constr = mean(ln_wage_constr) if year <= 2013
egen synth_mean_govt = mean(ln_wage_govt) if year <= 2013
egen synth_mean_educ = mean(ln_wage_educ) if year <= 2013
egen synth_mean_trade = mean(ln_wage_trade) if year <= 2013
egen agri_mean = mean(ln_wage_agri) if year <= 2013

* Fill in means for all years
foreach v in synth_mean_food synth_mean_constr synth_mean_govt synth_mean_educ synth_mean_trade agri_mean {
    egen temp = max(`v')
    replace `v' = temp
    drop temp
}

* Create de-meaned control sectors (deviation from pre-treatment mean)
gen dev_food = ln_wage_food - synth_mean_food
gen dev_constr = ln_wage_constr - synth_mean_constr
gen dev_govt = ln_wage_govt - synth_mean_govt
gen dev_educ = ln_wage_educ - synth_mean_educ
gen dev_trade = ln_wage_trade - synth_mean_trade

* Synthetic control: agriculture pre-mean + weighted average of control deviations
* Weight by 1/distance to agriculture
gen synth_matched = agri_mean + (dev_food + dev_constr + dev_trade)/3

* Also try: just shift control sectors to match agriculture level
gen synth_shifted = synth_simple - (synth_mean_food + synth_mean_constr + ///
    synth_mean_govt + synth_mean_educ + synth_mean_trade)/5 + agri_mean

di _n "=== Comparison: Agriculture vs Synthetic ==="
list year ln_wage_agri synth_simple synth_matched synth_shifted

********************************************************************************
* STEP 4: Calculate Treatment Effect (Gap)
********************************************************************************

di ""
di "======================================================================"
di "STEP 4: TREATMENT EFFECT (AGRICULTURE - SYNTHETIC)"
di "======================================================================"

gen gap_simple = ln_wage_agri - synth_simple
gen gap_matched = ln_wage_agri - synth_matched
gen gap_shifted = ln_wage_agri - synth_shifted

di _n "=== Gap: Agriculture minus Synthetic Control ==="
list year ln_wage_agri synth_matched gap_matched

* Pre-treatment gap (should be ~0 if good match)
sum gap_matched if year <= 2013
local pre_gap = r(mean)
di "Pre-treatment gap (matched): " `pre_gap'

* Post-treatment gap
sum gap_matched if year >= 2014
local post_gap = r(mean)
di "Post-treatment gap (matched): " `post_gap'

di _n "=== TREATMENT EFFECT ==="
di "Post-pre difference: " `post_gap' - `pre_gap'

* By year
di _n "=== Gap by Year ==="
list year gap_matched if year >= 2010

********************************************************************************
* STEP 5: Placebo Tests (treat each control sector as if treated)
********************************************************************************

di ""
di "======================================================================"
di "STEP 5: PLACEBO TESTS"
di "======================================================================"

* For each control sector, compute gap relative to other controls
* If agriculture effect is real, placebo gaps should be smaller

* Placebo: Food Industry
gen synth_ex_food = (ln_wage_constr + ln_wage_transport + ln_wage_govt + ///
                     ln_wage_educ + ln_wage_health + ln_wage_trade) / 6
gen gap_food = ln_wage_food - synth_ex_food

* Placebo: Construction
gen synth_ex_constr = (ln_wage_food + ln_wage_transport + ln_wage_govt + ///
                       ln_wage_educ + ln_wage_health + ln_wage_trade) / 6
gen gap_constr = ln_wage_constr - synth_ex_constr

* Placebo: Government
gen synth_ex_govt = (ln_wage_food + ln_wage_constr + ln_wage_transport + ///
                     ln_wage_educ + ln_wage_health + ln_wage_trade) / 6
gen gap_govt = ln_wage_govt - synth_ex_govt

* Placebo: Education
gen synth_ex_educ = (ln_wage_food + ln_wage_constr + ln_wage_transport + ///
                     ln_wage_govt + ln_wage_health + ln_wage_trade) / 6
gen gap_educ = ln_wage_educ - synth_ex_educ

* Placebo: Trade
gen synth_ex_trade = (ln_wage_food + ln_wage_constr + ln_wage_transport + ///
                      ln_wage_govt + ln_wage_educ + ln_wage_health) / 6
gen gap_trade = ln_wage_trade - synth_ex_trade

di _n "=== Placebo Gaps (Post-2014 Average) ==="
foreach sector in food constr govt educ trade {
    sum gap_`sector' if year >= 2014
    di "Gap `sector': " r(mean)
}

* Agriculture gap for comparison
sum gap_simple if year >= 2014
di "Gap agriculture (simple): " r(mean)

********************************************************************************
* STEP 6: Post/Pre Ratio Test
********************************************************************************

di ""
di "======================================================================"
di "STEP 6: POST/PRE RATIO TEST"
di "======================================================================"

* Calculate RMSPE (root mean squared prediction error) ratio
* Good synthetic control: small pre-treatment RMSPE

* Pre-treatment RMSPE
gen gap_sq = gap_matched^2
sum gap_sq if year <= 2013
local pre_rmspe = sqrt(r(mean))
di "Pre-treatment RMSPE: " `pre_rmspe'

* Post-treatment RMSPE
sum gap_sq if year >= 2014
local post_rmspe = sqrt(r(mean))
di "Post-treatment RMSPE: " `post_rmspe'

di "Post/Pre RMSPE ratio: " `post_rmspe'/`pre_rmspe'

********************************************************************************
* STEP 7: Export results for plotting
********************************************************************************

keep year ln_wage_agri synth_matched synth_simple gap_matched gap_simple ///
     gap_food gap_constr gap_govt gap_educ gap_trade

export delimited using "output/tables/synthetic_control_results.csv", replace

di _n "=== Results saved to output/tables/synthetic_control_results.csv ==="

********************************************************************************
* STEP 8: Summary Statistics
********************************************************************************

di ""
di "======================================================================"
di "SUMMARY: SYNTHETIC CONTROL RESULTS"
di "======================================================================"

di _n "Pre-treatment (2010-2013):"
sum gap_matched if year <= 2013
di "  Mean gap: " r(mean)
di "  SD gap: " r(sd)

di _n "Post-treatment (2014-2019):"
sum gap_matched if year >= 2014
di "  Mean gap: " r(mean)
di "  SD gap: " r(sd)

di _n "Year-by-year gaps:"
list year ln_wage_agri synth_matched gap_matched

di ""
di "Analysis complete!"
log close
