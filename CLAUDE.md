# Import Substitution and Labor Markets: Evidence from Russia's Food Embargo

## Project Overview

This paper studies how domestic labor markets respond to sudden trade barriers using the natural experiment of Russia's 2014 food import embargo. This setting offers clean identification: the policy was an unexpected response to geopolitical events, affected specific product categories, and has remained in place for over a decade — allowing us to trace both short and long-run labor market adjustments.

## Data Sources

### 1. RLMS (Individual-level) - PRIMARY
- **Source**: Russia Longitudinal Monitoring Survey
- **Files**:
  - `IND/RLMS_IND_1994_2023_eng_dta.dta` (11 GB) - Individual data
  - `HH/RLMS_HH_1994_2023_eng_dta.dta` (2.7 GB) - Household data
- **Timeline**: 1994-2023 (use 2010-2023 for analysis)
- **Treatment event**: August 2014 food import ban
- **Key variables**: Wages, employment, sector, region, demographics

### 2. RFSD (Firm-level) - SECONDARY
- **Source**: Russian Firm Statistical Database
- **Hugging Face**: `irlspbru/RFSD`
- **Zenodo**: https://doi.org/10.5281/zenodo.14622209
- **Timeline**: 2011-2024 (60.1M firm-year observations)
- **Location**: `RFSD_data/`
- **Use case**: Regional treatment intensity measures

## Regional Exposure Measures (Bartik-style)

### Option A: Agricultural Specialization (RFSD-based) ✓ DONE
- RFSD firm counts by region and product type
- Weight regions by pre-2014 share of banned-product production
- See `RFSD_data/output/rfsd_treatment_intensity.csv`

### Option B: Import Dependence Proxy
- Regions closer to EU borders had higher pre-ban import shares
- Distance to St. Petersburg/Moscow (major import hubs)
- Can use as instrument

### Option C: Agricultural Employment Share
- Regions with higher agricultural employment = higher treatment potential
- Can compute from RLMS directly

## Treatment Intensity Measures (from RFSD)

**Computed variables** in `RFSD_data/output/rfsd_treatment_intensity.csv`:

| Variable | Description |
|----------|-------------|
| `baseline_share_food_agri` | Share of food/agri firms in region (2013) |
| `treatment_intensity_product` | Product-weighted intensity |
| `treatment_intensity_combined` | Combined intensity measure |
| `treatment_tercile` | 1=low, 2=medium, 3=high |
| `high_treatment` | Binary above-median indicator |

**Import shares used:**
- Dairy: 35%
- Beef: 25%
- Pork: 25%
- Poultry: 15%
- Fruits/vegetables: 65%
- Fish: 30%

## Original Paper vs. New Analysis

| Aspect | Original | New |
|--------|----------|-----|
| Data | RLMS 2010-2018 | RLMS 2010-2023 |
| Post-treatment | 4 years | 9 years |
| Method | Simple DiD | Callaway-Sant'Anna, Sun-Abraham |
| Treatment | Binary (agri vs. other) | Continuous regional intensity |
| Finding | +5.6% earnings | TBD |

## Research Questions

1. Do workers in protected industries see sustained wage gains?
2. Does employment shift toward protected sectors?
3. Are gains concentrated in large firms or small producers?
4. Do effects vary by region/product exposure?
5. **NEW**: Do effects persist, fade, or grow over 9 years?

## Policy Variation to Exploit (Staggered Treatment)

| Date | Policy Change | Research Use |
|------|---------------|--------------|
| Aug 2014 | Initial ban (US/EU/Canada/Australia/Norway) | Baseline treatment |
| Aug 2015 | Albania, Montenegro, Iceland, Liechtenstein added | Staggered adoption |
| Jan 2016 | Ukraine added | Another treatment wave |
| Oct 2017 | Live pigs, animal offal added | Product-level variation |
| May 2016 | Baby food exemptions | Intensive margin |
| Dec 2020 | UK added (post-Brexit) | Recent treatment |
| Annual | Extensions through 2026 | Credibility/permanence |

**Key insight**: Not a single treatment — perfect for Callaway-Sant'Anna staggered DiD.

## Paper Angles (Choose 1-2)

### Angle A: Winners and Losers Within Agriculture ⭐
- Import substitution **succeeded** for: pork, poultry, tomatoes
- Import substitution **failed** for: dairy, cheese, milk
- Compare earnings in successful vs. failed sub-sectors
- RLMS has detailed industry codes for livestock vs. dairy vs. crops

### Angle B: Firm Size and Protection Benefits
- Embargo led to expansion of large agriholdings, crowding out small farms
- RLMS asks about firm size
- Policy question: Does protection help workers or just big firms?

### Angle C: Long-run Persistence (Strongest Selling Point)
- Original paper: 4 years post-treatment
- This paper: **9-10 years** post-treatment
- Event study showing year-by-year dynamics
- Did gains persist, fade, or compound?

### Angle D: Consumer vs. Producer Welfare
- Consumer losses: ~445 billion rubles/year (~3000 rubles/person)
- Do agricultural workers' wage gains offset higher food costs?
- RLMS has food consumption/expenditure data

## Project Structure

