
-- ##########################################################
-- ## Material parameters

yearinsec = 365.25 * 24.0 * 60.0 * 60.0
yearindays = 365.25 
Pa2MPa = 1.0E-06
MPainPa = 1.0e6

rhoi_si = 917.0  -- ## ice density in kg/m^3
rhoi    = rhoi_si / (1.0e6 * yearinsec^2)

-- ## ocean water density
rhoo_si = 1028.0
rhoo = rhoo_si / (1.0e6 * yearinsec^2.0)

-- ## fresh water density
rhow = 1000.0 / (1.0e6 * yearinsec^2.0)

gravity = -9.81 * yearinsec^2
gravity_abs = -gravity
gravity_si = -9.81
gravity_si_abs = 9.81

-- ## Ice fusion latent heat
Lf_si = 334000.0  -- ## Joules per kg
Lf = Lf_si * yearinsec^2.0 -- ## some old Elmer units conversion thing?  Not used I think...

-- ## Sea level elevation
zsl = 0.0

-- ## Specific heat of ocean water (4218.0 for pure water)
cw_si = 3974.0 
cw = cw_si * yearinsec^2.0

-- ## prescribed salinity at ice base for calculating ocean pressure melting temperature.  PSU.
Salinity_b = 35.0 

--  For Glen's flow law (Paterson 2010)
n  = 3.0
ng = n
m  = 1.0/n
A1_SI = 2.89165e-13
A2_SI = 2.42736e-02
A1 = A1_SI*yearinsec*1.0e18
A2 = A2_SI*yearinsec*1.0e18
Q1 = 60.0e3
Q2 = 139.0e3
Tlim = -10.0

-- ## GLToleranceInit=1.0e-1
GLTolerance=1.0e-3

--  Temperature of the simulation in Celsius
--  with the formula for A works only if T > -10
Tc=-1.0



-- ## Constants from Tyler Pelle (2023) for discharge enhanced melt parameterization
Cd            = 2.5e-3       -- drag coefficient
E0            = 3.6e-2       -- entrainment coefficient
GammaT        = 1.1e-3       -- turbulent heat-exchange coeff
gamma1        = 0.545        -- heat-exchange param
gamma2        = 3.5e-5       -- m^-1
Cd12_GammaTs0 = 6.0e-4       -- C_d^{1/2} * Gamma_{Ts0}
EPS           = 1.0e-14






-- ##########################################################
-- ## functions for material parameters and conditions

-- ## identify the grounding line in a 2D domain based on 
-- ## geometry (this is a crude approximation).
function groundingline(thick,bed,surf)
  if ((surf - thick) > (bed + 100.0) or (surf - thick) <= (bed + 1.0)) then
     gl_mask = -1.0
  else
     gl_mask = 1.0
  end
  return gl_mask
end


-- ## convert a viscosity enhancement factor to a 
-- ## flow enhancement factor, with limits.
function ConvertEF(viscEF,lowerLimit)
  if (viscEF < lowerLimit) then
    viscEF = lowerLimit
  end
  flowEF = 1.0 / viscEF
  if (flowEF < lowerLimit) then
    flowEF = lowerLimit
  end
  return flowEF
end

-- ## Scale the drag coefficient to tune thinning rates...
function ScaleDragCoef(coef)
  scaledCoef = coef*0.1
  return scaledCoef
end


-- ## for imposing a velocity condition based on temperature
-- ## input is temperature relative to pressure melting
function tempCondition(temp,tempCutoff)
  if (temp < tempCutoff) then
    cond = 1.0
  else
    cond = -1.0
  end
  return cond
end

-- ## Impose basal mass balance as lower surface normal velocity 
-- ## under shelf for steady simulations (e.g. inversions).
-- ## Note on sign:
-- ## Normal velocity is taken to be positive "outward" i.e. 
-- ## approx. downward under the ice shelf.
-- ## bmb is taken to be positive for mass gain and negative for 
-- ## mass loss.
-- ## So negative bmb => positive normal velocity
function bmb_as_vel(bmb,gmask)
  if (gmask < -0.5) then
    vel = -1.0 * bmb
  else
    vel = 0.0
  end
  return vel
end

-- ## more accurate identification of grounding line for a body
-- ## force condition if GroundedSolver is present.
-- ## Also checks velocity: allow coarse mesh for low speed GL.
function glCondition(glMask,vel,velCutoff)
  if ( (glMask < 0.5) and (glMask > -0.5) ) then 
    cond = 1.0
  else
    cond = -1.0
  end
  if ( vel < velCutoff ) then
    cond = -1.0
  end
  return cond
end

function LocateGL(glMask)
  if ( (glMask < 0.5) and (glMask > -0.5) ) then 
    cond = 1.0
  else
    cond = -1.0
  end
  return cond
end

function LocateDischarge(channelglflux)
  if (channelglflux > 1.0e8) then 
    cond = 1.0
  else
    cond = -1.0
  end
  return cond
