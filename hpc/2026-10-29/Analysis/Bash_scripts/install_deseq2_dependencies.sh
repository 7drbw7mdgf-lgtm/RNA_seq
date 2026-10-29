#!/usr/bin/env bash
set -euo pipefail

# Install the R/Bioconductor layer used after featureCounts.
# Alignment tools remain in Analysis/install_allignment_dependancies.sh so this
# script can be run independently after count matrices have been prepared.

CONDA_ENV="${CONDA_ENV:-dualrnaseq_deseq2}"
ENV_FILE="${ENV_FILE:-/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/DifferentialExpression/environment.deseq2.yml}"
INSTALLER="${INSTALLER:-}"
FORCE="false"
DRY_RUN="false"

usage() {
  cat <<'USAGE'
Usage:
  bash Analysis/install_deseq2_dependencies.sh [options]

Options:
  --env-name NAME      Conda environment name (default: dualrnaseq_deseq2)
  --env-file PATH      Environment YAML to create/update
  --force              Recreate the environment if it already exists
  --dry-run            Print the mamba/conda command without running it
  -h, --help           Show this help

Environment overrides:
  CONDA_ENV, ENV_FILE, INSTALLER
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
    --env-name)
      CONDA_ENV="${2:-}"
      shift 2
      ;;
    --env-file)
      ENV_FILE="${2:-}"
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

[[ -s "$ENV_FILE" ]] || die "Environment file not found or empty: $ENV_FILE"

if [[ -z "$INSTALLER" ]]; then
  if command -v mamba >/dev/null 2>&1; then
    INSTALLER="$(command -v mamba)"
  elif command -v conda >/dev/null 2>&1; then
    INSTALLER="$(command -v conda)"
  elif [[ -x /home/lshpk18/miniconda3/bin/mamba ]]; then
    INSTALLER="/home/lshpk18/miniconda3/bin/mamba"
  elif [[ -x /home/lshpk18/miniconda3/bin/conda ]]; then
    INSTALLER="/home/lshpk18/miniconda3/bin/conda"
  else
    die "No mamba or conda executable found"
  fi
fi

if "$INSTALLER" env list | awk '{print $1}' | grep -Fxq "$CONDA_ENV"; then
  if [[ "$FORCE" == "true" ]]; then
    log "Removing existing environment: $CONDA_ENV"
    if [[ "$DRY_RUN" != "true" ]]; then
      "$INSTALLER" env remove -n "$CONDA_ENV" -y
    fi
  else
    log "Environment already exists: $CONDA_ENV"
    log "Updating from: $ENV_FILE"
    if [[ "$DRY_RUN" == "true" ]]; then
      printf '%q env update -n %q -f %q\n' "$INSTALLER" "$CONDA_ENV" "$ENV_FILE"
    else
      "$INSTALLER" env update -n "$CONDA_ENV" -f "$ENV_FILE"
    fi
    exit 0
  fi
fi

log "Creating environment: $CONDA_ENV"
log "Environment file: $ENV_FILE"
if [[ "$DRY_RUN" == "true" ]]; then
  printf '%q env create -n %q -f %q\n' "$INSTALLER" "$CONDA_ENV" "$ENV_FILE"
else
  "$INSTALLER" env create -n "$CONDA_ENV" -f "$ENV_FILE"
fi

log "Done. Activate with: conda activate $CONDA_ENV"
