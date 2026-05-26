# HO Antarctica — Whole-Continent Blatter-Pattyn Ice Sheet Model

End-to-end Higher-Order (Blatter-Pattyn) Antarctic ice-sheet inversion using **Elmer/Ice**, scaled to **1024 MPI ranks** on **LUMI HPC** (CSC, Finland).

## What's here

| Path | Purpose |
|------|---------|
| `mesh_generation/` | MATLAB + Gmsh `.geo` to build the 2D Antarctica boundary mesh from BedMachine outlines |
| `mesh_refinement/` | Step 1–4 of the pipeline: MMG2D adaptive refinement, S1 data init, S2 3D extrusion + projection |
| `S5_HO_Inversion/` | **Step 5** — Adjoint BP inversion for basal friction (β); joint β + μ template included |
| `docs/` | Resume guide, lessons learned, data-source paths, full debugging chronicle |

## Quick start

If you are resuming this work in a new session — read [`docs/QUICKSTART.md`](docs/QUICKSTART.md) first. It tells you what to check and what to run.

If you are debugging an Elmer/Ice problem you haven't seen before — search [`docs/LESSONS.md`](docs/LESSONS.md) for the failure mode. 30+ categorised failure modes are documented (NaN matrices, Picard divergence, MPI OFI transients, mesh path hijacking, etc).

If you want the day-by-day history — read [`docs/CHRONICLE.md`](docs/CHRONICLE.md).

If you need to know where the input data lives on LUMI / Mahti — see [`docs/DATA_SOURCES.md`](docs/DATA_SOURCES.md).

## Pipeline overview

```
Step 0 : Boundary extraction      (QGIS → CSV → .geo)                 — DONE
Step 1 : Initial 2D mesh          (Gmsh, lc=2km/1km)                   — DONE
Step 2 : MMG2D adaptive refine    (GL 1km, shelf 3km, inland 25km)     — DONE
Step 3 : S1 data init             (Mahti reference single-task, 80 s)  — DONE
Step 4a: S1 data init (LUMI)      (1024 ranks, 2:40)                   — DONE
Step 4b: 3D project + Greve T     (1024 ranks, 1:30, 2-step pattern)   — DONE
Step 5 : HO inversion of β        (BP + AdjointBP + m1qn3)             — IN PROGRESS
Step 6 : Transient historic run   (HO + thickness + flotation)         — TODO
```

The current focus is **Step 5**, where the working SIF is [`S5_HO_Inversion/Antarctica_invert_beta_S5.sif`](S5_HO_Inversion/Antarctica_invert_beta_S5.sif).

## Mesh sizes (refined)

| Variant | Initial | Final 2D nodes | Grounding line | Shelf | Inland |
|---------|---------|----------------|----------------|-------|--------|
| 2km+shelf1km | 7M (lc=2km) | 2,263,958 | 1 km | 1 km | 25 km |
| 1km+shelf3km | 24M (lc=1km) | 929,491 | 1 km | 3 km | 25 km |

Step 5 runs on the **1km+shelf3km** mesh (929K × 15 layers = ~14M 3D nodes).

## Key references

- **Rupert Gladstone** (Univ. of Lapland) — `/scratch/project_462001251/gladston/` on LUMI. His `ISMIP6_HOtest/HO.sif` is the closest working continent-scale HO setup; his `Totten_HOTest/` has the AdjointBP examples we build on.
- **Ann Kristin Lund-Johansen** — `/scratch/project_462001251/lundjohansen/`. Her FS inversion (`ASB/ASB_FS/`) provided the 2-step init pattern and the m1qn3 dual-variable packing pattern we use for the joint inversion.
- **Chen Zhao** (Mahti) — `/scratch/project_2000881/czhao/ISMIP6/`. Her continent-scale SSA setup anchored our mesh decisions.

## HPC environment

LUMI module load:
```bash
module use /projappl/project_462001194/modules/
module load elmer/elmerice
```

This Elmer module has the `Adjoint_*` family of solvers; **`AdjointBP_*` is NOT in it** and must be locally compiled — see [`S5_HO_Inversion/src/`](S5_HO_Inversion/src/) for the F90 sources and the compile command in the README there.

## Contact

Yu Wang (`yuwang115` / `yuwang1@lumi.csc.fi`) — for questions on this work.
