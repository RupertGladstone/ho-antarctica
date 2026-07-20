
# BP handover 

This subdirectory contains files and notes 

## Solver input files

The BP_SpinUp input file is just spinning up the BP flow solution from zero using the optimised parameters read in from a result file (currently from SSA inversions).

The BP_Trans input file restarts from the spun up solution and evolves through time, so the geometry and groundedmask evolution is turned on. This is probably a good starting point for ISMIP7 simulations. I have put some notes in for things you need to add (search “TODO” in the .sif).

Several further sif files have been added, used in various tests. Current recommendation for the transient simulations is BP_T10b_L10.sif.
This incorporates the modified setting for mesh extrusion to ensure that a node layer sits exactly at sea level for floating ice, avoiding systematic bias in the integrated ice front force balance.

Note that both of the above are "transient", but the first one starts with uniform zero velocity and just runs one timestep with no geometry evolution. The second one uses the velocity from the first one and runs forward in time (albeit without ISMIP7 forcing).


#### Run times

The transient run above had a 30 day timestep. It took about 3 minutes per timestep, around 40 minutes for the 1 year in total. This was in an interactive queue. I don't know if the batch queue will be any different, I don't know why it would be. This gives us around 70 years of simulated timeon the 2-day LUMI standard partition. To run from 2015 to 2300 (285 years) we might need about 4 LUMI 2-day jobs. For 1020 cores on 8 nodes this is about 200k core hours.

This was with 12 extruded mesh levels with thinner layers near the bed. I expect it'll speed up if you run with 10 levels. I haven't experimented with different extruded mesh parameters, but I think in general keeping the finer vertical resolution near the bed and at least 10 levels in total is a good idea.


#### LUMI projects

We can't increase the resources on an existing LUMI project. If we need more core hours, which we do, we need to open a new project. We should do this sooner rather than later, to make sure we have sufficient resource for the production runs. 

We currently have around 3000000 core hours left on project 462001251. 3000k / 200k = approx. 15 full simulations. Given that there are other users on this project, the cheat sheet lists 6 runs this long (as well as other runs), we want to do some tier 2 and 3 runs, we'll certainly waste some hours getting it wrong, we most definitely need a new project for this.

Update 20th July 2026: Project 462001251 is rapidly diminishing. Down to 1200000 core hours.

Update 20th July 2026: Project 462001629 is for ISMIP7 runs. It is waiting approval from CSC.

Update 20th July 2026: Project 462001627 is for idealised simulations, no ISMIP7, but can be temporarily used if 462001251 is empty before 462001629 becomes available.


#### Outputting

I put in two output solvers. One for the bulk and one for the boundary. I do this because I like to download outputs to look at on my laptop and the full files are very large. So I use the icemap/utils to merge the boundary files into one vtu file per timestep and to extract a subregion of interest (and then merge) for the bulk. So I download two much smaller files that contain enough info for me to check the state looks sane.

You will need to change this for ISMIP7. You need to add XIOS and output unstructured netcdf for further processing. You may wish to turn off my vtu outputs entirely, or to reduce the frequency greatly. My suggestion would be to turn off outputting the bulk elements and output the boundary info very infrequently.


#### A note on BP solvers settings.

I’ve provisionally set the linear and nonlinear tolerances a bit larger for the transient run compared to the spin up, just to make it go a bit faster. I didn’t quite get convergence with the tighter settings, hence there is a nonlinear relaxation factor used in the spin up but not in the transient sif. Feel free to experiment!

I found the GCR and ILUT settings pretty optimal for linear solve for the spin up (I tried various settings) but they might not be optimal for the transient run, I’ve not experimented with different settings post spin up. I guess the block preconditioner might give faster convergence if it converges, and convergence was probably most problematic spinning up from rest.


## Updated code

The version of the BP solver here has a few small (but two of them are important) changes compared to the repository version.

More complete summary of changes here:
https://github.com/RupertGladstone/BlIP/blob/main/HydrostaticNSVec_local_changes.txt


The "flow solution" is now updated every nonlinear iteration instead of after nonlinear convergence. This is because the sliding code quietly looks for “flow solution” by default (it would need a  code change to let it use a 2 dofs variable other than the SSA velocity), so updating the flow solution only after nonlinear convergence removes the nonlinear sliding – flow speed feedback from the friction parameterisation.

Thomas implemented an optional velocity limit, which was applied to flow solution. I have switched this from the flow solution to the vertically averaged velocity, since this is the property used by the thickness solver to evolve the ice thickness. Now that we have more stable behaviour the limit is probably not needed anyway.

There's a new optional "minimum viscosity" parameter (which gets applied to effective viscosity at run time, not the "viscosity" material property). This is currently needed because of the small region of very low alpha which otherwise goes unstable. You might be able to comment this out at some point. <br>
Update 20th July 2026: I don't think this is wokring properly, and my latest suggested sif doesn't use it. I recommend NOT to use this feature.

There are a couple of minor checks on array bounds and nans that don’t get triggered, but who knows, maybe one day we’ll be glad of them…

I added an option for very thin shelves to the elmerice branch of the repo (in USF_Contact), but my latest runs don't need it, so feel free to use Thomas' latest elmer module on mahti, just with the BP solver itself locally compiled.


## LUA files

I copied these from Chen's directory on Mahti. They are probably the same as Chen's latest lua files on LUMI. I include them here just for completeness.


## Next steps

For ISMIP7 we aim to test the BP inversion provided elsewhere in this repository.

In the longer term the intention is to use cutfem for grounding line movement, and provide slip derivatives (merge with SSA code?) in order to use Newton iterations. 
Note: the current BP solver has it's own Weertman implementation including the derivative wrt sliding velocity, but it doesn't have ice shelf maskng, so the slipcoefficient would have to be continually remasked as the GL evolves... 

Currently the thickness coupling to velocity is explicit: geometry is updated outside the coupling loop. Semi implicit coupling will be tested (Clara Henry's ongoing work), but probably not for ISMIP7.
