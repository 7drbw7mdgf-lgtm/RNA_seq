#!/usr/bin/env bash
set -euo pipefail

# This script installs the packages required to run QC.sh.
# It prefers mamba, falls back to conda if needed.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ENV_NAME="rna-seq"
PKGS=(fastqc multiqc)

if command -v mamba >/dev/null 2>&1; then
  PKG_MANAGER="mamba"
elif command -v micromamba >/dev/null 2>&1; then
  PKG_MANAGER="micromamba"
elif command -v conda >/dev/null 2>&1; then
  PKG_MANAGER="conda"
else
  echo "ERROR: no mamba, micromamba, or conda command found in PATH." >&2
  echo "Install mamba first, then re-run this script." >&2
  exit 1
fi

# Check if the environment exists.
if "$PKG_MANAGER" env list 2>/dev/null | grep -E "^${ENV_NAME}(\s|$)" >/dev/null 2>&1; then
  echo "Using existing environment: $ENV_NAME"
  if [ "$PKG_MANAGER" = "conda" ]; then
    conda install -n "$ENV_NAME" -y -c bioconda "${PKGS[@]}"
  else
    "$PKG_MANAGER" install -n "$ENV_NAME" -y -c bioconda "${PKGS[@]}"
  fi
else
  echo "Creating environment: $ENV_NAME"
  if [ "$PKG_MANAGER" = "conda" ]; then
    conda create -n "$ENV_NAME" -y -c bioconda "${PKGS[@]}"
  else
    "$PKG_MANAGER" create -n "$ENV_NAME" -y -c bioconda "${PKGS[@]}"
  fi
fi

cat <<EOF
QC dependencies installed.
Activate the environment with:
  mamba activate $ENV_NAME
Then run:
  cd "$SCRIPT_DIR"
  bash QC.sh
EOF
