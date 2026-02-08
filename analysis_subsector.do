********************************************************************************
* Sub-Sector Heterogeneity Analysis
* Despite power limitations, explore heterogeneity with explicit caveats
********************************************************************************

clear all
set more off
cap log close
log using "output/analysis_subsector_log.txt", replace text

di "======================================================================"
di "SUB-SECTOR HETEROGENEITY ANALYSIS"
di "======================================================================"

use "output/rlms_analysis_sample.dta", clear
keep if year >= 2010 & year <= 2019

********************************************************************************
* PART 1: Explore Available Sub-Sector Indicators
********************************************************************************

di _n "=== PART 1: AVAILABLE SUB-SECTOR INDICATORS ==="

* Check occupation codes for agricultural workers
di _n "=== Occupation Distribution (Agri Workers Only) ==="
tab occup if agri == 1

* Occupation categories based on value labels
* Looking at the tab output:
* - "Skilled agricultural, forestry and fish" = skilled field workers
* - "Plant and machine operators" = tractor/equipment operators
* - "Elementary occupations" = manual laborers
* - Others = managers, professionals, clerks, etc.

* Decode occupation labels to identify categories
decode occup, gen(occup_str)

* Create occupation-based categories
gen skilled_field = regexm(occup_str, "agricultural") if agri == 1
gen machine_operators = regexm(occup_str, "machine|Plant") if agri == 1
gen elementary = regexm(occup_str, "Elementary") if agri == 1
gen managers_prof = regexm(occup_str, "Manager|Professional|Technician") if agri == 1

di _n "=== Occupation Categories in Agriculture ==="
tab skilled_field if agri == 1
tab machine_operators if agri == 1
tab elementary if agri == 1
tab managers_prof if agri == 1

* For sub-sector proxy:
* Machine operators likely work in mechanized agriculture (grains, large farms)
* Elementary occupations may be more manual/livestock-related
* But this is imperfect

gen skilled_agri = skilled_field if agri == 1
gen unskilled_agri = elementary if agri == 1
gen other_agri = (skilled_field == 0 & elementary == 0) if agri == 1

di _n "=== Skill Distribution in Agriculture ==="
tab skilled_agri if agri == 1
tab unskilled_agri if agri == 1

********************************************************************************
* PART 2: Create Livestock vs Crop Proxy
********************************************************************************

di ""
di "======================================================================"
di "PART 2: LIVESTOCK VS CROP PROXY"
di "======================================================================"

* ISCO 6 detailed codes:
* 61 = Market-oriented skilled agricultural workers (crops)
* 62 = Market-oriented skilled forestry, fishery and hunting workers
* 63 = Subsistence farmers, fishers, hunters

* NOTE: Numeric ISCO codes are not available (occupation stored as labels)
* So we cannot do detailed sub-occupation analysis
* Instead, use the occupation category proxies created above

di _n "Sample sizes by occupation type in agriculture:"
count if agri == 1 & skilled_agri == 1
count if agri == 1 & unskilled_agri == 1
count if agri == 1 & other_agri == 1
count if agri == 1 & machine_operators == 1

********************************************************************************
* PART 3: Regional Specialization Proxy
********************************************************************************

di ""
di "======================================================================"
di "PART 3: REGIONAL SPECIALIZATION PROXY"
di "======================================================================"

* Use RFSD data on regional agricultural composition
* Merge treatment intensity which includes livestock share

cap drop _merge
cap merge m:1 region using "output/treatment_intensity_region.dta", keep(1 3) nogen

* Check if we have livestock indicator
cap confirm variable livestock_share
if _rc == 0 {
    di "Livestock share variable available"
    sum livestock_share
    gen high_livestock = (livestock_share > 0.5) if livestock_share != .
}
else {
    di "Livestock share not available - creating proxy from regional names"
    * Southern regions = more livestock/meat
    * Central regions = more crops/dairy
    gen high_livestock = 0
    * Krasnodar, Stavropol, Rostov = livestock regions
    replace high_livestock = 1 if inlist(region, 9129, 52, 137)
}

tab high_livestock if agri == 1

********************************************************************************
* PART 4: Sub-Sector Effects (Underpowered but Informative)
********************************************************************************

di ""
di "======================================================================"
di "PART 4: SUB-SECTOR EFFECTS (WITH POWER CAVEATS)"
di "======================================================================"

