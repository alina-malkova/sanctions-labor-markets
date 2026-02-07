********************************************************************************
* Employment Collapse Investigation
* Investigate the sharp drop in agricultural workers 2013-2014
********************************************************************************

clear all
set more off
cap log close
log using "output/analysis_employment_collapse_log.txt", replace text

di "======================================================================"
di "EMPLOYMENT COLLAPSE INVESTIGATION"
di "======================================================================"

use "output/rlms_analysis_sample.dta", clear
keep if year >= 2010 & year <= 2019

********************************************************************************
* PART 1: Document the Collapse
********************************************************************************

di _n "=== PART 1: DOCUMENT THE COLLAPSE ==="

* Count agricultural workers by year
tab year agri, row

* Summarize
preserve
collapse (sum) n_agri = agri (count) n_total = agri, by(year)
gen pct_agri = 100 * n_agri / n_total
list year n_agri n_total pct_agri
di _n "Change 2013-2014:"
local n_2013 = n_agri[4]
local n_2014 = n_agri[5]
di "  2013: " `n_2013'
di "  2014: " `n_2014'
di "  Change: " `n_2014' - `n_2013' " (" %5.1f 100*(`n_2014'-`n_2013')/`n_2013' "%)"
restore

********************************************************************************
* PART 2: Panel vs Cross-Section - Same Individuals?
********************************************************************************

di ""
di "======================================================================"
di "PART 2: PANEL TRACKING - ARE THESE THE SAME PEOPLE?"
di "======================================================================"

* Create indicator for being in sample each year
gen in_2013 = (year == 2013)
gen in_2014 = (year == 2014)

* For each individual, check if they appear in both years
bys idind: egen ever_2013 = max(in_2013)
bys idind: egen ever_2014 = max(in_2014)

* Agricultural workers in 2013
gen agri_2013 = (year == 2013 & agri == 1)
bys idind: egen was_agri_2013 = max(agri_2013)

* Agricultural workers in 2014
gen agri_2014 = (year == 2014 & agri == 1)
bys idind: egen was_agri_2014 = max(agri_2014)

* Count unique individuals
preserve
keep idind was_agri_2013 was_agri_2014 ever_2013 ever_2014
duplicates drop

di _n "=== Individual-Level Tracking ==="

* How many 2013 agri workers appear in 2014?
count if was_agri_2013 == 1
local n_agri_2013 = r(N)
di "Individuals who were agri workers in 2013: " `n_agri_2013'

count if was_agri_2013 == 1 & ever_2014 == 1
local n_agri_2013_in_2014 = r(N)
di "  ...who appear in 2014 sample: " `n_agri_2013_in_2014' " (" %5.1f 100*`n_agri_2013_in_2014'/`n_agri_2013' "%)"

count if was_agri_2013 == 1 & was_agri_2014 == 1
local n_stayed_agri = r(N)
di "  ...who are still in agriculture: " `n_stayed_agri' " (" %5.1f 100*`n_stayed_agri'/`n_agri_2013' "%)"

count if was_agri_2013 == 1 & ever_2014 == 1 & was_agri_2014 == 0
local n_left_agri = r(N)
di "  ...who left agriculture: " `n_left_agri' " (" %5.1f 100*`n_left_agri'/`n_agri_2013' "%)"

count if was_agri_2013 == 1 & ever_2014 == 0
local n_attrited = r(N)
di "  ...who left the sample entirely: " `n_attrited' " (" %5.1f 100*`n_attrited'/`n_agri_2013' "%)"

restore

********************************************************************************
* PART 3: Compare Attrition Rates - Agri vs Non-Agri
********************************************************************************

di ""
di "======================================================================"
di "PART 3: DIFFERENTIAL ATTRITION?"
di "======================================================================"

preserve
* Keep 2013 observations only
keep if year == 2013

* Merge to see if they appear in 2014
rename ln_wage ln_wage_2013
rename hours_month hours_2013
keep idind agri ln_wage_2013 hours_2013 age female

tempfile sample_2013
save `sample_2013'

