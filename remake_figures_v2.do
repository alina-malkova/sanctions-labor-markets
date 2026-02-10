********************************************************************************
* Remake All Figures with Professional Academic Style
* Version 2 - Fixed variable conflicts
********************************************************************************

clear all
set more off

cd "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Working santctions"

capture mkdir "output/figures_professional"

log using "output/figures_professional/remake_v2_log.txt", replace text

********************************************************************************
* FIGURE 1: EVENT STUDY - MAIN RESULT
********************************************************************************

di "Figure 1: Event Study"

clear
input event_time coef se
-3  0.0986  0.0414
-2  0.0476  0.0466
-1  0       0
 0  0.1180  0.0445
 1  0.1596  0.0526
 2  0.1528  0.0696
 3  0.1517  0.0605
 4  0.2101  0.0527
end

gen ci_lo = coef - 1.96*se
gen ci_hi = coef + 1.96*se

twoway (rarea ci_lo ci_hi event_time, fcolor(gs14) lwidth(none)) ///
       (connected coef event_time, lcolor(black) lpattern(solid) lwidth(medthick) ///
           msymbol(O) mcolor(black) msize(large)), ///
    xline(-0.5, lcolor(gs5) lpattern(dash) lwidth(medthin)) ///
    xline(0.4, lcolor(gs5) lpattern(shortdash) lwidth(medthin)) ///
    yline(0, lcolor(gs12) lpattern(solid)) ///
    xlabel(-3 "2011" -2 "2012" -1 "2013" 0 "2014*" 1 "2015" 2 "2016" 3 "2017" 4 "2018", ///
           labsize(medlarge)) ///
    ylabel(-0.1(0.1)0.3, format(%3.1f) labsize(medlarge) angle(horizontal) ///
           grid glcolor(gs14) glwidth(vthin)) ///
    xtitle("Year", size(large) margin(t=3)) ///
    ytitle("Coefficient", size(large) margin(r=2)) ///
    title("Event Study: Agricultural Wage Premium", size(vlarge) margin(b=2)) ///
    subtitle("Effects Appear Before December 2014 Ruble Crash", size(medium) color(gs5)) ///
    legend(off) ///
    graphregion(color(white) margin(small)) ///
    plotregion(lcolor(gs10)) ///
    note("Notes: *2014 uses Oct-Nov interviews only (post-embargo, pre-crash). Reference: 2013." ///
         "Dashed lines: Aug 2014 embargo, Dec 2014 crash. Shaded = 95% CI. SEs clustered by region.", ///
         size(small) margin(t=2))

graph export "output/figures_professional/fig1_event_study.pdf", replace
graph export "output/figures_professional/fig1_event_study.png", replace width(2400) height(1600)

********************************************************************************
* FIGURE 2: WAGE TRENDS
********************************************************************************

di "Figure 2: Wage Trends"

use "output/rlms_analysis_sample.dta", clear

capture drop agri_temp
gen agri_temp = (industry == 8)

preserve
collapse (mean) ln_wage wage_month [pw=inwgt], by(year agri_temp)
reshape wide ln_wage wage_month, i(year) j(agri_temp)

twoway (connected ln_wage0 year, lcolor(gs7) lpattern(solid) lwidth(medium) ///
           msymbol(S) mcolor(gs7) msize(medium)) ///
       (connected ln_wage1 year, lcolor(black) lpattern(solid) lwidth(medthick) ///
           msymbol(O) mcolor(black) msize(medlarge)), ///
    xline(2014, lcolor(gs5) lpattern(dash) lwidth(medthin)) ///
    xlabel(2010(2)2022, labsize(medlarge)) ///
    ylabel(9.2(0.2)10.2, format(%3.1f) labsize(medlarge) angle(horizontal) ///
           grid glcolor(gs14) glwidth(vthin)) ///
    xtitle("Year", size(large) margin(t=3)) ///
    ytitle("Mean Log Wage", size(large) margin(r=2)) ///
    title("Wage Trends by Sector", size(vlarge) margin(b=2)) ///
    legend(order(1 "Other Sectors" 2 "Agriculture") ///
           position(6) rows(1) size(medlarge) region(lcolor(white))) ///
    graphregion(color(white) margin(small)) ///
    plotregion(lcolor(gs10)) ///
    note("Notes: Vertical line = August 2014 embargo. Sample: employed workers ages 18-65.", ///
         size(small) margin(t=2))