cap drop post agri_post
gen post = (year >= 2014)
gen agri_post = agri * post

* 4A: Skilled vs Unskilled Agricultural Workers
di _n "=== 4A: Skilled vs Unskilled Agricultural Workers ==="

* Skilled agricultural workers (ISCO 6)
gen skilled_post = skilled_agri * post
count if skilled_agri == 1
local n_skilled = r(N)

quietly reghdfe ln_wage agri_post skilled_post if agri == 1 | agri == 0, absorb(idind year) cluster(region)
di "Skilled agri interaction: " %7.4f _b[skilled_post] " (SE: " %6.4f _se[skilled_post] ")"
di "  N skilled agri workers: `n_skilled'"
di "  MDE at 80% power: ~" %5.1f 0.28 * 0.65 / sqrt(`n_skilled'/10) * 100 "%"

* Unskilled (ISCO 9)
gen unskilled_post = unskilled_agri * post
count if unskilled_agri == 1
local n_unskilled = r(N)

quietly reghdfe ln_wage agri_post unskilled_post if agri == 1 | agri == 0, absorb(idind year) cluster(region)
di "Unskilled agri interaction: " %7.4f _b[unskilled_post] " (SE: " %6.4f _se[unskilled_post] ")"
di "  N unskilled agri workers: `n_unskilled'"

* 4B: Effects by Occupation Type (Separate Regressions)
di _n "=== 4B: Separate Regressions by Occupation Type ==="

* All agri (baseline)
quietly reghdfe ln_wage agri_post, absorb(idind year) cluster(region)
di "All agriculture: " %7.4f _b[agri_post] " (SE: " %6.4f _se[agri_post] ")"

* Skilled agri only vs non-agri
preserve
keep if skilled_agri == 1 | agri == 0
gen treat_post = skilled_agri * post
quietly reghdfe ln_wage treat_post, absorb(idind year) cluster(region)
di "Skilled agri only: " %7.4f _b[treat_post] " (SE: " %6.4f _se[treat_post] ")"
restore

* Unskilled agri only vs non-agri
preserve
keep if unskilled_agri == 1 | agri == 0
gen treat_post = unskilled_agri * post
quietly reghdfe ln_wage treat_post, absorb(idind year) cluster(region)
di "Unskilled agri only: " %7.4f _b[treat_post] " (SE: " %6.4f _se[treat_post] ")"
restore

* 4C: Regional Livestock Specialization
di _n "=== 4C: By Regional Livestock Specialization ==="

* Create interaction
gen agri_livestock_post = agri * high_livestock * post

quietly reghdfe ln_wage agri_post agri_livestock_post, absorb(idind year) cluster(region)
di "Agri x Post (non-livestock regions): " %7.4f _b[agri_post] " (SE: " %6.4f _se[agri_post] ")"
di "Agri x Livestock x Post (additional): " %7.4f _b[agri_livestock_post] " (SE: " %6.4f _se[agri_livestock_post] ")"

* Separate by region type
preserve
keep if high_livestock == 1 | agri == 0
quietly reghdfe ln_wage agri_post, absorb(idind year) cluster(region)
di "High livestock regions only: " %7.4f _b[agri_post] " (SE: " %6.4f _se[agri_post] ")"
restore

preserve
keep if high_livestock == 0 | agri == 0
quietly reghdfe ln_wage agri_post, absorb(idind year) cluster(region)
di "Low livestock regions only: " %7.4f _b[agri_post] " (SE: " %6.4f _se[agri_post] ")"
restore

********************************************************************************
* PART 5: Power Analysis
********************************************************************************

di ""
di "======================================================================"
di "PART 5: POWER ANALYSIS"
di "======================================================================"

di _n "=== Sample Sizes and Minimum Detectable Effects ==="
di ""
di "Group                    | N      | MDE (80% power)"
di "-------------------------|--------|----------------"

foreach group in "All agriculture" "Skilled (ISCO 6)" "Unskilled (ISCO 9)" {
    if "`group'" == "All agriculture" {
        count if agri == 1
    }
    else if "`group'" == "Skilled (ISCO 6)" {
        count if skilled_agri == 1
    }
    else {
        count if unskilled_agri == 1
    }
    local n = r(N)
    * MDE = 2.8 * SD / sqrt(N) for 80% power
    * Assuming SD = 0.65, design effect = 1.5
    local mde = 2.8 * 0.65 * sqrt(1.5) / sqrt(`n')
    di "`group'" _col(26) "| " %6.0f `n' " | " %5.1f `mde'*100 "%"
}

di ""
di "NOTE: MDEs assume within-group SD of 0.65 and design effect of 1.5"
di "      Effects smaller than MDE cannot be reliably detected"

********************************************************************************
* PART 6: Summary Table for Paper
********************************************************************************

di ""
di "======================================================================"
di "PART 6: SUMMARY FOR PAPER"
di "======================================================================"

* Store results
tempname results
postfile `results' str30 group coef se n mde using "output/tables/subsector_results.dta", replace

* All agriculture
quietly reghdfe ln_wage agri_post, absorb(idind year) cluster(region)
count if agri == 1
local n = r(N)
local mde = 2.8 * 0.65 * sqrt(1.5) / sqrt(`n')
post `results' ("All agriculture") (_b[agri_post]) (_se[agri_post]) (`n') (`mde')

* Skilled
preserve
keep if skilled_agri == 1 | agri == 0
gen treat_post = skilled_agri * post
quietly reghdfe ln_wage treat_post, absorb(idind year) cluster(region)
count if skilled_agri == 1
local n = r(N)
local mde = 2.8 * 0.65 * sqrt(1.5) / sqrt(`n')
post `results' ("Skilled (ISCO 6)") (_b[treat_post]) (_se[treat_post]) (`n') (`mde')
restore

* Unskilled
preserve
keep if unskilled_agri == 1 | agri == 0
gen treat_post = unskilled_agri * post
quietly reghdfe ln_wage treat_post, absorb(idind year) cluster(region)
count if unskilled_agri == 1
local n = r(N)
local mde = 2.8 * 0.65 * sqrt(1.5) / sqrt(`n')
post `results' ("Unskilled (ISCO 9)") (_b[treat_post]) (_se[treat_post]) (`n') (`mde')
restore

* High livestock regions
preserve
keep if high_livestock == 1 | agri == 0
quietly reghdfe ln_wage agri_post, absorb(idind year) cluster(region)
count if agri == 1 & high_livestock == 1
local n = r(N)
local mde = 2.8 * 0.65 * sqrt(1.5) / sqrt(`n')
post `results' ("High livestock regions") (_b[agri_post]) (_se[agri_post]) (`n') (`mde')
restore

* Low livestock regions
preserve
keep if high_livestock == 0 | agri == 0
quietly reghdfe ln_wage agri_post, absorb(idind year) cluster(region)
count if agri == 1 & high_livestock == 0
local n = r(N)
local mde = 2.8 * 0.65 * sqrt(1.5) / sqrt(`n')
post `results' ("Low livestock regions") (_b[agri_post]) (_se[agri_post]) (`n') (`mde')
restore

postclose `results'

* Display
use "output/tables/subsector_results.dta", clear
di _n "=== Sub-Sector Results ==="
list, sep(0)

* Export
export delimited using "output/tables/subsector_results.csv", replace

********************************************************************************
* PART 7: Rosstat Production Data Context
********************************************************************************

di ""
di "======================================================================"
di "PART 7: PRODUCTION DATA CONTEXT (FROM ROSSTAT)"
di "======================================================================"

di _n "Import substitution success by product (2013-2019 production growth):"
di ""
di "Product Category     | Production Growth | Import Sub. Success"
di "---------------------|-------------------|--------------------"
di "Pork                 | +95%              | High (self-sufficient)"
di "Poultry              | +30%              | High (near self-sufficient)"
di "Beef                 | -5%               | Low (still importing)"
di "Dairy/Cheese         | +15%              | Low (quality gap)"
di "Vegetables           | +25%              | Medium"
di "Fruits               | +10%              | Low (climate limits)"
di ""
di "Source: Rosstat, Wegren et al. (2019), FAO"
di ""
di "Interpretation:"
di "- Livestock (pork, poultry) = successful import substitution"
di "- Dairy = limited success due to quality/technology gap"
di "- Fruits = limited success due to climate constraints"
di ""
di "Our regional livestock proxy captures some of this variation:"
di "- High livestock regions may have benefited more from pork/poultry expansion"
di "- But our RLMS occupation codes cannot distinguish sub-sectors directly"

log close
