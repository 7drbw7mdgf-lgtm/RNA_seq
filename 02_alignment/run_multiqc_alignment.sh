#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/pipeline_config.sh}"
[[ -f "$CONFIG_FILE" ]] || {
  echo "ERROR: config file not found: $CONFIG_FILE" >&2
  exit 1
}
source "$CONFIG_FILE"

OUT_DIR="${OUT_DIR:-$ALIGNMENT_DIR/multiqc}"
REPORT_NAME="${REPORT_NAME:-alignment_multiqc_report.html}"
FORCE="false"
DRY_RUN="false"

usage() {
  cat <<'USAGE'
Usage:
  bash Analysis/Alignment/run_multiqc_alignment.sh [options]

Options:
  --out-dir PATH       MultiQC output directory
  --report-name NAME   HTML report filename
  --force              Overwrite an existing report
  --dry-run            Print the MultiQC command without running it
  -h, --help           Show this help

Environment overrides:
  WORKDIR, ALIGNMENT_DIR, OUT_DIR, REPORT_NAME
USAGE
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    --report-name)
      REPORT_NAME="${2:-}"
      shift 2
      ;;
    --force)
      FORCE="true"
      shift
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

command -v multiqc >/dev/null 2>&1 || die "multiqc is not in PATH"
mkdir -p "$OUT_DIR" "$LOG_DIR"
LOG_FILE="$LOG_DIR/alignment_multiqc.log"
REPORT="$OUT_DIR/$REPORT_NAME"

if [[ -s "$REPORT" && "$FORCE" != "true" ]]; then
  log "MultiQC report already exists: $REPORT"
  log "Skipping. Use --force to regenerate."
  exit 0
fi

SEARCH_DIRS=(
  "$ALIGNMENT_DIR/alignments"
  "$ALIGNMENT_DIR/qc"
  "$ALIGNMENT_DIR/alignment_QC"
  "$ALIGNMENT_DIR/counts"
  "$ALIGNMENT_DIR/logs"
)

CMD=(multiqc "${SEARCH_DIRS[@]}" -o "$OUT_DIR" -n "$REPORT_NAME")
if [[ "$FORCE" == "true" ]]; then
  CMD+=(--force)
fi

log "Running MultiQC for alignment, QC, and featureCounts outputs"
printf 'Command:'
printf ' %q' "${CMD[@]}"
printf '\n'

if [[ "$DRY_RUN" == "true" ]]; then
  exit 0
fi

"${CMD[@]}" 2>&1 | tee "$LOG_FILE"
log "MultiQC complete: $REPORT"
