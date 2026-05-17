#!/bin/bash
#SBATCH --job-name=kegg_bact
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/KEGG_bacteria/logs/kegg_%j.log
#SBATCH --error=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/KEGG_bacteria/logs/kegg_%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=lshpk18@lshtm.ac.uk
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=02:00:00
#SBATCH --partition=normal

set -euo pipefail

SCRIPT_DIR="/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/KEGG_bacteria"
CONDA_ENV="${CONDA_ENV:-dualrnaseq_pathway}"

export DESEQ2_RESULTS_DIR="${DESEQ2_RESULTS_DIR:-/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/DeSeq2_bacteria/results}"
export OUT_DIR="${SCRIPT_DIR}"
export PADJ_CUTOFF="${PADJ_CUTOFF:-0.05}"
export KEGG_ORGANISM="${KEGG_ORGANISM:-cje}"

mkdir -p "${OUT_DIR}/logs"

echo "=============================================="
echo "KEGG ORA + GSEA — C. jejuni — Bacteria"
echo "=============================================="
echo "Job ID      : ${SLURM_JOB_ID:-manual}"
echo "Node        : $(hostname)"
echo "Start       : $(date)"
echo "DESeq2 dir  : ${DESEQ2_RESULTS_DIR}"
echo "OUT dir     : ${OUT_DIR}"
echo "PADJ cutoff : ${PADJ_CUTOFF}"
echo "Organism    : ${KEGG_ORGANISM}"
echo ""

[[ -f /home/lshpk18/miniconda3/bin/activate ]] || { echo "ERROR: conda not found" >&2; exit 1; }
source /home/lshpk18/miniconda3/bin/activate "${CONDA_ENV}"

[[ -d "${DESEQ2_RESULTS_DIR}" ]] || { echo "ERROR: DESeq2 results dir not found: ${DESEQ2_RESULTS_DIR}" >&2; exit 1; }

Rscript "${SCRIPT_DIR}/kegg_bacteria.R"

echo ""
echo "=============================================="
echo "Complete : $(date)"
echo "Results  : ${OUT_DIR}/results/"
echo "Figures  : ${OUT_DIR}/figures/"
echo "=============================================="
