#!/bin/bash
#SBATCH --job-name=merged_bam_qc
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Bam_indexing/logs/merged_bam_qc_%j.out
#SBATCH --error=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Bam_indexing/logs/merged_bam_qc_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --time=04:00:00

set -euo pipefail

SAMTOOLS=/home/lshpk18/miniconda3/bin/samtools
MULTIQC=/home/lshpk18/miniconda3/bin/multiqc

BAM_DIR=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Bam_indexing
QC_DIR="$BAM_DIR/qc"
REPORT_DIR="$BAM_DIR/multiqc"
LOG_DIR="$BAM_DIR/logs"

mkdir -p "$QC_DIR/bacteria" "$QC_DIR/host" "$REPORT_DIR" "$LOG_DIR"

echo "[$(date)] Running samtools flagstat and idxstats on merged BAMs"

# Bacteria
for BAM in "$BAM_DIR/Bacteria/merged"/*.bam; do
    SAMPLE=$(basename "$BAM" .bam)
    $SAMTOOLS flagstat -@ 2 "$BAM" > "$QC_DIR/bacteria/${SAMPLE}.flagstat" &
    $SAMTOOLS idxstats    "$BAM" > "$QC_DIR/bacteria/${SAMPLE}.idxstats"  &
done

# Host
for BAM in "$BAM_DIR/Host/merged"/*.bam; do
    SAMPLE=$(basename "$BAM" .bam)
    $SAMTOOLS flagstat -@ 2 "$BAM" > "$QC_DIR/host/${SAMPLE}.flagstat" &
    $SAMTOOLS idxstats    "$BAM" > "$QC_DIR/host/${SAMPLE}.idxstats"  &
done

wait
echo "[$(date)] samtools complete"

# MultiQC — overwrite the alignment report with merged-BAM stats
$MULTIQC \
    "$QC_DIR" \
    "$BAM_DIR/Bacteria/merged" \
    "$BAM_DIR/Host/merged" \
    -o "$REPORT_DIR" \
    -n merged_bam_multiqc_report.html \
    --force

echo "[$(date)] MultiQC complete: $REPORT_DIR/merged_bam_multiqc_report.html"