end


-- ## function to scale a normal velocity slip coefficient 
-- ## at the ice upper surface to restrict emergence 
-- ## velocity (stronger constraint in slow flowing regions).
function ControlEmergVel(vx,vy,upplim)
  ScalingSpeed = 10.0
  speed = math.sqrt(vx*vx + vy*vy)
  SlipCoef = upplim*(1.0 - math.tanh(speed/ScalingSpeed))
end

-- ## set the distance at GL to non-zero values depending on flow speed...
-- ## (experimental; not currently used)
function distBF(vel)
  if vel > refvel then
    dist = 0.0
  else
    dist = 100000.0 * (refvel - vel)/refvel
  end
  return dist
end

-- ## function for setting an upper limit to mesh size based on distance
-- ## (e.g. distance from grounding line)
function refinebydist(distance)
  factor = distance/GLdistlim
  if (factor < 0.0) then
    factor = 0.0
  end    
  if (factor > 1.0) then
    factor = 1.0
  end    
  Mmax = Mmaxclose*(1.0-factor) + Mmaxfar*factor
  return Mmax
end

-- ## function for setting an upper limit for mesh size
function setmaxmesh(gldist,bdist,vel,glmask)
  gldistfactor = gldist/GLdistlim
  if (gldistfactor < 0.0) then
    gldistfactor = 0.0
  end
  if (gldistfactor > 1.0) then
    gldistfactor = 1.0
  end    
  bdistfactor = bdist/Bdistlim
  if (bdistfactor < 0.0) then
    bdistfactor = 0.0
  end    
  if (bdistfactor > 1.0) then
    bdistfactor = 1.0
  end    
  if (gldistfactor < bdistfactor) then
    distfactor = gldistfactor
  else
    distfactor = bdistfactor
  end
  velfactor = vel/refvel
  if (velfactor > 1.0) then
    velfactor = 1.0
  end
  if velfactor < 0.5 then
    velfactor = 0.5
  end
  Mmax = ( Mmaxclose*(1.0-distfactor) + Mmaxfar*distfactor ) / (velfactor)
  if (glmask < 0.5) then
      if (Mmax > Mmaxshelf) then
      Mmax = Mmaxshelf
    end
  end
  return Mmax
end



-- ## function for setting a lower limit for mesh size
function setminmesh(gldist,bdist,glmask)
  effectivedist = gldist - GLdistlim
  if (effectivedist < 0.0) then
    effectivedist = 0.0
  end
  distfactor = effectivedist / distscale
  if (distfactor > 1.0) then
    distfactor = 1.0
  end
  if (bdist < Bdistlim) then
    distfactor = 0
  end
  Mmin = Mminfine*(1.0-distfactor) + Mmincoarse*distfactor
  if (glmask < 0.5) then
    if (Mmin > (Mmaxshelf - 50.0) ) then
      Mmin = Mmaxshelf - 50.0
    end
  end
  return Mmin
end

-- ## set the lower surface for a given upper surface and thickness
function getlowersurface(upp_surf,thick,bed)
-- ##  if (thick < MINH) then
-- ##   thick = MINH
-- ##  end
  if ((upp_surf - thick) > bed) then
    low_surf = upp_surf - thick
  else
    low_surf = bed
  end
  return low_surf
end
function getuppersurface(upp_surf)
  uppsurf = upp_surf
  return uppsurf
end         

-- ## set the upper and lower surfaces to floatation
function floatUpper(thick,bed)
  if (thick < MINH) then
    thick = MINH
  end
  if ( (thick*rhoi/rhoo) >= -(bed) ) then
    upp_surf = bed + thick
  else
    upp_surf = thick - thick*(rhoi/rhoo)
  end
  return upp_surf
end

function floatLower(thick,bed)
  if (thick < MINH) then
    thick = MINH
  end
  if ( (thick*rhoi/rhoo) >= -bed ) then
    low_surf = bed
  else
    low_surf = -thick*rhoi/rhoo
  end
  return low_surf
end     


-- ## variable timestepping (TODO: dt_init and dt_max and dt_incr should be passed in) 1.2 dt_max=0.25
function timeStepCalc(nt)
  dt_init = 0.000001 
  dt_max = 0.20
  dt_incr = 1.15
  dt = dt_init * 1.05^nt 
  if ( dt > dt_max ) then
    dt = dt_max
  end
  return dt
end

-- ## variable timestepping
function timeStepCalc2(nt, dt_init, dt_max, dt_incr)
  dt = dt_init * dt_incr^nt 
  if ( dt > dt_max ) then
    dt = dt_max
  end
  return dt
end

-- ## thermal properties
function conductivity(T)
 k=9.828*math.exp(-5.7E-03*T)
 return k
end

-- ## heat capacity
function capacity(T)
  c=146.3+(7.253*T)
  return c
end

