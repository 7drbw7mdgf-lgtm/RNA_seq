suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(cluster)
  library(pheatmap)
  library(umap)
  library(clusterProfiler)
  library(RColorBrewer)
})

# ---- Paths ----
deseq2_dir <- Sys.getenv("DESEQ2_RESULTS_DIR",
  "/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/DeSeq2_bacteria/results")
ora_dir    <- Sys.getenv("ORA_DIR",
  "/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Ensembl_ORA_bacteria")
out_dir    <- Sys.getenv("OUT_DIR",
  "/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Expression_Pathway_bacteria")
padj_lrt   <- as.numeric(Sys.getenv("PADJ_LRT", "0.05"))
padj_ora   <- as.numeric(Sys.getenv("PADJ_ORA", "0.05"))
k_min      <- as.integer(Sys.getenv("K_MIN", "2"))
k_max      <- as.integer(Sys.getenv("K_MAX", "12"))

for (d in c("results", "figures", "logs"))
  dir.create(file.path(out_dir, d), recursive = TRUE, showWarnings = FALSE)

progress <- file.path(out_dir, "logs", "expression_pathway_progress.log")
logmsg <- function(...) {
  line <- paste0("[", format(Sys.time(), "%F %T"), "] ", paste(..., collapse = " "))
  cat(line, "\n")
  cat(line, "\n", file = progress, append = TRUE)
}

save_plot <- function(p, base, w = 10, h = 8) {
  tryCatch({
    ggsave(paste0(base, ".pdf"), p, width = w, height = h)
    ggsave(paste0(base, ".png"), p, width = w, height = h, dpi = 150)
  }, error = function(e) logmsg("  [WARN] plot save failed:", conditionMessage(e)))
}

logmsg("=================================================")
logmsg("Expression Clustering + Pathway Enrichment")
logmsg("C. jejuni NCTC 11168 — time-course DESeq2")
logmsg("=================================================")

# Timepoints in biological order
TP_ORDER <- c("0h", "15m", "30m", "60m", "3h", "24h")
TP_LABELS <- c("0 h", "15 m", "30 m", "60 m", "3 h", "24 h")

# =============================================================================
# 1. Load normalised counts and metadata
# =============================================================================
logmsg("Loading normalised counts and metadata...")

norm_file <- file.path(deseq2_dir, "bacteria_normalised_counts.tsv")
meta_file <- file.path(dirname(deseq2_dir), "metadata.tsv")

if (!file.exists(norm_file)) stop("Normalised counts not found: ", norm_file)
if (!file.exists(meta_file)) stop("Metadata not found: ", meta_file)

norm_counts <- fread(norm_file)
metadata    <- fread(meta_file)

logmsg("Normalised counts:", nrow(norm_counts), "genes x",
       ncol(norm_counts) - 1, "samples")
logmsg("Metadata:", nrow(metadata), "samples |",
       paste(sort(unique(metadata$timepoint)), collapse = ", "))

# =============================================================================
# 2. Load LRT results and filter to time-significant genes
# =============================================================================
lrt_file <- file.path(deseq2_dir, "bacteria_global_time_LRT.tsv")
if (!file.exists(lrt_file)) stop("LRT results not found: ", lrt_file)

lrt <- fread(lrt_file)
sig_gene_ids <- lrt[!is.na(padj) & padj < padj_lrt, gene_id]
logmsg("LRT-significant genes (padj <", padj_lrt, "):", length(sig_gene_ids))

# =============================================================================
# 3. Build per-gene timepoint-averaged z-scored expression matrix
# =============================================================================
logmsg("Building z-scored expression matrix...")

# Melt to long form and join timepoint labels
count_long <- melt(norm_counts, id.vars = "gene_id",
                   variable.name = "sample_id", value.name = "count")
count_long[, sample_id := as.character(sample_id)]
count_long <- merge(count_long, metadata[, .(sample_id, timepoint)],
                    by = "sample_id", all.x = TRUE)

# Average replicates per timepoint
count_avg <- count_long[, .(mean_count = mean(count, na.rm = TRUE)),
                         by = .(gene_id, timepoint)]
count_avg[, log2_expr := log2(mean_count + 1)]

# Wide matrix: genes × timepoints
expr_wide <- dcast(count_avg, gene_id ~ timepoint, value.var = "log2_expr")

# Reorder columns to biological time order
tp_cols_present <- intersect(TP_ORDER, names(expr_wide))
setcolorder(expr_wide, c("gene_id", tp_cols_present))

