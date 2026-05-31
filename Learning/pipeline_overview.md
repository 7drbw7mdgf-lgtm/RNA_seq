# Dual RNA-seq Pipeline Overview

This document shows the full pipeline in execution order, the script used at each step, the key input files, and whether the step was **actually executed** (confirmed by log files / output evidence) or was a **dead end** (script exists but was not run, or was only a backup copy).

---

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ Executed | Confirmed by log output or produced files |
| ❌ Dead end | Script exists but was never invoked |
| 🗂 Backup copy | Identical duplicate of a currently-used script |

---

## Phase 1 — Environment Setup

| Step | Status | Script | Key Input Files / Dependencies | Evidence |
|------|--------|--------|-------------------------------|----------|
| 1.1 | ✅ Executed | `Analysis/install_mamba.sh` | Existing `conda` or downloads `micromamba` | `mamba` present in environment |
| 1.2 | ✅ Executed | `Analysis/install_allignment_dependancies.sh` | conda/mamba; installs STAR, samtools, subread, MultiQC into `dualrnaseq` env | Tools confirmed present in `~/miniconda3/envs/dualrnaseq/` |
| 1.3 | ✅ Executed | `Analysis/fastqc_results/install_qc_dependencies.sh` | conda/mamba; installs `fastqc`, `multiqc` into `rna-seq` env | FastQC and MultiQC in PATH |
| 1.4 | ✅ Executed | `Analysis/trim_results/install_fastp.sh` | `~/miniconda3/etc/profile.d/conda.sh`; creates `rna-seq` env | `fastp` present; trimmed files produced |
| 1.5 | ✅ Executed | `Analysis/fastqc_results/install_visualisation.sh` | Python; creates venv, installs plotly, matplotlib, seaborn, pandas, numpy, jupyter | `Analysis/fastqc_results/Visualisation/venv/` exists with install logs |
| 1.6 | ❌ Dead end | `Analysis/install_graphviz.sh` | graphviz package | `graphviz` not found in PATH — was never installed |
| 1.7 | ❌ Dead end | `Analysis/install_deseq2_dependencies.sh` | R/Bioconductor packages; targets a separate `dualrnaseq_deseq2` conda env | DE workflow used `DifferentialExpression/scripts/00_install_dependencies.sh` instead — no evidence this ran |

---

## Phase 2 — Raw Read Quality Control

| Step | Status | Script | Key Input Files / Dependencies | Evidence |
|------|--------|--------|-------------------------------|----------|
| 2.1 | ✅ Executed | `QC.sh` (at project root) | Raw FASTQ files in `/home/lshpk18/OzanGundogdu_SOUK011275/`; runs FastQC on 192 files | `Analysis/QC.log` — timestamped 2026-05-07 10:43:05 |
| 2.2 | ✅ Executed | MultiQC called within or after `QC.sh` | FastQC HTML/zip outputs in `Analysis/fastqc_results/` | `Analysis/multiqc/multiqc_files/multiqc.log` — timestamped 2026-05-07 11:01 |

---

## Phase 3 — Read Trimming

| Step | Status | Script | Key Input Files / Dependencies | Evidence |
|------|--------|--------|-------------------------------|----------|
| 3.1 | ✅ Executed | `Analysis/trim_results/trim_fastp.sh` | Raw paired FASTQ: `OzanGundogdu_SOUK011275/*_R1_001.fastq.gz` + `*_R2_001.fastq.gz` | Trimmed FASTQ files and `*_fastp.html/json` present in `Analysis/trim_results/` |
| 3.2 | ✅ Executed | `Analysis/trim_results/run_multiqc_trimmed.sh` | Trimmed FASTQ dir `Analysis/trim_results/` | `Analysis/trimmed_fastqc_results/run_multiqc_trimmed.log` — timestamped 2026-05-08 10:26:47 |

---

## Phase 4 — Reference Preparation & STAR Indexing

| Step | Status | Script | Key Input Files / Dependencies | Evidence |
|------|--------|--------|-------------------------------|----------|
| 4.1 | ✅ Executed | `Analysis/Alignment/dual_rnaseq_workflow.sh --step refs` | Host FASTA (`GCF_000001405.40_GRCh38.p14_genomic.fna`), host GTF, bacteria FASTA (`AL111168.1.fasta`), bacteria GFF3 | Workflow log: "Reference validation complete" — 2026-05-12 |
| 4.2 | ✅ Executed | `Analysis/Alignment/dual_rnaseq_workflow.sh --step index` | Host + bacteria FASTA + annotations; uses `STAR --runMode genomeGenerate` | `Analysis/Alignment/star_index/` directory populated; workflow log shows successful index build |

