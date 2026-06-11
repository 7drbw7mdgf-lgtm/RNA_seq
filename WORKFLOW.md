# Dual RNA-seq Workflow Guide

Campylobacter jejuni NCTC 11168 infection of human macrophages, project
SOUK011275.

- 48 infected samples plus 4 uninfected controls
- Two sequencing runs and two lanes per run, paired-end 150 bp
- Required analysis timepoints: `0h`, `15m`, `30m`, `60m`, `3h`, `24h`
- Project root: `/home/lshpk18/OzanGundogdu_SOUK011275`
- Main analysis root: `/home/lshpk18/OzanGundogdu_SOUK011275/Analysis`

Last updated: 2026-06-11

---

## Active entry points

Run commands from the project root unless a full path is shown.

| Purpose | Command |
|---|---|
| Complete pipeline submitter | `bash Analysis/Bash_scripts/submit_complete_dual_rnaseq_pipeline_slurm.sh` |
| Alignment only, local/resumable | `bash Analysis/Alignment/Bash_scripts/dual_rnaseq_workflow.sh --step all` |
| Alignment indexes only | `bash Analysis/Alignment/Bash_scripts/dual_rnaseq_workflow.sh --step index` |
| Alignment for one sample | `bash Analysis/Alignment/Bash_scripts/dual_rnaseq_workflow.sh --step align --sample SAMPLE_ID` |
| Post-alignment counting/QC bridge | `bash Analysis/Alignment/Bash_scripts/post_alignment_analysis.sh --threads 16 --require-complete` |
| Differential expression workflow | `bash Analysis/DifferentialExpression/scripts/submit_workflow.sh` |
| Watch DE progress | `bash Analysis/DifferentialExpression/scripts/monitor_progress.sh` |

Direct SLURM entry point for the current DifferentialExpression workflow:

```bash
sbatch /home/lshpk18/OzanGundogdu_SOUK011275/Analysis/DifferentialExpression/slurm/master_workflow.sbatch
```

Progress log:

```bash
tail -f /home/lshpk18/OzanGundogdu_SOUK011275/Analysis/DifferentialExpression/logs/progress.log
```

---

## Tools and references

| Tool | Version / source |
|---|---|
| FastQC | environment-provided |
| MultiQC | 1.25.1 |
| fastp | environment-provided |
| STAR | 2.7.11b |
| samtools | 1.20 |
| featureCounts / Subread | 2.0.6 |
| DESeq2 and R packages | installed/checked by `DifferentialExpression/scripts/00_install_dependencies.sh` and `00_install_r_packages.R` |

| Reference | Accession | Used for |
|---|---|---|
| Human genome + annotation | GCF_000001405.40, GRCh38.p14 | Host alignment and counting |
| C. jejuni NCTC 11168 genome | AL111168.1 | Bacterial alignment |
| C. jejuni NCTC 11168 annotation | AL111168.1.gff3 | Bacterial counting |

Reference files live under:

```text
Analysis/Alignment/references/
```

---

## Directory map

| Path | Contents |
|---|---|
| `Analysis/fastqc_results/` | Raw-read FastQC/MultiQC outputs |
| `Analysis/trim_results/` | fastp-trimmed FASTQs and fastp reports |
| `Analysis/trimmed_fastqc_results/` | Post-trim MultiQC output |
| `Analysis/Alignment/Bash_scripts/` | Alignment, QC, counting, audit, and SLURM helper scripts |
| `Analysis/Alignment/Slurm_scripts/` | Lower-level SLURM job definitions |
| `Analysis/Alignment/star_index/` | Host and bacterial STAR indexes |
| `Analysis/Alignment/alignments/` | STAR logs and unmapped read outputs |
| `Analysis/Alignment/bam/` | Coordinate-sorted host and bacterial BAM/BAI files |
| `Analysis/Alignment/qc/` | samtools flagstat/idxstats and related QC |
| `Analysis/Alignment/counts/` | Host and bacterial featureCounts outputs |
| `Analysis/Alignment/post_alignment_analysis/` | Completion summaries and metadata bridge outputs |
| `Analysis/DifferentialExpression/` | Validation, DESeq2, figures, enrichment, integrated networks, reports |

