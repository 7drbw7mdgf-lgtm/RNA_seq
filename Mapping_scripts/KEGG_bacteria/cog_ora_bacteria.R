suppressPackageStartupMessages({
  library(clusterProfiler)
  library(data.table)
  library(ggplot2)
  library(RColorBrewer)
})

# ---- Paths ----------------------------------------------------------------
emapper_file <- Sys.getenv("EMAPPER_FILE",
  "/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/KEGG_bacteria/emapper_output/cje_emapper.emapper.annotations")
results_dir  <- Sys.getenv("DESEQ2_RESULTS_DIR",
  "/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/DeSeq2_bacteria/results")
out_dir      <- Sys.getenv("OUT_DIR",
  "/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/KEGG_bacteria")
padj_cut     <- as.numeric(Sys.getenv("PADJ_CUTOFF", "0.05"))

cog_res_dir <- file.path(out_dir, "cog_results")
cog_fig_dir <- file.path(out_dir, "cog_figures")
for (d in c(cog_res_dir, cog_fig_dir, file.path(out_dir, "logs")))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)

progress <- file.path(out_dir, "logs", "cog_ora_progress.log")
logmsg <- function(...) {
  line <- paste0("[", format(Sys.time(), "%F %T"), "] ", paste(..., collapse = " "))
  cat(line, "\n")
  cat(line, "\n", file = progress, append = TRUE)
}

save_plot <- function(p, base, w = 9, h = 7) {
  tryCatch({
    ggsave(paste0(base, ".pdf"), p, width = w, height = h)
    ggsave(paste0(base, ".png"), p, width = w, height = h, dpi = 300)
  }, error = function(e) logmsg("  [WARN] plot save failed:", conditionMessage(e)))
}

strip_prefix <- function(ids) sub("^gene-", "", ids)

# Full COG category descriptions
COG_NAMES <- c(
  J = "Translation, ribosomal structure and biogenesis",
  A = "RNA processing and modification",
  K = "Transcription",
  L = "Replication, recombination and repair",
  B = "Chromatin structure and dynamics",
  D = "Cell cycle control and division",
  Y = "Nuclear structure",
  V = "Defense mechanisms",
  T = "Signal transduction mechanisms",
  M = "Cell wall/membrane/envelope biogenesis",
  N = "Cell motility",
  Z = "Cytoskeleton",
  W = "Extracellular structures",
  U = "Intracellular trafficking and secretion",
  O = "Post-translational modification and chaperones",
  X = "Mobilome: prophages, transposons",
  C = "Energy production and conversion",
  G = "Carbohydrate transport and metabolism",
  E = "Amino acid transport and metabolism",
  F = "Nucleotide transport and metabolism",
  H = "Coenzyme transport and metabolism",
  I = "Lipid transport and metabolism",
  P = "Inorganic ion transport and metabolism",
  Q = "Secondary metabolites biosynthesis and transport",
  R = "General function prediction only",
  S = "Function unknown"
)

logmsg("=================================================")
logmsg("COG ORA — C. jejuni — pairwise timepoints")
logmsg("Annotation: eggNOG-mapper 2.1.12 (COG categories)")
logmsg("=================================================")

# =============================================================================
# 1. Load and parse eggNOG-mapper annotations
# =============================================================================
logmsg("Loading eggNOG-mapper annotations:", emapper_file)
if (!file.exists(emapper_file))
  stop("Annotations file not found: ", emapper_file)

# Skip comment lines (start with ##); first data line has column headers (#query ...)
raw_lines <- readLines(emapper_file, warn = FALSE)
header_idx <- grep("^#query", raw_lines)
if (length(header_idx) == 0) stop("Cannot find header line in emapper file")

anno <- fread(
  text  = paste(raw_lines[header_idx:length(raw_lines)], collapse = "\n"),
  sep   = "\t",
  header = TRUE,
  check.names = FALSE
)
setnames(anno, names(anno)[1], "query")   # rename #query -> query

logmsg("Annotations loaded:", nrow(anno), "genes")
logmsg("Columns:", paste(names(anno)[1:10], collapse = ", "), "...")

# COG_category column (column 7 in emapper v2.1 output)
cog_col <- grep("COG_cat", names(anno), value = TRUE, ignore.case = TRUE)[1]
if (is.na(cog_col)) {
  # Fallback: column index 7 (0-indexed in file, 7th data column)
  cog_col <- names(anno)[7]
  logmsg("[WARN] COG_category column not found by name; using column:", cog_col)
} else {
  logmsg("COG category column:", cog_col)
}

anno_cog <- anno[, .(locus_tag = query, cog_raw = get(cog_col))]
anno_cog <- anno_cog[!is.na(cog_raw) & cog_raw != "" & cog_raw != "-"]

# Expand multi-letter COG assignments (e.g. "JK" -> two rows: J and K)
lt2cog <- anno_cog[, .(cog = strsplit(cog_raw, "")[[1]]), by = locus_tag]
lt2cog <- lt2cog[cog %in% names(COG_NAMES)]  # keep only valid letters
lt2cog <- unique(lt2cog)