---

## Phase 5 — Alignment

Each sample was sequenced across two flow-cell lanes (L001 and L007). Both lane files were aligned independently; the per-lane BAMs are merged in Phase 8.

| Step | Status | Script | Key Input Files / Dependencies | Evidence |
|------|--------|--------|-------------------------------|----------|
| 5.1 | ✅ Executed | `Analysis/Alignment/submit_dual_rnaseq_slurm.sh` | Activates `dualrnaseq` conda env; launches `dual_rnaseq_workflow.sh` | Multiple `Analysis/Alignment/logs/dual_rnaseq_slurm_XXXXXXXX.log` files (jobs 5628812–5628918+) |
| 5.2 | ✅ Executed | `Analysis/Alignment/dual_rnaseq_workflow.sh --step align` | Trimmed FASTQ pairs from `Analysis/trim_results/`; host + bacteria STAR indexes | Workflow log shows alignment of 96 files across timepoints (0h–24h), completing 2026-05-13 |
| 5.3 | 🗂 Backup copy | `Analysis/Alignment/Bash_scripts/dual_rnaseq_workflow.sh` | Same as `Alignment/dual_rnaseq_workflow.sh` | `diff` confirms files are identical — directory is a backup, not an alternative version |

---

## Phase 6 — Read Counting (featureCounts)

featureCounts was run on the unmerged per-lane BAMs directly (all L001 and L007 files together).

| Step | Status | Script | Key Input Files / Dependencies | Evidence |
|------|--------|--------|-------------------------------|----------|
| 6.1 | ✅ Executed | `Analysis/Alignment/dual_rnaseq_workflow.sh --step counts` | All `bam/host/*.host.Aligned.sortedByCoord.out.bam`; host GTF; outputs `counts/host/featureCounts_host.txt` | Workflow log: "Running featureCounts" — multiple runs as samples completed; final run 2026-05-13 21:44 |
| 6.2 | ✅ Executed | `Analysis/Alignment/dual_rnaseq_workflow.sh --step counts` | All `bam/bacteria/*.bacteria.Aligned.sortedByCoord.out.bam`; bacteria GFF3; outputs `counts/bacteria/featureCounts_bacteria.txt` | Same log entries as above — host and bacteria counted together |

---

## Phase 7 — Post-Alignment QC

| Step | Status | Script | Key Input Files / Dependencies | Evidence |
|------|--------|--------|-------------------------------|----------|
| 7.1 | ✅ Executed | `Analysis/Alignment/post_alignment_analysis.sh` | `sample_names.txt`; calls `dual_rnaseq_workflow.sh --step counts` and `Aligment_QC` | `post_alignment_analysis/resume_history.log` shows repeated runs; 96/96 samples complete by 2026-05-13 21:23 |
| 7.2 | ✅ Executed | `Analysis/Alignment/Aligment_QC` | Sorted BAMs in `bam/host/` + `bam/bacteria/`; GTF/GFF3 annotations; runs samtools, qualimap, RSeQC | `resume_history.log`: "alignment_QC complete" at 2026-05-12 20:00 |
| 7.3 | ✅ Executed | `Analysis/Alignment/run_multiqc_alignment.sh` | STAR log files in `Alignment/logs/`; outputs to `Alignment/multiqc/` | `Alignment/multiqc/alignment_multiqc_report.html` exists |

---

## Phase 8 — Lane Merge & Sense-Check (Anton Track)

A parallel validation track that took the main alignment BAMs, merged their two lanes per sample+run using `samtools merge`, then ran an independent featureCounts + DESeq2 sense-check.

| Step | Status | Script | Key Input Files / Dependencies | Evidence |
|------|--------|--------|-------------------------------|----------|
| 8.1 | ✅ Executed | `Analysis/Anton_downstream_mapping/Bam_indexing/Host/index_host_bams.sh` | Per-lane BAMs from `Analysis/Alignment/bam/host/`; merges L001 + L007 per sample+run using `samtools merge` | Merged BAMs present in `Bam_indexing/Host/merged/`; per-sample logs in `Host/logs/`; job log `merge_lanes_host_5926828.log` — 2026-05-14 |
| 8.2 | ✅ Executed | `Analysis/Anton_downstream_mapping/Bam_indexing/Bacteria/index_bacteria_bams.sh` | Per-lane BAMs from `Analysis/Alignment/bam/bacteria/`; same lane-merge logic | Merged BAMs present in `Bam_indexing/Bacteria/merged/` |
| 8.3 | ✅ Executed | `Analysis/Anton_downstream_mapping/FeatureCounts/run_featurecounts_host.sbatch` | Merged host BAMs from step 8.1; outputs `FeatureCounts_host/` | `FeatureCounts_host/` directory has count outputs |
| 8.4 | ✅ Executed | `Analysis/Anton_downstream_mapping/Sense_check_host/deseq2_sense_check_host.R` | Merged-BAM count matrix; sample metadata TSV | `logs/deseq2_sense_check_host.log` exists with results |

