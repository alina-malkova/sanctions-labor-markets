"""
RFSD Data Explorer
==================
Explore Russian Firm Statistical Database for sanctions analysis.
Identify agricultural firms and construct treatment intensity measures.

Usage:
    python explore_rfsd.py
"""

import polars as pl
from pathlib import Path
import sys

# Data directory
DATA_DIR = Path(__file__).parent
OUTPUT_DIR = DATA_DIR / "output"
OUTPUT_DIR.mkdir(exist_ok=True)

# OKVED codes for food/agriculture sectors (relevant to 2014 embargo)
# Section A: Agriculture, forestry, fishing
AGRI_OKVED_SECTIONS = ["A"]  # Primary agriculture

# More specific OKVED codes for food-related activities
# Based on Russian OKVED 2 classification
FOOD_OKVED_PREFIXES = [
    "01",    # Crop and animal production
    "03",    # Fishing and aquaculture
    "10",    # Manufacture of food products
    "11",    # Manufacture of beverages
    "46.2",  # Wholesale of agricultural raw materials
    "46.3",  # Wholesale of food, beverages, tobacco
    "47.2",  # Retail sale of food in specialized stores
]

# Products affected by 2014 embargo with import shares
EMBARGO_PRODUCTS = {
    "dairy_cheese": {"import_share": 0.35, "okved": ["10.5", "01.4"]},  # Dairy
    "meat_beef": {"import_share": 0.25, "okved": ["10.1", "01.4"]},     # Meat processing, cattle
    "pork": {"import_share": 0.25, "okved": ["10.1", "01.4"]},          # Meat processing
    "poultry": {"import_share": 0.15, "okved": ["10.1", "01.47"]},      # Poultry
    "fruits_vegetables": {"import_share": 0.65, "okved": ["10.3", "01.1", "01.2"]},  # Fruits/veg
    "fish": {"import_share": 0.30, "okved": ["10.2", "03"]},            # Fish processing
}


def load_rfsd_year(year: int) -> pl.LazyFrame:
    """Load RFSD data for a specific year."""
    # Try different file naming patterns
    patterns = [
        DATA_DIR / f"RFSD_{year}.parquet",
        DATA_DIR / f"RFSD_{year}_sample.parquet",
    ]

    for path in patterns:
        if path.exists():
            print(f"Loading {path.name}...")
            return pl.scan_parquet(path)

    raise FileNotFoundError(f"No RFSD file found for year {year}")


def explore_schema(lf: pl.LazyFrame, year: int):
    """Explore and print the schema of the dataset."""
    print(f"\n{'='*60}")
    print(f"RFSD {year} - Schema Overview")
    print(f"{'='*60}")

    schema = lf.collect_schema()
    print(f"\nTotal columns: {len(schema)}")

    # Group columns by type
    col_types = {}
    for col, dtype in schema.items():
        dtype_str = str(dtype)
        if dtype_str not in col_types:
            col_types[dtype_str] = []
        col_types[dtype_str].append(col)

    print("\nColumns by type:")
    for dtype, cols in sorted(col_types.items()):
        print(f"  {dtype}: {len(cols)} columns")
        if len(cols) <= 10:
            for c in cols:
                print(f"    - {c}")

    return schema


def explore_key_columns(lf: pl.LazyFrame, year: int):
    """Explore key columns for the analysis."""
    print(f"\n{'='*60}")
    print(f"RFSD {year} - Key Column Analysis")
    print(f"{'='*60}")

    # Sample data
    df_sample = lf.head(1000).collect()

    # Key columns to examine
    key_cols = ["inn", "ogrn", "region", "okved", "okved_section",
                "creation_date", "dissolution_date", "age"]

    available_cols = [c for c in key_cols if c in df_sample.columns]

    print(f"\nAvailable key columns: {available_cols}")

    for col in available_cols:
        print(f"\n--- {col} ---")
        non_null = df_sample[col].drop_nulls()
        print(f"  Non-null values: {len(non_null)}/{len(df_sample)}")
        if len(non_null) > 0:
            print(f"  Sample values: {non_null.head(5).to_list()}")
            if df_sample[col].dtype in [pl.Utf8, pl.String]:
                unique = non_null.unique()
                print(f"  Unique values (sample): {unique.head(10).to_list()}")

    return df_sample


