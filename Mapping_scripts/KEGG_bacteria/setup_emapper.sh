#!/usr/bin/env bash
# setup_emapper.sh
# One-time setup: installs eggNOG-mapper 2.1.12 and downloads DIAMOND databases.
# Run interactively on a login/compute node with internet access.
# Databases (~29 GB): eggnog_proteins.dmnd + eggnog.db

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/eggnog_data"
ENV_NAME="emapper"

echo "=============================================="
echo "eggNOG-mapper setup"
echo "Install dir : ${SCRIPT_DIR}"
echo "DB dir      : ${DATA_DIR}"
echo "Conda env   : ${ENV_NAME}"
echo "=============================================="

# 1. Create conda environment with eggNOG-mapper 2.1.12
if conda env list | grep -q "^${ENV_NAME} "; then
  echo "[INFO] Conda env '${ENV_NAME}' already exists — skipping creation"
else
  echo "[STEP 1] Creating conda environment '${ENV_NAME}'..."
  conda create -y -n "${ENV_NAME}" -c bioconda -c conda-forge \
    eggnog-mapper=2.1.12 python=3.9
  echo "[OK] Environment created."
fi

# 2. Download DIAMOND databases (eggnog_proteins.dmnd + eggnog.db)
mkdir -p "${DATA_DIR}"
source /home/lshpk18/miniconda3/bin/activate "${ENV_NAME}"

if [[ -f "${DATA_DIR}/eggnog.db" && -f "${DATA_DIR}/eggnog_proteins.dmnd" ]]; then
  echo "[INFO] Databases already present in ${DATA_DIR} — skipping download"
else
  echo "[STEP 2] Downloading eggNOG databases (~29 GB)..."
  download_eggnog_data.py \
    --data_dir "${DATA_DIR}" \
    -y \
    -f        # DIAMOND mode only (skip HMMER data)
  echo "[OK] Databases downloaded."
fi

echo ""
echo "=============================================="
echo "Setup complete."
echo "Next: sbatch run_emapper.sbatch"
echo "=============================================="
