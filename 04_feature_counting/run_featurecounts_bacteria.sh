#!/usr/bin/env bash
set -euo pipefail

# Run featureCounts on merged bacterial BAM files.
#
# Input:  merged BAMs from Bam_indexing/Bacteria/merged/
# Output: count matrix + summary in Anton_downstream_mapping/FeatureCounts/
#
# Annotation: AL111168.1.gff3 (C. jejuni NCTC 11168)
# Feature type: gene  |  Attribute: ID  (produces gene-Cj0001 style IDs)
#
# Usage:
#   bash run_featurecounts_bacteria.sh [--bam-dir PATH] [--out-dir PATH] \
#                                      [--annotation PATH] [--threads N] [--force]

BAM_DIR="${BAM_DIR:-/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Bam_indexing/Bacteria/merged}"
OUT_DIR="${OUT_DIR:-/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/FeatureCounts}"
ANNOTATION="${ANNOTATION:-/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/references/AL111168.1.gff3}"
THREADS="${THREADS:-16}"
FORCE="${FORCE:-false}"
LOG_DIR="${LOG_DIR:-$OUT_DIR/logs}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bam-dir)     BAM_DIR="$2";     shift 2 ;;
    --out-dir)     OUT_DIR="$2";     shift 2 ;;
    --annotation)  ANNOTATION="$2";  shift 2 ;;
    --threads)     THREADS="$2";     shift 2 ;;
    --force)       FORCE="true";     shift   ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 1 ;;
  esac
done

mkdir -p "$OUT_DIR" "$LOG_DIR"
LOG_FILE="$LOG_DIR/featurecounts_bacteria_$(date +%Y%m%d_%H%M%S).log"
OUT_FILE="$OUT_DIR/featureCounts_bacteria.txt"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "============================================"
log "featureCounts — Bacterial BAMs"
log "============================================"
log "BAM directory : $BAM_DIR"
log "Annotation    : $ANNOTATION"
log "Output file   : $OUT_FILE"
log "Threads       : $THREADS"
log "Force rerun   : $FORCE"
log "Log           : $LOG_FILE"

# Checks
[[ -d "$BAM_DIR" ]]    || { log "ERROR: BAM directory not found: $BAM_DIR"; exit 1; }
[[ -f "$ANNOTATION" ]] || { log "ERROR: annotation file not found: $ANNOTATION"; exit 1; }
command -v featureCounts >/dev/null 2>&1 || { log "ERROR: featureCounts not found in PATH"; exit 1; }
log "featureCounts: $(featureCounts -v 2>&1 | head -1)"

# Collect merged BAM files
mapfile -t BAM_FILES < <(find "$BAM_DIR" -maxdepth 1 -name "*.bacteria.merged.bam" | sort)
n_bams="${#BAM_FILES[@]}"
[[ "$n_bams" -gt 0 ]] || { log "ERROR: no merged bacterial BAM files found in $BAM_DIR"; exit 1; }
log "Found $n_bams merged BAM files"

# Check all BAMs are indexed
n_missing_idx=0
for bam in "${BAM_FILES[@]}"; do
  [[ -f "${bam}.bai" ]] || { log "WARNING: missing index for $(basename "$bam")"; (( n_missing_idx++ )) || true; }
done
[[ "$n_missing_idx" -eq 0 ]] || { log "ERROR: $n_missing_idx BAM files are not indexed — run indexing first"; exit 1; }

# Skip if already complete
if [[ "$FORCE" == "false" && -f "$OUT_FILE" ]]; then
  log "Output already exists: $OUT_FILE (use --force to rerun)"
  exit 0
fi

log ""
log "Running featureCounts..."

featureCounts \
  -T "$THREADS" \
  -p \
  -B \
  -C \
  -F GTF \
  -t gene \
  -g ID \
  -a "$ANNOTATION" \
  -o "$OUT_FILE" \
  "${BAM_FILES[@]}" \
  2>&1 | tee "$LOG_DIR/featureCounts_bacteria_run.log"

# Verify output
[[ -f "$OUT_FILE" ]] || { log "ERROR: output file not created"; exit 1; }
n_genes=$(grep -c "^gene-" "$OUT_FILE" || true)

log ""
log "============================================"
log "featureCounts complete"
log "  Genes counted : $n_genes"
log "  Count matrix  : $OUT_FILE"
log "  Summary       : ${OUT_FILE}.summary"
log "============================================"
