********************************************************************************
* Sub-sector × Firm Structure Analysis
* Statistical matching: RLMS workers to RFSD regional firm characteristics
********************************************************************************

clear all
set more off
cap log close
log using "output/analysis_firm_structure_log.txt", replace text

use "output/rlms_analysis_sample.dta", clear
keep if year >= 2010 & year <= 2019

di "======================================================================"
di "SUB-SECTOR x FIRM STRUCTURE ANALYSIS"
di "Statistical Matching Approach: RLMS workers to RFSD regional firm data"
di "======================================================================"

********************************************************************************
* STEP 1: Import RFSD regional firm structure data
********************************************************************************

preserve
import delimited "output/tables/region_firm_structure.csv", clear
list in 1/10

* Clean region names for matching
gen region_match = lower(region_rfsd)
replace region_match = trim(region_match)

save "temp/firm_structure.dta", replace
restore

********************************************************************************
* STEP 2: Create RLMS region matching variable
********************************************************************************

* Get region labels
decode region, gen(region_str)

* Clean for matching
gen region_match = lower(region_str)
replace region_match = trim(region_match)

* Show unique RLMS regions
di _n "=== RLMS Regions ==="
tab region_str if _n <= 100

********************************************************************************
* STEP 3: Manual crosswalk (RLMS region labels to RFSD)
********************************************************************************

* Create RFSD region name based on RLMS region
cap drop region_rfsd
gen region_rfsd = ""

* Moscow
replace region_rfsd = "moscow oblast" if strpos(region_str, "Moscow Oblast") > 0
replace region_rfsd = "moscow" if strpos(region_str, "Moscow City") > 0

* St. Petersburg
replace region_rfsd = "st. petersburg" if strpos(region_str, "St. Petersburg") > 0
replace region_rfsd = "leningrad oblast" if strpos(region_str, "Leningrad") > 0

* Major regions
replace region_rfsd = "krasnodar krai" if strpos(region_str, "Krasnodarsk") > 0
replace region_rfsd = "rostov oblast" if strpos(region_str, "Rostov") > 0 | strpos(region_str, "Batajsk") > 0
replace region_rfsd = "chelyabinsk oblast" if strpos(region_str, "Cheliabinsk") > 0
replace region_rfsd = "nizhny novgorod oblast" if strpos(region_str, "Gorkovsk") > 0 | strpos(region_str, "Nizhnij Novgorod") > 0
replace region_rfsd = "novosibirsk oblast" if strpos(region_str, "Novosibirsk") > 0
replace region_rfsd = "tatarstan" if strpos(region_str, "Tatarsk") > 0 | strpos(region_str, "Kazan") > 0
replace region_rfsd = "volgograd oblast" if strpos(region_str, "Volgograd") > 0
replace region_rfsd = "saratov oblast" if strpos(region_str, "Saratov") > 0
replace region_rfsd = "krasnoyarsk krai" if strpos(region_str, "Krasnojarsk") > 0
replace region_rfsd = "penza oblast" if strpos(region_str, "Penzensk") > 0
replace region_rfsd = "tula oblast" if strpos(region_str, "Tulsk") > 0
replace region_rfsd = "lipetzk" if strpos(region_str, "Lipetsk") > 0
replace region_rfsd = "tambov oblast" if strpos(region_str, "Tambov") > 0
replace region_rfsd = "kaluga oblast" if strpos(region_str, "Kaluzh") > 0 | strpos(region_str, "Kuibyshev") > 0
replace region_rfsd = "smolensk oblast" if strpos(region_str, "Smolensk") > 0
replace region_rfsd = "stavropol krai" if strpos(region_str, "Stavropol") > 0
replace region_rfsd = "altai krai" if strpos(region_str, "Altaisk") > 0
replace region_rfsd = "amur oblast" if strpos(region_str, "Amursk") > 0
replace region_rfsd = "tomsk" if strpos(region_str, "Tomsk") > 0
replace region_rfsd = "komi republic" if strpos(region_str, "Komi") > 0
replace region_rfsd = "udmurt republic" if strpos(region_str, "Udmurt") > 0
replace region_rfsd = "chuvash republic" if strpos(region_str, "Chuvash") > 0
replace region_rfsd = "kurgan oblast" if strpos(region_str, "Kurgan") > 0
replace region_rfsd = "orenburg oblast" if strpos(region_str, "Orenburg") > 0 | strpos(region_str, "Orsk") > 0
replace region_rfsd = "kabardino-balkaria" if strpos(region_str, "Kabardino") > 0
replace region_rfsd = "primorsky krai" if strpos(region_str, "Vladivostok") > 0
replace region_rfsd = "perm krai" if strpos(region_str, "Perm") > 0 | strpos(region_str, "Solikamsk") > 0
replace region_rfsd = "kalinin oblast" if strpos(region_str, "Kalinin") > 0 | strpos(region_str, "Rzhev") > 0

di _n "=== Merge Match Rates ==="
tab region_rfsd if region_rfsd != ""

********************************************************************************
* STEP 4: Merge with RFSD firm structure
********************************************************************************

merge m:1 region_rfsd using "temp/firm_structure.dta", keep(1 3) nogen

di _n "=== Match Summary ==="
count if livestock_dominance != .
di "Matched observations: " r(N)
count if livestock_dominance == .
di "Unmatched observations: " r(N)