function sw_pressure(z)
  if (z >  0) then
    p=0.0
  else
    p=-rhoo*gravity*z
  end
  return p
end

function init_velo1(v, g1, g2, zs, zb, z)
  gt = math.sqrt(g1*g1 + g2*g2)
  vin1=-v*(g1/gt)*z
  return vin1
end

function init_velo2(v, g1, g2, z)
  gt = math.sqrt(g1*g1 + g2*g2)
  vin2=-v*(g2/gt)*z
  return vin2
end

-- ## inputs: T is temperature in Kelvin.
-- ## returns temperature in Centigrade.
function K2C(T)
  Th= T - 273.15
  return Th
end  

-- ## inputs: TinC is temperature in Centigrade, p is pressure. 
-- ## Returns temperature relative to pressure melting point.
function relativetemp(TinC,p)
  pe = p
  if (pe < 0.0) then
    pe = 0.0
  end
  Trel = TinC + 9.8e-08*1.0e06*pe
  if (Trel > 0.0) then
    Trel = 0.0
  end
  return Trel
end  

function pressuremelting(p)
  pe = p
  if (pe < 0.0) then
    pe = 0.0
  end  
  Tpmp = 273.15 - 9.8e-08*1.0e06*pe
  return Tpmp
end

function pressuremelting_salinity(p)
  pe = p
  if (pe < 0.0) then
    pe = 0.0
  end  

  Tpmp = 273.15 - 5.73e-02*Salinity_b + 9.39e-02 - 7.53e-08*1.0e06*pe

  return Tpmp
end

function initMu(TempRel)
  if (TempRel < Tlim) then
    AF = A1_SI * math.exp( -Q1/(8.314 * (273.15 + TempRel)))
  elseif (TempRel > 0) then
    AF = A2_SI * math.exp( -Q2/(8.314 * (273.15)))
  else
    AF = A2_SI * math.exp( -Q2/(8.314 * (273.15 + TempRel)))
  end
  glen = (2.0 * AF)^(-1.0/n)
  viscosity = glen * yearinsec^(-1.0/n) * Pa2MPa
  return viscosity
end
--  mu = math.sqrt(viscosity)
--  return mu

function limitslc(slc)
  slco = slc
  if (slco < 1.0e-06) then
    slco = 1.0e-06
  end
  return slco
end

-- Condition to impose no flux on the lateral side applied if
-- surface slope in the normal direction positive (should result in inflow)
-- and greater than 50m/km
function OutFlow(N1,N2,G1,G2) 
  cond=N1*G1 + N2*G2 - 0.05
  return cond
end

function evalcost(velx,vx,vely,vy)
  if (math.abs(vx)<1.0e06) then
     Cost1=0.5*(velx-tx(1))*(velx-vxy)
  else
     Cost1=0.0
  end
  if (math.abs(vy)<1.0e06) then
     Cost2=0.5*(vely-vy)*(vely-vxy)
  else
     Cost2=0.0
  end   
  return Cost1+Cost2
end

function evalcostder(vel,v)
  if (abs(v) < 1.0e06) then
    return (vel - v)
  else
    return 0.0
  end
end  

function initbeta(slc)
  dummy = slc + 0.00001
  return  math.log(dummy)
end


function effective_pressure_poc(h,zb)
  P_ice = -rhoi*gravity*h
  P_water = -rhoo*gravity*(zsl-zb)
  P_effe = P_ice - P_water

  if (P_effe<0.05) then
    P_effe = 0.05
  else

  end
  return P_effe
end

function rCoulomb_C_ini(beta,SSAVELOCITY1,SSAVELOCITY2,zb,h,GroundedMask)
  SSAvel_mag = math.sqrt(SSAVELOCITY1^2 + SSAVELOCITY2^2)
  if (GroundedMask<-0.5) then
    haf = 0.001
  elseif (zb >= 0 ) then
    haf = h
  else
    haf = h + zb/(rhoi_si/rhoo_si)
  end
  hth = 75.0
  --if haf < 0.001 then
  --  haf = 0.001
  --end
  lbd = haf/hth
  if (lbd > 1) then 
    lbd = 1.0
  elseif (lbd < 0) then 
    lbd = 1.0
  end
  tau_b = 10.0^beta*SSAvel_mag
  m = 3.0
  u0 = 300
  C = (tau_b/((SSAvel_mag/(SSAvel_mag+u0))^(1/m)))*(1.0/lbd)
  --if (GroundedMask<-0.5) then
  --  C = 0.1
  --end
  return C
end


function rCoulomb_C_NoScaling(beta,SSAVELOCITY1,SSAVELOCITY2)
  SSAvel_mag = math.sqrt(SSAVELOCITY1^2 + SSAVELOCITY2^2)
  tau_b = 10.0^beta*SSAvel_mag
  m = 3.0
  u0 = 300
  C = (tau_b/((SSAvel_mag/(SSAvel_mag+u0))^(1/m)))
  return C
