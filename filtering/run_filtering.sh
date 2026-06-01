#!/usr/bin/env bash
# Run featureCounts filtering for bacteria and host count matrices.
# Outputs filtered TSVs and QC figures to Analysis/filtering/bacteria/ and /host/.
#
# Usage:
#   bash run_filtering.sh                          # both organisms, defaults
#   bash run_filtering.sh bacteria                 # bacteria only
#   bash run_filtering.sh host                     # host only
#   MIN_TOTAL_COUNT=20 bash run_filtering.sh       # custom count threshold

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-both}"

# Rscript lives in the dualrnaseq_pathway conda environment
RSCRIPT="$(conda run -n dualrnaseq_pathway which Rscript 2>/dev/null)" \
  || RSCRIPT="Rscript"

run_bacteria() {
  echo "[$(date '+%F %T')] Running bacteria filtering..."
  conda run -n dualrnaseq_pathway Rscript "${SCRIPT_DIR}/filter_bacteria.R"
  echo "[$(date '+%F %T')] Bacteria filtering done."
}

run_host() {
  echo "[$(date '+%F %T')] Running host filtering..."
  conda run -n dualrnaseq_pathway Rscript "${SCRIPT_DIR}/filter_host.R"
  echo "[$(date '+%F %T')] Host filtering done."
}

case "$TARGET" in
  bacteria) run_bacteria ;;
  host)     run_host ;;
  both)     run_bacteria; run_host ;;
  *)
    echo "Usage: $0 [bacteria|host|both]" >&2
    exit 1
    ;;
esac

echo ""
echo "Filtering complete. Outputs:"
echo "  Bacteria: ${SCRIPT_DIR}/bacteria/"
echo "  Host:     ${SCRIPT_DIR}/host/"
