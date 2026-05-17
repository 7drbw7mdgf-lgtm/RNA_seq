#!/bin/bash
#SBATCH --job-name=merge_runs_qc
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Bam_indexing/logs/merge_runs_qc_%j.out
#SBATCH --error=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Bam_indexing/logs/merge_runs_qc_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --time=06:00:00
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=lshpk18@lshtm.ac.uk

set -euo pipefail

SAMTOOLS=/home/lshpk18/miniconda3/bin/samtools
MULTIQC=/home/lshpk18/miniconda3/bin/multiqc
EMAIL=lshpk18@lshtm.ac.uk
JOB_ID=$SLURM_JOB_ID

BAM_BASE=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Bam_indexing
BACTERIA_IN="$BAM_BASE/Bacteria/merged"
HOST_IN="$BAM_BASE/Host/merged"
BACTERIA_OUT="$BAM_BASE/Bacteria/merged_runs"
HOST_OUT="$BAM_BASE/Host/merged_runs"
QC_DIR="$BAM_BASE/qc_merged_runs"
REPORT_DIR="$BAM_BASE/multiqc"
LOG_DIR="$BAM_BASE/logs"

mkdir -p "$BACTERIA_OUT" "$HOST_OUT" "$QC_DIR/bacteria" "$QC_DIR/host" "$REPORT_DIR" "$LOG_DIR"

send_email() {
    local subject="$1"
    local body="$2"
    echo "$body" | mail -s "$subject" "$EMAIL" 2>/dev/null || true
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Background progress emailer — sends update every 5 minutes
progress_emailer() {
    local step=0
    while true; do
        sleep 300
        step=$((step + 1))
        local elapsed=$((step * 5))
        local msg="Job ${JOB_ID} (merge_runs_qc) progress update at ${elapsed} minutes.

Current stage: $(tail -1 "$LOG_DIR/merge_runs_qc_${JOB_ID}.out" 2>/dev/null || echo 'running')

Node: $(hostname)
Time: $(date)"
        send_email "[SLURM ${JOB_ID}] Progress update: ${elapsed} min elapsed" "$msg"
    done
}

progress_emailer &
EMAILER_PID=$!
trap "kill $EMAILER_PID 2>/dev/null || true" EXIT

log "=== Step 1: Merge Run_1 + Run_2 BAMs per sample (bacteria) ==="

# Extract unique sample names by stripping _Run_N_SNN suffix
for BAM1 in "$BACTERIA_IN"/*_Run_1_*.bacteria.merged.bam; do
    SAMPLE=$(basename "$BAM1" | sed 's/_Run_1_S[0-9]*\.bacteria\.merged\.bam//')
    BAM2=$(ls "$BACTERIA_IN"/${SAMPLE}_Run_2_*.bacteria.merged.bam 2>/dev/null | head -1)
    OUT="$BACTERIA_OUT/${SAMPLE}.bacteria.bam"

    if [[ -f "$OUT" ]]; then
        log "Skipping $SAMPLE (already exists)"
        continue
    fi

    if [[ -z "$BAM2" ]]; then
        log "WARNING: No Run_2 found for $SAMPLE — copying Run_1 only"
        cp "$BAM1" "$OUT"
    else
        log "Merging: $SAMPLE"
        $SAMTOOLS merge -f -@ 2 "$OUT" "$BAM1" "$BAM2"
    fi
    $SAMTOOLS index "$OUT" &
done
wait
log "Bacteria merge complete"

log "=== Step 2: Merge Run_1 + Run_2 BAMs per sample (host) ==="

for BAM1 in "$HOST_IN"/*_Run_1_*.host.merged.bam; do
    SAMPLE=$(basename "$BAM1" | sed 's/_Run_1_S[0-9]*\.host\.merged\.bam//')
    BAM2=$(ls "$HOST_IN"/${SAMPLE}_Run_2_*.host.merged.bam 2>/dev/null | head -1)
    OUT="$HOST_OUT/${SAMPLE}.host.bam"

    if [[ -f "$OUT" ]]; then
        log "Skipping $SAMPLE (already exists)"
        continue
    fi

    if [[ -z "$BAM2" ]]; then
        log "WARNING: No Run_2 found for $SAMPLE — copying Run_1 only"
        cp "$BAM1" "$OUT"
    else
        log "Merging: $SAMPLE"
        $SAMTOOLS merge -f -@ 2 "$OUT" "$BAM1" "$BAM2"
    fi
    $SAMTOOLS index "$OUT" &
done
wait
log "Host merge complete"

log "=== Step 3: flagstat + idxstats on fully-merged BAMs ==="

for BAM in "$BACTERIA_OUT"/*.bacteria.bam; do
    SAMPLE=$(basename "$BAM" .bam)
    $SAMTOOLS flagstat -@ 2 "$BAM" > "$QC_DIR/bacteria/${SAMPLE}.flagstat" &
    $SAMTOOLS idxstats    "$BAM" > "$QC_DIR/bacteria/${SAMPLE}.idxstats"  &
done

for BAM in "$HOST_OUT"/*.host.bam; do
    SAMPLE=$(basename "$BAM" .bam)
    $SAMTOOLS flagstat -@ 2 "$BAM" > "$QC_DIR/host/${SAMPLE}.flagstat" &
    $SAMTOOLS idxstats    "$BAM" > "$QC_DIR/host/${SAMPLE}.idxstats"  &
done

wait
log "samtools QC complete"

log "=== Step 4: MultiQC ==="

$MULTIQC \
    "$QC_DIR" \
    "$BACTERIA_OUT" \
    "$HOST_OUT" \
    -o "$REPORT_DIR" \
    -n merged_runs_multiqc_report.html \
    --force

log "=== All done ==="
log "Report: $REPORT_DIR/merged_runs_multiqc_report.html"
