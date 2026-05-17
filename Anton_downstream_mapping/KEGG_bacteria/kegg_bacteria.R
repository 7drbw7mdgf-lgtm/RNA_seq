suppressPackageStartupMessages({
  library(clusterProfiler)
  library(data.table)
  library(ggplot2)
})

# ---- Paths ----
results_dir <- Sys.getenv("DESEQ2_RESULTS_DIR",
  "/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/DeSeq2_bacteria/results")
out_dir     <- Sys.getenv("OUT_DIR",
  "/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/KEGG_bacteria")
padj_cut    <- as.numeric(Sys.getenv("PADJ_CUTOFF", "0.05"))
organism    <- Sys.getenv("KEGG_ORGANISM", "cje")

for (d in c("results", "figures", "logs"))
  dir.create(file.path(out_dir, d), recursive = TRUE, showWarnings = FALSE)

progress <- file.path(out_dir, "logs", "kegg_progress.log")
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

logmsg("=================================================")
logmsg("KEGG ORA + GSEA — C. jejuni — pairwise timepoints")
logmsg("Organism:", organism)
logmsg("=================================================")

# =============================================================================
# 1. Identify all pairwise comparisons
# =============================================================================
sig_files <- list.files(results_dir, pattern = "_significant_genes\\.tsv$",
                         full.names = TRUE)
rnk_files <- list.files(results_dir, pattern = "_ranked_for_GSEA\\.rnk$",
                         full.names = TRUE)

if (length(sig_files) == 0)
  stop("No *_significant_genes.tsv files found in: ", results_dir)

logmsg("Pairwise comparisons found:", length(sig_files))

# =============================================================================
# 2. KEGG ORA — per comparison x direction (all / up / down)
# =============================================================================
logmsg("-------------------------------------------------")
logmsg("Running KEGG ORA (enrichKEGG)...")
logmsg("-------------------------------------------------")

ora_summary <- list()

