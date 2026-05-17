#!/usr/bin/env bash
set -euo pipefail

# Master Slurm submission wrapper for the current dual RNA-seq workflow.
# This script submits the maintained sbatch entry points and keeps historical
# alignment-stage commands available through one consistent interface.

WORKDIR="${WORKDIR:-/home/lshpk18/OzanGundogdu_SOUK011275}"
STAGE="${STAGE:-post-trim-to-deseq2}"
SAMPLE="${SAMPLE:-}"
SAMPLE_SHEET="${SAMPLE_SHEET:-}"
INPUT_DIR="${INPUT_DIR:-$WORKDIR/Analysis/DifferentialExpression}"
DESEQ2_OUT_DIR="${DESEQ2_OUT_DIR:-$INPUT_DIR/deseq2_results}"
EXPORT_OUT_DIR="${EXPORT_OUT_DIR:-$DESEQ2_OUT_DIR/exported_results}"
DESIGN="${DESIGN:-condition}"
CONTRAST="${CONTRAST:-}"
BATCH="${BATCH:-}"
GENE_SETS="${GENE_SETS:-}"
ORGANISM="${ORGANISM:-all}"
PADJ="${PADJ:-0.05}"
LFC="${LFC:-1}"
ALLOW_INCOMPLETE="${ALLOW_INCOMPLETE:-false}"
FORCE="${FORCE:-false}"
DRY_RUN="${DRY_RUN:-false}"
SKIP_DESEQ2="${SKIP_DESEQ2:-false}"
CONDA_ENV="${CONDA_ENV:-dualrnaseq}"
DESEQ2_CONDA_ENV="${DESEQ2_CONDA_ENV:-dualrnaseq_deseq2}"
THREADS="${THREADS:-16}"
SUBMIT="true"

