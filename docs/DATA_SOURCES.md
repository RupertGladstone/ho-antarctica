# Data sources

All input NetCDFs / TIFs live on the HPC scratch — they're large (multi-GB) and are NOT included in this repo. This page records where to find them.

## LUMI (project_462001251)

### Antarctica boundary, surface, bed, ice thickness
```
/projappl/project_2002875/data/antarctic/BedMachineAntarctica_V4.nc
```

### Surface velocity (observation, also IC warm-start for vx, vy)
```
/projappl/project_2002875/data/antarctic/antarctic_ice_vel_phase_map_v01_errordel_inpaint_extend_slim.nc
```
MEaSUREs phase-map, inpainted to remove NaN edges.

### Viscosity prefactor (Mu, Pattyn-94 fit)
```
/projappl/project_2002875/data/antarctic/ant08_b2_future25-06_hist0001_MuMean_pat94.nc
```
**Note**: this NetCDF has zero/NaN fill values outside the data domain. Step 5 ICs clamp `Mu` at floor 0.05 to avoid pathological matrix entries.

### Basal friction prior (beta)
```
/projappl/project_2002875/data/antarctic/aa_v3_e8_l11_beta.nc
```

### Surface mass balance (SMB)
```
/projappl/project_2002875/data/antarctic/smbref_1995_2014_mar.nc
```
MAR regional model, 1995-2014 mean.

### Temperature (Greve full 3D)
```
/scratch/project_462001251/lundjohansen/data/ant08_b2_future25-06_hist0001.nc
```
Greve historic temperature, full 3D column. Used by `Antarctica_init_project_3D.sif` (Step 4b).

## Mahti (project_2000881)

Mirror of the same datasets:
```
/projappl/project_2002875/data/antarctic/
```

## Rupert's reference results

```
/scratch/project_462001251/gladston/ISMIP6_HOtest/
  HO.sif                                          ! continent-scale HO SIF (closest analog)
  ASB.lua, COLD.lua, MISISSAE.lua                 ! Lua configs
  batchElmer.sh                                   ! sbatch layouts (6×42, 4×63, 2×126)
  README.asc                                      ! pre-flight checklist
  block2_idrs.sif                                 ! block GS + IDRS preconditioner
  mesh2D_AA_ZC_1kmGL_refined/                     ! Chen's refined mesh + result files (252 partitions)
    HIST30.result.0..251                          ! converged SSA β, μ, vx, vy
    HO.result.0, HO2.result.0                     ! HO forward outputs
```

```
/scratch/project_462001251/gladston/Totten_HOTest/
  ASB_HO_HIST_S5_legacy_discont_20yr.sif          ! basin-scale HO historic — Step 6 template
  block2_idrs.sif                                 ! same precond
  Flotation.F90, FlotationLocal.so                ! local Flotation fix (drop-in if upstream breaks)
  batchElmer.sh                                   ! 1 node × 128 ranks, 72 h time
```

## Ann Kristin's reference FS inversion

```
/scratch/project_462001251/lundjohansen/ASB/
  ASB_FS/ASB_FS_S1/ASB_init_S1_2D.sif              ! 2-step init pattern source (we mirrored this)
  ASB_FS/ASB_FS_S1/ASB_init_project_3D.sif         ! 3D extrusion + projection
  ASB_FS/ASB_FS_S3/ASB_inverse_S3.sif              ! FS S3 inversion template
  ASB_SSA/ASB_SSA_S3/ASB_SSA_S3_Lsurface.sif       ! SSA dual-variable inversion (joint β + μ packing template)
```

## Chen's ISMIP6 reference (Mahti)

```
/scratch/project_2000881/czhao/ISMIP6/
  AE05/      ! 2 km grounding line mesh (473K nodes), config AAnew2km.lua
  AE-1km/    ! 1 km grounding line mesh (948K nodes), config AAnew.lua
  AE-500m/   ! 500 m grounding line mesh (1.93M nodes), config AAnew500m.lua
```

## Our mesh & restart files (LUMI)

```
/scratch/project_462001251/YuWang/HO_Antarctica/
  shared/                                          ! shared Lua configs (COLD.lua, Antarctica_lumi.lua)
  Mesh_refinement_1km/                             ! mesh refinement SIF + the actual 2D mesh dir (~650 MB)
    mesh2D_Antarctica_1km_refined/                 ! 1024-partition refined mesh
  Init_S1_2D/                                      ! S1 2D data init outputs
  Init_3D/                                         ! S2 3D extrusion outputs (Step 4b)
    antarctica_init_project_3d.result.0..1023      ! the restart file Step 5 reads
  S5_HO_Inversion/                                 ! current Step 5 working dir (mirrors this repo's S5_HO_Inversion/)
  _archive/                                        ! dead-end runs (e.g. 2026-04-17 one-shot extrude OOM)
```

## Important: Step 4b restart file is THE input to Step 5

The Step 5 SIF reads `antarctica_init_project_3d.result.{0..1023}` from `Step 4b`'s output. If that restart file is missing or corrupted, Step 5 cannot run. Verify with:

```bash
ssh yuwang1@lumi.csc.fi "ls /scratch/project_462001251/YuWang/HO_Antarctica/S5_HO_Inversion/mesh2D_Antarctica_1km_refined/antarctica_init_project_3d.result.* | wc -l"
```

Should print `1024`.
