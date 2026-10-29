#!/usr/bin/env bash
set -euo pipefail

# End-to-end unattended dual RNA-seq pipeline driver.
# The script stitches the existing project scripts into one ordered workflow:
# raw/trimmed read QC, trimming, dual host/bacterial alignment, feature counting,
# DESeq2, result export, longitudinal host modelling, and pathway enrichment.

WORKDIR="${WORKDIR:-/home/lshpk18/OzanGundogdu_SOUK011275}"
ANALYSIS_DIR="${ANALYSIS_DIR:-$WORKDIR/Analysis}"
TRIM_DIR="${TRIM_DIR:-$ANALYSIS_DIR/trim_results}"
FASTQC_DIR="${FASTQC_DIR:-$ANALYSIS_DIR/fastqc_results}"
ALIGNMENT_DIR="${ALIGNMENT_DIR:-$ANALYSIS_DIR/Alignment}"
DE_DIR="${DE_DIR:-$ANALYSIS_DIR/DifferentialExpression}"
RUN_ID="${RUN_ID:-$(date +'%Y%m%d_%H%M%S')}"
LOG_DIR="${LOG_DIR:-$ANALYSIS_DIR/logs/complete_pipeline}"
LOG_FILE="$LOG_DIR/complete_dual_rnaseq_${RUN_ID}.log"
STATE_TSV="$LOG_DIR/complete_dual_rnaseq_state.tsv"

THREADS="${THREADS:-16}"
DESIGN="${DESIGN:-condition}"
CONTRAST="${CONTRAST:-}"
BATCH="${BATCH:-}"
GENE_SETS="${GENE_SETS:-}"
ORGANISM="${ORGANISM:-all}"
PADJ="${PADJ:-0.05}"
LFC="${LFC:-1}"
INPUT_DIR="${INPUT_DIR:-$DE_DIR}"
DESEQ2_OUT_DIR="${DESEQ2_OUT_DIR:-$INPUT_DIR/deseq2_results}"
EXPORT_DIR="${EXPORT_DIR:-$DESEQ2_OUT_DIR/exported_results}"
HOST_LONGITUDINAL_OUT_DIR="${HOST_LONGITUDINAL_OUT_DIR:-$DE_DIR/host_longitudinal_deseq2}"
HUMAN_PATHWAY_OUT_DIR="${HUMAN_PATHWAY_OUT_DIR:-$DE_DIR/pathway_enrichment/human}"
BACTERIAL_PATHWAY_OUT_DIR="${BACTERIAL_PATHWAY_OUT_DIR:-$DE_DIR/pathway_enrichment/bacteria}"
RAW_FASTQ_DIR="${RAW_FASTQ_DIR:-$WORKDIR}"
ALLOW_INCOMPLETE="${ALLOW_INCOMPLETE:-false}"
AUTO_SKIP_MISSING="${AUTO_SKIP_MISSING:-true}"
FORCE="${FORCE:-false}"
DRY_RUN="${DRY_RUN:-false}"

RUN_FASTQC="${RUN_FASTQC:-auto}"
RUN_TRIM="${RUN_TRIM:-auto}"
RUN_TRIM_MULTIQC="${RUN_TRIM_MULTIQC:-auto}"
RUN_ALIGNMENT_TO_DESEQ2="${RUN_ALIGNMENT_TO_DESEQ2:-true}"
RUN_EXPORT="${RUN_EXPORT:-true}"
RUN_HOST_LONGITUDINAL="${RUN_HOST_LONGITUDINAL:-true}"
RUN_HUMAN_PATHWAY="${RUN_HUMAN_PATHWAY:-true}"
RUN_BACTERIAL_PATHWAY="${RUN_BACTERIAL_PATHWAY:-true}"

