
-- ##########################################################
-- ## Whole-Antarctic GlaDS spin-up parameters
-- ##
-- ## Load COLD.lua before this file. COLD.lua defines the
-- ## m-year-MPa unit conversions, rhoi, rhow, gravity,
-- ## gravity_abs, yearinsec, MPainPa, and Lf.
-- ##########################################################

-- ## Production spin-up timestep schedule.
-- ## Input and output are in model years.
function gladsTimeStep(timeYears)
  if timeYears < 5.0 then
    return 0.1 / 365.25
  elseif timeYears < 25.0 then
    return 0.25 / 365.25
  else
    return 0.5 / 365.25
  end
end

-- ## Convert geothermal heat flux for the Elmer/Ice GroundedMelt solver.
GHF_scal = yearinsec / (1.0e6 * 1.0e6)

-- ## Grounded-mask tolerance.
GLTolerance = 1.0e-5

-- ## GlaDS sheet parameters.
-- ## All Units are in m, year, MPa
ev = 0.001 -- ## Englacial void ratio
Aglen = 2.5e-25 * yearinsec * MPainPa^3
Ar = Aglen
alphas = 1.25 
betas = 1.5 
lr = 2.0   -- ## Cavity spacing
hr = 0.08  -- ## Bedrock bump height
Ks = 0.002 * yearinsec * (1.0 / MPainPa)^(1.0 - betas)  -- ##Sheet conductivity coefficient
Hs = 0.05 -- ## Initial sheet thickness


-- ## GlaDS channel parameters.
alphac = 1.25
betac = 1.5
Kc = 0.5 * yearinsec * (1.0 / MPainPa)^(1.0 - betac) -- ## Channel conductivity coefficient 
Ac = Aglen
lc = 2.0   -- ## Sheet width below channel
Ct = -7.5e-8 * MPainPa  -- ## Pressure melting coefficient
Cw = 4220.0 * yearinsec^2
Lw = 334000.0 * yearinsec^2
