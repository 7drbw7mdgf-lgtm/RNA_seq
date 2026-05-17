suppressPackageStartupMessages({
  library(clusterProfiler)
  library(msigdbr)
  library(data.table)
  library(ggplot2)
})

# ---- Paths ----
results_dir <- Sys.getenv("DESEQ2_RESULTS_DIR",
  "/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/DeSeq2_host/results")
out_dir     <- Sys.getenv("OUT_DIR",
  "/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/Hallmark_host")
padj_cut    <- as.numeric(Sys.getenv("PADJ_CUTOFF", "0.05"))

for (d in c("results", "figures", "logs"))
  dir.create(file.path(out_dir, d), recursive = TRUE, showWarnings = FALSE)

progress <- file.path(out_dir, "logs", "hallmark_progress.log")
logmsg <- function(...) {
  line <- paste0("[", format(Sys.time(), "%F %T"), "] ", paste(..., collapse = " "))
  cat(line, "\n")
  cat(line, "\n", file = progress, append = TRUE)
}

save_plot <- function(p, base, w = 10, h = 8) {
  tryCatch({
    ggsave(paste0(base, ".pdf"), p, width = w, height = h)
    ggsave(paste0(base, ".png"), p, width = w, height = h, dpi = 300)
  }, error = function(e) logmsg("  [WARN] plot save failed:", conditionMessage(e)))
}

# Strip HALLMARK_ prefix for cleaner axis labels
clean_name <- function(x) gsub("^HALLMARK_", "", gsub("_", " ", x))

logmsg("=================================================")
logmsg("Hallmark ORA + GSEA — Homo sapiens — MSigDB H collection")
logmsg("=================================================")

# =============================================================================
# 0. Load Hallmark gene sets (MSigDB collection H)
# =============================================================================
logmsg("Loading Hallmark gene sets from msigdbr...")
h_sets   <- msigdbr(species = "Homo sapiens", category = "H")
term2gene <- h_sets[, c("gs_name", "gene_symbol")]
setDT(term2gene)

logmsg("  Gene sets:", uniqueN(term2gene$gs_name))
logmsg("  Set size range:",
       min(term2gene[, .N, by = gs_name]$N), "-",
       max(term2gene[, .N, by = gs_name]$N))

# =============================================================================
# 1. Build background universe from all genes tested in DESeq2
# =============================================================================
logmsg("Building background universe...")
full_files <- list.files(results_dir, pattern = "_DESeq2_results\\.tsv$", full.names = TRUE)
if (length(full_files) > 0) {
  universe_symbols <- unique(fread(full_files[1], select = "gene_id")$gene_id)
  logmsg("  Universe: ", length(universe_symbols), "gene symbols")
} else {
  logmsg("  [WARN] No full DESeq2 results found. ORA will run without explicit universe.")
  universe_symbols <- character(0)
}

uni_arg <- if (length(universe_symbols) > 0) universe_symbols else NULL

# =============================================================================
# 2. Identify all pairwise comparisons
# =============================================================================
sig_files <- list.files(results_dir, pattern = "_significant_genes\\.tsv$", full.names = TRUE)
rnk_files <- list.files(results_dir, pattern = "_ranked_for_GSEA\\.rnk$",  full.names = TRUE)

if (length(sig_files) == 0)
  stop("No *_significant_genes.tsv files found in: ", results_dir)

logmsg("Pairwise comparisons found:", length(sig_files))

# =============================================================================
# 3. Hallmark ORA — per comparison x direction (all / up / down)
# =============================================================================
logmsg("-------------------------------------------------")
logmsg("Running Hallmark ORA (enricher)...")
logmsg("-------------------------------------------------")

ora_summary <- list()