```
/Working santctions/
├── CLAUDE.md                    # This file
├── HH/
│   └── RLMS_HH_1994_2023_eng_dta.dta
├── IND/
│   └── RLMS_IND_1994_2023_eng_dta.dta
├── RFSD_data/
│   ├── RFSD_2013.parquet        # Pre-treatment
│   ├── RFSD_2014.parquet        # Treatment year
│   ├── RFSD_2018.parquet        # Original endpoint
│   ├── RFSD_2023_sample.parquet # Extended
│   ├── explore_rfsd.py
│   ├── compute_treatment_intensity.py
│   └── output/
│       ├── rfsd_treatment_intensity.csv
│       ├── rfsd_regional_panel.csv
│       └── agri_firms_*.parquet
├── temp/
│   ├── Do-files/
│   ├── Results/
│   └── RFSD_data/
└── Sanctions database/
```

## Analysis Pipeline

### Step 1: Prepare RLMS Data
```stata
* Load individual data
use "IND/RLMS_IND_1994_2023_eng_dta.dta", clear

* Keep relevant years (2010-2023)
keep if year >= 2010 & year <= 2023

* Keep key variables
keep idind year region psu age h5 h6 educ marst j1 j10 j4_1 j8 j11 occup08

* Clean wages
gen wage = j10
replace wage = . if wage >= 99999990  // Missing codes
gen ln_wage = ln(wage)

* Treatment: Agriculture sector
gen agri = (j4_1 == 8)
gen food_industry = (j4_1 == 1)
gen treated_sector = (agri == 1 | food_industry == 1)

* Demographics
gen female = (h5 == 2)
rename age age_years

* Save cleaned data
save "rlms_cleaned.dta", replace
```

### Step 2: Merge Region Crosswalk & Treatment Intensity
```stata
* Import region crosswalk
import delimited "region_crosswalk.csv", clear
rename psu region
save "region_crosswalk.dta", replace

* Import treatment intensity
import delimited "RFSD_data/output/rfsd_treatment_intensity.csv", clear
save "treatment_intensity.dta", replace

* Merge with RLMS
use "rlms_cleaned.dta", clear
merge m:1 region using "region_crosswalk.dta", keep(1 3) nogen
merge m:1 region_rfsd using "treatment_intensity.dta", keep(1 3) nogen
```

### Step 3: Event Study / DiD
```stata
* Install packages
ssc install reghdfe
ssc install csdid
ssc install drdid
ssc install eventstudyinteract

* Post indicator
gen post = (year >= 2014)

* Simple DiD: Agriculture vs. other sectors
reghdfe ln_wage i.agri##i.post i.year, absorb(idind) cluster(region)

* Regional intensity DiD
gen treat_x_post = baseline_treatment_combined * post
reghdfe ln_wage treat_x_post i.year, absorb(idind) cluster(region)

* Event study (year-by-year effects)
gen rel_year = year - 2014
forval t = -4/9 {
    gen D\`t' = (rel_year == \`t') * agri
}
reghdfe ln_wage D* i.year, absorb(idind) cluster(region) omit(D-1)

* Callaway-Sant'Anna (if staggered treatment)
* gen first_treat = 2014 if agri == 1
* csdid ln_wage, ivar(idind) time(year) gvar(first_treat) method(dripw)
```

## Key Variables in RLMS (Confirmed)

### Individual Level (IND file) - 3,114 variables
| Variable | Label | Notes |
|----------|-------|-------|
| `idind` | Unique longitudinal person ID | Panel identifier |
| `year` | Year | 1994-2023 |
| `region` | PSU code | See `region_crosswalk.csv` |
| `psu` | Primary sampling unit | Same as region |
| `age` | Number of full years | Direct age variable |
| `h5` | Gender | 1=Male, 2=Female |
| `h6` | Birth year | Alternative to age |
| `educ` | Education (detail) | Multiple categories |
| `marst` | Marital status | |
| `j1` | Current work status | Employment indicator |
| `j10` | After-tax wages last 30 days | **Main wage variable** |
| `j4_1` | Industry code | See industry codes below |
| `j8` | Hours worked last 30 days | Labor supply |
| `j11` | Enterprise type | Firm characteristics |
| `occup08` | Occupation (ISCO 2008) | |

### Industry Codes (j4_1) - Key for Treatment
| Code | Industry | Treatment |
|------|----------|-----------|
| **8** | **Agriculture** | **TREATED** |
| **1** | Light/Food Industry | Treated (food processing) |
| 2 | Civil Machine Construction | Control |
| 3 | Military Industrial Complex | Control |
| 4 | Oil and Gas | Control |
| 5 | Other Heavy Industry | Control |
| 6 | Construction | Control |
| 7 | Transportation, Communication | Control |
| 9 | Government | Control |
| 10 | Education | Control |
| 14 | Trade, Consumer Services | Partial (food retail) |

### Region Crosswalk
- RLMS uses PSU codes (1-200)
- Created `region_crosswalk.csv` mapping PSU → RFSD region names
- 35 unique oblasts/regions covered
- Key agricultural regions: Krasnodar (9,129), Stavropol (52), Rostov (137), Altai (58,84)

## Notes

- **Wages**: `j10` is after-tax, last 30 days - may need to annualize and deflate
- **Panel ID**: Use `idind` for individual fixed effects
- **Missing values**: 99999999 = "Don't know", 99999997 = "Refused"
- **Sample**: ~400K individuals over 30 years

## Next Steps

1. [ ] Explore RLMS variable names (describe data)
2. [ ] Create region crosswalk (RLMS PSU ↔ RFSD region)
3. [ ] Extract and clean relevant RLMS variables
4. [ ] Merge with treatment intensity
5. [ ] Run baseline DiD
6. [ ] Event study plots
