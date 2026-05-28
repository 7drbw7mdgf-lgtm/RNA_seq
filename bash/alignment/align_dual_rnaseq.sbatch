#!/bin/bash
#SBATCH --job-name=dualRNA_STAR
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/logs/slurm/align_%A_%a.out
#SBATCH --error=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/logs/slurm/align_%A_%a.err
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=16
#SBATCH --mem=120G
#SBATCH --array=1-100%10

set -euo pipefail

WORKDIR="/home/lshpk18/OzanGundogdu_SOUK011275"
cd "$WORKDIR"
mkdir -p "$WORKDIR/Analysis/Alignment/logs/slurm"

# If you need a conda environment, activate it here.
# source /home/lshpk18/miniconda3/bin/activate rna-seq

SAMPLE_LIST="$WORKDIR/Analysis/Alignment/sample_names.txt"
RAW_DIR="$WORKDIR/Analysis/trim_results"

if [[ ! -f "$SAMPLE_LIST" ]]; then
  ls "$RAW_DIR"/*_R1*_trimmed.fastq.gz | sed -E 's@.*/@@' | sed -E 's/_R1(_[0-9A-Za-z]+)?_trimmed\.fastq\.gz$//' | sort -u > "$SAMPLE_LIST"
fi

SAMPLE_NAME=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLE_LIST")
if [[ -z "$SAMPLE_NAME" ]]; then
  echo "No sample found for SLURM_ARRAY_TASK_ID=$SLURM_ARRAY_TASK_ID" >&2
  exit 1
fi

bash Analysis/Alignment/dual_rnaseq_workflow.sh --step align --sample "$SAMPLE_NAME"
