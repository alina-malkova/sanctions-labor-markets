********************************************************************************
* Industry Switching as Outcome
* Models transitions into/out of agriculture post-embargo
********************************************************************************

clear all
set more off
set matsize 11000

cd "/Users/amalkova/OneDrive - Florida Institute of Technology/Working santctions"

capture log close
log using "output/analysis_switching_log.txt", replace text

********************************************************************************
* PART 1: Prepare Panel for Transition Analysis
********************************************************************************

di as text "=========================================="
di as text "PART 1: Prepare Transition Panel"
di as text "=========================================="

use "output/rlms_analysis_sample.dta", clear

* Sort by individual and year
sort idind year

* Create lagged industry
by idind: gen industry_lag = industry[_n-1]
by idind: gen agri_lag = agri[_n-1]
by idind: gen year_lag = year[_n-1]

* Only keep observations where we have prior year
keep if industry_lag != . & agri_lag != .

* Transition indicators
gen switch_into_agri = (agri == 1 & agri_lag == 0)
gen switch_out_agri = (agri == 0 & agri_lag == 1)
gen stay_in_agri = (agri == 1 & agri_lag == 1)
gen stay_out_agri = (agri == 0 & agri_lag == 0)

label var switch_into_agri "Switched into agriculture"
label var switch_out_agri "Switched out of agriculture"

* Summary
di "Switching rates by year:"
tab year switch_into_agri, row
tab year switch_out_agri, row

save "output/rlms_transitions.dta", replace

********************************************************************************
* PART 2: Aggregate Switching Rates Over Time
********************************************************************************

di as text "=========================================="
di as text "PART 2: Switching Rates by Year"
di as text "=========================================="

* Calculate switching rates by year
preserve

* For switching INTO: base is non-agri workers
keep if agri_lag == 0
collapse (mean) switch_rate_in = switch_into_agri (count) n_nonagri = idind, by(year)
replace switch_rate_in = switch_rate_in * 100
tempfile switch_in
save `switch_in'
restore

preserve
* For switching OUT: base is agri workers
keep if agri_lag == 1
collapse (mean) switch_rate_out = switch_out_agri (count) n_agri = idind, by(year)
replace switch_rate_out = switch_rate_out * 100
tempfile switch_out
save `switch_out'
restore

* Merge
use `switch_in', clear
merge 1:1 year using `switch_out', nogen

* Calculate net flow
gen net_rate = switch_rate_in - switch_rate_out

list year switch_rate_in switch_rate_out net_rate n_nonagri n_agri

* Plot switching rates
twoway (line switch_rate_in year, lcolor(navy) lpattern(solid) lwidth(medthick)) ///
       (line switch_rate_out year, lcolor(maroon) lpattern(dash) lwidth(medthick)), ///
    xline(2014, lcolor(red) lpattern(dash)) ///
    xlabel(2011(2)2023) ///
    ylabel(0(2)10, format(%9.1f)) ///
    xtitle("Year") ///
    ytitle("Switching Rate (%)") ///
    title("Industry Switching Rates Over Time") ///
    legend(order(1 "Into agriculture (from non-agri)" 2 "Out of agriculture (from agri)") ///
        position(6) rows(1)) ///
    note("Switching into: % of non-agri workers who moved to agri. Switching out: % of agri workers who left.") ///
    scheme(s2color)
graph export "output/figures/switching_rates_time.png", replace width(1200)

export delimited using "output/tables/switching_rates_by_year.csv", replace

********************************************************************************
* PART 3: Regression Analysis of Switching
********************************************************************************

di as text "=========================================="
di as text "PART 3: Regression - Switching Outcomes"
di as text "=========================================="

use "output/rlms_transitions.dta", clear

eststo clear

* ============================================
* A. Probability of switching INTO agriculture
* Sample: Workers in non-agriculture at t-1
* ============================================

preserve
keep if agri_lag == 0

