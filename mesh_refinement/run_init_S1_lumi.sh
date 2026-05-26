#!/bin/bash -f
#SBATCH --partition=small
#SBATCH --time=00:45:00
#SBATCH --job-name=Ant_init_S1
#SBATCH --output=%x.%j.out
#SBATCH --error=%x.%j.err
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=128
#SBATCH --account=project_462001251

cd /scratch/project_462001251/YuWang/HO_Antarctica/Mesh_refinement_1km

module use /projappl/project_462001194/modules/
module load elmer/elmerice

echo "Antarctica_init_S1.sif" > ELMERSOLVER_STARTINFO

srun ElmerSolver
