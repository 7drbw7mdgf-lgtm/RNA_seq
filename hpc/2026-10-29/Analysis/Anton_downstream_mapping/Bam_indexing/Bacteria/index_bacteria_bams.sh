#!/usr/bin/env bash
set -euo pipefail

# Merge bacterial BAM files from different lanes of the same sample+run,
# then index each merged BAM.
#
# Grouping: the key is everything before the _L00X lane suffix, so
# Lane 1 and Lane 7 BAMs for the same sample+run are merged together.
#
# e.g.  15m_1_Run_1_S4_L001.bacteria...bam  ┐
#       15m_1_Run_1_S4_L007.bacteria...bam  ┘ -> 15m_1_Run_1_S4.bacteria.merged.bam
#
# Result: 96 merged+indexed BAMs (48 samples x 2 runs).
#
# Usage:
#   bash index_bacteria_bams.sh [--bam-dir PATH] [--out-dir PATH] \
#                               [--threads N] [--parallel N] [--force]

BAM_DIR="${BAM_DIR:-/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/bam/bacteria}"
OUT_DIR="${OUT_DIR:-/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Bam_indexing/Bacteria/merged}"
THREADS="${THREADS:-2}"
PARALLEL="${PARALLEL:-4}"
FORCE="${FORCE:-false}"
LOG_DIR="${LOG_DIR:-/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Bam_indexing/Bacteria/logs}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bam-dir)  BAM_DIR="$2";  shift 2 ;;
    --out-dir)  OUT_DIR="$2";  shift 2 ;;
    --threads)  THREADS="$2";  shift 2 ;;
    --parallel) PARALLEL="$2"; shift 2 ;;
    --force)    FORCE="true";  shift   ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 1 ;;
  esac
done

mkdir -p "$OUT_DIR" "$LOG_DIR"
LOG_FILE="$LOG_DIR/merge_index_bacteria_$(date +%Y%m%d_%H%M%S).log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "============================================"
log "Bacterial BAM Lane Merge + Index"
log "============================================"
log "BAM input dir : $BAM_DIR"
log "Output dir    : $OUT_DIR"
log "Threads/job   : $THREADS"
log "Parallel jobs : $PARALLEL"
log "Force redo    : $FORCE"
log "Log           : $LOG_FILE"

[[ -d "$BAM_DIR" ]] || { log "ERROR: BAM directory not found: $BAM_DIR"; exit 1; }
command -v samtools >/dev/null 2>&1 || { log "ERROR: samtools not found in PATH"; exit 1; }
log "samtools: $(samtools --version | head -1)"

# ---- Group BAMs by sample+run (strip _L00X lane suffix) ----
declare -A group_bams
while IFS= read -r bam; do
  name=$(basename "$bam")
  group_key="${name%%_L0*.bacteria*}"
  group_bams["$group_key"]+=" $bam"
done < <(find "$BAM_DIR" -maxdepth 1 -name "*.bacteria.Aligned.sortedByCoord.out.bam" | sort)

n_groups="${#group_bams[@]}"
[[ "$n_groups" -gt 0 ]] || { log "ERROR: no bacterial BAM files found in $BAM_DIR"; exit 1; }
log "Found $n_groups sample+run groups to process"

for key in $(echo "${!group_bams[@]}" | tr ' ' '\n' | sort); do
  n=$(echo "${group_bams[$key]}" | wc -w)
  log "  $key : $n lane BAM(s)"
done

# ---- Merge + index function ----
merge_and_index() {
  local key="$1"
  local bams="$2"
  local out_bam="$OUT_DIR/${key}.bacteria.merged.bam"
  local sample_log="$LOG_DIR/${key}_merge.log"

  if [[ "$FORCE" == "false" && -f "$out_bam" && -f "${out_bam}.bai" ]]; then
    echo "SKIP $key (already done)"
    return 0
  fi

  local bam_array=($bams)
  echo "MERGE $key (${#bam_array[@]} lane(s)) -> $(basename "$out_bam")"

  if [[ "${#bam_array[@]}" -eq 1 ]]; then
    samtools view -@ "$THREADS" -b -o "$out_bam" "${bam_array[0]}" 2>>"$sample_log"
  else
    samtools merge -f -@ "$THREADS" "$out_bam" "${bam_array[@]}" 2>>"$sample_log"
  fi

  samtools index -@ "$THREADS" "$out_bam" 2>>"$sample_log"
  echo "DONE  $key"
}
export -f merge_and_index
export OUT_DIR LOG_DIR THREADS FORCE

# ---- Run in parallel ----
log ""
log "Starting merges ($PARALLEL parallel jobs)..."

job_args=()
n_skip=0
for key in $(echo "${!group_bams[@]}" | tr ' ' '\n' | sort); do
  out_bam="$OUT_DIR/${key}.bacteria.merged.bam"
  if [[ "$FORCE" == "false" && -f "$out_bam" && -f "${out_bam}.bai" ]]; then
    (( n_skip++ )) || true
  else
    job_args+=("${key}|||${group_bams[$key]}")
  fi
done

log "Skipping $n_skip already-completed groups"
log "Processing ${#job_args[@]} groups"

if [[ "${#job_args[@]}" -gt 0 ]]; then
  printf '%s\n' "${job_args[@]}" \
    | xargs -P "$PARALLEL" -I{} bash -c '
        arg="{}"
        key="${arg%%|||*}"
        bams="${arg##*|||}"
        merge_and_index "$key" "$bams"
      ' \
    | tee -a "$LOG_FILE"
fi

# ---- Verify outputs ----
log ""
n_fail=0
for key in $(echo "${!group_bams[@]}" | tr ' ' '\n' | sort); do
  out_bam="$OUT_DIR/${key}.bacteria.merged.bam"
  if [[ ! -f "$out_bam" || ! -f "${out_bam}.bai" ]]; then
    log "MISSING: $out_bam"
    (( n_fail++ )) || true
  fi
done

log "============================================"
if [[ "$n_fail" -eq 0 ]]; then
  log "Complete — $n_groups merged + indexed BAMs in $OUT_DIR"
else
  log "ERROR: $n_fail groups failed — check logs in $LOG_DIR"
  exit 1
fi
log "============================================"
