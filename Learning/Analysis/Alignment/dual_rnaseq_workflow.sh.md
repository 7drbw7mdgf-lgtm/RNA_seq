# Annotated Script

**Original file:** `Analysis/Alignment/dual_rnaseq_workflow.sh`

Related lines are grouped into annotated blocks so each explanation covers a complete piece of workflow logic.

## Lines 1-2

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Script startup. This block selects bash as the interpreter and enables stricter error handling so failures, unset variables, and broken pipelines are caught early.</span>

```bash
#!/usr/bin/env bash
set -euo pipefail
```

## Lines 4-26

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
WORKDIR="/home/lshpk18/OzanGundogdu_SOUK011275"
TRIM_DIR="${TRIM_DIR:-$WORKDIR/Analysis/trim_results}"
REF_DIR="${REF_DIR:-$WORKDIR/Analysis/Alignment/references}"
STAR_INDEX_DIR="${STAR_INDEX_DIR:-$WORKDIR/Analysis/Alignment/star_index}"
HOST_STAR_INDEX_DIR="${HOST_STAR_INDEX_DIR:-$STAR_INDEX_DIR/host}"
BACTERIA_STAR_INDEX_DIR="${BACTERIA_STAR_INDEX_DIR:-$STAR_INDEX_DIR/bacteria}"
ALIGN_DIR="${ALIGN_DIR:-$WORKDIR/Analysis/Alignment/alignments}"
HOST_ALIGN_DIR="${HOST_ALIGN_DIR:-$ALIGN_DIR/host}"
BACTERIA_ALIGN_DIR="${BACTERIA_ALIGN_DIR:-$ALIGN_DIR/bacteria}"
BAM_DIR="${BAM_DIR:-$WORKDIR/Analysis/Alignment/bam}"
HOST_BAM_DIR="${HOST_BAM_DIR:-$BAM_DIR/host}"
BACTERIA_BAM_DIR="${BACTERIA_BAM_DIR:-$BAM_DIR/bacteria}"
LOG_DIR="${LOG_DIR:-$WORKDIR/Analysis/Alignment/logs}"
HOST_LOG_DIR="${HOST_LOG_DIR:-$LOG_DIR/host}"
BACTERIA_LOG_DIR="${BACTERIA_LOG_DIR:-$LOG_DIR/bacteria}"
QC_DIR="${QC_DIR:-$WORKDIR/Analysis/Alignment/qc}"
HOST_QC_DIR="${HOST_QC_DIR:-$QC_DIR/host}"
BACTERIA_QC_DIR="${BACTERIA_QC_DIR:-$QC_DIR/bacteria}"
COUNT_DIR="${COUNT_DIR:-$WORKDIR/Analysis/Alignment/counts}"
HOST_COUNT_DIR="${HOST_COUNT_DIR:-$COUNT_DIR/host}"
BACTERIA_COUNT_DIR="${BACTERIA_COUNT_DIR:-$COUNT_DIR/bacteria}"
THREADS="${THREADS:-16}"
READ_OVERHANG="${READ_OVERHANG:-149}"
```

## Lines 28-31

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
HOST_FASTA_SOURCE="${HOST_FASTA_SOURCE:-$REF_DIR/GCF_000001405.40_GRCh38.p14_genomic.fna}"
BACTERIA_FASTA_SOURCE="${BACTERIA_FASTA_SOURCE:-$REF_DIR/AL111168.1.fasta}"
HOST_ANN_SOURCE="${HOST_ANN_SOURCE:-$REF_DIR/GCF_000001405.40_GRCh38.p14_genomic.gtf}"
BACTERIA_ANN_SOURCE="${BACTERIA_ANN_SOURCE:-$REF_DIR/AL111168.1.gff3}"
```

## Lines 33-34

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
LOG_FILE="$LOG_DIR/dual_rnaseq_workflow.log"
FORCE="false"
```

## Lines 36-39

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
function die() {
  echo "ERROR: $*" >&2
  exit 1
}
```

## Lines 41-43

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Workflow step. These related commands work together as one small unit in the script, preparing inputs, checking state, or running part of the analysis.</span>

```bash
function check_command() {
  command -v "$1" >/dev/null 2>&1
}
```

## Lines 45-54

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Workflow step. These related commands work together as one small unit in the script, preparing inputs, checking state, or running part of the analysis.</span>

