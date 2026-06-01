suppressPackageStartupMessages({
  library(DESeq2); library(data.table); library(ggplot2)
  library(pheatmap); library(RColorBrewer); library(matrixStats)
})

# ---- Paths ----
counts_file <- Sys.getenv("COUNTS_FILE",
  "/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/filtering/bacteria/bacteria_filtered_counts.tsv")
meta_file <- Sys.getenv("META_FILE",
  "/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/filtering/bacteria/bacteria_metadata.tsv")
out_dir <- Sys.getenv("OUT_DIR",
  "/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/normalisation/bacteria")

timepoints <- c("0h", "15m", "30m", "60m", "3h", "24h")

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(out_dir, "figures"), recursive = TRUE, showWarnings = FALSE)

log_file <- file.path(out_dir, "normalise_bacteria.log")
logmsg <- function(...) {
  line <- paste0("[", format(Sys.time(), "%F %T"), "] ", paste(..., collapse = " "))
  cat(line, "\n")
  cat(line, "\n", file = log_file, append = TRUE)
}
save_plot <- function(p, base, w = 7, h = 5) {
  ggsave(paste0(base, ".pdf"), p, width = w, height = h)
  ggsave(paste0(base, ".png"), p, width = w, height = h, dpi = 300)
}

logmsg("=== Bacteria normalisation ===")
logmsg("Counts:", counts_file)
logmsg("Metadata:", meta_file)

# ---- 1. Load inputs ----
counts_dt <- fread(counts_file)
meta      <- fread(meta_file)

meta[, timepoint := factor(timepoint, levels = timepoints)]
meta[, run       := factor(run,       levels = c("Run1", "Run2"))]

mat <- as.matrix(counts_dt[, -"gene_id"])
storage.mode(mat) <- "integer"
rownames(mat) <- counts_dt$gene_id

common <- intersect(colnames(mat), meta$sample_id)
mat    <- mat[, common, drop = FALSE]
meta   <- meta[match(common, sample_id)]

logmsg("Matrix:", nrow(mat), "genes x", ncol(mat), "samples")
logmsg("Design: ~ run + timepoint")

# ---- 2. DESeq2 object ----
dds <- DESeqDataSetFromMatrix(mat, as.data.frame(meta), design = ~ run + timepoint)

# Bacteria data often has zeros across many samples; poscounts is more robust
dds <- tryCatch(
  estimateSizeFactors(dds),
  error = function(e) {
    logmsg("WARNING: standard size factors failed, switching to poscounts")
    estimateSizeFactors(dds, type = "poscounts")
  }
)

sf <- sizeFactors(dds)
sf_dt <- data.table(sample_id = names(sf), size_factor = sf)
sf_dt <- merge(sf_dt, meta, by = "sample_id")
fwrite(sf_dt, file.path(out_dir, "bacteria_size_factors.tsv"), sep = "\t")
logmsg("Size factor range:", round(min(sf), 3), "–", round(max(sf), 3))

# ---- 3. Normalised counts (median-of-ratios) ----
norm_mat <- counts(dds, normalized = TRUE)
norm_dt  <- as.data.table(norm_mat, keep.rownames = "gene_id")
fwrite(norm_dt, file.path(out_dir, "bacteria_normalised_counts.tsv"), sep = "\t")
logmsg("Normalised counts written")

# ---- 4. VST ----
dds <- estimateDispersions(dds, quiet = TRUE)
vst_obj <- tryCatch(
  vst(dds, blind = FALSE),
  error = function(e) {
    logmsg("WARNING: vst failed, using varianceStabilizingTransformation")
    varianceStabilizingTransformation(dds, blind = FALSE)
  }
)
vst_mat <- assay(vst_obj)
vst_dt  <- as.data.table(vst_mat, keep.rownames = "gene_id")
fwrite(vst_dt, file.path(out_dir, "bacteria_vst.tsv"), sep = "\t")
logmsg("VST matrix written")

saveRDS(dds,     file.path(out_dir, "bacteria_dds.rds"))
saveRDS(vst_obj, file.path(out_dir, "bacteria_vst.rds"))

# ---- 5. Figures ----
logmsg("Generating QC figures")

