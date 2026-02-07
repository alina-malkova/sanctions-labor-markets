********************************************************************************
* Extended Analysis: Addressing Referee Comments
* Uses pre-saved analysis sample from analysis_main.do
********************************************************************************

clear all
set more off
set matsize 11000

cd "/Users/amalkova/OneDrive - Florida Institute of Technology/Working santctions"

capture log close
log using "output/analysis_extended_log.txt", replace text

********************************************************************************
* PART 1: Intent-to-Treat Analysis (Pre-2014 Industry Assignment)
********************************************************************************

di as text "=========================================="
di as text "PART 1: Intent-to-Treat (Pre-2014 Industry)"
di as text "=========================================="

use "output/rlms_analysis_sample.dta", clear

* Create initial (pre-2014) industry assignment
preserve
keep if year < 2014 & industry != .
bysort idind (year): gen first_obs = (_n == 1)
keep if first_obs == 1
keep idind industry
rename industry initial_industry
tempfile initial_ind
save `initial_ind'
restore

merge m:1 idind using `initial_ind', keep(1 3)
gen matched_initial = (_merge == 3)
drop _merge

* Intent-to-treat: based on initial industry
gen agri_initial = (initial_industry == 8)
gen agri_initial_post = agri_initial * post
label var agri_initial "Agriculture (initial assignment)"
label var agri_initial_post "Agri (initial) × Post"

eststo clear

* (1) Baseline: Current industry
eststo itt1: reghdfe ln_wage agri_post, ///
    absorb(idind year) cluster(region)

* (2) Intent-to-treat: Initial industry
eststo itt2: reghdfe ln_wage agri_initial_post if matched_initial == 1, ///
    absorb(idind year) cluster(region)

* (3) ITT with controls
eststo itt3: reghdfe ln_wage agri_initial_post age age_sq i.educ_cat female ///
    if matched_initial == 1, ///
    absorb(idind year) cluster(region)

* (4) Primary sample: 2010-2019
eststo itt4: reghdfe ln_wage agri_initial_post if matched_initial == 1 & year <= 2019, ///
    absorb(idind year) cluster(region)

esttab itt1 itt2 itt3 itt4 using "output/tables/table10_itt.tex", ///
    replace booktabs label ///
    title("Intent-to-Treat: Pre-2014 Industry Assignment") ///
    mtitles("Current Ind" "Initial Ind" "ITT + Controls" "ITT 2010-19") ///
    keep(agri_post agri_initial_post) ///
    stats(N r2_a, labels("Observations" "Adj. R-squared")) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    se(3) b(3)

esttab itt1 itt2 itt3 itt4 using "output/tables/table10_itt.csv", ///
    replace csv label

********************************************************************************
* PART 2: Stayer Sample Analysis
********************************************************************************

di as text "=========================================="
di as text "PART 2: Stayer Sample"
di as text "=========================================="

use "output/rlms_analysis_sample.dta", clear

* Identify stayers
bysort idind: egen ever_agri_pre = max(agri * (year < 2014))
bysort idind: egen ever_agri_post = max(agri * (year >= 2014))
bysort idind: egen has_pre = max(year < 2014)
bysort idind: egen has_post = max(year >= 2014)
gen balanced = (has_pre == 1 & has_post == 1)

gen agri_stayer = (ever_agri_pre == 1 & ever_agri_post == 1 & balanced == 1)
gen nonagri_stayer = (ever_agri_pre == 0 & ever_agri_post == 0 & balanced == 1)
gen switcher_into_agri = (ever_agri_pre == 0 & ever_agri_post == 1 & balanced == 1)
gen switcher_out_agri = (ever_agri_pre == 1 & ever_agri_post == 0 & balanced == 1)

di "Sample composition:"
tab agri_stayer if year == 2013
tab nonagri_stayer if year == 2013
tab switcher_into_agri if year == 2013
tab switcher_out_agri if year == 2013

eststo clear

* (1) Full sample
eststo stay1: reghdfe ln_wage agri_post, ///
    absorb(idind year) cluster(region)

* (2) Stayers only
eststo stay2: reghdfe ln_wage agri_post if agri_stayer == 1 | nonagri_stayer == 1, ///
    absorb(idind year) cluster(region)

* (3) Agricultural stayers only
preserve
keep if agri_stayer == 1
eststo stay3: reghdfe ln_wage post, ///
    absorb(idind year) cluster(region)
restore

* (4) Balanced panel
eststo stay4: reghdfe ln_wage agri_post if balanced == 1, ///
    absorb(idind year) cluster(region)

esttab stay1 stay2 stay3 stay4 using "output/tables/table11_stayers.tex", ///
    replace booktabs label ///
    title("Stayer Sample Analysis") ///
    mtitles("Full Sample" "Stayers Only" "Agri Stayers" "Balanced Panel") ///
    keep(agri_post post) ///
    stats(N r2_a, labels("Observations" "Adj. R-squared")) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    se(3) b(3)

