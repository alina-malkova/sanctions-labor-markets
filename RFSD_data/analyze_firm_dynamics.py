"""
RFSD Firm Dynamics Analysis
===========================
Analyze firm entry/exit, profitability, and employment in agriculture
to complement worker-level RLMS analysis.
"""

import polars as pl
import pandas as pd
import numpy as np
from pathlib import Path
import json

OUTPUT_DIR = Path("output")
OUTPUT_DIR.mkdir(exist_ok=True)

def load_agri_firms(year):
    """Load agricultural firms for a given year."""
    path = OUTPUT_DIR / f"agri_firms_{year}.parquet"
    if path.exists():
        return pl.read_parquet(path)
    return None

def analyze_firm_counts():
    """Analyze agricultural firm counts over time."""
    print("="*60)
    print("FIRM COUNTS BY YEAR")
    print("="*60)
    
    years = [2013, 2014, 2018, 2023]
    results = []
    
    for year in years:
        df = load_agri_firms(year)
        if df is not None:
            # Total agricultural/food firms
            total = len(df)
            
            # Primary agriculture (Section A) vs food processing
            section_a = len(df.filter(pl.col('okved_section') == 'A'))
            food_processing = total - section_a
            
            # Firms with creation_date after 2014 (entrants)
            if year > 2013:
                entrants = len(df.filter(
                    (pl.col('creation_date').is_not_null()) &
                    (pl.col('creation_date') >= pl.date(2014, 1, 1))
                ))
            else:
                entrants = 0
            
            results.append({
                'year': year,
                'total_firms': total,
                'primary_agri': section_a,
                'food_processing': food_processing,
                'entrants_post_2014': entrants
            })
            
            print(f"\n{year}:")
            print(f"  Total agricultural/food firms: {total:,}")
            print(f"  Primary agriculture (Section A): {section_a:,}")
            print(f"  Food processing/retail: {food_processing:,}")
            if year > 2013:
                print(f"  Entrants (created after 2014): {entrants:,}")
    
    # Save results
    results_df = pd.DataFrame(results)
    results_df.to_csv(OUTPUT_DIR / "firm_counts_by_year.csv", index=False)
    
    # Calculate growth rates
    if len(results) >= 2:
        print("\n--- Growth Rates ---")
        base = results[0]['total_firms']  # 2013
        for r in results[1:]:
            growth = (r['total_firms'] - base) / base * 100
            print(f"  2013-{r['year']}: {growth:+.1f}%")
    
    return results

def analyze_profitability():
    """Analyze profitability trends in agriculture."""
    print("\n" + "="*60)
    print("PROFITABILITY ANALYSIS")
    print("="*60)
    
    years = [2013, 2014, 2018, 2023]
    results = []
    
    # Key financial lines (in thousands of rubles)
    # line_2110 = Revenue
    # line_2400 = Net profit
    # line_1600 = Total assets
    
    for year in years:
        df = load_agri_firms(year)
        if df is None:
            continue
            
        # Filter to firms with financial data
        df_fin = df.filter(
            pl.col('line_2110').is_not_null() & 
            pl.col('line_2400').is_not_null()
        )
        
        n_firms = len(df_fin)
        
        if n_firms == 0:
            continue
        
        # Calculate aggregates
        total_revenue = df_fin['line_2110'].sum()
        total_profit = df_fin['line_2400'].sum()
        total_assets = df_fin.filter(pl.col('line_1600').is_not_null())['line_1600'].sum()
        
        # Profit margin
        profit_margin = total_profit / total_revenue * 100 if total_revenue > 0 else 0
        
        # ROA (return on assets)
        roa = total_profit / total_assets * 100 if total_assets > 0 else 0
        
        # Median firm-level metrics
        median_revenue = df_fin['line_2110'].median()
        median_profit = df_fin['line_2400'].median()
        
        # Share of profitable firms
        profitable_firms = len(df_fin.filter(pl.col('line_2400') > 0))
        share_profitable = profitable_firms / n_firms * 100
        
        results.append({
            'year': year,
            'n_firms_with_data': n_firms,
            'total_revenue_bn': total_revenue / 1e6,  # Convert to billions
            'total_profit_bn': total_profit / 1e6,
            'profit_margin_pct': profit_margin,
            'roa_pct': roa,
            'median_revenue_k': median_revenue,
            'median_profit_k': median_profit,
            'share_profitable_pct': share_profitable
        })
        
        print(f"\n{year}:")
        print(f"  Firms with financial data: {n_firms:,}")
        print(f"  Total revenue: {total_revenue/1e6:,.1f} billion RUB")
        print(f"  Total net profit: {total_profit/1e6:,.1f} billion RUB")
        print(f"  Aggregate profit margin: {profit_margin:.1f}%")
        print(f"  Share of profitable firms: {share_profitable:.1f}%")
        print(f"  Median firm revenue: {median_revenue:,.0f} thousand RUB")
        print(f"  Median firm profit: {median_profit:,.0f} thousand RUB")
    
    # Save results
    results_df = pd.DataFrame(results)
    results_df.to_csv(OUTPUT_DIR / "profitability_by_year.csv", index=False)
    
    # Calculate changes
    if len(results) >= 2:
        print("\n--- Changes from 2013 Baseline ---")
        base = results[0]
        for r in results[1:]:
            rev_change = (r['total_revenue_bn'] / base['total_revenue_bn'] - 1) * 100
            profit_change = (r['total_profit_bn'] / base['total_profit_bn'] - 1) * 100
            margin_change = r['profit_margin_pct'] - base['profit_margin_pct']
            print(f"  {r['year']}: Revenue {rev_change:+.1f}%, Profit {profit_change:+.1f}%, Margin {margin_change:+.1f}pp")
    
    return results

