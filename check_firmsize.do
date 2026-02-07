clear all
cap log close
log using "output/check_firmsize_log.txt", replace text

use "output/rlms_analysis_sample.dta", clear
keep if year >= 2010 & year <= 2019 & agri == 1

di "=== FIRM SIZE AND SUB-SECTOR VARIABLES FOR AGRICULTURAL WORKERS ==="

* List all j* variables
di _n "--- All j* variables in dataset ---"
describe j*

* Check j11 (enterprise type) if exists
di _n "--- j11: Enterprise type (if exists) ---"
cap tab j11, m

* Check j2 (number of employees) if exists  
di _n "--- j2: Employees at workplace (if exists) ---"
cap tab j2, m

* Check occupation codes
di _n "--- Occupation codes (ISCO) ---"
tab occup08, m

* Create occupation-based categories
gen occ_1digit = floor(occup08/1000) if occup08 != .
di _n "--- 1-digit occupation ---"
tab occ_1digit, m

log close
