# Dual RNA-Seq Workflow Guide

Campylobacter jejuni NCTC 11168 infection of human macrophages (project SOUK011275).  
48 infected samples + 4 uninfected controls, sequenced across 2 runs × 2 lanes (L001, L007), paired-end 150 bp.

**Conda environment:** `dualrnaseq`  
**Working directory:** `/home/lshpk18/OzanGundogdu_SOUK011275`

---

## Tools and reference versions

| Tool | Version |
|---|---|
| FastQC | latest in `dualrnaseq` |
| MultiQC | 1.25.1 |
| fastp | latest in `dualrnaseq` |
| STAR | 2.7.11b |
| samtools | 1.20 |
| featureCounts (Subread) | 2.0.6 |

| Reference | Accession | Used for |
|---|---|---|
| Human genome + annotation | GCF_000001405.40 (GRCh38.p14) | Host alignment and counting |
| *C. jejuni* NCTC 11168 genome | AL111168.1 | Bacterial alignment |
| *C. jejuni* NCTC 11168 annotation | AL111168.1.gff3 | Bacterial counting |

---

## Step 1 — Raw read QC

**Script:** `01_trimming/run_pretrim_fastqc.sh`  
**QC report:** `01_trimming/qc/pre_trim_multiqc_report.html`

Run from the project root directory. FastQC is run on all raw `*_R1_*.fastq.gz` and `*_R2_*.fastq.gz` files, then MultiQC aggregates the results into a single report.

```bash
cd /home/lshpk18/OzanGundogdu_SOUK011275
bash 01_trimming/run_pretrim_fastqc.sh
```

Output goes to `Analysis/fastqc_results/`.

> A sequencing facility QC report is also available at `01_trimming/qc/source_genomics_qc_report.html`.

---

## Step 2 — Adapter trimming and quality filtering

**Script:** `01_trimming/trim_fastp.sh`

Processes all paired-end samples in `FASTQ_DIR`. Key parameters:

| Parameter | Value | Purpose |
|---|---|---|
| `--detect_adapter_for_pe` | — | Auto-detect adapters for paired-end reads |
| `--cut_front / --cut_tail` | window 4, quality 20 | Sliding-window quality trimming |
| `--qualified_quality_phred` | 20 | Minimum per-base quality |
| `--unqualified_percent_limit` | 40 | Drop reads with >40% low-quality bases |
| `--n_base_limit` | 5 | Drop reads with >5 N bases |
| `--length_required` | 30 | Drop reads shorter than 30 bp after trimming |
| `--thread` | 4 | Threads per sample |

```bash
bash 01_trimming/trim_fastp.sh
```

Output: `*_R1_trimmed.fastq.gz`, `*_R2_trimmed.fastq.gz`, and per-sample fastp HTML/JSON reports written alongside the script.

Note: downstream alignment and counting scripts expect trimmed FASTQs to be located in `Analysis/trim_results/` (the pipeline `TRIM_DIR`). If you run a different copy of `trim_fastp.sh`, set `FASTQ_DIR`/`TRIM_DIR` accordingly or run the script from the `Analysis/trim_results` location so downstream steps find the trimmed files.

---

## Step 3 — Post-trim QC

**Script:** `01_trimming/run_multiqc_trimmed.sh`  
**QC report:** `01_trimming/qc/post_trim_multiqc_report.html`

Runs MultiQC over the trimmed FastQC results directory to confirm trimming quality.

```bash
bash 01_trimming/run_multiqc_trimmed.sh
```

Output goes to `Analysis/trimmed_fastqc_results/`.

---

## Step 4 — Build STAR genome indexes

**Script:** `02_alignment/Star-mapping.sh`  
**Config:** `02_alignment/pipeline_config.sh`

Sources `pipeline_config.sh` for all paths. Builds separate STAR indexes for the host and bacterial genomes. The read overhang is set to 149 (read length 150 − 1).

```bash
bash 02_alignment/Star-mapping.sh --step index
```

Key STAR indexing flags applied to both genomes:

```
--runMode genomeGenerate
--genomeSAindexNbases 14
--sjdbOverhang 149
```

The bacterial genome is small enough that `--genomeSAindexNbases 14` is required to avoid STAR warnings about index size.

Index locations (from `pipeline_config.sh`):
- Host: `Analysis/Alignment/star_index/host/`
- Bacteria: `Analysis/Alignment/star_index/bacteria/`

---

## Step 5 — STAR alignment

**Script:** `02_alignment/Star-mapping.sh`

Aligns every sample in `Analysis/trim_results/` to the host genome first, then to the bacterial genome (STAR is run twice per sample). Skips samples already aligned (unless `--force` is passed). Runs `samtools flagstat` and `samtools idxstats` immediately after each alignment.

```bash
bash 02_alignment/Star-mapping.sh --step align
# or a single sample:
bash 02_alignment/Star-mapping.sh --step align --sample 15m_1_Run_1_S4_L001
```

Key STAR alignment flags used for both host and bacterial mapping:

| Flag | Value | Purpose |
|---|---|---|
| `--outSAMtype` | BAM SortedByCoordinate | Coordinate-sorted BAM output |
| `--outSAMattributes` | NH HI AS nM MD | Standard alignment tags |
| `--outFilterType` | BySJout | Filter reads by splice junctions |
| `--outFilterMultimapNmax` | 100 | Allow up to 100 multimappers |
| `--twopassMode` | Basic | Two-pass alignment for better splice junction detection |
| `--outSAMunmapped` | Within | Keep unmapped reads in the BAM |
| `--outReadsUnmapped` | Fastx | Write unmapped reads to FASTQ |
| `--alignIntronMax` | 1,000,000 | Maximum intron length (host) |
| `--runThreadN` | 16 | Threads |