```bash
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
```

## Lines 56-60

> <span style="color: #00bcd4;"><strong>Annotation:</strong> STAR alignment step. This block runs STAR-related commands to build indexes or align reads against the configured reference.</span>

```bash
function check_dependencies() {
  local required=(awk grep sed sort uniq wc STAR samtools)
  if [[ "$step" == "counts" || "$step" == "all" ]]; then
    required+=(featureCounts)
  fi
```

## Lines 62-66

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Repeated work. This loop applies the same operation to each item in a list, such as samples, files, targets, or package names.</span>

```bash
  for prog in "${required[@]}"; do
    if ! check_command "$prog"; then
      die "Required program '$prog' is not in PATH. Install it or load the correct environment."
    fi
  done
```

## Lines 68-71

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
  STAR_BIN="$(resolve_command STAR star || true)"
  SAMTOOLS_BIN="$(resolve_command samtools || true)"
  FEATURECOUNTS_BIN="$(resolve_command featureCounts || true)"
}
```

## Lines 73-75

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Output preparation. This creates the directories needed by later commands, using `-p` where appropriate so reruns do not fail if folders already exist.</span>

```bash
function make_dirs() {
  mkdir -p "$REF_DIR" "$STAR_INDEX_DIR" "$HOST_STAR_INDEX_DIR" "$BACTERIA_STAR_INDEX_DIR"     "$ALIGN_DIR" "$HOST_ALIGN_DIR" "$BACTERIA_ALIGN_DIR"     "$BAM_DIR" "$HOST_BAM_DIR" "$BACTERIA_BAM_DIR"     "$LOG_DIR" "$HOST_LOG_DIR" "$BACTERIA_LOG_DIR"     "$QC_DIR" "$HOST_QC_DIR" "$BACTERIA_QC_DIR"     "$COUNT_DIR" "$HOST_COUNT_DIR" "$BACTERIA_COUNT_DIR"
}
```

## Lines 77-88

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Workflow step. These related commands work together as one small unit in the script, preparing inputs, checking state, or running part of the analysis.</span>

```bash
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
```

## Lines 90-91

> <span style="color: #00bcd4;"><strong>Annotation:</strong> STAR alignment step. This block runs STAR-related commands to build indexes or align reads against the configured reference.</span>

```bash
function build_star_index() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] Building STAR genome indexes" | tee -a "$LOG_FILE"
```

## Lines 93-102

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
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
```

