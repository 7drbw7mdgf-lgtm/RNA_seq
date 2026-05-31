# Workflow Execution Log

**Date:** 2026-06-01
**Workflow:** Dual RNA-seq Time-course Analysis
**Working directory:** `/home/lshpk18/dual_rnaseq_timecourse_workflow`

---

## Execution Steps

| Step | % Progress | Description | File Path |
|------|-----------|-------------|-----------|
| 0 | — | SLURM job submission wrapper | `slurm/master_workflow.sbatch` |
| 1 | — | Master bash orchestrator (called by SLURM) | `run_full_workflow.sh` |
| 2 | 5% | Install and check system and R dependencies | `scripts/00_install_dependencies.sh` |
| 2a | 5% | Install required R packages | `scripts/00_install_r_packages.R` |
| 3 | 20% | Validate inputs and repair metadata, count matrices, and BAM files | `scripts/01_validate_repair_inputs.R` |
| 4 | 45% | Run DESeq2 time-course differential expression analysis | `scripts/02_deseq2_timecourse.R` |
| 5 | 65% | Generate publication-quality figures (PCA, volcano, heatmaps, trajectories) | `scripts/03_generate_figures.R` |
| 6 | 82% | Run pathway enrichment analyses (GO, KEGG, Reactome, GSEA) | `scripts/04_enrichment.R` |
| 7 | 92% | Run host–pathogen correlation and network analysis | `scripts/05_host_pathogen_correlation.R` |
| 8 | 100% | Write session info and final workflow summary | `scripts/06_session_summary.R` |

---

## Supporting Scripts

| Purpose | File Path |
|---------|-----------|
| Submit SLURM job | `submit_master_workflow.sh` |
| Initial directory and environment setup | `setup_workflow.sh` |
| Monitor workflow progress in real time | `monitor_progress.sh` |
| Workflow parameters and file path configuration | `config/workflow.env` |

---

## Output Locations

| Output Type | Path |
|-------------|------|
| Progress log | `logs/progress.log` |
| Master run log | `logs/master_workflow_<timestamp>.log` |
| Validated count matrices | `results/validated_counts/` |
| Corrected metadata | `results/metadata/corrected_metadata.tsv` |
| BAM/BAI QC status | `qc/<organism>_bam_bai_status.tsv` |
| Validation issues | `qc/validation_issues.tsv` |
| DESeq2 results (all genes) | `results/deseq2/<organism>/` |
| Normalised counts | `results/deseq2/<organism>_normalised_counts.tsv` |
| DESeq2 R objects | `objects/<organism>_dds.rds`, `objects/<organism>_vst.rds` |
| Figures | `figures/<organism>/` |
| Temporal gene clusters | `results/<organism>_temporal_clusters.tsv` |
| Enrichment summaries | `results/enrichment/` |
| Host–pathogen correlation edges | `results/correlation/host_pathogen_high_correlation_edges.tsv` |
| Session info | `results/sessionInfo.txt` |
| Final summary | `results/final_workflow_summary.tsv` |
