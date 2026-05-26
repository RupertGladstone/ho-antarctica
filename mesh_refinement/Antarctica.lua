
-- ##########################################################
-- ## Antarctica continent mesh refinement parameters
-- ## Based on Chen's AAnew2km.lua, adapted for HO Antarctica
-- ## Yu Wang, April 2026
-- ##########################################################

-- ## Data directory on Mahti
datadir = "/projappl/project_2002875/data/antarctic"
outdir = "./vtuoutputs"
meshdb = "./mesh2D_Antarctica_2km_refined"

-- ## Min threshold value for Ice thickness (Real)
MINH = 40.0

-- ## Levels in the vertical (for later 3D extrusion)
MLEV = 15

-- ## Controlling steady state iterations
IMIN = 10
IMAX = 100

Tol = 0.01
DPtol = 0.001

-- ## For block preconditioner
blocktol = 0.001

-- ## Run name (used in output filenames)
name = "Antarctica_S0"

-- ##########################################################
-- ## Mesh refinement parameters
-- ##########################################################

-- ## The name of the mesh to optimise (2km initial mesh)
MESH_IN = "mesh2D_Antarctica_2km"

-- ## Output mesh name
MESH_OUT = "mesh2D_Antarctica_2km_refined"

-- ## Tolerated interpolation errors on velocity and thickness
-- ## Same as Chen's ISMIP6 setup
U_err = 2
H_err = 35.0

-- ##########################################################
-- ## Mesh size limits in different regions
-- ##
-- ## Target: GL and shelves ~1 km, far inland ~25 km
-- ##########################################################

-- ## Absolute minimum mesh size (metres)
-- ## 1 km at GL and ice shelves
Mminfine = 1000.0

-- ## Minimum mesh size far from grounding line
-- ## (prevents detailed refinement in slow-flowing interior)
Mmincoarse = 10000.0

-- ## Maximum mesh size far from the grounding line (~25 km)
Mmaxfar = 25000.0

-- ## Maximum mesh size close to the grounding line (1 km)
Mmaxclose = 1000.0

-- ## Maximum mesh size for ice shelves (1 km)
Mmaxshelf = 1000.0

-- ## Reference velocity used in refinement to set upper limit
-- ## on element size (together with distance from GL).
refvel = 700.0

-- ## Distance from grounding line at which upper limit for
-- ## maximum mesh size is reached (metres)
GLdistlim = 600000.0

-- ## Distance from boundary at which upper limit for
-- ## maximum mesh size is reached (metres)
Bdistlim = 100000.0

-- ## For distances beyond GLdistlim, minimum mesh size may be
-- ## increased towards Mmincoarse on this distance scale
distscale = 300000.0

-- ##########################################################
-- ## Paths to forcing data
-- ##########################################################

-- ## BedMachine Antarctica V4
TOPOGRAPHY_DATA = "/projappl/project_2002875/data/antarctic/BedMachineAntarctica_V4.nc"

-- ## MEaSUREs velocity (error-deleted, inpainted, extended)
VELOCITY_DATA = "/projappl/project_2002875/data/antarctic/antarctic_ice_vel_phase_map_v01_errordel_inpaint_extend_slim.nc"

-- ## Viscosity (Pattyn 1994 depth-averaged estimate)
VISCOSITY_DATA = "/projappl/project_2002875/data/antarctic/ant08_b2_future25-06_hist0001_MuMean_pat94.nc"

-- ## Basal friction parameter (beta initial guess)
SLIP_DATA = "/projappl/project_2002875/data/antarctic/aa_v3_e8_l11_beta.nc"

-- ## Surface mass balance (MAR reference 1995-2014)
SMB_DATA = "/projappl/project_2002875/data/antarctic/smbref_1995_2014_mar.nc"
