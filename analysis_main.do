********************************************************************************
* Import Substitution and Labor Markets: Evidence from Russia's Food Embargo
* Main Analysis Do-File
*
* Data: RLMS 2010-2023, RFSD Regional Treatment Intensity
* Treatment: August 2014 Food Import Ban
********************************************************************************

clear all
set more off
set matsize 11000
set maxvar 32767

* Set working directory
cd "/Users/amalkova/OneDrive - Florida Institute of Technology/Working santctions"

* Create output folders
capture mkdir "output"
capture mkdir "output/tables"
capture mkdir "output/figures"

* Log file
capture log close
log using "output/analysis_log.txt", replace text

********************************************************************************
* PART 0: Install Required Packages
********************************************************************************

* Uncomment to install (run once)
/*
ssc install reghdfe, replace
ssc install ftools, replace
ssc install coefplot, replace
ssc install estout, replace
ssc install binscatter, replace
ssc install csdid, replace
ssc install drdid, replace
ssc install eventstudyinteract, replace
ssc install did_multiplegt, replace
ssc install avar, replace
ssc install event_plot, replace
*/

********************************************************************************
* PART 1: Load and Clean RLMS Data
********************************************************************************

di as text "=========================================="
di as text "PART 1: Loading RLMS Data"
di as text "=========================================="

* Load individual-level data
use "IND/RLMS_IND_1994_2023_eng_dta.dta", clear

* Keep analysis years (2010-2023)
keep if year >= 2010 & year <= 2023
di "Observations after year filter: " _N

* Keep key variables
keep idind id_h year region psu status ///
     age h5 h6 educ diplom marst ///
     j1 j10 j10_1 j10_2 j4_1 j8 j11 j9 ///
     occup08 inwgt

* Rename for clarity
rename h5 female
replace female = (female == 2)
label var female "Female (1=yes)"

rename j10 wage_month
label var wage_month "After-tax wages last 30 days"

rename j4_1 industry
label var industry "Industry code"

rename j8 hours_month
label var hours_month "Hours worked last 30 days"

rename j1 employed
label var employed "Currently working"

rename j9 firm_size
label var firm_size "Number of employees at firm"

rename j11 enterprise_type
label var enterprise_type "Enterprise type"

********************************************************************************
* PART 2: Clean Variables
********************************************************************************

di as text "=========================================="
di as text "PART 2: Cleaning Variables"
di as text "=========================================="

* Clean wage variable
* Missing codes: 99999999 = Don't know, 99999997 = Refused
replace wage_month = . if wage_month >= 99999990
replace wage_month = . if wage_month <= 0

* Log wage
gen ln_wage = ln(wage_month)
label var ln_wage "Log monthly wage"

* Clean hours
replace hours_month = . if hours_month >= 99999990
replace hours_month = . if hours_month <= 0 | hours_month > 744

* Hourly wage
gen wage_hourly = wage_month / hours_month if hours_month > 0
gen ln_wage_hourly = ln(wage_hourly)
label var wage_hourly "Hourly wage"
label var ln_wage_hourly "Log hourly wage"

* Clean age
replace age = . if age >= 99999990
replace age = . if age < 15 | age > 75
gen age_sq = age^2
label var age_sq "Age squared"

* Clean education
replace educ = . if educ >= 99999990

* Education categories
gen educ_cat = .
replace educ_cat = 1 if educ <= 6   // Less than secondary
replace educ_cat = 2 if educ >= 7 & educ <= 12  // Secondary
replace educ_cat = 3 if educ >= 13 & educ <= 17 // Some college
replace educ_cat = 4 if educ >= 18 & educ < .   // University+
label var educ_cat "Education category"
label define educ_cat_lbl 1 "Less than secondary" 2 "Secondary" 3 "Some college" 4 "University+"
label values educ_cat educ_cat_lbl

* Clean industry
replace industry = . if industry >= 99999990

********************************************************************************
* PART 3: Define Treatment Variables
********************************************************************************

di as text "=========================================="
di as text "PART 3: Defining Treatment"
di as text "=========================================="

* Agriculture sector (primary treatment)
gen agri = (industry == 8)
label var agri "Agriculture sector"

* Food industry (secondary treatment)
gen food_industry = (industry == 1)
label var food_industry "Food/Light industry"

* Broad treated sector
gen treated_sector = (agri == 1 | food_industry == 1)
label var treated_sector "Agriculture or Food industry"

* Post-treatment indicator
gen post = (year >= 2014)
label var post "Post-2014"

* Post August 2014 (more precise - assume survey is fall)
gen post_aug = (year >= 2015) | (year == 2014)
label var post_aug "Post-August 2014"

* Interaction terms
gen agri_post = agri * post
label var agri_post "Agriculture × Post-2014"

gen food_post = food_industry * post
label var food_post "Food industry × Post-2014"

gen treated_post = treated_sector * post
label var treated_post "Treated sector × Post-2014"

* Event time
gen event_time = year - 2014
label var event_time "Years relative to 2014"

* Event time dummies
forval t = -4/9 {
    if `t' < 0 {
        local tname = "m" + string(abs(`t'))
    }
    else {
        local tname = "p" + string(`t')
    }
    gen D_`tname' = (event_time == `t') * agri
    label var D_`tname' "Agri × Year `t'"
}

* Omit t=-1 as reference
drop D_m1

********************************************************************************
* PART 4: Merge Region Crosswalk
********************************************************************************

di as text "=========================================="
di as text "PART 4: Merging Region Data"
di as text "=========================================="

* Save temp file
tempfile rlms_temp
save `rlms_temp'

* Import region crosswalk
import delimited "region_crosswalk.csv", clear varnames(1)
rename psu region
tempfile crosswalk
save `crosswalk'

* Merge
use `rlms_temp', clear
merge m:1 region using `crosswalk', keep(1 3) nogen
di "Observations after region merge: " _N