usage() {
  cat <<'USAGE'
Usage:
  bash Analysis/Alignment/submit_dual_rnaseq_slurm.sh [options]

Stages:
  refs                 Submit reference validation
  index                Submit STAR genome indexing
  align                Submit STAR alignment
  counts               Submit featureCounts
  all                  Submit index, alignment, and counts via dual_rnaseq_workflow.sbatch
  post-alignment       Submit post_alignment_analysis.sbatch
  bam-qc               Submit bam_qc.sbatch
  alignment-multiqc    Submit run_multiqc_alignment.sbatch
  prepare-expression   Submit post_trim_to_deseq2_workflow.sbatch with --skip-deseq2
  deseq2               Submit DifferentialExpression/deseq2_analysis.sbatch
  export-deseq2        Submit DifferentialExpression/export_deseq2_results.sbatch
  post-trim-to-deseq2  Submit the full post-trimming wrapper

Options:
  --stage NAME             Stage to submit (default: post-trim-to-deseq2)
  --sample SAMPLE          Optional sample for alignment
  --sample-sheet PATH      Optional sample sheet
  --input-dir PATH         Prepared expression input directory
  --deseq2-out-dir PATH    DESeq2 output directory
  --export-out-dir PATH    Exported tables output directory
  --design COLUMN          DESeq2 design column
  --contrast A,B,C         Contrast as variable,numerator,denominator
  --batch COLUMN           Optional DESeq2 batch covariate
  --gene-sets PATH         Optional TERM<TAB>GENE pathway table
  --organism all|host|bacteria
  --padj VALUE             Adjusted p-value threshold for exported tables
  --lfc VALUE              Absolute log2FoldChange threshold for exported tables
  --allow-incomplete       Allow provisional post-alignment/DESeq2 output
  --force                  Re-run stages where supported
  --dry-run                Submit a dry-run job where supported
  --skip-deseq2            Stop full wrapper after prepared matrices
  --no-submit              Print sbatch command only
  -h, --help               Show this help

Examples:
  bash Analysis/Alignment/submit_dual_rnaseq_slurm.sh --stage align
  bash Analysis/Alignment/submit_dual_rnaseq_slurm.sh --stage post-alignment --allow-incomplete
  bash Analysis/Alignment/submit_dual_rnaseq_slurm.sh --stage alignment-multiqc
  bash Analysis/Alignment/submit_dual_rnaseq_slurm.sh --stage deseq2 --input-dir "Analysis/DifferentialExpression/smoke test" --design timepoint
  bash Analysis/Alignment/submit_dual_rnaseq_slurm.sh --stage export-deseq2 --deseq2-out-dir "Analysis/DifferentialExpression/smoke test/deseq2_results"
  bash Analysis/Alignment/submit_dual_rnaseq_slurm.sh --stage post-trim-to-deseq2 --allow-incomplete --input-dir "Analysis/DifferentialExpression/smoke test" --design timepoint
USAGE
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

abs_path() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s/%s\n' "$WORKDIR" "$path"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stage)
      STAGE="${2:-}"
      shift 2
      ;;
    --sample)
      SAMPLE="${2:-}"
      shift 2
      ;;
    --sample-sheet)
      SAMPLE_SHEET="$(abs_path "${2:-}")"
      shift 2
      ;;
    --input-dir)
      INPUT_DIR="$(abs_path "${2:-}")"
      DESEQ2_OUT_DIR="$INPUT_DIR/deseq2_results"
      EXPORT_OUT_DIR="$DESEQ2_OUT_DIR/exported_results"
      shift 2
      ;;
    --deseq2-out-dir)
      DESEQ2_OUT_DIR="$(abs_path "${2:-}")"
      EXPORT_OUT_DIR="$DESEQ2_OUT_DIR/exported_results"
      shift 2
      ;;
    --export-out-dir)
      EXPORT_OUT_DIR="$(abs_path "${2:-}")"
      shift 2
      ;;
    --design)
      DESIGN="${2:-}"
      shift 2
      ;;
    --contrast)
      CONTRAST="${2:-}"
      shift 2
      ;;
    --batch)
      BATCH="${2:-}"
      shift 2
      ;;
    --gene-sets)
      GENE_SETS="$(abs_path "${2:-}")"
      shift 2
      ;;
    --organism)
      ORGANISM="${2:-}"
      shift 2
      ;;
    --padj)
      PADJ="${2:-}"
      shift 2
      ;;
    --lfc)
      LFC="${2:-}"
      shift 2
      ;;
    --allow-incomplete)
      ALLOW_INCOMPLETE="true"
      shift
      ;;
    --force)
      FORCE="true"
      shift
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    --skip-deseq2)
      SKIP_DESEQ2="true"
      shift
      ;;
    --no-submit)
      SUBMIT="false"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

