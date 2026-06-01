#!/usr/bin/env bash
set -euo pipefail

TRIM_DIR="${TRIM_DIR:-/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/trim_results}"
OUTPUT_DIR="${OUTPUT_DIR:-/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/trimmed_fastqc_results}"
LOG_FILE="${LOG_FILE:-$OUTPUT_DIR/run_multiqc_trimmed.log}"

if ! command -v multiqc >/dev/null 2>&1; then
  echo "ERROR: multiqc is not installed or not in PATH."
  echo "Install it with conda/mamba or run /home/lshpk18/OzanGundogdu_SOUK011275/install_qc_dependencies.sh"
  exit 1
fi

if [[ ! -d "$TRIM_DIR" ]]; then
  echo "ERROR: trimmed data directory not found: $TRIM_DIR"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Running MultiQC on trimmed data in $TRIM_DIR" | tee "$LOG_FILE"

multiqc "$TRIM_DIR" -o "$OUTPUT_DIR" --force 2>&1 | tee -a "$LOG_FILE"

echo "MultiQC complete. Results are in $OUTPUT_DIR"