* (1) OLS with year FE only (no individual FE to avoid collinearity)
eststo in1: reg switch_into_agri post i.year, cluster(region)

* (2) Add demographics
eststo in2: reg switch_into_agri post age age_sq female i.educ_cat i.year, cluster(region)

* (3) Add region FE
eststo in3: reghdfe switch_into_agri post age age_sq female i.educ_cat, ///
    absorb(year region) cluster(region)

* (4) 2010-2019 only
eststo in4: reg switch_into_agri post i.year if year <= 2019, cluster(region)

restore

* ============================================
* B. Probability of switching OUT OF agriculture
* Sample: Workers in agriculture at t-1
* ============================================

preserve
keep if agri_lag == 1

* (1) OLS with year FE
eststo out1: reg switch_out_agri post i.year, cluster(region)

* (2) Add demographics
eststo out2: reg switch_out_agri post age age_sq female i.educ_cat i.year, cluster(region)

* (3) 2010-2019
eststo out3: reg switch_out_agri post i.year if year <= 2019, cluster(region)

restore

* ============================================
* C. Combined table
* ============================================

esttab in1 in2 in3 in4 using "output/tables/table15_switch_into.tex", ///
    replace booktabs label ///
    title("Probability of Switching INTO Agriculture") ///
    mtitles("Year FE" "+ Demographics" "+ Region FE" "2010-2019") ///
    keep(post) ///
    stats(N r2, labels("Observations" "R-squared")) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    se(4) b(4)

esttab in1 in2 in3 in4 using "output/tables/table15_switch_into.csv", ///
    replace csv label

esttab out1 out2 out3 using "output/tables/table16_switch_out.tex", ///
    replace booktabs label ///
    title("Probability of Switching OUT OF Agriculture") ///
    mtitles("Year FE" "+ Demographics" "2010-2019") ///
    keep(post) ///
    stats(N r2, labels("Observations" "R-squared")) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    se(4) b(4)

esttab out1 out2 out3 using "output/tables/table16_switch_out.csv", ///
    replace csv label

********************************************************************************
* PART 4: Event Study for Switching
********************************************************************************

di as text "=========================================="
di as text "PART 4: Event Study - Switching Into Agri"
di as text "=========================================="

use "output/rlms_transitions.dta", clear
keep if agri_lag == 0

* Event time dummies
forval t = -3/9 {
    if `t' < 0 {
        local tname = "m" + string(abs(`t'))
    }
    else {
        local tname = "p" + string(`t')
    }
    gen E_`tname' = (event_time == `t')
}
* Omit t=-1 as reference
drop E_m1

* Event study regression
reg switch_into_agri E_m3 E_m2 E_p0 E_p1 E_p2 E_p3 E_p4 E_p5 E_p6 E_p7 E_p8 E_p9 i.region, cluster(region)

matrix b_sw = e(b)
matrix V_sw = e(V)

* Create plot data
preserve
clear
set obs 12
gen event_time = .
replace event_time = -3 in 1
replace event_time = -2 in 2
replace event_time = 0 in 3
replace event_time = 1 in 4
replace event_time = 2 in 5
replace event_time = 3 in 6
replace event_time = 4 in 7
replace event_time = 5 in 8
replace event_time = 6 in 9
replace event_time = 7 in 10
replace event_time = 8 in 11
replace event_time = 9 in 12

gen coef = .
gen se = .

