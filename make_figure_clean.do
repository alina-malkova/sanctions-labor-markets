* Clean Event Study Figure
clear all
set more off

cd "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Working santctions"

* Create data from regression results
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

* CIs
gen ci_lo = coef - 1.96*se
gen ci_hi = coef + 1.96*se
gen year = event_time + 2014

* Figure: Publication ready
twoway (rcap ci_lo ci_hi event_time, lcolor(navy) lwidth(medthick)) ///
       (scatter coef event_time, mcolor(navy) msymbol(circle) msize(vlarge)) ///
       (connected coef event_time, lcolor(navy) lpattern(solid) lwidth(thick) msymbol(none)), ///
    xline(-0.5, lcolor(cranberry) lpattern(dash) lwidth(thick)) ///
    xline(0.4, lcolor(orange) lpattern(dash) lwidth(thick)) ///
    yline(0, lcolor(gs10) lpattern(solid)) ///
    xlabel(-3 "2011" -2 "2012" -1 "2013" 0 "2014" 1 "2015" 2 "2016" 3 "2017" 4 "2018", labsize(medlarge)) ///
    ylabel(-0.1(0.1)0.3, format(%3.1f) labsize(medlarge) angle(horizontal) grid) ///
    xtitle("Year", size(large)) ///
    ytitle("Effect on Log Wages", size(large)) ///
    title("Event Study: Agricultural Wage Effects", size(vlarge)) ///
    subtitle("Timing Evidence: Effects Appear Before December 2014 Ruble Crash", size(medium) color(gs5)) ///
    text(0.28 -0.3 "Food Embargo" "(Aug 6, 2014)", size(medsmall) color(cranberry)) ///
    text(0.28 0.7 "Ruble Crash" "(Dec 16, 2014)", size(medsmall) color(orange)) ///
    note("Notes: The 2014 coefficient uses October-November RLMS interviews only" ///
         "(after the August embargo but before the December currency crash)." ///
         "Reference year: 2013. Bars show 95% CI. SEs clustered by region.", size(small)) ///
    legend(off) ///
    graphregion(color(white)) bgcolor(white)

graph export "output/timing/event_study_pub.png", replace width(2000) height(1400)
graph export "output/timing/event_study_pub.pdf", replace

* Minimal version
twoway (rarea ci_lo ci_hi event_time, fcolor(blue%20) lcolor(blue%0)) ///
       (line coef event_time, lcolor(blue) lwidth(vthick)), ///
    xline(-0.5, lcolor(red) lpattern(dash) lwidth(thick)) ///
    xline(0.4, lcolor(orange) lpattern(dash) lwidth(thick)) ///
    yline(0, lcolor(gs8)) ///
    xlabel(-3 "2011" -2 "2012" -1 "2013" 0 "2014*" 1 "2015" 2 "2016" 3 "2017" 4 "2018", labsize(large)) ///
    ylabel(-0.1(0.1)0.3, format(%3.1f) labsize(large)) ///
    xtitle("Year", size(vlarge)) ///
    ytitle("Agricultural Wage Premium", size(vlarge)) ///
    title("Event Study: Effects Before Ruble Crash", size(huge)) ///
    legend(off) ///
    graphregion(color(white)) bgcolor(white)

graph export "output/timing/event_study_minimal.png", replace width(1600) height(1100)
graph export "output/timing/event_study_minimal.pdf", replace

di "Figures saved!"