end

function rCoulomb_separate_N(beta,N,SSAVELOCITY1,SSAVELOCITY2,GroundedMask)
  if GroundedMask<-0.5 or N<0.001 then
    N = 0.001
  end
  SSAvel_mag = math.sqrt(SSAVELOCITY1^2 + SSAVELOCITY2^2)
  tau_b = 10.0^beta*SSAvel_mag
  m = 5.0
  u0 = 300
  C = (tau_b/(N*(SSAvel_mag/(SSAvel_mag+u0))^(1/m)))
  return C
end

function rCoulomb_separate_N_limmin(beta,N,SSAVELOCITY1,SSAVELOCITY2,GroundedMask,h)
  lowLimN = 0.03*rhoi_si*gravity_si_abs*h*Pa2MPa
  if GroundedMask<-0.5 or N<lowLimN then
    N = lowLimN
  end
  SSAvel_mag = math.sqrt(SSAVELOCITY1^2 + SSAVELOCITY2^2)
  tau_b = 10.0^beta*SSAvel_mag
  m = 5.0
  u0 = 300
  C = (tau_b/(N*(SSAvel_mag/(SSAvel_mag+u0))^(1/m)))
  return C
end

function HAF_zc(zb,h,GroundedMask)
  if (GroundedMask<-0.5) then
    haf = 0.001
  elseif (zb >= 0 ) then
    haf = h
  else
    haf = h + zb/(rhoi_si/rhoo_si)
  end
  return haf
end

function EP_new(ef_glads,GroundedMask)
  if  (GroundedMask<-0.5) then 
    ef_glads_new = 0.001
  else
    ef_glads_new = ef_glads
  end
  return ef_glads_new
end

