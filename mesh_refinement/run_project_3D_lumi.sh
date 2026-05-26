#!/bin/bash -f
#SBATCH --partition=small
#SBATCH --time=01:00:00
#SBATCH --job-name=Ant_3D_proj
#SBATCH --output=%x.%j.out
#SBATCH --error=%x.%j.err
#SBATCH --nodes=4
#SBATCH --ntasks-per-node=128
#SBATCH --account=project_462001251

cd /scratch/project_462001251/YuWang/HO_Antarctica/Mesh_refinement_1km

module use /projappl/project_462001194/modules/
module load elmer/elmerice

echo "Antarctica_init_project_3D.sif" > ELMERSOLVER_STARTINFO

srun ElmerSolver