# Filter to LRT-significant genes
expr_sig <- expr_wide[gene_id %in% sig_gene_ids]
logmsg("Genes in expression matrix:", nrow(expr_sig))

# Z-score across timepoints per gene (captures shape, not magnitude)
gene_ids_vec <- expr_sig$gene_id
expr_sig[, gene_id := NULL]
expr_mat_raw <- as.matrix(expr_sig)
rownames(expr_mat_raw) <- gene_ids_vec
colnames(expr_mat_raw) <- tp_cols_present

row_means <- rowMeans(expr_mat_raw, na.rm = TRUE)
row_sds   <- apply(expr_mat_raw, 1, sd, na.rm = TRUE)
row_sds[row_sds < 1e-10] <- 1   # constant genes: z-score stays 0
expr_z <- sweep(sweep(expr_mat_raw, 1, row_means, "-"), 1, row_sds, "/")

# Save the locus_tag version (strip "gene-" prefix) for GO enrichment
locus_tags <- sub("^gene-", "", rownames(expr_z))
logmsg("Expression matrix ready:", nrow(expr_z), "genes x", ncol(expr_z), "timepoints")

# =============================================================================
# 4. Hierarchical clustering (Euclidean + Ward.D2) on z-scores
# =============================================================================
logmsg("Hierarchical clustering (Ward.D2 on Euclidean z-score distance)...")
expr_dist <- dist(expr_z, method = "euclidean")
hc        <- hclust(expr_dist, method = "ward.D2")
saveRDS(hc, file.path(out_dir, "results", "hclust_expression.rds"))

# =============================================================================
# 5. Silhouette-based optimal k selection
# =============================================================================
logmsg("Selecting optimal k via silhouette (k =", k_min, "to", k_max, ")...")

sil_df <- rbindlist(lapply(k_min:k_max, function(k) {
  cuts  <- cutree(hc, k = k)
  sil   <- silhouette(cuts, expr_dist)
  score <- mean(sil[, 3])
  logmsg("  k =", k, ": mean silhouette =", round(score, 4))
  data.table(k = k, silhouette = score)
}))

best_k <- sil_df[which.max(silhouette), k]
logmsg("Optimal k:", best_k,
       "(silhouette =", round(sil_df[k == best_k, silhouette], 4), ")")

p_sil <- ggplot(sil_df, aes(k, silhouette)) +
  geom_line(color = "steelblue", linewidth = 0.8) +
  geom_point(color = "steelblue", size = 2.5) +
  geom_vline(xintercept = best_k, linetype = "dashed", color = "firebrick") +
  annotate("text", x = best_k + 0.25, y = max(sil_df$silhouette) * 0.97,
           label = paste0("k = ", best_k), color = "firebrick", hjust = 0, size = 3.5) +
  scale_x_continuous(breaks = k_min:k_max) +
  labs(title    = "Silhouette width vs. number of expression clusters",
       subtitle = "Euclidean distance on z-scored log2 expression | Ward.D2",
       x = "k (clusters)", y = "Mean silhouette width") +
  theme_bw(base_size = 12)
save_plot(p_sil, file.path(out_dir, "figures", "silhouette_k_selection"), w = 8, h = 5)

# =============================================================================
# 6. Assign clusters and export gene_clusters.tsv
# =============================================================================
cluster_labels <- cutree(hc, k = best_k)

gene_clusters <- data.table(
  gene_id   = rownames(expr_z),
  locus_tag = sub("^gene-", "", rownames(expr_z)),
  cluster   = cluster_labels
)

# Annotate with LRT stats
gene_clusters <- merge(gene_clusters, lrt[, .(gene_id, baseMean, log2FoldChange, padj)],
                        by = "gene_id", all.x = TRUE)
setorder(gene_clusters, cluster, gene_id)

fwrite(gene_clusters,
       file.path(out_dir, "results", "expression_gene_clusters.tsv"),
       sep = "\t", quote = FALSE)

logmsg("Cluster assignments written:", nrow(gene_clusters), "genes in", best_k, "clusters")
logmsg("Cluster sizes:")
print(gene_clusters[, .N, keyby = cluster])

# =============================================================================
# 7. Expression heatmap (pheatmap) — genes × timepoints, annotated by cluster
# =============================================================================
logmsg("Building expression heatmap...")

# Order rows: cluster, then hierarchical order within cluster
dend_order <- hc$order
row_order   <- dend_order[order(cluster_labels[hc$labels[dend_order]])]

