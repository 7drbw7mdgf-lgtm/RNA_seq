#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/pipeline_config.sh}"
[[ -f "$CONFIG_FILE" ]] || {
  echo "ERROR: config file not found: $CONFIG_FILE" >&2
  exit 1
}
source "$CONFIG_FILE"

LOG_FILE="$LOG_DIR/dual_rnaseq_workflow.log"
RUN_ID="${RUN_ID:-$(date +'%Y%m%d_%H%M%S')}"
RUN_MANIFEST="$MANIFEST_DIR/run_${RUN_ID}.tsv"
FORCE="false"
DRY_RUN="false"

function die() {
  echo "ERROR: $*" >&2
  exit 1
}

function on_error() {
  local line="$1"
  local code="$2"
  echo "ERROR: workflow failed at line $line with exit code $code. Run manifest: $RUN_MANIFEST" >&2
  if [[ -n "${LOG_FILE:-}" ]]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: failed at line $line with exit code $code" >> "$LOG_FILE" 2>/dev/null || true
  fi
}

trap 'on_error "$LINENO" "$?"' ERR

function check_command() {
  command -v "$1" >/dev/null 2>&1
}

function log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

function resolve_command() {
  local candidate
  for candidate in "$@"; do
    if command -v "$candidate" >/dev/null 2>&1; then
      command -v "$candidate"
      return 0
    fi
  done
  return 1
}

function check_dependencies() {
  local required=(awk grep sed sort uniq wc sha256sum)
  if [[ "$step" == "index" || "$step" == "align" || "$step" == "all" ]]; then
    required+=(STAR)
  fi
  if [[ "$step" == "align" || "$step" == "all" ]]; then
    required+=(samtools)
  fi
  if [[ "$step" == "counts" || "$step" == "all" ]]; then
    required+=(featureCounts)
  fi

  for prog in "${required[@]}"; do
    if ! check_command "$prog"; then
      die "Required program '$prog' is not in PATH. Install it or load the correct environment."
    fi
  done

  STAR_BIN="$(resolve_command STAR star || true)"
  SAMTOOLS_BIN="$(resolve_command samtools || true)"
  FEATURECOUNTS_BIN="$(resolve_command featureCounts || true)"
}

function command_version() {
  local prog="$1"
  case "$prog" in
    STAR) "$prog" --version 2>/dev/null | head -n 1 || true ;;
    samtools) "$prog" --version 2>/dev/null | head -n 1 || true ;;
    featureCounts) "$prog" -v 2>&1 | head -n 1 || true ;;
    *) "$prog" --version 2>/dev/null | head -n 1 || true ;;
  esac
}

function write_tool_versions() {
  {
    printf 'tool\tpinned_version\tresolved_path\tobserved_version\n'
    printf 'pipeline\t%s\t%s\t%s\n' "$PIPELINE_VERSION" "$SCRIPT_DIR/dual_rnaseq_workflow.sh" "$PIPELINE_VERSION"
    for tool in STAR samtools featureCounts; do
      local path=""
      local observed=""
      if command -v "$tool" >/dev/null 2>&1; then
        path="$(command -v "$tool")"
        observed="$(command_version "$tool")"
      fi
      case "$tool" in
        STAR) printf '%s\t%s\t%s\t%s\n' "$tool" "$STAR_VERSION_PIN" "${path:-unavailable}" "${observed:-unavailable}" ;;
        samtools) printf '%s\t%s\t%s\t%s\n' "$tool" "$SAMTOOLS_VERSION_PIN" "${path:-unavailable}" "${observed:-unavailable}" ;;
        featureCounts) printf '%s\t%s\t%s\t%s\n' "$tool" "$SUBREAD_VERSION_PIN" "${path:-unavailable}" "${observed:-unavailable}" ;;
      esac
    done
  } > "$TOOL_VERSIONS"
}

function make_dirs() {
  mkdir -p "$REF_DIR" "$STAR_INDEX_DIR" "$HOST_STAR_INDEX_DIR" "$BACTERIA_STAR_INDEX_DIR"     "$ALIGN_DIR" "$HOST_ALIGN_DIR" "$BACTERIA_ALIGN_DIR"     "$BAM_DIR" "$HOST_BAM_DIR" "$BACTERIA_BAM_DIR"     "$LOG_DIR" "$HOST_LOG_DIR" "$BACTERIA_LOG_DIR"     "$QC_DIR" "$HOST_QC_DIR" "$BACTERIA_QC_DIR"     "$COUNT_DIR" "$HOST_COUNT_DIR" "$BACTERIA_COUNT_DIR"
  mkdir -p "$REPORT_DIR" "$MANIFEST_DIR" "$TMP_DIR"/star "$ARCHIVE_DIR"
}

