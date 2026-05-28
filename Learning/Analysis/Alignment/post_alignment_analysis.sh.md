# Annotated Script

**Original file:** `Analysis/Alignment/post_alignment_analysis.sh`

Related lines are grouped into annotated blocks so each explanation covers a complete piece of workflow logic.

## Lines 1-2

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Script startup. This block selects bash as the interpreter and enables stricter error handling so failures, unset variables, and broken pipelines are caught early.</span>

```bash
#!/usr/bin/env bash
set -euo pipefail
```

## Lines 4-18

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
WORKDIR="${WORKDIR:-/home/lshpk18/OzanGundogdu_SOUK011275}"
ALIGNMENT_DIR="${ALIGNMENT_DIR:-$WORKDIR/Analysis/Alignment}"
SAMPLE_LIST="${SAMPLE_LIST:-$ALIGNMENT_DIR/sample_names.txt}"
BAM_DIR="${BAM_DIR:-$ALIGNMENT_DIR/bam}"
HOST_BAM_DIR="${HOST_BAM_DIR:-$BAM_DIR/host}"
BACTERIA_BAM_DIR="${BACTERIA_BAM_DIR:-$BAM_DIR/bacteria}"
OUT_DIR="${OUT_DIR:-$ALIGNMENT_DIR/post_alignment_analysis}"
WORKFLOW_SCRIPT="${WORKFLOW_SCRIPT:-$ALIGNMENT_DIR/dual_rnaseq_workflow.sh}"
QC_SCRIPT="${QC_SCRIPT:-$ALIGNMENT_DIR/Alligment_QC}"
QC_OUT_DIR="${QC_OUT_DIR:-$ALIGNMENT_DIR/alignment_QC}"
COUNT_DIR="${COUNT_DIR:-$ALIGNMENT_DIR/counts}"
HOST_COUNT_FILE="${HOST_COUNT_FILE:-$COUNT_DIR/host/featureCounts_host.txt}"
BACTERIA_COUNT_FILE="${BACTERIA_COUNT_FILE:-$COUNT_DIR/bacteria/featureCounts_bacteria.txt}"
THREADS="${THREADS:-16}"
CONDA_ENV="${CONDA_ENV:-dualrnaseq}"
```

## Lines 20-25

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
RUN_COUNTS="true"
RUN_QC="true"
ALLOW_INCOMPLETE="false"
FORCE="false"
DRY_RUN="false"
SKIP_CONDA="false"
```

## Lines 27-56

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Multi-line message. This here-document prints a longer help or completion message without needing a separate echo command for every line.</span>

```bash
usage() {
  cat <<'USAGE'
Usage:
  bash Analysis/Alignment/post_alignment_analysis.sh [options]

Purpose:
  Run the standard post-alignment analysis for the dual RNA-seq project:
    1. Check host and bacterial BAM/index completion for every sample.
    2. Create sample metadata parsed from sample_names.txt.
    3. Read existing post-alignment outputs and skip completed stages.
    4. Run featureCounts through dual_rnaseq_workflow.sh --step counts when needed.
    5. Run alignment QC through Analysis/Alignment/Alligment_QC when needed.

Options:
  --skip-counts          Do not run featureCounts.
  --skip-qc              Do not run alignment QC.
  --allow-incomplete     Continue even if some samples are not fully aligned.
  --force                Re-run count/QC outputs where supported by child scripts.
  --dry-run              Print what would run, but do not run counts or QC.
  --threads N            Threads to pass to child scripts (default: 16).
  --out-dir PATH         Report/metadata output directory.
  --skip-conda           Do not activate the default conda environment.
  -h, --help             Show this help.

Environment overrides:
  WORKDIR, ALIGNMENT_DIR, SAMPLE_LIST, BAM_DIR, OUT_DIR, WORKFLOW_SCRIPT,
  QC_SCRIPT, QC_OUT_DIR, COUNT_DIR, HOST_COUNT_FILE, BACTERIA_COUNT_FILE,
  THREADS, CONDA_ENV
USAGE
}
```

## Lines 58-61

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Error helper. This small function prints a clear error message to standard error and exits, keeping failure handling consistent throughout the script.</span>

```bash
die() {
  echo "ERROR: $*" >&2
  exit 1
}
```

## Lines 63-65

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Reusable function. This block defines a named helper so related checks, messages, or workflow steps can be called consistently elsewhere in the script.</span>

```bash
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}
```

## Lines 67-73

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Reusable function. This block defines a named helper so related checks, messages, or workflow steps can be called consistently elsewhere in the script.</span>

```bash
run_cmd() {
  log "Running: $*"
  if [[ "$DRY_RUN" == "true" ]]; then
    return 0
  fi
  "$@"
}
```

