#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

if (!params.samplesheet) {
  error "Missing --samplesheet. See samplesheets/samplesheet.example.csv"
}
if (!params.host_star_index || !params.bacteria_star_index || !params.host_gtf || !params.bacteria_gff) {
  error "Missing one or more required reference params: --host_star_index --bacteria_star_index --host_gtf --bacteria_gff"
}

Channel
  .fromPath(params.samplesheet)
  .splitCsv(header: true)
  .map { row -> tuple(row.sample as String, file(row.r1), file(row.r2)) }
  .set { reads_ch }

process FASTP {
  tag "$sample"
  publishDir "${params.outdir}/trimmed", mode: 'copy'

  input:
  tuple val(sample), path(r1), path(r2)

  output:
  tuple val(sample), path("${sample}_R1_trimmed.fastq.gz"), path("${sample}_R2_trimmed.fastq.gz"), emit: trimmed_reads
  path "${sample}_fastp.html", emit: html
  path "${sample}_fastp.json", emit: json

  script:
  """
  fastp \
    -i ${r1} \
    -I ${r2} \
    -o ${sample}_R1_trimmed.fastq.gz \
    -O ${sample}_R2_trimmed.fastq.gz \
    --detect_adapter_for_pe \
    --cut_front \
    --cut_tail \
    --cut_window_size 4 \
    --cut_mean_quality 20 \
    --qualified_quality_phred 20 \
    --unqualified_percent_limit 40 \
    --n_base_limit 5 \
    --length_required 30 \
    --thread ${task.cpus} \
    --html ${sample}_fastp.html \
    --json ${sample}_fastp.json
  """
}

process ALIGN_HOST {
  tag "$sample"
  publishDir "${params.outdir}/alignment/host", mode: 'copy'

  input:
  tuple val(sample), path(r1), path(r2)
  path star_index

  output:
  tuple val(sample), path("${sample}.host.Aligned.sortedByCoord.out.bam"), path("${sample}.host.Aligned.sortedByCoord.out.bam.bai"), emit: host_bam
  path "${sample}.host.Log.final.out", emit: host_star_log
  path "${sample}.host.flagstat.txt", emit: host_flagstat
  path "${sample}.host.idxstats.txt", emit: host_idxstats

  script:
  """
  STAR \
    --runThreadN ${task.cpus} \
    --genomeDir ${star_index} \
    --readFilesIn ${r1} ${r2} \
    --readFilesCommand zcat \
    --outFileNamePrefix ${sample}.host. \
    --outSAMtype BAM SortedByCoordinate \
    --outSAMattributes NH HI AS nM MD \
    --outFilterType BySJout \
    --outFilterMultimapNmax 100 \
    --alignSJoverhangMin 8 \
    --alignSJDBoverhangMin 1 \
    --alignIntronMin 20 \
    --alignIntronMax 1000000 \
    --alignMatesGapMax 1000000 \
    --twopassMode Basic \
    --outSAMunmapped Within \
    --outReadsUnmapped Fastx

  samtools index -@ ${task.cpus} ${sample}.host.Aligned.sortedByCoord.out.bam
  samtools flagstat ${sample}.host.Aligned.sortedByCoord.out.bam > ${sample}.host.flagstat.txt
  samtools idxstats ${sample}.host.Aligned.sortedByCoord.out.bam > ${sample}.host.idxstats.txt
  """
}

process ALIGN_BACTERIA {
  tag "$sample"
  publishDir "${params.outdir}/alignment/bacteria", mode: 'copy'

  input:
  tuple val(sample), path(r1), path(r2)
  path star_index

  output:
  tuple val(sample), path("${sample}.bacteria.Aligned.sortedByCoord.out.bam"), path("${sample}.bacteria.Aligned.sortedByCoord.out.bam.bai"), emit: bacteria_bam
  path "${sample}.bacteria.Log.final.out", emit: bacteria_star_log
  path "${sample}.bacteria.flagstat.txt", emit: bacteria_flagstat
  path "${sample}.bacteria.idxstats.txt", emit: bacteria_idxstats

  script:
  """
  STAR \
    --runThreadN ${task.cpus} \
    --genomeDir ${star_index} \
    --readFilesIn ${r1} ${r2} \
    --readFilesCommand zcat \
    --outFileNamePrefix ${sample}.bacteria. \
    --outSAMtype BAM SortedByCoordinate \
    --outSAMattributes NH HI AS nM MD \
    --outFilterType BySJout \
    --outFilterMultimapNmax 100 \
    --alignSJoverhangMin 8 \
    --alignSJDBoverhangMin 1 \
    --alignIntronMin 20 \
    --alignIntronMax 1000000 \
    --alignMatesGapMax 1000000 \
    --twopassMode Basic \
    --outSAMunmapped Within \
    --outReadsUnmapped Fastx

  samtools index -@ ${task.cpus} ${sample}.bacteria.Aligned.sortedByCoord.out.bam
  samtools flagstat ${sample}.bacteria.Aligned.sortedByCoord.out.bam > ${sample}.bacteria.flagstat.txt
  samtools idxstats ${sample}.bacteria.Aligned.sortedByCoord.out.bam > ${sample}.bacteria.idxstats.txt
  """
}

