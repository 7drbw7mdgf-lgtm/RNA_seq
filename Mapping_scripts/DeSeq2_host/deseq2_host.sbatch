#!/bin/bash
#SBATCH --job-name=deseq2_host
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/DeSeq2_host/logs/deseq2_host_%j.log
#SBATCH --error=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/DeSeq2_host/logs/deseq2_host_%j.err
#SBATCH --time=04:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=4
#SBATCH --ntasks=1

set -euo pipefail

SCRIPT_DIR="/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/DeSeq2_host"
CONDA_ENV="${CONDA_ENV:-dualrnaseq_deseq2}"

export COUNTS_FILE="/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/FeatureCounts/FeatureCounts_host/featureCounts_host.txt"
export OUT_DIR="${SCRIPT_DIR}"
export PADJ_CUTOFF="0.05"
export LFC_CUTOFF="1"
export MIN_TOTAL_COUNT="10"

mkdir -p "${OUT_DIR}/logs"

echo "[$(date '+%F %T')] Starting host DESeq2 analysis (design: ~ run + timepoint)"
echo "[$(date '+%F %T')] COUNTS_FILE : ${COUNTS_FILE}"
echo "[$(date '+%F %T')] OUT_DIR     : ${OUT_DIR}"
echo "[$(date '+%F %T')] Conda env   : ${CONDA_ENV}"

[[ -f /home/lshpk18/miniconda3/bin/activate ]] || { echo "ERROR: conda not found" >&2; exit 1; }
source /home/lshpk18/miniconda3/bin/activate "${CONDA_ENV}"

[[ -f "${COUNTS_FILE}" ]] || { echo "ERROR: counts file not found: ${COUNTS_FILE}" >&2; exit 1; }

Rscript "${SCRIPT_DIR}/deseq2_host.R"

echo "[$(date '+%F %T')] Host DESeq2 analysis complete"
