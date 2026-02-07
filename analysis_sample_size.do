********************************************************************************
* Sample Size Analysis and Power Calculations
* Addressing referee concerns about small agricultural sample
********************************************************************************

clear all
set more off
cap log close
log using "output/analysis_sample_size_log.txt", replace text

* Load analysis sample
use "output/rlms_analysis_sample.dta", clear

********************************************************************************
* PART 1: Overall Sample Sizes by Year and Sector
********************************************************************************

di ""
di "======================================================================"
di "PART 1: SAMPLE SIZES BY YEAR AND SECTOR"
di "======================================================================"

* Agricultural workers by year
preserve
keep if agri == 1
tab year, matcell(agri_counts)
di ""
di "Agricultural workers by year:"
tab year
restore

* Total sample by year
tab year agri, row

* Baseline (2013) sample size
di ""
di "Baseline (2013) sample:"
count if year == 2013 & agri == 1
local n_agri_2013 = r(N)
count if year == 2013 & agri == 0
local n_other_2013 = r(N)
di "Agricultural workers: `n_agri_2013'"
di "Other sector workers: `n_other_2013'"

* Primary sample period (2010-2019)
di ""
di "Primary sample period (2010-2019):"
count if year >= 2010 & year <= 2019 & agri == 1
local n_agri_primary = r(N)
count if year >= 2010 & year <= 2019 & agri == 0
local n_other_primary = r(N)
di "Agricultural worker-years: `n_agri_primary'"
di "Other sector worker-years: `n_other_primary'"

* Unique individuals
preserve
keep if year >= 2010 & year <= 2019
bysort idind: gen first = _n == 1
count if first == 1 & agri == 1
di "Unique agricultural workers (ever in agri): " r(N)
restore

********************************************************************************
* PART 2: Sub-sector Analysis - What's Available?
********************************************************************************

di ""
di "======================================================================"
di "PART 2: SUB-SECTOR CLASSIFICATION CHECK"
di "======================================================================"

* Check what detailed industry variables exist
di ""
di "Checking for detailed industry codes..."

* j4_1 is the main industry code
describe j4*

* Look at occupation codes for agricultural workers
di ""
di "Occupation codes for agricultural workers (2013):"
preserve
keep if agri == 1 & year == 2013
tab occup08 if occup08 != ., m
restore

* Enterprise type might give us size information
di ""
di "Enterprise type for agricultural workers (j11):"
preserve
keep if agri == 1 & year >= 2010 & year <= 2019
cap tab j11, m
restore

********************************************************************************
* PART 3: Sample Sizes by Occupation Categories (ISCO)
********************************************************************************

di ""
di "======================================================================"
di "PART 3: SAMPLE BY OCCUPATION CATEGORIES (ISCO)"
di "======================================================================"

* ISCO-08 codes for agriculture:
* 6 = Skilled agricultural, forestry and fishery workers
* 61 = Market-oriented skilled agricultural workers
* 611 = Market gardeners and crop growers
* 612 = Animal producers
* 613 = Mixed crop and animal producers
* 62 = Market-oriented skilled forestry, fishery and hunting workers
* 9 = Elementary occupations (92 = Agricultural laborers)

preserve
keep if agri == 1 & year >= 2010 & year <= 2019

* Create broad occupation categories
gen occ_1digit = floor(occup08/1000) if occup08 != .
gen occ_2digit = floor(occup08/100) if occup08 != .
gen occ_3digit = floor(occup08/10) if occup08 != .

di ""
di "1-digit occupation distribution:"
tab occ_1digit, m

di ""
di "2-digit occupation distribution (skilled agricultural):"
tab occ_2digit if occ_1digit == 6, m

di ""
di "3-digit occupation distribution:"
tab occ_3digit if occ_2digit == 61 | occ_2digit == 62, m

* Create agricultural sub-categories based on occupation
gen subsector = .
replace subsector = 1 if occ_3digit == 611 | occ_3digit == 613  // Crop/mixed farmers
replace subsector = 2 if occ_3digit == 612  // Animal producers (livestock/dairy)
replace subsector = 3 if occ_2digit == 62  // Forestry/fishery
replace subsector = 4 if occ_1digit == 9  // Agricultural laborers
replace subsector = 5 if subsector == . & agri == 1  // Other agricultural (managers, etc.)

label define subsector_lbl 1 "Crop/Mixed Farmers" 2 "Animal Producers" 3 "Forestry/Fishery" 4 "Agricultural Laborers" 5 "Other Agricultural"
label values subsector subsector_lbl

di ""
di "Agricultural sub-sector sample sizes (2010-2019):"
tab subsector year, m

di ""
di "Sub-sector totals:"
tab subsector, m

restore

********************************************************************************
* PART 4: Regional Sample Sizes
********************************************************************************

di ""
di "======================================================================"
di "PART 4: REGIONAL SAMPLE SIZES"
di "======================================================================"

preserve
keep if agri == 1 & year >= 2010 & year <= 2019

di ""
di "Agricultural workers by region (2010-2019):"
tab region, sort

di ""
di "Number of regions with agricultural workers:"
distinct region
restore

********************************************************************************
* PART 5: Power Calculations
********************************************************************************

di ""
di "======================================================================"
di "PART 5: POWER CALCULATIONS"
di "======================================================================"

* Get key statistics for power calculation
preserve
keep if year >= 2010 & year <= 2019

* Standard deviation of log wages
sum ln_wage if agri == 1
local sd_agri = r(sd)
di "SD of log wages (agriculture): `sd_agri'"

sum ln_wage if agri == 0
local sd_other = r(sd)
di "SD of log wages (other): `sd_other'"

* Sample sizes
count if agri == 1
local n1 = r(N)
count if agri == 0
local n0 = r(N)

