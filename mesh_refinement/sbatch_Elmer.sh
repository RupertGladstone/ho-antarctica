#!/bin/bash

#SBATCH --partition=medium
#SBATCH --time=12:00:00
#SBATCH --job-name=Ant_mesh_refine
#SBATCH --output=output.txt
#SBATCH --error=errors.txt
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --account=project_2000881

module load elmer/latest

srun ElmerSolver