RandomNumbers = {298,297,304,291,292,288,305,299,296,299,297,299,297,301,296,306,290,288,288,287,294,295,293,302,299,302,305,306,290,288,300,287,297,297,304,296,294,300,301,296,293,289,298,291,286,301,291,295,300,293,301,294,300,300,295,286,292,294,291,290,303,295,304,294,302,294,302,301,293,290,302,305,292,300,295,303,302,289,304,306,296,304,298,289,290,294,301,303,302,292,297,287,288,288,300,296,289,296,289,287,303,297,305,300,298,303,304,306,286,304,298,306,297,296,302,290,296,304,298,303,301,298,291,299,287,299,299,301,304,306,302,298,305,298,286,288,304,296,303,290,297,299,286,298,293,287,296,290,288,290,289,289,286,299,291,297,300,296,297,295,288,296,303,304,291,290,297,299,294,290,305,287,288,288,289,299,298,287,305,301,301,287,304,305,306,304,302,296,289,294,288,286,305,292,292,292,295,299,286,303,297,303,293,295,287,289,299,292,304,288,306,297,300,306,292,294,295,302,303,288,289,293,287,296,293,289,290,305,300,295,305,288,301,301,297,289,298,292,288,290,304,287,291,287,295,286,304,290,287,292,295,288,306,292,292,287,292,286,296,301,299,287,287,302,305,297,288,303,293,292,301,286,287,300,298,297,301,300,302,292,300,297,294,287,302,293,298,301,288,288,297,296,304,302,301,287,287,287,302,305,300,288,301,288,288,299,292,299,301,298,301,290,301,306,304,287,293,293,300,298,302,293,290,287,302,290,294,297,290,299,296,289,302,288,292,290,297,287,294,288,288,302,292,298,306,295,300,301,295,299,288,305,289,291,302,296,302,294,291,286,300,295,295,298,287,292,302,300,288,288,287,286,294,299,301,297,288,299,288,288,288,288,289,290,292,292,290,291,304,300,297,289,290,287,305,300,297,292,289,299,306,289,291,294,287,300,294,306,294,299,289,294,289,301,304,293,300,292,297,303,298,293,292,295,294,293,297,301,294,295,288,286,292,292,299,306,305,295,291,302,301,301,301,288,300,295,290,288,303,289,289,299,304,296,300,289,306,297,300,286,302,301,288,297,292,297,294,294,289,291,286,305,299,305,289,305,302,298,295,291,301,290,287,302,300,301,299,294,294,303,292,303,302,303,296,299,305,295,287,304,298,297,304,291,292,288,305,299,296,299,297,299,297,301,296,306,290,288,288,287,294,295,293,302,299,302,305,306,290,288,300,287,297,297,304,296,294,300,301,296,293,289,298,291,286,301,291,295,300,293,301,294,300,300,295,286,292,294,291,290,303,295,304,294,302,294,302,301,293,290,302,305,292,300,295,303,302,289,304,306,296,304,298,289,290,294,301,303,302,292,297,287,288,288,300,296,289,296,289,287,303,297,305,300,298,303,304,306,286,304,298,306,297,296,302,290,296,304,298,303,301,298,291,299,287,299,299,301,304,306,302,298,305,298,286,288,304,296,303,290,297,299,286,298,293,287,296,290,288,290,289,289,286,299,291,297,300,296,297,295,288,296,303,304,291,290,297,299,294,290,305,287,288,288,289,299,298,287,305,301,301,287,304,305,306,304,302,296,289,294,288,286,305,292,292,292,295,299,286,303,297,303,293,295,287,289,299,292,304,288,306,297,300,306,292,294,295,302,303,288,289,293,287,296,293,289,290,305,300,295,305,288,301,301,297,289,298,292,288,290,304,287,291,287,295,286,304,290,287,292,295,288,306,292,292,287,292,286,296,301,299,287,287,302,305,297,288,303,293,292,301,286,287,300,298,297,301,300,302,292,300,297,294,287,302,293,298,301,288,288,297,296,304,302,301,287,287,287,302,305,300,288,301,288,288,299,292,299,301,298,301,290,301,306,304,287,293,293,300,298,302,293,290,287,302,290,294,297,290,299,296,289,302,288,292,290,297,287,294,288,288,302,292,298,306,295,300,301,295,299,288,305,289,291,302,296,302,294,291,286,300,295,295,298,287,292,302,300,288,288,287,286,294,299,301,297,288,299,288,288,288,288,289,290,292,292,290,291,304,300,297,289,290,287,305,300,297,292,289,299,306,289,291,294,287,300,294,306,294,299,289,294,289,301,304,293,300,292,297,303,298,293,292,295,294,293,297,301,294,295,288,286,292,292,299,306,305,295,291,302,301,301,301,288,300,295,290,288,303,289,289,299,304,296,300,289,306,297,300,286,302,301,288,297,292,297,294,294,289,291,286,305,299,305,289,305,302,298,295,291,301,290,287,302,300,301,299,294,294,303,292,303,302,303,296,299,305,295,287,304,298,297,304,291,292,288,305,299,296,299,297,299,297,301,296,306,290,288,288,287,294,295,293,302,299,302,305,306,290,288,300,287,297,297,304,296,294,300,301,296,293,289,298,291,286,301,291,295,300,293,301,294,300,300,295,286,292,294,291,290,303,295,304,294,302,294,302,301,293,290,302,305,292,300,295,303,302,289,304,306,296,304,298,289,290,294,301,303,302,292,297,287,288,288,300,296,289,296,289,287,303,297,305,300,298,303,304,306,286,304,298,306,297,296,302,290,296,304,298,303,301,298,291,299,287,299,299,301,304,306,302,298,305,298,286,288,304,296,303,290,297,299,286,298,293,287,296,290,288,290,289,289,286,299,291,297,300,296,297,295,288,296,303,304,291,290,297,299,294,290,305,287,288,288,289,299,298,287,305,301,301,287,304,305,306,304,302,296,289,294,288,286,305,292,292,292,295,299,286,303,297,303,293,295,287,289,299,292,304,288,306,297,300,306,292,294,295,302,303,288,289,293,287,296,293,289,290,305,300,295,305,288,301,301,297,289,298,292,288,290,304,287,291,287,295,286,304,290,287,292,295,288,306,292,292,287,292,286,296,301,299,287,287,302,305,297,288,303,293,292,301,286,287,300,298,297,301,300,302,292,300,297,294,287,302,293,298,301,288,288,297,296,304,302,301,287,287,287,302,305,300,288,301,288,288,299,292,299,301,298,301,290,301,306,304,287,293,293,300,298,302,293,290,287,302,290,294,297,290,299,296,289,302,288,292,290,297,287,294,288,288,302,292,298,306,295,300,301,295,299,288,305,289,291,302,296,302,294,291,286,300,295,295,298,287,292,302,300,288,288,287,286,294,299,301,297,288,299,288,288,288,288,289,290,292,292,290,291,304,300,297,289,290,287,305,300,297,292,289,299,306,289,291,294,287,300,294,306,294,299,289,294,289,301,304,293,300,292,297,303,298,293,292,295,294,293,297,301,294,295,288,286,292,292,299,306,305,295,291,302,301,301,301,288,300,295,290,288,303,289,289,299,304,296,300,289,306,297,300,286,302,301,288,297,292,297,294,294,289,291,286,305,299,305,289,305,302,298,295,291,301,290,287,302,300,301,299,294,294,303,292,303,302,303,296,299,305,295,287,304,298,297,304,291,292,288,305,299,296,299,297,299,297,301,296,306,290,288,288,287,294,295,293,302,299,302,305,306,290,288,300,287,297,297,304,296,294,300,301,296,293,289,298,291,286,301,291,295,300,293,301,294,300,300,295,286,292,294,291,290,303,295,304,294,302,294,302,301,293,290,302,305,292,300,295,303,302,289,304,306,296,304,298,289,290,294,301,303,302,292,297,287,288,288,300,296,289,296,289,287,303,297,305,300,298,303,304,306,286,304,298,306,297,296,302,290,296,304,298,303,301,298,291,299,287,299,299,301,304,306,302,298,305,298,286,288,304,296,303,290,297,299,286,298,293,287,296,290,288,290,289,289,286,299,291,297,300,296,297,295,288,296,303,304,291,290,297,299,294,290,305,287,288,288,289,299,298,287,305,301,301,287,304,305,306,304,302,296,289,294,288,286,305,292,292,292,295,299,286,303,297,303,293,295,287,289,299,292,304,288,306,297,300,306,292,294,295,302,303,288,289,293,287,296,293,289,290,305,300,295,305,288,301,301,297,289,298,292,288,290,304,287,291,287,295,286,304,290,287,292,295,288,306,292,292,287,292,286,296,301,299,287,287,302,305,297,288,303,293,292,301,286,287,300,298,297,301,300,302,292,300,297,294,287,302,293,298,301,288,288,297,296,304,302,301,287,287,287,302,305,300,288,301,288,288,299,292,299,301,298,301,290,301,306,304,287,293,293,300,298,302,293,290,287,302,290,294,297,290,299,296,289,302,288,292,290,297,287,294,288,288,302,292,298,306,295,300,301,295,299,288,305,289,291,302,296,302,294,291,286,300,295,295,298,287,292,302,300,288,288,287,286,294,299,301,297,288,299,288,288,288,288,289,290,292,292,290,291,304,300,297,289,290,287,305,300,297,292,289,299,306,289,291,294,287,300,294,306,294,299,289,294,289,301,304,293,300,292,297,303,298,293,292,295,294,293,297,301,294,295,288,286,292,292,299,306,305,295,291,302,301,301,301,288,300,295,290,288,303,289,289,299,304,296,300,289,306,297,300,286,302,301,288,297,292,297,294,294,289,291,286,305,299,305,289,305,302,298,295,291,301,290,287,302,300,301,299,294,294,303,292,303,302,303,296,299,305,295,287,304}
RandomNumberIndex = 1
function calculateTimePoint(Time, StartFrom)
  local TimePoint = Time + StartFrom
  if TimePoint <= 306 then
      return TimePoint
  else
      local randomNumber = RandomNumbers[RandomNumberIndex]
      RandomNumberIndex = RandomNumberIndex + 1
      return randomNumber
  end