---

## Phase 9 — Differential Expression & Downstream Analysis

| Step | Status | Script | Key Input Files / Dependencies | Evidence |
|------|--------|--------|-------------------------------|----------|
| 9.1 | ✅ Executed | `Analysis/DifferentialExpression/scripts/run_full_workflow.sh` | `config.env`; orchestrates scripts 00–06 | Progress log shows 0%–100% on 2026-05-14 |
| 9.2 | ✅ Executed | `Analysis/DifferentialExpression/scripts/00_install_dependencies.sh` | R/Bioconductor packages; DESeq2, igraph, etc. | `DifferentialExpression/logs/dependencies.log` |
| 9.3 | ✅ Executed | `Analysis/DifferentialExpression/scripts/01_validate_repair_inputs.R` | `featureCounts_host.txt`, `featureCounts_bacteria.txt`, sample metadata | Progress log: "20%: validation complete; samples=192 timepoints=0h,15m,30m,60m,3h,24h" |
| 9.4 | ✅ Executed | `Analysis/DifferentialExpression/scripts/02_deseq2_all_comparisons.R` | Validated count matrices; sample design | Progress log: "45%: DESeq2 complete host comparisons=30" |
| 9.5 | ✅ Executed | `Analysis/DifferentialExpression/scripts/03_publication_figures.R` | DESeq2 results; normalised counts | Progress log: "65%: plotting complete host/pathogen" |
| 9.6 | ✅ Executed | `Analysis/DifferentialExpression/scripts/04_pathway_enrichment.R` | DESeq2 results; KEGG pathway annotations | Progress log: "80%: enrichment/pathway complete host + pathogen" |
| 9.7 | ✅ Executed | `Analysis/DifferentialExpression/scripts/05_integrated_networks.R` | Host + bacteria counts; DE results | Progress log: "90%: integrated host-pathogen correlation complete edges=1" |
| 9.8 | ✅ Executed | `Analysis/DifferentialExpression/scripts/06_reports_manifests.R` | All workflow outputs | Progress log: "100%: workflow reports and manifests complete" |
| 9.9 | ❌ Dead end | `Analysis/DifferentialExpression/Snakefile` + `main.nf` | Snakemake / Nextflow alternative workflow definitions | Pipeline ran via bash scripts — no evidence snakemake or nextflow was invoked |
| 9.10 | ❌ Dead end | `Analysis/setup_enterprise_differential_expression_workflow.sh` | Sets up the DifferentialExpression directory structure | Directory was already set up; no log evidence of a named invocation |
| 9.11 | ❌ Dead end | `Analysis/post_trim_to_deseq2_workflow.sh` | End-to-end post-trim orchestrator | Only ran as `--dry-run`; DE was driven by `run_full_workflow.sh` instead |

---

## Summary Table

| Phase | Scripts Run | Scripts Never Used |
|-------|------------|-------------------|
| Env setup | `install_mamba.sh`, `install_allignment_dependancies.sh`, `install_qc_dependencies.sh`, `install_fastp.sh`, `install_visualisation.sh` | `install_graphviz.sh`, `install_deseq2_dependencies.sh` |
| Raw QC | `QC.sh` (project root), MultiQC | — |
| Trimming | `trim_fastp.sh`, `run_multiqc_trimmed.sh` | — |
| Alignment | `submit_dual_rnaseq_slurm.sh`, `dual_rnaseq_workflow.sh` | — |
| Post-alignment QC | `post_alignment_analysis.sh`, `Aligment_QC`, `run_multiqc_alignment.sh` | — |
| Lane merge & sense check | `index_host_bams.sh`, `index_bacteria_bams.sh`, `run_featurecounts_host.sbatch`, `deseq2_sense_check_host.R` | — |
| DE analysis | `run_full_workflow.sh`, `00_install_dependencies.sh` through `06_reports_manifests.R` | `Snakefile`, `main.nf`, `post_trim_to_deseq2_workflow.sh` |
| Backup copies | — (never executed) | All files in `Alignment/Bash_scripts/` |
