"""
Explore RLMS Data Structure
===========================
Read variable names and labels from RLMS .dta files without loading full data.
"""

import pyreadstat
from pathlib import Path
import json

DATA_DIR = Path(__file__).parent
OUTPUT_DIR = DATA_DIR / "RFSD_data" / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

def explore_dta_metadata(filepath: Path, sample_rows: int = 100):
    """Read metadata and sample from Stata file."""
    print(f"\n{'='*60}")
    print(f"Exploring: {filepath.name}")
    print(f"{'='*60}")

    # Read only metadata first
    print("\nReading metadata...")
    _, meta = pyreadstat.read_dta(filepath, metadataonly=True)

    print(f"\nTotal variables: {len(meta.column_names)}")
    print(f"Total observations: {meta.number_rows:,}")

    # Variable info
    print(f"\n--- Variable Names and Labels ---")
    var_info = {}
    for i, (name, label) in enumerate(zip(meta.column_names, meta.column_labels)):
        var_info[name] = label if label else ""
        if i < 50:  # Print first 50
            label_str = f" - {label}" if label else ""
            print(f"  {name}{label_str}")

    if len(meta.column_names) > 50:
        print(f"  ... and {len(meta.column_names) - 50} more variables")

    # Search for key variables
    print(f"\n--- Key Variables Search ---")

    key_patterns = {
        "ID": ["id", "idind", "id_h", "id_i"],
        "Year": ["year", "yr", "wave"],
        "Region": ["psu", "region", "oblast", "reg"],
        "Wage/Income": ["wage", "income", "earn", "salary", "j8", "j10"],
        "Employment": ["employ", "work", "job", "j1", "j2", "j4"],
        "Industry": ["indust", "sector", "okved", "branch", "j4"],
        "Age": ["age", "h5", "birth"],
        "Education": ["educ", "school", "h6"],
        "Gender": ["sex", "gender", "h1"],
        "Firm size": ["firm", "size", "employ", "j9"],
    }

    for category, patterns in key_patterns.items():
        matches = []
        for var in meta.column_names:
            var_lower = var.lower()
            for pattern in patterns:
                if pattern in var_lower:
                    label = var_info.get(var, "")
                    matches.append(f"{var}" + (f" ({label})" if label else ""))
                    break
        if matches:
            print(f"\n{category}:")
            for m in matches[:10]:  # Limit to 10 per category
                print(f"    {m}")
            if len(matches) > 10:
                print(f"    ... and {len(matches) - 10} more")

    # Read small sample
    print(f"\n--- Reading Sample ({sample_rows} rows) ---")
    df, _ = pyreadstat.read_dta(filepath, row_limit=sample_rows)

    # Check year range in sample
    year_cols = [c for c in df.columns if 'year' in c.lower()]
    if year_cols:
        for yc in year_cols[:2]:
            print(f"\n{yc} values in sample: {sorted(df[yc].dropna().unique())[:20]}")

    # Check region/PSU values
    region_cols = [c for c in df.columns if any(p in c.lower() for p in ['psu', 'region', 'oblast'])]
    if region_cols:
        for rc in region_cols[:2]:
            unique_vals = df[rc].dropna().unique()
            print(f"\n{rc} sample values ({len(unique_vals)} unique): {list(unique_vals)[:15]}")

    return var_info, meta


def main():
    print("RLMS Data Explorer")
    print("="*60)

    # Individual file
    ind_file = DATA_DIR / "IND" / "RLMS_IND_1994_2023_eng_dta.dta"
    if ind_file.exists():
        ind_vars, ind_meta = explore_dta_metadata(ind_file)

        # Save variable list
        with open(OUTPUT_DIR / "rlms_ind_variables.json", "w") as f:
            json.dump(ind_vars, f, indent=2)
        print(f"\nSaved variable list to: rlms_ind_variables.json")
    else:
        print(f"Individual file not found: {ind_file}")

    # Household file
    hh_file = DATA_DIR / "HH" / "RLMS_HH_1994_2023_eng_dta.dta"
    if hh_file.exists():
        hh_vars, hh_meta = explore_dta_metadata(hh_file)

        with open(OUTPUT_DIR / "rlms_hh_variables.json", "w") as f:
            json.dump(hh_vars, f, indent=2)
        print(f"\nSaved variable list to: rlms_hh_variables.json")
    else:
        print(f"Household file not found: {hh_file}")

    print("\n" + "="*60)
    print("Exploration complete!")
    print("="*60)


if __name__ == "__main__":
    main()