restore
preserve
keep if year == 2014
keep idind
gen in_2014_sample = 1
tempfile sample_2014
save `sample_2014'

use `sample_2013', clear
merge 1:1 idind using `sample_2014', keep(1 3)
gen attrited = (_merge == 1)
drop _merge

di _n "=== Attrition Rates by Sector (2013 → 2014) ==="
tab agri attrited, row

* Test for differential attrition
di _n "=== Test: Is Attrition Different for Agri Workers? ==="
reg attrited agri, robust
di "Coefficient on agri: " _b[agri]
di "SE: " _se[agri]
di "p-value: " 2*ttail(e(df_r), abs(_b[agri]/_se[agri]))

* Attrition by characteristics
di _n "=== Attrition by Characteristics (Agri Workers Only) ==="
reg attrited ln_wage_2013 age female if agri == 1, robust
restore

********************************************************************************
* PART 4: Where Did They Go? Sector Transitions
********************************************************************************

di ""
di "======================================================================"
di "PART 4: SECTOR TRANSITIONS"
di "======================================================================"

preserve
* Keep 2013-2014 pairs
keep if year == 2013 | year == 2014

* Reshape to wide
keep idind year agri industry ln_wage
reshape wide agri industry ln_wage, i(idind) j(year)

* Keep only those in both years
keep if agri2013 != . & agri2014 != .

di _n "=== Transition Matrix (2013 → 2014) ==="
tab agri2013 agri2014, row

* Where did agri workers go?
di _n "=== Where Did 2013 Agri Workers Go in 2014? ==="
tab industry2014 if agri2013 == 1

* Where did 2014 agri workers come from?
di _n "=== Where Did 2014 Agri Workers Come From? ==="
tab industry2013 if agri2014 == 1

restore

********************************************************************************
* PART 5: Check for Survey Design Changes
********************************************************************************

di ""
di "======================================================================"
di "PART 5: SURVEY DESIGN - NEW ENTRANTS VS PANEL"
di "======================================================================"

* Check if there are new individuals entering in 2014
preserve
bys idind: egen first_year = min(year)
bys idind: egen last_year = max(year)

* New entrants in each year
gen new_entrant = (year == first_year)
tab year new_entrant if agri == 1, row

di _n "=== Panel Tenure of Agri Workers ==="
gen panel_years = last_year - first_year + 1
tab panel_years if agri == 1 & year == 2013
tab panel_years if agri == 1 & year == 2014

restore

********************************************************************************
* PART 6: Compare 2013 vs 2014 Agri Worker Characteristics
********************************************************************************

di ""
di "======================================================================"
di "PART 6: COMPOSITION CHANGES"
di "======================================================================"

di _n "=== 2013 Agricultural Workers ==="
sum age female ln_wage hours_month if agri == 1 & year == 2013

di _n "=== 2014 Agricultural Workers ==="
sum age female ln_wage hours_month if agri == 1 & year == 2014

* T-test for differences
di _n "=== T-Tests for Composition Changes ==="
foreach var in age female ln_wage hours_month {
    di _n "Variable: `var'"
    ttest `var' if agri == 1, by(year == 2014)
}

********************************************************************************
* PART 7: Check All Years for Similar Patterns
********************************************************************************

di ""
di "======================================================================"
di "PART 7: YEAR-TO-YEAR CHANGES (ALL YEARS)"
di "======================================================================"

* Calculate year-to-year changes for all years
preserve
collapse (sum) n_agri = agri, by(year)
gen pct_change = 100 * (n_agri - n_agri[_n-1]) / n_agri[_n-1]
list year n_agri pct_change
restore

* Non-agri for comparison
preserve
gen non_agri = 1 - agri
collapse (sum) n_nonagri = non_agri, by(year)
gen pct_change = 100 * (n_nonagri - n_nonagri[_n-1]) / n_nonagri[_n-1]
di _n "=== Non-Agricultural Workers Year-to-Year Changes ==="
list year n_nonagri pct_change
restore

********************************************************************************
* PART 8: Real Employment or Sample Issue?
********************************************************************************

di ""
di "======================================================================"
di "PART 8: DIAGNOSIS"
di "======================================================================"

* Key diagnostic: Within the balanced panel, what happens?
preserve
* Create balanced panel of individuals present in both 2013 and 2014
keep if year == 2013 | year == 2014
bys idind: gen n_years = _N
keep if n_years == 2

di _n "=== Balanced Panel (Present in Both 2013 and 2014) ==="
tab year agri, row

* Employment change within balanced panel
collapse (sum) n_agri = agri (count) n_total = agri, by(year)
di _n "Balanced Panel Counts:"
list
local n_2013 = n_agri[1]
local n_2014 = n_agri[2]
di "Change in agri within balanced panel: " `n_2014' - `n_2013' " (" %5.1f 100*(`n_2014'-`n_2013')/`n_2013' "%)"
restore

********************************************************************************
* PART 9: Summary Statistics
********************************************************************************

di ""
di "======================================================================"
di "SUMMARY"
di "======================================================================"

di _n "Key findings to investigate:"
di "1. Total agri workers: 2013 vs 2014"
di "2. Attrition rate: agri vs non-agri"
di "3. Sector switching: agri workers who left agriculture"
di "4. New entrants: new panel members in 2014"
di "5. Balanced panel: change within consistent sample"

di _n "INTERPRETATION:"
di "If the decline is mostly attrition → sample composition issue"
di "If the decline is mostly sector switching → real employment change"
di "If new entrants are different → panel refresh effect"

log close
