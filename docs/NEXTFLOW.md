# Nextflow Dual RNA-seq Pipeline

This is a first-pass Nextflow DSL2 version of the existing FASTQ -> STAR QC -> featureCounts -> DESeq2 workflow.

It preserves the existing tool choices:

- `fastp` for paired FASTQ trimming
- `STAR` for host and bacterial alignment
- `samtools` for BAM indexing and alignment QC
- `featureCounts` for host and bacterial count matrices
- existing `DESeq2_host/deseq2_host.R` and `DESeq2_bacteria/deseq2_bacteria.R` for differential expression
- `MultiQC` for combined QC reporting

## Inputs

Create a CSV sample sheet:

```csv
sample,r1,r2
15m_1_Run_1_S4,/path/sample_R1_001.fastq.gz,/path/sample_R2_001.fastq.gz
```

See `samplesheets/samplesheet.example.csv`.

The current scaffold expects prebuilt STAR indexes:

- `--host_star_index`
- `--bacteria_star_index`

and annotations:

- `--host_gtf`
- `--bacteria_gff`

## Example

```bash
nextflow run main.nf \
  -profile slurm \
  --samplesheet samplesheets/samplesheet.csv \
  --host_star_index /path/to/host_star_index \
  --bacteria_star_index /path/to/bacteria_star_index \
  --host_gtf /path/to/GRCh38.gtf \
  --bacteria_gff /path/to/AL111168.1.gff3 \
  --outdir results/dual_rnaseq_nextflow
```

For local testing:

```bash
nextflow run main.nf \
  --samplesheet samplesheets/samplesheet.csv \
  --host_star_index /path/to/host_star_index \
  --bacteria_star_index /path/to/bacteria_star_index \
  --host_gtf /path/to/GRCh38.gtf \
  --bacteria_gff /path/to/AL111168.1.gff3
```

## Output Layout

```text
results/dual_rnaseq_nextflow/
  trimmed/
  alignment/
    host/
    bacteria/
  counts/
    host/
    bacteria/
  deseq2/
    host/
    bacteria/
  multiqc/
```

## Current Limitations

This is a scaffold, not yet a fully hardened production pipeline.

Known next steps:

1. Add optional STAR genome index generation from FASTA/GTF/GFF.
2. Add explicit raw FastQC if you want it in addition to fastp reports.
3. Decide whether bacterial Run_1/Run_2 should stay separate or be collapsed before DESeq2.
4. Add containers or a pinned Conda environment file for reproducibility.
5. Add a small test dataset and CI syntax test.
6. Add optional downstream enrichment modules after DESeq2.

The important improvement is that the whole analysis is now represented as a single resumable workflow graph rather than separate manual scripts.
