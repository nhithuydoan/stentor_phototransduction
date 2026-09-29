# Analysis Log — Stentor Phototransduction

## Datasets
- `data/PKG_0803.csv` — PKG inhibitor vs water control (3,040 rows, 33 cells, 6 sessions)
- `data/light_hab0805.csv` — Light habituation (3,640 rows, 19 cells, 6 sessions)
- `data/light_variation0814.csv` — Intensity × duration dose-response (24,740 rows, 39 cells, 57 sessions)

## Questions & Steps

### Q1: Where are NaN values highest across the three intensities?
- **Result**: NaN is evenly spread (~1%) across 300fc, 500fc, 800fc
- Driven by individual sessions, not intensity level
- Worst session: `2026_07_24_16_35_32` (500fc) at 3.0%

### Q2: Which light condition has the highest NaN in light_variation?
- **Result**: 300fc 15s has the highest NaN rate (1.6%, 25/1520)
- By raw count: 300fc 10s and 800fc 15s tied at 28 NaN rows each
- Lowest: 800fc 30s at 0.4% (8/2220)

---
