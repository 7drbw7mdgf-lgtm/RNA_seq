#!/usr/bin/env bash
set -euo pipefail

# Install mamba via an existing conda installation if available.
# If conda is not installed, use micromamba to bootstrap a local mamba prefix.

export PATH="$HOME/.local/bin:$PATH"

if command -v mamba >/dev/null 2>&1; then
  echo "mamba is already installed at $(command -v mamba)"
  exit 0
fi

if command -v conda >/dev/null 2>&1; then
  echo "Found conda at $(command -v conda). Installing mamba into the base environment..."
  conda install -y -n base -c conda-forge mamba
  echo "mamba installed successfully."
  exit 0
fi

MAMBA_PREFIX="$HOME/mamba-bootstrap"
MICROMAMBA_BIN="$HOME/.local/bin/micromamba"
mkdir -p "$HOME/.local/bin"
mkdir -p "$MAMBA_PREFIX"

if ! command -v micromamba >/dev/null 2>&1; then
  echo "No conda found; installing micromamba into $MICROMAMBA_BIN..."
  curl -L https://micro.mamba.pm/api/micromamba/linux-64/latest -o /tmp/micromamba
  chmod +x /tmp/micromamba
  mv /tmp/micromamba "$MICROMAMBA_BIN"
fi

echo "Bootstrapping mamba into $MAMBA_PREFIX..."
"$MICROMAMBA_BIN" install -y -p "$MAMBA_PREFIX" -c conda-forge mamba

ln -sf "$MAMBA_PREFIX/bin/mamba" "$HOME/.local/bin/mamba"

if command -v mamba >/dev/null 2>&1; then
  echo "mamba installed successfully at $(command -v mamba)"
else
  echo "ERROR: mamba installation completed but the binary could not be found in PATH." >&2
  exit 1
fi
