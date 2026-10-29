#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/pipeline_config.sh}"
[[ -f "$CONFIG_FILE" ]] || {
  echo "ERROR: config file not found: $CONFIG_FILE" >&2
  exit 1
}
source "$CONFIG_FILE"

mkdir -p "$MANIFEST_DIR" "$REPORT_DIR"

MISSING_FASTQ_REPORT="$REPORT_DIR/missing_fastq_pairs.tsv"
MISSING_INDEX_REPORT="$REPORT_DIR/missing_bam_indexes.tsv"
EMPTY_ALIGNMENT_REPORT="$REPORT_DIR/empty_alignment_files.tsv"
ORPHAN_ALIGNMENT_REPORT="$REPORT_DIR/alignment_files_outside_bam.tsv"
COMPLETION_REPORT="$REPORT_DIR/alignment_file_completion.tsv"
QC_LOG_REPORT="$REPORT_DIR/qc_log_status.tsv"
DIRECTORY_MANIFEST="$MANIFEST_DIR/directory_manifest.txt"

printf 'sample\tr1\tr2\tstatus\n' > "$SAMPLE_MANIFEST"
printf 'sample\tmissing_mate\tpresent_fastq\n' > "$MISSING_FASTQ_REPORT"

shopt -s nullglob
declare -A seen_samples=()

