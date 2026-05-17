#!/bin/bash
#SBATCH --job-name=sense_check_host
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Sense_check_host/logs/sense_check_%j.log
#SBATCH --error=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Sense_check_host/logs/sense_check_%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=lshpk18@lshtm.ac.uk
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=01:00:00
#SBATCH --partition=normal

set -euo pipefail

SCRIPT_DIR="/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Sense_check_host"
CONDA_ENV="${CONDA_ENV:-dualrnaseq_pathway}"

export COUNTS_FILE="${COUNTS_FILE:-/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/FeatureCounts/FeatureCounts_host/featureCounts_host.txt}"
export OUT_DIR="${SCRIPT_DIR}"
export TIMEPOINT="${TIMEPOINT:-0h}"
export PADJ_CUTOFF="${PADJ_CUTOFF:-0.05}"
export LFC_CUTOFF="${LFC_CUTOFF:-1}"
export MIN_TOTAL_COUNT="${MIN_TOTAL_COUNT:-10}"

mkdir -p "${OUT_DIR}/logs"

echo "=============================================="
echo "Host DESeq2 Sense Check — Run1 vs Run2"
echo "=============================================="
echo "Job ID     : ${SLURM_JOB_ID:-manual}"
echo "Node       : $(hostname)"
echo "Start      : $(date)"
echo "Counts     : ${COUNTS_FILE}"
echo "Timepoint  : ${TIMEPOINT}"
echo "padj cut   : ${PADJ_CUTOFF}"
echo "LFC cut    : ${LFC_CUTOFF}"
echo ""

[[ -f /home/lshpk18/miniconda3/bin/activate ]] || { echo "ERROR: conda not found" >&2; exit 1; }
source /home/lshpk18/miniconda3/bin/activate "${CONDA_ENV}"

[[ -f "${COUNTS_FILE}" ]] || { echo "ERROR: counts file not found: ${COUNTS_FILE}" >&2; exit 1; }

Rscript "${SCRIPT_DIR}/deseq2_sense_check_host.R"

echo ""
echo "=============================================="
echo "Complete : $(date)"
echo "Figures  : ${OUT_DIR}/figures/"
echo "Results  : ${OUT_DIR}/results/"
echo "=============================================="
