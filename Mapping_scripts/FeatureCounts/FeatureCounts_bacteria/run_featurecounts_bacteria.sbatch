#!/bin/bash
#SBATCH --job-name=featurecounts_bacteria
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/FeatureCounts/logs/featurecounts_bacteria_%j.log
#SBATCH --error=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/FeatureCounts/logs/featurecounts_bacteria_%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=lshpk18@lshtm.ac.uk
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --time=04:00:00
#SBATCH --chdir=/home/lshpk18/OzanGundogdu_SOUK011275

# featureCounts on merged bacterial BAMs (lane-merged, one BAM per sample+run).
# Depends on the BAM merge job (5926159) completing successfully.
#
# Usage:
#   sbatch /home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/FeatureCounts/run_featurecounts_bacteria.sbatch
#
# Environment overrides:
#   BAM_DIR     Merged BAM directory
#   OUT_DIR     Output directory (default: Anton_downstream_mapping/FeatureCounts)
#   ANNOTATION  GFF3 annotation file
#   THREADS     featureCounts threads (default: cpus-per-task)
#   FORCE       Set "true" to rerun if output already exists
#   CONDA_ENV   Conda environment with featureCounts (default: dualrnaseq)

set -euo pipefail

WORKDIR="${WORKDIR:-/home/lshpk18/OzanGundogdu_SOUK011275}"
BAM_DIR="${BAM_DIR:-$WORKDIR/Analysis/Anton_downstream_mapping/Bam_indexing/Bacteria/merged}"
OUT_DIR="${OUT_DIR:-$WORKDIR/Analysis/Anton_downstream_mapping/FeatureCounts}"
ANNOTATION="${ANNOTATION:-$WORKDIR/Analysis/Alignment/references/AL111168.1.gff3}"
THREADS="${THREADS:-${SLURM_CPUS_PER_TASK:-16}}"
FORCE="${FORCE:-false}"
CONDA_ENV="${CONDA_ENV:-dualrnaseq}"
SCRIPT_DIR="$WORKDIR/Analysis/Anton_downstream_mapping/FeatureCounts"

mkdir -p "$OUT_DIR/logs"

echo "=============================================="
echo "featureCounts Bacteria SLURM Job"
echo "=============================================="
echo "Job ID      : ${SLURM_JOB_ID:-manual}"
echo "Node        : $(hostname)"
echo "CPUs        : ${SLURM_CPUS_PER_TASK:-$THREADS}"
echo "Memory      : ${SLURM_MEM_M:-unknown} MB"
echo "Start time  : $(date)"
echo "BAM dir     : $BAM_DIR"
echo "Annotation  : $ANNOTATION"
echo "Output dir  : $OUT_DIR"
echo "Conda env   : $CONDA_ENV"
echo ""

[[ -f /home/lshpk18/miniconda3/bin/activate ]] || { echo "ERROR: conda not found" >&2; exit 1; }
source /home/lshpk18/miniconda3/bin/activate "$CONDA_ENV"

bash "$SCRIPT_DIR/run_featurecounts_bacteria.sh" \
  --bam-dir    "$BAM_DIR"    \
  --out-dir    "$OUT_DIR"    \
  --annotation "$ANNOTATION" \
  --threads    "$THREADS"    \
  ${FORCE:+--force}

echo ""
echo "=============================================="
echo "Job completed : $(date)"
echo "Results       : $OUT_DIR/featureCounts_bacteria.txt"
echo "=============================================="
