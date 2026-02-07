********************************************************************************
* Employment Effects Analysis
* Did agricultural employment grow? Displacement in control sectors?
********************************************************************************

clear all
set more off
set matsize 11000

cd "/Users/amalkova/OneDrive - Florida Institute of Technology/Working santctions"

capture log close
log using "output/analysis_employment_log.txt", replace text

********************************************************************************
* PART 1: Agricultural Employment Trends
********************************************************************************

di as text "=========================================="
di as text "PART 1: Agricultural Employment Trends"
di as text "=========================================="

use "output/rlms_analysis_sample.dta", clear

* Count employment by year and sector
preserve
gen n = 1
collapse (sum) n, by(year agri)
reshape wide n, i(year) j(agri)
rename n0 emp_nonagri
rename n1 emp_agri
gen emp_total = emp_nonagri + emp_agri
gen agri_share = emp_agri / emp_total * 100
gen agri_pct_change = (emp_agri / emp_agri[_n-1] - 1) * 100 if _n > 1

* Display
list year emp_agri emp_nonagri emp_total agri_share agri_pct_change

* Save
export delimited using "output/tables/employment_levels_by_year.csv", replace

* Plot: Agricultural employment level
twoway (bar emp_agri year, barwidth(0.7) color(navy%70)), ///
    xline(2013.5, lcolor(red) lpattern(dash)) ///
    xlabel(2010(2)2023) ///
    ylabel(0(100)600, format(%9.0f)) ///
    xtitle("Year") ///
    ytitle("Agricultural Workers (count)") ///
    title("Agricultural Employment Over Time") ///
    note("Sample: RLMS employed workers with wages. Vertical line: 2014 embargo.") ///
    scheme(s2color)
graph export "output/figures/agri_employment_level.png", replace width(1200)

* Plot: Agricultural share
twoway (line agri_share year, lcolor(navy) lpattern(solid) lwidth(medthick)), ///
    xline(2014, lcolor(red) lpattern(dash)) ///
    xlabel(2010(2)2023) ///
    ylabel(3(0.5)6, format(%9.1f)) ///
    xtitle("Year") ///
    ytitle("Agricultural Share of Employment (%)") ///
    title("Agricultural Employment Share") ///
    note("Share of employed workers in agriculture sector.") ///
    scheme(s2color)
graph export "output/figures/agri_employment_share_line.png", replace width(1200)

* Calculate pre vs post averages
sum agri_share if year < 2014
local pre_share = r(mean)
sum agri_share if year >= 2014
local post_share = r(mean)
local diff = `post_share' - `pre_share'

di ""
di "AGRICULTURAL EMPLOYMENT SHARE:"
di "Pre-2014 average:  " %5.2f `pre_share' "%"
di "Post-2014 average: " %5.2f `post_share' "%"
di "Difference:        " %5.2f `diff' " pp"
di ""

restore

********************************************************************************
* PART 2: Employment Growth by Sector
********************************************************************************

di as text "=========================================="
di as text "PART 2: Employment Growth by Sector"
di as text "=========================================="

* Calculate employment by detailed sector
preserve
gen n = 1
collapse (sum) n, by(year industry)
drop if industry == .

* Reshape
reshape wide n, i(year) j(industry)

* Calculate growth rates (relative to 2013)
foreach var of varlist n* {
    local base = `var'[4]  // 2013 is 4th year (2010, 2011, 2012, 2013)
    gen growth_`var' = (`var' / `base' - 1) * 100
}

* Agriculture is industry 8
list year n8 growth_n8

* Plot growth: Agriculture vs. average of other sectors
egen avg_other = rowmean(growth_n2 growth_n3 growth_n4 growth_n5 growth_n6 growth_n7 growth_n9 growth_n10 growth_n14)

twoway (line growth_n8 year, lcolor(navy) lpattern(solid) lwidth(medthick)) ///
       (line avg_other year, lcolor(gray) lpattern(dash) lwidth(medium)), ///
    xline(2014, lcolor(red) lpattern(dash)) ///
    yline(0, lcolor(gray) lpattern(solid)) ///
    xlabel(2010(2)2023) ///
    ylabel(-40(20)40, format(%9.0f)) ///
    xtitle("Year") ///
    ytitle("Employment Growth (% relative to 2013)") ///
    title("Employment Growth: Agriculture vs. Other Sectors") ///
    legend(order(1 "Agriculture" 2 "Other sectors (avg)") position(6) rows(1)) ///
    note("Base year: 2013 = 0%. Growth computed as % change from 2013 level.") ///
    scheme(s2color)
