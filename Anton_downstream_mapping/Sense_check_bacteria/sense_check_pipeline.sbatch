#!/bin/bash
#SBATCH --job-name=sense_check
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Sense_check/logs/sense_check_%j.log
#SBATCH --error=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Sense_check/logs/sense_check_%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=lshpk18@lshtm.ac.uk
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=04:00:00
#SBATCH --chdir=/home/lshpk18/OzanGundogdu_SOUK011275

# Technical-replicate sense-check pipeline
# =========================================
# Purpose: validate sequencing run consistency by comparing Run1 vs Run2
#          within a single timepoint (4 samples each).
#
# The two groups are in reality the SAME biological samples sequenced across
# two technical runs. A volcano plot with minimal DE confirms run consistency.
#
# Steps:
#   1. Check BAM index files; index any missing ones
#   2. Check featureCounts output; recount if missing
#   3. Run DESeq2: ~ run  (Run1 vs Run2 within the chosen timepoint)
#   4. Generate PCA, sample-distance heatmap, and volcano plot
#
# Chosen timepoint: 0h (uninfected bacterial controls: B1_H1 … B4_H4)
#   Run1 (n=4): B1_H1_Run_1_S3, B2_H2_Run_1_S9, B3_H3_Run_1_S15, B4_H4_Run_1_S21
#   Run2 (n=4): B1_H1_Run_2_S27, B2_H2_Run_2_S33, B3_H3_Run_2_S39, B4_H4_Run_2_S45
#
# Usage:
#   sbatch /home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Sense_check/sense_check_pipeline.sbatch
#
# Environment overrides:
#   TIMEPOINT     Timepoint to analyse (default: 0h)
#   PADJ_CUTOFF   Adjusted p-value threshold (default: 0.05)
#   LFC_CUTOFF    Absolute log2FC threshold  (default: 1)
#   CONDA_ENV_FC  Conda env with samtools + featureCounts (default: dualrnaseq)
#   CONDA_ENV_R   Conda env with DESeq2 (default: dualrnaseq_deseq2)

set -euo pipefail

WORKDIR="${WORKDIR:-/home/lshpk18/OzanGundogdu_SOUK011275}"
BAM_DIR="${BAM_DIR:-$WORKDIR/Analysis/Anton_downstream_mapping/Bam_indexing/Bacteria/merged}"
GFF="${GFF:-$WORKDIR/Analysis/Alignment/references/AL111168.1.gff3}"
FC_DIR="${FC_DIR:-$WORKDIR/Analysis/Anton_downstream_mapping/FeatureCounts/FeatureCounts_bacteria}"
FC_OUT="$FC_DIR/featureCounts_bacteria.txt"
OUT_DIR="${OUT_DIR:-$WORKDIR/Analysis/Anton_downstream_mapping/Sense_check}"
DESEQ2_SCRIPT="$WORKDIR/Analysis/Anton_downstream_mapping/Sense_check/deseq2_sense_check.R"
TIMEPOINT="${TIMEPOINT:-0h}"
PADJ_CUTOFF="${PADJ_CUTOFF:-0.05}"
LFC_CUTOFF="${LFC_CUTOFF:-1}"
THREADS="${SLURM_CPUS_PER_TASK:-8}"
CONDA_BASE="/home/lshpk18/miniconda3"
CONDA_FC="${CONDA_ENV_FC:-dualrnaseq}"
CONDA_R="${CONDA_ENV_R:-dualrnaseq_deseq2}"

mkdir -p "$OUT_DIR/logs" "$OUT_DIR/results" "$OUT_DIR/figures" "$OUT_DIR/objects"

echo "=============================================="
echo "Technical-Replicate Sense-Check Pipeline"
echo "=============================================="
echo "Job ID      : ${SLURM_JOB_ID:-manual}"
echo "Node        : $(hostname)"
echo "CPUs        : $THREADS"
echo "Memory      : ${SLURM_MEM_M:-unknown} MB"
echo "Start time  : $(date)"
echo "Timepoint   : $TIMEPOINT  (Run1 vs Run2, 4 samples each)"
echo "BAM dir     : $BAM_DIR"
echo "GFF         : $GFF"
echo "FC output   : $FC_OUT"
echo "DESeq2 out  : $OUT_DIR"
echo "padj cutoff : $PADJ_CUTOFF"
echo "LFC cutoff  : $LFC_CUTOFF"
echo ""