for (sig_file in sort(sig_files)) {
  comp <- sub("_significant_genes\\.tsv$", "", basename(sig_file))
  logmsg("--- ORA:", comp, "---")

  sig_dt <- tryCatch(fread(sig_file), error = function(e) NULL)
  if (is.null(sig_dt) || nrow(sig_dt) == 0) {
    logmsg("  [SKIP] no significant genes")
    next
  }

  all_genes  <- sig_dt$gene_id
  up_genes   <- sig_dt[log2FoldChange >  0, gene_id]
  down_genes <- sig_dt[log2FoldChange <  0, gene_id]
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
      row[[paste0(tag, "_sig_sets")]] <- 0L
      next
    }

    res <- tryCatch(
      enricher(
        gene          = genes,
        universe      = uni_arg,
        TERM2GENE     = as.data.frame(term2gene),
        pAdjustMethod = "BH",
        pvalueCutoff  = 1,
        qvalueCutoff  = 1,
        minGSSize     = 15,
        maxGSSize     = 500
      ),
      error = function(e) {
        logmsg("  [WARN]", tag, "enricher:", conditionMessage(e))
        NULL
      }
    )

    n_sig <- if (!is.null(res) && nrow(res@result) > 0)
               sum(res@result$p.adjust < padj_cut, na.rm = TRUE) else 0L
    logmsg("  [ORA]", tag, ":",
           if (!is.null(res)) nrow(res@result) else 0,
           "sets |", n_sig, "significant")
    row[[paste0(tag, "_sig_sets")]] <- as.integer(n_sig)

    if (!is.null(res) && nrow(res@result) > 0) {
      # Clean pathway names for output
      res@result$Description <- clean_name(res@result$ID)

      out_base <- file.path(out_dir, "results",
                            paste0(comp, "_Hallmark_ORA_", tag))
      fwrite(as.data.table(res@result),
             paste0(out_base, ".tsv"), sep = "\t", quote = FALSE)

      sig_res <- res@result[res@result$p.adjust < padj_cut, ]
      if (nrow(sig_res) > 0) {
        n_show <- min(25L, nrow(sig_res))
        p <- dotplot(res, showCategory = n_show, font.size = 9) +
          scale_y_discrete(labels = function(x) clean_name(x)) +
          labs(
            title    = paste0(comp, "  |  Hallmark ORA  (", tag, ")"),
            subtitle = paste0("MSigDB H | BH | ", n_sig, " significant gene sets")
          ) +
          theme_bw(base_size = 11)
        save_plot(p, file.path(out_dir, "figures",
                               paste0(comp, "_Hallmark_ORA_", tag)),
                  w = 10, h = max(5, n_show * 0.38 + 2))
      }
    }
  }
  ora_summary[[length(ora_summary) + 1]] <- row
}

if (length(ora_summary) > 0) {
  ora_dt <- rbindlist(ora_summary, fill = TRUE)
  setnafill(ora_dt, fill = 0L, cols = setdiff(names(ora_dt), "comparison"))
  setorder(ora_dt, comparison)
  fwrite(ora_dt,
         file.path(out_dir, "results", "hallmark_ora_summary.tsv"),
         sep = "\t", quote = FALSE)
  logmsg("ORA summary written:", nrow(ora_dt), "comparisons")
  print(ora_dt[, .(comparison, n_all, all_sig_sets, up_sig_sets, down_sig_sets)])
}

# =============================================================================
# 4. Hallmark GSEA — per comparison (full ranked gene list)
# =============================================================================
logmsg("-------------------------------------------------")
logmsg("Running Hallmark GSEA (GSEA)...")
logmsg("-------------------------------------------------")

gsea_summary <- list()

