suppressPackageStartupMessages({
  library(DESeq2); library(data.table); library(ggplot2)
  library(pheatmap); library(matrixStats); library(RColorBrewer)
})

# ---- Paths ----
counts_file <- Sys.getenv("COUNTS_FILE",
  "/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/FeatureCounts/FeatureCounts_bacteria/featureCounts_bacteria.txt")
out_dir <- Sys.getenv("OUT_DIR",
  "/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/DeSeq2_bacteria")

padj_cut   <- as.numeric(Sys.getenv("PADJ_CUTOFF",  "0.05"))
lfc_cut    <- as.numeric(Sys.getenv("LFC_CUTOFF",   "1"))
min_total  <- as.numeric(Sys.getenv("MIN_TOTAL_COUNT", "10"))
timepoints <- c("0h","15m","30m","60m","3h","24h")

dir.create(file.path(out_dir,"objects"),  recursive=TRUE, showWarnings=FALSE)
dir.create(file.path(out_dir,"results"),  recursive=TRUE, showWarnings=FALSE)
dir.create(file.path(out_dir,"figures"),  recursive=TRUE, showWarnings=FALSE)
dir.create(file.path(out_dir,"logs"),     recursive=TRUE, showWarnings=FALSE)

progress <- file.path(out_dir,"logs","deseq2_progress.log")
logmsg <- function(...) {
  line <- paste0("[",format(Sys.time(),"%F %T"),"] ", paste(..., collapse=" "))
  cat(line, "\n"); cat(line, "\n", file=progress, append=TRUE)
}

save_plot <- function(p, base, w=7, h=5) {
  ggsave(paste0(base,".pdf"), p, width=w, height=h)
  ggsave(paste0(base,".png"), p, width=w, height=h, dpi=300)
}

# ---- 1. Read featureCounts output ----
logmsg("Reading featureCounts file:", counts_file)
lines <- readLines(counts_file, warn=FALSE)
lines <- lines[!grepl("^#", lines)]
dt <- fread(text=paste(lines, collapse="\n"), check.names=FALSE)

gene_col  <- names(dt)[1]
meta_cols <- intersect(c("Chr","Start","End","Strand","Length"), names(dt))
count_start <- max(match(meta_cols, names(dt))) + 1
counts <- dt[, c(gene_col, names(dt)[count_start:ncol(dt)]), with=FALSE]
setnames(counts, gene_col, "gene_id")

# Clean column names: strip full path and .bacteria.merged.bam suffix
setnames(counts,
  setdiff(names(counts), "gene_id"),
  sub("\\.bacteria\\.merged\\.bam$", "", basename(setdiff(names(counts), "gene_id"))))

logmsg("Genes:", nrow(counts), "| Raw sample columns:", ncol(counts)-1)

# ---- 2. Collapse Run_1 / Run_2 into one column per biological sample ----
sample_cols <- setdiff(names(counts), "gene_id")
bio_id      <- sub("_Run_.*$", "", sample_cols)

logmsg("Collapsing", length(sample_cols), "run columns into", length(unique(bio_id)), "biological samples")

collapsed <- counts[, .(gene_id)]
for (uid in unique(bio_id)) {
  cols <- sample_cols[bio_id == uid]
  collapsed[[uid]] <- if (length(cols)==1L) counts[[cols]] else rowSums(counts[, cols, with=FALSE])
}
logmsg("Collapsed count matrix:", nrow(collapsed), "genes x", ncol(collapsed)-1, "samples")

# ---- 3. Build metadata ----
bio_samples <- setdiff(names(collapsed), "gene_id")

# B1_H1 / B2_H2 etc. are uninfected bacterial controls -> 0h
# All other samples: first token before _ is the timepoint
get_timepoint <- function(s) {
  tp <- ifelse(grepl("^B[0-9]+_H[0-9]+", s), "0h",
         ifelse(grepl("^1h_",             s), "60m",
                sub("_.*$", "", s)))
  tp
}

# Extract numeric replicate: B1_H1 -> 1, 15m_2 -> 2
get_replicate <- function(s) {
  ifelse(grepl("^B[0-9]+_H[0-9]+", s),
         sub("^B([0-9]+)_.*$", "\\1", s),
         sub("^[^_]+_", "", s))
}