forval i = 1/12 {
    replace coef = b_sw[1, `i'] in `i'
    replace se = sqrt(V_sw[`i', `i']) in `i'
}

* Add reference period
set obs 13
replace event_time = -1 in 13
replace coef = 0 in 13
replace se = 0 in 13
sort event_time

* Scale to percentage points
replace coef = coef * 100
replace se = se * 100

gen ci_lo = coef - 1.96*se
gen ci_hi = coef + 1.96*se

twoway (rcap ci_lo ci_hi event_time, lcolor(navy)) ///
       (scatter coef event_time, mcolor(navy) msymbol(circle)), ///
    xline(-0.5, lcolor(red) lpattern(dash)) ///
    yline(0, lcolor(gray) lpattern(solid)) ///
    xlabel(-3(1)9) ///
    ylabel(-1(0.5)1.5, format(%9.1f)) ///
    xtitle("Years Relative to 2014 Food Embargo") ///
    ytitle("Change in P(Switch to Agri) (pp)") ///
    title("Event Study: Switching Into Agriculture") ///
    note("Sample: Workers not in agriculture in t-1. Reference: 2013.") ///
    legend(off) ///
    scheme(s2color)
graph export "output/figures/event_study_switch_into.png", replace width(1200)
graph export "output/figures/event_study_switch_into.pdf", replace
restore

********************************************************************************
* PART 5: Employment in Agriculture (Level)
********************************************************************************

di as text "=========================================="
di as text "PART 5: P(Employed in Agriculture)"
di as text "=========================================="

use "output/rlms_analysis_sample.dta", clear

eststo clear

* Cross-sectional probability of being in agriculture
eststo emp1: reg agri post i.year, cluster(region)
eststo emp2: reg agri post age age_sq female i.educ_cat i.year, cluster(region)
eststo emp3: reghdfe agri post, absorb(year region) cluster(region)

esttab emp1 emp2 emp3 using "output/tables/table17_emp_agri.tex", ///
    replace booktabs label ///
    title("Probability of Being Employed in Agriculture") ///
    mtitles("Year FE" "+ Demographics" "+ Region FE") ///
    keep(post) ///
    stats(N r2, labels("Observations" "R-squared")) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    se(4) b(4)

esttab emp1 emp2 emp3 using "output/tables/table17_emp_agri.csv", ///
    replace csv label

********************************************************************************
* PART 6: Combined Summary Table
********************************************************************************

di as text "=========================================="
di as text "PART 6: Combined Switching Results"
di as text "=========================================="

use "output/rlms_transitions.dta", clear

eststo clear

* (1) P(Switch into) - from non-agri
preserve
keep if agri_lag == 0
eststo comb1: reg switch_into_agri post i.year, cluster(region)
local b1 = _b[post]
local se1 = _se[post]
local n1 = e(N)
restore

* (2) P(Switch out) - from agri
preserve
keep if agri_lag == 1
eststo comb2: reg switch_out_agri post i.year, cluster(region)
local b2 = _b[post]
local se2 = _se[post]
local n2 = e(N)
restore

* (3) P(In agriculture) - all workers
use "output/rlms_analysis_sample.dta", clear
eststo comb3: reg agri post i.year, cluster(region)

esttab comb1 comb2 comb3 using "output/tables/table18_switching_combined.tex", ///
    replace booktabs label ///
    title("Industry Switching and Employment as Outcomes") ///
    mtitles("P(Switch In)" "P(Switch Out)" "P(In Agri)") ///
    keep(post) ///
    stats(N r2, labels("Observations" "R-squared")) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    se(4) b(4)

esttab comb1 comb2 comb3 using "output/tables/table18_switching_combined.csv", ///
    replace csv label

di ""
di "SUMMARY OF SWITCHING RESULTS:"
di "=============================="
di "P(Switch INTO agri | was non-agri): post coef = " %6.4f `b1' " (se = " %6.4f `se1' "), N = " `n1'
di "P(Switch OUT of agri | was agri):   post coef = " %6.4f `b2' " (se = " %6.4f `se2' "), N = " `n2'
di ""

********************************************************************************
* CLOSE
********************************************************************************

di as text "=========================================="
di as text "Switching Analysis Complete!"
di as text "=========================================="
di as text "Tables: table15-18 (switching)"
di as text "Figures: switching_rates_time, event_study_switch_into"
di as text "=========================================="

log close
