#!/bin/bash
#SBATCH --job-name=bam_qc
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Bam_indexing/logs/bam_qc_%j.out
#SBATCH --error=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Bam_indexing/logs/bam_qc_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=06:00:00
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=lshpk18@lshtm.ac.uk

set -euo pipefail

PYTHON=/home/lshpk18/miniconda3/bin/python3
BAM_BASE=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Bam_indexing
SCRIPT="$BAM_BASE/bam_qc.py"
LOG_DIR="$BAM_BASE/logs"
mkdir -p "$LOG_DIR"

echo "[$(date)] Starting BAM QC"

echo "[$(date)] --- Bacteria merged BAMs ---"
$PYTHON "$SCRIPT" \
    "$BAM_BASE/Bacteria/merged" \
    --out-dir "$BAM_BASE/qc_results/bacteria" \
    --pattern "*.bam"

echo "[$(date)] --- Host merged BAMs ---"
$PYTHON "$SCRIPT" \
    "$BAM_BASE/Host/merged" \
    --out-dir "$BAM_BASE/qc_results/host" \
    --pattern "*.bam"

echo "[$(date)] All QC complete"
echo "Results:"
echo "  Bacteria: $BAM_BASE/qc_results/bacteria/qc_summary.tsv"
echo "  Host:     $BAM_BASE/qc_results/host/qc_summary.tsv"
