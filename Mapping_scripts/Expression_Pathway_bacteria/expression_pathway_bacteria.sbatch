#!/bin/bash
#SBATCH --job-name=expr_pathway_bact
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Expression_Pathway_bacteria/logs/expr_pathway_%j.log
#SBATCH --error=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Expression_Pathway_bacteria/logs/expr_pathway_%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=lshpk18@lshtm.ac.uk
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=01:00:00
#SBATCH --partition=normal

set -euo pipefail

SCRIPT_DIR="/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Expression_Pathway_bacteria"
CONDA_ENV="${CONDA_ENV:-dualrnaseq_pathway}"

export DESEQ2_RESULTS_DIR="${DESEQ2_RESULTS_DIR:-/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/DeSeq2_bacteria/results}"
export ORA_DIR="${ORA_DIR:-/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Ensembl_ORA_bacteria}"
export OUT_DIR="${SCRIPT_DIR}"
export PADJ_LRT="${PADJ_LRT:-0.05}"
export PADJ_ORA="${PADJ_ORA:-0.05}"
export K_MIN="${K_MIN:-2}"
export K_MAX="${K_MAX:-12}"

mkdir -p "${OUT_DIR}/logs"

echo "=============================================="
echo "Expression Clustering + Pathway Enrichment"
echo "C. jejuni — Bacteria time-course"
echo "=============================================="
echo "Job ID      : ${SLURM_JOB_ID:-manual}"
echo "Node        : $(hostname)"
echo "Start       : $(date)"
echo "DESeq2 dir  : ${DESEQ2_RESULTS_DIR}"
echo "ORA dir     : ${ORA_DIR}"
echo "OUT dir     : ${OUT_DIR}"
echo "PADJ LRT    : ${PADJ_LRT}"
echo "k range     : ${K_MIN} – ${K_MAX}"
echo ""

[[ -f /home/lshpk18/miniconda3/bin/activate ]] || { echo "ERROR: conda not found" >&2; exit 1; }
source /home/lshpk18/miniconda3/bin/activate "${CONDA_ENV}"

[[ -d "${DESEQ2_RESULTS_DIR}" ]] || { echo "ERROR: DESeq2 results dir not found" >&2; exit 1; }
[[ -d "${ORA_DIR}" ]]            || { echo "ERROR: ORA dir not found" >&2; exit 1; }

Rscript "${SCRIPT_DIR}/expression_pathway_bacteria.R"

echo ""
echo "=============================================="
echo "Complete : $(date)"
echo "Results  : ${OUT_DIR}/results/"
echo "Figures  : ${OUT_DIR}/figures/"
echo "=============================================="