---

## Step 1 - Raw read QC

FastQC is run on all raw paired FASTQ files, then MultiQC aggregates the
reports.

```bash
fastqc -t 8 -o Analysis/fastqc_results *_R1_001.fastq.gz *_R2_001.fastq.gz
multiqc Analysis/fastqc_results -o Analysis/fastqc_results
```

Output:

```text
Analysis/fastqc_results/
```

---

## Step 2 - Adapter trimming and read filtering

Script:

```text
Analysis/trim_results/trim_fastp.sh
```

Typical usage:

```bash
bash Analysis/trim_results/trim_fastp.sh
FASTQ_DIR=/path/to/raw_fastqs bash Analysis/trim_results/trim_fastp.sh
```

Important fastp settings:

| Parameter | Value / purpose |
|---|---|
| `--detect_adapter_for_pe` | Auto-detect paired-end adapters |
| `--cut_front --cut_tail` | Sliding-window quality trimming |
| `--cut_window_size` | 4 |
| `--cut_mean_quality` | 20 |
| `--qualified_quality_phred` | 20 |
| `--unqualified_percent_limit` | 40 |
| `--n_base_limit` | 5 |
| `--length_required` | 30 |
| `--thread` | 4 per sample |

Output:

```text
Analysis/trim_results/*_R1_trimmed.fastq.gz
Analysis/trim_results/*_R2_trimmed.fastq.gz
Analysis/trim_results/*.html
Analysis/trim_results/*.json
```

---

## Step 3 - Post-trim QC

```bash
multiqc Analysis/trim_results -o Analysis/trimmed_fastqc_results
```

Output:

```text
Analysis/trimmed_fastqc_results/multiqc_report.html
```

---

## Step 4 - STAR indexing and alignment

Main script:

```text
Analysis/Alignment/Bash_scripts/dual_rnaseq_workflow.sh
```

Configuration:

```text
Analysis/Alignment/Bash_scripts/pipeline_config.sh
```

Build host and bacterial STAR indexes:

```bash
bash Analysis/Alignment/Bash_scripts/dual_rnaseq_workflow.sh --step index
```

Run alignment:

```bash
bash Analysis/Alignment/Bash_scripts/dual_rnaseq_workflow.sh --step align
```

Run everything managed by the alignment script:

```bash
bash Analysis/Alignment/Bash_scripts/dual_rnaseq_workflow.sh --step all
```

The script discovers paired trimmed FASTQs, aligns each sample independently to
the host and bacterial references, sorts and indexes BAMs with samtools, records
tool/reference metadata, and reuses completed outputs unless `--force` is
supplied.

Key STAR index settings:

```text
--runMode genomeGenerate
--sjdbOverhang 149
--genomeSAindexNbases 14
```

Key STAR alignment settings:

| Flag | Value |
|---|---|
| `--outSAMtype` | `BAM SortedByCoordinate` |
| `--outSAMattributes` | `NH HI AS nM MD` |
| `--outFilterType` | `BySJout` |
| `--outFilterMultimapNmax` | `100` |
| `--twopassMode` | `Basic` |
| `--outSAMunmapped` | `Within` |
| `--outReadsUnmapped` | `Fastx` |
| `--alignIntronMax` | `1000000` for host |

Primary outputs:

```text
Analysis/Alignment/star_index/host/
Analysis/Alignment/star_index/bacteria/
Analysis/Alignment/bam/host/
Analysis/Alignment/bam/bacteria/
Analysis/Alignment/logs/host/
Analysis/Alignment/logs/bacteria/
Analysis/Alignment/qc/host/
Analysis/Alignment/qc/bacteria/
```

---

## Step 5 - Alignment audit and MultiQC

File audit:

