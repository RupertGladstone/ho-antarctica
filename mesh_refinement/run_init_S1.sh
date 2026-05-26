#!/bin/bash
#SBATCH --partition=medium
#SBATCH --time=02:00:00
#SBATCH --job-name=Ant_init_S1
#SBATCH --output=init_output.txt
#SBATCH --error=init_errors.txt
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --mem=100G
#SBATCH --account=project_2000881

module load elmer/latest

cd /scratch/project_2000881/yuwang/HO_Antarctica/Mesh_refinement

echo Antarctica_init_S1.sif > ELMERSOLVER_STARTINFO

srun ElmerSolver
