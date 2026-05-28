# Annotated Script

**Original file:** `Analysis/Alignment/Alligment_QC`

Related lines are grouped into annotated blocks so each explanation covers a complete piece of workflow logic.

## Lines 1-2

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Script startup. This block selects bash as the interpreter and enables stricter error handling so failures, unset variables, and broken pipelines are caught early.</span>

```bash
#!/usr/bin/env bash
set -euo pipefail
```

## Lines 4-14

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
WORKDIR="${WORKDIR:-/home/lshpk18/OzanGundogdu_SOUK011275}"
ALIGNMENT_DIR="${ALIGNMENT_DIR:-$WORKDIR/Analysis/Alignment}"
BAM_DIR="${BAM_DIR:-$ALIGNMENT_DIR/bam}"
OUT_DIR="${OUT_DIR:-$ALIGNMENT_DIR/alignment_QC}"
REF_DIR="${REF_DIR:-$ALIGNMENT_DIR/references}"
HOST_ANNOTATION="${HOST_ANNOTATION:-$REF_DIR/GCF_000001405.40_GRCh38.p14_genomic.gtf}"
BACTERIA_ANNOTATION="${BACTERIA_ANNOTATION:-$REF_DIR/AL111168.1.gff3}"
THREADS="${THREADS:-16}"
TARGET="${TARGET:-all}"
CONDA_ENV="${CONDA_ENV:-dualrnaseq}"
SKIP_CONDA="${SKIP_CONDA:-false}"
```

## Lines 16-33

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Multi-line message. This here-document prints a longer help or completion message without needing a separate echo command for every line.</span>

```bash
usage() {
  cat <<'USAGE'
Usage:
  bash Analysis/Alignment/Alligment_QC [options]

Options:
  --target host|bacteria|all   Which BAM set to QC (default: all)
  --bam-dir PATH               BAM root with host/ and bacteria/ subfolders
  --out-dir PATH               Output directory (default: Analysis/Alignment/alignment_QC)
  --threads N                  Threads for samtools and Qualimap (default: 16)
  --skip-conda                 Do not activate the default conda environment
  -h, --help                   Show this help

Environment overrides:
  WORKDIR, ALIGNMENT_DIR, BAM_DIR, OUT_DIR, HOST_ANNOTATION, BACTERIA_ANNOTATION,
  THREADS, TARGET, CONDA_ENV, SKIP_CONDA
USAGE
}
```

## Lines 35-38

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Error helper. This small function prints a clear error message to standard error and exits, keeping failure handling consistent throughout the script.</span>

```bash
die() {
  echo "ERROR: $*" >&2
  exit 1
}
```

## Lines 40-42

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Warning helper. This function reports non-fatal problems to standard error while allowing the workflow to continue when that is acceptable.</span>

```bash
warn() {
  echo "WARNING: $*" >&2
}
```

## Lines 44-74

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Command-line option parsing. This loop reads user-supplied arguments, stores option values, handles help requests, and rejects unknown flags before the main workflow runs.</span>

```bash
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="${2:-}"
      shift 2
      ;;
    --bam-dir)
      BAM_DIR="${2:-}"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    --threads)
      THREADS="${2:-}"
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

## Lines 76-79

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Choice handling. This case block selects behaviour from a small set of valid values, such as deciding which target, step, or mode the script should run.</span>

```bash
case "$TARGET" in
  host|bacteria|all) ;;
  *) die "--target must be one of: host, bacteria, all" ;;
esac
```

## Lines 81-88

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Environment activation. This loads the chosen conda environment into the current shell so the tools installed there are available on PATH.</span>

```bash
if [[ "$SKIP_CONDA" != "true" && -n "$CONDA_ENV" ]]; then
  if [[ -f /home/lshpk18/miniconda3/bin/activate ]]; then
    echo "Activating conda environment: $CONDA_ENV"
    source /home/lshpk18/miniconda3/bin/activate "$CONDA_ENV"
  else
    warn "Conda activate script not found; assuming QC tools are already in PATH"
  fi
fi
```

## Lines 90-93

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Tool availability check. This block lists required command-line programs and stops early with a clear error if any are missing from PATH.</span>

```bash
required_tools=(samtools qualimap infer_experiment.py inner_distance.py read_distribution.py awk sed sort)
for tool in "${required_tools[@]}"; do
  command -v "$tool" >/dev/null 2>&1 || die "Required tool '$tool' is not in PATH"
done
```

## Lines 95-97

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Output preparation. This creates the directories needed by later commands, using `-p` where appropriate so reruns do not fail if folders already exist.</span>

```bash
mkdir -p "$OUT_DIR"/{references,summary,logs}
SUMMARY="$OUT_DIR/summary/alignment_qc_summary.tsv"
printf 'target\tsample\tbam\ttotal_reads\tmapped_reads\tmapping_percent\tduplicate_reads\tduplicate_percent\trRNA_reads\trRNA_percent\tflagstat\tqualimap_dir\tinsert_size_file\tstrandedness_file\tread_distribution_file\n' > "$SUMMARY"
```

