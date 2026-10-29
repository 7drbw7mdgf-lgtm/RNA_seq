#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if command -v conda >/dev/null 2>&1; then
  echo "Installing FastQC and MultiQC with conda..."
  conda install -y -c bioconda -c conda-forge fastqc multiqc
  echo "Installation complete. fastqc and multiqc should now be available in PATH."
  exit 0
fi

if command -v mamba >/dev/null 2>&1; then
  echo "Installing FastQC and MultiQC with mamba..."
  mamba install -y -c bioconda -c conda-forge fastqc multiqc
  echo "Installation complete. fastqc and multiqc should now be available in PATH."
  exit 0
fi

echo "Neither conda nor mamba is available. Trying pip for MultiQC and checking FastQC..."

if ! command -v pip >/dev/null 2>&1; then
  echo "ERROR: pip is not installed. Please install conda/mamba or pip and rerun this script."
  exit 1
fi

pip install --user multiqc

echo "MultiQC installed via pip."

echo "Please install FastQC separately if it is not already available in PATH."
echo "On Debian/Ubuntu: sudo apt-get update && sudo apt-get install -y fastqc"
echo "Or install FastQC with conda/mamba once available: conda install -y -c bioconda fastqc"

echo "If FastQC is installed after this script, rerun QC.sh."
