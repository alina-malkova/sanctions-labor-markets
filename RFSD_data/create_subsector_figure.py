"""
Create Figure: Sub-Sector Revenue Growth Comparison
===================================================
Shows that import substitution SUCCESS sectors grew faster than FAILURE sectors.
"""

import polars as pl
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from pathlib import Path

DATA_DIR = Path(__file__).parent
OUTPUT_DIR = DATA_DIR / "output"

# Load the data
df = pl.read_csv(OUTPUT_DIR / "subsector_mechanism_revenue.csv")

# Sort by category then growth
order = ['meat_pork', 'meat_poultry', 'dairy', 'fruits_veg', 'meat_beef', 'fish']
df = df.with_columns([
    pl.when(pl.col('product') == 'meat_pork').then(0)
    .when(pl.col('product') == 'meat_poultry').then(1)
    .when(pl.col('product') == 'dairy').then(2)
    .when(pl.col('product') == 'fruits_veg').then(3)
    .when(pl.col('product') == 'meat_beef').then(4)
    .when(pl.col('product') == 'fish').then(5)
    .alias('order')
]).sort('order')

# Labels
labels = {
    'meat_pork': 'Pork',
    'meat_poultry': 'Poultry',
    'dairy': 'Dairy',
    'fruits_veg': 'Fruits/Veg',
    'meat_beef': 'Beef',
    'fish': 'Fish'
}

# Colors
colors = {
    'SUCCESS': '#2E7D32',  # Dark green
    'FAILURE': '#C62828',  # Dark red
    'MIXED': '#757575'     # Gray
}

# Create figure with two panels
fig, axes = plt.subplots(1, 2, figsize=(12, 5))

# Panel A: Total Revenue Growth
ax1 = axes[0]
products = df['product'].to_list()
categories = df['category'].to_list()
rev_growth = df['rev_growth'].to_list()

bar_colors = [colors[c] for c in categories]
x = range(len(products))
bars1 = ax1.bar(x, rev_growth, color=bar_colors, edgecolor='black', linewidth=0.5)

ax1.set_xticks(x)
ax1.set_xticklabels([labels[p] for p in products], fontsize=11)
ax1.set_ylabel('Revenue Growth 2013-2018 (%)', fontsize=12)
ax1.set_title('A. Total Revenue Growth by Sub-Sector', fontsize=13, fontweight='bold')
ax1.axhline(y=0, color='black', linewidth=0.5)
ax1.set_ylim(0, 140)

# Add value labels
for i, (bar, val) in enumerate(zip(bars1, rev_growth)):
    ax1.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 2,
             f'+{val:.0f}%', ha='center', va='bottom', fontsize=9)

# Add dividing lines between categories
ax1.axvline(x=1.5, color='gray', linestyle='--', linewidth=1, alpha=0.5)
ax1.axvline(x=3.5, color='gray', linestyle='--', linewidth=1, alpha=0.5)

# Panel B: Revenue per Firm Growth
ax2 = axes[1]
mean_growth = df['mean_rev_growth'].to_list()
bars2 = ax2.bar(x, mean_growth, color=bar_colors, edgecolor='black', linewidth=0.5)

ax2.set_xticks(x)
ax2.set_xticklabels([labels[p] for p in products], fontsize=11)
ax2.set_ylabel('Revenue per Firm Growth 2013-2018 (%)', fontsize=12)
ax2.set_title('B. Consolidation: Revenue per Firm Growth', fontsize=13, fontweight='bold')
ax2.axhline(y=0, color='black', linewidth=0.5)
ax2.set_ylim(0, 200)

# Add value labels
for bar, val in zip(bars2, mean_growth):
    ax2.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 2,
             f'+{val:.0f}%', ha='center', va='bottom', fontsize=9)

# Add dividing lines
ax2.axvline(x=1.5, color='gray', linestyle='--', linewidth=1, alpha=0.5)
ax2.axvline(x=3.5, color='gray', linestyle='--', linewidth=1, alpha=0.5)

