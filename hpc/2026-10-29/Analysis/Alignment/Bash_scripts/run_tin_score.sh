#!/usr/bin/env bash
# Calculate the RSeQC Transcript Integrity Number (TIN) for one BAM file.
#
# TIN measures RNA degradation from aligned reads (Wang et al. 2016, BMC
# Bioinformatics, https://doi.org/10.1186/s12859-016-0922-z) and is reported
# per transcript (0-100) plus a sample-level mean/median/stdev.
#
# Usage:
#   run_tin_score.sh <bam> <target: host|bacteria> <gene_bed> <out_dir>
#
# Writes into $OUT_DIR/$TARGET/$SAMPLE/rseqc/:
#   ${SAMPLE}.tin.xls          per-transcript TIN values
#   ${SAMPLE}.tin_summary.txt  sample-level TIN mean/median/stdev
set -euo pipefail

BAM="${1:?BAM file required}"
TARGET="${2:?target (host|bacteria) required}"
GENE_BED="${3:?reference BED12 required}"
OUT_DIR="${4:?output root required}"

[[ -f "$BAM" ]] || { echo "ERROR: BAM not found: $BAM" >&2; exit 1; }
[[ -f "$GENE_BED" ]] || { echo "ERROR: gene BED not found: $GENE_BED" >&2; exit 1; }

SAMPLE="$(basename "$BAM" .Aligned.sortedByCoord.out.bam)"
SAMPLE_DIR="$OUT_DIR/$TARGET/$SAMPLE"
RSEQC_DIR="$SAMPLE_DIR/rseqc"
mkdir -p "$RSEQC_DIR"

echo "TIN: target=$TARGET sample=$SAMPLE bam=$BAM"
echo "Host: $(hostname)  Start: $(date)"

[[ -s "${BAM}.bai" ]] || samtools index "$BAM"

WORK_TMP="$(mktemp -d "${RSEQC_DIR}/.tin_tmp.XXXXXX")"
trap 'rm -rf "$WORK_TMP"' EXIT

tin.py -i "$BAM" -r "$GENE_BED" -o "$WORK_TMP" --verbose

BAM_STEM="$(basename "$BAM" .bam)"
mv "$WORK_TMP/${BAM_STEM}.tin.xls" "$RSEQC_DIR/${SAMPLE}.tin.xls"
mv "$WORK_TMP/${BAM_STEM}.summary.txt" "$RSEQC_DIR/${SAMPLE}.tin_summary.txt"

echo "Wrote:"
echo "  $RSEQC_DIR/${SAMPLE}.tin.xls"
echo "  $RSEQC_DIR/${SAMPLE}.tin_summary.txt"
echo "End: $(date)"
