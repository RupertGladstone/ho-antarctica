
-- ##########################################################
-- ## Antarctica continent mesh parameters — LUMI edition
-- ## Based on Antarctica.lua; paths point to LUMI data
-- ## Yu Wang, April 2026
-- ##########################################################

-- ## Data directory on LUMI
datadir = "/scratch/project_462001251/YuWang/data_antarctic"
outdir  = "./vtuoutputs"
meshdb  = "./mesh2D_Antarctica_1km_refined"

-- ## Min threshold value for Ice thickness (Real)
MINH = 40.0

-- ## Levels in the vertical (for 3D extrusion)
MLEV = 15

-- ## Controlling steady state iterations
IMIN = 10
IMAX = 100

Tol   = 0.01
DPtol = 0.001

-- ## For block preconditioner
blocktol = 0.001

-- ## Run name (used in output filenames)
name = "Antarctica_S0"

-- ##########################################################
-- ## Mesh I/O names (1 km refined variant, our primary mesh)
-- ##########################################################

MESH_IN  = "mesh2D_Antarctica_1km"
MESH_OUT = "mesh2D_Antarctica_1km_refined"

-- ## Tolerated interpolation errors on velocity and thickness
U_err = 2
H_err = 35.0

-- ##########################################################
-- ## Mesh size limits in different regions
-- ## (kept for completeness; refinement already done on Mahti)
-- ##########################################################

Mminfine    = 1000.0
Mmincoarse  = 10000.0
Mmaxfar     = 25000.0
Mmaxclose   = 1000.0
Mmaxshelf   = 3000.0
refvel      = 700.0
GLdistlim   = 600000.0
Bdistlim    = 100000.0
distscale   = 300000.0

-- ##########################################################
-- ## Paths to forcing data on LUMI
-- ##########################################################

-- ## BedMachine Antarctica V4 (Ann Kristin's pre-filled version)
TOPOGRAPHY_DATA = "/scratch/project_462001251/lundjohansen/data/bedmachine_v4_filled_vostok.nc"

-- ## MEaSUREs velocity (error-deleted, inpainted, extended)
VELOCITY_DATA = "/scratch/project_462001251/lundjohansen/data/antarctic_ice_vel_phase_map_v01_errordel_inpaint_extend_slim.nc"

-- ## Viscosity (Pattyn 1994 depth-averaged estimate) — transferred from Mahti
VISCOSITY_DATA = "/scratch/project_462001251/YuWang/data_antarctic/ant08_b2_future25-06_hist0001_MuMean_pat94.nc"

-- ## Basal friction parameter (beta initial guess) — transferred from Mahti
SLIP_DATA = "/scratch/project_462001251/YuWang/data_antarctic/aa_v3_e8_l11_beta.nc"

-- ## Surface mass balance (MAR reference 1995-2014) — transferred from Mahti
SMB_DATA = "/scratch/project_462001251/YuWang/data_antarctic/smbref_1995_2014_mar.nc"