# Legend
legend_patches = [
    mpatches.Patch(color=colors['SUCCESS'], label='Success (Pork, Poultry)'),
    mpatches.Patch(color=colors['FAILURE'], label='Failure (Dairy, Fruits)'),
    mpatches.Patch(color=colors['MIXED'], label='Mixed (Beef, Fish)')
]
fig.legend(handles=legend_patches, loc='upper center', ncol=3,
           bbox_to_anchor=(0.5, 0.02), fontsize=10, frameon=False)

# Add annotations
ax1.annotate('Import substitution\nSUCCEEDED', xy=(0.5, 110), fontsize=9,
             ha='center', color=colors['SUCCESS'], fontweight='bold')
ax1.annotate('Import substitution\nFAILED', xy=(2.5, 70), fontsize=9,
             ha='center', color=colors['FAILURE'], fontweight='bold')

plt.tight_layout()
plt.subplots_adjust(bottom=0.12)

# Save
plt.savefig(OUTPUT_DIR / 'fig_subsector_mechanism.png', dpi=300, bbox_inches='tight',
            facecolor='white', edgecolor='none')
plt.savefig(OUTPUT_DIR / 'fig_subsector_mechanism.pdf', bbox_inches='tight',
            facecolor='white', edgecolor='none')
print(f"Saved figures to {OUTPUT_DIR}")

# Also create a simpler version
fig2, ax = plt.subplots(figsize=(8, 5))

# Group averages
success_rev = df.filter(pl.col('category') == 'SUCCESS')['rev_growth'].mean()
failure_rev = df.filter(pl.col('category') == 'FAILURE')['rev_growth'].mean()
success_mean = df.filter(pl.col('category') == 'SUCCESS')['mean_rev_growth'].mean()
failure_mean = df.filter(pl.col('category') == 'FAILURE')['mean_rev_growth'].mean()

x = [0, 1, 3, 4]
heights = [success_rev, failure_rev, success_mean, failure_mean]
bar_colors2 = [colors['SUCCESS'], colors['FAILURE'], colors['SUCCESS'], colors['FAILURE']]
labels2 = ['Success\n(Pork, Poultry)', 'Failure\n(Dairy, Fruits)',
           'Success\n(Pork, Poultry)', 'Failure\n(Dairy, Fruits)']

bars = ax.bar(x, heights, color=bar_colors2, edgecolor='black', linewidth=0.5, width=0.8)

ax.set_xticks(x)
ax.set_xticklabels(labels2, fontsize=10)
ax.set_ylabel('Growth 2013-2018 (%)', fontsize=12)

# Add value labels
for bar, val in zip(bars, heights):
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 2,
            f'+{val:.0f}%', ha='center', va='bottom', fontsize=11, fontweight='bold')

# Add group labels
ax.text(0.5, -25, 'Total Revenue Growth', ha='center', fontsize=11, fontweight='bold')
ax.text(3.5, -25, 'Revenue per Firm Growth', ha='center', fontsize=11, fontweight='bold')

# Add difference annotations
ax.annotate('', xy=(0, success_rev), xytext=(1, failure_rev),
            arrowprops=dict(arrowstyle='<->', color='black', lw=1.5))
ax.text(0.5, (success_rev + failure_rev)/2 + 5, f'+{success_rev-failure_rev:.0f}pp',
        ha='center', fontsize=10, fontweight='bold')

ax.annotate('', xy=(3, success_mean), xytext=(4, failure_mean),
            arrowprops=dict(arrowstyle='<->', color='black', lw=1.5))
ax.text(3.5, (success_mean + failure_mean)/2 + 5, f'+{success_mean-failure_mean:.0f}pp',
        ha='center', fontsize=10, fontweight='bold')

ax.axhline(y=0, color='black', linewidth=0.5)
ax.set_ylim(-10, 150)
ax.axvline(x=2, color='gray', linestyle='--', linewidth=1, alpha=0.5)

ax.set_title('Import Substitution Mechanism Test:\nSuccess vs Failure Sectors',
             fontsize=13, fontweight='bold')

plt.tight_layout()
plt.savefig(OUTPUT_DIR / 'fig_subsector_mechanism_simple.png', dpi=300, bbox_inches='tight',
            facecolor='white', edgecolor='none')
plt.savefig(OUTPUT_DIR / 'fig_subsector_mechanism_simple.pdf', bbox_inches='tight',
            facecolor='white', edgecolor='none')
print("Saved simple version")

print("\nDone!")
