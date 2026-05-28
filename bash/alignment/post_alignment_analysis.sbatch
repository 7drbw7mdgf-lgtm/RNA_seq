#!/bin/bash
#SBATCH --job-name=post_align
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/logs/slurm/post_alignment_%j.log
#SBATCH --error=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/logs/slurm/post_alignment_%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=lshpk18@lshtm.ac.uk
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=40G
#SBATCH --time=24:00:00
#SBATCH --chdir=/home/lshpk18/OzanGundogdu_SOUK011275

# Resumable post-alignment analysis Slurm wrapper.
#
# Usage:
#   sbatch Analysis/Alignment/post_alignment_analysis.sbatch
#   sbatch --export=REQUIRE_COMPLETE=true Analysis/Alignment/post_alignment_analysis.sbatch
#   sbatch --export=SKIP_COUNTS=true Analysis/Alignment/post_alignment_analysis.sbatch
#   sbatch --export=SKIP_QC=true Analysis/Alignment/post_alignment_analysis.sbatch
#   sbatch --export=FORCE=true Analysis/Alignment/post_alignment_analysis.sbatch
#   sbatch --export=DRY_RUN=true Analysis/Alignment/post_alignment_analysis.sbatch
#   sbatch --export=SKIP_COUNTS=true,INSTALL_QC_TOOLS=true Analysis/Alignment/post_alignment_analysis.sbatch
#
# Environment overrides:
#   WORKDIR, ALIGNMENT_DIR, OUT_DIR, THREADS, CONDA_ENV, ALLOW_INCOMPLETE,
#   REQUIRE_COMPLETE, SKIP_COUNTS, SKIP_QC, FORCE, DRY_RUN, SKIP_CONDA,
#   INSTALL_QC_TOOLS

set -euo pipefail

WORKDIR="${WORKDIR:-/home/lshpk18/OzanGundogdu_SOUK011275}"
ALIGNMENT_DIR="${ALIGNMENT_DIR:-$WORKDIR/Analysis/Alignment}"
SCRIPT="${SCRIPT:-$ALIGNMENT_DIR/post_alignment_analysis.sh}"
LOG_DIR="${ALIGNMENT_DIR}/logs"
THREADS="${THREADS:-${SLURM_CPUS_PER_TASK:-16}}"
CONDA_ENV="${CONDA_ENV:-dualrnaseq}"

ALLOW_INCOMPLETE="${ALLOW_INCOMPLETE:-true}"
REQUIRE_COMPLETE="${REQUIRE_COMPLETE:-false}"
SKIP_COUNTS="${SKIP_COUNTS:-false}"
SKIP_QC="${SKIP_QC:-false}"
FORCE="${FORCE:-false}"
DRY_RUN="${DRY_RUN:-false}"
SKIP_CONDA="${SKIP_CONDA:-false}"
INSTALL_QC_TOOLS="${INSTALL_QC_TOOLS:-false}"

mkdir -p "$LOG_DIR/slurm"

echo "======================================"
echo "Post-Alignment Analysis SLURM Job"
echo "======================================"
echo "Job ID: ${SLURM_JOB_ID:-manual}"
echo "Node: $(hostname)"
echo "CPUs: ${SLURM_CPUS_PER_TASK:-$THREADS}"
echo "Memory: ${SLURM_MEM_M:-${SLURM_MEM_PER_NODE:-unknown}} MB"
echo "Start time: $(date)"
echo "Workdir: $WORKDIR"
echo "Script: $SCRIPT"
echo "Threads: $THREADS"
echo "Conda env: ${CONDA_ENV:-none}"
echo "Allow incomplete: $ALLOW_INCOMPLETE"
echo "Require complete: $REQUIRE_COMPLETE"
echo "Skip counts: $SKIP_COUNTS"
echo "Skip QC: $SKIP_QC"
echo "Force: $FORCE"
echo "Dry run: $DRY_RUN"
echo "Install QC tools: $INSTALL_QC_TOOLS"
echo ""

if [[ ! -f "$SCRIPT" ]]; then
  echo "ERROR: post-alignment script not found: $SCRIPT" >&2
  exit 1
fi

SCRIPT_ARGS=(--threads "$THREADS")

if [[ "${REQUIRE_COMPLETE,,}" == "true" ]]; then
  SCRIPT_ARGS+=(--require-complete)
elif [[ "${ALLOW_INCOMPLETE,,}" == "true" ]]; then
  SCRIPT_ARGS+=(--allow-incomplete)
fi

if [[ "${SKIP_COUNTS,,}" == "true" ]]; then
  SCRIPT_ARGS+=(--skip-counts)
fi

if [[ "${SKIP_QC,,}" == "true" ]]; then
  SCRIPT_ARGS+=(--skip-qc)
fi

if [[ "${FORCE,,}" == "true" ]]; then
  SCRIPT_ARGS+=(--force)
fi

if [[ "${DRY_RUN,,}" == "true" ]]; then
  SCRIPT_ARGS+=(--dry-run)
fi

if [[ "${INSTALL_QC_TOOLS,,}" == "true" ]]; then
  SCRIPT_ARGS+=(--install-qc-tools)
fi

if [[ "${SKIP_CONDA,,}" == "true" ]]; then
  SCRIPT_ARGS+=(--skip-conda)
fi

export THREADS CONDA_ENV

echo "Running:"
printf '  bash %q' "$SCRIPT"
printf ' %q' "${SCRIPT_ARGS[@]}"
printf '\n\n'

bash "$SCRIPT" "${SCRIPT_ARGS[@]}"

echo ""
echo "======================================"
echo "Post-Alignment Analysis Completed"
echo "======================================"
echo "End time: $(date)"
echo "Summary: ${ALIGNMENT_DIR}/post_alignment_analysis/post_alignment_summary.txt"
echo "Resume state: ${ALIGNMENT_DIR}/post_alignment_analysis/resume_state.tsv"