def analyze_okved_distribution(lf: pl.LazyFrame, year: int):
    """Analyze OKVED code distribution to identify agricultural firms."""
    print(f"\n{'='*60}")
    print(f"RFSD {year} - OKVED Distribution Analysis")
    print(f"{'='*60}")

    # Check if okved columns exist
    schema = lf.collect_schema()

    okved_col = "okved" if "okved" in schema else None
    section_col = "okved_section" if "okved_section" in schema else None

    results = {}

    if section_col:
        print(f"\n--- OKVED Section Distribution ---")
        section_dist = (
            lf.group_by(section_col)
            .agg(pl.len().alias("count"))
            .sort("count", descending=True)
            .collect()
        )
        print(section_dist.head(20))
        results["section_dist"] = section_dist

        # Agricultural sector (Section A)
        agri_count = section_dist.filter(pl.col(section_col) == "A")
        if len(agri_count) > 0:
            total = section_dist["count"].sum()
            agri_n = agri_count["count"][0]
            print(f"\nAgricultural firms (Section A): {agri_n:,} ({100*agri_n/total:.2f}%)")

    if okved_col:
        print(f"\n--- Top OKVED Codes (2-digit) ---")
        # Extract first 2 digits of OKVED
        okved_2digit = (
            lf.with_columns(
                pl.col(okved_col).str.slice(0, 2).alias("okved_2d")
            )
            .group_by("okved_2d")
            .agg(pl.len().alias("count"))
            .sort("count", descending=True)
            .collect()
        )
        print(okved_2digit.head(20))
        results["okved_2digit"] = okved_2digit

        # Food-related OKVED codes
        print(f"\n--- Food/Agriculture Related OKVED Codes ---")
        for prefix in FOOD_OKVED_PREFIXES:
            food_firms = (
                lf.filter(pl.col(okved_col).str.starts_with(prefix))
                .select(pl.len().alias("count"))
                .collect()
            )
            if food_firms["count"][0] > 0:
                print(f"  {prefix}*: {food_firms['count'][0]:,} firms")

    return results


def analyze_regional_distribution(lf: pl.LazyFrame, year: int):
    """Analyze regional distribution of firms."""
    print(f"\n{'='*60}")
    print(f"RFSD {year} - Regional Distribution")
    print(f"{'='*60}")

    schema = lf.collect_schema()
    region_col = "region" if "region" in schema else None

    if not region_col:
        print("No region column found")
        return None

    region_dist = (
        lf.group_by(region_col)
        .agg(pl.len().alias("count"))
        .sort("count", descending=True)
        .collect()
    )

    print(f"\nTop 20 regions by firm count:")
    print(region_dist.head(20))

    print(f"\nTotal regions: {len(region_dist)}")

    return region_dist


def identify_agricultural_firms(lf: pl.LazyFrame, year: int) -> pl.DataFrame:
    """Identify and extract agricultural/food-related firms."""
    print(f"\n{'='*60}")
    print(f"RFSD {year} - Extracting Agricultural Firms")
    print(f"{'='*60}")

    schema = lf.collect_schema()
    okved_col = "okved" if "okved" in schema else None
    section_col = "okved_section" if "okved_section" in schema else None

    if not okved_col and not section_col:
        print("No OKVED columns found - cannot identify agricultural firms")
        return None

    # Build filter condition
    conditions = []

    if section_col:
        conditions.append(pl.col(section_col).is_in(AGRI_OKVED_SECTIONS))

    if okved_col:
        for prefix in FOOD_OKVED_PREFIXES:
            conditions.append(pl.col(okved_col).str.starts_with(prefix))

    if not conditions:
        return None

    # Combine with OR
    combined_filter = conditions[0]
    for cond in conditions[1:]:
        combined_filter = combined_filter | cond

    # Extract agricultural firms
    agri_firms = lf.filter(combined_filter).collect()

    print(f"\nAgricultural/food firms identified: {len(agri_firms):,}")

    # Summary by OKVED section if available
    if section_col and len(agri_firms) > 0:
        print("\nBreakdown by OKVED section:")
        breakdown = agri_firms.group_by(section_col).agg(pl.len().alias("count")).sort("count", descending=True)
        print(breakdown)

    return agri_firms