end

function Weert2Budd(vx,vy,beta,N)
  m = 3.0
  v_mag = math.sqrt(vx^2 + vy^2)
  tau_b = 10.0^beta*v_mag
  budd_beta = tau_b*rhoi*gravity_abs/(N*v_mag^(1.0/m))
  return budd_beta
end

-- ## variable timestepping (TODO: dt_init and dt_max and dt_incr should be passed in)
function timeStepCalc3(nt)
  dt_init = 0.1/yearindays
  dt_max  = 0.5/yearindays
  dt_incr = 1.001
  dt = dt_init * dt_incr^nt 
  if ( dt > dt_max ) then
    dt = dt_max
  end
  return dt
end

function N_rCoulombC(N,rCoulombC)
  if (N < 0.001) then
    N = 0.001
  end
  N_C = N*rCoulombC
  return N_C
end

function N_rCoulombC_limmin(N,rCoulombC,h)
  lowLimN = 0.03*rhoi_si*gravity_si_abs*h*Pa2MPa
  if N<lowLimN then
    N = lowLimN
  end
  N_C = N*rCoulombC
  return N_C
end

function N_rCoulombC_LimMinMax(N,rCoulombC,h,GroundedMask)
  P_ice = rhoi_si*gravity_si_abs*h*Pa2MPa
  lowLimN = 0.03*P_ice
  if GroundedMask<-0.5 or N<lowLimN then
    N = lowLimN
  end
  if N>P_ice then
    N = P_ice
  end
  N_C = N*rCoulombC
  return N_C
end

function rCoulomb_SepN_LimMinMax(beta,N,SSAVELOCITY1,SSAVELOCITY2,GroundedMask,h)
  P_ice = rhoi_si*gravity_si_abs*h*Pa2MPa
  lowLimN = 0.03*P_ice
  if GroundedMask<-0.5 or N<lowLimN then
    N = lowLimN
  end
  if N>P_ice then
    N = P_ice
  end
  SSAvel_mag = math.sqrt(SSAVELOCITY1^2 + SSAVELOCITY2^2)
  tau_b = 10.0^beta*SSAvel_mag
  m = 5.0
  u0 = 300
  C = (tau_b/(N*(SSAvel_mag/(SSAvel_mag+u0))^(1/m)))
  return C
end

function Calculate_rCoulombC(beta, N_filtered, SSAVELOCITY1, SSAVELOCITY2)
  local SSAvel_mag = math.sqrt(SSAVELOCITY1^2 + SSAVELOCITY2^2)
  local tau_b = 10^beta * SSAvel_mag
  local m = 3.0
  local u0 = 300.0
  local SSAvel_term = SSAvel_mag / (SSAvel_mag + u0)
  local C = tau_b / (N_filtered * SSAvel_term^(1/m))
  return C