for (rnk_file in sort(rnk_files)) {
  comp <- sub("_ranked_for_GSEA\\.rnk$", "", basename(rnk_file))
  logmsg("--- GSEA:", comp, "---")

  rnk_dt <- tryCatch(fread(rnk_file, header = FALSE,
                            col.names = c("gene_id", "rank")),
                     error = function(e) NULL)
  if (is.null(rnk_dt) || nrow(rnk_dt) == 0) {
    logmsg("  [SKIP] empty ranked list")
    next
  }

  # Remove duplicates; keep highest absolute rank per symbol
  setDT(rnk_dt)
  rnk_dt[, abs_rank := abs(rank)]
  rnk_dt <- rnk_dt[rnk_dt[, .I[which.max(abs_rank)], by = gene_id]$V1]
  setorder(rnk_dt, -rank)

  ranked_vec <- setNames(rnk_dt$rank, rnk_dt$gene_id)
  logmsg("  Ranked genes:", length(ranked_vec))

  res <- tryCatch(
    GSEA(
      geneList      = ranked_vec,
      TERM2GENE     = as.data.frame(term2gene),
      minGSSize     = 15,
      maxGSSize     = 500,
      pvalueCutoff  = 1,
      pAdjustMethod = "BH",
      verbose       = FALSE,
      eps           = 0
    ),
    error = function(e) {
      logmsg("  [WARN] GSEA:", conditionMessage(e))
      NULL
    }
  )

  n_sig <- if (!is.null(res) && nrow(res@result) > 0)
             sum(res@result$p.adjust < padj_cut, na.rm = TRUE) else 0L
  logmsg("  [GSEA]",
         if (!is.null(res)) nrow(res@result) else 0,
         "sets |", n_sig, "significant")

  gsea_summary[[length(gsea_summary) + 1]] <- data.table(
    comparison     = comp,
    n_ranked_genes = length(ranked_vec),
    n_sets         = if (!is.null(res)) nrow(res@result) else 0L,
    n_sig_sets     = as.integer(n_sig)
  )

  if (!is.null(res) && nrow(res@result) > 0) {
    res@result$Description <- clean_name(res@result$ID)

    out_base <- file.path(out_dir, "results", paste0(comp, "_Hallmark_GSEA"))
    fwrite(as.data.table(res@result),
           paste0(out_base, ".tsv"), sep = "\t", quote = FALSE)

    res_dt <- as.data.table(res@result)[order(p.adjust)]
    sig_dt <- res_dt[p.adjust < padj_cut]

    if (nrow(sig_dt) > 0) {
      n_show  <- min(25L, nrow(sig_dt))
      sig_top <- sig_dt[1:n_show]
      sig_top[, label     := clean_name(ID)]
      sig_top[, direction := ifelse(NES > 0, "Activated", "Suppressed")]

      p <- ggplot(sig_top,
                  aes(NES, reorder(label, NES),
                      color = p.adjust, size = setSize)) +
        geom_point() +
        geom_vline(xintercept = 0, linetype = "dashed", colour = "grey50") +
        scale_color_gradient(low = "firebrick", high = "steelblue",
                             name = "padj") +
        scale_size_continuous(name = "Set size", range = c(3, 9)) +
        labs(
          title    = paste0(comp, "  |  Hallmark GSEA"),
          subtitle = paste0("MSigDB H | BH | ", n_sig,
                            " significant | NES > 0: activated"),
          x = "Normalised Enrichment Score (NES)", y = NULL
        ) +
        theme_bw(base_size = 11) +
        theme(axis.text.y = element_text(size = 9))
      save_plot(p,
                file.path(out_dir, "figures", paste0(comp, "_Hallmark_GSEA")),
                w = 10, h = max(5, n_show * 0.38 + 2))
    }

    # Ridge plot
    if (requireNamespace("enrichplot", quietly = TRUE) && nrow(sig_dt) > 0) {
      tryCatch({
        n_ridge <- min(10L, nrow(sig_dt))
        p_ridge <- enrichplot::ridgeplot(res, showCategory = n_ridge,
                                         fill = "p.adjust") +
          scale_y_discrete(labels = function(x) clean_name(x)) +
          labs(title    = paste0(comp, "  |  Hallmark GSEA — ridge plot"),
               subtitle = paste0("Top ", n_ridge, " sets by padj")) +
          theme_bw(base_size = 10)
        save_plot(p_ridge,
                  file.path(out_dir, "figures", paste0(comp, "_Hallmark_GSEA_ridge")),
                  w = 10, h = max(5, n_ridge * 0.55 + 2))
      }, error = function(e)
        logmsg("  [WARN] ridge plot:", conditionMessage(e)))
    }
  }
}

