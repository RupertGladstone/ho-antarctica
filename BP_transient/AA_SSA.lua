

datadir = "/projappl/project_2002875/data/antarctic"

MINH = 40.0
MLEV = 15

IMIN = 10
IMAX = 100
Tol = 0.01
DPtol = 0.001
blocktol = 0.001

name = "Antarctica_1km_S0"

MESH_IN = "mesh2D_Antarctica"
MESH_OUT = "mesh2D_ANT_1km_refined"

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
-- ## Paths to forcing data on Mahti
-- ##########################################################
TOPOGRAPHY_DATA = "/projappl/project_2002875/data/antarctic/BedMachineAntarctica_V4.nc"
VELOCITY_DATA = "/projappl/project_2002875/data/antarctic/antarctic_ice_vel_phase_map_v01_errordel_inpaint_extend_slim.nc"
VISCOSITY_DATA = "/projappl/project_2002875/data/antarctic/ant08_b2_future25-06_hist0001_MuMean_pat94.nc"
-- ## Basal friction parameter (beta initial guess) — from Chen's ISMIP6 inversion
SLIP_DATA = "/scratch/project_2000881/czhao/data/beta_ismip6_cz.nc"

-- ## EF parameter (alpha initial guess) — from Chen's ISMIP6 inversion
EF_DATA = "/scratch/project_2000881/czhao/data/alpha_ismip6_cz.nc"

-- ## Greve full 3D temperature column (sigma coords)
GREVE_T_DATA = "/projappl/project_2002875/data/antarctic/ant08_b2_future25-06_hist0001.nc"

SMB_DATA = "/projappl/project_2002875/data/antarctic/smbref_1995_2014_mar.nc"
-- ## Stål et al. (2021) geothermal heat flux recommended by ISMIP7 community
GHF_DATA = "/projappl/project_2002875/data/antarctic/GHF_Stal2021_ISMIP7_1km.nc"