function write_run_manifest() {
  {
    printf 'key\tvalue\n'
    printf 'run_id\t%s\n' "$RUN_ID"
    printf 'started_at\t%s\n' "$(date +'%Y-%m-%d %H:%M:%S')"
    printf 'workdir\t%s\n' "$WORKDIR"
    printf 'config_file\t%s\n' "$CONFIG_FILE"
    printf 'trim_dir\t%s\n' "$TRIM_DIR"
    printf 'host_fasta\t%s\n' "$HOST_FASTA_SOURCE"
    printf 'bacteria_fasta\t%s\n' "$BACTERIA_FASTA_SOURCE"
    printf 'host_annotation\t%s\n' "$HOST_ANN_SOURCE"
    printf 'bacteria_annotation\t%s\n' "$BACTERIA_ANN_SOURCE"
    printf 'threads\t%s\n' "$THREADS"
    printf 'step\t%s\n' "$step"
    printf 'sample\t%s\n' "${sample:-all}"
    printf 'sample_sheet\t%s\n' "${SAMPLE_SHEET:-none}"
    printf 'dry_run\t%s\n' "$DRY_RUN"
    printf 'force\t%s\n' "$FORCE"
    if command -v git >/dev/null 2>&1 && git -C "$WORKDIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      printf 'git_commit\t%s\n' "$(git -C "$WORKDIR" rev-parse HEAD)"
    else
      printf 'git_commit\tunavailable\n'
    fi
  } > "$RUN_MANIFEST"
}

function write_reference_versions() {
  local host_fasta_sha host_ann_sha bacteria_fasta_sha bacteria_ann_sha
  host_fasta_sha="$(sha256sum "$HOST_FASTA_SOURCE" | awk '{print $1}')"
  host_ann_sha="$(sha256sum "$HOST_ANN_SOURCE" | awk '{print $1}')"
  bacteria_fasta_sha="$(sha256sum "$BACTERIA_FASTA_SOURCE" | awk '{print $1}')"
  bacteria_ann_sha="$(sha256sum "$BACTERIA_ANN_SOURCE" | awk '{print $1}')"
  {
    printf 'reference\tversion\taccession_or_source\tpath\tsize_bytes\tsha256\n'
    printf 'host_genome\tGRCh38.p14\tGCF_000001405.40\t%s\t%s\t%s\n' "$HOST_FASTA_SOURCE" "$(stat -c '%s' "$HOST_FASTA_SOURCE")" "$host_fasta_sha"
    printf 'host_annotation\tGRCh38.p14\tGCF_000001405.40\t%s\t%s\t%s\n' "$HOST_ANN_SOURCE" "$(stat -c '%s' "$HOST_ANN_SOURCE")" "$host_ann_sha"
    printf 'bacteria_genome\tAL111168.1\tAL111168.1\t%s\t%s\t%s\n' "$BACTERIA_FASTA_SOURCE" "$(stat -c '%s' "$BACTERIA_FASTA_SOURCE")" "$bacteria_fasta_sha"
    printf 'bacteria_annotation\tAL111168.1\tAL111168.1\t%s\t%s\t%s\n' "$BACTERIA_ANN_SOURCE" "$(stat -c '%s' "$BACTERIA_ANN_SOURCE")" "$bacteria_ann_sha"
  } > "$REFERENCE_VERSIONS"
}

function write_reference_checksums_if_missing() {
  if [[ -s "$REFERENCE_CHECKSUMS" ]]; then
    return 0
  fi
  sha256sum "$HOST_FASTA_SOURCE" "$HOST_ANN_SOURCE" "$BACTERIA_FASTA_SOURCE" "$BACTERIA_ANN_SOURCE" > "$REFERENCE_CHECKSUMS"
  log "Wrote reference checksum manifest: $REFERENCE_CHECKSUMS"
}

function verify_reference_checksums() {
  [[ -s "$REFERENCE_CHECKSUMS" ]] || die "Reference checksum manifest not found or empty: $REFERENCE_CHECKSUMS"
  sha256sum -c "$REFERENCE_CHECKSUMS" 2>&1 | tee -a "$LOG_FILE"
}