process FEATURECOUNTS_HOST {
  publishDir "${params.outdir}/counts/host", mode: 'copy'

  input:
  path bams
  path annotation

  output:
  path "featureCounts_host.txt", emit: counts
  path "featureCounts_host.txt.summary", emit: summary

  script:
  """
  featureCounts \
    -T ${task.cpus} \
    -p -B -C \
    -F GTF \
    -t exon \
    -g gene_id \
    -a ${annotation} \
    -o featureCounts_host.txt \
    ${bams}
  """
}

process FEATURECOUNTS_BACTERIA {
  publishDir "${params.outdir}/counts/bacteria", mode: 'copy'

  input:
  path bams
  path annotation

  output:
  path "featureCounts_bacteria.txt", emit: counts
  path "featureCounts_bacteria.txt.summary", emit: summary

  script:
  """
  featureCounts \
    -T ${task.cpus} \
    -p -B -C \
    -F GTF \
    -t gene \
    -g ID \
    -a ${annotation} \
    -o featureCounts_bacteria.txt \
    ${bams}
  """
}

process DESEQ2_HOST {
  publishDir "${params.outdir}/deseq2/host", mode: 'copy'

  input:
  path counts

  output:
  path "DeSeq2_host", emit: outdir

  script:
  """
  mkdir -p DeSeq2_host
  COUNTS_FILE=${counts} \
  OUT_DIR=DeSeq2_host \
  PADJ_CUTOFF=${params.padj_cutoff} \
  LFC_CUTOFF=${params.lfc_cutoff} \
  MIN_TOTAL_COUNT=${params.min_total_count} \
  Rscript ${params.deseq2_host_script}
  """
}

process DESEQ2_BACTERIA {
  publishDir "${params.outdir}/deseq2/bacteria", mode: 'copy'

  input:
  path counts

  output:
  path "DeSeq2_bacteria", emit: outdir

  script:
  """
  mkdir -p DeSeq2_bacteria
  COUNTS_FILE=${counts} \
  OUT_DIR=DeSeq2_bacteria \
  PADJ_CUTOFF=${params.padj_cutoff} \
  LFC_CUTOFF=${params.lfc_cutoff} \
  MIN_TOTAL_COUNT=${params.min_total_count} \
  Rscript ${params.deseq2_bacteria_script}
  """
}

process MULTIQC_FINAL {
  publishDir "${params.outdir}/multiqc", mode: 'copy'

  input:
  path files

  output:
  path "multiqc_report.html", emit: report

  script:
  """
  multiqc . --force -n multiqc_report.html
  """
}

workflow {
  host_index_ch = Channel.value(file(params.host_star_index))
  bacteria_index_ch = Channel.value(file(params.bacteria_star_index))
  host_gtf_ch = Channel.value(file(params.host_gtf))
  bacteria_gff_ch = Channel.value(file(params.bacteria_gff))

  FASTP(reads_ch)

  ALIGN_HOST(FASTP.out.trimmed_reads, host_index_ch)
  ALIGN_BACTERIA(FASTP.out.trimmed_reads, bacteria_index_ch)

  host_bams_ch = ALIGN_HOST.out.host_bam.map { sample, bam, bai -> bam }.collect()
  bacteria_bams_ch = ALIGN_BACTERIA.out.bacteria_bam.map { sample, bam, bai -> bam }.collect()

  FEATURECOUNTS_HOST(host_bams_ch, host_gtf_ch)
  FEATURECOUNTS_BACTERIA(bacteria_bams_ch, bacteria_gff_ch)

  DESEQ2_HOST(FEATURECOUNTS_HOST.out.counts)
  DESEQ2_BACTERIA(FEATURECOUNTS_BACTERIA.out.counts)

  qc_inputs = FASTP.out.html.mix(
    FASTP.out.json,
    ALIGN_HOST.out.host_star_log,
    ALIGN_HOST.out.host_flagstat,
    ALIGN_HOST.out.host_idxstats,
    ALIGN_BACTERIA.out.bacteria_star_log,
    ALIGN_BACTERIA.out.bacteria_flagstat,
    ALIGN_BACTERIA.out.bacteria_idxstats,
    FEATURECOUNTS_HOST.out.summary,
    FEATURECOUNTS_BACTERIA.out.summary
  ).collect()

  MULTIQC_FINAL(qc_inputs)
}
