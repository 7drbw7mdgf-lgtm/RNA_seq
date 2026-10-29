#!/bin/bash
#SBATCH --job-name=tin_score
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/logs/slurm/tin_score_%A_%a.log
#SBATCH --error=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/logs/slurm/tin_score_%A_%a.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=lshpk18@lshtm.ac.uk
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --chdir=/home/lshpk18/OzanGundogdu_SOUK011275
#
# RSeQC TIN (Transcript Integrity Number) array job.
# One array task = one BAM file, per the manifest for TARGET.
#
# Usage:
#   sbatch --array=1-96%48 --export=TARGET=host   Analysis/Alignment/Slurm_scripts/tin_score.sbatch
#   sbatch --array=1-96%48 --export=TARGET=bacteria Analysis/Alignment/Slurm_scripts/tin_score.sbatch
#
# Environment overrides:
#   WORKDIR, ALIGNMENT_DIR, OUT_DIR, TARGET, CONDA_ENV

set -euo pipefail

WORKDIR="${WORKDIR:-/home/lshpk18/OzanGundogdu_SOUK011275}"
ALIGNMENT_DIR="${ALIGNMENT_DIR:-$WORKDIR/Analysis/Alignment}"
OUT_DIR="${OUT_DIR:-$ALIGNMENT_DIR/alignment_QC}"
TARGET="${TARGET:-}"
CONDA_ENV="${CONDA_ENV:-dualrnaseq}"
MANIFEST="$ALIGNMENT_DIR/manifests/tin_${TARGET}_bams.txt"
GENE_BED="$OUT_DIR/references/${TARGET}.annotation.bed"
RUN_SCRIPT="$ALIGNMENT_DIR/Bash_scripts/run_tin_score.sh"

case "$TARGET" in
  host|bacteria) ;;
  *) echo "ERROR: --export=TARGET=host|bacteria is required" >&2; exit 1 ;;
esac

[[ -f "$MANIFEST" ]] || { echo "ERROR: manifest not found: $MANIFEST" >&2; exit 1; }
[[ -f "$GENE_BED" ]] || { echo "ERROR: gene BED not found: $GENE_BED" >&2; exit 1; }
[[ -n "${SLURM_ARRAY_TASK_ID:-}" ]] || { echo "ERROR: must be submitted as an array job (--array=1-N)" >&2; exit 1; }

BAM="$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$MANIFEST")"
[[ -n "$BAM" ]] || { echo "ERROR: no manifest line for array index $SLURM_ARRAY_TASK_ID" >&2; exit 1; }

echo "=============================================="
echo "TIN score — array task $SLURM_ARRAY_TASK_ID (job ${SLURM_ARRAY_JOB_ID:-manual})"
echo "Target: $TARGET"
echo "BAM: $BAM"
echo "Node: $(hostname)"
echo "=============================================="

source /home/lshpk18/miniconda3/bin/activate "$CONDA_ENV"

bash "$RUN_SCRIPT" "$BAM" "$TARGET" "$GENE_BED" "$OUT_DIR"