function validate_fasta() {
  local path="$1"
  local desc="$2"
  [[ -f "$path" ]] || die "$desc not found: $path"
  local first_char
  if [[ "$path" == *.gz ]]; then
    first_char="$(gunzip -c "$path" | head -c 1)"
  else
    first_char="$(head -c 1 "$path")"
  fi
  [[ "$first_char" == ">" ]] || die "$desc is not FASTA format: $path"
}

function build_star_index() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] Building STAR genome indexes" | tee -a "$LOG_FILE"

  if [[ ! -s "$HOST_STAR_INDEX_DIR/SA" ]]; then
    echo "  Building host genome index in $HOST_STAR_INDEX_DIR" | tee -a "$LOG_FILE"
    local host_args=()
    if [[ -f "$HOST_ANN_SOURCE" ]]; then
      host_args+=(--sjdbGTFfile "$HOST_ANN_SOURCE" --sjdbOverhang "$READ_OVERHANG")
    fi
    "$STAR_BIN"       --runThreadN "$THREADS"       --runMode genomeGenerate       --genomeDir "$HOST_STAR_INDEX_DIR"       --genomeFastaFiles "$HOST_FASTA_SOURCE"       --genomeSAindexNbases 14       "${host_args[@]}"       2>&1 | tee -a "$LOG_FILE"
  else
    echo "  Host STAR index already exists at $HOST_STAR_INDEX_DIR" | tee -a "$LOG_FILE"
  fi

  if [[ ! -s "$BACTERIA_STAR_INDEX_DIR/SA" ]]; then
    echo "  Building bacterial genome index in $BACTERIA_STAR_INDEX_DIR" | tee -a "$LOG_FILE"
    local bact_args=()
    if [[ -f "$BACTERIA_ANN_SOURCE" ]]; then
      bact_args+=(--sjdbGTFfile "$BACTERIA_ANN_SOURCE" --sjdbOverhang "$READ_OVERHANG")
    fi
    "$STAR_BIN"       --runThreadN "$THREADS"       --runMode genomeGenerate       --genomeDir "$BACTERIA_STAR_INDEX_DIR"       --genomeFastaFiles "$BACTERIA_FASTA_SOURCE"       --genomeSAindexNbases 14       "${bact_args[@]}"       2>&1 | tee -a "$LOG_FILE"
  else
    echo "  Bacterial STAR index already exists at $BACTERIA_STAR_INDEX_DIR" | tee -a "$LOG_FILE"
  fi
}

function validate_star_index() {
  local index_dir="$1"
  local desc="$2"
  [[ -s "$index_dir/SA" && -s "$index_dir/genomeParameters.txt" ]] || die "$desc STAR index is missing or incomplete: $index_dir. Run --step index first."
}