tp_norm <- get_timepoint(bio_samples)
rep_num <- get_replicate(bio_samples)

meta <- data.table(
  sample_id  = bio_samples,
  timepoint  = factor(tp_norm, levels=timepoints),
  replicate  = rep_num
)

missing_tp <- meta[is.na(timepoint), sample_id]
if (length(missing_tp)) stop("Unrecognised timepoint for samples: ", paste(missing_tp, collapse=", "))

fwrite(meta, file.path(out_dir,"metadata.tsv"), sep="\t")
logmsg("Metadata written:", file.path(out_dir,"metadata.tsv"))
logmsg("Samples per timepoint:")
meta[, .N, by=timepoint][order(timepoint)] |> print()

# ---- 4. Build count matrix ----
mat <- as.matrix(collapsed[, -"gene_id"])
storage.mode(mat) <- "integer"
rownames(mat) <- make.unique(collapsed$gene_id)

common <- intersect(colnames(mat), meta$sample_id)
mat    <- mat[, common, drop=FALSE]
meta   <- meta[match(common, sample_id)]

mat <- mat[rowSums(mat) >= min_total, , drop=FALSE]
logmsg("After low-count filter:", nrow(mat), "genes retained")

# ---- 5. DESeq2 ----
logmsg("Running DESeq2  design: ~ timepoint")
dds <- DESeqDataSetFromMatrix(mat, as.data.frame(meta), design = ~timepoint)
dds <- tryCatch(
  DESeq(dds, quiet=FALSE),
  error = function(e) {
    if (grepl("every gene contains at least one zero", conditionMessage(e), fixed=TRUE)) {
      logmsg("WARNING: retrying size factor estimation with type=poscounts")
      dds2 <- estimateSizeFactors(dds, type="poscounts")
      DESeq(dds2, quiet=FALSE)
    } else stop(e)
  })

vst_obj <- tryCatch(
  vst(dds, blind=FALSE),
  error = function(e) {
    logmsg("WARNING: vst failed, using varianceStabilizingTransformation")
    varianceStabilizingTransformation(dds, blind=FALSE)
  })

saveRDS(dds,     file.path(out_dir,"objects","bacteria_dds.rds"))
saveRDS(vst_obj, file.path(out_dir,"objects","bacteria_vst.rds"))
fwrite(as.data.table(counts(dds, normalized=TRUE), keep.rownames="gene_id"),
       file.path(out_dir,"results","bacteria_normalised_counts.tsv"), sep="\t")
logmsg("DESeq2 model fitted and saved")

# ---- 6. All pairwise comparisons ----
logmsg("Running all pairwise timepoint comparisons")
pairs    <- t(combn(timepoints, 2))
manifest <- list(); k <- 0

for (i in seq_len(nrow(pairs))) for (dirn in 1:2) {
  a <- pairs[i, ifelse(dirn==1,1,2)]
  b <- pairs[i, ifelse(dirn==1,2,1)]
  if (!a %in% levels(meta$timepoint) || !b %in% levels(meta$timepoint)) next
  cname <- paste0("bacteria_",a,"_vs_",b)
  res   <- results(dds, contrast=c("timepoint",a,b), alpha=padj_cut)
  tab   <- as.data.table(res, keep.rownames="gene_id")
  tab[, comparison := cname]
  tab[, rank_metric := fifelse(is.na(stat),
        sign(log2FoldChange) * -log10(pmax(pvalue, .Machine$double.xmin)), stat)]
  setorder(tab, padj)
  sig  <- tab[!is.na(padj) & padj < padj_cut & abs(log2FoldChange) >= lfc_cut]
  up   <- sig[log2FoldChange > 0]
  down <- sig[log2FoldChange < 0]
  fwrite(tab,  file.path(out_dir,"results",paste0(cname,"_DESeq2_results.tsv")),    sep="\t")
  fwrite(sig,  file.path(out_dir,"results",paste0(cname,"_significant_genes.tsv")), sep="\t")
  fwrite(up,   file.path(out_dir,"results",paste0(cname,"_upregulated_genes.tsv")), sep="\t")
  fwrite(down, file.path(out_dir,"results",paste0(cname,"_downregulated_genes.tsv")),sep="\t")
  fwrite(tab[!is.na(rank_metric), .(gene_id,rank_metric)][order(-rank_metric)],
         file.path(out_dir,"results",paste0(cname,"_ranked_for_GSEA.rnk")), sep="\t", col.names=FALSE)
  k <- k+1
  manifest[[k]] <- data.table(comparison=cname, numerator=a, denominator=b,
                               n_all=nrow(tab), n_sig=nrow(sig), n_up=nrow(up), n_down=nrow(down))
}
fwrite(rbindlist(manifest), file.path(out_dir,"results","bacteria_comparison_manifest.tsv"), sep="\t")
logmsg("Pairwise comparisons complete: k=", k)