heat_mat <- expr_z[row_order, , drop = FALSE]

# Rename columns to readable labels
colnames(heat_mat) <- TP_LABELS[match(colnames(heat_mat), TP_ORDER)]

row_ann <- data.frame(
  Cluster = factor(paste0("C", cluster_labels[rownames(heat_mat)])),
  row.names = rownames(heat_mat)
)

# Cluster colour palette
cl_cols <- setNames(
  colorRampPalette(brewer.pal(min(best_k, 9), "Set1"))(best_k),
  paste0("C", seq_len(best_k))
)
ann_colors <- list(Cluster = cl_cols)

n_genes_heat <- nrow(heat_mat)
ph_h <- max(6, min(20, n_genes_heat * 0.025 + 3))

pheatmap(heat_mat,
         color           = colorRampPalette(rev(brewer.pal(11, "RdBu")))(80),
         cluster_rows    = FALSE,
         cluster_cols    = FALSE,
         annotation_row  = row_ann,
         annotation_colors = ann_colors,
         show_rownames   = n_genes_heat <= 80,
         fontsize_row    = 6,
         fontsize_col    = 11,
         border_color    = NA,
         main            = paste0("Expression clusters (k = ", best_k,
                                  ") | LRT padj < ", padj_lrt,
                                  " | n = ", n_genes_heat, " genes"),
         filename        = file.path(out_dir, "figures", "expression_heatmap.pdf"),
         width           = 8,
         height          = ph_h)
logmsg("Expression heatmap saved.")

# =============================================================================
# 8. Per-cluster trajectory line plots
# =============================================================================
logmsg("Plotting expression trajectories per cluster...")

# Long-form z-score with cluster labels
z_long <- as.data.table(expr_z, keep.rownames = "gene_id")
z_long <- melt(z_long, id.vars = "gene_id", variable.name = "timepoint",
               value.name = "z_score")
z_long <- merge(z_long, gene_clusters[, .(gene_id, cluster)],
                by = "gene_id", all.x = TRUE)
z_long[, timepoint := factor(timepoint, levels = tp_cols_present,
                              labels = TP_LABELS[match(tp_cols_present, TP_ORDER)])]

# Summary: mean ± SD per cluster × timepoint
traj_sum <- z_long[, .(mean_z = mean(z_score, na.rm = TRUE),
                        sd_z   = sd(z_score,   na.rm = TRUE),
                        n      = .N),
                    by = .(cluster, timepoint)]
traj_sum[, se_z := sd_z / sqrt(n)]
traj_sum[, cluster_f := factor(paste0("Cluster ", cluster,
                                       " (n=", gene_clusters[cluster == cluster, .N][1], ")"),
                                levels = paste0("Cluster ", seq_len(best_k),
                                                " (n=", gene_clusters[, .N, keyby = cluster]$N, ")"))]

# One panel per cluster
p_traj <- ggplot(traj_sum, aes(timepoint, mean_z, group = cluster_f)) +
  geom_ribbon(aes(ymin = mean_z - se_z, ymax = mean_z + se_z, fill = factor(cluster)),
              alpha = 0.25) +
  geom_line(aes(color = factor(cluster)), linewidth = 1) +
  geom_point(aes(color = factor(cluster)), size = 2) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50", linewidth = 0.4) +
  facet_wrap(~ cluster_f, ncol = min(3, best_k)) +
  scale_color_manual(values = cl_cols, guide = "none") +
  scale_fill_manual(values  = cl_cols, guide = "none") +
  labs(title    = paste0("Expression trajectory per cluster (k = ", best_k, ")"),
       subtitle = paste0("Mean ± SE z-score | LRT-significant genes (n = ", nrow(gene_clusters), ")"),
       x = "Timepoint", y = "Mean z-score") +
  theme_bw(base_size = 11) +
  theme(axis.text.x = element_text(angle = 40, hjust = 1))
save_plot(p_traj,
          file.path(out_dir, "figures", "cluster_trajectories"),
          w = min(4 * min(3, best_k), 14),
          h = max(4, ceiling(best_k / 3) * 3.5 + 1))

