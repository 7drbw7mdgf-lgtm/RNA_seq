suppressPackageStartupMessages({
  library(DESeq2); library(data.table); library(ggplot2)
  library(pheatmap); library(RColorBrewer)
})

# ---- Paths ----------------------------------------------------------------
counts_file <- Sys.getenv("COUNTS_FILE",
  "/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/FeatureCounts/FeatureCounts_host/featureCounts_host.txt")
out_dir <- Sys.getenv("OUT_DIR",
  "/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Sense_check_host")

# Timepoint to use for the technical-replicate sense check
tp_use    <- Sys.getenv("TIMEPOINT",       "0h")
padj_cut  <- as.numeric(Sys.getenv("PADJ_CUTOFF",     "0.05"))
lfc_cut   <- as.numeric(Sys.getenv("LFC_CUTOFF",      "1"))
min_total <- as.numeric(Sys.getenv("MIN_TOTAL_COUNT", "10"))

for (d in c("objects","results","figures","logs"))
  dir.create(file.path(out_dir, d), recursive=TRUE, showWarnings=FALSE)

progress <- file.path(out_dir, "logs", "deseq2_sense_check_host.log")
logmsg <- function(...) {
  line <- paste0("[", format(Sys.time(), "%F %T"), "] ", paste(..., collapse=" "))
  cat(line, "\n"); cat(line, "\n", file=progress, append=TRUE)
}
save_plot <- function(p, base, w=7, h=5) {
  ggplot2::ggsave(paste0(base, ".pdf"), p, width=w, height=h)
  ggplot2::ggsave(paste0(base, ".png"), p, width=w, height=h, dpi=300)
}

logmsg("Host sense-check: technical replicate comparison for timepoint =", tp_use)
logmsg("Reading:", counts_file)

# ---- 1. Read featureCounts ------------------------------------------------
lines <- readLines(counts_file, warn=FALSE)
lines <- lines[!grepl("^#", lines)]
dt    <- fread(text=paste(lines, collapse="\n"), check.names=FALSE)

gene_col  <- names(dt)[1]
meta_cols <- intersect(c("Chr","Start","End","Strand","Length"), names(dt))
cnt_start <- max(match(meta_cols, names(dt))) + 1
counts    <- dt[, c(gene_col, names(dt)[cnt_start:ncol(dt)]), with=FALSE]
setnames(counts, gene_col, "gene_id")

# Strip full BAM path -> keep sample key
setnames(counts,
  setdiff(names(counts), "gene_id"),
  sub("\\.host\\.merged\\.bam$", "",
      basename(setdiff(names(counts), "gene_id"))))

logmsg("Total genes:", nrow(counts), "| Total samples:", ncol(counts)-1)

# ---- 2. Select samples for the chosen timepoint --------------------------
#
# Naming convention (mirrors bacteria):
#   0h uninfected controls : B1_H1_Run_1_S3, B2_H2_Run_2_S33 ...
#   Infected timepoints    : 15m_1_Run_1_S4, 30m_2_Run_2_S35 ...
#
all_samples <- setdiff(names(counts), "gene_id")

if (tp_use == "0h") {
  keep <- grep("^B[0-9]+_H[0-9]+_Run_", all_samples, value=TRUE)
} else {
  pat  <- paste0("^", tp_use, "_[0-9]+_Run_")
  keep <- grep(pat, all_samples, value=TRUE)
}

if (length(keep) == 0)
  stop("No samples found for timepoint '", tp_use,
       "'. Available: ", paste(all_samples, collapse=", "))

logmsg("Samples selected for", tp_use, ":", length(keep))
logmsg(paste(keep, collapse=", "))

sub_counts <- counts[, c("gene_id", keep), with=FALSE]

# ---- 3. Build metadata (group = Run1 vs Run2) ----------------------------
run_group <- ifelse(grepl("_Run_1_", keep), "Run1", "Run2")
meta <- data.table(
  sample_id = keep,
  run       = factor(run_group, levels=c("Run1","Run2"))
)

n_run1 <- sum(meta$run == "Run1")
n_run2 <- sum(meta$run == "Run2")
logmsg("Run1 samples:", n_run1, "| Run2 samples:", n_run2)

if (n_run1 < 2 || n_run2 < 2)
  stop("Need >=2 samples per run group. Got Run1=", n_run1, " Run2=", n_run2)

fwrite(meta, file.path(out_dir, "metadata_sense_check.tsv"), sep="\t")

# ---- 4. Count matrix -----------------------------------------------------
mat <- as.matrix(sub_counts[, -"gene_id"])
storage.mode(mat) <- "integer"
rownames(mat) <- make.unique(sub_counts$gene_id)
mat <- mat[rowSums(mat) >= min_total, , drop=FALSE]
logmsg("After low-count filter:", nrow(mat), "genes retained")

# ---- 5. DESeq2: ~ run ----------------------------------------------------
logmsg("Running DESeq2  design: ~ run  (Run1 vs Run2, technical replicate check)")
dds <- DESeqDataSetFromMatrix(mat, as.data.frame(meta), design = ~run)
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

saveRDS(dds,     file.path(out_dir, "objects", paste0(tp_use, "_run_dds.rds")))
saveRDS(vst_obj, file.path(out_dir, "objects", paste0(tp_use, "_run_vst.rds")))
fwrite(as.data.table(counts(dds, normalized=TRUE), keep.rownames="gene_id"),
       file.path(out_dir, "results", paste0(tp_use, "_normalised_counts.tsv")), sep="\t")
