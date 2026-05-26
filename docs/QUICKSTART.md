# Quickstart — Resuming work on Step 5 HO inversion

This guide is the "what to do when you sit back down" cheat sheet, as of **2026-05-25**.

## Where we are right now

A current Step-5 HO inversion test job is running on LUMI: `Antarctica_invert_beta_S5.sif` (the SIF in this repo, under `S5_HO_Inversion/`), submitted as Job **18813072** at 1024 ranks. At last check (1:20 elapsed of 12h budget):

```
Nonlinear iter 1: NRM = 1050.0 m/yr,  RELC = 2.000   (constant-viscosity start)
Nonlinear iter 2: NRM = 6208.5 m/yr,  RELC = 1.421   ← Picard contraction! First contraction today.
Nonlinear iter 3: in progress
```

This is the first job that's making real physics progress (velocity in realistic 10³ m/yr range, RELC decreasing). Earlier runs either diverged catastrophically (NRM 10¹⁷ m/yr) or hit MPI/SIF bugs. See `CHRONICLE.md` for the full 34-attempt journey.

## First thing to do in a new session

```bash
ssh yuwang1@lumi.csc.fi "ls -la /scratch/project_462001251/YuWang/HO_Antarctica/S5_HO_Inversion/Cost*.dat /scratch/project_462001251/YuWang/HO_Antarctica/S5_HO_Inversion/M1QN3*.out 2>/dev/null && sacct -j 18813072 --format=JobID,State,Elapsed,ExitCode -P 2>/dev/null | head -3"
```

If `Cost_*.dat` exists → first end-to-end success! Continue with L-curve.

If not → check whether the job is still running, completed at time limit, or hit a new error.

## Decision tree

### A. Cost.dat exists, cost decreasing

This is the success path. Now run an L-curve sweep:

1. Edit `S5_HO_Inversion/OPTIM_BETA.IN` — change `LambdaReg` to each of `{1e4, 1e5, 1e6, 1e7, 1e8}`, one at a time.
2. For each value, resubmit `sbatch run_invert_S5_lumi.sh` and let it run to completion or to a useful iteration count (~20 m1qn3 iters).
3. Plot `J_misfit` vs `J_reg` from the Cost files; pick the elbow value of λ.
4. Re-run at the chosen λ with `niter = 200-500` for full convergence.

After β-only converges, derive the joint β + μ SIF — template at `S5_HO_Inversion/Antarctica_invert_joint_S5.sif` (drafted day 1, needs the same fixes the beta-only SIF received).

### B. Job hit 12h time limit, didn't converge

Examine the last nonlinear iter's RELC.

- **RELC still > 1**: Picard is stalled. Try `Nonlinear System Relaxation Factor = Real 0.3` (more damping; currently 0.5).
- **RELC < 1 but slow**: matrix is being solved but linear solver is wasting iterations. Either tighten ILU2 → ILU3, or add Rupert's warm-start (section C).
- **Linear solve still maxing out 5000 iters per nonlinear**: bump `Linear System Max Iterations = 10000`.

### C. Add Rupert's warm-start (the untested path)

Five attempts on day 2 tried to integrate Rupert's converged ISMIP6 SSA inversion (`HIST30.result.0` on his 252-partition mesh) via `Mesh2MeshSolver`. All failed because the solver's `Mesh = -part 252 "/abs/path"` directive hijacked the active mesh path BEFORE the Sim-block restart loaded, breaking Step 4b's restart.

**The fix we never tried**: set `Restart Before Initial Conditions = Logical False` inside the Mesh2MeshSolver block (we always used `True`). With `False`, the solver runs in the regular "Before Simulation" exec slot — AFTER Sim-block restart finishes loading.

Proposed addition to `Antarctica_invert_beta_S5.sif`:

```
Solver 12
  Exec Solver = "Before Simulation"
  Equation = "InterpFromRupert"
  Procedure = "Mesh2MeshSolver" "Mesh2MeshSolver"
  Mesh = -part 252 "/scratch/project_462001251/gladston/ISMIP6_HOtest/mesh2D_AA_ZC_1kmGL_refined"
  Restart File = File "HIST30.result"
  Restart Error Continue = Logical True
  Restart Before Initial Conditions = Logical False   ! KEY: False, not True
  Interpolation Passive Coordinate = Integer 3
  restart variable 1 = String mu
End
```