## Lines 75-117

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Command-line option parsing. This loop reads user-supplied arguments, stores option values, handles help requests, and rejects unknown flags before the main workflow runs.</span>

```bash
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-counts)
      RUN_COUNTS="false"
      shift
      ;;
    --skip-qc)
      RUN_QC="false"
      shift
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
    --threads)
      THREADS="${2:-}"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    --skip-conda)
      SKIP_CONDA="true"
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
```

## Lines 119-122

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Workflow step. These related commands work together as one small unit in the script, preparing inputs, checking state, or running part of the analysis.</span>

```bash
[[ -f "$SAMPLE_LIST" ]] || die "Sample list not found: $SAMPLE_LIST"
[[ -f "$WORKFLOW_SCRIPT" ]] || die "Workflow script not found: $WORKFLOW_SCRIPT"
[[ -f "$QC_SCRIPT" ]] || die "QC script not found: $QC_SCRIPT"
[[ "$THREADS" =~ ^[0-9]+$ ]] || die "--threads must be a positive integer"
```

## Lines 124-131

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Environment activation. This loads the chosen conda environment into the current shell so the tools installed there are available on PATH.</span>

```bash
if [[ "$SKIP_CONDA" != "true" && -n "$CONDA_ENV" ]]; then
  if [[ -f /home/lshpk18/miniconda3/bin/activate ]]; then
    log "Activating conda environment: $CONDA_ENV"
    source /home/lshpk18/miniconda3/bin/activate "$CONDA_ENV"
  else
    log "Conda activate script not found; assuming tools are already in PATH."
  fi
fi
```