# ---- 7. LRT (global time effect) ----
logmsg("Running LRT for global time effect")
lrt <- tryCatch({
  ddsl <- DESeq(dds, test="LRT", reduced=~1, quiet=TRUE)
  as.data.table(results(ddsl), keep.rownames="gene_id")
}, error=function(e){ logmsg("WARNING: LRT failed:", conditionMessage(e)); data.table() })
if (nrow(lrt)) fwrite(lrt, file.path(out_dir,"results","bacteria_global_time_LRT.tsv"), sep="\t")

# ---- 8. Figures ----
logmsg("Generating QC figures")
mat_vst <- assay(vst_obj)
meta_vst <- as.data.table(as.data.frame(colData(vst_obj)))

pc  <- prcomp(t(mat_vst))
var <- round(100*pc$sdev^2/sum(pc$sdev^2), 1)
pcdf <- data.table(sample_id=rownames(pc$x), PC1=pc$x[,1], PC2=pc$x[,2])
pcdf <- merge(pcdf, meta_vst, by="sample_id")

p_pca <- ggplot(pcdf, aes(PC1, PC2, colour=timepoint)) +
  geom_point(size=3) +
  stat_ellipse(aes(group=timepoint), linewidth=.3) +
  theme_bw() + scale_colour_brewer(palette="Dark2") +
  labs(title="Bacteria PCA", x=paste0("PC1 (",var[1],"%)"), y=paste0("PC2 (",var[2],"%)"))
save_plot(p_pca, file.path(out_dir,"figures","bacteria_PCA"))

pdf(file.path(out_dir,"figures","bacteria_sample_distance_heatmap.pdf"), width=8, height=7)
pheatmap(as.matrix(dist(t(mat_vst))), main="Bacteria sample distances")
dev.off()

top_vars <- head(order(rowVars(mat_vst), decreasing=TRUE), 50)
pdf(file.path(out_dir,"figures","bacteria_top_variable_genes_heatmap.pdf"), width=8, height=10)
pheatmap(mat_vst[top_vars,], scale="row", show_rownames=TRUE,
         fontsize_row=6, main="Bacteria top 50 variable genes")
dev.off()

# Volcano plots for vs-0h comparisons
for (tp in setdiff(timepoints,"0h")) {
  f <- file.path(out_dir,"results",paste0("bacteria_0h_vs_",tp,"_DESeq2_results.tsv"))
  if (!file.exists(f)) next
  tab <- fread(f)
  tab[, status := fifelse(!is.na(padj)&padj<padj_cut&log2FoldChange>= lfc_cut,"Up",
                   fifelse(!is.na(padj)&padj<padj_cut&log2FoldChange<=-lfc_cut,"Down","NS"))]
  p_vol <- ggplot(tab, aes(log2FoldChange, -log10(pmax(padj,1e-300)), colour=status)) +
    geom_point(alpha=.6, size=.8) +
    scale_colour_manual(values=c(Up="#B2182B",Down="#2166AC",NS="grey75")) +
    theme_bw() +
    labs(title=paste("Bacteria 0h vs",tp), x="log2 fold change", y="-log10 adjusted p-value")
  save_plot(p_vol, file.path(out_dir,"figures",paste0("bacteria_0h_vs_",tp,"_volcano")), 6, 5)
}

logmsg("DESeq2 analysis complete. Results in:", out_dir)