logmsg("DESeq2 model fitted")

# ---- 6. Results: Run1 vs Run2 --------------------------------------------
res <- results(dds, contrast=c("run","Run1","Run2"), alpha=padj_cut)
tab <- as.data.table(res, keep.rownames="gene_id")
tab[, comparison := paste0(tp_use, "_Run1_vs_Run2")]
tab[, rank_metric := fifelse(is.na(stat),
      sign(log2FoldChange) * -log10(pmax(pvalue, .Machine$double.xmin)), stat)]
setorder(tab, padj)

sig  <- tab[!is.na(padj) & padj < padj_cut & abs(log2FoldChange) >= lfc_cut]
up   <- sig[log2FoldChange > 0]
down <- sig[log2FoldChange < 0]

cname <- paste0(tp_use, "_Run1_vs_Run2")
fwrite(tab,  file.path(out_dir, "results", paste0(cname, "_DESeq2_results.tsv")),     sep="\t")
fwrite(sig,  file.path(out_dir, "results", paste0(cname, "_significant_genes.tsv")),  sep="\t")
fwrite(up,   file.path(out_dir, "results", paste0(cname, "_upregulated_genes.tsv")),  sep="\t")
fwrite(down, file.path(out_dir, "results", paste0(cname, "_downregulated_genes.tsv")), sep="\t")

logmsg("Results: n_sig=", nrow(sig), " Up=", nrow(up), " Down=", nrow(down))
logmsg("(Low DE expected — runs should be technically consistent)")

# ---- 7. Figures ----------------------------------------------------------
logmsg("Generating figures")
mat_vst  <- assay(vst_obj)
meta_vst <- as.data.table(as.data.frame(colData(vst_obj)))

# PCA
pc  <- prcomp(t(mat_vst))
var <- round(100 * pc$sdev^2 / sum(pc$sdev^2), 1)
pcdf <- data.table(sample_id=rownames(pc$x), PC1=pc$x[,1], PC2=pc$x[,2])
pcdf <- merge(pcdf, meta_vst, by="sample_id")

p_pca <- ggplot(pcdf, aes(PC1, PC2, colour=run, label=sample_id)) +
  geom_point(size=4) +
  tryCatch(
    ggrepel::geom_text_repel(size=2.5, max.overlaps=20),
    error=function(e) geom_text(size=2.5, vjust=-0.8)
  ) +
  scale_colour_manual(values=c(Run1="#E41A1C", Run2="#377EB8")) +
  theme_bw() +
  labs(title=paste0("Host sense-check PCA — ", tp_use, " (Run1 vs Run2)"),
       x=paste0("PC1 (", var[1], "%)"), y=paste0("PC2 (", var[2], "%)"),
       colour="Run")
save_plot(p_pca, file.path(out_dir, "figures", paste0(tp_use, "_run_PCA")))

# Sample distance heatmap
pdf(file.path(out_dir, "figures", paste0(tp_use, "_run_sample_distances.pdf")),
    width=7, height=6)
pheatmap(as.matrix(dist(t(mat_vst))),
         annotation_col  = as.data.frame(meta_vst[, .(run)],
                                          row.names=meta_vst$sample_id),
         annotation_colors = list(run=c(Run1="#E41A1C", Run2="#377EB8")),
         main=paste0("Host sample distances — ", tp_use, " (Run1 vs Run2)"))
dev.off()

# Volcano plot
tab[, status := fifelse(!is.na(padj) & padj < padj_cut & log2FoldChange >=  lfc_cut, "Up",
                 fifelse(!is.na(padj) & padj < padj_cut & log2FoldChange <= -lfc_cut, "Down", "NS"))]
n_up   <- tab[status == "Up",   .N]
n_down <- tab[status == "Down", .N]
n_ns   <- tab[status == "NS",   .N]

p_vol <- ggplot(tab, aes(log2FoldChange, -log10(pmax(padj, 1e-300)), colour=status)) +
  geom_point(alpha=0.65, size=1) +
  scale_colour_manual(values=c(Up="#B2182B", Down="#2166AC", NS="grey75")) +
  geom_hline(yintercept=-log10(padj_cut), linetype="dashed", colour="grey50") +
  geom_vline(xintercept=c(-lfc_cut, lfc_cut), linetype="dashed", colour="grey50") +
  annotate("text", x= Inf, y=Inf, hjust=1.1, vjust=1.5,
           label=paste0("Up: ",   n_up),   colour="#B2182B", size=3.5) +
  annotate("text", x=-Inf, y=Inf, hjust=-0.1, vjust=1.5,
           label=paste0("Down: ", n_down), colour="#2166AC", size=3.5) +
  annotate("text", x=0,    y=Inf, hjust=0.5, vjust=3,
           label=paste0("NS: ", n_ns), colour="grey50", size=3.5) +
  theme_bw() +
  labs(title=paste0("Technical replicate sense-check (Host): ", tp_use, "  Run1 vs Run2"),
       subtitle="Expect minimal DE if runs are technically consistent",
       x="log2 fold change (Run1 / Run2)",
       y="-log10 adjusted p-value",
       colour=NULL)
save_plot(p_vol,
          file.path(out_dir, "figures", paste0(tp_use, "_Run1_vs_Run2_volcano")),
          7, 5)
logmsg("Volcano saved:", paste0(tp_use, "_Run1_vs_Run2_volcano"))

logmsg("Host sense-check complete. Results in:", out_dir)
