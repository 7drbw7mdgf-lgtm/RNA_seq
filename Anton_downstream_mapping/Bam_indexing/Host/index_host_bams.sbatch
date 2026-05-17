#!/bin/bash
#SBATCH --job-name=merge_lanes_host
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Bam_indexing/Host/logs/merge_lanes_host_%j.log
#SBATCH --error=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Bam_indexing/Host/logs/merge_lanes_host_%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=lshpk18@lshtm.ac.uk
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=60G
#SBATCH --time=08:00:00
#SBATCH --chdir=/home/lshpk18/OzanGundogdu_SOUK011275

# Merges Lane 1 and Lane 7 BAMs for each host sample+run, then indexes.
# Output: 96 merged BAMs (48 samples x 2 runs) in Bam_indexing/Host/merged/
#
# Usage:
#   sbatch index_host_bams.sbatch
#
# Environment overrides:
#   BAM_DIR    Input directory (default: Analysis/Alignment/bam/host)
#   OUT_DIR    Output directory for merged BAMs
#   THREADS    samtools threads per job (default: 2)
#   PARALLEL   Concurrent merge jobs (default: 8)
#   FORCE      Set "true" to redo already-completed samples
#   CONDA_ENV  Conda environment with samtools (default: dualrnaseq)

set -euo pipefail

WORKDIR="${WORKDIR:-/home/lshpk18/OzanGundogdu_SOUK011275}"
BAM_DIR="${BAM_DIR:-$WORKDIR/Analysis/Alignment/bam/host}"
OUT_DIR="${OUT_DIR:-$WORKDIR/Analysis/Anton_downstream_mapping/Bam_indexing/Host/merged}"
THREADS="${THREADS:-2}"
PARALLEL="${PARALLEL:-8}"
FORCE="${FORCE:-false}"
CONDA_ENV="${CONDA_ENV:-dualrnaseq}"
SCRIPT_DIR="$WORKDIR/Analysis/Anton_downstream_mapping/Bam_indexing/Host"

mkdir -p "$SCRIPT_DIR/logs" "$OUT_DIR"

echo "=============================================="
echo "Host BAM Lane Merge + Index SLURM Job"
echo "=============================================="
echo "Job ID      : ${SLURM_JOB_ID:-manual}"
echo "Node        : $(hostname)"
echo "CPUs        : ${SLURM_CPUS_PER_TASK:-16}"
echo "Memory      : ${SLURM_MEM_M:-unknown} MB"
echo "Start time  : $(date)"
echo "BAM dir     : $BAM_DIR"
echo "Output dir  : $OUT_DIR"
echo "Threads/job : $THREADS"
echo "Parallel    : $PARALLEL"
echo "Force       : $FORCE"
echo "Conda env   : $CONDA_ENV"
echo ""

[[ -f /home/lshpk18/miniconda3/bin/activate ]] || { echo "ERROR: conda not found" >&2; exit 1; }
source /home/lshpk18/miniconda3/bin/activate "$CONDA_ENV"

bash "$SCRIPT_DIR/index_host_bams.sh" \
  --bam-dir  "$BAM_DIR"  \
  --out-dir  "$OUT_DIR"  \
  --threads  "$THREADS"  \
  --parallel "$PARALLEL" \
  ${FORCE:+--force}

echo ""
echo "=============================================="
echo "Job completed : $(date)"
echo "Output        : $OUT_DIR"
echo "=============================================="