* Import treatment intensity
import delimited "RFSD_data/output/rfsd_treatment_intensity.csv", clear varnames(1)
keep region_rfsd baseline_share_food_agri baseline_treatment_combined ///
     treatment_tercile high_treatment
tempfile treatment
save `treatment'

* Merge treatment intensity
use `rlms_temp', clear
merge m:1 region using `crosswalk', keep(1 3) nogen
merge m:1 region_rfsd using `treatment', keep(1 3) nogen

* Treatment intensity interactions
gen intensity_post = baseline_treatment_combined * post
label var intensity_post "Treatment intensity × Post"

gen high_treat_post = high_treatment * post
label var high_treat_post "High treatment region × Post"

********************************************************************************
* PART 5: Sample Restrictions
********************************************************************************

di as text "=========================================="
di as text "PART 5: Sample Restrictions"
di as text "=========================================="

* Working-age sample
keep if age >= 18 & age <= 65
di "Observations (working age): " _N

* Employed with wages
keep if employed == 1
di "Observations (employed): " _N

keep if wage_month != . & wage_month > 0
di "Observations (with wages): " _N

* Non-missing industry
keep if industry != .
di "Observations (with industry): " _N

* Save analysis sample
save "output/rlms_analysis_sample.dta", replace

* Summary statistics
di as text "=========================================="
di as text "Sample Summary"
di as text "=========================================="
tab year
tab industry if agri == 1 | food_industry == 1
sum wage_month ln_wage age female if year == 2013
sum wage_month ln_wage age female if year == 2023

********************************************************************************
* PART 6: Baseline Difference-in-Differences
********************************************************************************

di as text "=========================================="
di as text "PART 6: Baseline DiD"
di as text "=========================================="

use "output/rlms_analysis_sample.dta", clear

* Table 1: Simple DiD - Agriculture vs. Others
eststo clear

* (1) Basic DiD
eststo m1: reghdfe ln_wage agri_post agri post, ///
    absorb(year) cluster(region)

* (2) With individual FE
eststo m2: reghdfe ln_wage agri_post, ///
    absorb(idind year) cluster(region)

* (3) With controls
eststo m3: reghdfe ln_wage agri_post age age_sq i.educ_cat female, ///
    absorb(idind year) cluster(region)

* (4) Food industry
eststo m4: reghdfe ln_wage treated_post, ///
    absorb(idind year) cluster(region)

* Export table
esttab m1 m2 m3 m4 using "output/tables/table1_baseline_did.tex", ///
    replace booktabs label ///
    title("Effect of Food Embargo on Agricultural Wages") ///
    mtitles("OLS" "Ind FE" "Ind FE + Controls" "Agri + Food") ///
    keep(agri_post treated_post agri post) ///
    stats(N r2_a, labels("Observations" "Adj. R-squared")) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    se(3) b(3)

esttab m1 m2 m3 m4 using "output/tables/table1_baseline_did.csv", ///
    replace csv label

di "DiD coefficient (with Ind FE): "
estimates restore m2
di _b[agri_post]

********************************************************************************
* PART 7: Event Study
********************************************************************************

di as text "=========================================="
di as text "PART 7: Event Study"
di as text "=========================================="

* Event study regression
reghdfe ln_wage D_m4 D_m3 D_m2 D_p0 D_p1 D_p2 D_p3 D_p4 D_p5 D_p6 D_p7 D_p8 D_p9, ///
    absorb(idind year) cluster(region)

* Store estimates for plotting
matrix b = e(b)
matrix V = e(V)

* Create coefficient plot data
preserve
clear
set obs 13
gen event_time = _n - 5  // -4 to 9, skipping -1
replace event_time = event_time + 1 if event_time >= 0

gen coef = .
gen se = .