# 5a. Size factor bar chart
sf_dt[, sample_id := factor(sample_id, levels = sample_id[order(timepoint, replicate, run)])]
p_sf <- ggplot(sf_dt, aes(sample_id, size_factor, fill = timepoint, alpha = run)) +
  geom_col() +
  geom_hline(yintercept = 1, linetype = "dashed", colour = "grey40") +
  scale_fill_brewer(palette = "Dark2") +
  scale_alpha_manual(values = c(Run1 = 1, Run2 = 0.55)) +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 6)) +
  labs(title = "Bacteria: DESeq2 size factors",
       x = NULL, y = "Size factor", fill = "Timepoint", alpha = "Run")
save_plot(p_sf, file.path(out_dir, "figures", "bacteria_size_factors"), 10, 5)

# 5b. Boxplot of log2 normalised counts per sample
log2_norm <- log2(norm_mat + 1)
box_dt <- melt(as.data.table(log2_norm, keep.rownames = "gene_id"),
               id.vars = "gene_id", variable.name = "sample_id", value.name = "log2_norm")
box_dt <- merge(box_dt, meta, by = "sample_id")
box_dt[, sample_id := factor(sample_id, levels = common[order(meta$timepoint, meta$replicate, meta$run)])]

p_box <- ggplot(box_dt, aes(sample_id, log2_norm, fill = timepoint, alpha = run)) +
  geom_boxplot(outlier.shape = NA) +
  scale_fill_brewer(palette = "Dark2") +
  scale_alpha_manual(values = c(Run1 = 1, Run2 = 0.55)) +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 6)) +
  labs(title = "Bacteria: log2 normalised counts per sample",
       x = NULL, y = "log2(normalised counts + 1)", fill = "Timepoint", alpha = "Run")
save_plot(p_box, file.path(out_dir, "figures", "bacteria_normalised_boxplot"), 12, 5)

# 5c. PCA on VST
pc  <- prcomp(t(vst_mat))
var <- round(100 * pc$sdev^2 / sum(pc$sdev^2), 1)
pca_dt <- data.table(sample_id = rownames(pc$x), PC1 = pc$x[, 1], PC2 = pc$x[, 2])
pca_dt <- merge(pca_dt, meta, by = "sample_id")

p_pca <- ggplot(pca_dt, aes(PC1, PC2, colour = timepoint, shape = run)) +
  geom_point(size = 3) +
  stat_ellipse(aes(group = timepoint), linewidth = 0.3) +
  scale_colour_brewer(palette = "Dark2") +
  theme_bw() +
  labs(title = "Bacteria PCA (VST, design: ~ run + timepoint)",
       x = paste0("PC1 (", var[1], "%)"), y = paste0("PC2 (", var[2], "%)"))
save_plot(p_pca, file.path(out_dir, "figures", "bacteria_PCA"), 8, 6)

# 5d. Sample distance heatmap
meta_df <- as.data.frame(meta[, .(timepoint, run)], row.names = meta$sample_id)
ann_col <- list(
  run       = c(Run1 = "#E41A1C", Run2 = "#377EB8"),
  timepoint = setNames(RColorBrewer::brewer.pal(6, "Dark2"), timepoints)
)
pdf(file.path(out_dir, "figures", "bacteria_sample_distances.pdf"), width = 10, height = 9)
pheatmap(as.matrix(dist(t(vst_mat))),
         annotation_col  = meta_df,
         annotation_colors = ann_col,
         main = "Bacteria sample distances (VST)")
dev.off()

# 5e. Top 50 variable genes heatmap
top50 <- head(order(rowVars(vst_mat), decreasing = TRUE), 50)
pdf(file.path(out_dir, "figures", "bacteria_top50_variable_genes.pdf"), width = 9, height = 11)
pheatmap(vst_mat[top50, ], scale = "row", show_rownames = TRUE, fontsize_row = 6,
         annotation_col  = meta_df,
         annotation_colors = ann_col,
         main = "Bacteria top 50 variable genes (VST, row-scaled)")
dev.off()

logmsg("Figures saved")
logmsg("=== Bacteria normalisation complete ===")