Output BAMs go to:
- `Analysis/Alignment/bam/host/*.host.Aligned.sortedByCoord.out.bam`
- `Analysis/Alignment/bam/bacteria/*.bacteria.Aligned.sortedByCoord.out.bam`

---

## Step 6 — File audit (optional)

**Script:** `02_alignment/pipeline_file_audit.sh`

Audits all alignment outputs and writes TSV reports to `Analysis/Alignment/reports/`:

- `alignment_file_completion.tsv` — per-sample BAM/BAI presence
- `missing_bam_indexes.tsv` — any unindexed BAMs
- `qc_log_status.tsv` — flagstat/idxstats/STAR log presence per sample

```bash
bash 02_alignment/pipeline_file_audit.sh
```

---

## Step 7 — Alignment MultiQC

**Script:** `02_alignment/run_multiqc_alignment.sh`  
**QC report:** `02_alignment/qc/alignment_multiqc_report.html`

Aggregates STAR logs, samtools flagstat/idxstats, and featureCounts summaries into a single MultiQC report. Searches `alignments/`, `qc/`, `alignment_QC/`, `counts/`, and `logs/` under `Analysis/Alignment/`.

```bash
bash 02_alignment/run_multiqc_alignment.sh
# force regeneration:
bash 02_alignment/run_multiqc_alignment.sh --force
```

---

## Step 8 — Merge BAMs across lanes

Each sample was sequenced across two lanes (L001 and L007). These are merged before downstream counting.

### Bacterial BAMs

**Script:** `03_bam_processing/index_bacteria_bams.sh`

Groups BAMs by sample+run key (strips the `_L00X` suffix), merges lane BAMs with `samtools merge`, and indexes with `samtools index`. Runs 4 parallel merge jobs with 2 threads each.

```bash
bash 03_bam_processing/index_bacteria_bams.sh
```

Output: `Analysis/Anton_downstream_mapping/Bam_indexing/Bacteria/merged/*.bacteria.merged.bam` (96 BAMs: 48 samples × 2 runs)

### Host BAMs

**Script:** `03_bam_processing/index_host_bams.sh`

Same logic as above for host BAMs. Runs 8 parallel merge jobs.

```bash
bash 03_bam_processing/index_host_bams.sh
```

Output: `Analysis/Anton_downstream_mapping/Bam_indexing/Host/merged/*.host.merged.bam` (96 BAMs)

---

## Step 9 — Merged BAM QC

**Script:** `03_bam_processing/merged_bam_qc.sh`  
**QC report:** `03_bam_processing/qc/merged_bam_multiqc_report.html`

Runs `samtools flagstat` and `samtools idxstats` on all merged BAMs (bacteria and host in parallel), then generates a combined MultiQC report.

```bash
bash 03_bam_processing/merged_bam_qc.sh
```

---

## Step 10 — Gene-level read counting

### Bacterial counts

**Script:** `04_feature_counting/run_featurecounts_bacteria.sh`

Counts reads over *C. jejuni* genes using the GFF3 annotation. Feature type `gene`, attribute `ID` (produces `gene-Cj0001` style IDs).

```bash
bash 04_feature_counting/run_featurecounts_bacteria.sh
```

Key featureCounts flags:

| Flag | Value |
|---|---|
| `-p -B` | Paired-end, both mates must map |
| `-C` | Do not count chimeric fragments |
| `-F GFF -t gene -g ID` | GFF3 input, count at gene level |
| `-T` | 16 threads |

Output: `Analysis/Anton_downstream_mapping/FeatureCounts/featureCounts_bacteria.txt`

### Host counts

**Script:** `04_feature_counting/run_featurecounts_host.sh`

Counts reads over human genes using the GRCh38.p14 GTF annotation. Feature type `exon`, attribute `gene_id`.

```bash
bash 04_feature_counting/run_featurecounts_host.sh
```

Key featureCounts flags:

| Flag | Value |
|---|---|
| `-p -B` | Paired-end, both mates must map |
| `-C` | Do not count chimeric fragments |
| `-F GTF -t exon -g gene_id` | GTF input, count at exon level, aggregate by gene |
| `-T` | 16 threads |

Output: `Analysis/Anton_downstream_mapping/FeatureCounts/FeatureCounts_host/featureCounts_host.txt`

---

## Workflow summary

```
Raw FASTQs
    │
    ├─ run_pretrim_fastqc.sh      → pre_trim_multiqc_report.html
    │
    ▼
trim_fastp.sh
    │
    ├─ run_multiqc_trimmed.sh     → post_trim_multiqc_report.html
    │
    ▼
Star-mapping.sh --step index     (build host + bacteria STAR indexes)
    │
    ▼
Star-mapping.sh --step align     (STAR → sorted BAM + flagstat/idxstats per sample)
    │
    ├─ run_multiqc_alignment.sh   → alignment_multiqc_report.html
    │
    ▼
index_bacteria_bams.sh           (merge L001+L007 → 96 bacterial merged BAMs)
index_host_bams.sh               (merge L001+L007 → 96 host merged BAMs)
    │
    ├─ merged_bam_qc.sh           → merged_bam_multiqc_report.html
    │
    ▼
run_featurecounts_bacteria.sh    → featureCounts_bacteria.txt
run_featurecounts_host.sh        → featureCounts_host.txt
```