usage() {
  cat <<'USAGE'
Usage:
  bash Analysis/run_complete_dual_rnaseq_pipeline.sh [options]

This is the non-interactive master driver for the complete host/bacterial
dual RNA-seq workflow. It is designed to be launched directly or through
Analysis/submit_complete_dual_rnaseq_pipeline_slurm.sh.

Options:
  --threads N                 Threads passed to child workflows [16]
  --design COLUMN             DESeq2 design column [condition]
  --contrast A,B,C            Optional DESeq2 contrast variable,numerator,denominator
  --batch COLUMN              Optional DESeq2 batch column
  --gene-sets PATH            Optional TERM<TAB>GENE table for DESeq2 enrichment
  --organism all|host|bacteria
  --padj VALUE                Adjusted p-value threshold for exports/pathways [0.05]
  --lfc VALUE                 Absolute log2FoldChange threshold [1]
  --input-dir PATH            Prepared matrix directory
  --deseq2-out-dir PATH       DESeq2 result directory
  --export-dir PATH           Exported DESeq2 result directory
  --allow-incomplete          Allow provisional output from incomplete sample sets
  --require-complete          Require every expected sample to be complete
  --strict                    Fail when optional upstream/pathway inputs are missing
  --force                     Re-run stages where child scripts support it
  --dry-run                   Validate and print planned commands without running them
  --skip-fastqc               Skip raw FASTQC dependency stage
  --skip-trim                 Skip fastp trimming stage
  --skip-trim-multiqc         Skip trimmed-read MultiQC stage
  --skip-alignment-deseq2     Skip alignment/count preparation/DESeq2 stage
  --skip-export               Skip DESeq2 export stage
  --skip-host-longitudinal    Skip host longitudinal DESeq2 stage
  --skip-human-pathway        Skip host pathway enrichment stage
  --skip-bacterial-pathway    Skip bacterial pathway enrichment stage
  -h, --help                  Show this help

Default behavior:
  Optional early stages run only when their inputs/scripts are present. Core
  alignment-to-DESeq2 and export stages run by default. Pathway stages run after
  export if their required result directories exist, otherwise they are skipped
  unless --strict is used.
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

abs_path() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s/%s\n' "$WORKDIR" "$path"
  fi
}

run_cmd() {
  log "Running: $*"
  if [[ "$DRY_RUN" == "true" ]]; then
    return 0
  fi
  "$@"
}

optional_stage_unavailable() {
  local stage="$1"
  local detail="$2"
  if [[ "$AUTO_SKIP_MISSING" == "true" ]]; then
    log "Skipping $stage: $detail"
    record_stage "$stage" skipped "$detail"
  else
    die "$stage cannot run: $detail"
  fi
}

should_run_auto_stage() {
  local mode="$1"
  case "$mode" in
    true|yes|1) return 0 ;;
    false|no|0) return 1 ;;
    auto) return 0 ;;
    *) die "Invalid stage mode: $mode" ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --threads) THREADS="${2:-}"; shift 2 ;;
    --design) DESIGN="${2:-}"; shift 2 ;;
    --contrast) CONTRAST="${2:-}"; shift 2 ;;
    --batch) BATCH="${2:-}"; shift 2 ;;
    --gene-sets) GENE_SETS="$(abs_path "${2:-}")"; shift 2 ;;
    --organism) ORGANISM="${2:-}"; shift 2 ;;
    --padj) PADJ="${2:-}"; shift 2 ;;
    --lfc) LFC="${2:-}"; shift 2 ;;
    --input-dir) INPUT_DIR="$(abs_path "${2:-}")"; shift 2 ;;
    --deseq2-out-dir) DESEQ2_OUT_DIR="$(abs_path "${2:-}")"; shift 2 ;;
    --export-dir) EXPORT_DIR="$(abs_path "${2:-}")"; shift 2 ;;
    --allow-incomplete) ALLOW_INCOMPLETE="true"; shift ;;
    --require-complete) ALLOW_INCOMPLETE="false"; shift ;;
    --strict) AUTO_SKIP_MISSING="false"; shift ;;
    --force) FORCE="true"; shift ;;
    --dry-run) DRY_RUN="true"; shift ;;
    --skip-fastqc) RUN_FASTQC="false"; shift ;;
    --skip-trim) RUN_TRIM="false"; shift ;;
    --skip-trim-multiqc) RUN_TRIM_MULTIQC="false"; shift ;;
    --skip-alignment-deseq2) RUN_ALIGNMENT_TO_DESEQ2="false"; shift ;;
    --skip-export) RUN_EXPORT="false"; shift ;;
    --skip-host-longitudinal) RUN_HOST_LONGITUDINAL="false"; shift ;;
    --skip-human-pathway) RUN_HUMAN_PATHWAY="false"; shift ;;
    --skip-bacterial-pathway) RUN_BACTERIAL_PATHWAY="false"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

case "$ORGANISM" in
  all|host|bacteria) ;;
  *) die "--organism must be one of: all, host, bacteria" ;;
esac
[[ "$THREADS" =~ ^[0-9]+$ ]] || die "--threads must be a positive integer"

mkdir -p "$LOG_DIR"
[[ -s "$STATE_TSV" ]] || printf 'timestamp\tstage\tstatus\tdetail\n' > "$STATE_TSV"