graph export "output/figures_professional/fig2_wage_trends.pdf", replace
graph export "output/figures_professional/fig2_wage_trends.png", replace width(2400) height(1600)

restore

********************************************************************************
* FIGURE 3: EMPLOYMENT SHARE
********************************************************************************

di "Figure 3: Employment Share"

preserve
gen n = 1
capture drop agri_temp
gen agri_temp = (industry == 8)
collapse (sum) n, by(year agri_temp)
reshape wide n, i(year) j(agri_temp)
gen agri_share = n1 / (n0 + n1) * 100

twoway (connected agri_share year, lcolor(black) lpattern(solid) lwidth(medthick) ///
           msymbol(O) mcolor(black) msize(medlarge)), ///
    xline(2014, lcolor(gs5) lpattern(dash) lwidth(medthin)) ///
    xlabel(2010(2)2022, labsize(medlarge)) ///
    ylabel(2(1)6, format(%3.1f) labsize(medlarge) angle(horizontal) ///
           grid glcolor(gs14) glwidth(vthin)) ///
    xtitle("Year", size(large) margin(t=3)) ///
    ytitle("Employment Share (%)", size(large) margin(r=2)) ///
    title("Agricultural Employment Share", size(vlarge) margin(b=2)) ///
    legend(off) ///
    graphregion(color(white) margin(small)) ///
    plotregion(lcolor(gs10)) ///
    note("Notes: Vertical line = August 2014 embargo.", size(small) margin(t=2))

graph export "output/figures_professional/fig3_employment_share.pdf", replace
graph export "output/figures_professional/fig3_employment_share.png", replace width(2400) height(1600)

restore

********************************************************************************
* FIGURE 4: EXCHANGE RATE 2014
********************************************************************************

di "Figure 4: Exchange Rate"

clear
input month day usd_rub
1 1 32.89
2 1 35.24
3 1 36.21
4 1 35.69
5 1 35.72
6 1 34.47
7 1 33.84
8 1 36.03
8 6 36.18
9 1 37.28
10 1 39.38
10 15 40.56
11 1 43.02
11 15 47.12
12 1 51.01
12 16 68.53
12 31 56.24
end

gen date = mdy(month, day, 2014)
format date %td

