#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

VIS_DIR="Visualisation"
PKG_DIR="Package installation"

mkdir -p "$VIS_DIR"
mkdir -p "$PKG_DIR"

echo "Creating virtual environment in $VIS_DIR/venv..."
python -m venv "$VIS_DIR/venv" > "$PKG_DIR/venv_creation.log" 2>&1

echo "Activating virtual environment and installing packages..."
source "$VIS_DIR/venv/bin/activate"
pip install --upgrade pip > "$PKG_DIR/pip_upgrade.log" 2>&1
pip install plotly matplotlib seaborn pandas numpy jupyter > "$PKG_DIR/package_install.log" 2>&1

echo "Installation complete. Virtual environment created in $VIS_DIR/venv"
echo "Packages installed: plotly, matplotlib, seaborn, pandas, numpy, jupyter"
echo "Installation outputs saved in $PKG_DIR/"