log "Complete dual RNA-seq pipeline"
log "Workdir: $WORKDIR"
log "Run ID: $RUN_ID"
log "Design: $DESIGN"
log "Organism: $ORGANISM"
log "Allow incomplete: $ALLOW_INCOMPLETE"

if should_run_auto_stage "$RUN_FASTQC"; then
  if [[ -x "$FASTQC_DIR/install_qc_dependencies.sh" ]]; then
    if ! stage_complete fastqc_dependencies || [[ "$FORCE" == "true" ]]; then
      record_stage fastqc_dependencies started "$FASTQC_DIR/install_qc_dependencies.sh"
      run_cmd bash "$FASTQC_DIR/install_qc_dependencies.sh"
      record_stage fastqc_dependencies complete "$FASTQC_DIR/install_qc_dependencies.sh"
    fi
  elif [[ "$RUN_FASTQC" != "auto" ]]; then
    optional_stage_unavailable fastqc_dependencies "script not found: $FASTQC_DIR/install_qc_dependencies.sh"
  fi
fi

if should_run_auto_stage "$RUN_TRIM"; then
  if [[ -x "$TRIM_DIR/trim_fastp.sh" ]]; then
    if ! stage_complete trimming || [[ "$FORCE" == "true" ]]; then
      record_stage trimming started "$TRIM_DIR/trim_fastp.sh"
      export FASTQ_DIR="$RAW_FASTQ_DIR"
      export THREADS
      run_cmd bash "$TRIM_DIR/trim_fastp.sh"
      record_stage trimming complete "$TRIM_DIR/trim_fastp.sh"
    fi
  elif [[ "$RUN_TRIM" != "auto" ]]; then
    optional_stage_unavailable trimming "script not found: $TRIM_DIR/trim_fastp.sh"
  fi
fi

if should_run_auto_stage "$RUN_TRIM_MULTIQC"; then
  if [[ -x "$TRIM_DIR/run_multiqc_trimmed.sh" ]]; then
    if ! stage_complete trim_multiqc || [[ "$FORCE" == "true" ]]; then
      record_stage trim_multiqc started "$TRIM_DIR/run_multiqc_trimmed.sh"
      run_cmd bash "$TRIM_DIR/run_multiqc_trimmed.sh"
      record_stage trim_multiqc complete "$TRIM_DIR/run_multiqc_trimmed.sh"
    fi
  elif [[ "$RUN_TRIM_MULTIQC" != "auto" ]]; then
    optional_stage_unavailable trim_multiqc "script not found: $TRIM_DIR/run_multiqc_trimmed.sh"
  fi
fi

if [[ "$RUN_ALIGNMENT_TO_DESEQ2" == "true" ]]; then
  [[ -x "$ANALYSIS_DIR/post_trim_to_deseq2_workflow.sh" ]] || die "Missing core workflow: $ANALYSIS_DIR/post_trim_to_deseq2_workflow.sh"
  args=(--threads "$THREADS" --design "$DESIGN" --organism "$ORGANISM" --input-dir "$INPUT_DIR" --deseq2-out-dir "$DESEQ2_OUT_DIR")
  [[ "$ALLOW_INCOMPLETE" == "true" ]] && args+=(--allow-incomplete)
  [[ "$FORCE" == "true" ]] && args+=(--force)
  [[ "$DRY_RUN" == "true" ]] && args+=(--dry-run)
  [[ -n "$CONTRAST" ]] && args+=(--contrast "$CONTRAST")
  [[ -n "$BATCH" ]] && args+=(--batch "$BATCH")
  [[ -n "$GENE_SETS" ]] && args+=(--gene-sets "$GENE_SETS")
  if ! stage_complete alignment_to_deseq2 || [[ "$FORCE" == "true" ]]; then
    record_stage alignment_to_deseq2 started "$ANALYSIS_DIR/post_trim_to_deseq2_workflow.sh"
    run_cmd bash "$ANALYSIS_DIR/post_trim_to_deseq2_workflow.sh" "${args[@]}"
    record_stage alignment_to_deseq2 complete "$DESEQ2_OUT_DIR"
  fi
fi

