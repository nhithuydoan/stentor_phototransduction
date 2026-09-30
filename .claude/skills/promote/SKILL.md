# /promote

Exploratory analysis code lives in `scratch/`. When a scratch analysis matures into something worth keeping, `/promote` rewrites it as a clean, self-contained script in `analysis/scripts/`. Nothing in `analysis/` may reference or import from `scratch/`.

This separation keeps `analysis/` reproducible and `scratch/` low-stakes.
