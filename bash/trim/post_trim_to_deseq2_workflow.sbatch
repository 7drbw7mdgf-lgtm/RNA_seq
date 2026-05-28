#!/bin/bash
#SBATCH --job-name=post_trim_de
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/logs/slurm/post_trim_de_%j.log
#SBATCH --error=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/logs/slurm/post_trim_de_%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=lshpk18@lshtm.ac.uk
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=72:00:00
#SBATCH --chdir=/home/lshpk18/OzanGundogdu_SOUK011275

# End-to-end wrapper from trimmed FASTQs to DESeq2.
# Existing checkpoints are skipped unless FORCE=true.

set -euo pipefail

WORKDIR="${WORKDIR:-/home/lshpk18/OzanGundogdu_SOUK011275}"
SCRIPT="${SCRIPT:-$WORKDIR/Analysis/post_trim_to_deseq2_workflow.sh}"
LOG_DIR="$WORKDIR/Analysis/logs/slurm"
THREADS="${THREADS:-${SLURM_CPUS_PER_TASK:-16}}"
ALLOW_INCOMPLETE="${ALLOW_INCOMPLETE:-false}"
DESIGN="${DESIGN:-condition}"
CONTRAST="${CONTRAST:-}"
ORGANISM="${ORGANISM:-all}"
INPUT_DIR="${INPUT_DIR:-$WORKDIR/Analysis/DifferentialExpression}"
DESEQ2_OUT_DIR="${DESEQ2_OUT_DIR:-$INPUT_DIR/deseq2_results}"
FORCE="${FORCE:-false}"
DRY_RUN="${DRY_RUN:-false}"
SKIP_DESEQ2="${SKIP_DESEQ2:-false}"

mkdir -p "$LOG_DIR"

echo "======================================"
echo "Post-Trim To DESeq2 SLURM Job"
echo "======================================"
echo "Job ID: ${SLURM_JOB_ID:-manual}"
echo "Node: $(hostname)"
echo "CPUs: ${SLURM_CPUS_PER_TASK:-$THREADS}"
echo "Memory: ${SLURM_MEM_M:-${SLURM_MEM_PER_NODE:-unknown}} MB"
echo "Start time: $(date)"
echo "Workdir: $WORKDIR"
echo "Input dir: $INPUT_DIR"
echo "DESeq2 out: $DESEQ2_OUT_DIR"
echo "Allow incomplete: $ALLOW_INCOMPLETE"
echo ""

ARGS=(--input-dir "$INPUT_DIR" --deseq2-out-dir "$DESEQ2_OUT_DIR" --design "$DESIGN" --organism "$ORGANISM")
if [[ -n "$CONTRAST" ]]; then ARGS+=(--contrast "$CONTRAST"); fi
if [[ "${ALLOW_INCOMPLETE,,}" == "true" ]]; then ARGS+=(--allow-incomplete); fi
if [[ "${FORCE,,}" == "true" ]]; then ARGS+=(--force); fi
if [[ "${DRY_RUN,,}" == "true" ]]; then ARGS+=(--dry-run); fi
if [[ "${SKIP_DESEQ2,,}" == "true" ]]; then ARGS+=(--skip-deseq2); fi

export THREADS
bash "$SCRIPT" "${ARGS[@]}"

echo ""
echo "======================================"
echo "Post-Trim To DESeq2 Completed"
echo "======================================"
echo "End time: $(date)"
