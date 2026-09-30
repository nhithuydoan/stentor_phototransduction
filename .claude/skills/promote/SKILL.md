---
name: promote
description: Promote a scratch analysis into the clean analysis/ pipeline. Use this skill whenever the user says "promote", "move to analysis", "promote scratch", or "/promote". Takes one argument — the file(s) in scratch/ to promote.
---

# Promote scratch work into analysis/

This skill takes exploratory work from `scratch/` and produces a clean, minimal, reproducible script in `analysis/scripts/` with outputs in `analysis/outputs/`. It does NOT copy scratch scripts — it rewrites from scratch.

## Steps

### 1. Identify what to promote

The user passes a file or files from `scratch/` as the argument (e.g., `/promote initial_dose_response.jl`). Read the scratch script to understand what it does.

### 2. Clarify the question

If the question the script answers is not obvious from context or from `scratch/analysis_log.md`, ask the user:
> "Which question does this result answer?"

Do not proceed until you have the question.

### 3. Show the plan before writing anything

Present this to the user and wait for confirmation:
- The question being answered
- The script name (numbered in run order, e.g., `01_initial_dose_response.jl`)
- The inputs (which data files)
- The outputs (what files will be written to `analysis/outputs/<script_name>/`)
- Any non-obvious decisions carried over from the scratch version

Check `analysis/scripts/` for existing numbered scripts to determine the next number.

### 4. Write the clean script

Write the **shortest script that produces the result**, reading from `data/` (never from `scratch/`). Place it in `analysis/scripts/`. Use this header format exactly:

```
# <filename>.jl
# Question: <the question it answers>
# Inputs: <data files, relative to project root>
# Outputs: <output files, relative to project root>
# Decisions: <any non-obvious choices made in the analysis>
```

The script must:
- Read data from `../data/` (or use a path relative to project root)
- Write outputs to `../outputs/<script_name>/` (relative to `analysis/scripts/`)
- Be self-contained — no dependencies on scratch files
- Be minimal — no exploratory code, no commented-out alternatives

### 5. Run and compare

- Create the output directory `analysis/outputs/<script_name>/`
- Run the new script
- Compare every numerical result against the scratch version:
  - For figures: compare data values that went into the plot (not pixel comparison)
  - For printed statistics: compare numbers exactly
- Show the user a side-by-side comparison

**If anything differs, STOP and tell the user.** Do not silently fix discrepancies. The user decides how to resolve them.

### 6. Leave scratch alone

Do not modify, move, or delete anything in `scratch/`. The user manages scratch cleanup themselves.

### 7. Update the analysis log

Add an entry to `scratch/analysis_log.md` noting which question was promoted and where the clean script lives.
