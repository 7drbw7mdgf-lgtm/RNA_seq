#!/bin/bash
#SBATCH --job-name=bam_qc
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/logs/bam_qc_%j.log
#SBATCH --error=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/logs/bam_qc_%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=lshpk18@lshtm.ac.uk
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=40G
#SBATCH --time=24:00:00
#SBATCH --chdir=/home/lshpk18/OzanGundogdu_SOUK011275

# BAM QC SLURM wrapper for the dual RNA-seq alignment outputs.
#
# Usage:
#   sbatch Analysis/Alignment/bam_qc.sbatch
#   sbatch --export=TARGET=host Analysis/Alignment/bam_qc.sbatch
#   sbatch --export=TARGET=bacteria Analysis/Alignment/bam_qc.sbatch
#   sbatch --export=TARGET=all,THREADS=8 Analysis/Alignment/bam_qc.sbatch
#
# Environment overrides:
#   WORKDIR, ALIGNMENT_DIR, BAM_DIR, OUT_DIR, TARGET, THREADS, CONDA_ENV, SKIP_CONDA

set -euo pipefail

WORKDIR="${WORKDIR:-/home/lshpk18/OzanGundogdu_SOUK011275}"
ALIGNMENT_DIR="${ALIGNMENT_DIR:-$WORKDIR/Analysis/Alignment}"
QC_SCRIPT="${QC_SCRIPT:-$ALIGNMENT_DIR/Aligment_QC}"
BAM_DIR="${BAM_DIR:-$ALIGNMENT_DIR/bam}"
OUT_DIR="${OUT_DIR:-$ALIGNMENT_DIR/alignment_QC}"
TARGET="${TARGET:-all}"
THREADS="${THREADS:-${SLURM_CPUS_PER_TASK:-16}}"
CONDA_ENV="${CONDA_ENV:-dualrnaseq}"
SKIP_CONDA="${SKIP_CONDA:-false}"
LOG_DIR="${ALIGNMENT_DIR}/logs"

mkdir -p "$LOG_DIR"

echo "======================================"
echo "Dual RNA-Seq BAM QC SLURM Job"
echo "======================================"
echo "Job ID: ${SLURM_JOB_ID:-manual}"
echo "Node: $(hostname)"
echo "CPUs: ${SLURM_CPUS_PER_TASK:-$THREADS}"
echo "Memory: ${SLURM_MEM_M:-${SLURM_MEM_PER_NODE:-unknown}} MB"
echo "Start time: $(date)"
echo "Workdir: $WORKDIR"
echo "BAM directory: $BAM_DIR"
echo "Output directory: $OUT_DIR"
echo "Target: $TARGET"
echo "Threads: $THREADS"
echo "Conda env: ${CONDA_ENV:-none}"
echo ""

case "$TARGET" in
  host|bacteria|all) ;;
  *)
    echo "ERROR: TARGET must be one of: host, bacteria, all" >&2
    exit 1
    ;;
esac

if [[ ! -f "$QC_SCRIPT" ]]; then
  echo "ERROR: BAM QC script not found: $QC_SCRIPT" >&2
  exit 1
fi

if [[ ! -d "$BAM_DIR" ]]; then
  echo "ERROR: BAM directory not found: $BAM_DIR" >&2
  exit 1
fi

if [[ "$SKIP_CONDA" != "true" && -n "$CONDA_ENV" ]]; then
  echo "Activating conda environment: $CONDA_ENV"
  if [[ ! -f /home/lshpk18/miniconda3/bin/activate ]]; then
    echo "ERROR: conda activate script not found: /home/lshpk18/miniconda3/bin/activate" >&2
    exit 1
  fi
  source /home/lshpk18/miniconda3/bin/activate "$CONDA_ENV"
fi

echo "Checking required BAM QC tools..."
for tool in samtools qualimap infer_experiment.py inner_distance.py read_distribution.py; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: required tool not found in PATH: $tool" >&2
    exit 1
  fi
  echo "  $tool: $(command -v "$tool")"
done

echo ""
echo "Running BAM QC..."
bash "$QC_SCRIPT" \
  --target "$TARGET" \
  --bam-dir "$BAM_DIR" \
  --out-dir "$OUT_DIR" \
  --threads "$THREADS"

echo ""
echo "======================================"
echo "BAM QC Completed Successfully"
echo "======================================"
echo "End time: $(date)"
echo "Summary directory: $OUT_DIR/summary"