def compute_summary_statistics(lf: pl.LazyFrame, year: int):
    """Compute summary statistics for key financial variables."""
    print(f"\n{'='*60}")
    print(f"RFSD {year} - Financial Summary Statistics")
    print(f"{'='*60}")

    schema = lf.collect_schema()

    # Look for common financial variables
    # Balance sheet: 1100s (assets), 1600 (total assets)
    # Income statement: 2110 (revenue), 2400 (net income)
    financial_cols = []
    for col in schema:
        if col.startswith("line_") or col.isdigit() or (col[0].isdigit() and len(col) == 4):
            financial_cols.append(col)

    if not financial_cols:
        # Try finding columns that look like financial statement lines
        for col in schema:
            if any(x in col.lower() for x in ["revenue", "asset", "profit", "income", "wage"]):
                financial_cols.append(col)

    print(f"\nPotential financial columns found: {len(financial_cols)}")
    if financial_cols:
        print(f"Sample: {financial_cols[:10]}")

    # Basic count
    total_firms = lf.select(pl.len()).collect().item()
    print(f"\nTotal firms in dataset: {total_firms:,}")

    return financial_cols


def save_agricultural_firms(agri_df: pl.DataFrame, year: int):
    """Save agricultural firms to parquet file."""
    if agri_df is None or len(agri_df) == 0:
        print(f"No agricultural firms to save for {year}")
        return

    output_path = OUTPUT_DIR / f"agri_firms_{year}.parquet"
    agri_df.write_parquet(output_path)
    print(f"\nSaved {len(agri_df):,} agricultural firms to {output_path}")


def main():
    """Main exploration function."""
    print("="*60)
    print("RFSD Data Explorer for Sanctions Analysis")
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

    if not available_years:
        print("No RFSD data files found!")
        sys.exit(1)

    # Analyze each year
    all_results = {}

    for year in available_years:
        try:
            lf = load_rfsd_year(year)

            # Explore schema (only for first year to understand structure)
            if year == available_years[0]:
                schema = explore_schema(lf, year)
                sample = explore_key_columns(lf, year)
                fin_cols = compute_summary_statistics(lf, year)

            # OKVED analysis for all years
            okved_results = analyze_okved_distribution(lf, year)

            # Regional distribution
            region_dist = analyze_regional_distribution(lf, year)

            # Extract agricultural firms
            agri_firms = identify_agricultural_firms(lf, year)

            # Save agricultural firms
            save_agricultural_firms(agri_firms, year)

            all_results[year] = {
                "okved": okved_results,
                "regions": region_dist,
                "agri_firms_count": len(agri_firms) if agri_firms is not None else 0
            }

        except FileNotFoundError as e:
            print(f"Skipping {year}: {e}")
            continue
        except Exception as e:
            print(f"Error processing {year}: {e}")
            import traceback
            traceback.print_exc()
            continue

    # Summary across years
    print(f"\n{'='*60}")
    print("SUMMARY: Agricultural Firms by Year")
    print(f"{'='*60}")

    for year, results in sorted(all_results.items()):
        print(f"  {year}: {results['agri_firms_count']:,} agricultural/food firms")

    print(f"\n{'='*60}")
    print("Analysis Complete!")
    print(f"{'='*60}")
    print(f"\nOutput files saved to: {OUTPUT_DIR}")
    print("\nNext steps:")
    print("1. Review agricultural firm extracts in output/")
    print("2. Match with RLMS data using region codes")
    print("3. Construct treatment intensity measures by region")


if __name__ == "__main__":
    main()
