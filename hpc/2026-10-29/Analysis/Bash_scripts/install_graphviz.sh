#!/usr/bin/env bash
set -euo pipefail

# This script installs Graphviz into the RNA-seq conda environment used by the analysis pipeline.
# It prefers mamba, falls back to micromamba or conda if needed.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ENV_NAME="rna-seq"
PKGS=(graphviz)

if command -v mamba >/dev/null 2>&1; then
  PKG_MANAGER="mamba"
elif command -v micromamba >/dev/null 2>&1; then
  PKG_MANAGER="micromamba"
elif command -v conda >/dev/null 2>&1; then
  PKG_MANAGER="conda"
else
  echo "ERROR: no mamba, micromamba, or conda command found in PATH." >&2
  echo "Install mamba or conda first, then re-run this script." >&2
  exit 1
fi

if "$PKG_MANAGER" env list 2>/dev/null | grep -E "^${ENV_NAME}(\s|$)" >/dev/null 2>&1; then
  echo "Using existing environment: $ENV_NAME"
  if [ "$PKG_MANAGER" = "conda" ]; then
    conda install -n "$ENV_NAME" -y -c conda-forge "${PKGS[@]}"
  else
    "$PKG_MANAGER" install -n "$ENV_NAME" -y -c conda-forge "${PKGS[@]}"
  fi
else
  echo "Creating environment: $ENV_NAME"
  if [ "$PKG_MANAGER" = "conda" ]; then
    conda create -n "$ENV_NAME" -y -c conda-forge "${PKGS[@]}"
  else
    "$PKG_MANAGER" create -n "$ENV_NAME" -y -c conda-forge "${PKGS[@]}"
  fi
fi

cat <<EOF
Graphviz installed into the $ENV_NAME environment.
Activate the environment with:
  mamba activate $ENV_NAME
Then run your analysis commands from this folder.
EOF
