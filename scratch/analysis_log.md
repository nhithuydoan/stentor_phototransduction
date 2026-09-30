# Analysis Log — Stentor Phototransduction

## Datasets
- `data/PKG_0803.csv` — PKG inhibitor vs water control (3,040 rows, 33 cells, 6 sessions)
- `data/light_hab0805.csv` — Light habituation (3,640 rows, 19 cells, 6 sessions)
- `data/light_variation0814.csv` — Intensity × duration dose-response (24,740 rows, 39 cells, 57 sessions)

## Conventions
- All scripts in Julia
- Filter: `trial == 1`, exclude NaN responses
- New code in `scratch/`, promote to `analysis/` via `/promote`

## Questions & Results

### Q1: NaN distribution across intensities
- NaN is evenly spread (~1%) across 300fc, 500fc, 800fc
- Highest NaN rate: 300fc 15s at 1.6%
- Driven by individual sessions, not intensity

### Q2: Initial dose-response surface
- **Script**: `scratch/initial_dose_response.jl`
- **Filter**: stimulus == 1, trial == 1, all runs
- **Result**: Response probability increases with both intensity and duration
- 800fc consistently highest, 300fc lowest
- n = 74–127 per condition

### Q3: Habituation decrement curves + response subtype breakdown
- **Script**: `scratch/habituation_subtypes.jl`
- **Outputs**:
  - `habituation_subtypes.png` — full 3-row composite
  - `habituation_by_duration.png` — 2x2, grouped by duration (with SE ribbons)
  - `habituation_by_intensity.png` — 2x2, grouped by intensity (with SE ribbons)
  - `habituation_conditional_subtypes.png` — P(subtype | responded), normalized stacked bars
- **Findings**:
  - Intensity dominates habituation curves more than duration
  - Subtypes are mutually exclusive (exactly 1 per responding cell)
  - Normalized stacked bars show all subtypes decline during habituation
  - **Needs further investigation**: whether the conditional composition (P(subtype | responded)) shifts over stimuli — early numbers for 800fc 30s suggest contract drops from ~50% to ~34% while bend/shorten increase, but this needs proper visualization and testing across conditions

### Q4: Individual cell trajectories (800fc 30s)
- **Script**: `scratch/cell_trajectories.jl`
- **Outputs**: `cell_trajectories.png` — heatmap of per-cell responses across 20 stimuli
- **Findings**:
  - 90% of cells (96/107) use multiple subtypes across their responses
  - Transition probabilities are nearly uniform regardless of previous subtype (~30% same, ~30-40% to each other type)
  - Subtypes are NOT fixed cell properties — they vary stochastically within cells
  - Subtypes represent stages of a single response sequence (bend → shorten → partial contract → contract), scored within an observation window (1s before to 1s after stimulus)
  - A cell scored as "bend" would eventually contract if given more time — the label reflects how far the cell progressed within the window

### Open questions
- Does P(contract | responded) systematically decrease across stimuli? (Early look at 800fc 30s says yes, but needs proper visualization across all conditions)
- If so, this would favor τ_photo ↑ (slower buildup → later threshold crossing → less time to complete sequence) over η ↓ (sensitivity shift) as the habituation mechanism
- PKG inhibitor data (PKG_0803.csv) not yet analyzed
- Light habituation with recovery/potentiation (light_hab0805.csv) not yet analyzed
