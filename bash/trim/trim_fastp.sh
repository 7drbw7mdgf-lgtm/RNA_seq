#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

FASTQ_DIR="${FASTQ_DIR:-/home/lshpk18/OzanGundogdu_SOUK011275}"
OUTPUT_DIR="$SCRIPT_DIR"
THREADS="${THREADS:-4}"

if ! command -v fastp >/dev/null 2>&1; then
  echo "ERROR: fastp not found in PATH."
  echo "Run: conda activate rna-seq"
  exit 1
fi

if [[ ! -d "$FASTQ_DIR" ]]; then
  echo "ERROR: FASTQ input directory not found: $FASTQ_DIR"
  echo "Set it with:"
  echo "export FASTQ_DIR=/home/lshpk18/OzanGundogdu_SOUK011275"
  exit 1
fi

echo "Using FASTQ_DIR: $FASTQ_DIR"
echo "Writing trimmed files to: $OUTPUT_DIR"

shopt -s nullglob

R1_FILES=("$FASTQ_DIR"/*_R1_001.fastq.gz)

if [[ ${#R1_FILES[@]} -eq 0 ]]; then
  echo "ERROR: No R1 FASTQ files found in $FASTQ_DIR"
  exit 1
fi

for R1 in "${R1_FILES[@]}"; do
  R2="${R1/_R1_001.fastq.gz/_R2_001.fastq.gz}"

  if [[ ! -f "$R2" ]]; then
    echo "WARNING: No matching R2 found for $R1. Skipping."
    continue
  fi

  SAMPLE="$(basename "$R1" _R1_001.fastq.gz)"

  echo "Trimming: $SAMPLE"

  fastp \
    -i "$R1" \
    -I "$R2" \
    -o "$OUTPUT_DIR/${SAMPLE}_R1_trimmed.fastq.gz" \
    -O "$OUTPUT_DIR/${SAMPLE}_R2_trimmed.fastq.gz" \
    --detect_adapter_for_pe \
    --cut_front \
    --cut_tail \
    --cut_window_size 4 \
    --cut_mean_quality 20 \
    --qualified_quality_phred 20 \
    --unqualified_percent_limit 40 \
    --n_base_limit 5 \
    --length_required 30 \
    --thread "$THREADS" \
    --html "$OUTPUT_DIR/${SAMPLE}_fastp.html" \
    --json "$OUTPUT_DIR/${SAMPLE}_fastp.json"
done

echo "All trimming complete."
echo "Trimmed FASTQ files are in: $OUTPUT_DIR"
