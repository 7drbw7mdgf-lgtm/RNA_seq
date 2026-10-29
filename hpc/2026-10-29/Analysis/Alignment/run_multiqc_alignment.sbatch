#!/bin/bash
#SBATCH --job-name=align_multiqc
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/logs/slurm/alignment_multiqc_%j.log
#SBATCH --error=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/logs/slurm/alignment_multiqc_%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=lshpk18@lshtm.ac.uk
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --chdir=/home/lshpk18/OzanGundogdu_SOUK011275

set -euo pipefail

WORKDIR="${WORKDIR:-/home/lshpk18/OzanGundogdu_SOUK011275}"
SCRIPT="${SCRIPT:-$WORKDIR/Analysis/Alignment/run_multiqc_alignment.sh}"
OUT_DIR="${OUT_DIR:-$WORKDIR/Analysis/Alignment/multiqc}"
REPORT_NAME="${REPORT_NAME:-alignment_multiqc_report.html}"
CONDA_ENV="${CONDA_ENV:-dualrnaseq}"
FORCE="${FORCE:-false}"
DRY_RUN="${DRY_RUN:-false}"

echo "======================================"
echo "Alignment MultiQC SLURM Job"
echo "======================================"
echo "Job ID: ${SLURM_JOB_ID:-manual}"
echo "Node: $(hostname)"
echo "Start time: $(date)"
echo "Output: $OUT_DIR/$REPORT_NAME"
echo ""

if [[ -n "$CONDA_ENV" && -f /home/lshpk18/miniconda3/bin/activate ]]; then
  echo "Activating conda environment: $CONDA_ENV"
  source /home/lshpk18/miniconda3/bin/activate "$CONDA_ENV"
fi

ARGS=(--out-dir "$OUT_DIR" --report-name "$REPORT_NAME")
if [[ "${FORCE,,}" == "true" ]]; then ARGS+=(--force); fi
if [[ "${DRY_RUN,,}" == "true" ]]; then ARGS+=(--dry-run); fi

bash "$SCRIPT" "${ARGS[@]}"

echo ""
echo "======================================"
echo "Alignment MultiQC Completed"
echo "======================================"
echo "End time: $(date)"
