# Step 5 debugging chronicle

The day-by-day record of debugging the Step 5 HO inversion. Categorised lessons are in [`LESSONS.md`](LESSONS.md); this file is the chronological narrative.

Spans 2026-05-23 → 2026-05-25, ~34 sbatch attempts.

---

## 10 · Step 5 debugging chronicle (2026-05-23 PM)

Single sit-down session that took the S5 HO inversion from a parse-failing draft (Job 18794274) through six iterations of root-cause-and-fix. Final job 18797029 is the first to survive into the actual HO solve.

### 10.1 Sequential failures and fixes

| # | Job | Lasted | Failure | Root cause | Fix |
|---|---|---|---|---|---|
| 1 | 18794274 | 53 s | `Steady State Max Iterations = nil` | `$niter`, `$LambdaReg`, `$minbeta` defined as MATC but referenced as Lua (`#niter` / `Real lua "... minbeta ..."`) — different namespaces | Move into the SIF `!---LUA BEGIN` block as Lua globals |
| 2 | 18796475 | 52 s | `Max H = nil` | `#MAXH` referenced but never defined in any include | Add `MAXH = 6000.0` to `shared/Antarctica_lumi.lua` |
| 3 | 18796635 | 38 s | `Lambda = nil` again | Elmer does NOT process `!---LUA BEGIN` inside `include`d files — `OPTIM_BETA.IN` Lua block was inert | Convert `OPTIM_BETA.IN` to plain Lua (no SIF markers), load via `assert(loadfile('./OPTIM_BETA.IN'))()` in the SIF Lua block |
| 4 | 18796745 | 61 s | `DetectExtrudedStructure: Zero rounds implies unsuccessful operation` | 2D mesh on disk wasn't extruded in-memory; restart loads 3D variable values but mesh stays 2D | Add `Extruded Mesh Levels = #MLEV` + `Extruded Mesh Density = "1.0 + 2.5 * tx"` to Simulation block |
| 5 | 18796834 | 6:45 | `HydrostaticNSVec: Could not find height variable: height` | `height`/`depth` are not auto-computed; HO solver expects them as variables | Insert new Solver: `StructuredProjectToPlane` with `Operator 1 = depth`, `Operator 2 = height` right after MapCoordinate |
| 6 | 18796834 (next round) | 6:45 | `IterSolve: System diverged over maximum tolerance` (block2_idrs linear solve, every rank, on first BP nonlinear iter) | Two compounding issues: (a) `Minimum Height` keyword on StructuredMeshMapper is silently ignored (correct name is `Minimum Mesh Height`) — left 4.5 M tangled nodes; (b) `Viscosity = Variable Mu; Real Procedure ElmerIceUSF Asquare_Scaled` passes one arg, but Rupert's working Totten HO SIF shows Asquare_Scaled is a **2-arg USF**: `(bottom_EF, Mu)`. Missing first arg → garbage second arg → divergent viscosity → linear solve blows up | Rename keyword; add `bottom EF` as Exported Variable (=1.0 everywhere via IC); change Material to `Viscosity = Variable "bottom EF", Mu` |
| 7 | 18797029 | 1:56 | Process aborted with core dump inside `BlockSolveInt` / `BlockInitMatrix`; no Elmer ERROR string captured | StructuredMeshMapper STILL reports 4 502 475 tangled nodes despite the keyword rename (so `Minimum Mesh Height` either isn't honoured in our Elmer version, or 32 % of columns genuinely have surface ≤ lowersurface in the Step 4b restart — needs verification). When `HydrostaticNSSolver` then tries to assemble the block matrix on the broken geometry, a downstream rank segfaults and srun terminates the rest | TBD — next session: (a) instrument the SIF with a `SaveData` solver to dump surface, lowersurface, thickness right after MapCoordinate so we can see which columns are degenerate; (b) compare against Step 4b's output VTU for the same nodes; (c) consider re-running Step 4b with explicit `Min H` clamp before writing restart |
| 8 | (pending) | — | (next attempt — see actions in row 7) | — | — |

### 10.2 Generalisable lessons

- **Never mix MATC `$` and Lua `#` in the same scalar.** Pick one namespace per variable and stay there. The error message `Non-numeric characters for integer for keyword X: nil` is the giveaway.
- **`!---LUA BEGIN` blocks ONLY execute at top-level of the SIF actually loaded by ElmerSolver.** Lua inside `include`d files is dead code. Either inline the Lua, or load the file with Lua's `loadfile` from inside the SIF's own Lua block.
- **Restart files persist variable VALUES per node, not mesh TOPOLOGY.** A SIF that consumes a 3D-extruded restart still has to re-create the same 3D mesh from the 2D mesh on disk — `Extruded Mesh Levels` and `Extruded Mesh Density` must match the producer SIF exactly.
- **`HydrostaticNSSolver` requires a `height` variable.** Add a `StructuredProjectToPlane` solver before it with `Operator 1 = depth`, `Operator 2 = height`.
- **Always grep Rupert's `Totten_HOTest/*.sif` for the function signatures of every USF you call.** `Asquare_Scaled` takes `(bottom_EF, Mu)`, not `Mu` alone. The .so won't tell you — it just reads garbage memory for missing args and returns a diverging viscosity field.
- **`Minimum Mesh Height`** is the keyword that StructuredMeshMapper actually consumes. `Minimum Height` is silently ignored and leaves tangled-node clamping disabled.

### 10.3 Joint inversion deliverable (drafted same session)

`Antarctica_invert_joint_S5.sif` (uploaded, 13 solvers, 16 kB) — simultaneous β + Mu inversion via m1qn3 on a packed control vector. Mirrors Ann Kristin's `ASB_SSA_S3_Lsurface.sif` joint-variable pattern, adapted for the HO 2-DOF state.

Packed control / gradient (the m1qn3 view):

```
Exported Variable = Var[alpha:1 etaMu:1]
Exported Variable = DJDVar[DJDalpha:1 DJDetaMu:1]
```

- `alpha = log10(β)` — bed-only, declared on bulk (interior values inert).
- `etaMu = log10(Mu / MuPrior)` — 3D bulk perturbation around the frozen restart Mu field. Initial `etaMu = 0` → no perturbation at iter 0.

Key implementation choices:

- **Two split gradient solvers** (HO splits what SSA does in one): `AdjointBP_GradientBetaSolver` writes DJDalpha at bed; `AdjointBP_GradientMuSolver` writes DJDetaMu in bulk. Both write into the shared DJDVar via the `[name:dof]` alias syntax.
- **Mu refresh each iter**: a small `UpdateExport` solver re-evaluates `Mu = MuPrior * 10^etaMu` from the IC formula before each steady-state iteration. No custom Fortran needed.
- **Change-of-variable factor** for the Mu gradient: `Viscosity derivative = ln(10) * Mu` in Material.
- **Three regularisers**: Tikhonov smoothness on alpha (λ = LambdaReg), Tikhonov smoothness on etaMu (λ = LambdaRegMu), and a prior pull of etaMu → 0 (λ = LambdaPriorMu = 1e3) — without the prior the optimiser aliases soft bed against weak ice (depth-resolved degeneracy that SSA avoids by depth-averaging).

Compiled today: `src/AdjointBP_GradientMuSolver.so` (elmerf90 on login node — works; one harmless legacy SAVE warning).

### 10.4 Recommended next session

**Current blocker**: 4.5 M tangled nodes (≈ 32 %) in StructuredMeshMapper, surviving the `Minimum Mesh Height` rename. This is the next thing to nail down — every fix above is upstream of getting a clean linear assembly. Plan:

1. Add a small `SaveData` solver that runs once after MapCoordinate and dumps `surface`, `lowersurface`, `thickness = surface − lowersurface`, `groundedmask` to a CSV. Run on a tiny single-node debug build (32 ranks, 5-min job) to read it back locally.
2. Cross-check the same nodes against `antarctica_init_project_3d.result.0` (the bottom-layer band of the restart) and against Step 4b's VTU if still on disk. If the 2D values are degenerate at the source, fix in Step 4b (likely needs `Min H = #MINH` clamp on the bottom-layer write).
3. If 2D values are fine but the 3D broadcast didn't propagate, re-run Step 4b with explicit `StructuredProjectToPlane Project To Everywhere = Logical True` audit.

**After β-only converges**:

1. L-curve sweep `LambdaReg ∈ {1e4, 1e5, 1e6, 1e7, 1e8}` on the β-only SIF; pick the elbow.
2. Then run `Antarctica_invert_joint_S5.sif` with `LambdaReg` from step 1, `LambdaRegMu = LambdaReg`, `LambdaPriorMu = LambdaRegMu / 1000`. Validate that Mu stays within ~½–2× of MuPrior across the bulk; if it drifts further, raise `LambdaPriorMu`.

### 10.5 Updated file list under `S5_HO_Inversion/`

```
S5_HO_Inversion/
├── Antarctica_invert_beta_S5.sif         # 9 solvers — patched today
├── Antarctica_invert_joint_S5.sif        # 13 solvers — new today, joint β + Mu via packed Var/DJDVar
├── OPTIM_BETA.IN                          # plain Lua now: LambdaReg, LambdaRegMu, LambdaPriorMu
├── block2_idrs.sif                        # byte-identical to Rupert's
├── COLD.lua → ../shared/COLD.lua
├── Antarctica_lumi.lua → ../shared/Antarctica_lumi.lua  # MAXH = 6000.0 added
├── run_invert_S5_lumi.sh                  # beta-only sbatch
├── run_invert_joint_S5_lumi.sh            # joint sbatch (24 h, 1024 ranks)
├── mesh2D_Antarctica_1km_refined/         # symlink
└── src/
    ├── AdjointBP_GradientBetaSolver.{F90,so}
    └── AdjointBP_GradientMuSolver.{F90,so}    # .so compiled today
```

---

## 11 · Step 5 debugging chronicle, day 2 (2026-05-24)

Continuation of day-1 chronicle (Section 10). Day 1 ended with Job 18797029 — first run to clear the SIF/parse/geometry hurdles, then hit `IterSolve: System diverged` inside the block-iterative HO linear solve at 1024 ranks. Day 2 was the marathon of diagnosing **why** that divergence happened. Spoiler: it was NEVER a block-solver tuning issue — the block solver was silently masking a NaN-matrix bug.

### 11.1 The full attempt ladder (24 runs)

Compressed because most early ones were SIF / parse issues — see Section 10 for those. Day-2 substantive runs:

| # | Job | Time | What we tested | Result / signal |
|---|-----|------|----------------|-----------------|
| 17 | 18798395 | 0:44 | Force flat slab (lowersurface=0, surface=1000, thickness=1000, Mu=1, alpha=0, EF=1, temp_c=-10, HV=0). Bisect: data vs SIF | "4.5 M tangled" message DISAPPEARED (IC override works), but `IterSolve diverged` identical → not data, not geometry |
| 18 | 18800976 | 0:23 | Same flat-slab + add `ComputeNormalSolver` (was missing in our SIF, present in Rupert's) | `ComputeNormalSolver: End` logged successfully, divergence unchanged → normals not the issue |
| 19-20 | 18801053, 18801086 | MPI transient + 22 s | Add `temp_c = -10` IC override | First MPI Bsend transient; retry showed same divergence → temp_c not the issue |
| 21 | 18801106 | 3:41 | **Switch Forward HO to MUMPS direct solver** (Rupert's ISMIP6 HO.sif setting) | `OUT_OF_MEMORY (status 0:125)` during factorization. **Crucially: MUMPS got past matrix assembly**, no NaN error, no zero pivot → **matrix structure is VALID**. Eliminates 18 attempts' worth of hypotheses about "matrix has NaN entries from data/geometry". |
| 22 | 18801185 | 0:24 | Switch back to iterative, use **BiCgStabL + ILU2 monolithic** (no blocks). Revert IC overrides to data-driven | `ERROR:: RealBiCGStab(l): Breakdown error: nrm0 = NaN.` — first time we see explicit NaN in initial-residual. Block2_idrs had been silently calling this "diverged". |
| 23 | 18801241 | 17:16 | Replace `Viscosity = Asquare_Scaled(bottom EF, Mu)` with constant `Viscosity = 1.0e16` | **Iterates** for 2351 BiCgStabL steps! Residuals oscillate around 1e18, occasional 1e21 spike triggers divergence threshold. **The Asquare_Scaled USF was the NaN source.** |
| **24** | **18801567** | **in flight** | Same as 23 but `Viscosity = Real 1.0` (correct scaled MPa·yr unit, not 1e16) | TBD |

### 11.2 Root cause synthesis

The actual sequence of bugs we untangled:

1. **`Asquare_Scaled` USF returns NaN** at every node because it expects 2 args `(bottom EF, Mu)` and either:
   - `bottom EF` wasn't being created by our `StructuredProjectToPlane Operator = bottom` solver (Solver 3 in beta SIF), OR
   - The variable existed but was uninitialised memory, OR
   - Rupert's setup somehow has additional init we haven't replicated.
2. **NaN viscosity → NaN matrix entries** at every interior element.
3. **`block2_idrs.sif`'s iterative solver, on a NaN matrix, prints `IterSolve diverged` instead of `nrm0 = NaN`** — silently failed in a non-diagnostic way.
4. We spent 17 attempts chasing red herrings (IC overrides, BC fixes, missing solvers, scaling, etc.) because the error message pointed at "block solver divergence" rather than the underlying NaN.

The bisection that broke the deadlock:
- **MUMPS** ruled out matrix-structure problems (got past assembly → matrix is *structurally* valid).
- **BiCgStabL** is more diagnostic than block-iterative GCR — it gives `nrm0 = NaN` rather than swallowing it as "diverged".
- **Constant viscosity** confirmed Asquare_Scaled was the culprit by eliminating the NaN.

### 11.3 Lessons for future Elmer HO setups

- **`Asquare_Scaled` is fragile** at parallel scale. The "bottom EF" projection chain (declare EF in IC, declare EF as Exported Variable, run StructuredProjectToPlane with Variable=EF / Operator=bottom) needs an end-to-end verification — at minimum, save the "bottom EF" variable to VTU and inspect before relying on it in Material.
- **Block-iterative solvers can lie**. `IterSolve diverged` is not informative when initial residual is NaN. Always test with a monolithic iterative method (BiCgStabL+ILU2) as a fallback — its error messages are explicit about NaN.
- **MUMPS is a powerful diagnostic** even when it OOMs. Reaching OOM during factorization proves matrix structure is correct, eliminating a huge class of hypotheses.
- **Don't trust unit assumptions across SIFs**. Rupert's setup uses Pa·s for viscosity in some places, MPa·yr scaled in others. Verify the unit system that the loaded modules actually expect. Constant Viscosity = 1.0e16 in scaled units gave matrix entries ~1e16 → residuals ~1e18.

### 11.4 Current state of files

LUMI `S5_HO_Inversion/Antarctica_invert_beta_S5.sif` (running Job 18801567):

- **Material**: `Viscosity = Real 1.0` (constant, diagnostic — to be restored to Asquare_Scaled after BiCgStabL convergence proves the rest of the chain works)
- **Forward HO linear solver**: BiCgStabL polynomial degree 4 + ILU2 + scaling, 5000 max iters, 1e-6 tolerance, residual output every 10 iters, Abort=False
- **Adjoint linear solver**: same setup as forward
- **ICs**: data-driven from Step 4b restart, with `surface = lowersurface + max(thickness, 40)` clamp as defensive geometry safety
- **Solvers**: 11 total — MapCoord, HeightDepth, ProjectEF, Forward HO, Cost, Adjoint, GradientBeta, Reg, m1qn3, ResultOutput, ComputeNormalSolver (the last one is `Before Simulation`)

### 11.5 Next steps once Job 18801567 lands

If converges:
1. Get baseline `Cost_*.dat` trajectory and confirm m1qn3 takes steps that decrease cost.
2. **Debug `Asquare_Scaled`** properly — save `bottom EF` and `Mu` to VTU at start of run; verify they're finite. The most likely fix is to add `Body Force 1 → bottom EF = Real 1.0` so it's set on the bulk body, not just IC.
3. Restore proper Glen-law viscosity via Asquare_Scaled.
4. Sweep `LambdaReg ∈ {1e4 … 1e8}` for L-curve.
5. Mirror the fix to `Antarctica_invert_joint_S5.sif` for the β + Mu joint inversion.

If still problematic:
- Try MUMPS but on fewer ranks (256 instead of 1024) — may fit in memory.
- Or replace BiCgStabL with GCR + IDRS combo and tune tolerances more carefully.

---

## 12 · Step 5 — resume guide for next session

Section 11 captured the chronicle. This section is the "what to do when you sit back down". Day-3 summary plus a decision tree for the next session.

### 12.1 Where we are right now (2026-05-25)

**Currently running**: Job **18813072** — `Antarctica_invert_beta_S5.sif` with Picard relaxation + Critical Shear Rate fix. At last check (~1:20 elapsed of 12 h budget):

```
Nonlinear iter 1: NRM = 1050.0 m/yr,  RELC = 2.000   (start, constant-viscosity)
Nonlinear iter 2: NRM = 6208.5 m/yr,  RELC = 1.421   ← Picard contraction! First time today.
Nonlinear iter 3: in progress
```

The RELC decreasing from 2.0 → 1.4 is the first sign the nonlinear loop is **actually converging** rather than diverging (compare Job 18805270 where RELC stayed near 2.0 and NRM blew up to 10^17). Velocity NRM is in the realistic range (~10^3 m/yr, Antarctic ice streams peak ~3000 m/yr).

If the run lands and produces `Cost_*.dat`, that's the first end-to-end success and the L-curve sweep can begin. If it stalls at high RELC, try `Nonlinear System Relaxation Factor = 0.3` (more damping) or add Rupert's warm-start (see 12.4).

### 12.2 Current working SIF (what's actually deployed)

Path: `S5_HO_Inversion/Antarctica_invert_beta_S5.sif` on LUMI (and synced locally at `/Users/eddie/Documents/HO Antarctica/S5_HO_Inversion/`).

Key knobs that took 34 attempts to settle on:

| Component | Setting | Why |
|-----------|---------|-----|
| **Restart** | Sim-block, relative path `antarctica_init_project_3d.result` (Step 4b output) | NO Mesh2MeshSolver — caused mesh-path hijacking |
| **Material Viscosity** | `Variable Mu; Real lua "tx[0]"` (passthrough, Mu from Step 4b's Pattyn-94 fit) | Asquare_Scaled USF was the original NaN source ("bottom EF" issue) — bypassed |
| **Mu clamp** | `Mu = Variable temp_c, Mu; Real lua "math.max(tx[1], 0.05)"` in IC 1 | Floor at 0.05 (MPa·yr scaled units) prevents NaN/zero Mu from blowing up matrix |
| **Surface clamp** | `surface = Variable lowersurface, thickness; Real lua "tx[0] + math.max(tx[1], 40.0)"` | Non-self-ref clamp on thin-ice columns |
| **Linear solver** | Monolithic **BiCgStabL pd=4 + ILU2 + scaling**, NOT block2_idrs.sif | block2_idrs silently masks NaN; BiCgStabL gives explicit diagnostics |
| **Convergence tol / max iter** | 1e-6 / 5000, `Abort Not Converged = False` | Let nonlinear continue even if linear doesn't fully converge |
| **Nonlinear relaxation** | `Nonlinear System Relaxation Factor = Real 0.5` | THE key new knob today — without it, Picard diverged from iter 2 |
| **Critical Shear Rate** | `1.0E-5` (was 1e-10) | Floors strain rate in Glen's law η ∝ ε̇^(-2/3) to keep viscosity bounded |
| **Solvers** | 1=MapCoord, 2=HeightDepth, 3=ProjectEF, 4=ForwardHO, 5=Cost, 6=AdjointLinear, 7=GradientBeta, 8=Reg, 9=m1qn3, 10=ResultOutput, 11=ComputeNormalSolver | All on Body 1 except 5 (Body 2, Top), 7+8 (Body 3, Bottom) |
| **Exported Variable 5** | `Flow Solution[Velocity:3 Pressure:1]` | Required by HydrostaticNSVec (mirrors Rupert's HO.sif line 297) |
| **Icefront BC formula** | Variable `surface` not `lowersurface`, NO outer minus sign | Skill-notes formula was wrong — corrected 2026-05-24 (see Section 11.3 / SKILL.md) |

### 12.3 sbatch envelope with OFI workarounds

`run_invert_S5_lumi.sh` now has three Slingshot/CXI env vars after four MPI Bsend transient crashes today:

```bash
export FI_CXI_RDZV_PROTO=alt_read       # alternate RDMA rendezvous protocol
export MPICH_OFI_STARTUP_CONNECT=1      # pre-connect ranks at MPI_Init
export FI_CXI_DEFAULT_TX_SIZE=8192      # bigger OFI Tx queue
```

Do NOT add `FI_CXI_RX_MATCH_MODE=hybrid` (Step 4b lesson — Job 18793223 hung 19 min in MPI init).

### 12.4 Decision tree when next session starts

**Step 1 — Check if Job 18813072 produced output**:

```bash
ssh yuwang1@lumi.csc.fi "ls -la /scratch/project_462001251/YuWang/HO_Antarctica/S5_HO_Inversion/Cost*.dat /scratch/project_462001251/YuWang/HO_Antarctica/S5_HO_Inversion/M1QN3*.out 2>/dev/null"
```

**If Cost.dat exists**: first end-to-end success! Check whether cost is decreasing. If yes:
- Sweep `LambdaReg ∈ {1e4, 1e5, 1e6, 1e7, 1e8}` for L-curve — edit `OPTIM_BETA.IN`, resubmit.
- Once L-curve elbow chosen, ramp `niter` to 200-500 and run to full convergence.
- Then derive joint β + μ SIF (template already exists at `Antarctica_invert_joint_S5.sif` — needs the same fixes as beta-only).

**If Cost.dat doesn't exist** (job hit 12h limit without converging, or HO nonlinear didn't converge):
- Examine the final iter's RELC. If still > 1, try `Nonlinear System Relaxation Factor = 0.3` (more damping) and resubmit.
- If RELC < 1 but iters slow, add Rupert's warm-start (see 12.5).

**If job died with new error**: grep for `ERROR|FATAL|forrtl|nrm0|Breakdown` in `.out`, consult `~/.claude/skills/HO-Antarctica/SKILL.md` "Step 5 HO inversion debugging" section for known failure modes.

### 12.5 Adding Rupert's warm-start (UNTESTED — proposed only)

We never successfully integrated Mesh2MeshSolver because it consistently overrode the active mesh path BEFORE Sim-block restart loaded. The fix we never tried: set `Restart Before Initial Conditions = Logical False` inside the Mesh2MeshSolver block — this is the dial that decides whether Mesh2MeshSolver runs early (and hijacks the path) vs late (after Sim-block restart finishes).

Proposed solver block to add at end of SIF:

```bash
Solver 12
  Exec Solver = "Before Simulation"
  Equation = "InterpFromRupert"
  Procedure = "Mesh2MeshSolver" "Mesh2MeshSolver"
  Mesh = -part 252 "/scratch/project_462001251/gladston/ISMIP6_HOtest/mesh2D_AA_ZC_1kmGL_refined"
  Restart File = File "HIST30.result"
  Restart Error Continue = Logical True
  Restart Before Initial Conditions = Logical False    ! THE KEY: False, not True (previous attempts all used True)
  Interpolation Passive Coordinate = Integer 3
  restart variable 1 = String mu
End
```

Plus in Material: change `Viscosity = Variable Mu` → `Viscosity = Variable mu` (lowercase — Mesh2MeshSolver writes the variable with the name it has in HIST30, which is lowercase `mu`).

Plus in Equation 1: add `12` to the Active Solvers list.

The execution order should be:
1. Sim-block restart loads Step 4b (Mu capital = Pattyn-94)
2. ICs apply with Step 4b values (HV1 = vx, alpha = log10(beta) — all Step 4b)
3. Solver 12 fires (Before Simulation) → writes Rupert's converged `mu` (lowercase) onto our mesh
4. HO solve begins → Material reads `Variable mu` → Rupert's μ powers the matrix

What Rupert's HIST30.result.0 contains (verified):

| Variable | Dimension | Meaning |
|----------|-----------|---------|
| `mu` | 1D (2D bed nodes) | His converged viscosity prefactor — what we want |
| `beta` | 1D | His converged β |
| `vx, vy` | 1D | His converged surface velocity |
| `groundedmask, bedrock, zs, zb, h, beta0, mueta2` | 1D | Geometry and aux |

His mesh: `/scratch/project_462001251/gladston/ISMIP6_HOtest/mesh2D_AA_ZC_1kmGL_refined/` (252 partitions). Coordinate system is EPSG:3031 (same as ours — Antarctic Polar Stereographic).

### 12.6 Files and locations cheat sheet

| Resource | Path |
|----------|------|
| Working SIF (LUMI) | `/scratch/project_462001251/YuWang/HO_Antarctica/S5_HO_Inversion/Antarctica_invert_beta_S5.sif` |
| Working SIF (local) | `/Users/eddie/Documents/HO Antarctica/S5_HO_Inversion/Antarctica_invert_beta_S5.sif` |
| sbatch script | `S5_HO_Inversion/run_invert_S5_lumi.sh` (3 OFI env vars) |
| Joint β+μ template | `S5_HO_Inversion/Antarctica_invert_joint_S5.sif` (13 solvers, draft from day 1 — needs same fixes as beta-only) |
| L-curve config | `S5_HO_Inversion/OPTIM_BETA.IN` (plain Lua: `LambdaReg`, `LambdaRegMu`, `LambdaPriorMu`) |
| Block preconditioner | `S5_HO_Inversion/block2_idrs.sif` (deprecated — kept as reference) |
| Rupert reference | `/scratch/project_462001251/gladston/ISMIP6_HOtest/HO.sif` and `HIST30.result.0` |
| Skill memory | `/Users/eddie/.claude/skills/HO-Antarctica/SKILL.md` (361 lines, all today's lessons) |
| Notion page | `31f311d1-6609-801c-8e59-d969cdbc80fd` |

### 12.7 Job audit (today's runs)

Today executed Jobs 18801053 → 18813072 (~30 jobs). The "what worked" highlights:

| Issue | Fix that landed |
|-------|----------------|
| `nrm0 = NaN` from Asquare_Scaled USF | Bypassed: `Viscosity = Variable Mu; Real lua "tx[0]"` |
| Velocity NRM = 10^30 | Mu floor clamp at 0.05 + `Critical Shear Rate = 1e-5` |
| MPI Bsend OFI errors (×4) | OFI env vars: `alt_read`, `STARTUP_CONNECT=1`, `TX_SIZE=8192` |
| Picard divergence (iter 2 → 10^17) | `Nonlinear System Relaxation Factor = 0.5` |
| `Could not find components of velocity: flow solution` | `Exported Variable 5 = Flow Solution[Velocity:3 Pressure:1]` |

### 12.8 Skill memory is up to date

Don't re-derive lessons from scratch — `/Users/eddie/.claude/skills/HO-Antarctica/SKILL.md` has all categorised lessons (SIF parsing, mesh/geometry, USFs, BCs, linear solver, Mesh2MeshSolver) plus the 5-step diagnostic methodology. Read that section before debugging anything new.