```bash
bash Analysis/Alignment/Bash_scripts/pipeline_file_audit.sh
```

Alignment MultiQC:

```bash
bash Analysis/Alignment/Bash_scripts/run_multiqc_alignment.sh
```

Outputs:

```text
Analysis/Alignment/reports/
Analysis/Alignment/multiqc/alignment_multiqc_report.html
```

---

## Step 6 - Post-alignment counting and metadata bridge

Main script:

```text
Analysis/Alignment/Bash_scripts/post_alignment_analysis.sh
```

Recommended production-style run:

```bash
bash Analysis/Alignment/Bash_scripts/post_alignment_analysis.sh --threads 16 --require-complete
```

Exploratory/provisional run if some inputs are still missing:

```bash
bash Analysis/Alignment/Bash_scripts/post_alignment_analysis.sh --threads 16 --allow-incomplete
```

This stage checks BAM/index completion, runs or refreshes featureCounts for host
and bacteria, creates sample metadata from aligned samples, and writes completion
summaries. It is the active bridge from alignment into expression modelling.

Counting outputs:

```text
Analysis/Alignment/counts/host/featureCounts_host.txt
Analysis/Alignment/counts/bacteria/featureCounts_bacteria.txt
```

FeatureCounts settings:

| Organism | Annotation mode | Important flags |
|---|---|---|
| Host | GTF, exons aggregated by `gene_id` | `-p -B -C -F GTF -t exon -g gene_id` |
| Bacteria | GFF3, genes by `ID` | `-p -B -C -F GFF -t gene -g ID` |

---

## Step 7 - DifferentialExpression validation and DESeq2

Current workflow root:

```text
Analysis/DifferentialExpression/
```

Submit:

```bash
bash Analysis/DifferentialExpression/scripts/submit_workflow.sh
```

Or run the master workflow directly:

```bash
bash Analysis/DifferentialExpression/scripts/run_full_workflow.sh
```

The workflow enforces the chronological timepoint order:

```text
0h -> 15m -> 30m -> 60m -> 3h -> 24h
```

Validation behavior:

- blank/control baseline values are repaired to `0h` where safe
- `1h` and `60min` are normalized to `60m`
- malformed timepoints are logged
- missing required timepoints stop the workflow
- validation issues are written to `Analysis/DifferentialExpression/qc/`

Requested model:

```r
~ condition * timepoint
```

If `condition` has only one level or the model matrix is not full rank, the
workflow logs the issue and falls back to a valid timepoint model rather than
silently fitting invalid coefficients.

DE scripts:

| Script | Purpose |
|---|---|
| `00_install_dependencies.sh` | Check/install system and R dependencies |
| `00_install_r_packages.R` | R package installation/checks |
| `01_validate_repair_inputs.R` | Validate counts, metadata, timepoints, BAMs, annotations |
| `02_deseq2_all_comparisons.R` | Run DESeq2 for all host/pathogen timepoint contrasts |
| `03_publication_figures.R` | PCA, heatmaps, volcano plots, trajectories |
| `04_pathway_enrichment.R` | DEG/pathway-ready files and enrichment summaries |
| `05_integrated_networks.R` | Host-pathogen integrated/correlation/network analysis |
| `06_reports_manifests.R` | Final reports, manifests, and session summaries |

Pairwise comparisons:

- All 15 unordered timepoint pairs are generated in both directions
- Outputs are generated for host and pathogen
- Example names:
  - `host_0h_vs_30m_DESeq2_results.tsv`
  - `host_30m_vs_0h_DESeq2_results.tsv`
  - `pathogen_0h_vs_30m_DESeq2_results.tsv`

Core outputs:

```text
Analysis/DifferentialExpression/results/deseq2/
Analysis/DifferentialExpression/objects/
Analysis/DifferentialExpression/figures/
Analysis/DifferentialExpression/qc/
Analysis/DifferentialExpression/reports/
Analysis/DifferentialExpression/manifests/
```

---