function list_samples() {
  if [[ -n "$SAMPLE_SHEET" ]]; then
    validate_sample_sheet >/dev/null
    awk -F '\t' 'NR > 1 && $4 == "paired" {print $1}' "$SAMPLE_MANIFEST" | sort -u
    return 0
  fi

  if [[ -s "$SAMPLE_MANIFEST" ]]; then
    awk -F '\t' 'NR > 1 && $4 == "paired" {print $1}' "$SAMPLE_MANIFEST" | sort -u
    return 0
  fi

  shopt -s nullglob
  local files=("$TRIM_DIR"/*_R1*_trimmed.fastq.gz)
  if [[ ${#files[@]} -eq 0 ]]; then
    die "No paired-end R1 trimmed FASTQ files found in $TRIM_DIR"
  fi
  for fq in "${files[@]}"; do
    basename "$fq" | sed -E 's/_R1(_[0-9A-Za-z]+)?_trimmed\.fastq\.gz$//' || true
  done | sort -u
}

function validate_sample_sheet() {
  [[ -n "$SAMPLE_SHEET" ]] || die "No sample sheet was provided."
  [[ -f "$SAMPLE_SHEET" ]] || die "Sample sheet not found: $SAMPLE_SHEET"
  mkdir -p "$MANIFEST_DIR" "$REPORT_DIR"
  local validation_report="$REPORT_DIR/sample_sheet_validation.tsv"
  printf 'sample\tfield\tstatus\tdetail\n' > "$validation_report"
  printf 'sample\tr1\tr2\tstatus\n' > "$SAMPLE_MANIFEST"

  local errors=0
  local rows=0
  awk -F '\t' 'NR == 1 {exit !($1 == "sample" && $2 == "r1" && $3 == "r2")}' "$SAMPLE_SHEET" \
    || die "Sample sheet header must be exactly: sample<TAB>r1<TAB>r2"

  local sample_name r1 r2 extra
  while IFS=$'\t' read -r sample_name r1 r2 extra; do
    [[ -n "$sample_name$r1$r2$extra" ]] || continue
    rows=$((rows + 1))
    if [[ -n "${extra:-}" ]]; then
      printf '%s\tcolumns\tfail\ttoo many columns\n' "$sample_name" >> "$validation_report"
      errors=$((errors + 1))
    fi
    if [[ ! "$sample_name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
      printf '%s\tsample\tfail\tinvalid sample name\n' "$sample_name" >> "$validation_report"
      errors=$((errors + 1))
    else
      printf '%s\tsample\tpass\tvalid sample name\n' "$sample_name" >> "$validation_report"
    fi
    if [[ ! -f "$r1" ]]; then
      printf '%s\tr1\tfail\tmissing file: %s\n' "$sample_name" "$r1" >> "$validation_report"
      errors=$((errors + 1))
    else
      printf '%s\tr1\tpass\t%s\n' "$sample_name" "$r1" >> "$validation_report"
    fi
    if [[ ! -f "$r2" ]]; then
      printf '%s\tr2\tfail\tmissing file: %s\n' "$sample_name" "$r2" >> "$validation_report"
      errors=$((errors + 1))
    else
      printf '%s\tr2\tpass\t%s\n' "$sample_name" "$r2" >> "$validation_report"
    fi
    printf '%s\t%s\t%s\tpaired\n' "$sample_name" "$r1" "$r2" >> "$SAMPLE_MANIFEST"
  done < <(tail -n +2 "$SAMPLE_SHEET")

  [[ "$rows" -gt 0 ]] || die "Sample sheet contains no sample rows: $SAMPLE_SHEET"
  if [[ "$errors" -gt 0 ]]; then
    die "Sample sheet validation failed with $errors error(s). See $validation_report"
  fi
  log "Sample sheet validation passed: $SAMPLE_SHEET"
}

function write_sample_manifest() {
  if [[ -n "$SAMPLE_SHEET" ]]; then
    validate_sample_sheet
    return 0
  fi

  mkdir -p "$MANIFEST_DIR" "$REPORT_DIR"
  printf 'sample\tr1\tr2\tstatus\n' > "$SAMPLE_MANIFEST"
  local missing_report="$REPORT_DIR/missing_fastq_pairs.tsv"
  printf 'sample\tmissing_mate\tpresent_fastq\n' > "$missing_report"

  shopt -s nullglob
  local r1 r2 sample
  local missing=0
  local count=0
  for r1 in "$TRIM_DIR"/*_R1*_trimmed.fastq.gz; do
    sample="$(basename "$r1" | sed -E 's/_R1(_[0-9A-Za-z]+)?_trimmed\.fastq\.gz$//')"
    r2="$TRIM_DIR/${sample}_R2_trimmed.fastq.gz"
    count=$((count + 1))
    if [[ -f "$r2" ]]; then
      printf '%s\t%s\t%s\tpaired\n' "$sample" "$r1" "$r2" >> "$SAMPLE_MANIFEST"
    else
      printf '%s\t%s\t%s\tmissing_R2\n' "$sample" "$r1" "$r2" >> "$SAMPLE_MANIFEST"
      printf '%s\tR2\t%s\n' "$sample" "$r1" >> "$missing_report"
      missing=$((missing + 1))
    fi
  done

  [[ "$count" -gt 0 ]] || die "No paired-end R1 trimmed FASTQ files found in $TRIM_DIR"
  if [[ "$missing" -gt 0 ]]; then
    die "Found $missing sample(s) with missing FASTQ mates. See $missing_report"
  fi
  log "Wrote sample manifest: $SAMPLE_MANIFEST"
}

function sample_already_aligned() {
  local sample="$1"
  local host_bam="$HOST_BAM_DIR/${sample}.host.Aligned.sortedByCoord.out.bam"
  local host_bai="${host_bam}.bai"
  local bact_bam="$BACTERIA_BAM_DIR/${sample}.bacteria.Aligned.sortedByCoord.out.bam"
  local bact_bai="${bact_bam}.bai"
  
  if [[ -f "$host_bam" && -f "$host_bai" && -f "$bact_bam" && -f "$bact_bai" ]]; then
    return 0  # Already aligned
  fi
  return 1    # Not aligned
}

function list_unaligned_samples() {
  local samples
  mapfile -t samples < <(list_samples)
  local unaligned=()
  
  for sample in "${samples[@]}"; do
    if ! sample_already_aligned "$sample"; then
      unaligned+=("$sample")
    fi
  done
  
  printf '%s\n' "${unaligned[@]}"
}

function align_sample() {
  local sample="$1"
  local r1="$TRIM_DIR/${sample}_R1_trimmed.fastq.gz"
  local r2="$TRIM_DIR/${sample}_R2_trimmed.fastq.gz"
  if [[ -s "$SAMPLE_MANIFEST" ]]; then
    local manifest_row
    manifest_row="$(awk -F '\t' -v s="$sample" 'NR > 1 && $1 == s {print $2 "\t" $3; exit}' "$SAMPLE_MANIFEST")"
    if [[ -n "$manifest_row" ]]; then
      IFS=$'\t' read -r r1 r2 <<< "$manifest_row"
    fi
  fi
  [[ -f "$r1" ]] || die "Missing R1 read for sample $sample: $r1"
  [[ -f "$r2" ]] || die "Missing R2 read for sample $sample: $r2"

  local host_prefix="$HOST_ALIGN_DIR/${sample}.host."
  local host_bam="$HOST_BAM_DIR/${sample}.host.Aligned.sortedByCoord.out.bam"
  local host_bai="${host_bam}.bai"
  local host_log="$HOST_LOG_DIR/${sample}.host.star.log"
  local host_tmp="$TMP_DIR/star/${sample}.host._STARtmp"

  local bact_prefix="$BACTERIA_ALIGN_DIR/${sample}.bacteria."
  local bact_bam="$BACTERIA_BAM_DIR/${sample}.bacteria.Aligned.sortedByCoord.out.bam"
  local bact_bai="${bact_bam}.bai"
  local bact_log="$BACTERIA_LOG_DIR/${sample}.bacteria.star.log"
  local bact_tmp="$TMP_DIR/star/${sample}.bacteria._STARtmp"

  # Check if sample is already aligned
  if [[ "$FORCE" == "false" ]] && [[ -f "$host_bam" ]] && [[ -f "$host_bai" ]] && [[ -f "$bact_bam" ]] && [[ -f "$bact_bai" ]]; then
    log "Sample $sample already aligned. Skipping. (Use --force to re-align)"
    return 0
  fi

  rm -rf "$host_tmp" "$bact_tmp"

  if [[ "$DRY_RUN" == "true" ]]; then
    log "DRY RUN: would align sample $sample using R1=$r1 R2=$r2"
    return 0
  fi

  log "Aligning sample $sample to host genome"
  "$STAR_BIN"     --runThreadN "$THREADS"     --genomeDir "$HOST_STAR_INDEX_DIR"     --readFilesIn "$r1" "$r2"     --readFilesCommand zcat     --outFileNamePrefix "$host_prefix"     --outSAMtype BAM SortedByCoordinate     --outSAMattributes NH HI AS nM MD     --outFilterType BySJout     --outFilterMultimapNmax 100     --alignSJoverhangMin 8     --alignSJDBoverhangMin 1     --alignIntronMin 20     --alignIntronMax 1000000     --alignMatesGapMax 1000000     --twopassMode Basic     --outSAMunmapped Within     --outReadsUnmapped Fastx     --outTmpDir "$host_tmp"     2>&1 | tee "$host_log"

  mv "${host_prefix}Aligned.sortedByCoord.out.bam" "$host_bam"
  "$SAMTOOLS_BIN" index -@ "$THREADS" "$host_bam"
  [[ -s "$host_bam" && -s "$host_bai" ]] || die "Host BAM or index was not created for $sample"
  "$SAMTOOLS_BIN" flagstat "$host_bam" > "$HOST_QC_DIR/${sample}.host.flagstat.txt"
  "$SAMTOOLS_BIN" idxstats "$host_bam" > "$HOST_QC_DIR/${sample}.host.idxstats.txt"

  log "Aligning sample $sample to bacterial genome"
  "$STAR_BIN"     --runThreadN "$THREADS"     --genomeDir "$BACTERIA_STAR_INDEX_DIR"     --readFilesIn "$r1" "$r2"     --readFilesCommand zcat     --outFileNamePrefix "$bact_prefix"     --outSAMtype BAM SortedByCoordinate     --outSAMattributes NH HI AS nM MD     --outFilterType BySJout     --outFilterMultimapNmax 100     --alignSJoverhangMin 8     --alignSJDBoverhangMin 1     --alignIntronMin 20     --alignIntronMax 1000000     --alignMatesGapMax 1000000     --twopassMode Basic     --outSAMunmapped Within     --outReadsUnmapped Fastx     --outTmpDir "$bact_tmp"     2>&1 | tee "$bact_log"

  mv "${bact_prefix}Aligned.sortedByCoord.out.bam" "$bact_bam"
  "$SAMTOOLS_BIN" index -@ "$THREADS" "$bact_bam"
  [[ -s "$bact_bam" && -s "$bact_bai" ]] || die "Bacterial BAM or index was not created for $sample"
  "$SAMTOOLS_BIN" flagstat "$bact_bam" > "$BACTERIA_QC_DIR/${sample}.bacteria.flagstat.txt"
  "$SAMTOOLS_BIN" idxstats "$bact_bam" > "$BACTERIA_QC_DIR/${sample}.bacteria.idxstats.txt"

  rm -rf "$host_tmp" "$bact_tmp"
}

function run_all_samples() {
  local samples unaligned
  mapfile -t samples < <(list_samples)
  echo "Found ${#samples[@]} total samples." | tee -a "$LOG_FILE"
  
  if [[ "$FORCE" == "false" ]]; then
    mapfile -t unaligned < <(list_unaligned_samples)
    echo "${#unaligned[@]} samples need alignment." | tee -a "$LOG_FILE"
    if [[ ${#unaligned[@]} -eq 0 ]]; then
      echo "All samples already aligned. Skipping alignment step. (Use --force to re-align)" | tee -a "$LOG_FILE"
      return 0
    fi
    for sample in "${unaligned[@]}"; do
      align_sample "$sample"
    done
  else
    echo "FORCE mode: Re-aligning all ${#samples[@]} samples." | tee -a "$LOG_FILE"
    for sample in "${samples[@]}"; do
      align_sample "$sample"
    done
  fi
}

function featurecounts_args() {
  local ann="$1"
  if [[ "$ann" == *.gff ]] || [[ "$ann" == *.gff3 ]]; then
    printf '%s\n' "-F GTF -t gene -g ID"
  else
    printf '%s\n' "-F GTF -t exon -g gene_id"
  fi
}

function run_featurecounts() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] Running featureCounts" | tee -a "$LOG_FILE"

  if [[ -f "$HOST_ANN_SOURCE" ]]; then
    local host_count_file="$HOST_COUNT_DIR/featureCounts_host.txt"
    if [[ "$FORCE" == "false" ]] && [[ -f "$host_count_file" ]]; then
      echo "Host featureCounts output already exists. Skipping. (Use --force to re-run)" | tee -a "$LOG_FILE"
    else
      local args=( -T "$THREADS" -p -B -C -a "$HOST_ANN_SOURCE" -o "$host_count_file" )
      local extra
      extra=$(featurecounts_args "$HOST_ANN_SOURCE")
      read -r -a extra <<< "$extra"
      args+=("${extra[@]}")
      "$FEATURECOUNTS_BIN" "${args[@]}" "$HOST_BAM_DIR"/*.host.Aligned.sortedByCoord.out.bam 2>&1 | tee "$HOST_LOG_DIR/featureCounts_host.log"
    fi
  fi

  if [[ -f "$BACTERIA_ANN_SOURCE" ]]; then
    local bact_count_file="$BACTERIA_COUNT_DIR/featureCounts_bacteria.txt"
    if [[ "$FORCE" == "false" ]] && [[ -f "$bact_count_file" ]]; then
      echo "Bacterial featureCounts output already exists. Skipping. (Use --force to re-run)" | tee -a "$LOG_FILE"
    else
      local args=( -T "$THREADS" -p -B -C -a "$BACTERIA_ANN_SOURCE" -o "$bact_count_file" )
      local extra
      extra=$(featurecounts_args "$BACTERIA_ANN_SOURCE")
      read -r -a extra <<< "$extra"
      args+=("${extra[@]}")
      "$FEATURECOUNTS_BIN" "${args[@]}" "$BACTERIA_BAM_DIR"/*.bacteria.Aligned.sortedByCoord.out.bam 2>&1 | tee "$BACTERIA_LOG_DIR/featureCounts_bacteria.log"
    fi
  fi
}

function usage() {
  cat <<EOF
Usage: $0 [--step refs|index|align|counts|all] [--sample SAMPLE] [--force]

Options:
  --step      Which step to run. Default: all
  --sample    Align only one sample name when running step=align.
  --sample-sheet TSV with header: sample<TAB>r1<TAB>r2.
  --dry-run   Validate configuration, references, and samples without running STAR/featureCounts.
  --force     Force re-execution of all steps, ignoring previous outputs.
  --help,-h   Show this help message.

Examples:
  $0 --step refs
  $0 --step index
  $0 --step align                    # Aligns only unaligned samples
  $0 --step align --force            # Re-aligns all samples
  $0 --step align --sample sample1
  $0 --step align --sample-sheet samples.tsv --dry-run
  $0 --step counts
  $0 --force                         # Re-run entire workflow from scratch
EOF
  exit 1
}

step="all"
sample=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --step) shift; step="$1" ;; 
    --sample) shift; sample="$1" ;; 
    --sample-sheet) shift; SAMPLE_SHEET="$1" ;;
    --dry-run) DRY_RUN="true" ;;
    --force) FORCE="true" ;; 
    --help|-h) usage ;; 
    *) usage ;; 
  esac
  shift
done

check_dependencies
make_dirs
write_tool_versions
write_run_manifest
write_reference_versions
if [[ "$step" == "align" || "$step" == "all" ]]; then
  write_sample_manifest
fi

# Print workflow status
log "Workflow Status:"
if [[ "$FORCE" == "true" ]]; then
  log "  FORCE mode: Re-running all steps"
else
  log "  Checking for previously completed work..."
  if [[ "$step" == "align" || "$step" == "all" ]]; then
    total_samples=()
    mapfile -t total_samples < <(list_samples)
    if [[ ${#total_samples[@]} -gt 0 ]]; then
      unaligned_count=$(list_unaligned_samples | wc -l)
      aligned_count=$((${#total_samples[@]} - unaligned_count))
      log "  Samples: $aligned_count/$((${#total_samples[@]})) already aligned"
      if [[ $unaligned_count -gt 0 ]]; then
        log "  Remaining: $unaligned_count samples to align"
      fi
    fi
  fi
  if [[ -f "$HOST_COUNT_DIR/featureCounts_host.txt" ]]; then
    log "  Host featureCounts: already completed"
  fi
  if [[ -f "$BACTERIA_COUNT_DIR/featureCounts_bacteria.txt" ]]; then
    log "  Bacterial featureCounts: already completed"
  fi
fi
echo "" | tee -a "$LOG_FILE"

if [[ "$step" == "refs" || "$step" == "index" || "$step" == "all" ]]; then
  validate_fasta "$HOST_FASTA_SOURCE" "Host FASTA"
  validate_fasta "$BACTERIA_FASTA_SOURCE" "Bacterial FASTA"
  write_reference_checksums_if_missing
  verify_reference_checksums
  if [[ "$step" == "refs" ]]; then
    echo "Reference validation complete." | tee -a "$LOG_FILE"
    exit 0
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "Dry run complete." | tee -a "$LOG_FILE"
    exit 0
  fi
  build_star_index
elif [[ "$step" == "align" ]]; then
  validate_star_index "$HOST_STAR_INDEX_DIR" "Host"
  validate_star_index "$BACTERIA_STAR_INDEX_DIR" "Bacterial"
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo "Dry run complete." | tee -a "$LOG_FILE"
  exit 0
fi

case "$step" in
  index)
    echo "STAR index generation complete." | tee -a "$LOG_FILE"
    ;;
  align)
    if [[ -n "$sample" ]]; then
      align_sample "$sample"
    else
      run_all_samples
    fi
    ;;
  counts)
    run_featurecounts
    ;;
  all)
    if [[ -n "$sample" ]]; then
      align_sample "$sample"
    else
      run_all_samples
    fi
    run_featurecounts
    ;;
  *) die "Unknown step: $step" ;;
esac

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Workflow finished." | tee -a "$LOG_FILE"