# All clusters overlaid (overview)
p_traj_all <- ggplot(traj_sum, aes(timepoint, mean_z,
                                    color = factor(cluster),
                                    group = factor(cluster))) +
  geom_line(linewidth = 1) +
  geom_point(size = 2.5) +
  scale_color_manual(values = cl_cols, name = "Cluster") +
  labs(title    = paste0("All cluster trajectories (k = ", best_k, ")"),
       subtitle = "Mean z-scored log2 expression across infection time-course",
       x = "Timepoint", y = "Mean z-score") +
  theme_bw(base_size = 12) +
  theme(axis.text.x = element_text(angle = 40, hjust = 1))
save_plot(p_traj_all,
          file.path(out_dir, "figures", "all_trajectories_overlay"),
          w = 8, h = 5)
logmsg("Trajectory plots saved.")

# =============================================================================
# 9. UMAP on expression z-scores
# =============================================================================
logmsg("Running UMAP on expression z-scores...")
set.seed(42)
umap_cfg             <- umap.defaults
umap_cfg$n_neighbors <- min(15L, as.integer(nrow(expr_z) / 4L))
umap_cfg$min_dist    <- 0.1
umap_cfg$n_epochs    <- 500L
umap_res <- umap(expr_z, config = umap_cfg, input = "data")

umap_dt <- data.table(
  gene_id   = rownames(expr_z),
  locus_tag = sub("^gene-", "", rownames(expr_z)),
  UMAP1     = umap_res$layout[, 1],
  UMAP2     = umap_res$layout[, 2]
)
umap_dt <- merge(umap_dt, gene_clusters[, .(gene_id, cluster)],
                 by = "gene_id", all.x = TRUE)
umap_dt[, cluster_f := factor(paste0("C", cluster))]

p_umap <- ggplot(umap_dt, aes(UMAP1, UMAP2, color = cluster_f)) +
  geom_point(alpha = 0.65, size = 1.5) +
  scale_color_manual(values = setNames(cl_cols, paste0("C", seq_len(best_k))),
                     name = "Cluster") +
  labs(title    = paste0("Expression clusters — UMAP (k = ", best_k, ")"),
       subtitle = paste0("LRT-significant genes | n = ", nrow(expr_z),
                         " | Euclidean z-score distance")) +
  theme_bw(base_size = 11) +
  guides(color = guide_legend(override.aes = list(size = 3, alpha = 1)))
save_plot(p_umap,
          file.path(out_dir, "figures", "umap_expression_clusters"),
          w = 8, h = 6)

fwrite(umap_dt, file.path(out_dir, "results", "umap_expression_coordinates.tsv"),
       sep = "\t", quote = FALSE)
logmsg("UMAP saved.")

# =============================================================================
# 10. GO enrichment per cluster
# =============================================================================
logmsg("Loading GO annotations for pathway enrichment...")

lt2up_file  <- file.path(ora_dir, "cje_locus_to_uniprot.tsv")
go_raw_file <- file.path(ora_dir, "cje_uniprot_go_annotations.tsv")

if (!file.exists(lt2up_file) || !file.exists(go_raw_file))
  stop("GO annotation caches not found in ORA_DIR: ", ora_dir)

lt2up  <- fread(lt2up_file)
go_raw <- fread(go_raw_file)
go_raw[, go_ids_raw := as.character(go_ids_raw)]
go_exp <- go_raw[, .(go_id = unlist(strsplit(go_ids_raw, ";\\s*"))), by = accession]
go_exp <- go_exp[grepl("^GO:", go_id)]
go_exp[, go_id := trimws(go_id)]
lt2go  <- unique(merge(go_exp, lt2up, by.x = "accession", by.y = "uniprot_acc",
                        allow.cartesian = TRUE)[, .(locus_tag, go_id)])
logmsg("Gene-GO pairs loaded:", nrow(lt2go), "| genes:", uniqueN(lt2go$locus_tag))

# Build TERM2GENE and TERM2NAME
t2g <- as.data.frame(unique(lt2go[, .(go_id, locus_tag)]))
t2n_df <- NULL
if (requireNamespace("GO.db", quietly = TRUE)) {
  term_tbl <- suppressMessages(as.data.table(AnnotationDbi::select(
    GO.db::GO.db, keys = unique(lt2go$go_id),
    columns = c("GOID", "TERM", "ONTOLOGY"), keytype = "GOID"
  )))
  setnames(term_tbl, c("go_id", "go_name", "go_namespace"))
  t2n_df <- as.data.frame(term_tbl[, .(go_id, go_name)])
  logmsg("GO term names loaded from GO.db.")
}

universe_lt <- unique(sub("^gene-", "", lrt$gene_id))  # all detected genes as universe
enrich_list <- list()

