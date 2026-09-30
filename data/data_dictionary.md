# Data Dictionary

Light-evoked contraction responses in *Stentor coeruleus*, scored from video. Each row records whether a single cell responded to a single stimulus presentation, and if so, what kind of contraction it exhibited. The data folder include three experiments investigating habituation, dose-response, and the effect of PKG inhibition on phototransduction.

---

## Files at a glance

| File | Grain (one row =) | Use it for |
|---|---|---|
| `PKG_0803.csv` | one cell × one stimulus | PKG inhibitor vs water control |
| `light_hab0805.csv` | one cell × one stimulus | Light habituation across repeated trials |
| `light_variation0814.csv` | one cell × one stimulus | Dose-response: 3 intensities × 4 durations |

---

## Column definitions

All three files share the same 16-column schema.

### Session and protocol

| Column | Type | Description |
|---|---|---|
| `fold_name` | text | Folder ID, in format YYYY Mon DD hh:mm:s |
| `condition` | text | Experimental condition |
| `run` | integer | Replicate run within a dataset |
| `isi` | integer | Inter-stimulus interval (in seconds) |
| `iti` | integer | Inter-trial interval (in seconds) |
| `trial` | integer | Trial number within a run |
| `stimulus` | integer | Stimulus number within a trial (1–20) |

### Cell

| Column | Type | Description |
|---|---|---|
| `cell_number` | integer | Individual cell |

### Response

| Column | Type | Description |
|---|---|---|
| `response` | binary | Whether the cell responded (1) or not (0) |
| `contract` | binary | Response subtype: full contraction |
| `bend` | binary | Response subtype: bending |
| `shorten` | binary | Response subtype: shortening |
| `partial_contract` | binary | Response subtype: partial contraction |

The four subtypes are **mutually exclusive**, meaning a responding cell is scored as exactly one subtype. If a cell contracts prior to the stimulus, it is marked as NaN.

### Stimulus

| Column | Type | Description |
|---|---|---|
| `stim_mode` | text | Stimulus modality. There are light, tap, and both light and taps. In this experiment, only light stimuli were used|
| `light_duration` | integer | Light pulse duration (in seconds) |
| `light_level` | integer | Light intensity (PWM) |

The `light_level` value is the hardware PWM setting. Condition labels in `light_variation0814.csv`
encode the corresponding footcandle measurement:

| PWM value | Footcandles |
|---|---|
| 1930 | 300 |
| 5900 | 500 |
| 13080 | 800 |

---

## The files

### `PKG_0803.csv` — PKG inhibition

Tests the effect of a PKG inhibitor on the light-evoked contraction response.

### `light_hab0805.csv` — habituation

Repeated light stimulation to observe habituation of the contraction response.

### `light_variation0814.csv` — dose-response

Systematically varies light intensity and duration to map the dose-response surface.



