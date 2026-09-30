# Stentor Phototransduction

Behavioral data and analysis for the light-evoked contraction response in *Stentor coeruleus*. Cells are presented with repeated light pulses and each response is scored from video as one of four mutually exclusive contraction subtypes (contract, bend, shorten, partial contract) or no response. The data covers three experiments: habituation under repeated stimulation, dose-response across light intensities and durations, and the effect of PKG inhibition.

## Data

Three CSV files in `data/`, all sharing the same strucutre (one row per cell per stimulus). See [`data/data_dictionary.md`](data/data_dictionary.md) for column definitions, per-file details, and analysis notes.

| File | Experiment |
|---|---|
| `PKG_0803.csv` | PKG inhibitor vs water control |
| `light_hab0805.csv` | Habituation across repeated trials |
| `light_variation0814.csv` | 3 intensities × 4 durations dose-response |

## Repository structure

```
data/           Raw experimental data and data dictionary
scratch/        Exploratory analysis scripts (Julia)
analysis/       Clean, reproducible pipeline (promoted from scratch)
```

