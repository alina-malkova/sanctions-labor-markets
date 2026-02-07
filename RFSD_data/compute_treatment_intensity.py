"""
Compute Regional Treatment Intensity for Food Embargo Analysis
===============================================================
Creates regional exposure measures for Russia's 2014 food import ban.

Treatment intensity = f(regional agri specialization, product mix, pre-ban import shares)

Output: Stata .dta files ready to merge with RLMS data.
"""

import polars as pl
from pathlib import Path
import json

# Paths
DATA_DIR = Path(__file__).parent
OUTPUT_DIR = DATA_DIR / "output"
OUTPUT_DIR.mkdir(exist_ok=True)

# Pre-ban import shares by product category (from literature)
# These represent the share of domestic consumption that came from imports
IMPORT_SHARES = {
    "dairy": 0.35,           # Dairy products, cheese
    "meat_beef": 0.25,       # Beef
    "meat_pork": 0.25,       # Pork
    "meat_poultry": 0.15,    # Poultry
    "fruits_veg": 0.65,      # Fruits and vegetables
    "fish": 0.30,            # Fish and seafood
}

# OKVED codes mapping to embargo product categories
# Based on OKVED 2 classification
OKVED_TO_PRODUCT = {
    # Dairy
    "01.41": "dairy",    # Dairy cattle
    "01.45": "dairy",    # Sheep/goat (some dairy)
    "10.51": "dairy",    # Dairy processing
    "10.52": "dairy",    # Ice cream

    # Beef
    "01.42": "meat_beef",  # Cattle (beef)
    "10.11": "meat_beef",  # Meat processing (partial)

    # Pork
    "01.46": "meat_pork",  # Pig farming

    # Poultry
    "01.47": "meat_poultry",  # Poultry farming

    # Fruits and vegetables
    "01.1": "fruits_veg",    # Growing of non-perennial crops
    "01.11": "fruits_veg",   # Cereals (less affected, but related)
    "01.13": "fruits_veg",   # Vegetables
    "01.2": "fruits_veg",    # Growing of perennial crops
    "01.21": "fruits_veg",   # Grapes
    "01.24": "fruits_veg",   # Pome fruits
    "01.25": "fruits_veg",   # Other fruits
    "10.3": "fruits_veg",    # Fruit/veg processing
    "10.31": "fruits_veg",   # Potato processing
    "10.32": "fruits_veg",   # Fruit/veg juice
    "10.39": "fruits_veg",   # Other fruit/veg processing

    # Fish
    "03": "fish",         # Fishing
    "03.1": "fish",       # Fishing
    "03.11": "fish",      # Marine fishing
    "03.12": "fish",      # Freshwater fishing
    "03.2": "fish",       # Aquaculture
    "10.2": "fish",       # Fish processing
    "10.20": "fish",      # Fish processing
}

# General food/agri codes (for total agri employment measure)
FOOD_AGRI_PREFIXES = ["01", "03", "10", "11", "46.2", "46.3", "47.2"]


def load_rfsd_year(year: int) -> pl.LazyFrame:
    """Load RFSD data for a specific year."""
    patterns = [
        DATA_DIR / f"RFSD_{year}.parquet",
        DATA_DIR / f"RFSD_{year}_sample.parquet",
    ]
    for path in patterns:
        if path.exists():
            return pl.scan_parquet(path)
    raise FileNotFoundError(f"No RFSD file found for year {year}")


def classify_firm_product(okved: str) -> str | None:
    """Classify a firm's OKVED code to embargo product category."""
    if okved is None:
        return None

    # Try exact match first
    if okved in OKVED_TO_PRODUCT:
        return OKVED_TO_PRODUCT[okved]

    # Try prefix matches (longer prefixes first)
    for prefix_len in [4, 3, 2]:
        prefix = okved[:prefix_len] if len(okved) >= prefix_len else okved
        if prefix in OKVED_TO_PRODUCT:
            return OKVED_TO_PRODUCT[prefix]

    return None


