# Competing Explanations: Data Summary

## 1. Government Subsidies

### Annual Agricultural Subsidies (billion rubles)
| Year | Amount (bn RUB) | Notes |
|------|-----------------|-------|
| 2008-2012 | ~130 avg | Pre-State Program |
| 2013 | 159 | State Program begins |
| 2014 | ~160 | Embargo year |
| 2015 | 222 | +39% from 2014 |
| 2016 | 218 | |
| 2017 | 234 | |
| 2018 | 248 | |
| 2019 | 304 | +23% jump |
| 2020 | 295 | |
| 2021 | 312 | |
| 2022 | 366 | |
| 2023 | 378 | |

### Key Subsidy Programs
- **State Program 2013-2020**: 2.3 trillion rubles total (1.5 trillion federal, 777 billion regional)
- **Import Substitution Projects 2015-2018**: 1.6 trillion rubles ($24.9 billion)
- **Key finding (World Bank)**: "Subsidies financed through public funds have NOT contributed to productivity increase at the agri-enterprise or farm level"

### Sources
- Statista: https://www.statista.com/statistics/1064082/russia-agricultural-subsidies/
- World Bank Report: https://documents1.worldbank.org/curated/en/385381624614968540/pdf/Russian-Federation-Agricultural-Sector-Subsidies-and-Resilience.pdf
- USDA FAS Reports: https://www.fas.usda.gov/data/russia-agricultural-state-program-2013-2020-amended-2017

---

## 2. Ruble Depreciation (2014-2015)

### Exchange Rate
| Date | RUB/USD |
|------|---------|
| Jan 2014 | 34 |
| Dec 2014 | 80 (peak) |
| Mar 2015 | 60 |
| 2016-2019 | 60-70 |

**Depreciation**: ~70% from 2014 to 2015

### Effects on Agriculture
- **Positive**: Made Russian grain/wheat exports more competitive on world markets
- **Positive**: Record grain exports July 2014-Jan 2015 (23 mmt total, 18 mmt wheat)
- **Positive**: Stimulated import substitution by making imports expensive
- **Negative**: Raised domestic food inflation from 6% (2013) to 21% (2015)
- **Negative**: Made importing agricultural machinery/technology more expensive

### Differential Sectoral Effects
- Agriculture: BENEFITED (labor-intensive, less import-dependent)
- Manufacturing: HURT (import-dependent for equipment)
- Services: Mixed (less directly affected)

### Sources
- Choices Magazine: https://www.choicesmagazine.org/choices-magazine/submitted-articles/russias-economic-crisis-and-its-agricultural-and-food-economy
- Liefert et al. 2019: https://journals.sagepub.com/doi/full/10.1177/1879366519840185
- Brookings: https://www.brookings.edu/articles/with-the-ruble-depreciation-made-in-russia-could-once-more-become-a-worldwide-trademark/

---

## 3. Pre-2014 Productivity Trends

### TFP Growth Periods (USDA ERS)
| Period | Annual TFP Growth |
|--------|-------------------|
| 1994-1998 | +4.2% (output declined faster than inputs) |
| 1998-2005 | Recovery period |
| 2005-2013 | +1.7% (modest growth) |
| 2010-2016 | -1.0% (DECLINE) |

### Key Findings
- Russian agriculture was ALREADY recovering post-2000
- Southern regions drove most of the productivity gains
- Technology transfer from Western machinery, seeds, animal stock was important
- Post-2008 financial crisis slowed TFP growth
- By 2016, Russia exceeded Soviet-era grain production levels

### Output Trends
- Significant contraction in 1990s (transition)
- Rebound after 2000
- South and Central districts: 51% of national TFP growth by 2009-2013
- 2014 grain harvest: 105 million metric tons (bountiful)

### Sources
- USDA ERS: https://www.ers.usda.gov/publications/pub-details?pubid=83284
- USDA Amber Waves: https://www.ers.usda.gov/amber-waves/2017/april/agricultural-recovery-in-russia-and-the-rise-of-its-south

---

## Implications for Identification

### Challenge 1: Subsidies
- Subsidies increased sharply after 2014 (+39% in 2015 alone)
- BUT: State Program started in 2013, before embargo
- BUT: World Bank finds subsidies did NOT increase productivity
- TESTABLE: Compare wage trends in years with larger vs smaller subsidy increases

### Challenge 2: Ruble Depreciation
- Depreciation clearly benefited agriculture (export competitiveness)
- This affected ALL of Russian agriculture, not just embargo-related products
- Could be SEPARATE channel that reinforces embargo effects
- NOT TESTABLE with DiD: affects all agricultural workers equally

### Challenge 3: Pre-trends
- Agriculture was on positive trajectory since 2000
- BUT: TFP growth was SLOWING (from +2.7% to -1.0%) before embargo
- Our event study can test this: pre-treatment coefficients
- If agriculture was doing better anyway, we'd see positive pre-trends

### Proposed Approach
1. **Subsidies**: Acknowledge limitation, note World Bank finding that subsidies didn't boost productivity
2. **Ruble**: This is a CONFOUNDER we cannot fully separate; include in limitations
3. **Pre-trends**: Our event study addresses this; pre-2014 coefficients are near zero or negative
