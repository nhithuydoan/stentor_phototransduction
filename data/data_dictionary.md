# Data Dictionary

Light-evoked contraction responses in *Stentor coeruleus*, scored from video. Each row records
whether a single cell responded to a single stimulus presentation, and if so, what kind of
contraction it performed. The data spans three experiments investigating habituation, dose-response,
and the effect of PKG inhibition on phototransduction.

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
| `fold_name` | text | Timestamp-based session ID (e.g. `2026_07_07_13_47_02`) identifying one recording session |
| `condition` | text | Experimental condition. Values vary by dataset — see per-file sections below |
| `run` | integer | Replicate run within a session |
| `isi` | integer | Inter-stimulus interval in seconds. Always 120 |
| `iti` | integer | Inter-trial interval in seconds. Always 2400 |
| `trial` | integer | Trial number within a run |
| `stimulus` | integer | Stimulus number within a trial (1–20) |

### Cell

| Column | Type | Description |
|---|---|---|
| `cell_number` | integer | Individual cell tracked in the field of view |

### Response

| Column | Type | Description |
|---|---|---|
| `response` | binary | Whether the cell responded (1) or not (0) |
| `contract` | binary | Response subtype: full contraction |
| `bend` | binary | Response subtype: bending |
| `shorten` | binary | Response subtype: shortening |
| `partial_contract` | binary | Response subtype: partial contraction |

The four subtypes are **mutually exclusive** — a responding cell is scored as exactly one subtype.
When `response = 0`, all subtypes are 0. A small number of rows have `NaN` across all five
response columns (response + subtypes): 10 in PKG_0803, 25 in light_hab0805, 232 in
light_variation0814. These are unscored observations, not zero responses.

### Stimulus

| Column | Type | Description |
|---|---|---|
| `stim_mode` | text | Stimulus modality. Always `light` |
| `light_duration` | integer | Light pulse duration in seconds |
| `light_level` | integer | Light intensity as a PWM setting from the computer |

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

- **3,040 rows**, 6 sessions, up to 33 cells per session
- **Conditions:** `PKG` (inhibitor) and `water` (vehicle control)
- **Protocol:** 1 trial of 20 stimuli per run, 3 runs per session
- **Stimulus:** 30s light at 13080 PWM (800fc)

### `light_hab0805.csv` — habituation

Repeated light stimulation to observe habituation of the contraction response.

- **3,640 rows**, 6 sessions, up to 19 cells per session
- **Condition:** `light` (single condition)
- **Protocol:** 2 trials of 20 stimuli per run, up to 6 runs per session. Both trials use the same protocol
- **Stimulus:** 13080 PWM (800fc). `light_duration` is blank in some rows

### `light_variation0814.csv` — dose-response

Systematically varies light intensity and duration to map the dose-response surface.

- **24,740 rows**, 57 sessions, up to 39 cells per session
- **Conditions:** 12 conditions crossing 3 intensities × 4 durations
  - Intensities: 300fc, 500fc, 800fc
  - Durations: 10s, 15s, 20s, 30s
  - Labels encode both (e.g. `800fc 30s`)
- **Protocol:** 1 trial of 20 stimuli per run, up to 5 runs per session

---

## Analysis gotchas

- **`light_level` is PWM, not footcandles.** The condition labels in `light_variation0814.csv`
  give the footcandle equivalent, but the column itself stores the hardware setting. See the
  mapping table above.
- **NaN rows.** A small number of rows have `NaN` across all five response columns — these are
  unscored observations. Drop or impute them; do not treat them as zeros.
- **Blank `light_duration` in light_hab0805.** Some rows have no value for `light_duration`.
  These are missing values, not zero-duration pulses.
- **`trial` in light_hab does not mean train vs test.** The two trials per run use the same
  protocol — they are consecutive blocks of 20 stimuli, not different experimental phases.