case "$STAGE" in
  refs|index|align|counts|all)
    SBATCH_SCRIPT="$WORKDIR/Analysis/Alignment/dual_rnaseq_workflow.sbatch"
    EXPORTS=("STEP=$STAGE" "FORCE=$FORCE" "DRY_RUN=$DRY_RUN" "CONDA_ENV=$CONDA_ENV")
    [[ -n "$SAMPLE" ]] && EXPORTS+=("SAMPLE=$SAMPLE")
    [[ -n "$SAMPLE_SHEET" ]] && EXPORTS+=("SAMPLE_SHEET=$SAMPLE_SHEET")
    ;;
  post-alignment)
    SBATCH_SCRIPT="$WORKDIR/Analysis/Alignment/post_alignment_analysis.sbatch"
    EXPORTS=("ALLOW_INCOMPLETE=$ALLOW_INCOMPLETE" "FORCE=$FORCE" "DRY_RUN=$DRY_RUN" "CONDA_ENV=$CONDA_ENV" "THREADS=$THREADS")
    ;;
  bam-qc)
    SBATCH_SCRIPT="$WORKDIR/Analysis/Alignment/bam_qc.sbatch"
    EXPORTS=("TARGET=$ORGANISM" "CONDA_ENV=$CONDA_ENV" "THREADS=$THREADS")
    ;;
  alignment-multiqc)
    SBATCH_SCRIPT="$WORKDIR/Analysis/Alignment/run_multiqc_alignment.sbatch"
    EXPORTS=("FORCE=$FORCE" "DRY_RUN=$DRY_RUN" "CONDA_ENV=$CONDA_ENV")
    ;;
  prepare-expression)
    SBATCH_SCRIPT="$WORKDIR/Analysis/post_trim_to_deseq2_workflow.sbatch"
    EXPORTS=("ALLOW_INCOMPLETE=$ALLOW_INCOMPLETE" "INPUT_DIR=$INPUT_DIR" "DESEQ2_OUT_DIR=$DESEQ2_OUT_DIR" "DESIGN=$DESIGN" "ORGANISM=$ORGANISM" "FORCE=$FORCE" "DRY_RUN=$DRY_RUN" "SKIP_DESEQ2=true" "THREADS=$THREADS")
    [[ -n "$CONTRAST" ]] && EXPORTS+=("CONTRAST=$CONTRAST")
    ;;
  deseq2)
    SBATCH_SCRIPT="$WORKDIR/Analysis/DifferentialExpression/deseq2_analysis.sbatch"
    EXPORTS=("INPUT_DIR=$INPUT_DIR" "OUT_DIR=$DESEQ2_OUT_DIR" "DESIGN=$DESIGN" "ORGANISM=$ORGANISM" "CONDA_ENV=$DESEQ2_CONDA_ENV" "FORCE=$FORCE" "DRY_RUN=$DRY_RUN")
    [[ -n "$CONTRAST" ]] && EXPORTS+=("CONTRAST=$CONTRAST")
    [[ -n "$BATCH" ]] && EXPORTS+=("BATCH=$BATCH")
    [[ -n "$GENE_SETS" ]] && EXPORTS+=("GENE_SETS=$GENE_SETS")
    ;;
  export-deseq2)
    SBATCH_SCRIPT="$WORKDIR/Analysis/DifferentialExpression/export_deseq2_results.sbatch"
    EXPORTS=("RESULTS_DIR=$DESEQ2_OUT_DIR" "OUT_DIR=$EXPORT_OUT_DIR" "PADJ=$PADJ" "LFC=$LFC" "CONDA_ENV=$DESEQ2_CONDA_ENV" "FORCE=$FORCE" "DRY_RUN=$DRY_RUN")
    ;;
  post-trim-to-deseq2)
    SBATCH_SCRIPT="$WORKDIR/Analysis/post_trim_to_deseq2_workflow.sbatch"
    EXPORTS=("ALLOW_INCOMPLETE=$ALLOW_INCOMPLETE" "INPUT_DIR=$INPUT_DIR" "DESEQ2_OUT_DIR=$DESEQ2_OUT_DIR" "DESIGN=$DESIGN" "ORGANISM=$ORGANISM" "FORCE=$FORCE" "DRY_RUN=$DRY_RUN" "SKIP_DESEQ2=$SKIP_DESEQ2" "THREADS=$THREADS")
    [[ -n "$CONTRAST" ]] && EXPORTS+=("CONTRAST=$CONTRAST")
    ;;
  *)
    die "Unknown stage: $STAGE"
    ;;
esac

[[ -f "$SBATCH_SCRIPT" ]] || die "Slurm script not found: $SBATCH_SCRIPT"
mkdir -p "$WORKDIR/Analysis/logs/slurm" "$WORKDIR/Analysis/Alignment/logs/slurm" "$WORKDIR/Analysis/DifferentialExpression/logs/slurm"

CMD=(env "${EXPORTS[@]}" sbatch --export=ALL "$SBATCH_SCRIPT")

echo "Stage: $STAGE"
echo "Script: $SBATCH_SCRIPT"
echo "Environment:"
printf '  %s\n' "${EXPORTS[@]}"
printf 'Command:'
printf ' %q' "${CMD[@]}"
printf '\n'

if [[ "$SUBMIT" == "true" ]]; then
  "${CMD[@]}"
else
  echo "No submission performed because --no-submit was set."
fi
