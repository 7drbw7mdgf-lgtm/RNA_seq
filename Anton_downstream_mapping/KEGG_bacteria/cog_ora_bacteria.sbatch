#!/bin/bash
#SBATCH --job-name=cog_ora_cje
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/KEGG_bacteria/logs/cog_ora_%j.log
#SBATCH --error=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/KEGG_bacteria/logs/cog_ora_%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=lshpk18@lshtm.ac.uk
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=01:00:00
#SBATCH --partition=normal

set -euo pipefail

SCRIPT_DIR="/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/KEGG_bacteria"
CONDA_ENV="dualrnaseq_pathway"

export EMAPPER_FILE="${EMAPPER_FILE:-${SCRIPT_DIR}/emapper_output/cje_emapper.emapper.annotations}"
export DESEQ2_RESULTS_DIR="${DESEQ2_RESULTS_DIR:-/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/DeSeq2_bacteria/results}"
export OUT_DIR="${OUT_DIR:-${SCRIPT_DIR}}"
export PADJ_CUTOFF="${PADJ_CUTOFF:-0.05}"

mkdir -p "${SCRIPT_DIR}/logs"

echo "=============================================="
echo "COG ORA — C. jejuni — eggNOG-mapper 2.1.12"
echo "=============================================="
echo "Job ID       : ${SLURM_JOB_ID:-manual}"
echo "Node         : $(hostname)"
echo "Start        : $(date)"
echo "Annotations  : ${EMAPPER_FILE}"
echo "DESeq2 dir   : ${DESEQ2_RESULTS_DIR}"
echo "Output dir   : ${OUT_DIR}"
echo "padj cutoff  : ${PADJ_CUTOFF}"
echo ""

[[ -f /home/lshpk18/miniconda3/bin/activate ]] || { echo "ERROR: conda not found" >&2; exit 1; }
source /home/lshpk18/miniconda3/bin/activate "${CONDA_ENV}"

[[ -f "${EMAPPER_FILE}" ]] || {
  echo "ERROR: eggNOG-mapper annotations not found: ${EMAPPER_FILE}" >&2
  echo "       Run run_emapper.sbatch first." >&2
  exit 1
}

[[ -d "${DESEQ2_RESULTS_DIR}" ]] || {
  echo "ERROR: DESeq2 results directory not found: ${DESEQ2_RESULTS_DIR}" >&2
  exit 1
}

echo "[INFO] Annotation file: $(wc -l < "${EMAPPER_FILE}") lines"
echo ""

Rscript "${SCRIPT_DIR}/cog_ora_bacteria.R"

echo ""
echo "=============================================="
echo "Complete : $(date)"
echo "Results  : ${OUT_DIR}/cog_results/"
echo "Figures  : ${OUT_DIR}/cog_figures/"
echo "=============================================="