def analyze_firm_entry_exit():
    """Analyze firm entry and exit patterns."""
    print("\n" + "="*60)
    print("FIRM ENTRY/EXIT ANALYSIS")
    print("="*60)
    
    # Load 2013 and 2023 data to track entry/exit
    df_2013 = load_agri_firms(2013)
    df_2023 = load_agri_firms(2023)
    
    if df_2013 is None or df_2023 is None:
        print("Missing data for entry/exit analysis")
        return None
    
    # Get unique firm identifiers (INN)
    inns_2013 = set(df_2013['inn'].drop_nulls().to_list())
    inns_2023 = set(df_2023['inn'].drop_nulls().to_list())
    
    # Survivors (in both years)
    survivors = inns_2013 & inns_2023
    
    # Exits (in 2013 but not 2023)
    exits = inns_2013 - inns_2023
    
    # Entrants (in 2023 but not 2013)
    entrants = inns_2023 - inns_2013
    
    print(f"\nFirms in 2013: {len(inns_2013):,}")
    print(f"Firms in 2023: {len(inns_2023):,}")
    print(f"\nSurvivors (in both): {len(survivors):,}")
    print(f"Exits (2013 only): {len(exits):,}")
    print(f"Entrants (2023 only): {len(entrants):,}")
    
    survival_rate = len(survivors) / len(inns_2013) * 100
    entry_rate = len(entrants) / len(inns_2023) * 100
    
    print(f"\n10-year survival rate: {survival_rate:.1f}%")
    print(f"Entrant share of 2023 firms: {entry_rate:.1f}%")
    
    # Net firm growth
    net_growth = len(inns_2023) - len(inns_2013)
    net_growth_pct = net_growth / len(inns_2013) * 100
    print(f"\nNet firm growth: {net_growth:+,} ({net_growth_pct:+.1f}%)")
    
    # Analyze entrants by creation year
    print("\n--- Entrants by Creation Year ---")
    df_entrants = df_2023.filter(pl.col('inn').is_in(list(entrants)))
    
    entrants_by_year = (
        df_entrants
        .with_columns(
            pl.col('creation_date').dt.year().alias('creation_year')
        )
        .group_by('creation_year')
        .agg(pl.len().alias('count'))
        .sort('creation_year')
        .filter(pl.col('creation_year') >= 2010)
        .collect() if hasattr(df_entrants, 'collect') else 
        df_entrants
        .with_columns(
            pl.col('creation_date').dt.year().alias('creation_year')
        )
        .group_by('creation_year')
        .agg(pl.len().alias('count'))
        .sort('creation_year')
        .filter(pl.col('creation_year') >= 2010)
    )
    
    print(entrants_by_year)
    
    # Save entry/exit results
    results = {
        'firms_2013': len(inns_2013),
        'firms_2023': len(inns_2023),
        'survivors': len(survivors),
        'exits': len(exits),
        'entrants': len(entrants),
        'survival_rate_pct': survival_rate,
        'entry_rate_pct': entry_rate,
        'net_growth': net_growth,
        'net_growth_pct': net_growth_pct
    }
    
    with open(OUTPUT_DIR / "entry_exit_analysis.json", 'w') as f:
        json.dump(results, f, indent=2)
    
    # Save entrants by year
    entrants_by_year.write_csv(OUTPUT_DIR / "entrants_by_year.csv")
    
    return results

