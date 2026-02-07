********************************************************************************
* Dose-Response Analysis
* Test whether effects vary with treatment intensity (pre-ban import shares)
* Check for nonlinear relationships
********************************************************************************

clear all
set more off
cap log close
log using "output/analysis_dose_response_log.txt", replace text

use "output/rlms_analysis_sample.dta", clear
keep if year >= 2010 & year <= 2019

di "======================================================================"
di "DOSE-RESPONSE ANALYSIS"
di "======================================================================"

********************************************************************************
* STEP 1: Import and merge treatment intensity data
********************************************************************************

di _n "=== STEP 1: Merge Treatment Intensity ==="

* Import RFSD treatment intensity
preserve
import delimited "RFSD_data/output/rfsd_treatment_intensity.csv", clear
keep region_std baseline_treatment_product baseline_treatment_combined high_treatment
rename region_std region_rfsd
rename baseline_treatment_product treatment_intensity_product
rename baseline_treatment_combined treatment_intensity_combined
save "temp/treatment_intensity.dta", replace
restore

* Create region matching variable (same as in geographic analysis)
decode region, gen(region_str)
cap drop region_rfsd
gen region_rfsd = ""

* Map RLMS regions to RFSD
replace region_rfsd = "moscow oblast" if strpos(region_str, "Moscow Oblast") > 0
replace region_rfsd = "moscow" if strpos(region_str, "Moscow City") > 0
replace region_rfsd = "st. petersburg" if strpos(region_str, "St. Petersburg") > 0
replace region_rfsd = "leningrad oblast" if strpos(region_str, "Leningrad") > 0
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

* Merge treatment intensity
merge m:1 region_rfsd using "temp/treatment_intensity.dta", keep(1 3) nogen

* Fill missing with median
sum treatment_intensity_product, detail
replace treatment_intensity_product = r(p50) if treatment_intensity_product == .
sum treatment_intensity_combined, detail
replace treatment_intensity_combined = r(p50) if treatment_intensity_combined == .
replace high_treatment = 0 if high_treatment == .

di _n "=== Treatment Intensity Distribution ==="
sum treatment_intensity_product treatment_intensity_combined, detail

********************************************************************************
* PART 1: Linear Dose-Response
********************************************************************************

di ""
di "======================================================================"
di "PART 1: LINEAR DOSE-RESPONSE"
di "======================================================================"

cap drop agri_post
gen agri_post = agri * post

* Standardize treatment intensity for interpretation
sum treatment_intensity_product
gen intensity_std = (treatment_intensity_product - r(mean)) / r(sd)

* Create interaction: Agri × Post × Intensity
gen agri_post_intensity = agri_post * intensity_std

di _n "=== Model 1: Baseline (no intensity) ==="
reghdfe ln_wage agri_post, absorb(idind year) cluster(region)
estimates store m1

di _n "=== Model 2: Linear dose-response ==="
reghdfe ln_wage agri_post agri_post_intensity, absorb(idind year) cluster(region)
estimates store m2

* Marginal effects at different intensity levels
di _n "=== Marginal effects at different intensity levels ==="
di "At mean intensity (0 SD): " _b[agri_post]
di "At +1 SD intensity: " _b[agri_post] + _b[agri_post_intensity]
di "At +2 SD intensity: " _b[agri_post] + 2*_b[agri_post_intensity]
di "At -1 SD intensity: " _b[agri_post] - _b[agri_post_intensity]

********************************************************************************
* PART 2: Nonlinear Dose-Response (Quadratic)
********************************************************************************

di ""
di "======================================================================"
di "PART 2: NONLINEAR DOSE-RESPONSE (QUADRATIC)"
di "======================================================================"

* Create quadratic term
gen intensity_std_sq = intensity_std^2
gen agri_post_intensity_sq = agri_post * intensity_std_sq

di _n "=== Model 3: Quadratic dose-response ==="
reghdfe ln_wage agri_post agri_post_intensity agri_post_intensity_sq, absorb(idind year) cluster(region)
estimates store m3

