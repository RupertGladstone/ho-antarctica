#!/bin/bash
#SBATCH --partition=medium
#SBATCH --time=01:00:00
#SBATCH --job-name=Ant_extrude
#SBATCH --output=extrude_output.txt
#SBATCH --error=extrude_errors.txt
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --mem=100G
#SBATCH --account=project_2000881

module load elmer/latest

cd /scratch/project_2000881/yuwang/HO_Antarctica/Mesh_refinement

echo Antarctica_extrude_test.sif > ELMERSOLVER_STARTINFO

srun ElmerSolver
