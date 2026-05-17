#!/bin/bash
#SBATCH --job-name=deseq2_bacteria
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/DeSeq2_bacteria/logs/deseq2_bacteria_%j.log
#SBATCH --error=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/DeSeq2_bacteria/logs/deseq2_bacteria_%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=lshpk18@lshtm.ac.uk
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=02:00:00
#SBATCH --chdir=/home/lshpk18/OzanGundogdu_SOUK011275

# DESeq2 differential expression on bacterial featureCounts output.
#
# Input:  FeatureCounts/FeatureCounts_bacteria/featureCounts_bacteria.txt
# Output: Anton_downstream_mapping/DeSeq2_bacteria/
#
# Usage:
#   sbatch /home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/DeSeq2_bacteria/deseq2_bacteria.sbatch
#
# Environment overrides:
#   COUNTS_FILE   Path to featureCounts output
#   OUT_DIR       Results output directory
#   PADJ_CUTOFF   Adjusted p-value threshold (default: 0.05)
#   LFC_CUTOFF    Absolute log2FC threshold (default: 1)
#   CONDA_ENV     Conda environment with DESeq2 (default: dualrnaseq_deseq2)

set -euo pipefail

WORKDIR="${WORKDIR:-/home/lshpk18/OzanGundogdu_SOUK011275}"
COUNTS_FILE="${COUNTS_FILE:-$WORKDIR/Analysis/Anton_downstream_mapping/FeatureCounts/FeatureCounts_bacteria/featureCounts_bacteria.txt}"
OUT_DIR="${OUT_DIR:-$WORKDIR/Analysis/Anton_downstream_mapping/DeSeq2_bacteria}"
PADJ_CUTOFF="${PADJ_CUTOFF:-0.05}"
LFC_CUTOFF="${LFC_CUTOFF:-1}"
CONDA_ENV="${CONDA_ENV:-dualrnaseq_deseq2}"
SCRIPT="$WORKDIR/Analysis/Anton_downstream_mapping/DeSeq2_bacteria/deseq2_bacteria.R"

mkdir -p "$OUT_DIR/logs"

echo "=============================================="
echo "DESeq2 Bacteria SLURM Job"
echo "=============================================="
echo "Job ID      : ${SLURM_JOB_ID:-manual}"
echo "Node        : $(hostname)"
echo "CPUs        : ${SLURM_CPUS_PER_TASK:-4}"
echo "Memory      : ${SLURM_MEM_M:-unknown} MB"
echo "Start time  : $(date)"
echo "Counts file : $COUNTS_FILE"
echo "Output dir  : $OUT_DIR"
echo "padj cutoff : $PADJ_CUTOFF"
echo "LFC cutoff  : $LFC_CUTOFF"
echo "Conda env   : $CONDA_ENV"
echo ""

[[ -f /home/lshpk18/miniconda3/bin/activate ]] || { echo "ERROR: conda not found" >&2; exit 1; }
source /home/lshpk18/miniconda3/bin/activate "$CONDA_ENV"

[[ -f "$COUNTS_FILE" ]] || { echo "ERROR: counts file not found: $COUNTS_FILE" >&2; exit 1; }
[[ -f "$SCRIPT" ]]      || { echo "ERROR: R script not found: $SCRIPT" >&2; exit 1; }

export COUNTS_FILE OUT_DIR PADJ_CUTOFF LFC_CUTOFF

Rscript "$SCRIPT"

echo ""
echo "=============================================="
echo "Job completed : $(date)"
echo "Results       : $OUT_DIR/results/"
echo "Figures       : $OUT_DIR/figures/"
echo "Objects       : $OUT_DIR/objects/"
echo "=============================================="