for r1 in "$TRIM_DIR"/*_R1*_trimmed.fastq.gz; do
  sample="$(basename "$r1" | sed -E 's/_R1(_[0-9A-Za-z]+)?_trimmed\.fastq\.gz$//')"
  r2="$TRIM_DIR/${sample}_R2_trimmed.fastq.gz"
  seen_samples["$sample"]=1
  if [[ -f "$r2" ]]; then
    printf '%s\t%s\t%s\tpaired\n' "$sample" "$r1" "$r2" >> "$SAMPLE_MANIFEST"
  else
    printf '%s\t%s\t%s\tmissing_R2\n' "$sample" "$r1" "$r2" >> "$SAMPLE_MANIFEST"
    printf '%s\tR2\t%s\n' "$sample" "$r1" >> "$MISSING_FASTQ_REPORT"
  fi
done

for r2 in "$TRIM_DIR"/*_R2*_trimmed.fastq.gz; do
  sample="$(basename "$r2" | sed -E 's/_R2(_[0-9A-Za-z]+)?_trimmed\.fastq\.gz$//')"
  if [[ -z "${seen_samples[$sample]+x}" ]]; then
    r1="$TRIM_DIR/${sample}_R1_trimmed.fastq.gz"
    printf '%s\t%s\t%s\tmissing_R1\n' "$sample" "$r1" "$r2" >> "$SAMPLE_MANIFEST"
    printf '%s\tR1\t%s\n' "$sample" "$r2" >> "$MISSING_FASTQ_REPORT"
  fi
done

{
  printf 'path\ttype\tsize_bytes\tmodified_epoch\n'
  find "$ALIGNMENT_DIR" -type f \
    \( -name '*.bam' -o -name '*.bai' -o -name '*.txt' -o -name '*.tsv' -o -name '*.log' -o -name '*.out' \) \
    -printf '%p\tfile\t%s\t%T@\n' | sort
} > "$FILE_INVENTORY"

printf 'bam\tmissing_index\n' > "$MISSING_INDEX_REPORT"
printf 'path\tsize_bytes\n' > "$EMPTY_ALIGNMENT_REPORT"
while IFS= read -r bam; do
  if [[ ! -s "$bam" ]]; then
    size="$(stat -c '%s' "$bam" 2>/dev/null || printf '0')"
    printf '%s\t%s\n' "$bam" "$size" >> "$EMPTY_ALIGNMENT_REPORT"
    continue
  fi
  [[ -f "${bam}.bai" ]] || printf '%s\t%s\n' "$bam" "${bam}.bai" >> "$MISSING_INDEX_REPORT"
done < <(find "$BAM_DIR" "$ALIGN_DIR" -type f -name '*Aligned.sortedByCoord.out.bam' 2>/dev/null | sort)

printf 'path\trecommended_location\n' > "$ORPHAN_ALIGNMENT_REPORT"
while IFS= read -r bam; do
  sample="$(basename "$bam")"
  case "$bam" in
    "$HOST_BAM_DIR"/*|"$BACTERIA_BAM_DIR"/*) ;;
    *".host.Aligned.sortedByCoord.out.bam")
      printf '%s\t%s/%s\n' "$bam" "$HOST_BAM_DIR" "$sample" >> "$ORPHAN_ALIGNMENT_REPORT"
      ;;
    *".bacteria.Aligned.sortedByCoord.out.bam")
      printf '%s\t%s/%s\n' "$bam" "$BACTERIA_BAM_DIR" "$sample" >> "$ORPHAN_ALIGNMENT_REPORT"
      ;;
  esac
done < <(find "$ALIGN_DIR" -type f -name '*Aligned.sortedByCoord.out.bam' 2>/dev/null | sort)

printf 'sample\thost_bam\thost_bai\tbacteria_bam\tbacteria_bai\tstatus\n' > "$COMPLETION_REPORT"
if [[ -s "$SAMPLE_MANIFEST" ]]; then
  awk -F '\t' 'NR > 1 && $4 == "paired" {print $1}' "$SAMPLE_MANIFEST" | while read -r sample; do
    host_bam="$HOST_BAM_DIR/${sample}.host.Aligned.sortedByCoord.out.bam"
    bacteria_bam="$BACTERIA_BAM_DIR/${sample}.bacteria.Aligned.sortedByCoord.out.bam"
    host_bai="${host_bam}.bai"
    bacteria_bai="${bacteria_bam}.bai"
    have_host_bam=0
    have_host_bai=0
    have_bacteria_bam=0
    have_bacteria_bai=0
    [[ -s "$host_bam" ]] && have_host_bam=1
    [[ -s "$host_bai" ]] && have_host_bai=1
    [[ -s "$bacteria_bam" ]] && have_bacteria_bam=1
    [[ -s "$bacteria_bai" ]] && have_bacteria_bai=1
    count=$((have_host_bam + have_host_bai + have_bacteria_bam + have_bacteria_bai))
    status="partial"
    [[ "$count" -eq 4 ]] && status="complete"
    [[ "$count" -eq 0 ]] && status="missing"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$sample" "$have_host_bam" "$have_host_bai" "$have_bacteria_bam" "$have_bacteria_bai" "$status" >> "$COMPLETION_REPORT"
  done
fi

printf 'target\tsample\tbam\tbai\tflagstat\tidxstats\tstar_log\tstatus\n' > "$QC_LOG_REPORT"
while IFS= read -r bam; do
  name="$(basename "$bam")"
  target=""
  sample=""
  qc_dir=""
  log_dir=""
  if [[ "$bam" == "$HOST_BAM_DIR"/* ]]; then
    target="host"
    sample="${name%.host.Aligned.sortedByCoord.out.bam}"
    qc_dir="$HOST_QC_DIR"
    log_dir="$HOST_LOG_DIR"
  elif [[ "$bam" == "$BACTERIA_BAM_DIR"/* ]]; then
    target="bacteria"
    sample="${name%.bacteria.Aligned.sortedByCoord.out.bam}"
    qc_dir="$BACTERIA_QC_DIR"
    log_dir="$BACTERIA_LOG_DIR"
  else
    continue
  fi

  bai="${bam}.bai"
  flagstat="$qc_dir/${sample}.${target}.flagstat.txt"
  idxstats="$qc_dir/${sample}.${target}.idxstats.txt"
  star_log="$log_dir/${sample}.${target}.star.log"
  status="complete"

  [[ -s "$bai" ]] || status="missing_bai"
  [[ -s "$flagstat" ]] || status="missing_flagstat"
  [[ -s "$idxstats" ]] || status="missing_idxstats"
  [[ -s "$star_log" ]] || status="missing_star_log"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$target" "$sample" "$bam" "$bai" "$flagstat" "$idxstats" "$star_log" "$status" >> "$QC_LOG_REPORT"
done < <(find "$BAM_DIR" -type f -name '*Aligned.sortedByCoord.out.bam' 2>/dev/null | sort)

{
  printf '%s\n' "$ALIGNMENT_DIR"
  printf '%s\n' "$REF_DIR"
  printf '%s\n' "$STAR_INDEX_DIR"
  printf '%s\n' "$ALIGN_DIR"
  printf '%s\n' "$BAM_DIR"
  printf '%s\n' "$QC_DIR"
  printf '%s\n' "$COUNT_DIR"
  printf '%s\n' "$LOG_DIR"
  printf '%s\n' "$REPORT_DIR"
  printf '%s\n' "$MANIFEST_DIR"
  printf '%s\n' "$TMP_DIR"
  printf '%s\n' "$ARCHIVE_DIR"
} > "$DIRECTORY_MANIFEST"

echo "Wrote sample manifest: $SAMPLE_MANIFEST"
echo "Wrote file inventory: $FILE_INVENTORY"
echo "Wrote completion report: $COMPLETION_REPORT"
echo "Wrote missing FASTQ report: $MISSING_FASTQ_REPORT"
echo "Wrote missing BAM index report: $MISSING_INDEX_REPORT"
echo "Wrote empty alignment file report: $EMPTY_ALIGNMENT_REPORT"
echo "Wrote misplaced alignment report: $ORPHAN_ALIGNMENT_REPORT"
echo "Wrote QC/log status report: $QC_LOG_REPORT"
