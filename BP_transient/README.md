
# BP handover 

This subdirectory contains files and notes 

## Solver input files

The BP_SpinUp input file is just spinning up the BP flow solution from zero using the optimised parameters read in from a result file (currently from SSA inversions).

The BP_Trans input file restarts from the spun up solution and evolves through time, so the geometry and groundedmask evolution is turned on. This is your starting point for ISMIP7 simulations. I have put some notes in for things you need to add (search “TODO” in the .sif).

#### Outputting:

I put in two output solvers. One for the bulk and one for the boundary. I do this because I like to download outputs to look at on my laptop and the full files are very large. So I use the icemap/utils to merge the boundary files into one vtu file per timestep and to extract a subregion of interest (and then merge) for the bulk. So I download two much smaller files that contain enough info for me to check the state looks sane.

You will need to change this for ISMIP7. You need to add XIOS and output unstructured netcdf for further processing. You may wish to turn off my vtu outputs entirely, or to reduce the frequency greatly.


#### A note on BP solvers settings.

I’ve provisionally set the linear and nonlinear tolerances to an order of magnitude larger for the transient run compared to the spin up, just to make it go a bit faster. I didn’t quite get convergence with the tighter settings, hence there is a nonlinear relaxation factor used in the spin up but not in the transient sif. Feel free to experiment!

I found the GCR and ILUT settings pretty optimal for the spin up (I tried various settings) but they might not be optimal for the transient run, I’ve not experimented with different settings post spin up. I guess the block preconditioner might give faster convergence if it converges, and convergence was probably most problematic spinning up from rest.

## Updated code

The version of the BP solver here has a few small (but two of them are important) changes compared to the repository version:

The flow solution is now updated every nonlinear iteration instead of after nonlinear convergence. This is because the sliding code quietly looks for “flow solution” by default (it would need a small code change to let it use a 2 dofs variable other than the SSA velocity), so updating the flow solution only after nonlinear convergence removes the nonlinear sliding – flow speed feedback from the friction parameterisation.

Thomas implemented an optional velocity limit, which was applied to flow solution. I have switched this from the flow solution to the vertically averaged velocity, since this is the property used by the thickness solver to evolve the ice thickness. Now that we have more stable behaviour the limit is probably not needed anyway.

There are a couple of minor checks on array bounds and nans that don’t get triggered, but who knows, maybe one day we’ll be glad of them…

## Next steps

For ISMIP7 we aim to test the inversion provided elsewhere in this repository.

In the longer term the intention is to use cutfem for grounding line movement, and provide slip derivatives (merge with SSA code?) in order to use Newton iterations. 
Note: the current BP solver has it's own Weertman implementation including the derivative wrt sliding velocity, but it doesn't have ice shelf maskng, so the slipcoefficient would have to be continually remasked as the GL evolves... 

Currently the thickness coupling to velocity is explicit: geometry is updated outside the coupling loop. Semi implicit coupling will be tested (Clara Henry's ongoing work), but probably not for ISMIP7.
