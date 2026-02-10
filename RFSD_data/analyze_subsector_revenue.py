"""
Sub-Sector Analysis: Revenue and Firm Size
==========================================
Analyzes revenue growth by sub-sector to show consolidation in successful
import substitution sectors (pork, poultry) vs failure sectors (dairy, fruit).

Key hypothesis: Successful sectors show
- Fewer firms (consolidation)
- BUT higher total revenue (production increased)
- AND higher revenue per firm (larger operations)
"""

import polars as pl
from pathlib import Path
import numpy as np

DATA_DIR = Path(__file__).parent
OUTPUT_DIR = DATA_DIR / "output"

# OKVED codes mapping
OKVED_TO_PRODUCT = {
    "01.41": "dairy", "01.45": "dairy", "10.51": "dairy", "10.52": "dairy",
    "01.42": "meat_beef", "10.11": "meat_beef",
    "01.46": "meat_pork",
    "01.47": "meat_poultry",
    "01.1": "fruits_veg", "01.11": "fruits_veg", "01.13": "fruits_veg",
    "01.2": "fruits_veg", "01.21": "fruits_veg", "01.24": "fruits_veg",
    "01.25": "fruits_veg", "10.3": "fruits_veg", "10.31": "fruits_veg",
    "10.32": "fruits_veg", "10.39": "fruits_veg",
    "03": "fish", "03.1": "fish", "03.11": "fish", "03.12": "fish",
    "03.2": "fish", "10.2": "fish", "10.20": "fish",
}

SUBSECTOR_CATEGORY = {
    "meat_pork": "SUCCESS",
    "meat_poultry": "SUCCESS",
    "dairy": "FAILURE",
    "fruits_veg": "FAILURE",
    "meat_beef": "MIXED",
    "fish": "MIXED",
}


def classify_firm_product(okved: str) -> str | None:
    if okved is None:
        return None
    if okved in OKVED_TO_PRODUCT:
        return OKVED_TO_PRODUCT[okved]
    for prefix_len in [5, 4, 3, 2]:
        if len(okved) >= prefix_len:
            prefix = okved[:prefix_len]
            if prefix in OKVED_TO_PRODUCT:
                return OKVED_TO_PRODUCT[prefix]
    return None