## Lines 99-148

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Host annotation conversion. This function converts transcript or exon records from a GTF file into BED format for downstream read-distribution and QC tools.</span>

```bash
make_gene_bed_from_gtf() {
  local gtf="$1"
  local bed="$2"
  [[ -f "$gtf" ]] || die "Host annotation not found: $gtf"
  awk -F '\t' 'BEGIN {OFS="\t"}
    $0 !~ /^#/ && $3 == "exon" {
      tx_id = ""
      n = split($9, attrs, ";")
      for (i = 1; i <= n; i++) {
        field = attrs[i]
        sub(/^[[:space:]]+/, "", field)
        if (field ~ /^transcript_id /) {
          tx_id = field
          sub(/^transcript_id "/, "", tx_id)
          sub(/"$/, "", tx_id)
        } else if (field ~ /^gene_id / && tx_id == "") {
          tx_id = field
          sub(/^gene_id "/, "", tx_id)
          sub(/"$/, "", tx_id)
        }
      }
      if (tx_id == "") tx_id = $1 ":" $4 "-" $5
      start = $4 - 1
      if (start < 0) start = 0
      key = $1 SUBSEP tx_id SUBSEP $7
      if (!(key in chrom)) {
        chrom[key] = $1
        name[key] = tx_id
        strand[key] = $7
        tx_start[key] = start
        tx_end[key] = $5
      }
      if (start < tx_start[key]) tx_start[key] = start
      if ($5 > tx_end[key]) tx_end[key] = $5
      count[key]++
      exon_start[key, count[key]] = start
      exon_size[key, count[key]] = $5 - start
    }
    END {
      for (key in chrom) {
        block_sizes = ""
        block_starts = ""
        for (i = 1; i <= count[key]; i++) {
          block_sizes = block_sizes exon_size[key, i] ","
          block_starts = block_starts (exon_start[key, i] - tx_start[key]) ","
        }
        print chrom[key], tx_start[key], tx_end[key], name[key], 0, strand[key], tx_start[key], tx_end[key], 0, count[key], block_sizes, block_starts
      }
    }' "$gtf" | sort -k1,1 -k2,2n > "$bed"
}
```

## Lines 150-170

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Bacterial annotation conversion. This function extracts gene-like features from a GFF3 file and writes them in BED format for downstream QC.</span>

```bash
make_gene_bed_from_gff3() {
  local gff="$1"
  local bed="$2"
  [[ -f "$gff" ]] || die "Bacterial annotation not found: $gff"
  awk -F '\t' 'BEGIN {OFS="\t"}
    $0 !~ /^#/ && ($3 == "gene" || $3 == "CDS" || $3 == "exon" || $3 == "rRNA" || $3 == "tRNA") {
      name = "feature"
      n = split($9, attrs, ";")
      for (i = 1; i <= n; i++) {
        split(attrs[i], kv, "=")
        if (kv[1] == "ID" || kv[1] == "Name" || kv[1] == "gene") {
          name = kv[2]
          break
        }
      }
      start = $4 - 1
      if (start < 0) start = 0
      size = $5 - start
      print $1, start, $5, name, 0, $7, start, $5, 0, 1, size ",", "0,"
    }' "$gff" | sort -k1,1 -k2,2n > "$bed"
}
```

## Lines 172-198

> <span style="color: #00bcd4;"><strong>Annotation:</strong> rRNA annotation conversion. This function builds a BED file containing ribosomal RNA features so the workflow can estimate rRNA-associated reads.</span>

```bash
make_rrna_bed_from_gtf() {
  local gtf="$1"
  local bed="$2"
  [[ -f "$gtf" ]] || die "Host annotation not found: $gtf"
  awk -F '\t' 'BEGIN {OFS="\t"; IGNORECASE=1}
    $0 !~ /^#/ && ($3 ~ /rRNA/ || $9 ~ /gene_biotype "rRNA"/ || $9 ~ /transcript_biotype "rRNA"/ || $9 ~ /gbkey "rRNA"/ || $9 ~ /product "[^"]*ribosomal RNA/) {
      name = "rRNA"
      n = split($9, attrs, ";")
      for (i = 1; i <= n; i++) {
        field = attrs[i]
        sub(/^[[:space:]]+/, "", field)
        if (field ~ /^gene /) {
          name = field
          sub(/^gene "/, "", name)
          sub(/"$/, "", name)
          break
        } else if (field ~ /^gene_id /) {
          name = field
          sub(/^gene_id "/, "", name)
          sub(/"$/, "", name)
        }
      }
      start = $4 - 1
      if (start < 0) start = 0
      print $1, start, $5, name, 0, $7
    }' "$gtf" | sort -k1,1 -k2,2n > "$bed"
}
```

