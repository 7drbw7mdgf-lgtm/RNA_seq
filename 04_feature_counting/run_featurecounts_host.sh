#!/usr/bin/env bash
set -euo pipefail

# Run featureCounts on merged host BAM files.
#
# Input:  merged BAMs from Bam_indexing/Host/merged/
# Output: count matrix + summary in Anton_downstream_mapping/FeatureCounts/FeatureCounts_host/
#
# Annotation: GCF_000001405.40_GRCh38.p14_genomic.gtf (GRCh38.p14)
# Feature type: exon  |  Attribute: gene_id

WORKDIR="${WORKDIR:-/home/lshpk18/OzanGundogdu_SOUK011275}"
BAM_DIR="${BAM_DIR:-$WORKDIR/Analysis/Anton_downstream_mapping/Bam_indexing/Host/merged}"
GTF="${GTF:-$WORKDIR/Analysis/Alignment/references/GCF_000001405.40_GRCh38.p14_genomic.gtf}"
OUT_DIR="${OUT_DIR:-$WORKDIR/Analysis/Anton_downstream_mapping/FeatureCounts/FeatureCounts_host}"
OUT_FILE="$OUT_DIR/featureCounts_host.txt"
THREADS="${THREADS:-16}"
CONDA_ENV="${CONDA_ENV:-dualrnaseq}"

mkdir -p "$OUT_DIR/logs"

echo "=============================================="
echo "featureCounts — Host (GRCh38)"
echo "=============================================="
echo "CPUs        : $THREADS"
echo "Start time  : $(date)"
echo "BAM dir     : $BAM_DIR"
echo "GTF         : $GTF"
echo "Output      : $OUT_FILE"
echo ""

[[ -f /home/lshpk18/miniconda3/bin/activate ]] || { echo "ERROR: conda not found" >&2; exit 1; }
source /home/lshpk18/miniconda3/bin/activate "$CONDA_ENV"

[[ -f "$GTF" ]]     || { echo "ERROR: GTF not found: $GTF" >&2; exit 1; }
[[ -d "$BAM_DIR" ]] || { echo "ERROR: BAM directory not found: $BAM_DIR" >&2; exit 1; }

missing_bai=()
for bam in "$BAM_DIR"/*.host.merged.bam; do
  [[ -f "${bam}.bai" ]] || missing_bai+=("$bam")
done
if [[ ${#missing_bai[@]} -gt 0 ]]; then
  echo "ERROR: ${#missing_bai[@]} BAMs are not indexed:" >&2
  printf '  %s\n' "${missing_bai[@]}" >&2
  exit 1
fi

n_bams=$(ls "$BAM_DIR"/*.host.merged.bam | wc -l)
echo "Running featureCounts on $n_bams BAMs..."
echo "Flags: -p -B -C -F GTF -t exon -g gene_id"
echo ""

featureCounts \
  -T "$THREADS" \
  -p -B -C \
  -F GTF -t exon -g gene_id \
  -a "$GTF" \
  -o "$OUT_FILE" \
  "$BAM_DIR"/*.host.merged.bam

echo ""
echo "=============================================="
echo "Job completed : $(date)"
echo "Output        : $OUT_FILE"
n_cols=$(awk 'NR==2{print NF-6; exit}' "$OUT_FILE")
echo "Sample columns: $n_cols"
echo "=============================================="