if [[ "$RUN_EXPORT" == "true" ]]; then
  [[ -x "$DE_DIR/export_deseq2_results.sh" ]] || die "Missing DESeq2 export wrapper: $DE_DIR/export_deseq2_results.sh"
  args=(--results-dir "$DESEQ2_OUT_DIR" --out-dir "$EXPORT_DIR" --padj "$PADJ" --lfc "$LFC" --skip-conda)
  [[ "$FORCE" == "true" ]] && args+=(--force)
  [[ "$DRY_RUN" == "true" ]] && args+=(--dry-run)
  if ! stage_complete export_deseq2 || [[ "$FORCE" == "true" ]]; then
    record_stage export_deseq2 started "$EXPORT_DIR"
    run_cmd bash "$DE_DIR/export_deseq2_results.sh" "${args[@]}"
    record_stage export_deseq2 complete "$EXPORT_DIR"
  fi
fi

if [[ "$RUN_HOST_LONGITUDINAL" == "true" ]]; then
  if [[ "$ORGANISM" == "all" || "$ORGANISM" == "host" ]]; then
    if [[ -x "$DE_DIR/run_host_longitudinal_deseq2.sh" && -s "$INPUT_DIR/matrices/host_counts.tsv" ]]; then
      args=(--counts "$INPUT_DIR/matrices/host_counts.tsv" --existing-metadata "$INPUT_DIR/metadata/metadata_for_counts.tsv" --out-dir "$HOST_LONGITUDINAL_OUT_DIR" --skip-conda)
      [[ "$FORCE" == "true" ]] && args+=(--force)
      [[ "$DRY_RUN" == "true" ]] && args+=(--dry-run)
      if ! stage_complete host_longitudinal || [[ "$FORCE" == "true" ]]; then
        record_stage host_longitudinal started "$HOST_LONGITUDINAL_OUT_DIR"
        run_cmd bash "$DE_DIR/run_host_longitudinal_deseq2.sh" "${args[@]}"
        record_stage host_longitudinal complete "$HOST_LONGITUDINAL_OUT_DIR"
      fi
    else
      optional_stage_unavailable host_longitudinal "host counts or wrapper not available"
    fi
  fi
fi

if [[ "$RUN_HUMAN_PATHWAY" == "true" ]]; then
  if [[ "$ORGANISM" == "all" || "$ORGANISM" == "host" ]]; then
    if [[ -x "$DE_DIR/human_pathway_enrichment/run_human_pathway_enrichment.sh" && -d "$EXPORT_DIR/significant_genes" && -d "$EXPORT_DIR/results_tsv" ]]; then
      args=(--sig-dir "$EXPORT_DIR/significant_genes" --results-dir "$EXPORT_DIR/results_tsv" --out-dir "$HUMAN_PATHWAY_OUT_DIR" --padj "$PADJ" --lfc "$LFC" --skip-conda)
      [[ "$FORCE" == "true" ]] && args+=(--force)
      [[ "$DRY_RUN" == "true" ]] && args+=(--dry-run)
      if ! stage_complete human_pathway || [[ "$FORCE" == "true" ]]; then
        record_stage human_pathway started "$HUMAN_PATHWAY_OUT_DIR"
        run_cmd bash "$DE_DIR/human_pathway_enrichment/run_human_pathway_enrichment.sh" "${args[@]}"
        record_stage human_pathway complete "$HUMAN_PATHWAY_OUT_DIR"
      fi
    else
      optional_stage_unavailable human_pathway "host significant/full result exports are not available"
    fi
  fi
fi

if [[ "$RUN_BACTERIAL_PATHWAY" == "true" ]]; then
  if [[ "$ORGANISM" == "all" || "$ORGANISM" == "bacteria" ]]; then
    if [[ -x "$DE_DIR/bacterial_pathway_enrichment/run_bacterial_pathway_enrichment.sh" && -d "$EXPORT_DIR/significant_genes" ]]; then
      args=(--sig-dir "$EXPORT_DIR/significant_genes" --out-dir "$BACTERIAL_PATHWAY_OUT_DIR" --padj "$PADJ" --lfc "$LFC" --skip-conda)
      [[ "$FORCE" == "true" ]] && args+=(--force)
      [[ "$DRY_RUN" == "true" ]] && args+=(--dry-run)
      if ! stage_complete bacterial_pathway || [[ "$FORCE" == "true" ]]; then
        record_stage bacterial_pathway started "$BACTERIAL_PATHWAY_OUT_DIR"
        run_cmd bash "$DE_DIR/bacterial_pathway_enrichment/run_bacterial_pathway_enrichment.sh" "${args[@]}"
        record_stage bacterial_pathway complete "$BACTERIAL_PATHWAY_OUT_DIR"
      fi
    else
      optional_stage_unavailable bacterial_pathway "bacterial significant result exports are not available"
    fi
  fi
fi

log "Complete dual RNA-seq pipeline finished."