logmsg("Gene-COG pairs:", nrow(lt2cog),
       "| genes:", uniqueN(lt2cog$locus_tag),
       "| categories:", uniqueN(lt2cog$cog))
logmsg("COG category counts:")
print(lt2cog[, .N, keyby = cog][, .(cog, N, description = COG_NAMES[cog])])

fwrite(lt2cog, file.path(cog_res_dir, "cje_locus_to_cog.tsv"),
       sep = "\t", quote = FALSE)

# =============================================================================
# 2. Build TERM2GENE and TERM2NAME
# =============================================================================
term2gene <- lt2cog[, .(term = cog, gene = locus_tag)]
term2name <- data.table(
  term = names(COG_NAMES),
  name = paste0("[", names(COG_NAMES), "] ", COG_NAMES)
)[term %in% unique(lt2cog$cog)]

universe_all <- unique(lt2cog$locus_tag)
logmsg("Universe:", length(universe_all), "annotated genes")

# =============================================================================
# 3. COG category distribution barplot (all annotated genes)
# =============================================================================
cog_counts <- lt2cog[, .N, keyby = cog]
cog_counts[, description := COG_NAMES[cog]]
cog_counts[, label := paste0("[", cog, "] ", description)]

# Colour palette by functional supergroup
cog_colours <- c(
  J="#E41A1C", A="#E41A1C", K="#FF7F00", L="#FF7F00",   # info storage
  B="#984EA3", D="#984EA3",
  V="#4DAF4A", T="#4DAF4A", M="#4DAF4A", N="#4DAF4A",   # cellular processes
  O="#4DAF4A", U="#4DAF4A",
  C="#377EB8", G="#377EB8", E="#377EB8", F="#377EB8",   # metabolism
  H="#377EB8", I="#377EB8", P="#377EB8", Q="#377EB8",
  R="grey60", S="grey80", X="#A65628"
)

p_cog_dist <- ggplot(cog_counts,
                      aes(N, reorder(label, N),
                          fill = cog)) +
  geom_col() +
  geom_text(aes(label = N), hjust = -0.2, size = 3) +
  scale_fill_manual(values = cog_colours, guide = "none") +
  labs(
    title    = "COG category distribution — C. jejuni NCTC 11168",
    subtitle = paste0("eggNOG-mapper 2.1.12 | ", uniqueN(lt2cog$locus_tag),
                      " annotated genes"),
    x = "Number of genes", y = NULL
  ) +
  theme_bw(base_size = 11) +
  theme(axis.text.y = element_text(size = 8)) +
  expand_limits(x = max(cog_counts$N) * 1.1)
save_plot(p_cog_dist,
          file.path(cog_fig_dir, "cog_category_distribution"),
          w = 10, h = max(5, nrow(cog_counts) * 0.42 + 2))
logmsg("COG distribution barplot saved.")

# =============================================================================
# 4. ORA per pairwise comparison x direction
# =============================================================================
sig_files <- list.files(results_dir, pattern = "_significant_genes\\.tsv$",
                         full.names = TRUE)
if (length(sig_files) == 0)
  stop("No *_significant_genes.tsv files found in: ", results_dir)
logmsg("Comparisons to process:", length(sig_files))

run_ora <- function(genes, comp_label) {
  if (length(genes) < 2) return(NULL)
  res <- tryCatch(
    enricher(
      gene          = genes,
      universe      = universe_all,
      TERM2GENE     = as.data.frame(term2gene),
      TERM2NAME     = as.data.frame(term2name),
      pAdjustMethod = "BH",
      pvalueCutoff  = 1,
      qvalueCutoff  = 1
    ),
    error = function(e) {
      logmsg("  [WARN]", comp_label, "enricher:", conditionMessage(e))
      NULL
    }
  )
  if (is.null(res) || nrow(res@result) == 0) return(NULL)
  res
}

summary_rows <- list()