## Line 133

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
export THREADS CONDA_ENV
```

## Lines 135-145

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Output preparation. This creates the directories needed by later commands, using `-p` where appropriate so reruns do not fail if folders already exist.</span>

```bash
mkdir -p "$OUT_DIR"
COMPLETION_TSV="$OUT_DIR/alignment_completion.tsv"
SUMMARY_TXT="$OUT_DIR/post_alignment_summary.txt"
METADATA_TSV="$OUT_DIR/sample_metadata.tsv"
STATE_TSV="$OUT_DIR/resume_state.tsv"
RESUME_LOG="$OUT_DIR/resume_history.log"
FULLY_ALIGNED="false"
TOTAL_SAMPLES=0
COMPLETE_SAMPLES=0
PARTIAL_SAMPLES=0
MISSING_SAMPLES=0
```

## Lines 147-153

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Reusable function. This block defines a named helper so related checks, messages, or workflow steps can be called consistently elsewhere in the script.</span>

```bash
record_stage() {
  local stage="$1"
  local status="$2"
  local detail="$3"
  printf '%s\t%s\t%s\t%s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$stage" "$status" "$detail" >> "$STATE_TSV"
  printf '[%s] %s\t%s\t%s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$stage" "$status" "$detail" >> "$RESUME_LOG"
}
```

## Lines 155-158

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Reusable function. This block defines a named helper so related checks, messages, or workflow steps can be called consistently elsewhere in the script.</span>

```bash
init_state_files() {
  printf 'timestamp\tstage\tstatus\tdetail\n' > "$STATE_TSV"
  touch "$RESUME_LOG"
}
```

## Lines 160-164

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Reusable function. This block defines a named helper so related checks, messages, or workflow steps can be called consistently elsewhere in the script.</span>

```bash
file_has_featurecounts_rows() {
  local file="$1"
  [[ -s "$file" ]] || return 1
  awk 'BEGIN {found=0} /^#/ {next} $1 == "Geneid" {next} NF > 1 {found=1} END {exit !found}' "$file"
}
```

## Lines 166-168

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Reusable function. This block defines a named helper so related checks, messages, or workflow steps can be called consistently elsewhere in the script.</span>

```bash
counts_complete() {
  file_has_featurecounts_rows "$HOST_COUNT_FILE" && file_has_featurecounts_rows "$BACTERIA_COUNT_FILE"
}
```

## Lines 170-181

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Reusable function. This block defines a named helper so related checks, messages, or workflow steps can be called consistently elsewhere in the script.</span>

```bash
qc_complete() {
  local summary="$QC_OUT_DIR/summary/alignment_qc_summary.tsv"
  [[ -s "$summary" ]] || return 1

  local expected
  expected="$(awk -F '\t' 'NR > 1 && $7 == "complete" {count += 2} END {print count + 0}' "$COMPLETION_TSV")"
  [[ "$expected" -gt 0 ]] || return 1

  local observed
  observed="$(awk 'NR > 1 {count++} END {print count + 0}' "$summary")"
  [[ "$observed" -ge "$expected" ]]
}
```

## Lines 183-385

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Reusable function. This block defines a named helper so related checks, messages, or workflow steps can be called consistently elsewhere in the script.</span>

```bash
write_completion_report() {
  local total=0
  local full=0
  local partial=0
  local none=0

  printf 'sample\thost_bam\thost_bai\tbacteria_bam\tbacteria_bai\tfiles_present\tstatus\n' > "$COMPLETION_TSV"

  while read -r sample; do
    [[ -n "$sample" ]] || continue
    total=$((total + 1))

    local host_bam="$HOST_BAM_DIR/${sample}.host.Aligned.sortedByCoord.out.bam"
    local host_bai="${host_bam}.bai"
    local bacteria_bam="$BACTERIA_BAM_DIR/${sample}.bacteria.Aligned.sortedByCoord.out.bam"
    local bacteria_bai="${bacteria_bam}.bai"
    local have_host_bam=0
    local have_host_bai=0
    local have_bacteria_bam=0
    local have_bacteria_bai=0
    local count=0
    local status

    if [[ -s "$host_bam" ]]; then have_host_bam=1; count=$((count + 1)); fi
    if [[ -s "$host_bai" ]]; then have_host_bai=1; count=$((count + 1)); fi
    if [[ -s "$bacteria_bam" ]]; then have_bacteria_bam=1; count=$((count + 1)); fi
    if [[ -s "$bacteria_bai" ]]; then have_bacteria_bai=1; count=$((count + 1)); fi

    if [[ "$count" -eq 4 ]]; then
      status="complete"
      full=$((full + 1))
    elif [[ "$count" -eq 0 ]]; then
      status="missing"
      none=$((none + 1))
    else
      status="partial"
      partial=$((partial + 1))
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$sample" "$have_host_bam" "$have_host_bai" "$have_bacteria_bam" "$have_bacteria_bai" "$count/4" "$status" \
      >> "$COMPLETION_TSV"
  done < "$SAMPLE_LIST"

  local percent
  percent="$(awk -v f="$full" -v t="$total" 'BEGIN { if (t > 0) printf "%.1f", 100 * f / t; else print "0.0" }')"

  TOTAL_SAMPLES="$total"
  COMPLETE_SAMPLES="$full"
  PARTIAL_SAMPLES="$partial"
  MISSING_SAMPLES="$none"
  if [[ "$total" -gt 0 && "$full" -eq "$total" ]]; then
    FULLY_ALIGNED="true"
  else
    FULLY_ALIGNED="false"
  fi

  {
    printf 'total_samples=%s\n' "$total"
    printf 'complete_samples=%s\n' "$full"
    printf 'partial_samples=%s\n' "$partial"
    printf 'missing_samples=%s\n' "$none"
    printf 'percent_complete=%s%%\n' "$percent"
    printf 'completion_table=%s\n' "$COMPLETION_TSV"
    printf 'metadata_table=%s\n' "$METADATA_TSV"
    printf 'resume_state_table=%s\n' "$STATE_TSV"
    printf 'resume_history_log=%s\n' "$RESUME_LOG"
    printf 'host_count_file=%s\n' "$HOST_COUNT_FILE"
    printf 'bacteria_count_file=%s\n' "$BACTERIA_COUNT_FILE"
    printf 'qc_summary_file=%s\n' "$QC_OUT_DIR/summary/alignment_qc_summary.tsv"
  } > "$SUMMARY_TXT"

  log "Alignment completion: $full/$total samples complete ($percent%)."
  record_stage "alignment_completion" "complete" "$full/$total samples complete; partial=$partial; missing=$none"
  if [[ "$partial" -gt 0 || "$none" -gt 0 ]]; then
    log "Incomplete samples: $partial partial, $none missing. See $COMPLETION_TSV"
  fi

  if [[ "$ALLOW_INCOMPLETE" != "true" && "$full" -ne "$total" ]]; then
    die "Not all samples are fully aligned. Re-run with --allow-incomplete to continue anyway."
  fi
}