for (sig_file in sort(sig_files)) {
  comp   <- sub("_significant_genes\\.tsv$", "", basename(sig_file))
  logmsg("--- ORA:", comp, "---")

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
                    n_all = length(all_genes),
                    n_up  = length(up_genes),
                    n_down = length(down_genes))

  for (d in list(list(genes = all_genes,  tag = "all"),
                 list(genes = up_genes,   tag = "up"),
                 list(genes = down_genes, tag = "down"))) {

    genes <- d$genes
    tag   <- d$tag
    if (length(genes) < 2) {
      row[[paste0(tag, "_sig_pathways")]] <- 0L
      next
    }

    res <- tryCatch(
      enrichKEGG(
        gene          = genes,
        organism      = organism,
        keyType       = "kegg",
        pAdjustMethod = "BH",
        pvalueCutoff  = 1,
        qvalueCutoff  = 1
      ),
      error = function(e) {
        logmsg("  [WARN]", tag, "enrichKEGG:", conditionMessage(e))
        NULL
      }
    )

    n_sig <- if (!is.null(res) && nrow(res@result) > 0)
               sum(res@result$p.adjust < padj_cut, na.rm = TRUE) else 0L
    logmsg("  [ORA]", tag, ":",
           if (!is.null(res)) nrow(res@result) else 0,
           "pathways |", n_sig, "significant")
    row[[paste0(tag, "_sig_pathways")]] <- as.integer(n_sig)

    if (!is.null(res) && nrow(res@result) > 0) {
      out_base <- file.path(out_dir, "results",
                            paste0(comp, "_KEGG_ORA_", tag))
      fwrite(as.data.table(res@result),
             paste0(out_base, ".tsv"), sep = "\t", quote = FALSE)

      sig_res <- res@result[res@result$p.adjust < padj_cut, ]
      if (nrow(sig_res) > 0) {
        n_show <- min(20L, nrow(sig_res))
        p <- dotplot(res, showCategory = n_show, font.size = 9) +
          labs(
            title    = paste0(comp, "  |  KEGG ORA  (", tag, ")"),
            subtitle = paste0("organism = ", organism,
                              " | BH | ", n_sig, " significant pathways")
          ) +
          theme_bw(base_size = 11)
        save_plot(p, file.path(out_dir, "figures",
                               paste0(comp, "_KEGG_ORA_", tag)),
                  w = 9, h = max(5, n_show * 0.38 + 2))
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
         file.path(out_dir, "results", "kegg_ora_summary.tsv"),
         sep = "\t", quote = FALSE)
  logmsg("ORA summary written:", nrow(ora_dt), "comparisons")
  print(ora_dt[, .(comparison, n_all, all_sig_pathways, up_sig_pathways, down_sig_pathways)])
}

# =============================================================================
# 3. KEGG GSEA — per comparison (full ranked gene list)
# =============================================================================
logmsg("-------------------------------------------------")
logmsg("Running KEGG GSEA (gseKEGG)...")
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

  rnk_dt[, locus_tag := strip_prefix(gene_id)]

  # Remove duplicates and sort descending
  rnk_dt <- rnk_dt[!duplicated(locus_tag)]
  setorder(rnk_dt, -rank)
  ranked_vec <- setNames(rnk_dt$rank, rnk_dt$locus_tag)

  logmsg("  Ranked genes:", length(ranked_vec))

  res <- tryCatch(
    gseKEGG(
      geneList      = ranked_vec,
      organism      = organism,
      keyType       = "kegg",
      minGSSize     = 5,
      maxGSSize     = 500,
      pvalueCutoff  = 1,
      pAdjustMethod = "BH",
      verbose       = FALSE
    ),
    error = function(e) {
      logmsg("  [WARN] gseKEGG:", conditionMessage(e))
      NULL
    }
  )

  n_sig <- if (!is.null(res) && nrow(res@result) > 0)
             sum(res@result$p.adjust < padj_cut, na.rm = TRUE) else 0L
  logmsg("  [GSEA]",
         if (!is.null(res)) nrow(res@result) else 0,
         "pathways |", n_sig, "significant")

  gsea_summary[[length(gsea_summary) + 1]] <- data.table(
    comparison     = comp,
    n_ranked_genes = length(ranked_vec),
    n_pathways     = if (!is.null(res)) nrow(res@result) else 0L,
    n_sig_pathways = as.integer(n_sig)
  )

  if (!is.null(res) && nrow(res@result) > 0) {
    out_base <- file.path(out_dir, "results", paste0(comp, "_KEGG_GSEA"))
    fwrite(as.data.table(res@result),
           paste0(out_base, ".tsv"), sep = "\t", quote = FALSE)

    # Dotplot (NES coloured)
    res_dt <- as.data.table(res@result)[order(p.adjust)]
    sig_dt <- res_dt[p.adjust < padj_cut]

    if (nrow(sig_dt) > 0) {
      n_show  <- min(20L, nrow(sig_dt))
      sig_top <- sig_dt[1:n_show]
      sig_top[, direction := ifelse(NES > 0, "Activated", "Suppressed")]

      p <- ggplot(sig_top,
                  aes(NES, reorder(Description, NES),
                      color = p.adjust, size = setSize)) +
        geom_point() +
        geom_vline(xintercept = 0, linetype = "dashed", colour = "grey50") +
        scale_color_gradient(low = "firebrick", high = "steelblue",
                             name = "padj") +
        scale_size_continuous(name = "Gene set\nsize", range = c(2, 8)) +
        labs(
          title    = paste0(comp, "  |  KEGG GSEA"),
          subtitle = paste0("organism = ", organism,
                            " | BH | ", n_sig, " significant | NES > 0: activated"),
          x = "Normalised Enrichment Score (NES)", y = NULL
        ) +
        theme_bw(base_size = 11) +
        theme(axis.text.y = element_text(size = 8))
      save_plot(p,
                file.path(out_dir, "figures", paste0(comp, "_KEGG_GSEA")),
                w = 9, h = max(5, n_show * 0.38 + 2))
    }

    # Ridge plot (if enrichplot available)
    if (requireNamespace("enrichplot", quietly = TRUE) && nrow(sig_dt) > 0) {
      tryCatch({
        n_ridge <- min(10L, nrow(sig_dt))
        p_ridge <- enrichplot::ridgeplot(res, showCategory = n_ridge,
                                         fill = "p.adjust") +
          labs(title    = paste0(comp, "  |  KEGG GSEA — ridge plot"),
               subtitle = paste0("Top ", n_ridge, " pathways by padj")) +
          theme_bw(base_size = 10)
        save_plot(p_ridge,
                  file.path(out_dir, "figures", paste0(comp, "_KEGG_GSEA_ridge")),
                  w = 9, h = max(5, n_ridge * 0.55 + 2))
      }, error = function(e)
        logmsg("  [WARN] ridge plot:", conditionMessage(e)))
    }
  }
}

