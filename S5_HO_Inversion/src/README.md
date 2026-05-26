# AdjointBP custom solvers

These are F90 Elmer/Ice solvers for HO inversion. The upstream Elmer module on LUMI (`/projappl/project_462001194/modules/elmer/elmerice`) provides the `Adjoint_*` family and the full `AdjointSSA_*` family, but **NOT** `AdjointBP_*`. We compile these locally.

## Files

| File | Purpose |
|------|---------|
| `AdjointBP_GradientBetaSolver.F90` | ∂J/∂α gradient at the bed (α = log10 β). Adapted from `AdjointStokes_GradientBetaSolver.F90`. |
| `AdjointBP_GradientMuSolver.F90` | ∂J/∂η gradient in the bulk (η = log10 Mu). Adapted from `AdjointStokes_GradientMu.F90`. Needed for the joint β + μ inversion (`Antarctica_invert_joint_S5.sif`). |

## Compile on LUMI

The login node works (Cray PrgEnv inherits the right env from the module load):

```bash
ssh yuwang1@lumi.csc.fi
module purge
module use /projappl/project_462001194/modules/
module load elmer/elmerice

cd /scratch/project_462001251/YuWang/HO_Antarctica/S5_HO_Inversion/src
elmerf90 -o AdjointBP_GradientBetaSolver.so AdjointBP_GradientBetaSolver.F90
elmerf90 -o AdjointBP_GradientMuSolver.so AdjointBP_GradientMuSolver.F90
```

Expected output: one harmless `Legacy Extension: Duplicate SAVE attribute` warning, then a 40-50 KB `.so` file.

## Wire into the SIF

The sbatch script `run_invert_S5_lumi.sh` adds `src/` to `LD_LIBRARY_PATH`:

```bash
export LD_LIBRARY_PATH=/scratch/project_462001251/YuWang/HO_Antarctica/S5_HO_Inversion/src:$LD_LIBRARY_PATH
```

Then the SIF references them by name without the `.so`:

```
Solver 7
  Equation = "DJDalpha"
  Procedure = File "AdjointBP_GradientBetaSolver" "AdjointBP_GradientBetaSolver"
  ...
End
```