## Lines 104-114

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
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
```

## Lines 116-120

> <span style="color: #00bcd4;"><strong>Annotation:</strong> STAR alignment step. This block runs STAR-related commands to build indexes or align reads against the configured reference.</span>

```bash
function validate_star_index() {
  local index_dir="$1"
  local desc="$2"
  [[ -s "$index_dir/SA" && -s "$index_dir/genomeParameters.txt" ]] || die "$desc STAR index is missing or incomplete: $index_dir. Run --step index first."
}
```

## Lines 122-131

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Text and file discovery. These commands locate files or transform text into the structured lists used by later workflow steps.</span>

```bash
function list_samples() {
  shopt -s nullglob
  local files=("$TRIM_DIR"/*_R1*_trimmed.fastq.gz)
  if [[ ${#files[@]} -eq 0 ]]; then
    die "No paired-end R1 trimmed FASTQ files found in $TRIM_DIR"
  fi
  for fq in "${files[@]}"; do
    basename "$fq" | sed -E 's/_R1(_[0-9A-Za-z]+)?_trimmed\.fastq\.gz$//' || true
  done | sort -u
}
```

## Lines 133-138

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Text and file discovery. These commands locate files or transform text into the structured lists used by later workflow steps.</span>

```bash
function sample_already_aligned() {
  local sample="$1"
  local host_bam="$HOST_BAM_DIR/${sample}.host.Aligned.sortedByCoord.out.bam"
  local host_bai="${host_bam}.bai"
  local bact_bam="$BACTERIA_BAM_DIR/${sample}.bacteria.Aligned.sortedByCoord.out.bam"
  local bact_bai="${bact_bam}.bai"
```

## Lines 140-144

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
  if [[ -f "$host_bam" && -f "$host_bai" && -f "$bact_bam" && -f "$bact_bai" ]]; then
    return 0  # Already aligned
  fi
  return 1    # Not aligned
}
```

## Lines 146-149

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Workflow step. These related commands work together as one small unit in the script, preparing inputs, checking state, or running part of the analysis.</span>

```bash
function list_unaligned_samples() {
  local samples
  mapfile -t samples < <(list_samples)
  local unaligned=()
```

## Lines 151-155

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Repeated work. This loop applies the same operation to each item in a list, such as samples, files, targets, or package names.</span>

```bash
  for sample in "${samples[@]}"; do
    if ! sample_already_aligned "$sample"; then
      unaligned+=("$sample")
    fi
  done
```

## Lines 157-158

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
  printf '%s\n' "${unaligned[@]}"
}
```

## Lines 160-165

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Workflow step. These related commands work together as one small unit in the script, preparing inputs, checking state, or running part of the analysis.</span>

```bash
function align_sample() {
  local sample="$1"
  local r1="$TRIM_DIR/${sample}_R1_trimmed.fastq.gz"
  local r2="$TRIM_DIR/${sample}_R2_trimmed.fastq.gz"
  [[ -f "$r1" ]] || die "Missing R1 read for sample $sample: $r1"
  [[ -f "$r2" ]] || die "Missing R2 read for sample $sample: $r2"
```

## Lines 167-170

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Text and file discovery. These commands locate files or transform text into the structured lists used by later workflow steps.</span>

```bash
  local host_prefix="$HOST_ALIGN_DIR/${sample}.host."
  local host_bam="$HOST_BAM_DIR/${sample}.host.Aligned.sortedByCoord.out.bam"
  local host_bai="${host_bam}.bai"
  local host_log="$HOST_LOG_DIR/${sample}.host.star.log"
```

## Lines 172-175

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Text and file discovery. These commands locate files or transform text into the structured lists used by later workflow steps.</span>

```bash
  local bact_prefix="$BACTERIA_ALIGN_DIR/${sample}.bacteria."
  local bact_bam="$BACTERIA_BAM_DIR/${sample}.bacteria.Aligned.sortedByCoord.out.bam"
  local bact_bai="${bact_bam}.bai"
  local bact_log="$BACTERIA_LOG_DIR/${sample}.bacteria.star.log"
```

## Lines 177-181

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
  # Check if sample is already aligned
  if [[ "$FORCE" == "false" ]] && [[ -f "$host_bam" ]] && [[ -f "$host_bai" ]] && [[ -f "$bact_bam" ]] && [[ -f "$bact_bai" ]]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Sample $sample already aligned. Skipping. (Use --force to re-align)" | tee -a "$LOG_FILE"
    return 0
  fi
```

## Lines 183-184

> <span style="color: #00bcd4;"><strong>Annotation:</strong> STAR alignment step. This block runs STAR-related commands to build indexes or align reads against the configured reference.</span>

```bash
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] Aligning sample $sample to host genome" | tee -a "$LOG_FILE"
  "$STAR_BIN"     --runThreadN "$THREADS"     --genomeDir "$HOST_STAR_INDEX_DIR"     --readFilesIn "$r1" "$r2"     --readFilesCommand zcat     --outFileNamePrefix "$host_prefix"     --outSAMtype BAM SortedByCoordinate     --outSAMattributes NH HI AS nM MD     --outFilterType BySJout     --outFilterMultimapNmax 100     --alignSJoverhangMin 8     --alignSJDBoverhangMin 1     --alignIntronMin 20     --alignIntronMax 1000000     --alignMatesGapMax 1000000     --twopassMode Basic     --outSAMunmapped Within     --outReadsUnmapped Fastx     2>&1 | tee "$host_log"
```

## Lines 186-189

> <span style="color: #00bcd4;"><strong>Annotation:</strong> BAM processing and QC. These commands use samtools to index, inspect, or summarize alignment files for downstream checks.</span>

```bash
  mv "${host_prefix}Aligned.sortedByCoord.out.bam" "$host_bam"
  "$SAMTOOLS_BIN" index -@ "$THREADS" "$host_bam"
  "$SAMTOOLS_BIN" flagstat "$host_bam" > "$HOST_QC_DIR/${sample}.host.flagstat.txt"
  "$SAMTOOLS_BIN" idxstats "$host_bam" > "$HOST_QC_DIR/${sample}.host.idxstats.txt"
```

## Lines 191-192

> <span style="color: #00bcd4;"><strong>Annotation:</strong> STAR alignment step. This block runs STAR-related commands to build indexes or align reads against the configured reference.</span>

```bash
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] Aligning sample $sample to bacterial genome" | tee -a "$LOG_FILE"
  "$STAR_BIN"     --runThreadN "$THREADS"     --genomeDir "$BACTERIA_STAR_INDEX_DIR"     --readFilesIn "$r1" "$r2"     --readFilesCommand zcat     --outFileNamePrefix "$bact_prefix"     --outSAMtype BAM SortedByCoordinate     --outSAMattributes NH HI AS nM MD     --outFilterType BySJout     --outFilterMultimapNmax 100     --alignSJoverhangMin 8     --alignSJDBoverhangMin 1     --alignIntronMin 20     --alignIntronMax 1000000     --alignMatesGapMax 1000000     --twopassMode Basic     --outSAMunmapped Within     --outReadsUnmapped Fastx     2>&1 | tee "$bact_log"
```

## Lines 194-198

> <span style="color: #00bcd4;"><strong>Annotation:</strong> BAM processing and QC. These commands use samtools to index, inspect, or summarize alignment files for downstream checks.</span>

```bash
  mv "${bact_prefix}Aligned.sortedByCoord.out.bam" "$bact_bam"
  "$SAMTOOLS_BIN" index -@ "$THREADS" "$bact_bam"
  "$SAMTOOLS_BIN" flagstat "$bact_bam" > "$BACTERIA_QC_DIR/${sample}.bacteria.flagstat.txt"
  "$SAMTOOLS_BIN" idxstats "$bact_bam" > "$BACTERIA_QC_DIR/${sample}.bacteria.idxstats.txt"
}
```

## Lines 200-203

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
function run_all_samples() {
  local samples unaligned
  mapfile -t samples < <(list_samples)
  echo "Found ${#samples[@]} total samples." | tee -a "$LOG_FILE"
```

## Lines 205-221

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
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
```

## Lines 223-232

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
function featurecounts_args() {
  local ann="$1"
  if [[ "$ann" == *.gff ]] || [[ "$ann" == *.gff3 ]]; then
    printf '%s
' -F GFF -g gene
  else
    printf '%s
' -F GTF -g gene_id
  fi
}
```

## Lines 234-235

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
function run_featurecounts() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] Running featureCounts" | tee -a "$LOG_FILE"
```

## Lines 237-249

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
  if [[ -f "$HOST_ANN_SOURCE" ]]; then
    local host_count_file="$HOST_COUNT_DIR/featureCounts_host.txt"
    if [[ "$FORCE" == "false" ]] && [[ -f "$host_count_file" ]]; then
      echo "Host featureCounts output already exists. Skipping. (Use --force to re-run)" | tee -a "$LOG_FILE"
    else
      local args=( -T "$THREADS" -p -B -C -t exon -a "$HOST_ANN_SOURCE" -o "$host_count_file" )
      local extra
      extra=$(featurecounts_args "$HOST_ANN_SOURCE")
      read -r -a extra <<< "$extra"
      args+=("${extra[@]}")
      "$FEATURECOUNTS_BIN" "${args[@]}" "$HOST_BAM_DIR"/*.host.Aligned.sortedByCoord.out.bam 2>&1 | tee "$HOST_LOG_DIR/featureCounts_host.log"
    fi
  fi
```

## Lines 251-264

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
  if [[ -f "$BACTERIA_ANN_SOURCE" ]]; then
    local bact_count_file="$BACTERIA_COUNT_DIR/featureCounts_bacteria.txt"
    if [[ "$FORCE" == "false" ]] && [[ -f "$bact_count_file" ]]; then
      echo "Bacterial featureCounts output already exists. Skipping. (Use --force to re-run)" | tee -a "$LOG_FILE"
    else
      local args=( -T "$THREADS" -p -B -C -t exon -a "$BACTERIA_ANN_SOURCE" -o "$bact_count_file" )
      local extra
      extra=$(featurecounts_args "$BACTERIA_ANN_SOURCE")
      read -r -a extra <<< "$extra"
      args+=("${extra[@]}")
      "$FEATURECOUNTS_BIN" "${args[@]}" "$BACTERIA_BAM_DIR"/*.bacteria.Aligned.sortedByCoord.out.bam 2>&1 | tee "$BACTERIA_LOG_DIR/featureCounts_bacteria.log"
    fi
  fi
}
```

## Lines 266-268

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Multi-line message. This here-document prints a longer help or completion message without needing a separate echo command for every line.</span>

```bash
function usage() {
  cat <<EOF
Usage: $0 [--step refs|index|align|counts|all] [--sample SAMPLE] [--force]
```

## Lines 270-274

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Workflow step. These related commands work together as one small unit in the script, preparing inputs, checking state, or running part of the analysis.</span>

```bash
Options:
  --step      Which step to run. Default: all
  --sample    Align only one sample name when running step=align.
  --force     Force re-execution of all steps, ignoring previous outputs.
  --help,-h   Show this help message.
```

## Lines 276-286

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Workflow step. These related commands work together as one small unit in the script, preparing inputs, checking state, or running part of the analysis.</span>

```bash
Examples:
  $0 --step refs
  $0 --step index
  $0 --step align                    # Aligns only unaligned samples
  $0 --step align --force            # Re-aligns all samples
  $0 --step align --sample sample1
  $0 --step counts
  $0 --force                         # Re-run entire workflow from scratch
EOF
  exit 1
}
```

## Lines 288-299

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
step="all"
sample=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --step) shift; step="$1" ;; 
    --sample) shift; sample="$1" ;; 
    --force) FORCE="true" ;; 
    --help|-h) usage ;; 
    *) usage ;; 
  esac
  shift
done
```

## Lines 301-302

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Workflow step. These related commands work together as one small unit in the script, preparing inputs, checking state, or running part of the analysis.</span>

```bash
check_dependencies
make_dirs
```

## Lines 304-329

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
# Print workflow status
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Workflow Status:" | tee -a "$LOG_FILE"
if [[ "$FORCE" == "true" ]]; then
  echo "  FORCE mode: Re-running all steps" | tee -a "$LOG_FILE"
else
  echo "  Checking for previously completed work..." | tee -a "$LOG_FILE"
  if [[ "$step" == "align" || "$step" == "all" ]]; then
    total_samples=()
    mapfile -t total_samples < <(list_samples)
    if [[ ${#total_samples[@]} -gt 0 ]]; then
      unaligned_count=$(list_unaligned_samples | wc -l)
      aligned_count=$((${#total_samples[@]} - unaligned_count))
      echo "  Samples: $aligned_count/$((${#total_samples[@]})) already aligned" | tee -a "$LOG_FILE"
      if [[ $unaligned_count -gt 0 ]]; then
        echo "  Remaining: $unaligned_count samples to align" | tee -a "$LOG_FILE"
      fi
    fi
  fi
  if [[ -f "$HOST_COUNT_DIR/featureCounts_host.txt" ]]; then
    echo "  Host featureCounts: already completed" | tee -a "$LOG_FILE"
  fi
  if [[ -f "$BACTERIA_COUNT_DIR/featureCounts_bacteria.txt" ]]; then
    echo "  Bacterial featureCounts: already completed" | tee -a "$LOG_FILE"
  fi
fi
echo "" | tee -a "$LOG_FILE"
```

## Lines 331-342

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
if [[ "$step" == "refs" || "$step" == "index" || "$step" == "all" ]]; then
  validate_fasta "$HOST_FASTA_SOURCE" "Host FASTA"
  validate_fasta "$BACTERIA_FASTA_SOURCE" "Bacterial FASTA"
  if [[ "$step" == "refs" ]]; then
    echo "Reference validation complete." | tee -a "$LOG_FILE"
    exit 0
  fi
  build_star_index
elif [[ "$step" == "align" ]]; then
  validate_star_index "$HOST_STAR_INDEX_DIR" "Host"
  validate_star_index "$BACTERIA_STAR_INDEX_DIR" "Bacterial"
fi
```

## Lines 344-367

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Choice handling. This case block selects behaviour from a small set of valid values, such as deciding which target, step, or mode the script should run.</span>

```bash
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
```

## Line 369

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Workflow finished." | tee -a "$LOG_FILE"
```

