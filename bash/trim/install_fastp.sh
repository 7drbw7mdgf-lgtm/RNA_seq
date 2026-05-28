#!/usr/bin/env bash
set -euo pipefail

echo "==== Activating conda ===="

source ~/miniconda3/etc/profile.d/conda.sh

echo "==== Creating rna-seq environment if missing ===="

if ! conda env list | grep -q "^rna-seq "; then
    conda create -y -n rna-seq python=3.11
fi

echo "==== Activating rna-seq environment ===="

conda activate rna-seq

echo "==== Installing fastp ===="

conda install -y -c bioconda -c conda-forge fastp

echo "==== Testing installation ===="

fastp --version

echo "==== Done ===="