if (length(gsea_summary) > 0) {
  gsea_dt <- rbindlist(gsea_summary, fill = TRUE)
  setorder(gsea_dt, comparison)
  fwrite(gsea_dt,
         file.path(out_dir, "results", "kegg_gsea_summary.tsv"),
         sep = "\t", quote = FALSE)
  logmsg("GSEA summary written:", nrow(gsea_dt), "comparisons")
  print(gsea_dt)
}

# =============================================================================
# 4. Combined summary: which pathways are significant across comparisons
# =============================================================================
logmsg("-------------------------------------------------")
logmsg("Building cross-comparison pathway summary...")
logmsg("-------------------------------------------------")

ora_tsv_files <- list.files(file.path(out_dir, "results"),
                             pattern = "_KEGG_ORA_all\\.tsv$", full.names = TRUE)

if (length(ora_tsv_files) > 0) {
  all_ora <- rbindlist(lapply(ora_tsv_files, function(f) {
    dt <- fread(f)
    dt[, comparison := sub("_KEGG_ORA_all\\.tsv$", "", basename(f))]
    dt
  }), fill = TRUE)

  sig_ora <- all_ora[p.adjust < padj_cut]
  logmsg("Significant ORA hits across all comparisons:", nrow(sig_ora),
         "| unique pathways:", uniqueN(sig_ora$ID))

  if (nrow(sig_ora) > 0) {
    # Count how many comparisons each pathway is significant in
    pathway_freq <- sig_ora[, .(
      n_comparisons = .N,
      comparisons   = paste(comparison, collapse = "; "),
      Description   = Description[1],
      mean_GeneRatio = mean(sapply(GeneRatio, function(x) {
        p <- strsplit(x, "/")[[1]]; as.numeric(p[1]) / as.numeric(p[2])
      }), na.rm = TRUE),
      mean_padj     = mean(p.adjust, na.rm = TRUE)
    ), keyby = ID]
    setorder(pathway_freq, -n_comparisons, mean_padj)

    fwrite(pathway_freq,
           file.path(out_dir, "results", "kegg_pathway_frequency.tsv"),
           sep = "\t", quote = FALSE)
    logmsg("Pathway frequency table written:", nrow(pathway_freq), "pathways")

    logmsg("Top recurring pathways:")
    print(pathway_freq[1:min(15, nrow(pathway_freq)),
                        .(ID, Description, n_comparisons, mean_padj)])

    # Bubble plot: top pathways by frequency
    top_pw <- pathway_freq[1:min(20, nrow(pathway_freq))]
    p_freq <- ggplot(top_pw,
                     aes(n_comparisons,
                         reorder(Description, n_comparisons),
                         size  = mean_GeneRatio,
                         color = mean_padj)) +
      geom_point() +
      scale_color_gradient(low = "firebrick", high = "steelblue",
                           name = "Mean\npadj") +
      scale_size_continuous(name = "Mean\ngene ratio", range = c(2, 9)) +
      scale_x_continuous(breaks = seq_len(max(top_pw$n_comparisons))) +
      labs(
        title    = "KEGG pathways significant across pairwise comparisons",
        subtitle = paste0("C. jejuni NCTC 11168 | organism = ", organism,
                          " | ORA (all DEGs) | padj < ", padj_cut),
        x = "Number of comparisons significant in",
        y = NULL
      ) +
      theme_bw(base_size = 11) +
      theme(axis.text.y = element_text(size = 9))
    save_plot(p_freq,
              file.path(out_dir, "figures", "kegg_pathway_frequency"),
              w = 10, h = max(5, nrow(top_pw) * 0.38 + 2))
    logmsg("Pathway frequency plot saved.")
  }
}

logmsg("=================================================")
logmsg("KEGG analysis complete.")
logmsg("  ORA results  :", file.path(out_dir, "results"))
logmsg("  Figures      :", file.path(out_dir, "figures"))
logmsg("=================================================")