def is_food_agri_firm(okved: str) -> bool:
    """Check if firm is in food/agriculture sector."""
    if okved is None:
        return False
    return any(okved.startswith(prefix) for prefix in FOOD_AGRI_PREFIXES)


def compute_regional_measures(year: int) -> pl.DataFrame:
    """Compute treatment intensity measures by region for a given year."""
    print(f"\nProcessing year {year}...")

    lf = load_rfsd_year(year)

    # Collect relevant columns
    df = lf.select([
        "region",
        "okved",
        "okved_section",
    ]).collect()

    print(f"  Total firms: {len(df):,}")

    # Add product category classification
    df = df.with_columns([
        pl.col("okved").map_elements(
            classify_firm_product,
            return_dtype=pl.Utf8
        ).alias("product_category"),
        pl.col("okved").map_elements(
            is_food_agri_firm,
            return_dtype=pl.Boolean
        ).alias("is_food_agri"),
    ])

    # Compute regional aggregates
    regional_stats = (
        df.group_by("region")
        .agg([
            # Total firms
            pl.len().alias("total_firms"),

            # Food/agri firms
            pl.col("is_food_agri").sum().alias("food_agri_firms"),

            # By product category
            (pl.col("product_category") == "dairy").sum().alias("n_dairy"),
            (pl.col("product_category") == "meat_beef").sum().alias("n_meat_beef"),
            (pl.col("product_category") == "meat_pork").sum().alias("n_meat_pork"),
            (pl.col("product_category") == "meat_poultry").sum().alias("n_meat_poultry"),
            (pl.col("product_category") == "fruits_veg").sum().alias("n_fruits_veg"),
            (pl.col("product_category") == "fish").sum().alias("n_fish"),

            # Section A (primary agriculture)
            (pl.col("okved_section") == "A").sum().alias("n_section_a"),
        ])
        .filter(pl.col("region").is_not_null())
    )

    # Compute shares and treatment intensity
    regional_stats = regional_stats.with_columns([
        # Share of food/agri firms
        (pl.col("food_agri_firms") / pl.col("total_firms")).alias("share_food_agri"),

        # Share of primary agriculture
        (pl.col("n_section_a") / pl.col("total_firms")).alias("share_agri_primary"),

        # Product-specific shares (of food/agri firms)
        (pl.col("n_dairy") / pl.col("food_agri_firms")).fill_nan(0).alias("share_dairy"),
        (pl.col("n_meat_beef") / pl.col("food_agri_firms")).fill_nan(0).alias("share_meat_beef"),
        (pl.col("n_meat_pork") / pl.col("food_agri_firms")).fill_nan(0).alias("share_meat_pork"),
        (pl.col("n_meat_poultry") / pl.col("food_agri_firms")).fill_nan(0).alias("share_meat_poultry"),
        (pl.col("n_fruits_veg") / pl.col("food_agri_firms")).fill_nan(0).alias("share_fruits_veg"),
        (pl.col("n_fish") / pl.col("food_agri_firms")).fill_nan(0).alias("share_fish"),
    ])

    # Compute treatment intensity as weighted sum of product shares × import shares
    # This captures: regions specialized in high-import products get higher treatment
    regional_stats = regional_stats.with_columns([
        (
            pl.col("share_dairy") * IMPORT_SHARES["dairy"] +
            pl.col("share_meat_beef") * IMPORT_SHARES["meat_beef"] +
            pl.col("share_meat_pork") * IMPORT_SHARES["meat_pork"] +
            pl.col("share_meat_poultry") * IMPORT_SHARES["meat_poultry"] +
            pl.col("share_fruits_veg") * IMPORT_SHARES["fruits_veg"] +
            pl.col("share_fish") * IMPORT_SHARES["fish"]
        ).alias("treatment_intensity_product"),
    ])

    # Combined treatment intensity: agri share × product-weighted intensity
    regional_stats = regional_stats.with_columns([
        (pl.col("share_food_agri") * pl.col("treatment_intensity_product"))
        .alias("treatment_intensity_combined"),
    ])

    # Add year
    regional_stats = regional_stats.with_columns([
        pl.lit(year).alias("year"),
    ])

    print(f"  Regions with data: {len(regional_stats)}")

    return regional_stats