## Step 8 - Pathway enrichment and integrated analysis

Pathway and network analysis are part of the current DifferentialExpression
workflow.

Important locations:

```text
Analysis/DifferentialExpression/enrichment/host/
Analysis/DifferentialExpression/enrichment/pathogen/
Analysis/DifferentialExpression/kegg/host/
Analysis/DifferentialExpression/kegg/pathogen/
Analysis/DifferentialExpression/pathway_analysis/host/
Analysis/DifferentialExpression/pathway_analysis/pathogen/
Analysis/DifferentialExpression/integrated_analysis/
```

Enrichment files include:

- all significant DEGs for pathway analysis
- upregulated DEG subsets
- downregulated DEG subsets
- unmapped gene reports
- per-comparison pathway status files
- host/pathogen pathway summaries

---

## Monitoring and diagnostics

Watch DifferentialExpression progress:

```bash
tail -f Analysis/DifferentialExpression/logs/progress.log
```

Show recent progress:

```bash
tail -n 30 Analysis/DifferentialExpression/logs/progress.log
```

Watch major workflow state changes only:

```bash
tail -f Analysis/DifferentialExpression/logs/progress.log | grep --line-buffered -E 'START|DONE|FAILED|INSTALL|R-INSTALL|%:'
```

Check SLURM jobs:

```bash
squeue -u lshpk18
```

Check a specific job:

```bash
squeue -j JOB_ID
sacct -j JOB_ID --format=JobID,JobName,Partition,State,ExitCode,Elapsed,MaxRSS,ReqMem,NodeList%20
```

---

## Current workflow summary

```text
Raw FASTQs
    |
    v
FastQC + MultiQC
    |
    v
fastp trimming
    |
    v
Post-trim MultiQC
    |
    v
dual_rnaseq_workflow.sh --step index
    |
    v
dual_rnaseq_workflow.sh --step align
    |
    v
pipeline_file_audit.sh + run_multiqc_alignment.sh
    |
    v
post_alignment_analysis.sh
    |-- host featureCounts
    |-- bacterial featureCounts
    |-- metadata and completion summaries
    |
    v
DifferentialExpression/scripts/submit_workflow.sh
    |-- dependency checks
    |-- input validation and repair
    |-- DESeq2 all timepoint comparisons
    |-- publication figures
    |-- pathway enrichment
    |-- integrated host-pathogen networks
    |-- reports and manifests
```

---

## Legacy standalone filtering and normalisation

The older standalone filtering and normalisation scripts are still present:

```text
Analysis/filtering/filter_bacteria.R
Analysis/filtering/filter_host.R
Analysis/filtering/run_filtering.sh
Analysis/normalisation/normalise_bacteria.R
Analysis/normalisation/normalise_host.R
Analysis/normalisation/run_normalisation.sh
```

They previously produced filtered matrices, DESeq2 size-factor-normalised counts,
and VST matrices under `Analysis/filtering/` and `Analysis/normalisation/`.

The current production path is the generated `Analysis/DifferentialExpression/`
workflow, which validates inputs from `Analysis/Alignment/counts/`, repairs
metadata/timepoints where safe, runs all DESeq2 comparisons, and continues into
figures, enrichment, integrated analysis, and final reports.

---

## Main documentation files

| File | Purpose |
|---|---|
| `Analysis/README_complete_dual_rnaseq_pipeline.md` | Master project workflow README |
| `Analysis/Alignment/README_alignment_scripts.md` | Alignment/counting/QC script guide |
| `Analysis/DifferentialExpression/README.md` | DifferentialExpression overview |
| `Analysis/DifferentialExpression/scripts/README.md` | Generated DE script responsibilities |
| `Analysis/DifferentialExpression/slurm/README.md` | SLURM job files and submission |
| `Analysis/trim_results/README_trim_scripts.md` | fastp trimming notes |
| `Analysis/fastqc_results/README_fastqc_scripts.md` | FastQC/MultiQC notes |