end

function Calculate_betaRC(beta, SSAVELOCITY1, SSAVELOCITY2)
  local SSAvel_mag = math.sqrt(SSAVELOCITY1^2 + SSAVELOCITY2^2)
  local tau_b = 10^beta * SSAvel_mag
  local m = 3.0
  local u0 = 300.0
  local SSAvel_term = SSAvel_mag / (SSAvel_mag + u0)
  local C = tau_b / SSAvel_term^(1/m)
  return math.log10(C)
end

function Calculate_betaRC_with_betaM(beta, SSAVELOCITY1, SSAVELOCITY2)
  local m = 5.0
  local SSAvel_mag = math.sqrt(SSAVELOCITY1^2 + SSAVELOCITY2^2)
  local tau_b = 10^beta * SSAvel_mag^3.0
  local u0 = 300.0
  local SSAvel_term = SSAvel_mag / (SSAvel_mag + u0)
  local C = tau_b / SSAvel_term^(1/m)
  return math.log10(C)
end



function N_filter_after_GlaDS(N, connmask_front, connmask_combined, zb, h)
  local pinning = connmask_front - connmask_combined
  local P_ice = rhoi_si * gravity_si_abs * h * Pa2MPa
  local P_water = rhoo_si * gravity_si_abs * (zsl - zb) * Pa2MPa

  if pinning > 0 then
    N = math.min(math.max(P_ice - P_water, 0.05), P_ice)
  else
    N = math.min(math.max(N, 0.05), P_ice)
  end

  return N
end

function Calculate_rCoulombC_withN(betam, N, SSAVELOCITY1, SSAVELOCITY2)
  if N < 0.1 then
    N = 0.1
  end
  local m = 3.0
  local u0 = 300.0
  local SSAvel_mag = math.sqrt(SSAVELOCITY1^2.0 + SSAVELOCITY2^2.0)
  local tau_b = 10.0^betam * SSAvel_mag^(1.0/m)
  local SSAvel_term = SSAvel_mag / (SSAvel_mag + u0)
  local C = tau_b / (N * SSAvel_term^(1.0/m))
  return C
end

function Calculate_rCoulombC_withN_hT46(betam, N, SSAVELOCITY1, SSAVELOCITY2,haf)
  local m = 3.0
  local u0 = 300.0
  local hth = 46.0
  
  local hth = 46.0
  if haf>hth then
    lbd = 1.0
  else
    lbd = haf/hth
  end
  local N_filtered = lbd*N

  if N_filtered < 0.05 then
    N_filtered = 0.05
  end

  local SSAvel_mag = math.sqrt(SSAVELOCITY1^2.0 + SSAVELOCITY2^2.0)
  local tau_b = 10.0^betam * SSAvel_mag^(1.0/m)
  local SSAvel_term = SSAvel_mag / (SSAvel_mag + u0)
  local C = tau_b / (N_filtered * SSAvel_term^(1.0/m))

  return C
end


function Scale_N46(N,haf)
  local hth = 46.0
  if haf>hth then
    lbd = 1.0
  else
    lbd = haf/hth
  end
  local N_filtered = lbd*N
  return N_filtered
end

function Calculate_rCoulombC_withN_n5(betam, N, SSAVELOCITY1, SSAVELOCITY2)
  if N < 0.1 then
    N = 0.1
  end
  local m = 5.0
  local u0 = 300.0
  local SSAvel_mag = math.sqrt(SSAVELOCITY1^2.0 + SSAVELOCITY2^2.0)
  local tau_b = 10.0^betam * SSAvel_mag^(1.0/3.0)
  local SSAvel_term = SSAvel_mag / (SSAvel_mag + u0)
  local C = tau_b / (N * SSAvel_term^(1.0/m))
  return C
end

function Calculate_rCoulomb_As_withN_n5(betam, N, SSAVELOCITY1, SSAVELOCITY2)
  if N < 0.05 then
    N = 0.05
  end
  local m = 5.0
  local Cmax = 0.8
  local SSAvel_mag = math.sqrt(SSAVELOCITY1^2.0 + SSAVELOCITY2^2.0)
  local tau_b = 10.0^betam * SSAvel_mag^(1.0/3.0)
  local As = (Cmax^m*N^m*SSAvel_mag-SSAvel_mag*tau_b^m)/(tau_b*Cmax*N)^m
  if As < 0.0001 then
    As = 0.0001
  end
  return As
end



