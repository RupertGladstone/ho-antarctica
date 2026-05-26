#!/bin/bash -f
#SBATCH --partition=standard
#SBATCH --time=12:00:00
#SBATCH --job-name=Ant_invertB
#SBATCH --output=%x.%j.out
#SBATCH --error=%x.%j.err
#SBATCH --nodes=8
#SBATCH --ntasks-per-node=128
#SBATCH --exclusive
#SBATCH --account=project_462001251

cd /scratch/project_462001251/YuWang/HO_Antarctica/S5_HO_Inversion

module purge
module use /projappl/project_462001194/modules/
module load elmer/elmerice

ulimit -s unlimited

# Custom AdjointBP solver lives in src/ — add to lib search path
export LD_LIBRARY_PATH=/scratch/project_462001251/YuWang/HO_Antarctica/S5_HO_Inversion/src:$LD_LIBRARY_PATH

# ---- LUMI Slingshot/OFI workarounds at 1024 ranks ------------------------
# Jobs 18798123, 18801053, 18804486, 18804892 all crashed with
#   MPIDI_OFI_send_normal: OFI tagged senddata failed (Input/output error)
# during HydrostaticNSSolver matrix-assembly Bsend. The default rendezvous
# protocol cannot reliably handle sustained 1024-rank message volume on
# Cray Slingshot CXI. Switch to alternate RDMA-read rendezvous, pre-connect
# ranks at startup, and raise the OFI Tx queue size.
#
# Do NOT set FI_CXI_RX_MATCH_MODE=hybrid (Job 18793223 hung 19 min) — match
# mode and rendezvous protocol are independent dials.
export FI_CXI_RDZV_PROTO=alt_read
export MPICH_OFI_STARTUP_CONNECT=1
export FI_CXI_DEFAULT_TX_SIZE=8192

echo "Antarctica_invert_beta_S5.sif" > ELMERSOLVER_STARTINFO

srun ElmerSolver
