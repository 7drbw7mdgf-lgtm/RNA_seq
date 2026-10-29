#!/usr/bin/env bash
set -euo pipefail

# Installer for alignment workflow dependencies.
# This script assumes you have conda or mamba installed and available in PATH.

ENV_NAME="dualrnaseq"
CHANNELS=(-c bioconda -c conda-forge)
DEPS=(star=2.7.11b samtools=1.20 subread=2.0.6 python=3.11)
OPTIONAL_DEPS=(multiqc=1.25.1 qualimap rseqc)

function die() {
  echo "ERROR: $*" >&2
  exit 1
}

function check_command() {
  command -v "$1" >/dev/null 2>&1
}

if ! check_command conda && ! check_command mamba; then
  die "Neither conda nor mamba was found in PATH. Install Miniconda/Anaconda or add it to PATH before running this script."
fi

INSTALLER="$(command -v mamba || command -v conda)"

cat <<EOF
Installing required alignment workflow dependencies into conda environment: $ENV_NAME
Required packages: ${DEPS[*]}
Optional package: ${OPTIONAL_DEPS[*]}
EOF

if check_command mamba; then
  echo "Using mamba for faster installation."
  "$INSTALLER" create -n "$ENV_NAME" "${DEPS[@]}" "${CHANNELS[@]}" -y
else
  echo "Using conda for installation."
  "$INSTALLER" create -n "$ENV_NAME" "${DEPS[@]}" "${CHANNELS[@]}" -y
fi

echo
cat <<EOF
To use the workflow, activate the environment:
  conda activate $ENV_NAME

If you want optional QC support (MultiQC, Qualimap, and RSeQC), run:
  conda activate $ENV_NAME
  conda install -n $ENV_NAME -c bioconda -c conda-forge ${OPTIONAL_DEPS[*]} -y
EOF
