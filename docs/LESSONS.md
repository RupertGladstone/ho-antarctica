---
name: HO-Antarctica
description: Develop the whole-Antarctica Higher-Order (Blatter-Pattyn) ice sheet model with Elmer/Ice. Manages HPC jobs, mesh generation, SIF files, and progress tracking via Notion.
command: ho-antarctica
---

# HO Antarctica — Blatter-Pattyn Ice Sheet Model

Orchestrate the development of a whole-Antarctica Higher-Order ice sheet model using Elmer/Ice.

## Trigger

Use when user types `/ho-antarctica` or asks about the HO Antarctica project, mesh refinement, Elmer SIF files, or anything related to the Antarctica Blatter-Pattyn model.

## Steps

When invoked, assess what the user needs and take the appropriate action:

### 1. Connect to HPC (if remote operations needed)

**Mahti** (mesh generation, refinement, init):
```bash
/mahti
```
Working directory: `/scratch/project_2000881/yuwang/HO_Antarctica/`

**LUMI** (HO solver runs, Rupert's test):
```bash
/lumi
```
Working directory: `/scratch/project_462001251/YuWang/`

### 2. Check current project status

Read Notion page for latest progress:
```bash
notion page view 31f311d1-6609-801c-8e59-d969cdbc80fd
```

Check running jobs:
```bash
# Mahti
ssh yuwang1@mahti.csc.fi "squeue -u yuwang1"

# LUMI
ssh yuwang1@lumi.csc.fi "squeue -u yuwang1"
```

### 3. Update Notion progress

Write progress updates as markdown files, then append:
```bash
notion block append 31f311d1-6609-801c-8e59-d969cdbc80fd --file /tmp/update.md
```

For full page reorganization, delete all blocks first, then append fresh content (max 100 blocks per append call — split into parts if needed).

## Project Reference

### Pipeline

```
Step 0 : Boundary extraction (QGIS → CSV → .geo)                          Done
Step 1 : Initial 2D mesh (Gmsh, lc=2km/1km)                                Done
Step 2 : MMG2D adaptive refinement (GL 1km, shelf 3km, inland 25km)        Done
Step 3 : S1 data init on Mahti (single task, 80 s)                          Done — reference
Step 4a: S1 data init on LUMI parallel (Job 18792654, 2:40, 1024 ranks)    Done
Step 4b: 3D project + Greve T (Job 18793622, 1:30, Ann Kristin 2-step)     Done
Step 5 : HO inversion of beta (Blatter-Pattyn + AdjointBP)                 In prep (S5_HO_Inversion/)
Step 6 : Transient historic run (HO + thickness + flotation)                TODO
```

### Key Directories

LUMI master: `/scratch/project_462001251/YuWang/HO_Antarctica/` (per-step sibling subdirs; the 2D mesh exists once and is symlinked into each step).

| Location | Path | Content |
|----------|------|---------|
| **Local mesh gen** | `/Users/eddie/Documents/HO Antarctica/Mesh_generation/` | Check_csv.m, Makegeo_Antarctica.m, .geo |
| **Local refinement** | `/Users/eddie/Documents/HO Antarctica/Mesh_refinement/` | SIF, Lua, SLURM scripts |
| **Local AdjointBP src** | `/Users/eddie/Documents/HO Antarctica/elmerfem-source/elmerice/Solvers/AdjointBP/` | F90 sources to upload + compile on LUMI for Step 5 |
| **Mahti mesh** | `/scratch/project_2000881/yuwang/HO_Antarctica/Process_mesh/` | Initial meshes (1km, 2km) |
| **Mahti refine (2km)** | `/scratch/project_2000881/yuwang/HO_Antarctica/Mesh_refinement/` | 2km+shelf1km refined (2.26M nodes) |
| **Mahti refine (1km)** | `/scratch/project_2000881/yuwang/HO_Antarctica/Mesh_refinement_1km/` | 1km+shelf3km refined (929K nodes) |
| **LUMI shared** | `HO_Antarctica/shared/` | `COLD.lua` + `Antarctica_lumi.lua` (single source, symlinked into each step) |
| **LUMI Mesh refinement** | `HO_Antarctica/Mesh_refinement_1km/` | mesh refinement SIF + the actual 2D refined mesh dir (~650 MB) — physical home of `mesh2D_Antarctica_1km_refined/` |
| **LUMI Init_S1_2D** | `HO_Antarctica/Init_S1_2D/` | 2D data init (S1) — SIF + sbatch + logs; symlinks to shared & mesh |
| **LUMI Init_3D** | `HO_Antarctica/Init_3D/` | 3D extrude + project + Greve T — SIF + sbatch + logs |
| **LUMI S5_HO_Inversion (planned)** | `HO_Antarctica/S5_HO_Inversion/` | beta inversion: AdjointBP `.so`, inversion SIF, `block2_idrs.sif`, `OPTIM_BETA.IN` |
| **LUMI archive** | `HO_Antarctica/_archive/` | Dead-end runs (e.g. 2026-04-17 one-shot extrude OOM) |
| **Rupert HO refs** | `/scratch/project_462001251/gladston/ISMIP6_HOtest/`, `Totten_HOTest/` | Forward HO SIFs, block preconditioner, sbatch layouts — see "Rupert's HO references" below |
| **Ann Kristin FS refs** | `/scratch/project_462001251/lundjohansen/ASB/` | 2-step init pattern + FS S3 inversion template (`ASB_inverse_S3.sif`) |
| **Data (LUMI)** | `/scratch/project_462001251/lundjohansen/data/`, `/scratch/project_462001251/YuWang/data_antarctic/`, `/scratch/project_462001251/data/` | BedMachine V4, velocity, viscosity, beta, SMB, Greve full-3D T (`ant08_b2_future25-06_hist0001.nc`) |
| **Data (Mahti)** | `/projappl/project_2002875/data/antarctic/` | Source data on Mahti side |

### Key SIF Files (Local)

| File | Purpose |
|------|---------|
| `Antarctica_mesh_refinement.sif` | 14-solver MMG2D pipeline |
| `Antarctica_init_S1.sif` | Read NC data onto 2D refined mesh |
| `Antarctica_extrude_test.sif` | 3D extrusion test (15 layers) |

### Lua Configuration Files

| File | Purpose |
|------|---------|
| `Antarctica.lua` | Mesh params, data paths, run name |
| `COLD.lua` | Physical constants, shared Lua functions (setminmesh, setmaxmesh, etc.) |

### Mesh Refinement Results

| Version | Initial | Final nodes | GL | Shelf | Inland |
|---------|---------|-------------|-----|-------|--------|
| 2km+shelf1km | 7M (lc=2km) | 2,263,958 | 1 km | 1 km | 25 km |
| 1km+shelf3km | 24M (lc=1km) | 929,491 | 1 km | 3 km | 25 km |

### Data Sources (all at `/projappl/project_2002875/data/antarctic/`)

| Data | File |
|------|------|
| Topography | `BedMachineAntarctica_V4.nc` |
| Velocity | `antarctic_ice_vel_phase_map_v01_errordel_inpaint_extend_slim.nc` |
| Viscosity | `ant08_b2_future25-06_hist0001_MuMean_pat94.nc` |
| Friction | `aa_v3_e8_l11_beta.nc` |
| SMB | `smbref_1995_2014_mar.nc` |

### Chen ISMIP6 Reference (Mahti)

| Mesh | Nodes | GL | Config |
|------|-------|-----|--------|
| AE05 (2kmGL) | 473K | 2 km | `AAnew2km.lua` |
| 1kmGL | 948K | 1 km | `AAnew.lua` |
| 500mGL | 1.93M | 500 m | `AAnew500m.lua` |
| Location | `/scratch/project_2000881/czhao/ISMIP6/` | | |

### Rupert's HO Test Reference (LUMI)

- Totten domain, 126K 2D nodes, 15 layers, 128 partitions
- ~30 min/yr, iterative block preconditioner
- SIF: `Totten_HOTest/ASB_HO_HIST_S5_legacy_discont_20yr.sif`
- Key notes: GL melt=FALSE, increase nonlinear iter >20, GLFlux broken

### Elmer Module (LUMI)

```bash
module use /projappl/project_462001194/modules/
module load elmer/elmerice
```

Adjoint solvers present in this module (verified via `nm`): `Adjoint_CostContSolver`, `Adjoint_CostDiscSolver`, `Adjoint_CostRegSolver`, `Adjoint_GradientValidation`, `Adjoint_LinearSolver`, `AdjointSolver`, full `AdjointSSA_*` family. **`AdjointBP*` is NOT in the module** — must be compiled locally for Step 5 (see "Step 5 HO inversion" below).

### Elmer Module (Mahti)

```bash
module load elmer/latest
```

### LUMI 1024-rank sbatch recipe (canonical)

Every Elmer job in `HO_Antarctica/<StepDir>/` on LUMI uses this envelope. The four bolded lines are the ones that made the difference between a 1:30 successful run and a 19-min deadlocked hang:

```bash
#!/bin/bash -f
#SBATCH --partition=standard           # 8 nodes > small's 4-node cap
#SBATCH --time=01:00:00                # tune per step
#SBATCH --job-name=...
#SBATCH --output=%x.%j.out
#SBATCH --error=%x.%j.err
#SBATCH --nodes=8                       # matches mesh partitioning.1024
#SBATCH --ntasks-per-node=128
#SBATCH --exclusive                     # ← required at 1024 ranks
#SBATCH --account=project_462001251

cd /scratch/project_462001251/YuWang/HO_Antarctica/<StepDir>

module purge                            # ← clean stale lumi-tools etc.
module use /projappl/project_462001194/modules/
module load elmer/elmerice

ulimit -s unlimited                     # ← Elmer needs deep stacks

echo "<your.sif>" > ELMERSOLVER_STARTINFO

srun ElmerSolver
```

**Do NOT add `export FI_CXI_RX_MATCH_MODE=hybrid`** to "preempt" libfabric errors. At 1024 ranks it triggers a startup deadlock — Job 18793223 hung for 19 minutes burning compute with zero progress past `STARTED AT` prints. The libfabric Fatal that the env var is meant to fix was actually downstream of an OOM cascade in a prior failed run; default match mode is fine for our 1024-rank workload on standard partition.

### Notion Page

- **Page ID**: `31f311d1-6609-801c-8e59-d969cdbc80fd`
- **CLI**: `notion page view 31f311d1-6609-801c-8e59-d969cdbc80fd`
- **Append**: `notion block append 31f311d1-6609-801c-8e59-d969cdbc80fd --file <md>`
- **Search**: `notion search "HO Antarctica"`

### Common Workflows

**Submit mesh refinement job on Mahti:**
```bash
ssh -t yuwang1@mahti.csc.fi "source /appl/profile/zz-csc-env.sh; source /appl/lmod/lmod/init/bash; cd /scratch/project_2000881/yuwang/HO_Antarctica/Mesh_refinement && sbatch sbatch_Elmer.sh"
```

**Check refinement convergence:**
```bash
ssh yuwang1@mahti.csc.fi "grep 'RELC.*MMG2D' /scratch/project_2000881/yuwang/HO_Antarctica/Mesh_refinement/output.txt"
```

**Upload local SIF/Lua to Mahti:**
```bash
scp "/Users/eddie/Documents/HO Antarctica/Mesh_refinement/"*.{sif,lua} yuwang1@mahti.csc.fi:/scratch/project_2000881/yuwang/HO_Antarctica/Mesh_refinement/
```

**Download VTU results from LUMI:**
```bash
scp yuwang1@lumi.csc.fi:/scratch/project_462001251/gladston/ISMIP6_HOtest/VTUoutputs/<file> "/Users/eddie/Documents/vtuoutputs/"
```

### Rupert's HO references (`/scratch/project_462001251/gladston/`)

Two dirs hold working HO setups built by Rupert Gladstone — they anchor Steps 5–6:

**`ISMIP6_HOtest/`** — continent-scale ISMIP6 HO (closest analog to our setup):

| File | Use for |
|------|---------|
| `HO.sif` | Whole-Antarctica HO forward template |
| `ASB.lua`, `COLD.lua`, `MISISSAE.lua` | Continent-scale Lua constants |
| `batchElmer.sh` | sbatch layouts (6×42 / 4×63 / 2×126) — note he uses 42 ranks/node for memory headroom |
| `README.asc` | Pre-flight checklist: mesh2mesh restart, init bits (beta, EF, H, dHdt, drift tuning) |
| `block2_idrs.sif` | Block-GS + IDRS preconditioner (mandatory at scale; MUMPS won't fit) |
| `mesh2D_AA_ZC_1kmGL_refined/`, `2kmGL_refined/` | Chen's refined meshes Rupert reused |

**`Totten_HOTest/`** — basin-scale HO historic (Solver-by-solver template for Step 6):

| File | Use for |
|------|---------|
| `ASB_HO_HIST_S5_legacy_discont_20yr.sif` | 20-yr HO historic — Solvers 1–14: MeshMapper, SMB/BMB GridDataReader, ComputeNormal, **HydrostaticNSSolver** (with `include "block2_idrs.sif"`), Thickness, Flotation, ProjectZS, MapCoordinate, UpdateExport, ResultOutput |
| `block2_idrs.sif` | Block GCR/IDRS for HO 2-DOF; outer 500 iters, blocks ILU0+IDRS |
| `notes.asc` | Switch-from-FS-to-HO notes (zs/zb naming, init guesses, BC differences from Ann Kristin's FS) |
| `Flotation.F90`, `FlotationLocal.so` | Local Flotation fix (Apr 10) — drop-in if upstream version breaks |
| `batchElmer.sh` | 1 node × 128 ranks, 72 h time (126 K 2D mesh × 15 layers × 20 yr) |
| `ASB.lua`, `COLD.lua` | Includes `gamma 0` for SubShelfMelt, BMB forcing paths |

Key patterns to inherit:
- `Variable = -dofs 2 "Horizontal Velocity"` is the HO state variable (use as adjoint target).
- Warm-start: `Horizontal Velocity 1 = Equals vx`, `Horizontal Velocity 2 = Equals vy` in IC.
- `Constant-Viscosity Start = Logical True` on HydrostaticNSSolver — first sweep constant μ, then full power-law.
- Sliding: `SlidCoef_Contact` + `Sliding Law = String Weertman` + `Grounding Line Definition = string discontinuous`.
- icefront BC (corrected 2026-05-24 — second variable is `surface` not `lowersurface`, no outer minus):
  `Normal Surface Traction = Variable Coordinate 3, surface; Real Lua "(math.max(rhow*math.abs(gravity)*(zsl-tx[0]),0)-rhoi*math.abs(gravity)*(tx[1]-tx[0]))"`
- `Compute GL Flux` is now in the elmerice module (Rupert pushed Fab's commits) — no local solver needed.

### Step 5 HO Inversion (in prep)

Working dir: `HO_Antarctica/S5_HO_Inversion/` (planned).

- **Target**: invert **beta** (basal friction, in `log10`) using AdjointBP.
- **Cost**: velocity misfit `Adjoint_CostDiscSolver` against `vobs` + Tikhonov on `log10(beta)` via `Adjoint_CostRegSolver`.
- **Forward**: `HydrostaticNSSolver` (`HydrostaticNSVec`); **adjoint**: `AdjointBPSolver` + `AdjointBPGradientBSolver` from `elmerfem/elmerice/Solvers/AdjointBP/` — clone elmerfem locally, `scp` the F90 to LUMI, then `elmerf90 -o <name>.so <name>.F90` inside a compute node (not login — Cray PrgEnv requires job env). Pattern: Ann Kristin's `ASB_FS_S3/AdjointStokes_GradientMu.so`.
- **Optimizer**: `Optimize_m1qn3Parallel` (quasi-Newton), reads gradient, writes new beta.
- **Restart**: `antarctica_init_project_3d.result.{0..1023}` from Step 4b.
- **Linear solver**: monolithic **BiCgStabL + ILU2 + scaling**, NOT `block2_idrs.sif`. The block-iterative scheme silently masks NaN matrices at this scale; the monolithic BiCgStabL is more diagnostic and converged in our setup. See Step-5 lessons below for the exact config.

Sbatch: standard envelope above; budget 12 h for the first L-curve point.

### Issues & Lessons Learned

**Pre-2026-05-23 (mesh + init era):**

- Physical group IDs in .geo must use simple IDs (1, 2) — ElmerGrid renumbers
- Body ID in SIF must match Physical Surface ID in mesh
- MMG keyword: `hmin` → `MMG hmin` in Elmer 26.1+
- Lower surface: use `floatLower(H, bedrock)` (Chen's approach)
- Direct solver: `mumps` not `umfpack` for metric computation
- LUMI /tmp is not shared across login nodes — use scratch for staging
- Gmsh parallel: `-nt 128 -algo del2d` on compute node with `--mem=200G`
- Notion API: max 100 blocks per append — split large content into parts; **`notion block move` is a silent noop**, use delete-old + append-new instead

**Step 4b debugging (2026-05-23 session):**

- **One-shot extrude + GridDataReader OOM-kills at 1024 ranks** on full-Antarctica — every task tries to load full BedMachine. Use Ann Kristin's 2-step pattern: S1 reads all NetCDFs onto the 2D mesh and writes a restart; S2 just restart-loads + extrudes + projects + reads Greve full 3D T column.
- **3D init SIF must NOT have `StructuredMeshMapper`.** Geometry mapping is deferred to the HO forward/transient SIF. Putting it in the init SIF causes "Correct Surface" to report millions of tangled nodes because 2D restart vars (`surface`, `lowersurface`) haven't yet been projected up the column when the mapper runs.
- **`StructuredProjectToPlane` is required** in the 3D init SIF to broadcast restart variables from the bottom layer to all extruded layers (`Project To Everywhere = Logical True`). Without it, restart values stay on a thin band of nodes and downstream solvers see mostly zeros.
- **Init SIF should be a single body, single Equation, single Material** — drop the `BedrockInterface` / `TopSurface` body trick from Stokes-style SIFs. Matches Ann Kristin's `ASB_init_project_3D.sif`.
- **At 1024 ranks DO NOT set `FI_CXI_RX_MATCH_MODE=hybrid`** — causes startup deadlock (Job 18793223 hung 19 min). The libfabric Fatal that motivated this env var was actually downstream of an OOM cascade; default match mode handles 1024 ranks fine.
- **Elmer lowercases the result-file prefix.** `$name = "Antarctica_init_project_3D"` writes files as `antarctica_init_project_3d.result.0..N`. Reference them in downstream SIFs with the lowercase form.
- **Always `module purge` + `ulimit -s unlimited` + `--exclusive`** in LUMI Elmer sbatch — see canonical recipe above.
- **`--partition=small` is capped at 4 nodes**; 8 nodes requires `--partition=standard`.
- **Mesh partition count must match `srun -n`**: 8 nodes × 128 = 1024 → `partitioning.1024/`. Don't drop to `partitioning.128` "just to test fast" — the SIF mesh ref resolves to whatever partition layout the rank count selects, and a mismatch silently crashes mid-LoadMesh.

**Step 5 HO inversion debugging (2026-05-23 → 2026-05-24, 30+ attempts):**

Categorised by failure mode, with the diagnostic that finally surfaced each one.

_SIF parsing / Lua / MATC:_

- **Never mix `$` (MATC) and `#` (Lua) for the same scalar.** `$niter = 100` referenced as `#niter` resolves to `nil`. Pick one namespace per variable and stay there.
- **Lua block inside an `include`d file is inert.** `!---LUA BEGIN` only executes at top-level of the main SIF Elmer loads. To share Lua scalars across SIFs (e.g. `LambdaReg` from `OPTIM_BETA.IN`), make it a plain `.lua`-syntax file and load via `assert(loadfile('./OPTIM_BETA.IN'))()` inside the main SIF's Lua block.
- **`#MAXH` etc. must actually be defined.** Audit every `#X` reference in the SIF against `shared/COLD.lua` + `Antarctica_lumi.lua` + the SIF's own Lua block. The error `Invalid characters for real 1 for keyword "X": nil` is the giveaway.

_Mesh / geometry:_

- **Restart files don't persist mesh topology.** A SIF that reads Step 4b's 3D restart still has to extrude the 2D mesh in-memory with the same `Extruded Mesh Levels = #MLEV` + `Extruded Mesh Density` directives the producer used. Otherwise `DetectExtrudedStructure: Zero rounds`.
- **`Minimum Mesh Height` (not `Minimum Height`)** is the correct keyword for `StructuredMeshMapper` to clamp tangled columns. Earlier misnamed keyword is silently ignored.
- **`StructuredProjectToPlane` with `Operator 1 = depth, Operator 2 = height` is mandatory** before `HydrostaticNSSolver` — it complains `Could not find height variable: height` otherwise.
- **Bottom BC needs `height = Real 0.0`, top BC needs `depth = Real 0.0`** as integration anchors for the height/depth solver. Missing these can produce NaN at boundaries.
- **Surface clamp via non-self-referential formula**: `surface = Variable lowersurface, thickness; Real lua "tx[0] + math.max(tx[1], 40.0)"`. The self-referential form `surface = Variable surface, lowersurface; Real lua "..."` causes Elmer to corrupt the variable during evaluation (only 6 % of tangled nodes were fixed in practice, and the SIF crashed earlier than the non-self-ref version).

_USFs / variable bindings:_

- **`Asquare_Scaled` is a 2-arg USF**: `Viscosity = Variable "bottom EF", Mu; Real Procedure "ElmerIceUSF" "Asquare_Scaled"`. Passing only `Mu` reads garbage memory for the missing arg and returns NaN viscosity → NaN matrix → block-iterative solver silently reports "diverged" while the actual issue is `nrm0 = NaN`.
- **`"bottom EF"` is the auto-created output of `StructuredProjectToPlane Variable 1 = EF; Operator 1 = bottom`** — it cannot be set directly via IC (`bottom EF = Real 1.0` causes a SIGABRT in BlockSolveInt because the variable isn't properly Elmer-managed). Pattern: declare `EF = Real 1.0` in IC, add a SPP solver to project to bottom.
- **`Flow Solution[Velocity:3 Pressure:1]` must be declared as Exported Variable** on the HO solver. Without it: `HydrostaticNSVec: Could not find components of velocity variable: flow solution`.
- **`ComputeNormalSolver` is required** if any BC uses `Compute Normal = Logical True`. Without it, normals are undefined → NaN traction at the icefront → NaN matrix.
- **Slip Coefficient `Variable alpha; Real Procedure ElmerIceUSF TenPowerA`** needs `alpha` to be initialized (typically `alpha = log10(beta)` from restart). Floor `alpha ≥ -3` (slip coef ≥ 1e-3) to avoid near-free-slip null mode in the bed BC.
- **Mu clamp**: Step 4b's Pattyn-94 Mu has zero/NaN at out-of-domain nodes. Without clamping, those produce huge inverse viscosity → velocity NRM ~ 10^30. Add IC: `Mu = Variable temp_c, Mu; Real lua "math.max(tx[1], 0.05)"` (non-self-ref via temp_c trigger; floor ≈ 0.05 in scaled MPa·yr units, typical ice 0.1-1.0).

_Boundary conditions:_

- **Icefront `Normal Surface Traction` second variable MUST be `surface` (or `bottom zs`), NOT `lowersurface`.** The cryostatic ice-pressure term is ρ_ice·g·(surface − z) — the ice column ABOVE point z. The skill-notes formula prior to 2026-05-24 used `lowersurface` (wrong) which produced ~10 MPa spurious force at the icefront base. Corrected formula (matches Rupert ISMIP6_HOtest/HO.sif):

  ```
  Normal Surface Traction = Variable Coordinate 3, surface
    Real Lua "(math.max(rhow*math.abs(gravity)*(zsl-tx[0]),0)-rhoi*math.abs(gravity)*(tx[1]-tx[0]))"
  ```
  No outer minus sign (Elmer's convention is inward-positive in this context).

_Linear solver:_

- **`block2_idrs.sif` silently masks NaN matrices.** When matrix has NaN entries (from a USF returning NaN), the block-iterative GCR+IDRS scheme reports `IterSolve: System diverged over maximum tolerance` with no per-iter residual output — even with `Linear System Residual Output = 1` and `Linear System Abort Not Converged = False`. Switch to **monolithic BiCgStabL + ILU2 + scaling** for diagnostic clarity; it gives `ERROR:: RealBiCGStab(l): Breakdown error: nrm0 = NaN.` explicitly.
- **MUMPS direct solver as a one-shot diagnostic.** Even at 1024 ranks where MUMPS will OOM during factorization, it gets past matrix assembly first — proving the matrix STRUCTURE is valid eliminates a huge class of hypotheses ("matrix has NaN from data/geometry") in a single run. ~4 min to OOM on our 14 M-node mesh.
- **Unit system is MPa·yr (scaled), not SI.** Constant `Viscosity = 1.0` works (matrix entries O(1), residuals O(1)); `Viscosity = 1e16` (interpreted as Pa·s) gives matrix entries ~1e16 → residuals ~1e18 → BiCgStabL declares divergence in the first thousand iterations.
- Working linear-solver config for Forward HO at 1024 ranks:
  ```
  Linear System Solver               = Iterative
  Linear System Iterative Method     = BiCgStabL
  BiCgStabl Polynomial Degree        = 4
  Linear System Preconditioning      = ILU2
  Linear System Convergence Tolerance = 1.0e-6
  Linear System Max Iterations       = 5000
  Linear System Residual Output      = 10
  Linear System Scaling              = Logical True
  Linear System Abort Not Converged  = False
  ```

_Mesh2MeshSolver:_

- **`Mesh = -part N "/abs/path"` hijacks the active mesh path** for all subsequent restart lookups. Cannot coexist with a Sim-block `Restart File = "..."` that resolves relative to the Header `Mesh DB`. Either drop the Sim-block restart and load everything via Mesh2MeshSolver, or use the Mesh2MeshSolver only when its source mesh equals the current mesh.
- **`Restart Position` is NOT a Mesh2MeshSolver keyword** (only valid in the Simulation block).
- **Cross-mesh warm-start is hard at parallel scale.** Loading Rupert's converged ISMIP6 β/μ via Mesh2MeshSolver looked attractive on paper but failed on path hijacking + IC variable ordering. **Fallback that works**: use Step 4b's Pattyn-94 Mu directly, clamped to a sane floor. Convergence is slower than with a converged warm-start, but the chain is at least functional.

_Diagnostics methodology that worked:_

1. Strip every IC override to constants (flat-slab geometry, uniform Mu, uniform alpha) to rule out data-driven NaN. 2 attempts.
2. Switch to MUMPS direct solver to prove matrix structure is valid (OOM during factorization is fine — it tells you the matrix exists). 1 attempt.
3. Switch to monolithic BiCgStabL with verbose residual output for explicit NaN diagnostics. 1 attempt.
4. Replace USFs with constant viscosity to isolate USF-derived NaN. 1 attempt.
5. Rebuild from there with realistic constants in the right unit system.

The total saving over chasing block-solver "divergence" red herrings: dozens of failed jobs across 18 attempts before the bisection chain above ran in 5 attempts and pinpointed the cause.
