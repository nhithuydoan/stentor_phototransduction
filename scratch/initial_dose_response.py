import csv
import numpy as np
import matplotlib.pyplot as plt

DATA_PATH = "../data/light_variation0814.csv"

with open(DATA_PATH) as fh:
    rows = list(csv.DictReader(fh))

initial = [r for r in rows if r['stimulus'] == '1' and r['run'] == '1' and r['response'] != 'NaN']

intensities = ['300fc', '500fc', '800fc']
durations = [10, 15, 20, 30]
intensity_lux = {'300fc': 1930, '500fc': 5900, '800fc': 13080}
colors = {'300fc': '#4363d8', '500fc': '#7A3DB8', '800fc': '#3cb44b'}

fig, ax = plt.subplots(figsize=(6, 4.5))

for intensity in intensities:
    rates = []
    cis = []
    ns = []
    for dur in durations:
        cond = f"{intensity} {dur}s"
        subset = [r for r in initial if r['condition'] == cond]
        n = len(subset)
        k = sum(float(r['response']) for r in subset)
        p = k / n if n > 0 else 0
        se = np.sqrt(p * (1 - p) / n) if n > 0 else 0
        rates.append(p)
        cis.append(1.96 * se)
        ns.append(n)

    ax.errorbar(durations, rates, yerr=cis, marker='o', capsize=4,
                label=f'{intensity} ({intensity_lux[intensity]} lux)',
                color=colors[intensity], linewidth=1.5, markersize=6)

    for d, r, n in zip(durations, rates, ns):
        ax.annotate(f'n={n}', (d, r), textcoords="offset points",
                    xytext=(8, -4), fontsize=7, color=colors[intensity])

ax.set_xlabel('Stimulus duration (s)', fontsize=12)
ax.set_ylabel('P(response)', fontsize=12)
ax.set_title('Initial Dose-Response (Stimulus 1, Run 1)', fontsize=13)
ax.set_ylim(-0.05, 1.05)
ax.set_xticks(durations)
ax.legend(title='Intensity', fontsize=9, title_fontsize=10)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)

plt.tight_layout()
plt.savefig('initial_dose_response.png', dpi=150)
plt.savefig('initial_dose_response.pdf')
print("Saved to scratch/initial_dose_response.png and .pdf")