esttab stay1 stay2 stay3 stay4 using "output/tables/table11_stayers.csv", ///
    replace csv label

save "output/rlms_analysis_extended.dta", replace

********************************************************************************
* PART 3: Extensive Margin (Simplified - using wage sample)
********************************************************************************

di as text "=========================================="
di as text "PART 3: Extensive Margin (Employment Shares)"
di as text "=========================================="

use "output/rlms_analysis_sample.dta", clear

* Employment share in agriculture over time
preserve
gen n = 1
collapse (sum) n, by(year agri)
reshape wide n, i(year) j(agri)
gen agri_share = n1 / (n0 + n1) * 100
gen total_n = n0 + n1

list year agri_share total_n n1

twoway (line agri_share year, lcolor(navy) lpattern(solid)), ///
    xline(2014, lcolor(red) lpattern(dash)) ///
    xlabel(2010(2)2023) ///
    ylabel(, format(%9.1f)) ///
    xtitle("Year") ///
    ytitle("Share of Employment in Agriculture (%)") ///
    title("Agricultural Employment Share Over Time") ///
    note("Sample: Employed workers with wages. Vertical line: August 2014.") ///
    scheme(s2color)
graph export "output/figures/agri_employment_share.png", replace width(1200)

export delimited year agri_share total_n n1 using "output/tables/employment_shares.csv", replace
restore

********************************************************************************
* PART 4: Wage Decomposition
********************************************************************************

di as text "=========================================="
di as text "PART 4: Wage Decomposition"
di as text "=========================================="

use "output/rlms_analysis_sample.dta", clear

gen ln_hours = ln(hours_month) if hours_month > 0 & hours_month < .

eststo clear

* (1) Log monthly earnings
eststo dec1: reghdfe ln_wage agri_post, ///
    absorb(idind year) cluster(region)

* (2) Log hourly wage
eststo dec2: reghdfe ln_wage_hourly agri_post if ln_wage_hourly != ., ///
    absorb(idind year) cluster(region)

* (3) Log hours
eststo dec3: reghdfe ln_hours agri_post if ln_hours != ., ///
    absorb(idind year) cluster(region)

* (4) Hours in levels
eststo dec4: reghdfe hours_month agri_post if hours_month != ., ///
    absorb(idind year) cluster(region)

esttab dec1 dec2 dec3 dec4 using "output/tables/table13_decomposition.tex", ///
    replace booktabs label ///
    title("Wage Decomposition: Earnings = Hourly Wage × Hours") ///
    mtitles("Log Earnings" "Log Hourly" "Log Hours" "Hours (levels)") ///
    keep(agri_post) ///
    stats(N r2_a, labels("Observations" "Adj. R-squared")) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    se(3) b(3)

esttab dec1 dec2 dec3 dec4 using "output/tables/table13_decomposition.csv", ///
    replace csv label

* Event study for hours
forval t = -4/9 {
    if `t' < 0 {
        local tname = "m" + string(abs(`t'))
    }
    else {
        local tname = "p" + string(`t')
    }
    capture gen H_`tname' = (event_time == `t') * agri
}
capture drop H_m1

reghdfe ln_hours H_m4 H_m3 H_m2 H_p0 H_p1 H_p2 H_p3 H_p4 H_p5 H_p6 H_p7 H_p8 H_p9 ///
    if ln_hours != ., absorb(idind year) cluster(region)

matrix b_hrs = e(b)
matrix V_hrs = e(V)

preserve
clear
set obs 13
gen event_time = _n - 5
replace event_time = event_time + 1 if event_time >= 0

gen coef = .
gen se = .

