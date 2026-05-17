suppressPackageStartupMessages({
  library(DESeq2); library(data.table); library(ggplot2)
  library(pheatmap); library(matrixStats); library(RColorBrewer)
})

# ---- Paths ----
counts_file <- Sys.getenv("COUNTS_FILE",
  "/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/FeatureCounts/FeatureCounts_host/featureCounts_host.txt")
out_dir <- Sys.getenv("OUT_DIR",
  "/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/DeSeq2_host")

padj_cut   <- as.numeric(Sys.getenv("PADJ_CUTOFF",      "0.05"))
lfc_cut    <- as.numeric(Sys.getenv("LFC_CUTOFF",       "1"))
min_total  <- as.numeric(Sys.getenv("MIN_TOTAL_COUNT",  "10"))
timepoints <- c("0h","15m","30m","60m","3h","24h")

for (d in c("objects","results","figures","logs"))
  dir.create(file.path(out_dir, d), recursive=TRUE, showWarnings=FALSE)

progress <- file.path(out_dir, "logs", "deseq2_host_progress.log")
logmsg <- function(...) {
  line <- paste0("[", format(Sys.time(), "%F %T"), "] ", paste(..., collapse=" "))
  cat(line, "\n"); cat(line, "\n", file=progress, append=TRUE)
}

save_plot <- function(p, base, w=7, h=5) {
  ggsave(paste0(base, ".pdf"), p, width=w, height=h)
  ggsave(paste0(base, ".png"), p, width=w, height=h, dpi=300)
}

# ---- 1. Read featureCounts ----
logmsg("Reading featureCounts file:", counts_file)
lines <- readLines(counts_file, warn=FALSE)
lines <- lines[!grepl("^#", lines)]
dt    <- fread(text=paste(lines, collapse="\n"), check.names=FALSE)

gene_col    <- names(dt)[1]
meta_cols   <- intersect(c("Chr","Start","End","Strand","Length"), names(dt))
count_start <- max(match(meta_cols, names(dt))) + 1
counts      <- dt[, c(gene_col, names(dt)[count_start:ncol(dt)]), with=FALSE]
setnames(counts, gene_col, "gene_id")

# Strip path and .host.merged.bam suffix -> sample key e.g. 15m_1_Run_1_S4
setnames(counts,
  setdiff(names(counts), "gene_id"),
  sub("\\.host\\.merged\\.bam$", "", basename(setdiff(names(counts), "gene_id"))))

logmsg("Genes:", nrow(counts), "| Raw sample columns:", ncol(counts) - 1)

# ---- 2. Build metadata ----
# Keep all 48 samples (Run_1 + Run_2 kept separate; run modelled as covariate)
all_samples <- setdiff(names(counts), "gene_id")

get_timepoint <- function(s) {
  ifelse(grepl("^B[0-9]+_H[0-9]+", s), "0h",
  ifelse(grepl("^1h_",             s), "60m",
         sub("_.*$", "", s)))
}

get_run <- function(s) {
  ifelse(grepl("_Run_1_", s), "Run1", "Run2")
}

get_replicate <- function(s) {
  ifelse(grepl("^B[0-9]+_H[0-9]+", s),
         sub("^B([0-9]+)_.*$", "\\1", s),
         sub("^[^_]+_([0-9]+)_Run_.*$", "\\1", s))
}

tp_norm  <- get_timepoint(all_samples)
run_grp  <- get_run(all_samples)
rep_num  <- get_replicate(all_samples)

meta <- data.table(
  sample_id = all_samples,
  timepoint = factor(tp_norm, levels=timepoints),
  run       = factor(run_grp, levels=c("Run1","Run2")),
  replicate = rep_num
)

missing_tp <- meta[is.na(timepoint), sample_id]
if (length(missing_tp)) stop("Unrecognised timepoint for: ", paste(missing_tp, collapse=", "))

fwrite(meta, file.path(out_dir, "metadata_host.tsv"), sep="\t")
logmsg("Metadata written. Samples per timepoint:")
meta[, .N, by=timepoint][order(timepoint)] |> print()
logmsg("Samples per run:")
meta[, .N, by=run] |> print()

# ---- 3. Count matrix ----
mat <- as.matrix(counts[, -"gene_id"])
storage.mode(mat) <- "integer"
rownames(mat) <- make.unique(counts$gene_id)

common <- intersect(colnames(mat), meta$sample_id)
mat    <- mat[, common, drop=FALSE]
meta   <- meta[match(common, sample_id)]

mat <- mat[rowSums(mat) >= min_total, , drop=FALSE]
logmsg("After low-count filter:", nrow(mat), "genes retained")

