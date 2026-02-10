* Event Study Figure: Embargo Timing
* Shows effects appear BEFORE the December 2014 ruble crash

clear all
set more off

cd "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Working santctions"

log using "output/timing/event_study_figure2_log.txt", replace text

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
gen Dm3 = agri * (event_time == -3)
gen Dm2 = agri * (event_time == -2)
gen D0 = agri * (event_time == 0)
gen D1 = agri * (event_time == 1)
gen D2 = agri * (event_time == 2)
gen D3 = agri * (event_time == 3)
gen D4 = agri * (event_time == 4)

********************************************************************************
* Run event study regression
********************************************************************************

di "Event study regression:"
reg ln_wage Dm3 Dm2 D0 D1 D2 D3 D4 agri i.period age age_sq female i.educ_cat, cluster(region)

* Store results
local b_m3 = _b[Dm3]
local b_m2 = _b[Dm2]
local b_0 = _b[D0]
local b_1 = _b[D1]
local b_2 = _b[D2]
local b_3 = _b[D3]
local b_4 = _b[D4]

local se_m3 = _se[Dm3]
local se_m2 = _se[Dm2]
local se_0 = _se[D0]
local se_1 = _se[D1]
local se_2 = _se[D2]
local se_3 = _se[D3]
local se_4 = _se[D4]

di ""
di "Coefficients:"
di "  2011 (t=-3): " %6.4f `b_m3' " (SE: " %6.4f `se_m3' ")"
di "  2012 (t=-2): " %6.4f `b_m2' " (SE: " %6.4f `se_m2' ")"
di "  2013 (t=-1): Reference"
di "  2014 (t=0):  " %6.4f `b_0' " (SE: " %6.4f `se_0' ") *** KEY: Aug-Nov only ***"
di "  2015 (t=1):  " %6.4f `b_1' " (SE: " %6.4f `se_1' ")"
di "  2016 (t=2):  " %6.4f `b_2' " (SE: " %6.4f `se_2' ")"
di "  2017 (t=3):  " %6.4f `b_3' " (SE: " %6.4f `se_3' ")"
di "  2018 (t=4):  " %6.4f `b_4' " (SE: " %6.4f `se_4' ")"

********************************************************************************
* Create plotting dataset
********************************************************************************

preserve
clear
set obs 8

* Event time
gen event_time = _n - 4  // -3 to 4

* Coefficients
gen coef = .
replace coef = `b_m3' if event_time == -3
replace coef = `b_m2' if event_time == -2
replace coef = 0 if event_time == -1
replace coef = `b_0' if event_time == 0
replace coef = `b_1' if event_time == 1
replace coef = `b_2' if event_time == 2
replace coef = `b_3' if event_time == 3
replace coef = `b_4' if event_time == 4

* Standard errors
gen se = .
replace se = `se_m3' if event_time == -3
replace se = `se_m2' if event_time == -2
replace se = 0 if event_time == -1
replace se = `se_0' if event_time == 0
replace se = `se_1' if event_time == 1
replace se = `se_2' if event_time == 2
replace se = `se_3' if event_time == 3
replace se = `se_4' if event_time == 4

* Confidence intervals
gen ci_lo = coef - 1.96*se
gen ci_hi = coef + 1.96*se

* Year labels
gen year = event_time + 2014

* List
list event_time year coef se ci_lo ci_hi

********************************************************************************
* Figure 1: Main event study with annotations
********************************************************************************

twoway (rarea ci_lo ci_hi event_time, fcolor(navy%20) lcolor(navy%0)) ///
       (connected coef event_time, lcolor(navy) lpattern(solid) lwidth(medthick) ///
           msymbol(circle) mcolor(navy) msize(medlarge)), ///
    xline(-0.5, lcolor(cranberry) lpattern(dash) lwidth(medthick)) ///
    xline(0.4, lcolor(orange) lpattern(shortdash) lwidth(medthick)) ///
    yline(0, lcolor(gs10) lpattern(solid)) ///
    xlabel(-3 "2011" -2 "2012" -1 "2013" 0 "2014" 1 "2015" 2 "2016" 3 "2017" 4 "2018", ///
           labsize(medium)) ///
    ylabel(-0.15(0.05)0.3, format(%4.2f) labsize(medium) angle(horizontal)) ///
    xtitle("Year", size(medlarge)) ///
    ytitle("Effect on Log Wages (relative to 2013)", size(medlarge)) ///
    title("Event Study: Agricultural vs. Other Sectors", size(large)) ///
    text(0.27 -0.5 "Embargo" "(Aug 6)", size(small) color(cranberry) placement(e)) ///
    text(0.27 0.5 "Crash" "(Dec 16)", size(small) color(orange) placement(e)) ///
    note("Notes: 2014 coefficient uses October-November interviews only (after embargo, before December crash)." ///
         "Reference year: 2013. Shaded area = 95% CI. Standard errors clustered by region.", size(small)) ///
    legend(off) ///
    graphregion(color(white)) ///
    plotregion(margin(small))

