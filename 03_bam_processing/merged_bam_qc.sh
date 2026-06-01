#!/usr/bin/env bash
set -euo pipefail

# Run samtools flagstat + idxstats on all merged BAMs (bacteria and host),
# then generate a combined MultiQC report.

SAMTOOLS="${SAMTOOLS:-/home/lshpk18/miniconda3/bin/samtools}"
MULTIQC="${MULTIQC:-/home/lshpk18/miniconda3/bin/multiqc}"
THREADS="${THREADS:-16}"

BAM_DIR="${BAM_DIR:-/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Bam_indexing}"
QC_DIR="$BAM_DIR/qc"
REPORT_DIR="$BAM_DIR/multiqc"
LOG_DIR="$BAM_DIR/logs"

mkdir -p "$QC_DIR/bacteria" "$QC_DIR/host" "$REPORT_DIR" "$LOG_DIR"

echo "[$(date)] Running samtools flagstat and idxstats on merged BAMs"

for BAM in "$BAM_DIR/Bacteria/merged"/*.bam; do
    SAMPLE=$(basename "$BAM" .bam)
    $SAMTOOLS flagstat -@ 2 "$BAM" > "$QC_DIR/bacteria/${SAMPLE}.flagstat" &
    $SAMTOOLS idxstats    "$BAM" > "$QC_DIR/bacteria/${SAMPLE}.idxstats"  &
done

for BAM in "$BAM_DIR/Host/merged"/*.bam; do
    SAMPLE=$(basename "$BAM" .bam)
    $SAMTOOLS flagstat -@ 2 "$BAM" > "$QC_DIR/host/${SAMPLE}.flagstat" &
    $SAMTOOLS idxstats    "$BAM" > "$QC_DIR/host/${SAMPLE}.idxstats"  &
done

wait
echo "[$(date)] samtools complete"

$MULTIQC \
    "$QC_DIR" \
    "$BAM_DIR/Bacteria/merged" \
    "$BAM_DIR/Host/merged" \
    -o "$REPORT_DIR" \
    -n merged_bam_multiqc_report.html \
    --force

echo "[$(date)] MultiQC complete: $REPORT_DIR/merged_bam_multiqc_report.html"