## Lines 200-219

> <span style="color: #00bcd4;"><strong>Annotation:</strong> rRNA annotation conversion. This function builds a BED file containing ribosomal RNA features so the workflow can estimate rRNA-associated reads.</span>

```bash
make_rrna_bed_from_gff3() {
  local gff="$1"
  local bed="$2"
  [[ -f "$gff" ]] || die "Bacterial annotation not found: $gff"
  awk -F '\t' 'BEGIN {OFS="\t"; IGNORECASE=1}
    $0 !~ /^#/ && ($3 ~ /rRNA/ || $9 ~ /ribosomal RNA/ || $9 ~ /Name=.*rRNA/) {
      name = "rRNA"
      n = split($9, attrs, ";")
      for (i = 1; i <= n; i++) {
        split(attrs[i], kv, "=")
        if (kv[1] == "ID" || kv[1] == "Name" || kv[1] == "gene") {
          name = kv[2]
          break
        }
      }
      start = $4 - 1
      if (start < 0) start = 0
      print $1, start, $5, name, 0, $7
    }' "$gff" | sort -k1,1 -k2,2n > "$bed"
}
```

## Lines 221-244

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Reusable function. This block defines a named helper so related checks, messages, or workflow steps can be called consistently elsewhere in the script.</span>

```bash
parse_flagstat() {
  local flagstat="$1"
  local metric="$2"
  case "$metric" in
    total)
      awk '/ in total / {print $1; exit}' "$flagstat"
      ;;
    mapped)
      awk '/ mapped \(/ && $0 !~ /primary mapped/ {print $1; exit}' "$flagstat"
      ;;
    mapped_percent)
      awk '/ mapped \(/ && $0 !~ /primary mapped/ {
        line = $0
        sub(/^.*\(/, "", line)
        sub(/%.*$/, "", line)
        if (line ~ /^[0-9.]+$/) print line; else print "NA"
        exit
      }' "$flagstat"
      ;;
    duplicate)
      awk '/ duplicates$/ {print $1; exit}' "$flagstat"
      ;;
  esac
}
```

## Lines 246-250

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Reusable function. This block defines a named helper so related checks, messages, or workflow steps can be called consistently elsewhere in the script.</span>

```bash
percent() {
  local numerator="$1"
  local denominator="$2"
  awk -v n="$numerator" -v d="$denominator" 'BEGIN { if (d > 0) printf "%.4f", (n / d) * 100; else print "NA" }'
}
```

## Lines 252-269

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Reusable function. This block defines a named helper so related checks, messages, or workflow steps can be called consistently elsewhere in the script.</span>

```bash
prepare_reference_beds() {
  local host_gene="$OUT_DIR/references/host.annotation.bed"
  local host_rrna="$OUT_DIR/references/host.rRNA.bed"
  local bact_gene="$OUT_DIR/references/bacteria.annotation.bed"
  local bact_rrna="$OUT_DIR/references/bacteria.rRNA.bed"

  [[ -s "$host_gene" ]] || make_gene_bed_from_gtf "$HOST_ANNOTATION" "$host_gene"
  [[ -s "$host_rrna" ]] || make_rrna_bed_from_gtf "$HOST_ANNOTATION" "$host_rrna"
  [[ -s "$bact_gene" ]] || make_gene_bed_from_gff3 "$BACTERIA_ANNOTATION" "$bact_gene"
  [[ -s "$bact_rrna" ]] || make_rrna_bed_from_gff3 "$BACTERIA_ANNOTATION" "$bact_rrna"

  if [[ ! -s "$host_rrna" ]]; then
    warn "No host rRNA intervals were detected in $HOST_ANNOTATION"
  fi
  if [[ ! -s "$bact_rrna" ]]; then
    warn "No bacterial rRNA intervals were detected in $BACTERIA_ANNOTATION"
  fi
}
```

## Lines 271-337

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Reusable function. This block defines a named helper so related checks, messages, or workflow steps can be called consistently elsewhere in the script.</span>