if (length(gsea_summary) > 0) {
  gsea_dt <- rbindlist(gsea_summary, fill = TRUE)
  setorder(gsea_dt, comparison)
  fwrite(gsea_dt,
         file.path(out_dir, "results", "hallmark_gsea_summary.tsv"),
         sep = "\t", quote = FALSE)
  logmsg("GSEA summary written:", nrow(gsea_dt), "comparisons")
  print(gsea_dt)
}

# =============================================================================
# 5. Cross-comparison frequency: which Hallmark sets are significant repeatedly
# =============================================================================
logmsg("-------------------------------------------------")
logmsg("Building cross-comparison Hallmark set frequency...")
logmsg("-------------------------------------------------")

ora_tsv_files <- list.files(file.path(out_dir, "results"),
                             pattern = "_Hallmark_ORA_all\\.tsv$", full.names = TRUE)

if (length(ora_tsv_files) > 0) {
  all_ora <- rbindlist(lapply(ora_tsv_files, function(f) {
    dt <- fread(f)
    dt[, comparison := sub("_Hallmark_ORA_all\\.tsv$", "", basename(f))]
    dt
  }), fill = TRUE)

  sig_ora <- all_ora[p.adjust < padj_cut]
  logmsg("Significant ORA hits:", nrow(sig_ora),
         "| unique sets:", uniqueN(sig_ora$ID))

  if (nrow(sig_ora) > 0) {
    set_freq <- sig_ora[, .(
      n_comparisons  = .N,
      comparisons    = paste(comparison, collapse = "; "),
      label          = clean_name(ID[1]),
      mean_GeneRatio = mean(sapply(GeneRatio, function(x) {
        p <- strsplit(x, "/")[[1]]; as.numeric(p[1]) / as.numeric(p[2])
      }), na.rm = TRUE),
      mean_padj      = mean(p.adjust, na.rm = TRUE)
    ), keyby = ID]
    setorder(set_freq, -n_comparisons, mean_padj)

    fwrite(set_freq,
           file.path(out_dir, "results", "hallmark_set_frequency.tsv"),
           sep = "\t", quote = FALSE)
    logmsg("Set frequency table written:", nrow(set_freq), "gene sets")
    print(set_freq[1:min(15, nrow(set_freq)), .(ID, label, n_comparisons, mean_padj)])

    top_sets <- set_freq[1:min(25, nrow(set_freq))]
    p_freq <- ggplot(top_sets,
                     aes(n_comparisons,
                         reorder(label, n_comparisons),
                         size  = mean_GeneRatio,
                         color = mean_padj)) +
      geom_point() +
      scale_color_gradient(low = "firebrick", high = "steelblue",
                           name = "Mean\npadj") +
      scale_size_continuous(name = "Mean\ngene ratio", range = c(2, 9)) +
      scale_x_continuous(breaks = seq_len(max(top_sets$n_comparisons))) +
      labs(
        title    = "Hallmark gene sets significant across pairwise comparisons",
        subtitle = paste0("Homo sapiens | MSigDB H | ORA (all DEGs) | padj < ", padj_cut),
        x = "Number of comparisons significant in",
        y = NULL
      ) +
      theme_bw(base_size = 11) +
      theme(axis.text.y = element_text(size = 9))
    save_plot(p_freq,
              file.path(out_dir, "figures", "hallmark_set_frequency"),
              w = 12, h = max(5, nrow(top_sets) * 0.38 + 2))
    logmsg("Set frequency plot saved.")
  }
}

logmsg("=================================================")
logmsg("Hallmark analysis complete.")
logmsg("  Results :", file.path(out_dir, "results"))
logmsg("  Figures :", file.path(out_dir, "figures"))
logmsg("=================================================")
