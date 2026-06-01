#!/usr/bin/env bash
set -euo pipefail

# Run from the script directory
cd "$(dirname "$0")"

DATA_DIR="$(pwd)"
OUT_DIR="$(pwd)/Analysis/fastqc_results"
LOG_FILE="$(pwd)/Analysis/QC.log"

mkdir -p "$OUT_DIR"

num_threads=$(nproc 2>/dev/null || echo 1)

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Starting QC on FASTQ files in $DATA_DIR" | tee "$LOG_FILE"

if ! command -v fastqc >/dev/null 2>&1; then
  echo "ERROR: fastqc is not installed or not in PATH." | tee -a "$LOG_FILE"
  exit 1
fi

if ! command -v multiqc >/dev/null 2>&1; then
  echo "ERROR: multiqc is not installed or not in PATH." | tee -a "$LOG_FILE"
  exit 1
fi

shopt -s nullglob
fastq_files=("$DATA_DIR"/*_R1_*.fastq.gz "$DATA_DIR"/*_R2_*.fastq.gz)
shopt -u nullglob

if [[ ${#fastq_files[@]} -eq 0 ]]; then
  echo "ERROR: No paired-end FASTQ files found in $DATA_DIR." | tee -a "$LOG_FILE"
  exit 1
fi

echo "Found ${#fastq_files[@]} FASTQ files. Running FastQC with $num_threads threads..." | tee -a "$LOG_FILE"
fastqc -t "$num_threads" -o "$OUT_DIR" "${fastq_files[@]}" 2>&1 | tee -a "$LOG_FILE"

echo "FastQC complete. Generating MultiQC report..." | tee -a "$LOG_FILE"
cd "$OUT_DIR"
multiqc . -o . 2>&1 | tee -a "$LOG_FILE"

echo "QC finished successfully. Results are in $OUT_DIR." | tee -a "$LOG_FILE"
