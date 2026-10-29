#!/bin/bash
#SBATCH --job-name=featurecounts_host
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/logs/slurm/featurecounts_host_%j.log
#SBATCH --error=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/logs/slurm/featurecounts_host_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=60G
#SBATCH --time=06:00:00

set -euo pipefail

WORKDIR="/home/lshpk18/OzanGundogdu_SOUK011275"
BAM_DIR="$WORKDIR/Analysis/Alignment/bam/host"
GTF="$WORKDIR/Analysis/Alignment/references/GCF_000001405.40_GRCh38.p14_genomic.gtf"
OUT_FILE="$WORKDIR/Analysis/Alignment/counts/host/featureCounts_host.txt"
LOG_FILE="$WORKDIR/Analysis/Alignment/logs/host/featureCounts_host.log"
THREADS="${SLURM_CPUS_PER_TASK:-16}"

source ~/miniconda3/bin/activate dualrnaseq

echo "=============================================="
echo "featureCounts — Host (GRCh38)"
echo "Job ID    : ${SLURM_JOB_ID:-manual}"
echo "Node      : $(hostname)"
echo "Start     : $(date)"
echo "BAMs      : $BAM_DIR"
echo "GTF       : $GTF"
echo "Output    : $OUT_FILE"
echo "=============================================="

featureCounts \
    -T "$THREADS" \
    -p -B -C \
    --fracOverlap 0.5 \
    --fracOverlapFeature 0.5 \
    -Q 10 \
    -F GTF -t exon -g gene_id \
    -a "$GTF" \
    -o "$OUT_FILE" \
    "$BAM_DIR"/*.host.Aligned.sortedByCoord.out.bam \
    2>&1 | tee "$LOG_FILE"

echo "=============================================="
echo "Completed : $(date)"
n_cols=$(awk 'NR==2{print NF-6; exit}' "$OUT_FILE")
echo "Samples   : $n_cols"
echo "=============================================="