# ---- 4. DESeq2: design ~ run + timepoint ----
# run is modelled as a batch covariate; timepoint is the factor of interest.
# This removes systematic run-to-run differences identified in the sense check
# before testing biological timepoint effects.
logmsg("Running DESeq2  design: ~ run + timepoint")
dds <- DESeqDataSetFromMatrix(mat, as.data.frame(meta), design = ~ run + timepoint)
dds <- tryCatch(
  DESeq(dds, quiet=FALSE),
  error = function(e) {
    if (grepl("every gene contains at least one zero", conditionMessage(e), fixed=TRUE)) {
      logmsg("WARNING: retrying with poscounts size factor estimation")
      DESeq(estimateSizeFactors(dds, type="poscounts"), quiet=FALSE)
    } else stop(e)
  })

vst_obj <- tryCatch(vst(dds, blind=FALSE),
  error = function(e) {
    logmsg("WARNING: vst failed, using varianceStabilizingTransformation")
    varianceStabilizingTransformation(dds, blind=FALSE)
  })

saveRDS(dds,     file.path(out_dir, "objects", "host_dds.rds"))
saveRDS(vst_obj, file.path(out_dir, "objects", "host_vst.rds"))
fwrite(as.data.table(counts(dds, normalized=TRUE), keep.rownames="gene_id"),
       file.path(out_dir, "results", "host_normalised_counts.tsv"), sep="\t")
logmsg("DESeq2 model fitted and saved")

# ---- 5. All pairwise timepoint comparisons ----
logmsg("Running all pairwise timepoint comparisons")
pairs    <- t(combn(timepoints, 2))
manifest <- list(); k <- 0

for (i in seq_len(nrow(pairs))) for (dirn in 1:2) {
  a <- pairs[i, ifelse(dirn==1, 1, 2)]
  b <- pairs[i, ifelse(dirn==1, 2, 1)]
  if (!a %in% levels(meta$timepoint) || !b %in% levels(meta$timepoint)) next
  cname <- paste0("host_", a, "_vs_", b)
  res   <- results(dds, contrast=c("timepoint", a, b), alpha=padj_cut)
  tab   <- as.data.table(res, keep.rownames="gene_id")
  tab[, comparison := cname]
  tab[, rank_metric := fifelse(is.na(stat),
        sign(log2FoldChange) * -log10(pmax(pvalue, .Machine$double.xmin)), stat)]
  setorder(tab, padj)
  sig  <- tab[!is.na(padj) & padj < padj_cut & abs(log2FoldChange) >= lfc_cut]
  up   <- sig[log2FoldChange > 0]
  down <- sig[log2FoldChange < 0]
  fwrite(tab,  file.path(out_dir, "results", paste0(cname, "_DESeq2_results.tsv")),     sep="\t")
  fwrite(sig,  file.path(out_dir, "results", paste0(cname, "_significant_genes.tsv")),  sep="\t")
  fwrite(up,   file.path(out_dir, "results", paste0(cname, "_upregulated_genes.tsv")),  sep="\t")
  fwrite(down, file.path(out_dir, "results", paste0(cname, "_downregulated_genes.tsv")), sep="\t")
  fwrite(tab[!is.na(rank_metric), .(gene_id, rank_metric)][order(-rank_metric)],
         file.path(out_dir, "results", paste0(cname, "_ranked_for_GSEA.rnk")), sep="\t", col.names=FALSE)
  k <- k + 1
  manifest[[k]] <- data.table(comparison=cname, numerator=a, denominator=b,
                               n_all=nrow(tab), n_sig=nrow(sig), n_up=nrow(up), n_down=nrow(down))
}
fwrite(rbindlist(manifest), file.path(out_dir, "results", "host_comparison_manifest.tsv"), sep="\t")
logmsg("Pairwise comparisons complete: k=", k)

# ---- 6. LRT (global time effect, controlling for run) ----
logmsg("Running LRT for global time effect (reduced: ~ run)")
lrt <- tryCatch({
  ddsl <- DESeq(dds, test="LRT", reduced=~run, quiet=TRUE)
  as.data.table(results(ddsl), keep.rownames="gene_id")
}, error=function(e) { logmsg("WARNING: LRT failed:", conditionMessage(e)); data.table() })
if (nrow(lrt)) fwrite(lrt, file.path(out_dir, "results", "host_global_time_LRT.tsv"), sep="\t")

# ---- 7. Figures ----
logmsg("Generating QC figures")
mat_vst  <- assay(vst_obj)
meta_vst <- as.data.table(as.data.frame(colData(vst_obj)))

