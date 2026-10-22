# FASTQ-to-featureCounts scripts

This folder contains the scripts used in the project workflow from paired FASTQ
files through host and bacterial featureCounts output. Raw FASTQ QC and trimming
scripts are kept at their workflow paths.

## Scripts

| Script | Role |
|---|---|
| [`QC.sh`](../../../QC.sh) | Runs FastQC and MultiQC on raw paired FASTQ files. |
| [`trim_fastp.sh`](../../trim_results/trim_fastp.sh) | Trims and filters paired FASTQ files with fastp. |
| [`pipeline_config.sh`](./pipeline_config.sh) | Defines project, reference, BAM, count, and log paths. |
| [`dual_rnaseq_workflow.sh`](./dual_rnaseq_workflow.sh) | Builds STAR indexes, aligns reads, and runs host and bacterial featureCounts. |

## Typical run

Run these commands from the project root. Set `FASTQ_DIR` to the directory
containing raw paired FASTQ files and `WORKDIR` to the project directory.

```bash
bash QC.sh
FASTQ_DIR=/path/to/raw_fastqs bash Analysis/trim_results/trim_fastp.sh
WORKDIR=/path/to/project \
  bash Analysis/Alignment/Bash_scripts/dual_rnaseq_workflow.sh --step all
```

To run only featureCounts after BAMs have been created:

```bash
WORKDIR=/path/to/project \
  bash Analysis/Alignment/Bash_scripts/dual_rnaseq_workflow.sh --step counts
```

The workflow expects trimmed read pairs under `Analysis/trim_results/`, reference
FASTA/annotation files under `Analysis/Alignment/references/`, and writes BAMs
and count tables under `Analysis/Alignment/`. The host output is
`counts/host/featureCounts_host.txt`; the bacterial output is
`counts/bacteria/featureCounts_bacteria.txt`.

The scripts are source snapshots from the executed project workflow. They use
the original project path as a default; use the documented environment
overrides when running in a different location. Input FASTQ files, references,
intermediate BAMs, and generated count tables are not included here.