def analyze_revenue_by_subsector():
    """Analyze total and per-firm revenue by sub-sector."""
    print("=" * 70)
    print("Revenue Analysis by Sub-Sector")
    print("=" * 70)

    available_years = []
    for f in DATA_DIR.glob("RFSD_*.parquet"):
        try:
            year = int(f.stem.split("_")[1])
            available_years.append(year)
        except:
            continue

    available_years = sorted(available_years)
    print(f"Available years: {available_years}")

    all_results = []

    for year in available_years:
        print(f"\nProcessing {year}...")

        try:
            df = pl.scan_parquet(DATA_DIR / f"RFSD_{year}.parquet").select([
                "okved", "region", "line_2110", "line_2400", "line_1600", "line_6100"
            ]).collect()

            print(f"  Total firms: {len(df):,}")

            # Classify products
            df = df.with_columns([
                pl.col("okved").map_elements(classify_firm_product, return_dtype=pl.Utf8).alias("product")
            ])

            # Filter to classified products only and valid revenue
            df_sub = df.filter(
                (pl.col("product").is_not_null()) &
                (pl.col("line_2110").is_not_null()) &
                (pl.col("line_2110") > 0)
            )

            print(f"  Firms with product classification and revenue: {len(df_sub):,}")

            # Aggregate by product
            agg = df_sub.group_by("product").agg([
                pl.len().alias("n_firms"),
                pl.col("line_2110").sum().alias("total_revenue"),
                pl.col("line_2110").mean().alias("mean_revenue"),
                pl.col("line_2110").median().alias("median_revenue"),
                pl.col("line_2400").sum().alias("total_profit"),
                pl.col("line_2400").mean().alias("mean_profit"),
                pl.col("line_1600").sum().alias("total_assets"),
                pl.col("line_1600").mean().alias("mean_assets"),
                pl.col("line_6100").sum().alias("total_employment"),
                pl.col("line_6100").mean().alias("mean_employment"),
            ]).with_columns([
                pl.lit(year).alias("year")
            ])

            all_results.append(agg)

            # Print summary
            print(f"\n  Sub-sector summary (revenue in millions RUB):")
            for row in agg.sort("total_revenue", descending=True).iter_rows(named=True):
                cat = SUBSECTOR_CATEGORY.get(row['product'], 'UNK')
                rev_m = row['total_revenue'] / 1e6 if row['total_revenue'] else 0
                mean_rev_k = row['mean_revenue'] / 1e3 if row['mean_revenue'] else 0
                print(f"    {row['product']:15} [{cat:7}]: {row['n_firms']:,} firms, "
                      f"Total rev: {rev_m:,.0f}M, Mean: {mean_rev_k:,.0f}K")

        except Exception as e:
            print(f"  Error: {e}")
            import traceback
            traceback.print_exc()
            continue

    if not all_results:
        print("No data!")
        return None

    panel = pl.concat(all_results)

    # Create summary table
    print("\n" + "=" * 70)
    print("PANEL DATA: REVENUE BY SUB-SECTOR OVER TIME")
    print("=" * 70)

    # Pivot for total revenue
    revenue_wide = panel.pivot(
        index="product",
        on="year",
        values="total_revenue"
    )
    print("\nTotal Revenue (RUB):")
    print(revenue_wide)

    # Pivot for firm count
    firms_wide = panel.pivot(
        index="product",
        on="year",
        values="n_firms"
    )
    print("\nFirm Counts:")
    print(firms_wide)

    # Pivot for mean revenue per firm
    mean_rev_wide = panel.pivot(
        index="product",
        on="year",
        values="mean_revenue"
    )
    print("\nMean Revenue per Firm (RUB):")
    print(mean_rev_wide)

    # Compute growth rates
    print("\n" + "=" * 70)
    print("GROWTH ANALYSIS: 2013 → 2023")
    print("=" * 70)

    year_cols = [str(c) for c in revenue_wide.columns if str(c).isdigit()]
    if '2013' in year_cols and '2023' in year_cols:
        results = []
        for row in revenue_wide.iter_rows(named=True):
            product = row['product']
            cat = SUBSECTOR_CATEGORY.get(product, 'UNK')

            rev_2013 = row.get('2013', 0) or 0
            rev_2023 = row.get('2023', 0) or 0

            # Get firm counts
            firms_row = firms_wide.filter(pl.col('product') == product)
            firms_2013 = firms_row['2013'][0] if len(firms_row) > 0 and '2013' in firms_row.columns else 0
            firms_2023 = firms_row['2023'][0] if len(firms_row) > 0 and '2023' in firms_row.columns else 0

            # Get mean revenue
            mean_row = mean_rev_wide.filter(pl.col('product') == product)
            mean_2013 = mean_row['2013'][0] if len(mean_row) > 0 and '2013' in mean_row.columns else 0
            mean_2023 = mean_row['2023'][0] if len(mean_row) > 0 and '2023' in mean_row.columns else 0

            # Growth rates
            rev_growth = ((rev_2023 - rev_2013) / rev_2013 * 100) if rev_2013 > 0 else None
            firms_growth = ((firms_2023 - firms_2013) / firms_2013 * 100) if firms_2013 > 0 else None
            mean_growth = ((mean_2023 - mean_2013) / mean_2013 * 100) if mean_2013 > 0 else None

            results.append({
                'product': product,
                'category': cat,
                'total_rev_growth_pct': rev_growth,
                'firm_count_growth_pct': firms_growth,
                'mean_rev_growth_pct': mean_growth,
                'rev_2013_B': rev_2013 / 1e9,
                'rev_2023_B': rev_2023 / 1e9,
                'firms_2013': firms_2013,
                'firms_2023': firms_2023,
            })

        results_df = pl.DataFrame(results).sort(['category', 'total_rev_growth_pct'], descending=[False, True])

        print("\nGrowth Summary:")
        print(results_df.select(['product', 'category', 'total_rev_growth_pct', 'firm_count_growth_pct', 'mean_rev_growth_pct']))

        # Summary by category
        print("\n" + "-" * 50)
        print("MECHANISM TEST: SUCCESS vs FAILURE")
        print("-" * 50)

        for cat in ['SUCCESS', 'FAILURE', 'MIXED']:
            cat_data = results_df.filter(pl.col('category') == cat)
            if len(cat_data) > 0:
                print(f"\n{cat} sectors:")
                for row in cat_data.iter_rows(named=True):
                    rev_g = row['total_rev_growth_pct']
                    firms_g = row['firm_count_growth_pct']
                    mean_g = row['mean_rev_growth_pct']
                    print(f"  {row['product']:15}:")
                    print(f"    Revenue: {row['rev_2013_B']:.1f}B → {row['rev_2023_B']:.1f}B ({rev_g:+.0f}%)" if rev_g else f"    Revenue: N/A")
                    print(f"    Firms: {row['firms_2013']:,} → {row['firms_2023']:,} ({firms_g:+.0f}%)" if firms_g else f"    Firms: N/A")
                    print(f"    Mean Rev/Firm: {mean_g:+.0f}% growth" if mean_g else f"    Mean Rev/Firm: N/A")

                # Category averages
                avg_rev = cat_data['total_rev_growth_pct'].drop_nulls().mean()
                avg_firms = cat_data['firm_count_growth_pct'].drop_nulls().mean()
                avg_mean = cat_data['mean_rev_growth_pct'].drop_nulls().mean()
                print(f"\n  CATEGORY AVERAGE:")
                print(f"    Total revenue growth: {avg_rev:+.0f}%")
                print(f"    Firm count growth: {avg_firms:+.0f}%")
                print(f"    Revenue per firm growth: {avg_mean:+.0f}%")

        # Key comparison
        print("\n" + "=" * 70)
        print("KEY FINDING FOR PAPER")
        print("=" * 70)

        success_data = results_df.filter(pl.col('category') == 'SUCCESS')
        failure_data = results_df.filter(pl.col('category') == 'FAILURE')

        if len(success_data) > 0 and len(failure_data) > 0:
            s_rev = success_data['total_rev_growth_pct'].drop_nulls().mean()
            f_rev = failure_data['total_rev_growth_pct'].drop_nulls().mean()
            s_mean = success_data['mean_rev_growth_pct'].drop_nulls().mean()
            f_mean = failure_data['mean_rev_growth_pct'].drop_nulls().mean()
            s_firms = success_data['firm_count_growth_pct'].drop_nulls().mean()
            f_firms = failure_data['firm_count_growth_pct'].drop_nulls().mean()

            print(f"""
SUCCESS sectors (pork, poultry) - where import substitution worked:
  - Total revenue growth: {s_rev:+.0f}%
  - Firm count change: {s_firms:+.0f}%
  - Revenue per firm growth: {s_mean:+.0f}%

FAILURE sectors (dairy, fruits) - where import substitution failed:
  - Total revenue growth: {f_rev:+.0f}%
  - Firm count change: {f_firms:+.0f}%
  - Revenue per firm growth: {f_mean:+.0f}%

INTERPRETATION:
""")
            if s_rev > f_rev:
                print("  ✓ SUCCESS sectors grew revenue faster than FAILURE sectors")
                print(f"    Difference: {s_rev - f_rev:+.0f} percentage points")
            if s_mean > f_mean:
                print("  ✓ SUCCESS sectors show more consolidation (larger firms)")
                print(f"    Revenue/firm grew {s_mean - f_mean:+.0f}pp more in SUCCESS sectors")

        # Save results
        results_df.write_csv(OUTPUT_DIR / "subsector_revenue_analysis.csv")
        panel.write_csv(OUTPUT_DIR / "subsector_revenue_panel.csv")
        print(f"\nSaved to: {OUTPUT_DIR / 'subsector_revenue_analysis.csv'}")

        return results_df

    return panel


if __name__ == "__main__":
    results = analyze_revenue_by_subsector()