function Calculate_rCoulomb_As_withN_n5_MinN001(betam, N, SSAVELOCITY1, SSAVELOCITY2)
  if N < 0.01 then
    N = 0.01
  end
  local m = 5.0
  local Cmax = 0.8
  local SSAvel_mag = math.sqrt(SSAVELOCITY1^2.0 + SSAVELOCITY2^2.0)
  local tau_b = 10.0^betam * SSAvel_mag^(1.0/3.0)
  local As = (Cmax^m*N^m*SSAvel_mag-SSAvel_mag*tau_b^m)/(tau_b*Cmax*N)^m
  if As < 0.0001 then
    As = 0.0001
  end
  return As
end

function Calculate_rCoulomb_As_withN_n5_Cmax02(betam, N, SSAVELOCITY1, SSAVELOCITY2)
  if N < 0.05 then
    N = 0.05
  end
  local m = 5.0
  local Cmax = 0.2
  local SSAvel_mag = math.sqrt(SSAVELOCITY1^2.0 + SSAVELOCITY2^2.0)
  local tau_b = 10.0^betam * SSAvel_mag^(1.0/3.0)
  local As = (Cmax^m*N^m*SSAvel_mag-SSAvel_mag*tau_b^m)/(tau_b*Cmax*N)^m
  if As < 0.0001 then
    As = 0.0001
  end
  return As
end

function Calculate_rCoulomb_As_withN_n5_Cmax05(betam, N, SSAVELOCITY1, SSAVELOCITY2)
  if N < 0.05 then
    N = 0.05
  end
  local m = 5.0
  local Cmax = 0.5
  local SSAvel_mag = math.sqrt(SSAVELOCITY1^2.0 + SSAVELOCITY2^2.0)
  local tau_b = 10.0^betam * SSAvel_mag^(1.0/3.0)
  local As = (Cmax^m*N^m*SSAvel_mag-SSAvel_mag*tau_b^m)/(tau_b*Cmax*N)^m
  if As < 0.0001 then
    As = 0.0001
  end
  return As
end

function Calculate_rCoulomb_As_withN_n5_Cmax02_MinN001(betam, N, SSAVELOCITY1, SSAVELOCITY2)
  if N < 0.01 then
    N = 0.01
  end
  local m = 5.0
  local Cmax = 0.2
  local SSAvel_mag = math.sqrt(SSAVELOCITY1^2.0 + SSAVELOCITY2^2.0)
  local tau_b = 10.0^betam * SSAvel_mag^(1.0/3.0)
  local As = (Cmax^m*N^m*SSAvel_mag-SSAvel_mag*tau_b^m)/(tau_b*Cmax*N)^m
  if As < 0.0001 then
    As = 0.0001
  end
  return As
end

function Calculate_rCoulomb_logAs_n5C08(betam, N, SSAVELOCITY1, SSAVELOCITY2)
  local m = 5.0
  local Cmax = 0.8
  local SSAvel_mag = math.sqrt(SSAVELOCITY1^2.0 + SSAVELOCITY2^2.0)
  local tau_b = 10.0^betam * SSAvel_mag^(1.0/3.0)
  local As = (Cmax^m*N^m*SSAvel_mag-SSAvel_mag*tau_b^m)/(tau_b*Cmax*N)^m
  if As < 10 then
    As = 10
  end
  return math.log10(As)
end


function Calculate_rCoulomb_betaRC_C02(ceff, N, SSAVELOCITY1, SSAVELOCITY2)
  local m = 5.0
  local Cmax = 0.2
  local SSAvel_mag = math.sqrt(SSAVELOCITY1^2.0 + SSAVELOCITY2^2.0)
  local tau_b = ceff * SSAvel_mag
  local As = (Cmax^m*N^m*SSAvel_mag-SSAvel_mag*tau_b^m)/(tau_b*Cmax*N)^m
  -- ##if As < 10 then
  -- ##  As = 10
  -- ##end
  return math.log10(As)
end

function Calculate_rCoulomb_betaRC_C08(ceff, N, SSAVELOCITY1, SSAVELOCITY2)
  local m = 5.0
  local Cmax = 0.8
  local SSAvel_mag = math.sqrt(SSAVELOCITY1^2.0 + SSAVELOCITY2^2.0)
  local tau_b = ceff * SSAvel_mag
  local As = (Cmax^m*N^m*SSAvel_mag-SSAvel_mag*tau_b^m)/(tau_b*Cmax*N)^m
  -- ##if As < 10 then
  -- ##  As = 10
  -- ##end
  return math.log10(As)
end


function computeChi(vx, vy, betaRC, effectivePressure)
  local speed = math.sqrt(vx * vx + vy * vy)
  local neff = math.max(effectivePressure, 0.05)
  local numerator = speed
  local denominator = (0.2 ^ 5.0) * (neff ^ 5.0) * (10.0 ^ betaRC)
  if denominator == 0.0 then
    return 0.0
  end
  return numerator / denominator
end


function calculate_ice_normal_stress(h)
  if h < 10 then
    h = 10
  end
  local P_ice = rhoi * gravity_abs * h 
  return P_ice
end