graph export "output/figures/employment_growth_comparison.png", replace width(1200)

restore

********************************************************************************
* PART 3: Displacement Effects in Control Sectors
********************************************************************************

di as text "=========================================="
di as text "PART 3: Displacement Effects"
di as text "=========================================="

use "output/rlms_analysis_sample.dta", clear

* Create sector indicators
gen manufacturing = inlist(industry, 2, 3, 4, 5)
gen construction = (industry == 6)
gen transport = (industry == 7)
gen services = inlist(industry, 9, 10, 11, 12, 13, 14)
gen trade = (industry == 14)

* Regression: P(in sector) on post, controlling for demographics
eststo clear

* Agriculture (for comparison)
eststo disp1: reg agri post age age_sq female i.educ_cat i.year, cluster(region)

* Manufacturing
eststo disp2: reg manufacturing post age age_sq female i.educ_cat i.year, cluster(region)

* Construction
eststo disp3: reg construction post age age_sq female i.educ_cat i.year, cluster(region)

* Transport
eststo disp4: reg transport post age age_sq female i.educ_cat i.year, cluster(region)

* Services (gov, edu, health, etc.)
eststo disp5: reg services post age age_sq female i.educ_cat i.year, cluster(region)

* Trade
eststo disp6: reg trade post age age_sq female i.educ_cat i.year, cluster(region)

esttab disp1 disp2 disp3 disp4 disp5 disp6 using "output/tables/table19_displacement.tex", ///
    replace booktabs label ///
    title("Displacement Effects: Employment by Sector") ///
    mtitles("Agriculture" "Manufacturing" "Construction" "Transport" "Services" "Trade") ///
    keep(post) ///
    stats(N r2, labels("Observations" "R-squared")) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    se(4) b(4)

esttab disp1 disp2 disp3 disp4 disp5 disp6 using "output/tables/table19_displacement.csv", ///
    replace csv label

********************************************************************************
* PART 4: Employment Shares Over Time (Detailed)
********************************************************************************

di as text "=========================================="
di as text "PART 4: Sector Shares Over Time"
di as text "=========================================="

preserve
gen n = 1

* Collapse by sector groups
gen sector_group = .
replace sector_group = 1 if agri == 1
replace sector_group = 2 if inlist(industry, 2, 3, 4, 5)  // Manufacturing
replace sector_group = 3 if industry == 6                  // Construction
replace sector_group = 4 if inlist(industry, 9, 10)        // Public (gov, edu)
replace sector_group = 5 if industry == 14                 // Trade
replace sector_group = 6 if sector_group == .              // Other

label define sector_lbl 1 "Agriculture" 2 "Manufacturing" 3 "Construction" ///
    4 "Public Sector" 5 "Trade" 6 "Other"
label values sector_group sector_lbl

collapse (sum) n, by(year sector_group)
bysort year: egen total = sum(n)
gen share = n / total * 100

reshape wide n share, i(year) j(sector_group)

list year share1 share2 share3 share4 share5 share6

* Stacked area plot
twoway (area share6 share5 share4 share3 share2 share1 year, ///
    color(gs12 orange%70 maroon%70 teal%70 navy%70 green%70)), ///
    xline(2014, lcolor(red) lpattern(dash)) ///
    xlabel(2010(2)2023) ///
    ylabel(0(20)100, format(%9.0f)) ///
    xtitle("Year") ///
    ytitle("Employment Share (%)") ///
    title("Employment Composition by Sector") ///
    legend(order(6 "Agriculture" 5 "Manufacturing" 4 "Construction" ///
        3 "Public" 2 "Trade" 1 "Other") position(3) cols(1)) ///
    note("Vertical line: 2014 embargo.") ///
    scheme(s2color)
graph export "output/figures/employment_composition.png", replace width(1200)

