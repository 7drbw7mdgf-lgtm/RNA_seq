#!/bin/bash
#SBATCH --job-name=featurecounts_bacteria
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/logs/slurm/featurecounts_bacteria_%j.log
#SBATCH --error=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/logs/slurm/featurecounts_bacteria_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --time=04:00:00

set -euo pipefail

WORKDIR="/home/lshpk18/OzanGundogdu_SOUK011275"
BAM_DIR="$WORKDIR/Analysis/Alignment/bam/bacteria"
GFF="$WORKDIR/Analysis/Alignment/references/AL111168.1.gff3"
OUT_FILE="$WORKDIR/Analysis/Alignment/counts/bacteria/featureCounts_bacteria.txt"
LOG_FILE="$WORKDIR/Analysis/Alignment/logs/bacteria/featureCounts_bacteria.log"
THREADS="${SLURM_CPUS_PER_TASK:-16}"

source ~/miniconda3/bin/activate dualrnaseq

echo "=============================================="
echo "featureCounts — Bacteria (C. jejuni AL111168.1)"
echo "Job ID    : ${SLURM_JOB_ID:-manual}"
echo "Node      : $(hostname)"
echo "Start     : $(date)"
echo "BAMs      : $BAM_DIR"
echo "GFF       : $GFF"
echo "Output    : $OUT_FILE"
echo "=============================================="

featureCounts \
    -T "$THREADS" \
    -p -B -C \
    --fracOverlap 0.5 \
    --fracOverlapFeature 0.5 \
    -Q 10 \
    -F GTF -t gene -g ID \
    -a "$GFF" \
    -o "$OUT_FILE" \
    "$BAM_DIR"/*.bacteria.Aligned.sortedByCoord.out.bam \
    2>&1 | tee "$LOG_FILE"

echo "=============================================="
echo "Completed : $(date)"
n_cols=$(awk 'NR==2{print NF-6; exit}' "$OUT_FILE")
echo "Samples   : $n_cols"
echo "=============================================="
