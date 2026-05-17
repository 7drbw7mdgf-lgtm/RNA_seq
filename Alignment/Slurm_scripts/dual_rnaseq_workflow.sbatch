#!/bin/bash
#SBATCH --job-name=dual_rnaseq
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/logs/slurm/dual_rnaseq_%j.log
#SBATCH --error=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/logs/slurm/dual_rnaseq_%j.err

#SBATCH --mail-type=BEGIN,END,FAIL          # Mail events (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-user=lshpk18@lshtm.ac.uk # Where to send mail
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=40gb                     # Job memory request
#SBATCH --time=70:05:00               # Time limit hrs:min:sec
#SBATCH --chdir=/home/lshpk18/OzanGundogdu_SOUK011275

# Dual RNA-Seq Workflow SLURM Job Script
# Runs the dual_rnaseq_workflow.sh for host and bacterial genome alignment
# 
# Usage:
#   sbatch dual_rnaseq_workflow.sbatch                    # Run full workflow (all steps)
#   sbatch --export=STEP=index dual_rnaseq_workflow.sbatch
#   sbatch --export=STEP=align dual_rnaseq_workflow.sbatch
#   sbatch --export=STEP=align,SAMPLE_SHEET=/path/to/samples.tsv dual_rnaseq_workflow.sbatch
#   sbatch --export=STEP=counts dual_rnaseq_workflow.sbatch

set -euo pipefail

# Configuration
WORKDIR="${WORKDIR:-/home/lshpk18/OzanGundogdu_SOUK011275}"
SCRIPT="${WORKDIR}/Analysis/Alignment/dual_rnaseq_workflow.sh"
STEP="${STEP:-all}"  # Default to running all steps
SAMPLE="${SAMPLE:-}"  # Optional: specific sample to align
SAMPLE_LIST="${SAMPLE_LIST:-${WORKDIR}/Analysis/Alignment/sample_names.txt}"
SAMPLE_SHEET="${SAMPLE_SHEET:-}"
FORCE="${FORCE:-false}"
DRY_RUN="${DRY_RUN:-false}"
CONDA_ENV="${CONDA_ENV:-dualrnaseq}"

# Logging
LOG_DIR="${WORKDIR}/Analysis/Alignment/logs"
mkdir -p "$LOG_DIR/slurm"

echo "======================================"
echo "Dual RNA-Seq Workflow SLURM Job"
echo "======================================"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $(hostname)"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: ${SLURM_MEM_M:-${SLURM_MEM_PER_NODE:-unknown}} MB"
echo "Start time: $(date)"
echo "Step: $STEP"
echo "Workdir: $WORKDIR"
if [[ -n "$SAMPLE" ]]; then
  echo "Sample: $SAMPLE"
fi
if [[ -n "$SAMPLE_SHEET" ]]; then
  echo "Sample sheet: $SAMPLE_SHEET"
fi
echo ""

# Activate the conda environment used by the workflow.
if [[ -n "$CONDA_ENV" ]]; then
  echo "Activating conda environment: $CONDA_ENV"
  if [[ ! -f /home/lshpk18/miniconda3/bin/activate ]]; then
    echo "ERROR: conda activate script not found: /home/lshpk18/miniconda3/bin/activate" >&2
    exit 1
  fi
  source /home/lshpk18/miniconda3/bin/activate "$CONDA_ENV"
fi

# Load required modules only when a conda environment was not requested.
if [[ -z "$CONDA_ENV" ]]; then
  echo "Loading modules..."
fi
if [[ -z "$CONDA_ENV" ]] && command -v module >/dev/null 2>&1; then
  # Try loading common module names - adjust for your cluster
  if module avail STAR/2.7.* >/dev/null 2>&1; then
    module load STAR
  elif module avail star >/dev/null 2>&1; then
    module load star
  fi
  
  if module avail samtools >/dev/null 2>&1; then
    module load samtools
  fi
  
  if module avail subread >/dev/null 2>&1; then
    module load subread
  fi
else
  if [[ -z "$CONDA_ENV" ]]; then
    echo "Module system not available - assuming tools are in PATH"
  fi
fi

# Verify required tools are available
echo "Checking for required tools..."
for tool in STAR samtools; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "WARNING: $tool not found in PATH"
  else
    echo "  ✓ $tool found"
  fi
done

echo ""
echo "======================================"
echo "Running workflow step: $STEP"
echo "======================================"
echo ""

# Run the workflow script
SCRIPT_ARGS=(--step "$STEP")
if [[ "${FORCE,,}" == "true" ]]; then
  SCRIPT_ARGS+=(--force)
fi
if [[ "${DRY_RUN,,}" == "true" ]]; then
  SCRIPT_ARGS+=(--dry-run)
fi
if [[ -n "$SAMPLE_SHEET" ]]; then
  SCRIPT_ARGS+=(--sample-sheet "$SAMPLE_SHEET")
fi

if [[ -n "${SLURM_ARRAY_TASK_ID:-}" ]]; then
  if [[ ! -f "$SAMPLE_LIST" ]]; then
    echo "ERROR: sample list not found for array job: $SAMPLE_LIST" >&2
    exit 1
  fi
  SAMPLE="$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLE_LIST")"
  if [[ -z "$SAMPLE" ]]; then
    echo "ERROR: no sample found for SLURM_ARRAY_TASK_ID=$SLURM_ARRAY_TASK_ID in $SAMPLE_LIST" >&2
    exit 1
  fi
  echo "Array task sample: $SAMPLE"
fi

if [[ -n "$SAMPLE" ]]; then
  SCRIPT_ARGS+=(--sample "$SAMPLE")
fi

if [[ ! -f "$SCRIPT" ]]; then
  echo "ERROR: Workflow script not found: $SCRIPT"
  exit 1
fi

# Set THREADS environment variable
export THREADS=$SLURM_CPUS_PER_TASK

# Run the workflow
bash "$SCRIPT" "${SCRIPT_ARGS[@]}"

echo ""
echo "======================================"
echo "Workflow Completed Successfully"
echo "======================================"
echo "End time: $(date)"
echo ""

# Print summary statistics
echo "Output directories summary:"
echo "  Alignments: $(find ${WORKDIR}/Analysis/Alignment/alignments -type f 2>/dev/null | wc -l) files"
echo "  BAM files: $(find ${WORKDIR}/Analysis/Alignment/bam -type f -name "*.bam" 2>/dev/null | wc -l) files"
echo "  Logs: $(find ${LOG_DIR} -type f 2>/dev/null | wc -l) files"
echo "  QC reports: $(find ${WORKDIR}/Analysis/Alignment/qc -type f 2>/dev/null | wc -l) files"

if [[ -d "${WORKDIR}/Analysis/Alignment/counts" ]]; then
  count_files=$(find ${WORKDIR}/Analysis/Alignment/counts -type f 2>/dev/null | wc -l)
  if [[ $count_files -gt 0 ]]; then
    echo "  Count tables: $count_files files"
  fi
fi