* Fill unmatched with median values
sum livestock_dominance, detail
replace livestock_dominance = r(p50) if livestock_dominance == .
sum dairy_share, detail
replace dairy_share = r(p50) if dairy_share == .
sum high_livestock, detail
replace high_livestock = round(r(p50)) if high_livestock == .

********************************************************************************
* PART 1: Effects by Regional Firm Structure
********************************************************************************

di ""
di "======================================================================"
di "PART 1: EFFECTS BY REGIONAL FIRM STRUCTURE"
di "======================================================================"

cap drop agri_post
gen agri_post = agri * post

* Overall baseline
di _n "=== OVERALL (Baseline) ==="
reghdfe ln_wage agri_post, absorb(idind year) cluster(region)

* By livestock vs dairy dominance
di _n "=== LIVESTOCK-DOMINANT REGIONS (large farm proxy) ==="
reghdfe ln_wage agri_post if high_livestock == 1, absorb(idind year) cluster(region)

di _n "=== DAIRY-DOMINANT REGIONS (small farm proxy) ==="
reghdfe ln_wage agri_post if high_livestock == 0, absorb(idind year) cluster(region)

********************************************************************************
* PART 2: Triple Difference - Agri × Post × Firm Structure
********************************************************************************

di ""
di "======================================================================"
di "PART 2: TRIPLE DIFFERENCE WITH FIRM STRUCTURE"
di "======================================================================"

* Standardize livestock dominance
sum livestock_dominance
gen livestock_std = (livestock_dominance - r(mean)) / r(sd)

* Create triple interaction
gen agri_post_livestock = agri_post * livestock_std

di _n "=== TRIPLE DIFF: Agri × Post × Livestock Dominance (standardized) ==="
reghdfe ln_wage agri_post agri_post_livestock, absorb(idind year) cluster(region)

* With binary indicator
gen agri_post_highlivestock = agri_post * high_livestock

di _n "=== TRIPLE DIFF: Agri × Post × High Livestock (binary) ==="
reghdfe ln_wage agri_post agri_post_highlivestock, absorb(idind year) cluster(region)

********************************************************************************
* PART 3: Dairy-dominant vs Other (Small farm proxy)
********************************************************************************

di ""
di "======================================================================"
di "PART 3: DAIRY REGIONS (Small Farm Proxy)"
di "======================================================================"

* Standardize dairy share
sum dairy_share
gen dairy_std = (dairy_share - r(mean)) / r(sd)

* Triple interaction with dairy
gen agri_post_dairy = agri_post * dairy_std

di _n "=== TRIPLE DIFF: Agri × Post × Dairy Share (standardized) ==="
reghdfe ln_wage agri_post agri_post_dairy, absorb(idind year) cluster(region)

********************************************************************************
* PART 4: Combined Model (test both simultaneously)
********************************************************************************

di ""
di "======================================================================"
di "PART 4: COMBINED MODEL"
di "======================================================================"

di _n "=== Livestock AND Dairy interactions (testing both) ==="
reghdfe ln_wage agri_post agri_post_livestock agri_post_dairy, absorb(idind year) cluster(region)

********************************************************************************
* PART 5: Sub-sector proxy using occupation codes
********************************************************************************

di ""
di "======================================================================"
di "PART 5: SUB-SECTOR PROXY USING OCCUPATION CODES"
di "======================================================================"

* Check if occupation variable exists
cap describe occup08
if _rc == 0 {
    * ISCO codes: 6 = Skilled agricultural workers, 92 = Agricultural laborers
    gen skilled_agri = (occup08 >= 600 & occup08 < 700)
    gen unskilled_agri = (occup08 >= 920 & occup08 < 930)

    * Create sub-sector proxy
    gen agri_skilled = agri * skilled_agri
    gen agri_unskilled = agri * unskilled_agri

    tab skilled_agri agri if agri == 1
    tab unskilled_agri agri if agri == 1

    * Effects by skill level (sub-sector proxy)
    di _n "=== SKILLED AGRICULTURAL WORKERS ==="
    reghdfe ln_wage agri_post if skilled_agri == 1, absorb(idind year) cluster(region)

    di _n "=== UNSKILLED AGRICULTURAL LABORERS ==="
    reghdfe ln_wage agri_post if unskilled_agri == 1, absorb(idind year) cluster(region)

    * Triple difference with skill × firm structure
    gen skilled_post = skilled_agri * post
    gen skilled_post_livestock = skilled_post * livestock_std

    di _n "=== SKILLED AGRI × Livestock Dominance ==="
    reghdfe ln_wage skilled_post skilled_post_livestock if agri == 1, absorb(idind year) cluster(region)
}
else {
    di "Occupation variable (occup08) not available"
}

********************************************************************************
* PART 6: Summary Table
********************************************************************************

di ""
di "======================================================================"
di "SUMMARY: SUB-SECTOR × FIRM STRUCTURE INTERACTIONS"
di "======================================================================"

di _n "Key findings:"
di "1. This analysis uses statistical matching - NOT true worker-firm linking"
di "2. Livestock dominance proxies for large farm structure (pork, poultry)"
di "3. Dairy dominance proxies for small farm structure"
di "4. Interactions test whether effects differ by regional firm composition"
di ""
di "Caveats:"
di "- This is ecological inference, not individual-level matching"
di "- Regional firm structure != individual worker's employer"
di "- Results should be interpreted as suggestive, not causal"

di ""
di "Analysis complete!"
log close