```bash
run_bam_qc() {
  local target="$1"
  local bam="$2"
  local gene_bed="$3"
  local rrna_bed="$4"
  local sample
  sample="$(basename "$bam" .Aligned.sortedByCoord.out.bam)"

  local target_dir="$OUT_DIR/$target"
  local sample_dir="$target_dir/$sample"
  local flagstat_dir="$sample_dir/samtools_flagstat"
  local qualimap_dir="$sample_dir/qualimap_bamqc"
  local rseqc_dir="$sample_dir/rseqc"
  local rrna_dir="$sample_dir/rRNA_contamination"
  mkdir -p "$flagstat_dir" "$qualimap_dir" "$rseqc_dir" "$rrna_dir"

  echo "QC: $target $sample"

  if [[ ! -s "${bam}.bai" ]]; then
    samtools index -@ "$THREADS" "$bam"
  fi

  local flagstat_file="$flagstat_dir/${sample}.flagstat.txt"
  samtools flagstat -@ "$THREADS" "$bam" > "$flagstat_file"

  qualimap bamqc \
    -bam "$bam" \
    -outdir "$qualimap_dir" \
    -outformat HTML \
    -nt "$THREADS" \
    --java-mem-size=8G \
    > "$sample_dir/qualimap_bamqc.log" 2>&1 || warn "Qualimap failed for $bam; see $sample_dir/qualimap_bamqc.log"

  local strandedness_file="$rseqc_dir/${sample}.infer_experiment.txt"
  local insert_file="$rseqc_dir/${sample}.inner_distance.txt"
  local read_distribution_file="$rseqc_dir/${sample}.read_distribution.txt"
  infer_experiment.py -r "$gene_bed" -i "$bam" > "$strandedness_file" 2> "$rseqc_dir/${sample}.infer_experiment.stderr.log" || warn "RSeQC infer_experiment failed for $bam"
  inner_distance.py -r "$gene_bed" -i "$bam" -o "$rseqc_dir/${sample}.inner_distance" > "$insert_file" 2> "$rseqc_dir/${sample}.inner_distance.stderr.log" || warn "RSeQC inner_distance failed for $bam"
  read_distribution.py -r "$gene_bed" -i "$bam" > "$read_distribution_file" 2> "$rseqc_dir/${sample}.read_distribution.stderr.log" || warn "RSeQC read_distribution failed for $bam"

  local total_reads mapped_reads mapping_percent duplicate_reads duplicate_percent rrna_reads rrna_percent
  total_reads="$(parse_flagstat "$flagstat_file" total)"
  mapped_reads="$(parse_flagstat "$flagstat_file" mapped)"
  mapping_percent="$(parse_flagstat "$flagstat_file" mapped_percent)"
  duplicate_reads="$(parse_flagstat "$flagstat_file" duplicate)"
  duplicate_percent="$(percent "${duplicate_reads:-0}" "${total_reads:-0}")"

  if [[ -s "$rrna_bed" ]]; then
    rrna_reads="$(samtools view -@ "$THREADS" -c -F 4 -L "$rrna_bed" "$bam")"
  else
    rrna_reads="NA"
  fi
  if [[ "$rrna_reads" == "NA" ]]; then
    rrna_percent="NA"
  else
    rrna_percent="$(percent "$rrna_reads" "${mapped_reads:-0}")"
  fi
  {
    echo "sample	target	bam	mapped_reads	rRNA_reads	rRNA_percent_of_mapped"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$sample" "$target" "$bam" "${mapped_reads:-NA}" "$rrna_reads" "$rrna_percent"
  } > "$rrna_dir/${sample}.rRNA_contamination.tsv"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$target" "$sample" "$bam" "${total_reads:-NA}" "${mapped_reads:-NA}" "${mapping_percent:-NA}" \
    "${duplicate_reads:-NA}" "$duplicate_percent" "$rrna_reads" "$rrna_percent" \
    "$flagstat_file" "$qualimap_dir" "$insert_file" "$strandedness_file" "$read_distribution_file" >> "$SUMMARY"
}
```

## Lines 339-353

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Reusable function. This block defines a named helper so related checks, messages, or workflow steps can be called consistently elsewhere in the script.</span>

```bash
run_target() {
  local target="$1"
  local bam_subdir="$BAM_DIR/$target"
  local gene_bed="$OUT_DIR/references/$target.annotation.bed"
  local rrna_bed="$OUT_DIR/references/$target.rRNA.bed"

  [[ -d "$bam_subdir" ]] || die "BAM directory not found: $bam_subdir"
  shopt -s nullglob
  local bams=("$bam_subdir"/*.bam)
  [[ ${#bams[@]} -gt 0 ]] || die "No BAM files found in $bam_subdir"

  for bam in "${bams[@]}"; do
    run_bam_qc "$target" "$bam" "$gene_bed" "$rrna_bed"
  done
}
```

## Line 355

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Workflow step. These related commands work together as one small unit in the script, preparing inputs, checking state, or running part of the analysis.</span>

```bash
prepare_reference_beds
```

## Lines 357-368

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Choice handling. This case block selects behaviour from a small set of valid values, such as deciding which target, step, or mode the script should run.</span>

```bash
case "$TARGET" in
  host)
    run_target host
    ;;
  bacteria)
    run_target bacteria
    ;;
  all)
    run_target host
    run_target bacteria
    ;;
esac
```

## Lines 370-372

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
echo "QC complete."
echo "Results: $OUT_DIR"
echo "Summary: $SUMMARY"
```

