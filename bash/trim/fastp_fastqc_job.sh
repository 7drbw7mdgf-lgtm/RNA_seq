#!/bin/bash
#SBATCH --job-name=fastp_fastqc
#SBATCH --output=/home/lshpk18/fastp_fastqc_%j.log
#SBATCH --error=/home/lshpk18/fastp_fastqc_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=02:00:00

source ~/miniconda3/etc/profile.d/conda.sh
conda activate base

INPUT="/home/lshpk18/281274_EscherichiacoliAE23_2.fastq (1)"
OUTDIR="/home/lshpk18/fastp_fastqc_output"
SAMPLE="281274_EscherichiacoliAE23_2"

mkdir -p "$OUTDIR"

echo "[$(date +%H:%M:%S)] Running fastp..."
fastp \
    --in1 "$INPUT" \
    --out1 "$OUTDIR/${SAMPLE}.trimmed.fastq.gz" \
    --html "$OUTDIR/${SAMPLE}.fastp.html" \
    --json "$OUTDIR/${SAMPLE}.fastp.json" \
    --thread 8 \
    --qualified_quality_phred 20 \
    --length_required 50 \
    --correction \
    --overrepresentation_analysis

echo "[$(date +%H:%M:%S)] Running FastQC on trimmed output..."
fastqc \
    --outdir "$OUTDIR" \
    --threads 8 \
    "$OUTDIR/${SAMPLE}.trimmed.fastq.gz"

echo "[$(date +%H:%M:%S)] Done. Reports in: $OUTDIR"