def standardize_region_names(df: pl.DataFrame) -> pl.DataFrame:
    """Standardize region names for RLMS matching."""
    # RLMS uses specific region coding - create mapping
    # This is a partial mapping; may need adjustment based on RLMS region names

    region_mapping = {
        "moscow city": "moscow",
        "moscow reg.": "moscow oblast",
        "sankt-petersburg": "st. petersburg",
        "leningrad": "leningrad oblast",
        "tatarstan": "tatarstan",
        "bashkortostan": "bashkortostan",
        "krasnodar": "krasnodar krai",
        "krasnoyarsk": "krasnoyarsk krai",
        "sverdlovsk": "sverdlovsk oblast",
        "novosibirsk": "novosibirsk oblast",
        "chelyabinsk": "chelyabinsk oblast",
        "nizhni novgorod": "nizhny novgorod oblast",
        "samara": "samara oblast",
        "rostov": "rostov oblast",
        "perm": "perm krai",
        "volgograd": "volgograd oblast",
        "voronezh": "voronezh oblast",
        "saratov": "saratov oblast",
        "tyumen": "tyumen oblast",
        "altai terr.": "altai krai",
        "irkutsk": "irkutsk oblast",
        "omsk": "omsk oblast",
        "kemerovo": "kemerovo oblast",
        "orenburg": "orenburg oblast",
        "kaliningrad": "kaliningrad oblast",
        "tula": "tula oblast",
        "stavropol": "stavropol krai",
        "belgorod": "belgorod oblast",
        "lipetsk": "lipetsk oblast",
        "kursk": "kursk oblast",
        "tver": "tver oblast",
        "yaroslavl": "yaroslavl oblast",
        "vladimir": "vladimir oblast",
        "bryansk": "bryansk oblast",
        "arkhangelsk": "arkhangelsk oblast",
        "murmansk": "murmansk oblast",
        "kaluga": "kaluga oblast",
        "smolensk": "smolensk oblast",
        "ryazan": "ryazan oblast",
        "tambov": "tambov oblast",
        "penza": "penza oblast",
        "ulyanovsk": "ulyanovsk oblast",
        "chuvashia": "chuvash republic",
        "mordovia": "mordovia",
        "udmurtia": "udmurt republic",
        "kirov": "kirov oblast",
        "vologda": "vologda oblast",
        "komi": "komi republic",
        "karelia": "republic of karelia",
        "dagestan": "dagestan",
        "crimea": "republic of crimea",
        "sevastopol": "sevastopol",
    }

    # Keep original and add standardized version
    df = df.with_columns([
        pl.col("region").alias("region_rfsd"),
        pl.col("region").replace(region_mapping).alias("region_std"),
    ])

    return df


def export_to_stata(df: pl.DataFrame, filename: str):
    """Export DataFrame to CSV format (Stata-compatible)."""
    # Export as CSV - can be imported to Stata with: import delimited
    csv_filename = filename.replace(".dta", ".csv")
    output_path = OUTPUT_DIR / csv_filename
    df.write_csv(output_path)
    print(f"  Saved: {output_path}")
    print(f"    Stata: import delimited \"{output_path.name}\", clear")


def create_panel_dataset(years: list[int]) -> pl.DataFrame:
    """Create panel dataset with all years."""
    all_years = []

    for year in years:
        try:
            regional_stats = compute_regional_measures(year)
            all_years.append(regional_stats)
        except FileNotFoundError:
            print(f"  Skipping {year}: file not found")
            continue

    if not all_years:
        raise ValueError("No data found for any year")

    # Combine all years
    panel = pl.concat(all_years)

    # Standardize region names
    panel = standardize_region_names(panel)

    return panel