Plus:
- Material: change `Viscosity = Variable Mu` → `Viscosity = Variable mu` (lowercase to match HIST30's variable name).
- Equation 1: add `12` to the Active Solvers list.

### D. New error, not seen before

`grep -nE 'ERROR|FATAL|forrtl|nrm0|Breakdown|Could not'` in the `.out` log. Then consult [`LESSONS.md`](LESSONS.md) — 30+ Elmer/Ice failure modes are documented there.

## Re-running from scratch

If you need to re-run Step 5 from a clean LUMI state:

```bash
ssh yuwang1@lumi.csc.fi
cd /scratch/project_462001251/YuWang/HO_Antarctica/S5_HO_Inversion

# Verify Mu/Beta gradient .so files exist
ls -la src/AdjointBP_GradientBetaSolver.so src/AdjointBP_GradientMuSolver.so

# If missing, compile on a login node:
module purge
module use /projappl/project_462001194/modules/
module load elmer/elmerice
cd src
elmerf90 -o AdjointBP_GradientBetaSolver.so AdjointBP_GradientBetaSolver.F90
elmerf90 -o AdjointBP_GradientMuSolver.so AdjointBP_GradientMuSolver.F90
cd ..

# Verify Step 4b restart files exist (1024 partition files)
ls mesh2D_Antarctica_1km_refined/antarctica_init_project_3d.result.* | wc -l   # should be 1024

# Submit
sbatch run_invert_S5_lumi.sh
```

## Monitoring while running

```bash
# Job state
ssh yuwang1@lumi.csc.fi "squeue -u yuwang1; sacct -j <JOBID> --format=State,Elapsed -P -n | head -1"

# Nonlinear iter progress
ssh yuwang1@lumi.csc.fi "grep -E 'Nonlinear iteration|ComputeChange' /scratch/.../Ant_invertB.<JOBID>.out | tail -20"

# Linear-solver residuals (BiCgStabL prints every 10 iters)
ssh yuwang1@lumi.csc.fi "tail -30 /scratch/.../Ant_invertB.<JOBID>.out"

# Cost & m1qn3 (once produced)
ssh yuwang1@lumi.csc.fi "tail -20 /scratch/.../Cost_Antarctica_invert_beta_S5.dat /scratch/.../M1QN3_Antarctica_invert_beta_S5.out"
```

## Key files in this repo

| File | What it is |
|------|------------|
| `S5_HO_Inversion/Antarctica_invert_beta_S5.sif` | The current production SIF (34 attempts to get here) |
| `S5_HO_Inversion/Antarctica_invert_joint_S5.sif` | Joint β + μ template — needs same fixes as beta SIF before running |
| `S5_HO_Inversion/run_invert_S5_lumi.sh` | sbatch with all 3 OFI workarounds |
| `S5_HO_Inversion/OPTIM_BETA.IN` | L-curve λ values (plain Lua, loaded via `loadfile` in SIF) |
| `S5_HO_Inversion/block2_idrs.sif` | DEPRECATED — block-iterative preconditioner that silently masked NaN. Kept as reference only |
| `S5_HO_Inversion/src/AdjointBP_*.F90` | Custom Fortran solvers — compile on LUMI with `elmerf90` |
| `mesh_refinement/Antarctica_init_S1.sif` | Step S1 (2D data load from BedMachine/MEaSUREs/Pattyn-94) |
| `mesh_refinement/Antarctica_init_project_3D.sif` | Step S2 (extrude to 3D + project 2D vars up the column + Greve T) |
| `mesh_refinement/Antarctica_mesh_refinement.sif` | MMG2D adaptive refinement |

## Don't repeat known mistakes

Read these before changing anything substantial:

1. **Never mix `$` (MATC) and `#` (Lua) for the same scalar.** Different namespaces. The error `Invalid characters for real X: nil` is the giveaway.
2. **Lua block inside an `include`d file is INERT.** Elmer only parses `!---LUA BEGIN` at the top level of the SIF being loaded. Use `assert(loadfile('./X.IN'))()` from inside the main Lua block instead.
3. **Don't put `block2_idrs.sif` back.** It silently masked a NaN-matrix bug for ~18 attempts. Use monolithic BiCgStabL + ILU2 + scaling instead.
4. **The icefront BC uses `surface` not `lowersurface`**, and there is NO outer minus sign. The earlier skill-note formula was wrong.
5. **`Asquare_Scaled` USF wants 2 args** `(bottom EF, mu)`. The "bottom EF" must come from a `StructuredProjectToPlane` solver — cannot be set directly in IC.
6. **MPI Bsend OFI errors at 1024 ranks** are fixed by the 3 env vars in `run_invert_S5_lumi.sh`. Don't remove them. Do NOT add `FI_CXI_RX_MATCH_MODE=hybrid` (caused 19-min hang in earlier Step 4b).
