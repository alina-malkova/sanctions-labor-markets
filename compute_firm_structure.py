"""
Compute regional firm structure measures from RFSD for RLMS matching.

Key insight from referee: Large firms dominate livestock (pork, poultry)
while small farms concentrate in dairy. We create proxies for this.
"""

import pandas as pd
import numpy as np

# Load RFSD regional panel
rfsd = pd.read_csv('RFSD_data/output/rfsd_regional_panel.csv')

# Filter to 2013 (pre-treatment baseline)
rfsd_2013 = rfsd[rfsd['year'] == 2013].copy()

print("=== RFSD Regional Data (2013) ===")
print(f"Regions: {len(rfsd_2013)}")
print(f"\nColumns available:")
print(rfsd_2013.columns.tolist())

# Create firm structure measures
# 1. Livestock dominance = proxy for large firm structure
#    (large agriholdings dominate pork/poultry; small farms in dairy)
rfsd_2013['n_livestock'] = rfsd_2013['n_meat_pork'] + rfsd_2013['n_meat_poultry']
rfsd_2013['n_animal'] = rfsd_2013['n_dairy'] + rfsd_2013['n_meat_beef'] + rfsd_2013['n_meat_pork'] + rfsd_2013['n_meat_poultry']

# Livestock share among animal products
rfsd_2013['livestock_dominance'] = rfsd_2013['n_livestock'] / rfsd_2013['n_animal'].replace(0, np.nan)

# 2. Dairy share (proxy for small farm structure)
rfsd_2013['dairy_share'] = rfsd_2013['n_dairy'] / rfsd_2013['n_animal'].replace(0, np.nan)

# 3. Firm concentration = agri firms as share of all firms
rfsd_2013['agri_concentration'] = rfsd_2013['share_food_agri']

# 4. Average firm "size" proxy = firms per product category
#    Regions with more product diversity may have larger operations
rfsd_2013['product_diversity'] = (
    (rfsd_2013['n_dairy'] > 0).astype(int) +
    (rfsd_2013['n_meat_beef'] > 0).astype(int) +
    (rfsd_2013['n_meat_pork'] > 0).astype(int) +
    (rfsd_2013['n_meat_poultry'] > 0).astype(int) +
    (rfsd_2013['n_fruits_veg'] > 0).astype(int) +
    (rfsd_2013['n_fish'] > 0).astype(int)
)

print("\n=== Firm Structure Measures ===")
print(rfsd_2013[['region_std', 'livestock_dominance', 'dairy_share', 'agri_concentration', 'product_diversity']].describe())

# Show distribution of livestock dominance
print("\n=== Livestock vs Dairy Regions ===")
rfsd_2013['firm_type'] = pd.cut(
    rfsd_2013['livestock_dominance'],
    bins=[0, 0.3, 0.5, 1.0],
    labels=['Dairy-dominant', 'Mixed', 'Livestock-dominant']
)
print(rfsd_2013.groupby('firm_type').agg({
    'region_std': 'count',
    'livestock_dominance': 'mean',
    'n_dairy': 'sum',
    'n_livestock': 'sum',
    'food_agri_firms': 'sum'
}).rename(columns={'region_std': 'n_regions'}))

# Create crosswalk for RLMS regions
# Map RFSD region names to RLMS PSU labels
region_crosswalk = {
    # Major matches based on region names
    'moscow oblast': 'Moscow Oblast',
    'st. petersburg': 'St. Petersburg City',
    'krasnodar krai': 'Krasnodarskij Kraj',
    'rostov oblast': 'Rostov Oblast',
    'chelyabinsk oblast': 'Cheliabinsk Oblast',
    'sverdlovsk oblast': 'Sverdlovsk Oblast',
    'nizhny novgorod oblast': 'Gorkovskaja Oblast: Nizhnij Novgorod',
    'novosibirsk oblast': 'Novosibirskaya Oblast',
    'samara oblast': 'Samara Oblast',
    'tatarstan': 'Tatarskaja ASSR',
    'bashkortostan': 'Bashkortostan',
    'perm krai': 'Perm Territory',
    'volgograd oblast': 'Volgograd Oblast',
    'saratov oblast': 'Saratov Oblast',
    'krasnoyarsk krai': 'Krasnojarskij Kraij',
    'voronezh oblast': 'Voronezh Oblast',
    'tula oblast': 'Tulskaja Oblast',
    'lipetzk': 'Lipetskaya Oblast',
    'tambov oblast': 'Tambov Oblast',
    'penza oblast': 'Penzenskaya Oblast',
    'kaluga oblast': 'Kaluzhskaya Oblast',
    'smolensk oblast': 'Smolensk Oblast',
    'leningrad oblast': 'Leningrad Oblast',
    'stavropol krai': 'Stavropolskij Kraj',
    'altai krai': 'Altaiskij Kraj',
    'amur oblast': 'Amurskaja Oblast',
    'tomsk': 'Tomsk',
    'komi republic': 'Komi-ASSR',
    'udmurt republic': 'Udmurt ASSR',
    'chuvash republic': 'Chuvashskaya ASSR',
    'kurgan oblast': 'Kurgan',
    'orenburg oblast': 'Orenburg Oblast',
    'kabardino-balkaria': 'Kabardino-Balkarija',
    'vladivostok': 'Vladivostok'
}

# Select key variables for export
export_cols = [
    'region_std', 'food_agri_firms', 'n_dairy', 'n_livestock',
    'livestock_dominance', 'dairy_share', 'agri_concentration',
    'treatment_intensity_product', 'treatment_intensity_combined'
]

rfsd_export = rfsd_2013[export_cols].copy()
rfsd_export = rfsd_export.rename(columns={'region_std': 'region_rfsd'})

# Fill missing values
rfsd_export['livestock_dominance'] = rfsd_export['livestock_dominance'].fillna(0.5)
rfsd_export['dairy_share'] = rfsd_export['dairy_share'].fillna(0.5)

# Create binary indicators
rfsd_export['high_livestock'] = (rfsd_export['livestock_dominance'] > rfsd_export['livestock_dominance'].median()).astype(int)
rfsd_export['high_dairy'] = (rfsd_export['dairy_share'] > rfsd_export['dairy_share'].median()).astype(int)

print("\n=== Export Summary ===")
print(rfsd_export.describe())

# Save for Stata merge
rfsd_export.to_csv('output/tables/region_firm_structure.csv', index=False)
print(f"\nSaved: output/tables/region_firm_structure.csv")

# Also save mapping info
print("\n=== Top Livestock-Dominant Regions ===")
print(rfsd_2013.nlargest(10, 'livestock_dominance')[['region_std', 'livestock_dominance', 'n_dairy', 'n_livestock', 'n_animal']])

print("\n=== Top Dairy-Dominant Regions ===")
print(rfsd_2013.nsmallest(10, 'livestock_dominance')[['region_std', 'livestock_dominance', 'n_dairy', 'n_livestock', 'n_animal']])