twoway (line usd_rub date, lcolor(black) lwidth(medthick)), ///
    xline(`=mdy(8,6,2014)', lcolor(gs5) lpattern(dash) lwidth(medthin)) ///
    xline(`=mdy(12,16,2014)', lcolor(gs5) lpattern(shortdash) lwidth(medthin)) ///
    xlabel(`=mdy(1,1,2014)' "Jan" `=mdy(4,1,2014)' "Apr" `=mdy(7,1,2014)' "Jul" ///
           `=mdy(10,1,2014)' "Oct" `=mdy(12,31,2014)' "Dec", labsize(medlarge)) ///
    ylabel(30(10)70, format(%3.0f) labsize(medlarge) angle(horizontal) ///
           grid glcolor(gs14) glwidth(vthin)) ///
    xtitle("Date (2014)", size(large) margin(t=3)) ///
    ytitle("USD/RUB", size(large) margin(r=2)) ///
    title("Ruble Exchange Rate in 2014", size(vlarge) margin(b=2)) ///
    text(62 `=mdy(8,6,2014)' "Embargo", size(medsmall) color(gs4) placement(e)) ///
    text(72 `=mdy(12,16,2014)' `""Black Tuesday""', size(medsmall) color(gs4) placement(w)) ///
    legend(off) ///
    graphregion(color(white) margin(small)) ///
    plotregion(lcolor(gs10)) ///
    note("Notes: Dashed lines = Aug 6 embargo, Dec 16 crash.", size(small) margin(t=2))

graph export "output/figures_professional/fig4_exchange_rate.pdf", replace
graph export "output/figures_professional/fig4_exchange_rate.png", replace width(2400) height(1600)

********************************************************************************
* FIGURE 5: SYNTHETIC CONTROL
********************************************************************************

di "Figure 5: Synthetic Control"

use "output/rlms_analysis_sample.dta", clear

preserve
capture drop agri_temp
gen agri_temp = (industry == 8)
collapse (mean) ln_wage [pw=inwgt], by(year industry)
drop if industry == .
reshape wide ln_wage, i(year) j(industry)

egen synth = rowmean(ln_wage2 ln_wage5 ln_wage6 ln_wage7 ln_wage9 ln_wage10 ln_wage14)

sum ln_wage8 if year <= 2013
local a = r(mean)
sum synth if year <= 2013
local s = r(mean)
gen synth_adj = synth + (`a' - `s')

twoway (line ln_wage8 year, lcolor(black) lpattern(solid) lwidth(medthick)) ///
       (line synth_adj year, lcolor(gs7) lpattern(dash) lwidth(medium)), ///
    xline(2014, lcolor(gs5) lpattern(dash) lwidth(medthin)) ///
    xlabel(2010(2)2022, labsize(medlarge)) ///
    ylabel(9.0(0.2)9.8, format(%3.1f) labsize(medlarge) angle(horizontal) ///
           grid glcolor(gs14) glwidth(vthin)) ///
    xtitle("Year", size(large) margin(t=3)) ///
    ytitle("Mean Log Wage", size(large) margin(r=2)) ///
    title("Synthetic Control Comparison", size(vlarge) margin(b=2)) ///
    legend(order(1 "Agriculture" 2 "Synthetic Control") ///
           position(6) rows(1) size(medlarge) region(lcolor(white))) ///
    graphregion(color(white) margin(small)) ///
    plotregion(lcolor(gs10)) ///
    note("Notes: Synthetic = weighted avg of manufacturing, services. Adjusted to match pre-2014.", ///
         size(small) margin(t=2))

graph export "output/figures_professional/fig5_synthetic.pdf", replace
graph export "output/figures_professional/fig5_synthetic.png", replace width(2400) height(1600)

restore

********************************************************************************
* FIGURE 6: TIMING DETAIL - INTERVIEW MONTHS
********************************************************************************

di "Figure 6: Interview Timing"

use "output/timing/rlms_timing_sample.dta", clear

capture drop agri_temp
gen agri_temp = (industry == 8)

preserve
keep if year == 2014
collapse (mean) ln_wage (count) n=ln_wage, by(interview_month agri_temp)
reshape wide ln_wage n, i(interview_month) j(agri_temp)

twoway (bar n1 interview_month, barwidth(0.8) fcolor(gs10) lcolor(black)), ///
    xline(8, lcolor(gs5) lpattern(dash) lwidth(medthin)) ///
    xline(12, lcolor(gs5) lpattern(shortdash) lwidth(medthin)) ///
    xlabel(1 "Jan" 10 "Oct" 11 "Nov" 12 "Dec", labsize(medlarge)) ///
    ylabel(0(50)200, labsize(medlarge) angle(horizontal) grid glcolor(gs14)) ///
    xtitle("Interview Month (2014)", size(large) margin(t=3)) ///
    ytitle("Number of Agricultural Workers", size(large) margin(r=2)) ///
    title("2014 RLMS Interview Timing", size(vlarge) margin(b=2)) ///
    subtitle("Agricultural Workers by Month", size(medium) color(gs5)) ///
    text(180 8 "Embargo", size(medsmall) color(gs4) placement(e)) ///
    text(180 12 "Crash", size(medsmall) color(gs4) placement(w)) ///
    legend(off) ///
    graphregion(color(white) margin(small)) ///
    plotregion(lcolor(gs10)) ///
    note("Notes: Most 2014 interviews (Oct-Nov) occurred after embargo but before crash.", ///
         size(small) margin(t=2))

graph export "output/figures_professional/fig6_interview_timing.pdf", replace
graph export "output/figures_professional/fig6_interview_timing.png", replace width(2400) height(1600)

restore

********************************************************************************
* DONE
********************************************************************************

di ""
di "=========================================="
di "All Professional Figures Created!"
di "=========================================="
di ""
di "Location: output/figures_professional/"
di ""
di "Files created:"
di "  fig1_event_study.png"
di "  fig2_wage_trends.png"
di "  fig3_employment_share.png"
di "  fig4_exchange_rate.png"
di "  fig5_synthetic.png"
di "  fig6_interview_timing.png"

log close
