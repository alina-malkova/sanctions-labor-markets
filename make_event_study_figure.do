* Event Study Figure: Embargo Timing
* Shows effects appear BEFORE the December 2014 ruble crash

clear all
set more off

cd "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Working santctions"

log using "output/timing/event_study_figure_log.txt", replace text

********************************************************************************
* Load and prepare data
********************************************************************************

use "output/timing/rlms_timing_sample.dta", clear

* Drop and recreate variables
foreach v in agri period {
    capture drop `v'
}

gen agri = (industry == 8)

* Create period: use Aug-Nov for 2014, drop Dec 2014
gen period = year
replace period = . if year == 2014 & interview_month < 8
replace period = . if year == 2014 & interview_month == 12
keep if period != . & period >= 2011 & period <= 2018

* Event time relative to 2014
gen event_time = period - 2014

* Create interaction dummies (omit t=-1, i.e., 2013)
forval t = -3/4 {
    if `t' != -1 {
        gen D`t' = agri * (event_time == `t')
    }
}

********************************************************************************
* Run event study regression
********************************************************************************

di "Event study regression:"
reg ln_wage D* agri i.period age age_sq female i.educ_cat, cluster(region)

* Store coefficients and SEs
matrix b = e(b)
matrix V = e(V)

* Extract coefficients for D variables
local coefs ""
local ses ""
local i = 1
foreach t in -3 -2 0 1 2 3 4 {
    local coef = b[1, `i']
    local se = sqrt(V[`i', `i'])
    local coefs "`coefs' `coef'"
    local ses "`ses' `se'"
    local i = `i' + 1
}

di "Coefficients: `coefs'"
di "SEs: `ses'"

********************************************************************************
* Create plotting dataset
********************************************************************************

clear
set obs 8

* Event time
gen event_time = .
replace event_time = -3 in 1
replace event_time = -2 in 2
replace event_time = -1 in 3
replace event_time = 0 in 4
replace event_time = 1 in 5
replace event_time = 2 in 6
replace event_time = 3 in 7
replace event_time = 4 in 8

* Coefficients (from regression above)
gen coef = .
replace coef = `=word("`coefs'", 1)' in 1  // t=-3
replace coef = `=word("`coefs'", 2)' in 2  // t=-2
replace coef = 0 in 3                       // t=-1 (reference)
replace coef = `=word("`coefs'", 3)' in 4  // t=0
replace coef = `=word("`coefs'", 4)' in 5  // t=1
replace coef = `=word("`coefs'", 5)' in 6  // t=2
replace coef = `=word("`coefs'", 6)' in 7  // t=3
replace coef = `=word("`coefs'", 7)' in 8  // t=4

* Standard errors
gen se = .
replace se = `=word("`ses'", 1)' in 1
replace se = `=word("`ses'", 2)' in 2
replace se = 0 in 3
replace se = `=word("`ses'", 3)' in 4
replace se = `=word("`ses'", 4)' in 5
replace se = `=word("`ses'", 5)' in 6
replace se = `=word("`ses'", 6)' in 7
replace se = `=word("`ses'", 7)' in 8

* Confidence intervals
gen ci_lo = coef - 1.96*se
gen ci_hi = coef + 1.96*se

* Labels for years
gen year_label = event_time + 2014
tostring year_label, replace
replace year_label = "2014*" if event_time == 0

* List data
list event_time coef se ci_lo ci_hi year_label

********************************************************************************
* Create figure
********************************************************************************

