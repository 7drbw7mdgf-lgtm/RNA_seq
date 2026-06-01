#!/usr/bin/env bash
# Run DESeq2 normalisation for bacteria and host filtered count matrices.
# Reads from Analysis/filtering/{bacteria,host}/ and writes to
# Analysis/normalisation/{bacteria,host}/.
#
# Usage:
#   bash run_normalisation.sh                  # both organisms
#   bash run_normalisation.sh bacteria         # bacteria only
#   bash run_normalisation.sh host             # host only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-both}"

run_bacteria() {
  echo "[$(date '+%F %T')] Running bacteria normalisation..."
  conda run -n dualrnaseq_pathway Rscript "${SCRIPT_DIR}/normalise_bacteria.R"
  echo "[$(date '+%F %T')] Bacteria normalisation done."
}

run_host() {
  echo "[$(date '+%F %T')] Running host normalisation..."
  conda run -n dualrnaseq_pathway Rscript "${SCRIPT_DIR}/normalise_host.R"
  echo "[$(date '+%F %T')] Host normalisation done."
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
echo "Normalisation complete. Outputs:"
echo "  Bacteria: ${SCRIPT_DIR}/bacteria/"
echo "  Host:     ${SCRIPT_DIR}/host/"