local i = 1
foreach t in m4 m3 m2 p0 p1 p2 p3 p4 p5 p6 p7 p8 p9 {
    replace coef = b[1, `i'] in `i'
    replace se = sqrt(V[`i', `i']) in `i'
    local i = `i' + 1
}

* Add reference period (t=-1)
set obs 14
replace event_time = -1 in 14
replace coef = 0 in 14
replace se = 0 in 14
sort event_time

* Confidence intervals
gen ci_lo = coef - 1.96*se
gen ci_hi = coef + 1.96*se

* Plot
twoway (rcap ci_lo ci_hi event_time, lcolor(navy)) ///
       (scatter coef event_time, mcolor(navy) msymbol(circle)) ///
       (line coef event_time, lcolor(navy) lpattern(solid)), ///
    xline(-0.5, lcolor(red) lpattern(dash)) ///
    yline(0, lcolor(gray) lpattern(solid)) ///
    xlabel(-4(1)9) ///
    ylabel(, format(%9.2f)) ///
    xtitle("Years Relative to 2014 Food Embargo") ///
    ytitle("Effect on Log Wages") ///
    title("Event Study: Agricultural Workers vs. Others") ///
    note("Reference period: 2013 (t=-1). 95% CIs shown. Clustered SEs at region level.") ///
    legend(off) ///
    scheme(s2color)
graph export "output/figures/event_study_main.png", replace width(1200)
graph export "output/figures/event_study_main.pdf", replace

restore

********************************************************************************
* PART 8: Regional Treatment Intensity
********************************************************************************

di as text "=========================================="
di as text "PART 8: Regional Treatment Intensity"
di as text "=========================================="

use "output/rlms_analysis_sample.dta", clear

* Keep only agricultural workers for intensity analysis
* (or use full sample with triple difference)

eststo clear

* (1) Continuous intensity measure (all workers)
eststo r1: reghdfe ln_wage intensity_post, ///
    absorb(idind year) cluster(region)

* (2) High vs. low treatment regions (all workers)
eststo r2: reghdfe ln_wage high_treat_post high_treatment post, ///
    absorb(idind year) cluster(region)

* (3) Agricultural workers only - by region intensity
preserve
keep if agri == 1
eststo r3: reghdfe ln_wage intensity_post, ///
    absorb(idind year) cluster(region)
restore

* (4) Triple difference: Agri × High-treatment region × Post
gen triple_did = agri * high_treatment * post
gen agri_high = agri * high_treatment
gen high_post = high_treatment * post

eststo r4: reghdfe ln_wage triple_did agri_post high_treat_post ///
    agri high_treatment post, ///
    absorb(idind year) cluster(region)

esttab r1 r2 r3 r4 using "output/tables/table2_regional_intensity.tex", ///
    replace booktabs label ///
    title("Regional Treatment Intensity") ///
    mtitles("Intensity" "High/Low" "Agri Only" "Triple DiD") ///
    keep(intensity_post high_treat_post triple_did) ///
    stats(N r2_a, labels("Observations" "Adj. R-squared")) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    se(3) b(3)

********************************************************************************
* PART 9: Heterogeneity Analysis
********************************************************************************

di as text "=========================================="
di as text "PART 9: Heterogeneity"
di as text "=========================================="

use "output/rlms_analysis_sample.dta", clear

eststo clear

* (1) By gender
eststo h1: reghdfe ln_wage c.agri_post##i.female, ///
    absorb(idind year) cluster(region)

* (2) By education
eststo h2: reghdfe ln_wage c.agri_post##i.educ_cat, ///
    absorb(idind year) cluster(region)

* (3) By firm size (if available)
gen large_firm = (firm_size >= 4) if firm_size != . & firm_size < 99999990
eststo h3: reghdfe ln_wage c.agri_post##i.large_firm if large_firm != ., ///
    absorb(idind year) cluster(region)

* (4) By age group
gen age_group = 1 if age < 30
replace age_group = 2 if age >= 30 & age < 50
replace age_group = 3 if age >= 50
eststo h4: reghdfe ln_wage c.agri_post##i.age_group, ///
    absorb(idind year) cluster(region)

esttab h1 h2 h3 h4 using "output/tables/table3_heterogeneity.tex", ///
    replace booktabs label ///
    title("Heterogeneous Effects") ///
    mtitles("Gender" "Education" "Firm Size" "Age") ///
    stats(N r2_a, labels("Observations" "Adj. R-squared")) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    se(3) b(3)

********************************************************************************
* PART 10: Robustness Checks
********************************************************************************

di as text "=========================================="
di as text "PART 10: Robustness"
di as text "=========================================="

use "output/rlms_analysis_sample.dta", clear

eststo clear

* (1) Hourly wages instead of monthly
eststo rob1: reghdfe ln_wage_hourly agri_post if ln_wage_hourly != ., ///
    absorb(idind year) cluster(region)

* (2) Levels instead of logs
eststo rob2: reghdfe wage_month agri_post, ///
    absorb(idind year) cluster(region)

* (3) Different control group (exclude potentially treated)
preserve
drop if industry == 14  // Drop trade/retail
eststo rob3: reghdfe ln_wage agri_post, ///
    absorb(idind year) cluster(region)
restore

* (4) Placebo: Treatment in 2012
gen placebo_post = (year >= 2012)
gen agri_placebo = agri * placebo_post
preserve
keep if year <= 2014
eststo rob4: reghdfe ln_wage agri_placebo, ///
    absorb(idind year) cluster(region)
restore

* (5) With sampling weights
eststo rob5: reghdfe ln_wage agri_post [pw=inwgt], ///
    absorb(idind year) cluster(region)

esttab rob1 rob2 rob3 rob4 rob5 using "output/tables/table4_robustness.tex", ///
    replace booktabs label ///
    title("Robustness Checks") ///
    mtitles("Hourly" "Levels" "Excl Trade" "Placebo 2012" "Weighted") ///
    keep(agri_post agri_placebo) ///
    stats(N r2_a, labels("Observations" "Adj. R-squared")) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    se(3) b(3)

********************************************************************************
* PART 10B: Additional Robustness Checks
********************************************************************************

di as text "=========================================="
di as text "PART 10B: Additional Robustness Checks"
di as text "=========================================="

use "output/rlms_analysis_sample.dta", clear

*------------------------------------------------------------------------------
* A. Alternative Control Groups
*------------------------------------------------------------------------------

di as text "--- A. Alternative Control Groups ---"

eststo clear

* (1) Baseline for comparison
eststo alt1: reghdfe ln_wage agri_post, ///
    absorb(idind year) cluster(region)

* (2) Control: Manufacturing only (industries 2-5)
preserve
keep if agri == 1 | inlist(industry, 2, 3, 4, 5)
eststo alt2: reghdfe ln_wage agri_post, ///
    absorb(idind year) cluster(region)
restore

* (3) Control: Services only (industries 9-14)
preserve
keep if agri == 1 | inlist(industry, 9, 10, 11, 12, 13, 14)
eststo alt3: reghdfe ln_wage agri_post, ///
    absorb(idind year) cluster(region)
restore

* (4) Control: Private sector only (exclude government/education)
preserve
drop if inlist(industry, 9, 10)  // Drop government and education
eststo alt4: reghdfe ln_wage agri_post, ///
    absorb(idind year) cluster(region)
restore

* (5) Control: Exclude all potentially affected sectors
* (Drop trade, food industry, transport which may have spillovers)
preserve
drop if inlist(industry, 1, 7, 14)
eststo alt5: reghdfe ln_wage agri_post, ///
    absorb(idind year) cluster(region)
restore

esttab alt1 alt2 alt3 alt4 alt5 using "output/tables/table5_alt_controls.tex", ///
    replace booktabs label ///
    title("Alternative Control Groups") ///
    mtitles("Baseline" "Manuf Only" "Services Only" "Private Only" "Excl Spillovers") ///
    keep(agri_post) ///
    stats(N r2_a, labels("Observations" "Adj. R-squared")) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    se(3) b(3)

esttab alt1 alt2 alt3 alt4 alt5 using "output/tables/table5_alt_controls.csv", ///
    replace csv label

*------------------------------------------------------------------------------
* B. Different Wage Measures
*------------------------------------------------------------------------------

di as text "--- B. Different Wage Measures ---"

eststo clear

* Create additional wage measures

* (1) Baseline: Log monthly wage
eststo wage1: reghdfe ln_wage agri_post, ///
    absorb(idind year) cluster(region)

* (2) Log hourly wage (already exists)
eststo wage2: reghdfe ln_wage_hourly agri_post if ln_wage_hourly != ., ///
    absorb(idind year) cluster(region)

* (3) Winsorized wages (trim top/bottom 1%)
preserve
egen wage_p1 = pctile(wage_month), p(1)
egen wage_p99 = pctile(wage_month), p(99)
gen wage_wins = wage_month
replace wage_wins = wage_p1 if wage_month < wage_p1
replace wage_wins = wage_p99 if wage_month > wage_p99
gen ln_wage_wins = ln(wage_wins)
eststo wage3: reghdfe ln_wage_wins agri_post, ///
    absorb(idind year) cluster(region)
restore

* (4) Winsorized by year (account for inflation)
preserve
bysort year: egen wage_p1_yr = pctile(wage_month), p(1)
bysort year: egen wage_p99_yr = pctile(wage_month), p(99)
gen wage_wins_yr = wage_month
replace wage_wins_yr = wage_p1_yr if wage_month < wage_p1_yr
replace wage_wins_yr = wage_p99_yr if wage_month > wage_p99_yr
gen ln_wage_wins_yr = ln(wage_wins_yr)
eststo wage4: reghdfe ln_wage_wins_yr agri_post, ///
    absorb(idind year) cluster(region)
restore

* (5) Real wages deflated to 2013 rubles (approximate CPI)
* Russia CPI index (2013=100): 2010:83, 2011:90, 2012:95, 2013:100,
* 2014:108, 2015:121, 2016:128, 2017:133, 2018:137, 2019:143,
* 2020:148, 2021:157, 2022:178, 2023:189
preserve
gen cpi = .
replace cpi = 83 if year == 2010
replace cpi = 90 if year == 2011
replace cpi = 95 if year == 2012
replace cpi = 100 if year == 2013
replace cpi = 108 if year == 2014
replace cpi = 121 if year == 2015
replace cpi = 128 if year == 2016
replace cpi = 133 if year == 2017
replace cpi = 137 if year == 2018
replace cpi = 143 if year == 2019
replace cpi = 148 if year == 2020
replace cpi = 157 if year == 2021
replace cpi = 178 if year == 2022
replace cpi = 189 if year == 2023
gen wage_real = wage_month * (100 / cpi)
gen ln_wage_real = ln(wage_real)
eststo wage5: reghdfe ln_wage_real agri_post, ///
    absorb(idind year) cluster(region)
restore

esttab wage1 wage2 wage3 wage4 wage5 using "output/tables/table6_wage_measures.tex", ///
    replace booktabs label ///
    title("Different Wage Measures") ///
    mtitles("Log Monthly" "Log Hourly" "Winsorized" "Wins by Year" "Real (2013)") ///
    keep(agri_post) ///
    stats(N r2_a, labels("Observations" "Adj. R-squared")) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    se(3) b(3)

esttab wage1 wage2 wage3 wage4 wage5 using "output/tables/table6_wage_measures.csv", ///
    replace csv label

*------------------------------------------------------------------------------
* C. Excluding 2022-2024 (Ukraine War Period)
*------------------------------------------------------------------------------

di as text "--- C. Excluding 2022-2024 ---"

* The Ukraine war (Feb 2022) introduced major economic disruptions:
* - New sanctions, supply chain shocks, mobilization
* - These could confound agricultural labor market effects

eststo clear

* (1) Baseline with full sample (2010-2023)
eststo excl1: reghdfe ln_wage agri_post, ///
    absorb(idind year) cluster(region)

* (2) Excluding 2022-2023
preserve
keep if year <= 2021
eststo excl2: reghdfe ln_wage agri_post, ///
    absorb(idind year) cluster(region)
restore

* (3) Excluding only 2022
preserve
keep if year != 2022
eststo excl3: reghdfe ln_wage agri_post, ///
    absorb(idind year) cluster(region)
restore

* (4) Pre-pandemic sample (2010-2019)
preserve
keep if year <= 2019
eststo excl4: reghdfe ln_wage agri_post, ///
    absorb(idind year) cluster(region)
restore

* (5) Original paper period (2010-2018)
preserve
keep if year <= 2018
eststo excl5: reghdfe ln_wage agri_post, ///
    absorb(idind year) cluster(region)
restore

esttab excl1 excl2 excl3 excl4 excl5 using "output/tables/table7_excl_years.tex", ///
    replace booktabs label ///
    title("Excluding Recent Years") ///
    mtitles("Full Sample" "Excl 2022-23" "Excl 2022" "Pre-COVID" "2010-2018") ///
    keep(agri_post) ///
    stats(N r2_a, labels("Observations" "Adj. R-squared")) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    se(3) b(3)

esttab excl1 excl2 excl3 excl4 excl5 using "output/tables/table7_excl_years.csv", ///
    replace csv label

* Event study excluding 2022-2024
preserve
keep if year <= 2021

reghdfe ln_wage D_m4 D_m3 D_m2 D_p0 D_p1 D_p2 D_p3 D_p4 D_p5 D_p6 D_p7, ///
    absorb(idind year) cluster(region)

* Store and plot
matrix b_excl = e(b)
matrix V_excl = e(V)

clear
set obs 11
gen event_time = _n - 5
replace event_time = event_time + 1 if event_time >= 0

gen coef = .
gen se = .

local i = 1
foreach t in m4 m3 m2 p0 p1 p2 p3 p4 p5 p6 p7 {
    replace coef = b_excl[1, `i'] in `i'
    replace se = sqrt(V_excl[`i', `i']) in `i'
    local i = `i' + 1
}

set obs 12
replace event_time = -1 in 12
replace coef = 0 in 12
replace se = 0 in 12
sort event_time

gen ci_lo = coef - 1.96*se
gen ci_hi = coef + 1.96*se

twoway (rcap ci_lo ci_hi event_time, lcolor(navy)) ///
       (scatter coef event_time, mcolor(navy) msymbol(circle)) ///
       (line coef event_time, lcolor(navy) lpattern(solid)), ///
    xline(-0.5, lcolor(red) lpattern(dash)) ///
    yline(0, lcolor(gray) lpattern(solid)) ///
    xlabel(-4(1)7) ///
    ylabel(, format(%9.2f)) ///
    xtitle("Years Relative to 2014 Food Embargo") ///
    ytitle("Effect on Log Wages") ///
    title("Event Study: Excluding 2022-2023 (War Period)") ///
    note("Reference period: 2013 (t=-1). 95% CIs shown. Sample: 2010-2021.") ///
    legend(off) ///
    scheme(s2color)
graph export "output/figures/event_study_excl_war.png", replace width(1200)
graph export "output/figures/event_study_excl_war.pdf", replace

restore

*------------------------------------------------------------------------------
* D. Placebo Tests with Other Sectors
*------------------------------------------------------------------------------

di as text "--- D. Placebo Tests with Other Sectors ---"

* If our identification is valid, using non-treated sectors as
* "fake treatment" should yield null effects

eststo clear

* (1) Baseline: Agriculture (true treatment)
eststo plac1: reghdfe ln_wage agri_post, ///
    absorb(idind year) cluster(region)

* (2) Placebo: Construction sector (industry == 6)
gen construction = (industry == 6)
gen constr_post = construction * post
eststo plac2: reghdfe ln_wage constr_post, ///
    absorb(idind year) cluster(region)

* (3) Placebo: Heavy industry (industry == 5)
gen heavy_ind = (industry == 5)
gen heavy_post = heavy_ind * post
eststo plac3: reghdfe ln_wage heavy_post, ///
    absorb(idind year) cluster(region)

* (4) Placebo: Transportation/Communication (industry == 7)
gen transport = (industry == 7)
gen transp_post = transport * post
eststo plac4: reghdfe ln_wage transp_post, ///
    absorb(idind year) cluster(region)

* (5) Placebo: Government sector (industry == 9)
gen government = (industry == 9)
gen gov_post = government * post
eststo plac5: reghdfe ln_wage gov_post, ///
    absorb(idind year) cluster(region)

* (6) Placebo: Education sector (industry == 10)
gen education = (industry == 10)
gen educ_post = education * post
eststo plac6: reghdfe ln_wage educ_post, ///
    absorb(idind year) cluster(region)

esttab plac1 plac2 plac3 plac4 plac5 plac6 using "output/tables/table8_placebo_sectors.tex", ///
    replace booktabs label ///
    title("Placebo Tests: Other Sectors as Fake Treatment") ///
    mtitles("Agriculture" "Construction" "Heavy Ind" "Transport" "Government" "Education") ///
    keep(agri_post constr_post heavy_post transp_post gov_post educ_post) ///
    stats(N r2_a, labels("Observations" "Adj. R-squared")) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    se(3) b(3)

esttab plac1 plac2 plac3 plac4 plac5 plac6 using "output/tables/table8_placebo_sectors.csv", ///
    replace csv label

* Placebo with pre-treatment timing (using 2012 as fake treatment year)
* Already exists in Part 10 but add more

di as text "--- Additional Placebo Timing Tests ---"

eststo clear

* Multiple fake treatment years
foreach yr in 2011 2012 2013 {
    preserve
    keep if year <= 2014
    gen placebo_`yr' = (year >= `yr')
    gen agri_plac_`yr' = agri * placebo_`yr'
    eststo plac_`yr': reghdfe ln_wage agri_plac_`yr', ///
        absorb(idind year) cluster(region)
    restore
}

* True treatment for comparison
preserve
keep if year <= 2018
eststo plac_2014: reghdfe ln_wage agri_post, ///
    absorb(idind year) cluster(region)
restore

esttab plac_2011 plac_2012 plac_2013 plac_2014 using "output/tables/table9_placebo_timing.tex", ///
    replace booktabs label ///
    title("Placebo Tests: Alternative Treatment Timing") ///
    mtitles("Fake 2011" "Fake 2012" "Fake 2013" "True 2014") ///
    keep(agri_plac_2011 agri_plac_2012 agri_plac_2013 agri_post) ///
    stats(N r2_a, labels("Observations" "Adj. R-squared")) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    se(3) b(3)

esttab plac_2011 plac_2012 plac_2013 plac_2014 using "output/tables/table9_placebo_timing.csv", ///
    replace csv label

di as text "Additional robustness checks complete."
di as text "Tables saved: table5-table9"

********************************************************************************
* PART 11: Summary Statistics Table
********************************************************************************

di as text "=========================================="
di as text "PART 11: Summary Statistics"
di as text "=========================================="

use "output/rlms_analysis_sample.dta", clear

* Overall summary
eststo summ_all: estpost summarize ln_wage wage_month hours_month age female ///
    agri food_industry if year == 2013

* By treatment status
eststo summ_agri: estpost summarize ln_wage wage_month hours_month age female ///
    if agri == 1 & year == 2013

eststo summ_other: estpost summarize ln_wage wage_month hours_month age female ///
    if agri == 0 & year == 2013

esttab summ_all summ_agri summ_other using "output/tables/table0_summary_stats.tex", ///
    replace booktabs ///
    title("Summary Statistics (2013)") ///
    mtitles("All Workers" "Agriculture" "Other Sectors") ///
    cells("mean(fmt(2)) sd(fmt(2)) count(fmt(0))") ///
    label

********************************************************************************
* PART 12: Additional Figures
********************************************************************************

di as text "=========================================="
di as text "PART 12: Additional Figures"
di as text "=========================================="

use "output/rlms_analysis_sample.dta", clear

* Figure: Wage trends by sector
preserve
collapse (mean) wage_month ln_wage, by(year agri)
reshape wide wage_month ln_wage, i(year) j(agri)

twoway (line ln_wage0 year, lcolor(gray) lpattern(solid)) ///
       (line ln_wage1 year, lcolor(navy) lpattern(solid)), ///
    xline(2014, lcolor(red) lpattern(dash)) ///
    xlabel(2010(2)2023) ///
    ylabel(, format(%9.2f)) ///
    xtitle("Year") ///
    ytitle("Mean Log Monthly Wage") ///
    title("Wage Trends: Agriculture vs. Other Sectors") ///
    legend(order(1 "Other sectors" 2 "Agriculture") position(6) rows(1)) ///
    note("Vertical line: August 2014 food import ban") ///
    scheme(s2color)
graph export "output/figures/wage_trends.png", replace width(1200)
graph export "output/figures/wage_trends.pdf", replace
restore

* Figure: Employment share in agriculture
preserve
gen n = 1
collapse (sum) n, by(year agri)
reshape wide n, i(year) j(agri)
gen agri_share = n1 / (n0 + n1) * 100

twoway (line agri_share year, lcolor(navy) lpattern(solid)), ///
    xline(2014, lcolor(red) lpattern(dash)) ///
    xlabel(2010(2)2023) ///
    ylabel(, format(%9.1f)) ///
    xtitle("Year") ///
    ytitle("Share of Employment in Agriculture (%)") ///
    title("Agricultural Employment Share Over Time") ///
    note("Vertical line: August 2014 food import ban") ///
    scheme(s2color)
graph export "output/figures/agri_employment_share.png", replace width(1200)
restore

********************************************************************************
* PART 13: Intent-to-Treat Analysis (Pre-2014 Industry Assignment)
********************************************************************************

di as text "=========================================="
di as text "PART 13: Intent-to-Treat (Pre-2014 Industry)"
di as text "=========================================="

* Address selection concerns: workers may switch INTO agriculture post-ban
* attracted by rising wages. Use initial industry assignment instead.

use "output/rlms_analysis_sample.dta", clear

* Create initial (pre-2014) industry assignment
* For each individual, get their industry in their first pre-2014 observation
preserve
keep if year < 2014 & industry != .
bysort idind (year): gen first_obs = (_n == 1)
keep if first_obs == 1
keep idind industry
rename industry initial_industry
tempfile initial_ind
save `initial_ind'
restore

* Merge back
merge m:1 idind using `initial_ind', keep(1 3)
gen matched_initial = (_merge == 3)
drop _merge

* Intent-to-treat: based on initial industry
gen agri_initial = (initial_industry == 8)
gen agri_initial_post = agri_initial * post
label var agri_initial "Agriculture (initial assignment)"
label var agri_initial_post "Agri (initial) × Post"

eststo clear

* (1) Baseline: Current industry (for comparison)
eststo itt1: reghdfe ln_wage agri_post, ///
    absorb(idind year) cluster(region)

* (2) Intent-to-treat: Initial industry
eststo itt2: reghdfe ln_wage agri_initial_post if matched_initial == 1, ///
    absorb(idind year) cluster(region)

* (3) ITT with controls
eststo itt3: reghdfe ln_wage agri_initial_post age age_sq i.educ_cat female ///
    if matched_initial == 1, ///
    absorb(idind year) cluster(region)

* (4) Primary sample: 2010-2019 (pre-COVID/war)
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
* PART 14: Stayer Sample Analysis
********************************************************************************

di as text "=========================================="
di as text "PART 14: Stayer Sample"
di as text "=========================================="

* Analyze workers who stayed in agriculture throughout the sample period
* This addresses selection from industry switching

use "output/rlms_analysis_sample.dta", clear

* Identify "stayers": workers observed both pre and post, same industry
* First, check if individual ever worked in agriculture pre-2014
bysort idind: egen ever_agri_pre = max(agri * (year < 2014))
* Check if individual ever worked in agriculture post-2014
bysort idind: egen ever_agri_post = max(agri * (year >= 2014))
* Check if individual appears both pre and post
bysort idind: egen has_pre = max(year < 2014)
bysort idind: egen has_post = max(year >= 2014)
gen balanced = (has_pre == 1 & has_post == 1)

* Stayer in agriculture: in agri both pre and post
gen agri_stayer = (ever_agri_pre == 1 & ever_agri_post == 1 & balanced == 1)

* Stayer in non-agriculture
gen nonagri_stayer = (ever_agri_pre == 0 & ever_agri_post == 0 & balanced == 1)

* Switchers
gen switcher_into_agri = (ever_agri_pre == 0 & ever_agri_post == 1 & balanced == 1)
gen switcher_out_agri = (ever_agri_pre == 1 & ever_agri_post == 0 & balanced == 1)

* Report sample sizes
di "Sample composition:"
tab agri_stayer if year == 2013
tab nonagri_stayer if year == 2013
tab switcher_into_agri if year == 2013
tab switcher_out_agri if year == 2013

eststo clear

* (1) Full sample
eststo stay1: reghdfe ln_wage agri_post, ///
    absorb(idind year) cluster(region)

* (2) Stayers only (agri stayers + non-agri stayers)
eststo stay2: reghdfe ln_wage agri_post if agri_stayer == 1 | nonagri_stayer == 1, ///
    absorb(idind year) cluster(region)

* (3) Agricultural stayers only (within agri variation)
preserve
keep if agri_stayer == 1
eststo stay3: reghdfe ln_wage post, ///
    absorb(idind year) cluster(region)
restore

* (4) Balanced panel requirement
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

* Save for later use
save "output/rlms_analysis_extended.dta", replace

********************************************************************************
* PART 15: Extensive Margin Analysis (Employment Effects)
********************************************************************************

di as text "=========================================="
di as text "PART 15: Extensive Margin (Employment)"
di as text "=========================================="

* Reload full sample including non-employed
use "IND/RLMS_IND_1994_2023_eng_dta.dta", clear
keep if year >= 2010 & year <= 2023

* Keep key variables
keep idind id_h year region psu age h5 j1 j4_1 educ inwgt

* Clean
replace age = . if age >= 99999990 | age < 15 | age > 75
gen female = (h5 == 2)
rename j1 employed
replace employed = 0 if employed != 1
rename j4_1 industry
replace industry = . if industry >= 99999990

* Working age
keep if age >= 18 & age <= 65

* Treatment variables
gen post = (year >= 2014)
gen agri = (industry == 8) if industry != .

* Employment in agriculture
gen emp_agri = (employed == 1 & agri == 1)
replace emp_agri = 0 if emp_agri == .

* Get initial characteristics (pre-2014)
preserve
keep if year < 2014 & industry != .
bysort idind (year): gen first_obs = (_n == 1)
keep if first_obs == 1
keep idind industry region
rename industry initial_industry
rename region initial_region
tempfile initial_chars
save `initial_chars'
restore

merge m:1 idind using `initial_chars', keep(1 3)
gen matched = (_merge == 3)
drop _merge

gen agri_initial = (initial_industry == 8) if matched == 1
replace agri_initial = 0 if agri_initial == .

eststo clear

* (1) Probability of being employed in agriculture
eststo ext1: reghdfe emp_agri post, ///
    absorb(idind year) cluster(region)

* (2) Probability of switching INTO agriculture (initially non-agri)
preserve
keep if matched == 1 & agri_initial == 0
eststo ext2: reghdfe emp_agri post, ///
    absorb(idind year) cluster(region)
restore

* (3) Probability of staying IN agriculture (initially agri)
preserve
keep if matched == 1 & agri_initial == 1
eststo ext3: reghdfe emp_agri post, ///
    absorb(idind year) cluster(region)
restore

* (4) Overall employment probability
eststo ext4: reghdfe employed post, ///
    absorb(idind year) cluster(region)

esttab ext1 ext2 ext3 ext4 using "output/tables/table12_extensive.tex", ///
    replace booktabs label ///
    title("Extensive Margin: Employment Effects") ///
    mtitles("P(Emp in Agri)" "P(Switch to Agri)" "P(Stay in Agri)" "P(Employed)") ///
    keep(post) ///
    stats(N r2_a, labels("Observations" "Adj. R-squared")) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    se(3) b(3)

esttab ext1 ext2 ext3 ext4 using "output/tables/table12_extensive.csv", ///
    replace csv label

* Figure: Switching rates over time
preserve
keep if matched == 1
gen switch_into = (agri_initial == 0 & emp_agri == 1)
gen switch_out = (agri_initial == 1 & emp_agri == 0 & employed == 1)
collapse (mean) switch_into switch_out, by(year)
replace switch_into = switch_into * 100
replace switch_out = switch_out * 100

twoway (line switch_into year, lcolor(navy) lpattern(solid)) ///
       (line switch_out year, lcolor(maroon) lpattern(dash)), ///
    xline(2014, lcolor(red) lpattern(dash)) ///
    xlabel(2010(2)2023) ///
    ylabel(0(1)5, format(%9.1f)) ///
    xtitle("Year") ///
    ytitle("Switching Rate (%)") ///
    title("Industry Switching: Into and Out of Agriculture") ///
    legend(order(1 "Switch into agriculture" 2 "Switch out of agriculture") ///
        position(6) rows(1)) ///
    note("Sample: Workers observed pre-2014 with known initial industry.") ///
    scheme(s2color)
graph export "output/figures/industry_switching.png", replace width(1200)
graph export "output/figures/industry_switching.pdf", replace
restore

********************************************************************************
* PART 16: Wage Decomposition (Hours vs. Hourly Wage)
********************************************************************************

di as text "=========================================="
di as text "PART 16: Wage Decomposition"
di as text "=========================================="

use "output/rlms_analysis_sample.dta", clear

* Create decomposition variables
* Total earnings = Hourly wage × Hours
* ln(earnings) = ln(hourly) + ln(hours)

gen ln_hours = ln(hours_month) if hours_month > 0 & hours_month < .

eststo clear

* (1) Log monthly earnings (total)
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

* Note: Effect on ln(earnings) ≈ Effect on ln(hourly) + Effect on ln(hours)

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
* PART 17: Synthetic Control Analysis
********************************************************************************

di as text "=========================================="
di as text "PART 17: Synthetic Control"
di as text "=========================================="

* Construct a synthetic "agriculture" from weighted control sectors
* Compare actual agriculture wages to synthetic control

use "output/rlms_analysis_sample.dta", clear

* Collapse to sector-year level
preserve
collapse (mean) ln_wage wage_month hours_month [pw=inwgt], by(year industry)
drop if industry == .

* Reshape to wide format
reshape wide ln_wage wage_month hours_month, i(year) j(industry)

* Agriculture is industry 8
* Potential donors: 2 (civil machine), 5 (heavy ind), 6 (construction),
* 7 (transport), 9 (gov), 10 (education), 14 (trade)

* Simple synthetic control: match pre-trends
* Use 2010-2013 to find weights that best match agriculture

* Pre-period means
foreach var in ln_wage {
    forval ind = 1/15 {
        capture sum `var'`ind' if year <= 2013
        if _rc == 0 {
            local pre_`var'_`ind' = r(mean)
        }
        else {
            local pre_`var'_`ind' = .
        }
    }
}

* Agriculture pre-mean
local agri_pre = `pre_ln_wage_8'
di "Agriculture pre-period mean: `agri_pre'"

* Simple weighted average using manufacturing + services
* Weight: inverse distance from agri pre-mean
gen synth_ln_wage = .

* For simplicity, use average of comparable sectors weighted equally
* Manufacturing: 2, 5; Services: 9, 10, 14
* Adjust weights to match pre-period

egen synth_simple = rowmean(ln_wage2 ln_wage5 ln_wage6 ln_wage7 ln_wage9 ln_wage10 ln_wage14)

* Calculate pre-period difference
sum ln_wage8 if year <= 2013
local agri_pre = r(mean)
sum synth_simple if year <= 2013
local synth_pre = r(mean)
local adjust = `agri_pre' - `synth_pre'

* Adjusted synthetic
gen synth_adjusted = synth_simple + `adjust'

* Plot
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
    note("Synthetic control: average of manufacturing, construction, transport, government, education, trade." ///
         "Adjusted to match agriculture pre-2014.") ///
    scheme(s2color)
graph export "output/figures/synthetic_control.png", replace width(1200)
graph export "output/figures/synthetic_control.pdf", replace

* Calculate treatment effect (gap)
gen gap = ln_wage8 - synth_adjusted
list year ln_wage8 synth_adjusted gap

* Export gap
export delimited year ln_wage8 synth_adjusted gap using "output/tables/synthetic_control_gap.csv", replace

restore

********************************************************************************
* PART 18: Pre vs. Post 2022 Structural Break Test
********************************************************************************

di as text "=========================================="
di as text "PART 18: Pre/Post 2022 Structural Break"
di as text "=========================================="

use "output/rlms_analysis_sample.dta", clear

* Test whether treatment effects differ before vs. after 2022

* Create period indicators
gen period = 1 if year >= 2010 & year <= 2013  // Pre-treatment
replace period = 2 if year >= 2014 & year <= 2019  // Post-treatment, pre-COVID
replace period = 3 if year >= 2020 & year <= 2021  // COVID period
replace period = 4 if year >= 2022  // War period

* Interaction with periods
gen agri_p2 = agri * (period == 2)
gen agri_p3 = agri * (period == 3)
gen agri_p4 = agri * (period == 4)

eststo clear

* (1) Single post-treatment effect
eststo brk1: reghdfe ln_wage agri_post, ///
    absorb(idind year) cluster(region)

* (2) Separate effects by period
eststo brk2: reghdfe ln_wage agri_p2 agri_p3 agri_p4, ///
    absorb(idind year) cluster(region)

* (3) Test: effect different 2014-2019 vs 2022+?
* F-test of agri_p2 == agri_p4
reghdfe ln_wage agri_p2 agri_p3 agri_p4, absorb(idind year) cluster(region)
test agri_p2 == agri_p4
local pval_diff = r(p)

* (4) Primary specification: 2010-2019 only
preserve
keep if year <= 2019
eststo brk3: reghdfe ln_wage agri_post, ///
    absorb(idind year) cluster(region)
restore

* (5) Extended period: 2020-2023 only
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
    se(3) b(3) ///
    addnotes("P-value for H0: Effect(2014-19) = Effect(2022+): `pval_diff'")

esttab brk1 brk2 brk3 brk4 using "output/tables/table14_structural_break.csv", ///
    replace csv label

di "P-value for structural break test (2014-19 vs 2022+): `pval_diff'"

********************************************************************************
* PART 19: Sample Size and Power Diagnostics
********************************************************************************

di as text "=========================================="
di as text "PART 19: Sample Size Diagnostics"
di as text "=========================================="

use "output/rlms_analysis_sample.dta", clear

* Report effective sample sizes
di "=== SAMPLE SIZE DIAGNOSTICS ==="

* By year and treatment
tab year agri

* Agricultural workers by year
preserve
keep if agri == 1
tab year
restore

* Unique individuals
distinct idind
distinct idind if agri == 1

* By detailed sub-sector (if available - using enterprise type as proxy)
tab enterprise_type if agri == 1 & year == 2013, missing

* Regional coverage
tab region if agri == 1 & year == 2013

* Effective sample for key specifications
di "=== EFFECTIVE SAMPLES ==="
count if ln_wage != . & agri != .
count if ln_wage != . & agri == 1
count if ln_wage_hourly != . & agri == 1

* Export summary
preserve
collapse (count) n_obs = ln_wage (sum) n_agri = agri, by(year)
export delimited using "output/tables/sample_sizes_by_year.csv", replace
restore

********************************************************************************
* CLOSE LOG
********************************************************************************

di as text "=========================================="
di as text "Analysis Complete!"
di as text "=========================================="
di as text "Output saved to: output/"
di as text "  - Tables: output/tables/"
di as text "  - Figures: output/figures/"
di as text "=========================================="
di as text ""
di as text "NEW TABLES (addressing referee comments):"
di as text "  - table10_itt.tex: Intent-to-treat (pre-2014 industry)"
di as text "  - table11_stayers.tex: Stayer sample analysis"
di as text "  - table12_extensive.tex: Extensive margin (employment)"
di as text "  - table13_decomposition.tex: Wage decomposition"
di as text "  - table14_structural_break.tex: Pre/post 2022 analysis"
di as text ""
di as text "NEW FIGURES:"
di as text "  - industry_switching.png: Switching rates"
di as text "  - event_study_hours.png: Hours event study"
di as text "  - synthetic_control.png: Synthetic control comparison"
di as text "=========================================="

log close

********************************************************************************
* END OF DO-FILE
********************************************************************************