* Main event study figure
twoway (rcap ci_lo ci_hi event_time, lcolor(navy) lwidth(medium)) ///
       (scatter coef event_time, mcolor(navy) msymbol(circle) msize(large)) ///
       (connected coef event_time, lcolor(navy) lpattern(solid) msymbol(none)), ///
    xline(-0.5, lcolor(red) lpattern(dash) lwidth(medthick)) ///
    xline(0.35, lcolor(orange) lpattern(shortdash) lwidth(medium)) ///
    yline(0, lcolor(gs10) lpattern(solid)) ///
    xlabel(-3 "2011" -2 "2012" -1 "2013" 0 `" "2014" "(Aug-Nov)" "' 1 "2015" 2 "2016" 3 "2017" 4 "2018", labsize(small)) ///
    ylabel(-0.1(0.05)0.25, format(%4.2f) labsize(small)) ///
    xtitle("Year", size(medium)) ///
    ytitle("Effect on Log Wages" "(relative to 2013)", size(medium)) ///
    title("Event Study: Agricultural Wage Effects", size(large)) ///
    subtitle("Effects Appear Before December 2014 Ruble Crash", size(medium)) ///
    note("Notes: Red dashed line = August 2014 food embargo. Orange line = December 2014 ruble crash." ///
         "2014 coefficient uses Oct-Nov interviews only (post-embargo, pre-crash)." ///
         "Reference period: 2013. 95% confidence intervals shown. Standard errors clustered by region.", ///
         size(vsmall)) ///
    legend(off) ///
    graphregion(color(white)) ///
    plotregion(margin(small)) ///
    scheme(s2color)

graph export "output/timing/event_study_embargo_timing.png", replace width(1400) height(1000)
graph export "output/timing/event_study_embargo_timing.pdf", replace

********************************************************************************
* Alternative: Cleaner version for publication
********************************************************************************

twoway (rarea ci_lo ci_hi event_time, fcolor(navy%20) lcolor(navy%0)) ///
       (connected coef event_time, lcolor(navy) lpattern(solid) lwidth(medthick) ///
           msymbol(circle) mcolor(navy) msize(medlarge)), ///
    xline(-0.5, lcolor(cranberry) lpattern(dash) lwidth(medium)) ///
    xline(0.35, lcolor(orange) lpattern(shortdash) lwidth(medium)) ///
    yline(0, lcolor(gs8) lpattern(solid)) ///
    xlabel(-3 "2011" -2 "2012" -1 "2013" 0 "2014" 1 "2015" 2 "2016" 3 "2017" 4 "2018", labsize(medsmall)) ///
    ylabel(-0.1(0.05)0.25, format(%4.2f) labsize(medsmall) angle(horizontal)) ///
    xtitle("Year", size(medlarge)) ///
    ytitle("Effect on Log Wages", size(medlarge)) ///
    title("Agricultural Wage Premium: Event Study", size(large)) ///
    text(0.22 -0.5 "Embargo" "(Aug 6)", size(small) color(cranberry) placement(n)) ///
    text(0.22 0.35 "Ruble Crash" "(Dec 16)", size(small) color(orange) placement(n)) ///
    text(0.15 0 "Pre-crash" "interviews", size(vsmall) color(navy) placement(s)) ///
    legend(off) ///
    graphregion(color(white)) ///
    plotregion(margin(small))

graph export "output/timing/event_study_clean.png", replace width(1400) height(1000)
graph export "output/timing/event_study_clean.pdf", replace

********************************************************************************
* Version with annotation box
********************************************************************************

twoway (rarea ci_lo ci_hi event_time, fcolor(navy%15) lcolor(navy%0)) ///
       (connected coef event_time, lcolor(navy) lpattern(solid) lwidth(medthick) ///
           msymbol(circle) mcolor(navy) msize(medlarge)), ///
    xline(-0.5, lcolor(cranberry) lpattern(dash) lwidth(medium)) ///
    xline(0.35, lcolor(orange) lpattern(dash) lwidth(medium)) ///
    yline(0, lcolor(gs10) lpattern(solid)) ///
    xlabel(-3 "2011" -2 "2012" -1 "2013" 0 "2014" 1 "2015" 2 "2016" 3 "2017" 4 "2018", labsize(medsmall)) ///
    ylabel(-0.1(0.05)0.25, format(%4.2f) labsize(medsmall) angle(horizontal)) ///
    xtitle("Year", size(medlarge)) ///
    ytitle("Coefficient (Log Wage Difference)", size(medlarge)) ///
    title("Event Study: Agricultural vs. Other Sectors", size(large)) ///
    subtitle("Reference Year: 2013", size(medium)) ///
    note("Red line: August 2014 food embargo. Orange line: December 2014 ruble crash ('Black Tuesday')." ///
         "2014 coefficient estimated using October-November interviews only (after embargo, before crash)." ///
         "Shaded area: 95% CI. SEs clustered by region. N = 38,243.", size(vsmall)) ///
    legend(off) ///
    graphregion(color(white)) ///
    plotregion(margin(small))

graph export "output/timing/event_study_publication.png", replace width(1600) height(1100)
graph export "output/timing/event_study_publication.pdf", replace

di ""
di "=========================================="
di "Figures saved to output/timing/"
di "=========================================="
di "  - event_study_embargo_timing.png"
di "  - event_study_clean.png"
di "  - event_study_publication.png"

log close