for (cl in seq_len(best_k)) {
  cl_lt <- gene_clusters[cluster == cl, locus_tag]
  if (length(cl_lt) < 2) next

  res <- tryCatch(
    enricher(
      gene          = cl_lt,
      universe      = universe_lt,
      TERM2GENE     = t2g,
      TERM2NAME     = if (!is.null(t2n_df)) t2n_df else
                        data.frame(go_id = character(), go_name = character()),
      pAdjustMethod = "BH",
      pvalueCutoff  = 1,
      qvalueCutoff  = 1
    ),
    error = function(e) {
      logmsg("  [WARN] cluster", cl, "enricher:", conditionMessage(e))
      NULL
    }
  )

  if (is.null(res) || nrow(res@result) == 0) {
    logmsg("  Cluster", cl, ": no enrichment results")
    next
  }

  dt <- as.data.table(res@result)
  dt[, cluster := cl]
  enrich_list[[cl]] <- dt
  sig_n <- sum(dt$p.adjust < padj_ora, na.rm = TRUE)
  logmsg("  Cluster", cl, "(n =", length(cl_lt), "):",
         nrow(dt), "GO terms |", sig_n, "significant (padj <", padj_ora, ")")

  # Dotplot — only if there are significant terms
  sig_dt <- dt[p.adjust < padj_ora][order(p.adjust)]
  if (nrow(sig_dt) == 0) next
  n_show <- min(15L, nrow(sig_dt))
  sig_dt <- sig_dt[1:n_show]
  sig_dt[, GR := sapply(GeneRatio, function(x) {
    p <- strsplit(x, "/")[[1]]; as.numeric(p[1]) / as.numeric(p[2])
  })]

  p_dot <- ggplot(sig_dt, aes(GR, reorder(Description, -log10(p.adjust)),
                               color = p.adjust, size = Count)) +
    geom_point() +
    scale_color_gradient(low = "firebrick", high = "steelblue",
                         name = "padj") +
    labs(title    = paste0("Cluster ", cl, " — GO enrichment"),
         subtitle = paste0(length(cl_lt), " genes | trajectory: ",
                           paste(round(traj_sum[cluster == cl, mean_z], 1),
                                 collapse = " → ")),
         x = "Gene Ratio", y = NULL, size = "Count") +
    theme_bw(base_size = 10) +
    theme(axis.text.y = element_text(size = 8))
  save_plot(p_dot,
            file.path(out_dir, "figures", paste0("cluster_", cl, "_go_enrichment")),
            w = 9, h = max(4, n_show * 0.38 + 1.5))
}

if (length(enrich_list) > 0) {
  enrich_all <- rbindlist(enrich_list, fill = TRUE)
  setorder(enrich_all, cluster, p.adjust)
  fwrite(enrich_all,
         file.path(out_dir, "results", "cluster_go_enrichment.tsv"),
         sep = "\t", quote = FALSE)
  logmsg("GO enrichment table saved:", nrow(enrich_all), "rows across",
         uniqueN(enrich_all$cluster), "clusters")
} else {
  logmsg("[WARN] No enrichment results produced — check GO annotation coverage.")
}

# =============================================================================
# 11. Cluster summary table
# =============================================================================
logmsg("Writing cluster summary...")

# Mean z-score per timepoint per cluster
mean_z_wide <- dcast(traj_sum[, .(cluster, timepoint, mean_z)],
                      cluster ~ timepoint, value.var = "mean_z")

cl_summary <- gene_clusters[, .(n_genes = .N,
                                  mean_baseMean = round(mean(baseMean, na.rm = TRUE), 1),
                                  median_padj_lrt = round(median(padj, na.rm = TRUE), 4)),
                              keyby = cluster]
cl_summary <- merge(cl_summary, mean_z_wide, by = "cluster")
setcolorder(cl_summary, c("cluster", "n_genes", "mean_baseMean", "median_padj_lrt",
                            intersect(tp_cols_present, names(cl_summary))))

fwrite(cl_summary,
       file.path(out_dir, "results", "cluster_summary.tsv"),
       sep = "\t", quote = FALSE)
logmsg("Cluster summary:")
print(cl_summary)

logmsg("=================================================")
logmsg("Expression clustering + pathway enrichment complete.")
logmsg("  LRT-significant genes :", nrow(gene_clusters))
logmsg("  Expression clusters   :", best_k)
logmsg("  Output                :", out_dir)
logmsg("=================================================")