* Test for nonlinearity
test agri_post_intensity_sq = 0
local quad_pval = r(p)
di "Test for quadratic term: p = " `quad_pval'

********************************************************************************
* PART 3: Threshold Effects (by terciles)
********************************************************************************

di ""
di "======================================================================"
di "PART 3: THRESHOLD EFFECTS (TERCILES)"
di "======================================================================"

* Create terciles of treatment intensity
xtile intensity_tercile = treatment_intensity_product, nq(3)
label define terc_lbl 1 "Low intensity" 2 "Medium" 3 "High intensity"
label values intensity_tercile terc_lbl

tab intensity_tercile

* Create tercile interactions
gen agri_post_t2 = agri_post * (intensity_tercile == 2)
gen agri_post_t3 = agri_post * (intensity_tercile == 3)

di _n "=== Model 4: Tercile interactions ==="
reghdfe ln_wage agri_post agri_post_t2 agri_post_t3, absorb(idind year) cluster(region)
estimates store m4

di _n "Effects by tercile:"
di "  Low intensity (T1): " _b[agri_post]
di "  Medium intensity (T2): " _b[agri_post] + _b[agri_post_t2]
di "  High intensity (T3): " _b[agri_post] + _b[agri_post_t3]

* Test for difference between high and low
test agri_post_t3 = 0
di "Test T3 vs T1: p = " r(p)

********************************************************************************
* PART 4: Separate regressions by intensity level
********************************************************************************

di ""
di "======================================================================"
di "PART 4: SEPARATE REGRESSIONS BY INTENSITY"
di "======================================================================"

di _n "=== Low intensity regions (Tercile 1) ==="
reghdfe ln_wage agri_post if intensity_tercile == 1, absorb(idind year) cluster(region)

di _n "=== Medium intensity regions (Tercile 2) ==="
reghdfe ln_wage agri_post if intensity_tercile == 2, absorb(idind year) cluster(region)

di _n "=== High intensity regions (Tercile 3) ==="
reghdfe ln_wage agri_post if intensity_tercile == 3, absorb(idind year) cluster(region)

********************************************************************************
* PART 5: High vs Low treatment (binary)
********************************************************************************

di ""
di "======================================================================"
di "PART 5: HIGH VS LOW TREATMENT (BINARY)"
di "======================================================================"

gen agri_post_high = agri_post * high_treatment

di _n "=== Model 5: Binary high treatment interaction ==="
reghdfe ln_wage agri_post agri_post_high, absorb(idind year) cluster(region)
estimates store m5

di _n "Effects:"
di "  Low treatment regions: " _b[agri_post]
di "  High treatment regions: " _b[agri_post] + _b[agri_post_high]

********************************************************************************
* PART 6: Product-specific intensity
********************************************************************************

di ""
di "======================================================================"
di "PART 6: PRODUCT-SPECIFIC EFFECTS"
di "======================================================================"

* Import product-level shares for regions
preserve
import delimited "RFSD_data/output/rfsd_regional_panel.csv", clear
keep if year == 2013
keep region_std share_dairy share_meat_pork share_meat_poultry share_fruits_veg
rename region_std region_rfsd
save "temp/product_shares.dta", replace
restore

* Merge product shares
merge m:1 region_rfsd using "temp/product_shares.dta", keep(1 3) nogen

* Fill missing with zeros
foreach v in share_dairy share_meat_pork share_meat_poultry share_fruits_veg {
    replace `v' = 0 if `v' == .
}

* Standardize product shares
foreach v in share_dairy share_meat_pork share_meat_poultry share_fruits_veg {
    sum `v'
    gen `v'_std = (`v' - r(mean)) / r(sd)
}

* Create product-specific interactions
gen agri_post_dairy = agri_post * share_dairy_std
gen agri_post_pork = agri_post * share_meat_pork_std
gen agri_post_poultry = agri_post * share_meat_poultry_std
gen agri_post_veg = agri_post * share_fruits_veg_std

di _n "=== Model 6: Product-specific dose-response ==="
reghdfe ln_wage agri_post agri_post_dairy agri_post_pork agri_post_poultry agri_post_veg, ///
    absorb(idind year) cluster(region)
estimates store m6

di _n "Product-specific effects (per SD increase in regional share):"
di "  Dairy regions: " _b[agri_post_dairy]
di "  Pork regions: " _b[agri_post_pork]
di "  Poultry regions: " _b[agri_post_poultry]
di "  Fruits/Veg regions: " _b[agri_post_veg]

********************************************************************************
* PART 7: Summary Table
********************************************************************************

di ""
di "======================================================================"
di "SUMMARY TABLE"
di "======================================================================"

esttab m1 m2 m3 m4 m5 m6, ///
    keep(agri_post agri_post_intensity agri_post_intensity_sq agri_post_t2 agri_post_t3 ///
         agri_post_high agri_post_dairy agri_post_pork agri_post_poultry agri_post_veg) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("Baseline" "Linear" "Quadratic" "Terciles" "Binary" "Products") ///
    title("Dose-Response Analysis")

********************************************************************************
* PART 8: Visualization data export
********************************************************************************

preserve
collapse (mean) ln_wage, by(agri intensity_tercile year)
reshape wide ln_wage, i(intensity_tercile year) j(agri)
gen wage_gap = ln_wage1 - ln_wage0
export delimited using "output/tables/dose_response_by_tercile.csv", replace
restore

di ""
di "Analysis complete!"
log close