write_sample_metadata() {
  printf 'sample\tcondition\ttimepoint\tbiological_replicate\thost_control\trun\tlane\tindex_sample\n' > "$METADATA_TSV"

  while read -r sample; do
    [[ -n "$sample" ]] || continue

    local condition="infection"
    local timepoint=""
    local biological_replicate=""
    local host_control=""
    local run=""
    local lane=""
    local index_sample=""

    if [[ "$sample" =~ ^([^_]+)_([0-9]+)_Run_([0-9]+)_S([0-9]+)_L([0-9]+)$ ]]; then
      timepoint="${BASH_REMATCH[1]}"
      biological_replicate="${BASH_REMATCH[2]}"
      run="${BASH_REMATCH[3]}"
      index_sample="S${BASH_REMATCH[4]}"
      lane="L${BASH_REMATCH[5]}"
    elif [[ "$sample" =~ ^B([0-9]+)_H([0-9]+)_Run_([0-9]+)_S([0-9]+)_L([0-9]+)$ ]]; then
      condition="host_control"
      biological_replicate="${BASH_REMATCH[1]}"
      host_control="H${BASH_REMATCH[2]}"
      run="${BASH_REMATCH[3]}"
      index_sample="S${BASH_REMATCH[4]}"
      lane="L${BASH_REMATCH[5]}"
    else
      condition="unparsed"
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$sample" "$condition" "$timepoint" "$biological_replicate" "$host_control" "$run" "$lane" "$index_sample" \
      >> "$METADATA_TSV"
  done < "$SAMPLE_LIST"

  log "Wrote sample metadata: $METADATA_TSV"
  record_stage "sample_metadata" "complete" "$METADATA_TSV"
}

run_counts() {
  if [[ "$FORCE" != "true" ]] && counts_complete; then
    log "featureCounts outputs already exist and look complete. Skipping counts."
    record_stage "featureCounts" "skipped_complete" "$HOST_COUNT_FILE ; $BACTERIA_COUNT_FILE"
    return 0
  fi

  if [[ "$FULLY_ALIGNED" != "true" && "$ALLOW_INCOMPLETE" != "true" ]]; then
    record_stage "featureCounts" "blocked" "alignment incomplete: $COMPLETE_SAMPLES/$TOTAL_SAMPLES complete"
    die "Counts are blocked because not all samples are fully aligned."
  fi

  local args=(env THREADS="$THREADS" bash "$WORKFLOW_SCRIPT" --step counts)
  if [[ "$FORCE" == "true" ]]; then
    args+=(--force)
  fi
  run_cmd "${args[@]}"

  if [[ "$DRY_RUN" == "true" ]]; then
    record_stage "featureCounts" "dry_run" "${args[*]}"
  elif counts_complete; then
    record_stage "featureCounts" "complete" "$HOST_COUNT_FILE ; $BACTERIA_COUNT_FILE"
  else
    record_stage "featureCounts" "incomplete_after_run" "expected $HOST_COUNT_FILE and $BACTERIA_COUNT_FILE"
    die "featureCounts finished but expected count outputs were not both complete."
  fi
}

run_alignment_qc() {
  if [[ "$FORCE" != "true" ]] && qc_complete; then
    log "Alignment QC summary already exists and covers the completed BAMs. Skipping BAM QC."
    record_stage "alignment_QC" "skipped_complete" "$QC_OUT_DIR/summary/alignment_qc_summary.tsv"
    return 0
  fi

  if [[ "$FULLY_ALIGNED" != "true" && "$ALLOW_INCOMPLETE" != "true" ]]; then
    record_stage "alignment_QC" "blocked" "alignment incomplete: $COMPLETE_SAMPLES/$TOTAL_SAMPLES complete"
    die "BAM QC is blocked because not all samples are fully aligned."
  fi

  local args=(env THREADS="$THREADS" CONDA_ENV="$CONDA_ENV" bash "$QC_SCRIPT" --target all --threads "$THREADS" --out-dir "$QC_OUT_DIR")
  run_cmd "${args[@]}"

  if [[ "$DRY_RUN" == "true" ]]; then
    record_stage "alignment_QC" "dry_run" "${args[*]}"
  elif qc_complete; then
    record_stage "alignment_QC" "complete" "$QC_OUT_DIR/summary/alignment_qc_summary.tsv"
  else
    record_stage "alignment_QC" "incomplete_after_run" "expected $QC_OUT_DIR/summary/alignment_qc_summary.tsv"
    die "Alignment QC finished but the expected summary was not complete."
  fi
}

main() {
  log "Starting post-alignment analysis"
  log "Output directory: $OUT_DIR"

  init_state_files
  write_completion_report
  write_sample_metadata

  if [[ "$RUN_COUNTS" == "true" ]]; then
    run_counts
  else
    log "Skipping featureCounts (--skip-counts)."
    record_stage "featureCounts" "skipped_user" "--skip-counts"
  fi

  if [[ "$RUN_QC" == "true" ]]; then
    run_alignment_qc
  else
    log "Skipping alignment QC (--skip-qc)."
    record_stage "alignment_QC" "skipped_user" "--skip-qc"
  fi

  log "Post-alignment analysis finished."
  log "Summary: $SUMMARY_TXT"
}

main "$@"
```