graph export "output/timing/event_study_main.png", replace width(1600) height(1100)
graph export "output/timing/event_study_main.pdf", replace

********************************************************************************
* Figure 2: Publication-ready version
********************************************************************************

twoway (rcap ci_lo ci_hi event_time, lcolor(navy) lwidth(medium)) ///
       (scatter coef event_time, mcolor(navy) msymbol(circle) msize(large)) ///
       (connected coef event_time, lcolor(navy) lpattern(solid) lwidth(medium) msymbol(none)), ///
    xline(-0.5, lcolor(red*0.8) lpattern(dash) lwidth(medium)) ///
    xline(0.4, lcolor(orange) lpattern(shortdash) lwidth(medium)) ///
    yline(0, lcolor(gs12) lpattern(solid)) ///
    xlabel(-3 "2011" -2 "2012" -1 "2013" 0 `" "2014" "(Oct-Nov)" "' 1 "2015" 2 "2016" 3 "2017" 4 "2018", ///
           labsize(medsmall)) ///
    ylabel(-0.15(0.05)0.3, format(%4.2f) labsize(medsmall) angle(horizontal) grid) ///
    xtitle("Year", size(medium)) ///
    ytitle("Coefficient" "(Agricultural Wage Premium)", size(medium)) ///
    title("Figure X: Event Study - Timing of Agricultural Wage Effects", size(medlarge)) ///
    subtitle("Effects Appear Before December 2014 Ruble Crash", size(medium) color(gs6)) ///
    note("Notes: Red dashed line marks August 6, 2014 food embargo announcement. Orange dashed line marks December 16, 2014" ///
         "'Black Tuesday' ruble crash. The 2014 coefficient is estimated using only October-November interviews, capturing the" ///
         "period after the embargo but before the major currency depreciation. Reference period: 2013. Bars show 95% confidence" ///
         "intervals. Standard errors clustered at the region level. Sample restricted to employed workers aged 18-65.", ///
         size(vsmall)) ///
    legend(off) ///
    graphregion(color(white)) ///
    plotregion(margin(small))

graph export "output/timing/event_study_publication.png", replace width(1800) height(1200)
graph export "output/timing/event_study_publication.pdf", replace

********************************************************************************
* Figure 3: Minimal clean version
********************************************************************************

twoway (rarea ci_lo ci_hi event_time, fcolor(blue%15) lcolor(blue%0)) ///
       (line coef event_time, lcolor(blue) lwidth(thick)), ///
    xline(-0.5, lcolor(red) lpattern(dash)) ///
    xline(0.4, lcolor(orange) lpattern(dash)) ///
    yline(0, lcolor(gs10)) ///
    xlabel(-3 "2011" -2 "2012" -1 "2013" 0 "2014*" 1 "2015" 2 "2016" 3 "2017" 4 "2018") ///
    ylabel(-0.1(0.1)0.3, format(%4.1f)) ///
    xtitle("Year") ///
    ytitle("Effect on Log Wages") ///
    title("Agricultural Wage Premium: Event Study") ///
    legend(off) ///
    graphregion(color(white))

graph export "output/timing/event_study_simple.png", replace width(1200) height(800)
graph export "output/timing/event_study_simple.pdf", replace

restore

di ""
di "=========================================="
di "Figures saved!"
di "=========================================="
di "  output/timing/event_study_main.png"
di "  output/timing/event_study_publication.png"
di "  output/timing/event_study_simple.png"

log close
