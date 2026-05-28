#!/usr/bin/env bash
set -euo pipefail

# End-to-end post-trimming workflow. Existing completed stages are detected and
# skipped unless --force is used. This script does not redo raw FASTQ QC or
# trimming; it starts from compressed paired-end trimmed FASTQ files.

WORKDIR="${WORKDIR:-/home/lshpk18/OzanGundogdu_SOUK011275}"
ALIGNMENT_DIR="${ALIGNMENT_DIR:-$WORKDIR/Analysis/Alignment}"
DE_DIR="${DE_DIR:-$WORKDIR/Analysis/DifferentialExpression}"
CONFIG_FILE="${CONFIG_FILE:-$ALIGNMENT_DIR/pipeline_config.sh}"
RUN_ID="${RUN_ID:-$(date +'%Y%m%d_%H%M%S')}"
LOG_DIR="${LOG_DIR:-$WORKDIR/Analysis/logs}"
LOG_FILE="$LOG_DIR/post_trim_to_deseq2_${RUN_ID}.log"
STATE_TSV="$LOG_DIR/post_trim_to_deseq2_state.tsv"
THREADS="${THREADS:-16}"
INPUT_DIR="${INPUT_DIR:-$DE_DIR}"
DESEQ2_OUT_DIR="${DESEQ2_OUT_DIR:-$INPUT_DIR/deseq2_results}"
DESIGN="${DESIGN:-condition}"
CONTRAST="${CONTRAST:-}"
BATCH="${BATCH:-}"
GENE_SETS="${GENE_SETS:-}"
ORGANISM="${ORGANISM:-all}"
ALLOW_INCOMPLETE="${ALLOW_INCOMPLETE:-false}"
FORCE="false"
DRY_RUN="false"
SKIP_DESEQ2="false"

usage() {
  cat <<'USAGE'
Usage:
  bash Analysis/post_trim_to_deseq2_workflow.sh [options]

Options:
  --allow-incomplete       Allow provisional downstream and DESeq2 outputs
  --design COLUMN          Metadata design column for DESeq2
  --contrast A,B,C         Contrast as variable,numerator,denominator
  --batch COLUMN           Optional batch covariate for DESeq2
  --gene-sets PATH         Optional TERM<TAB>GENE pathway table for DESeq2
  --organism all|host|bacteria
  --threads N              Threads for post-alignment featureCounts/QC
  --input-dir PATH         Prepared matrix directory for DESeq2
  --deseq2-out-dir PATH    DESeq2 output directory
  --skip-deseq2            Stop after prepared count matrices
  --force                  Re-run stages where child scripts support it
  --dry-run                Validate and print planned actions
  -h, --help               Show this help

Stages:
  1. STAR reference validation/indexing
  2. STAR alignment for unaligned samples
  3. featureCounts and alignment QC through post_alignment_analysis.sh
  4. count matrix/metadata preparation
  5. DESeq2 visualisation, differential expression, and enrichment
USAGE
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

record_stage() {
  printf '%s\t%s\t%s\t%s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$1" "$2" "$3" >> "$STATE_TSV"
}

stage_complete() {
  local stage="$1"
  awk -F '\t' -v stage="$stage" '$2 == stage && $3 == "complete" {found=1} END {exit !found}' "$STATE_TSV"
}

run_cmd() {
  log "Running: $*"
  if [[ "$DRY_RUN" == "true" ]]; then
    return 0
  fi
  "$@"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-incomplete)
      ALLOW_INCOMPLETE="true"
      shift
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
      GENE_SETS="${2:-}"
      shift 2
      ;;
    --organism)
      ORGANISM="${2:-}"
      shift 2
      ;;
    --threads)
      THREADS="${2:-}"
      shift 2
      ;;
    --input-dir)
      INPUT_DIR="${2:-}"
      shift 2
      ;;
    --deseq2-out-dir)
      DESEQ2_OUT_DIR="${2:-}"
      shift 2
      ;;
    --skip-deseq2)
      SKIP_DESEQ2="true"
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
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

mkdir -p "$LOG_DIR"
[[ -s "$STATE_TSV" ]] || printf 'timestamp\tstage\tstatus\tdetail\n' > "$STATE_TSV"
[[ -f "$CONFIG_FILE" ]] || die "Config file not found: $CONFIG_FILE"
source "$CONFIG_FILE"

log "Post-trimming to DESeq2 workflow"
log "Workdir: $WORKDIR"
log "Run ID: $RUN_ID"
log "Allow incomplete: $ALLOW_INCOMPLETE"

ALIGN_ARGS=(--step index)
if [[ "$FORCE" == "true" ]]; then ALIGN_ARGS+=(--force); fi
if [[ "$DRY_RUN" == "true" ]]; then ALIGN_ARGS+=(--dry-run); fi
if ! stage_complete star_index || [[ "$FORCE" == "true" ]]; then
  record_stage star_index started "$ALIGNMENT_DIR/star_index"
  run_cmd bash "$ALIGNMENT_DIR/dual_rnaseq_workflow.sh" "${ALIGN_ARGS[@]}"
  record_stage star_index complete "$ALIGNMENT_DIR/star_index"