[[ -f "$CONDA_BASE/bin/activate" ]] || { echo "ERROR: conda not found at $CONDA_BASE" >&2; exit 1; }

# ---- Step 1: BAM index check --------------------------------------------
echo "[$(date '+%F %T')] STEP 1: Checking BAM index files..."

shopt -s nullglob
bams=( "$BAM_DIR"/*.bacteria.merged.bam )
shopt -u nullglob

if [[ ${#bams[@]} -eq 0 ]]; then
  echo "ERROR: No merged BAMs found in $BAM_DIR" >&2; exit 1
fi
echo "[$(date '+%F %T')] Found ${#bams[@]} merged BAMs."

missing_bai=()
for bam in "${bams[@]}"; do
  [[ -f "${bam}.bai" ]] || missing_bai+=("$bam")
done

if [[ ${#missing_bai[@]} -gt 0 ]]; then
  echo "[$(date '+%F %T')] Indexing ${#missing_bai[@]} un-indexed BAM(s)..."
  source "$CONDA_BASE/bin/activate" "$CONDA_FC"
  printf '%s\n' "${missing_bai[@]}" | xargs -P4 -I{} samtools index -@ 1 {}
  conda deactivate 2>/dev/null || true
  echo "[$(date '+%F %T')] BAM indexing complete."
else
  echo "[$(date '+%F %T')] All ${#bams[@]} BAMs already indexed. Skipping."
fi

# ---- Step 2: featureCounts check ----------------------------------------
echo "[$(date '+%F %T')] STEP 2: Checking featureCounts output..."

if [[ -f "$FC_OUT" ]]; then
  n_data_cols=$(awk 'NR==2{print NF-6; exit}' "$FC_OUT")
  echo "[$(date '+%F %T')] featureCounts already complete ($n_data_cols sample columns). Skipping."
else
  echo "[$(date '+%F %T')] Running featureCounts on all ${#bams[@]} BAMs..."
  [[ -f "$GFF" ]] || { echo "ERROR: GFF not found: $GFF" >&2; exit 1; }
  mkdir -p "$FC_DIR"
  source "$CONDA_BASE/bin/activate" "$CONDA_FC"
  featureCounts \
    -T "$THREADS" \
    -p -B -C \
    -F GTF -t gene -g ID \
    -a "$GFF" \
    -o "$FC_OUT" \
    "${bams[@]}"
  conda deactivate 2>/dev/null || true
  echo "[$(date '+%F %T')] featureCounts complete."
fi

# ---- Step 3: DESeq2 sense-check -----------------------------------------
echo "[$(date '+%F %T')] STEP 3: DESeq2 — ${TIMEPOINT} Run1 (n=4) vs Run2 (n=4)..."

[[ -f "$DESEQ2_SCRIPT" ]] || { echo "ERROR: R script not found: $DESEQ2_SCRIPT" >&2; exit 1; }
[[ -f "$FC_OUT" ]]        || { echo "ERROR: featureCounts output missing: $FC_OUT" >&2; exit 1; }

source "$CONDA_BASE/bin/activate" "$CONDA_R"

export COUNTS_FILE="$FC_OUT"
export OUT_DIR
export TIMEPOINT
export PADJ_CUTOFF
export LFC_CUTOFF

Rscript "$DESEQ2_SCRIPT"

echo ""
echo "=============================================="
echo "Sense-check complete : $(date)"
echo "Results  : $OUT_DIR/results/"
echo "Figures  : $OUT_DIR/figures/"
echo "Objects  : $OUT_DIR/objects/"
echo "Volcano  : $OUT_DIR/figures/${TIMEPOINT}_Run1_vs_Run2_volcano.pdf"
echo "=============================================="
