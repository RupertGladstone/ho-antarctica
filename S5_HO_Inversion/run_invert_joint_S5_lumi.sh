#!/bin/bash -f
#SBATCH --partition=standard
#SBATCH --time=24:00:00
#SBATCH --job-name=Ant_invertBM
#SBATCH --output=%x.%j.out
#SBATCH --error=%x.%j.err
#SBATCH --nodes=8
#SBATCH --ntasks-per-node=128
#SBATCH --exclusive
#SBATCH --account=project_462001251

# Joint HO inversion: simultaneous beta + Mu via m1qn3 on packed
# Var[alpha:1 etaMu:1]. Bulk Mu gradient roughly doubles wall time
# vs. beta-only -> 24h budget for the first L-curve point.

cd /scratch/project_462001251/YuWang/HO_Antarctica/S5_HO_Inversion

module purge
module use /projappl/project_462001194/modules/
module load elmer/elmerice

ulimit -s unlimited

# Custom AdjointBP solvers live in src/ — both Beta and Mu .so files
export LD_LIBRARY_PATH=/scratch/project_462001251/YuWang/HO_Antarctica/S5_HO_Inversion/src:$LD_LIBRARY_PATH

echo "Antarctica_invert_joint_S5.sif" > ELMERSOLVER_STARTINFO

srun ElmerSolver