def create_baseline_measures(panel: pl.DataFrame, baseline_year: int = 2013) -> pl.DataFrame:
    """Create baseline (pre-treatment) measures for each region."""
    baseline = (
        panel
        .filter(pl.col("year") == baseline_year)
        .select([
            "region",
            "region_rfsd",
            "region_std",
            pl.col("total_firms").alias("baseline_total_firms"),
            pl.col("food_agri_firms").alias("baseline_food_agri_firms"),
            pl.col("share_food_agri").alias("baseline_share_food_agri"),
            pl.col("share_agri_primary").alias("baseline_share_agri_primary"),
            pl.col("treatment_intensity_product").alias("baseline_treatment_product"),
            pl.col("treatment_intensity_combined").alias("baseline_treatment_combined"),
            pl.col("share_dairy").alias("baseline_share_dairy"),
            pl.col("share_meat_beef").alias("baseline_share_meat_beef"),
            pl.col("share_meat_pork").alias("baseline_share_meat_pork"),
            pl.col("share_meat_poultry").alias("baseline_share_meat_poultry"),
            pl.col("share_fruits_veg").alias("baseline_share_fruits_veg"),
            pl.col("share_fish").alias("baseline_share_fish"),
        ])
    )

    return baseline


def create_treatment_terciles(baseline: pl.DataFrame) -> pl.DataFrame:
    """Create treatment terciles for heterogeneity analysis."""
    # Compute tercile cutoffs
    treatment_vals = baseline["baseline_treatment_combined"].drop_nulls().to_numpy()
    tercile_1 = float(pl.Series(treatment_vals).quantile(0.33))
    tercile_2 = float(pl.Series(treatment_vals).quantile(0.67))

    baseline = baseline.with_columns([
        pl.when(pl.col("baseline_treatment_combined") <= tercile_1)
        .then(pl.lit(1))
        .when(pl.col("baseline_treatment_combined") <= tercile_2)
        .then(pl.lit(2))
        .otherwise(pl.lit(3))
        .alias("treatment_tercile"),

        # Binary high/low treatment
        pl.when(pl.col("baseline_treatment_combined") > baseline["baseline_treatment_combined"].median())
        .then(pl.lit(1))
        .otherwise(pl.lit(0))
        .alias("high_treatment"),
    ])

    print(f"\nTreatment tercile cutoffs:")
    print(f"  Low (tercile 1): <= {tercile_1:.4f}")
    print(f"  Medium (tercile 2): {tercile_1:.4f} - {tercile_2:.4f}")
    print(f"  High (tercile 3): > {tercile_2:.4f}")

    return baseline