for (sig_file in sort(sig_files)) {
  comp   <- sub("_significant_genes\\.tsv$", "", basename(sig_file))
  logmsg("---", comp, "---")

  sig_dt <- tryCatch(fread(sig_file), error = function(e) NULL)
  if (is.null(sig_dt) || nrow(sig_dt) == 0) {
    logmsg("  [SKIP] no significant genes")
    next
  }

  all_genes  <- strip_prefix(sig_dt$gene_id)
  up_genes   <- strip_prefix(sig_dt[log2FoldChange >  0, gene_id])
  down_genes <- strip_prefix(sig_dt[log2FoldChange <  0, gene_id])
  logmsg("  Genes — all:", length(all_genes),
         "| up:", length(up_genes), "| down:", length(down_genes))

  row <- data.table(comparison = comp,
                    n_all  = length(all_genes),
                    n_up   = length(up_genes),
                    n_down = length(down_genes))

  for (d in list(list(genes = all_genes,  tag = "all"),
                 list(genes = up_genes,   tag = "up"),
                 list(genes = down_genes, tag = "down"))) {

    genes <- d$genes
    tag   <- d$tag
    if (length(genes) < 2) {
      row[[paste0(tag, "_sig_cog")]] <- 0L
      next
    }

    ora   <- run_ora(genes, paste(comp, tag))
    n_sig <- if (!is.null(ora))
               sum(ora@result$p.adjust < padj_cut, na.rm = TRUE) else 0L
    logmsg("  [ORA]", tag, ":",
           if (!is.null(ora)) nrow(ora@result) else 0,
           "COG categories |", n_sig, "significant")
    row[[paste0(tag, "_sig_cog")]] <- as.integer(n_sig)

    if (!is.null(ora) && nrow(ora@result) > 0) {
      out_base <- file.path(cog_res_dir, paste0(comp, "_COG_ORA_", tag))
      fwrite(as.data.table(ora@result),
             paste0(out_base, ".tsv"), sep = "\t", quote = FALSE)

      sig_ora <- ora@result[ora@result$p.adjust < padj_cut, ]
      if (nrow(sig_ora) > 0) {
        n_show <- min(20L, nrow(sig_ora))
        p <- dotplot(ora, showCategory = n_show, font.size = 9) +
          labs(
            title    = paste0(comp, "  |  COG ORA  (", tag, ")"),
            subtitle = paste0("eggNOG-mapper 2.1.12 | BH | ",
                              n_sig, " significant categories")
          ) +
          theme_bw(base_size = 11) +
          theme(axis.text.y = element_text(size = 8))
        save_plot(p,
                  file.path(cog_fig_dir, paste0(comp, "_COG_ORA_", tag)),
                  w = 9, h = max(5, n_show * 0.42 + 2))
      }
    }
  }
  summary_rows[[length(summary_rows) + 1]] <- row
}

# =============================================================================
# 5. Summary table + cross-comparison heatmap
# =============================================================================
if (length(summary_rows) > 0) {
  summary_dt <- rbindlist(summary_rows, fill = TRUE)
  setnafill(summary_dt, fill = 0L, cols = setdiff(names(summary_dt), "comparison"))
  setorder(summary_dt, comparison)
  fwrite(summary_dt,
         file.path(cog_res_dir, "cog_ora_summary.tsv"),
         sep = "\t", quote = FALSE)
  logmsg("Summary written:", nrow(summary_dt), "comparisons")
  print(summary_dt[, .(comparison, n_all, all_sig_cog, up_sig_cog, down_sig_cog)])
}

# Cross-comparison heatmap: -log10(padj) per COG × comparison (all DEGs)
cog_tsv_files <- list.files(cog_res_dir,
                             pattern = "_COG_ORA_all\\.tsv$",
                             full.names = TRUE)
if (length(cog_tsv_files) > 0) {
  all_ora <- rbindlist(lapply(cog_tsv_files, function(f) {
    dt <- fread(f)
    dt[, comparison := sub("_COG_ORA_all\\.tsv$", "", basename(f))]
    dt
  }), fill = TRUE)

  if (nrow(all_ora) > 0 && any(all_ora$p.adjust < padj_cut, na.rm = TRUE)) {
    # Build matrix: rows = COG categories, cols = comparisons
    heat_dt <- all_ora[, .(
      neg_log10_padj = -log10(pmax(p.adjust, 1e-10))
    ), by = .(Description, comparison)]

    heat_wide <- dcast(heat_dt, Description ~ comparison,
                       value.var = "neg_log10_padj", fill = 0)
    heat_mat  <- as.matrix(heat_wide[, -"Description"])
    rownames(heat_mat) <- heat_wide$Description

    # Keep only rows with at least one significant hit
    sig_mask  <- apply(heat_mat, 1, function(x) any(x > -log10(padj_cut)))
    heat_mat  <- heat_mat[sig_mask, , drop = FALSE]

    if (nrow(heat_mat) > 0) {
      # Shorten column names for display
      colnames(heat_mat) <- sub("^bacteria_", "", colnames(heat_mat))

      library(pheatmap)
      ph_w <- max(10, ncol(heat_mat) * 0.4 + 4)
      ph_h <- max(4,  nrow(heat_mat) * 0.55 + 2)
      pheatmap(heat_mat,
               color        = colorRampPalette(c("white", "#FEE08B", "#D73027"))(60),
               cluster_cols = TRUE,
               cluster_rows = TRUE,
               fontsize_row = 9,
               fontsize_col = 7,
               angle_col    = 45,
               main         = paste0("-log10(padj) | COG ORA across comparisons\n",
                                     "eggNOG-mapper 2.1.12 | C. jejuni NCTC 11168"),
               filename     = file.path(cog_fig_dir, "cog_ora_heatmap.pdf"),
               width        = ph_w,
               height       = ph_h)
      logmsg("Cross-comparison COG heatmap saved.")
    }
  }
}

logmsg("=================================================")
logmsg("COG ORA analysis complete.")
logmsg("  Results : ", cog_res_dir)
logmsg("  Figures : ", cog_fig_dir)
logmsg("=================================================")