di ""
di "Sample sizes:"
di "N agricultural worker-years: `n1'"
di "N other sector worker-years: `n0'"

* Clusters
distinct region if agri == 1
local clusters = r(ndistinct)
di "Number of clusters (regions): `clusters'"

restore

* Minimum detectable effect (MDE) calculation
* Formula: MDE = 2.8 * sigma / sqrt(N) for 80% power, alpha=0.05
* With clustering, effective N is reduced

di ""
di "MINIMUM DETECTABLE EFFECTS (80% power, alpha=0.05):"
di "--------------------------------------------------"

* Simple calculation (ignoring clustering)
local mde_simple = 2.8 * `sd_agri' / sqrt(`n1')
di "MDE (simple, no clustering): " %5.3f `mde_simple' " log points"
local pct_simple = (exp(`mde_simple')-1)*100
di "  = " %5.1f `pct_simple' "% wage change"

* With clustering adjustment (assume ICC ~ 0.05, avg cluster size ~ 50)
local icc = 0.05
local avg_cluster = `n1' / `clusters'
local deff = 1 + (`avg_cluster' - 1) * `icc'
local n_eff = `n1' / `deff'
local mde_cluster = 2.8 * `sd_agri' / sqrt(`n_eff')
di ""
di "MDE (with clustering, ICC=0.05): " %5.3f `mde_cluster' " log points"
local pct_cluster = (exp(`mde_cluster')-1)*100
di "  = " %5.1f `pct_cluster' "% wage change"

* For heterogeneity (sub-sectors)
di ""
di "MDE by sub-sample size:"
foreach n in 50 100 200 500 1000 {
    local n_eff_sub = `n' / `deff'
    local mde_sub = 2.8 * `sd_agri' / sqrt(`n_eff_sub')
    local pct_sub = (exp(`mde_sub')-1)*100
    di "  N=`n': " %5.3f `mde_sub' " log points (" %5.1f `pct_sub' "%)"
}

* Power for our estimated effect (3.6%)
di ""
di "POWER FOR DETECTED EFFECT SIZE (3.6% = 0.035 log points):"
local effect = 0.035
local se = `sd_agri' / sqrt(`n_eff')
local t_stat = `effect' / `se'
di "t-statistic for 3.6% effect: " %5.2f `t_stat'
di "Power is HIGH if t > 2.8 (we have t=" %5.2f `t_stat' ")"

********************************************************************************
* PART 6: Create Summary Table for Paper
********************************************************************************

di ""
di "======================================================================"
di "PART 6: SUMMARY TABLE FOR PAPER"
di "======================================================================"

preserve
keep if year >= 2010 & year <= 2019

* Overall counts
count if agri == 1
local n_agri = r(N)
count if agri == 0  
local n_other = r(N)

* Unique individuals
bysort idind: gen first = _n == 1
count if first == 1 & agri == 1
local unique_agri = r(N)

* Pre-treatment baseline (2013)
count if agri == 1 & year == 2013
local n_agri_2013 = r(N)

* Post-treatment (2014-2019)
count if agri == 1 & year >= 2014 & year <= 2019
local n_agri_post = r(N)

* Create occupation-based sub-sectors again
gen occ_2digit = floor(occup08/100) if occup08 != .
gen occ_3digit = floor(occup08/10) if occup08 != .
gen occ_1digit = floor(occup08/1000) if occup08 != .

* Sub-sector counts
count if agri == 1 & (occ_3digit == 611 | occ_3digit == 613)
local n_crop = r(N)
count if agri == 1 & occ_3digit == 612
local n_animal = r(N)
count if agri == 1 & occ_2digit == 62
local n_forestry = r(N)
count if agri == 1 & occ_1digit == 9
local n_laborers = r(N)

di ""
di "SAMPLE SIZE SUMMARY (2010-2019):"
di "--------------------------------------------------"
di "Total worker-years (agricultural): `n_agri'"
di "Total worker-years (other sectors): `n_other'"
di "Unique agricultural workers: `unique_agri'"
di "Agricultural baseline (2013): `n_agri_2013'"
di "Agricultural post-treatment (2014-2019): `n_agri_post'"
di ""
di "Sub-sector breakdown (occupation-based):"
di "  Crop/Mixed farmers: `n_crop'"
di "  Animal producers: `n_animal'"
di "  Forestry/Fishery: `n_forestry'"
di "  Agricultural laborers: `n_laborers'"

restore

********************************************************************************
* PART 7: Export Tables
********************************************************************************

* Create sample size table
preserve
keep if year >= 2010 & year <= 2019

collapse (count) n=ln_wage, by(year agri)
reshape wide n, i(year) j(agri)
rename n0 n_other
rename n1 n_agri
gen total = n_other + n_agri

export delimited using "output/tables/sample_size_by_year.csv", replace
restore

* Create sub-sector table
preserve
keep if agri == 1 & year >= 2010 & year <= 2019

gen occ_1digit = floor(occup08/1000) if occup08 != .
gen occ_2digit = floor(occup08/100) if occup08 != .
gen occ_3digit = floor(occup08/10) if occup08 != .

gen subsector = "Other/Unknown"
replace subsector = "Crop/Mixed Farmers" if occ_3digit == 611 | occ_3digit == 613
replace subsector = "Animal Producers" if occ_3digit == 612
replace subsector = "Forestry/Fishery" if occ_2digit == 62
replace subsector = "Agricultural Laborers" if occ_1digit == 9

collapse (count) n=ln_wage (mean) mean_wage=ln_wage (sd) sd_wage=ln_wage, by(subsector)
gsort -n
export delimited using "output/tables/subsector_sample_sizes.csv", replace

list
restore

di ""
di "Analysis complete. Output saved to output/tables/"

log close