def analyze_firm_size_distribution():
    """Analyze firm size distribution changes."""
    print("\n" + "="*60)
    print("FIRM SIZE DISTRIBUTION")
    print("="*60)
    
    years = [2013, 2018, 2023]
    
    for year in years:
        df = load_agri_firms(year)
        if df is None:
            continue
        
        # Use total assets (line_1600) as size proxy
        df_size = df.filter(pl.col('line_1600').is_not_null())
        
        print(f"\n{year} (n={len(df_size):,} firms with asset data):")
        
        assets = df_size['line_1600']
        
        # Size percentiles
        p10 = assets.quantile(0.10)
        p25 = assets.quantile(0.25)
        p50 = assets.quantile(0.50)
        p75 = assets.quantile(0.75)
        p90 = assets.quantile(0.90)
        
        print(f"  10th percentile: {p10:,.0f} thousand RUB")
        print(f"  25th percentile: {p25:,.0f} thousand RUB")
        print(f"  Median: {p50:,.0f} thousand RUB")
        print(f"  75th percentile: {p75:,.0f} thousand RUB")
        print(f"  90th percentile: {p90:,.0f} thousand RUB")
        
        # Share of assets held by top 10%
        top_10_cutoff = assets.quantile(0.90)
        top_10_assets = df_size.filter(pl.col('line_1600') >= top_10_cutoff)['line_1600'].sum()
        total_assets = assets.sum()
        top_10_share = top_10_assets / total_assets * 100
        print(f"  Share of assets held by top 10%: {top_10_share:.1f}%")

def create_summary_for_paper():
    """Create summary statistics suitable for paper tables."""
    print("\n" + "="*60)
    print("SUMMARY FOR PAPER")
    print("="*60)
    
    # Load all results
    firm_counts = pd.read_csv(OUTPUT_DIR / "firm_counts_by_year.csv")
    profitability = pd.read_csv(OUTPUT_DIR / "profitability_by_year.csv")
    
    with open(OUTPUT_DIR / "entry_exit_analysis.json") as f:
        entry_exit = json.load(f)
    
    print("\n--- Table: Agricultural Firm Dynamics ---")
    print("""
| Metric | 2013 | 2018 | 2023 | Change |
|--------|------|------|------|--------|""")
    
    # Firm counts
    for _, row in firm_counts.iterrows():
        if row['year'] == 2013:
            base_firms = row['total_firms']
    
    for _, row in firm_counts.iterrows():
        change = (row['total_firms'] / base_firms - 1) * 100
        change_str = f"{change:+.1f}%" if row['year'] != 2013 else "---"
        print(f"| Total firms | {row['total_firms']:,} | | | {change_str} |" if row['year'] == 2013 else "")
    
    print(f"""
Key findings:
- Net firm growth 2013-2023: {entry_exit['net_growth']:+,} firms ({entry_exit['net_growth_pct']:+.1f}%)
- 10-year survival rate: {entry_exit['survival_rate_pct']:.1f}%
- New entrants (post-2013): {entry_exit['entrants']:,} firms
""")

def main():
    print("="*60)
    print("RFSD FIRM DYNAMICS ANALYSIS")
    print("="*60)
    
    # Run all analyses
    analyze_firm_counts()
    analyze_profitability()
    analyze_firm_entry_exit()
    analyze_firm_size_distribution()
    create_summary_for_paper()
    
    print("\n" + "="*60)
    print("Analysis complete! Output saved to:", OUTPUT_DIR)
    print("="*60)

if __name__ == "__main__":
    main()