export delimited using "output/tables/sector_shares_by_year.csv", replace

restore

********************************************************************************
* PART 5: DiD for Employment (Not Wages)
********************************************************************************

di as text "=========================================="
di as text "PART 5: DiD for Employment Probability"
di as text "=========================================="

use "output/rlms_analysis_sample.dta", clear

* Create initial industry (pre-2014)
preserve
keep if year < 2014 & industry != .
bysort idind (year): gen first_obs = (_n == 1)
keep if first_obs == 1
keep idind industry
rename industry initial_industry
tempfile init
save `init'
restore

merge m:1 idind using `init', keep(1 3)
gen matched = (_merge == 3)
drop _merge

gen initial_agri = (initial_industry == 8) if matched == 1

* DiD: Does being initially in agriculture predict staying employed?
gen employed = 1  // All observations in wage sample are employed

* For this we need full sample including non-employed
* Using wage sample, we can test: conditional on being employed,
* what's P(in agriculture)?

eststo clear

* Among initially agricultural workers: P(still in agri)
preserve
keep if initial_agri == 1 & matched == 1
eststo emp1: reg agri post i.year, cluster(region)
restore

* Among initially non-agricultural: P(now in agri)
preserve
keep if initial_agri == 0 & matched == 1
eststo emp2: reg agri post i.year, cluster(region)
restore

* All workers: P(in agri)
eststo emp3: reg agri post i.year if matched == 1, cluster(region)

esttab emp1 emp2 emp3 using "output/tables/table20_employment_did.tex", ///
    replace booktabs label ///
    title("Employment in Agriculture: DiD by Initial Sector") ///
    mtitles("Initially Agri" "Initially Non-Agri" "All Workers") ///
    keep(post) ///
    stats(N r2, labels("Observations" "R-squared")) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    se(4) b(4)

esttab emp1 emp2 emp3 using "output/tables/table20_employment_did.csv", ///
    replace csv label

********************************************************************************
* PART 6: Summary Statistics
********************************************************************************

di as text "=========================================="
di as text "PART 6: Summary"
di as text "=========================================="

di ""
di "=============================================="
di "EMPLOYMENT EFFECTS SUMMARY"
di "=============================================="
di ""

* Calculate key numbers
use "output/rlms_analysis_sample.dta", clear

* Agricultural employment counts
count if agri == 1 & year == 2013
local agri_2013 = r(N)
count if agri == 1 & year == 2019
local agri_2019 = r(N)
count if agri == 1 & year == 2023
local agri_2023 = r(N)

local growth_2019 = (`agri_2019' / `agri_2013' - 1) * 100
local growth_2023 = (`agri_2023' / `agri_2013' - 1) * 100

di "Agricultural employment (counts):"
di "  2013: " `agri_2013'
di "  2019: " `agri_2019' " (growth: " %5.1f `growth_2019' "%)"
di "  2023: " `agri_2023' " (growth: " %5.1f `growth_2023' "%)"
di ""

* Share
gen n = 1
preserve
collapse (sum) n, by(year agri)
reshape wide n, i(year) j(agri)
gen share = n1 / (n0 + n1) * 100
sum share if year == 2013
local share_2013 = r(mean)
sum share if year == 2019
local share_2019 = r(mean)
sum share if year == 2023
local share_2023 = r(mean)
restore

di "Agricultural share of employment:"
di "  2013: " %5.2f `share_2013' "%"
di "  2019: " %5.2f `share_2019' "% (change: " %5.2f `share_2019'-`share_2013' " pp)"
di "  2023: " %5.2f `share_2023' "% (change: " %5.2f `share_2023'-`share_2013' " pp)"
di ""

di "Key finding: Agricultural employment share DECLINED post-embargo"
di "despite earnings gains for agricultural workers."
di ""

********************************************************************************
* CLOSE
********************************************************************************

di as text "=========================================="
di as text "Employment Analysis Complete!"
di as text "=========================================="
di as text "Tables: table19-20, employment_levels_by_year, sector_shares"
di as text "Figures: agri_employment_level, employment_growth_comparison,"
di as text "         employment_composition"
di as text "=========================================="

log close