def main():
    """Main function to compute all treatment measures."""
    print("="*60)
    print("Computing Regional Treatment Intensity Measures")
    print("="*60)

    # Find available years
    available_years = []
    for f in DATA_DIR.glob("RFSD_*.parquet"):
        try:
            year = int(f.stem.split("_")[1])
            available_years.append(year)
        except (IndexError, ValueError):
            continue

    available_years = sorted(available_years)
    print(f"\nAvailable years: {available_years}")

    # Create panel dataset
    print("\n" + "="*60)
    print("Creating Panel Dataset")
    print("="*60)
    panel = create_panel_dataset(available_years)

    # Create baseline measures (pre-treatment)
    print("\n" + "="*60)
    print("Creating Baseline (Pre-Treatment) Measures")
    print("="*60)
    baseline_year = min(y for y in available_years if y < 2014) if any(y < 2014 for y in available_years) else available_years[0]
    print(f"Using {baseline_year} as baseline year")

    baseline = create_baseline_measures(panel, baseline_year)
    baseline = create_treatment_terciles(baseline)

    # Summary statistics
    print("\n" + "="*60)
    print("Summary Statistics: Treatment Intensity")
    print("="*60)

    print("\nBaseline treatment intensity by region (top 15):")
    top_regions = (
        baseline
        .sort("baseline_treatment_combined", descending=True)
        .select(["region", "baseline_share_food_agri", "baseline_treatment_combined", "treatment_tercile"])
        .head(15)
    )
    print(top_regions)

    print("\nBaseline treatment intensity by region (bottom 15):")
    bottom_regions = (
        baseline
        .sort("baseline_treatment_combined")
        .select(["region", "baseline_share_food_agri", "baseline_treatment_combined", "treatment_tercile"])
        .head(15)
    )
    print(bottom_regions)

    print("\nDescriptive statistics:")
    print(f"  Mean treatment intensity: {baseline['baseline_treatment_combined'].mean():.4f}")
    print(f"  Std treatment intensity: {baseline['baseline_treatment_combined'].std():.4f}")
    print(f"  Min: {baseline['baseline_treatment_combined'].min():.4f}")
    print(f"  Max: {baseline['baseline_treatment_combined'].max():.4f}")

    # Export to Stata
    print("\n" + "="*60)
    print("Exporting to Stata Format")
    print("="*60)

    # Panel data (all years)
    export_to_stata(panel, "rfsd_regional_panel.dta")

    # Baseline measures (for merging with RLMS)
    export_to_stata(baseline, "rfsd_treatment_intensity.dta")

    # Also save as parquet
    panel.write_parquet(OUTPUT_DIR / "rfsd_regional_panel.parquet")
    baseline.write_parquet(OUTPUT_DIR / "rfsd_treatment_intensity.parquet")
    print(f"  Saved parquet files")

    # Save variable descriptions
    var_descriptions = {
        "region": "Region name (RFSD original)",
        "region_rfsd": "Region name (RFSD original)",
        "region_std": "Region name (standardized for RLMS matching)",
        "year": "Year of observation",
        "total_firms": "Total number of firms in region",
        "food_agri_firms": "Number of food/agriculture firms",
        "share_food_agri": "Share of food/agri firms in region",
        "share_agri_primary": "Share of primary agriculture (Section A) firms",
        "n_dairy": "Number of dairy firms",
        "n_meat_beef": "Number of beef firms",
        "n_meat_pork": "Number of pork firms",
        "n_meat_poultry": "Number of poultry firms",
        "n_fruits_veg": "Number of fruits/vegetables firms",
        "n_fish": "Number of fish/seafood firms",
        "share_dairy": "Share of dairy in food/agri sector",
        "share_meat_beef": "Share of beef in food/agri sector",
        "share_meat_pork": "Share of pork in food/agri sector",
        "share_meat_poultry": "Share of poultry in food/agri sector",
        "share_fruits_veg": "Share of fruits/veg in food/agri sector",
        "share_fish": "Share of fish in food/agri sector",
        "treatment_intensity_product": "Product-weighted treatment intensity (sum of product_share × import_share)",
        "treatment_intensity_combined": "Combined treatment intensity (share_food_agri × treatment_intensity_product)",
        "baseline_*": "Baseline (pre-2014) values of corresponding variables",
        "treatment_tercile": "Treatment tercile (1=low, 2=medium, 3=high)",
        "high_treatment": "Binary indicator for above-median treatment intensity",
    }

    with open(OUTPUT_DIR / "variable_descriptions.json", "w") as f:
        json.dump(var_descriptions, f, indent=2)
    print(f"  Saved variable descriptions")

    # Print import shares used
    print("\n" + "="*60)
    print("Import Shares Used in Treatment Intensity Calculation")
    print("="*60)
    for product, share in IMPORT_SHARES.items():
        print(f"  {product}: {share:.0%}")

    print("\n" + "="*60)
    print("Complete!")
    print("="*60)
    print(f"\nOutput files in: {OUTPUT_DIR}")
    print("\nFor Stata, use:")
    print('  use "RFSD_data/output/rfsd_treatment_intensity.dta", clear')
    print('  merge m:1 region using "rfsd_treatment_intensity.dta"')


if __name__ == "__main__":
    main()