else
  log "STAR index stage already complete. Skipping."
fi

ALIGN_ARGS=(--step align)
if [[ "$FORCE" == "true" ]]; then ALIGN_ARGS+=(--force); fi
if [[ "$DRY_RUN" == "true" ]]; then ALIGN_ARGS+=(--dry-run); fi
if ! stage_complete star_align || [[ "$FORCE" == "true" ]]; then
  record_stage star_align started "$BAM_DIR"
  run_cmd bash "$ALIGNMENT_DIR/dual_rnaseq_workflow.sh" "${ALIGN_ARGS[@]}"
  record_stage star_align complete "$BAM_DIR"
else
  log "STAR alignment stage already complete. Skipping."
fi

POST_ARGS=(--threads "$THREADS")
if [[ "$ALLOW_INCOMPLETE" == "true" ]]; then POST_ARGS+=(--allow-incomplete); else POST_ARGS+=(--require-complete); fi
if [[ "$FORCE" == "true" ]]; then POST_ARGS+=(--force); fi
if [[ "$DRY_RUN" == "true" ]]; then POST_ARGS+=(--dry-run); fi
if ! stage_complete post_alignment || [[ "$FORCE" == "true" ]]; then
  record_stage post_alignment started "$ALIGNMENT_DIR/post_alignment_analysis"
  run_cmd bash "$ALIGNMENT_DIR/post_alignment_analysis.sh" "${POST_ARGS[@]}"
  record_stage post_alignment complete "$ALIGNMENT_DIR/post_alignment_analysis"
else
  log "Post-alignment analysis stage already complete. Skipping."
fi

MULTIQC_ARGS=()
if [[ "$FORCE" == "true" ]]; then MULTIQC_ARGS+=(--force); fi
if [[ "$DRY_RUN" == "true" ]]; then MULTIQC_ARGS+=(--dry-run); fi
if [[ -f "$ALIGNMENT_DIR/run_multiqc_alignment.sh" ]]; then
  if ! stage_complete alignment_multiqc || [[ "$FORCE" == "true" ]]; then
    record_stage alignment_multiqc started "$ALIGNMENT_DIR/multiqc"
    run_cmd bash "$ALIGNMENT_DIR/run_multiqc_alignment.sh" "${MULTIQC_ARGS[@]}"
    record_stage alignment_multiqc complete "$ALIGNMENT_DIR/multiqc"
  else
    log "Alignment MultiQC stage already complete. Skipping."
  fi
fi

PREP_ARGS=()
if [[ "$ALLOW_INCOMPLETE" == "true" ]]; then PREP_ARGS+=(--allow-incomplete); fi
if [[ "$FORCE" == "true" ]]; then PREP_ARGS+=(--force); fi
if [[ "$DRY_RUN" == "true" ]]; then PREP_ARGS+=(--dry-run); fi
if ! stage_complete prepare_expression || [[ "$FORCE" == "true" ]]; then
  record_stage prepare_expression started "$INPUT_DIR"
  export OUT_DIR="$INPUT_DIR"
  run_cmd "$DE_DIR/prepare_downstream_expression.sh" "${PREP_ARGS[@]}"
  record_stage prepare_expression complete "$INPUT_DIR"
else
  log "Prepared expression input stage already complete. Skipping."
fi

if [[ "$SKIP_DESEQ2" == "true" ]]; then
  log "Skipping DESeq2 stage by request."
  exit 0
fi

DESEQ2_ARGS=(--input-dir "$INPUT_DIR" --out-dir "$DESEQ2_OUT_DIR" --organism "$ORGANISM" --design "$DESIGN")
if [[ -n "$CONTRAST" ]]; then DESEQ2_ARGS+=(--contrast "$CONTRAST"); fi
if [[ -n "$BATCH" ]]; then DESEQ2_ARGS+=(--batch "$BATCH"); fi
if [[ -n "$GENE_SETS" ]]; then DESEQ2_ARGS+=(--gene-sets "$GENE_SETS"); fi
if [[ "$FORCE" == "true" ]]; then DESEQ2_ARGS+=(--force); fi
if [[ "$DRY_RUN" == "true" ]]; then DESEQ2_ARGS+=(--dry-run); fi
if ! stage_complete deseq2 || [[ "$FORCE" == "true" ]]; then
  record_stage deseq2 started "$DESEQ2_OUT_DIR"
  run_cmd bash "$DE_DIR/run_deseq2_analysis.sh" "${DESEQ2_ARGS[@]}"
  record_stage deseq2 complete "$DESEQ2_OUT_DIR"
else
  log "DESeq2 stage already complete. Skipping."
fi

log "Workflow finished."
