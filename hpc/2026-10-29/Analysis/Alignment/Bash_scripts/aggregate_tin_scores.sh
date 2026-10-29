#!/usr/bin/env bash
# Aggregate per-sample RSeQC TIN summaries into one project-wide table.
#
# Reads:  alignment_QC/{host,bacteria}/<sample>/rseqc/<sample>.tin_summary.txt
#         alignment_QC/{host,bacteria}/<sample>/rseqc/<sample>.tin.xls
# Writes: alignment_QC/summary/tin_summary.tsv
set -euo pipefail

WORKDIR="${WORKDIR:-/home/lshpk18/OzanGundogdu_SOUK011275}"
OUT_DIR="${OUT_DIR:-$WORKDIR/Analysis/Alignment/alignment_QC}"
SUMMARY="$OUT_DIR/summary/tin_summary.tsv"

mkdir -p "$OUT_DIR/summary"
printf 'target\tsample\ttimepoint\tTIN_mean\tTIN_median\tTIN_stdev\tn_transcripts_scored\tn_transcripts_total\n' > "$SUMMARY"

for target in host bacteria; do
  for summary_file in "$OUT_DIR/$target"/*/rseqc/*.tin_summary.txt; do
    [[ -e "$summary_file" ]] || continue
    sample_dir="$(dirname "$(dirname "$summary_file")")"
    sample="$(basename "$sample_dir")"
    xls_file="$(dirname "$summary_file")/${sample}.tin.xls"

    # timepoint = sample name with the trailing _<batch>_<replicate> and
    # .host/.bacteria suffix stripped, e.g. 15m_1_1.host -> 15m
    timepoint="$(echo "$sample" | sed -E "s/\.(host|bacteria)$//; s/_[0-9]+_[0-9]+$//")"

    read -r tin_mean tin_median tin_stdev < <(
      awk -F'\t' 'NR==2 {print $2, $3, $4}' "$summary_file"
    )

    if [[ -f "$xls_file" ]]; then
      n_total="$(($(wc -l < "$xls_file") - 1))"
      n_scored="$(awk -F'\t' 'NR>1 && $5>0' "$xls_file" | wc -l)"
    else
      n_total="NA"
      n_scored="NA"
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$target" "$sample" "$timepoint" "$tin_mean" "$tin_median" "$tin_stdev" "$n_scored" "$n_total" >> "$SUMMARY"
  done
done

n_rows=$(($(wc -l < "$SUMMARY") - 1))
echo "Wrote $n_rows rows to $SUMMARY"