# PCA
pc  <- prcomp(t(mat_vst))
var <- round(100 * pc$sdev^2 / sum(pc$sdev^2), 1)
pcdf <- data.table(sample_id=rownames(pc$x), PC1=pc$x[,1], PC2=pc$x[,2])
pcdf <- merge(pcdf, meta_vst, by="sample_id")

p_pca_tp <- ggplot(pcdf, aes(PC1, PC2, colour=timepoint, shape=run)) +
  geom_point(size=3) +
  stat_ellipse(aes(group=timepoint), linewidth=0.3) +
  theme_bw() + scale_colour_brewer(palette="Dark2") +
  labs(title="Host PCA — coloured by timepoint, shaped by run",
       subtitle="Design: ~ run + timepoint (run covariate corrects batch effect)",
       x=paste0("PC1 (", var[1], "%)"), y=paste0("PC2 (", var[2], "%)"))
save_plot(p_pca_tp, file.path(out_dir, "figures", "host_PCA_by_timepoint"), 8, 6)

p_pca_run <- ggplot(pcdf, aes(PC1, PC2, colour=run, shape=timepoint)) +
  geom_point(size=3) +
  scale_colour_manual(values=c(Run1="#E41A1C", Run2="#377EB8")) +
  theme_bw() +
  labs(title="Host PCA — coloured by run (batch)",
       x=paste0("PC1 (", var[1], "%)"), y=paste0("PC2 (", var[2], "%)"))
save_plot(p_pca_run, file.path(out_dir, "figures", "host_PCA_by_run"), 7, 5)

pdf(file.path(out_dir, "figures", "host_sample_distance_heatmap.pdf"), width=10, height=9)
pheatmap(as.matrix(dist(t(mat_vst))),
         annotation_col = as.data.frame(meta_vst[, .(timepoint, run)], row.names=meta_vst$sample_id),
         annotation_colors = list(
           run = c(Run1="#E41A1C", Run2="#377EB8"),
           timepoint = setNames(RColorBrewer::brewer.pal(6,"Dark2"), timepoints)),
         main="Host sample distances (VST, ~ run + timepoint)")
dev.off()

top_vars <- head(order(rowVars(mat_vst), decreasing=TRUE), 50)
pdf(file.path(out_dir, "figures", "host_top_variable_genes_heatmap.pdf"), width=10, height=12)
pheatmap(mat_vst[top_vars, ], scale="row", show_rownames=TRUE, fontsize_row=6,
         annotation_col = as.data.frame(meta_vst[, .(timepoint, run)], row.names=meta_vst$sample_id),
         main="Host top 50 variable genes")
dev.off()

# Volcano plots for vs-0h comparisons
for (tp in setdiff(timepoints, "0h")) {
  f <- file.path(out_dir, "results", paste0("host_0h_vs_", tp, "_DESeq2_results.tsv"))
  if (!file.exists(f)) next
  tab <- fread(f)
  tab[, status := fifelse(!is.na(padj) & padj < padj_cut & log2FoldChange >=  lfc_cut, "Up",
                   fifelse(!is.na(padj) & padj < padj_cut & log2FoldChange <= -lfc_cut, "Down", "NS"))]
  n_up   <- tab[status == "Up",   .N]
  n_down <- tab[status == "Down", .N]
  n_ns   <- tab[status == "NS",   .N]
  p_vol <- ggplot(tab, aes(log2FoldChange, -log10(pmax(padj, 1e-300)), colour=status)) +
    geom_point(alpha=0.6, size=0.8) +
    scale_colour_manual(values=c(Up="#B2182B", Down="#2166AC", NS="grey75")) +
    geom_hline(yintercept=-log10(padj_cut), linetype="dashed", colour="grey50") +
    geom_vline(xintercept=c(-lfc_cut, lfc_cut), linetype="dashed", colour="grey50") +
    annotate("text", x= Inf, y=Inf, hjust=1.1, vjust=1.5, label=paste0("Up: ",   n_up),   colour="#B2182B", size=3.5) +
    annotate("text", x=-Inf, y=Inf, hjust=-0.1, vjust=1.5, label=paste0("Down: ", n_down), colour="#2166AC", size=3.5) +
    annotate("text", x=0,    y=Inf, hjust=0.5,  vjust=3,   label=paste0("NS: ",   n_ns),   colour="grey50",  size=3.5) +
    theme_bw() +
    labs(title=paste("Host 0h vs", tp, "(run batch-corrected)"),
         subtitle="DESeq2 design: ~ run + timepoint",
         x="log2 fold change (0h / time)", y="-log10 adjusted p-value", colour=NULL)
  save_plot(p_vol, file.path(out_dir, "figures", paste0("host_0h_vs_", tp, "_volcano")), 7, 5)
}

logmsg("Host DESeq2 analysis complete. Results in:", out_dir)
