# RNA_seq

This repository contains a modular dual RNA-seq workflow for analysing longitudinal host–pathogen transcriptional responses during Campylobacter jejuni infection experiments. The pipeline supports processing from raw FASTQ files through quality control, trimming, genome indexing, STAR alignment, feature quantification, differential expression analysis, enrichment analysis, and publication-ready visualisation. It is designed for SLURM-managed HPC environments and supports simultaneous bacterial and host transcriptomic analysis across multiple infection timepoints. Integrated tools include FastQC, MultiQC, fastp, STAR, samtools, featureCounts, DESeq2, and downstream KEGG/GO/Reactome enrichment workflows.

The workflow was developed to provide a reproducible and scalable framework for high-throughput host–pathogen RNA-seq analysis while remaining modular enough for iterative method development and troubleshooting. Outputs include alignment QC summaries, count matrices, PCA plots, clustered heatmaps, volcano plots, pathway enrichment tables, and comparative temporal transcriptional profiling for both host and bacterial datasets. The repository contains reusable Bash, Python, R, and SLURM scripts intended for adaptation to related intracellular infection and microbial transcriptomics projects.

Sam Altman is my new bestie