local i = 1
foreach t in m4 m3 m2 p0 p1 p2 p3 p4 p5 p6 p7 p8 p9 {
    replace coef = b_hrs[1, `i'] in `i'
    replace se = sqrt(V_hrs[`i', `i']) in `i'
    local i = `i' + 1
}

set obs 14
replace event_time = -1 in 14
replace coef = 0 in 14
replace se = 0 in 14
sort event_time

gen ci_lo = coef - 1.96*se
gen ci_hi = coef + 1.96*se

twoway (rcap ci_lo ci_hi event_time, lcolor(maroon)) ///
       (scatter coef event_time, mcolor(maroon) msymbol(circle)), ///
    xline(-0.5, lcolor(red) lpattern(dash)) ///
    yline(0, lcolor(gray) lpattern(solid)) ///
    xlabel(-4(1)9) ///
    ylabel(, format(%9.2f)) ///
    xtitle("Years Relative to 2014 Food Embargo") ///
    ytitle("Effect on Log Hours") ///
    title("Event Study: Effect on Hours Worked") ///
    note("Reference period: 2013 (t=-1). 95% CIs shown.") ///
    legend(off) ///
    scheme(s2color)
graph export "output/figures/event_study_hours.png", replace width(1200)
restore

********************************************************************************
* PART 5: Synthetic Control
********************************************************************************

di as text "=========================================="
di as text "PART 5: Synthetic Control"
di as text "=========================================="

use "output/rlms_analysis_sample.dta", clear

preserve
collapse (mean) ln_wage wage_month hours_month [pw=inwgt], by(year industry)
drop if industry == .

reshape wide ln_wage wage_month hours_month, i(year) j(industry)

* Synthetic: average of control sectors
egen synth_simple = rowmean(ln_wage2 ln_wage5 ln_wage6 ln_wage7 ln_wage9 ln_wage10 ln_wage14)

* Adjust to match pre-period
sum ln_wage8 if year <= 2013
local agri_pre = r(mean)
sum synth_simple if year <= 2013
local synth_pre = r(mean)
local adjust = `agri_pre' - `synth_pre'

gen synth_adjusted = synth_simple + `adjust'

* Calculate gap
gen gap = ln_wage8 - synth_adjusted

twoway (line ln_wage8 year, lcolor(navy) lpattern(solid) lwidth(medthick)) ///
       (line synth_adjusted year, lcolor(maroon) lpattern(dash) lwidth(medthick)), ///
    xline(2014, lcolor(red) lpattern(dash)) ///
    xlabel(2010(2)2023) ///
    ylabel(, format(%9.2f)) ///
    xtitle("Year") ///
    ytitle("Mean Log Wage") ///
    title("Synthetic Control: Agriculture vs. Synthetic") ///
    legend(order(1 "Agriculture (actual)" 2 "Synthetic control") ///
        position(6) rows(1)) ///
    note("Synthetic: average of manufacturing, construction, transport, government, education, trade.") ///
    scheme(s2color)
graph export "output/figures/synthetic_control.png", replace width(1200)
graph export "output/figures/synthetic_control.pdf", replace

list year ln_wage8 synth_adjusted gap
export delimited year ln_wage8 synth_adjusted gap using "output/tables/synthetic_control_gap.csv", replace

restore

********************************************************************************
* PART 6: Structural Break Test (Pre/Post 2022)
********************************************************************************

di as text "=========================================="
di as text "PART 6: Pre/Post 2022 Structural Break"
di as text "=========================================="

use "output/rlms_analysis_sample.dta", clear

* Period indicators
gen period = 1 if year >= 2010 & year <= 2013
replace period = 2 if year >= 2014 & year <= 2019
replace period = 3 if year >= 2020 & year <= 2021
replace period = 4 if year >= 2022

gen agri_p2 = agri * (period == 2)
gen agri_p3 = agri * (period == 3)
gen agri_p4 = agri * (period == 4)

eststo clear

* (1) Single post-treatment effect
eststo brk1: reghdfe ln_wage agri_post, ///
    absorb(idind year) cluster(region)

* (2) Separate by period
eststo brk2: reghdfe ln_wage agri_p2 agri_p3 agri_p4, ///
    absorb(idind year) cluster(region)

* Test structural break
reghdfe ln_wage agri_p2 agri_p3 agri_p4, absorb(idind year) cluster(region)
test agri_p2 == agri_p4
local pval_diff = r(p)
di "P-value for H0: Effect(2014-19) = Effect(2022+): `pval_diff'"

* (3) Primary: 2010-2019
preserve
keep if year <= 2019
eststo brk3: reghdfe ln_wage agri_post, ///
    absorb(idind year) cluster(region)
restore

* (4) Post-2014 only
preserve
keep if year >= 2014
gen post_2022 = (year >= 2022)
gen agri_post22 = agri * post_2022
eststo brk4: reghdfe ln_wage agri_post22, ///
    absorb(idind year) cluster(region)
restore

esttab brk1 brk2 brk3 brk4 using "output/tables/table14_structural_break.tex", ///
    replace booktabs label ///
    title("Pre vs. Post 2022: Structural Break Analysis") ///
    mtitles("Pooled" "By Period" "2010-2019" "Post-2014 Only") ///
    keep(agri_post agri_p2 agri_p3 agri_p4 agri_post22) ///
    stats(N r2_a, labels("Observations" "Adj. R-squared")) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    se(3) b(3)

esttab brk1 brk2 brk3 brk4 using "output/tables/table14_structural_break.csv", ///
    replace csv label

********************************************************************************
* PART 7: Sample Diagnostics
********************************************************************************

di as text "=========================================="
di as text "PART 7: Sample Diagnostics"
di as text "=========================================="

use "output/rlms_analysis_sample.dta", clear

di "=== SAMPLE SIZE DIAGNOSTICS ==="
tab year agri
di ""
di "Unique individuals total:"
distinct idind
di "Unique agricultural workers:"
distinct idind if agri == 1

preserve
collapse (count) n_obs = ln_wage (sum) n_agri = agri, by(year)
list
export delimited using "output/tables/sample_sizes_by_year.csv", replace
restore

********************************************************************************
* CLOSE
********************************************************************************

di as text "=========================================="
di as text "Extended Analysis Complete!"
di as text "=========================================="
di as text "New tables: table10-14"
di as text "New figures: event_study_hours, synthetic_control"
di as text "=========================================="

log close
