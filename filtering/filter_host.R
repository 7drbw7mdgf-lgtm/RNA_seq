suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

# ---- Paths ----
counts_file <- Sys.getenv("COUNTS_FILE",
  "/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/FeatureCounts/FeatureCounts_host/featureCounts_host.txt")
out_dir <- Sys.getenv("OUT_DIR",
  "/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/filtering/host")

min_total  <- as.numeric(Sys.getenv("MIN_TOTAL_COUNT", "10"))
timepoints <- c("0h", "15m", "30m", "60m", "3h", "24h")

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(out_dir, "figures"), recursive = TRUE, showWarnings = FALSE)

log_file <- file.path(out_dir, "filter_host.log")
logmsg <- function(...) {
  line <- paste0("[", format(Sys.time(), "%F %T"), "] ", paste(..., collapse = " "))
  cat(line, "\n")
  cat(line, "\n", file = log_file, append = TRUE)
}

logmsg("=== Host featureCounts filtering ===")
logmsg("Input:", counts_file)
logmsg("Output dir:", out_dir)
logmsg("Low-count threshold (rowSums >=):", min_total)

# ---- 1. Read featureCounts ----
logmsg("Reading featureCounts file")
lines <- readLines(counts_file, warn = FALSE)
lines <- lines[!grepl("^#", lines)]
dt    <- fread(text = paste(lines, collapse = "\n"), check.names = FALSE)

gene_col    <- names(dt)[1]
meta_cols   <- intersect(c("Chr", "Start", "End", "Strand", "Length"), names(dt))
count_start <- max(match(meta_cols, names(dt))) + 1
counts      <- dt[, c(gene_col, names(dt)[count_start:ncol(dt)]), with = FALSE]
setnames(counts, gene_col, "gene_id")

# Strip full path and .host.merged.bam suffix -> sample key e.g. 15m_1_Run_1_S4
setnames(counts,
  setdiff(names(counts), "gene_id"),
  sub("\\.host\\.merged\\.bam$", "",
      basename(setdiff(names(counts), "gene_id"))))

n_genes_raw   <- nrow(counts)
n_samples_raw <- ncol(counts) - 1L
logmsg("Raw genes:", n_genes_raw, "| Raw sample columns:", n_samples_raw)

# ---- 2. Build metadata ----
# Host keeps Run_1 and Run_2 as separate observations; run is modelled as a
# batch covariate in DESeq2 (design: ~ run + timepoint).
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

tp_norm <- get_timepoint(all_samples)
run_grp <- get_run(all_samples)
rep_num <- get_replicate(all_samples)

meta <- data.table(
  sample_id = all_samples,
  timepoint = factor(tp_norm, levels = timepoints),
  run       = factor(run_grp, levels = c("Run1", "Run2")),
  replicate = rep_num
)

missing_tp <- meta[is.na(timepoint), sample_id]
if (length(missing_tp))
  stop("Unrecognised timepoint for samples: ", paste(missing_tp, collapse = ", "))

logmsg("Samples per timepoint x run:")
print(meta[, .N, by = .(timepoint, run)][order(timepoint, run)])

# ---- 3. Build integer count matrix ----
mat <- as.matrix(counts[, -"gene_id"])
storage.mode(mat) <- "integer"
rownames(mat) <- make.unique(counts$gene_id)

common <- intersect(colnames(mat), meta$sample_id)
mat    <- mat[, common, drop = FALSE]
meta   <- meta[match(common, sample_id)]

# ---- 4. Low-count filter ----
# rowSums across all 96 columns (48 bio x 2 runs).
keep_mask <- rowSums(mat) >= min_total
n_removed <- sum(!keep_mask)
mat_filt  <- mat[keep_mask, , drop = FALSE]

logmsg("Genes before filter:", nrow(mat))
logmsg("Genes removed (rowSums <", min_total, "):", n_removed)
logmsg("Genes retained:", nrow(mat_filt))
logmsg(sprintf("Retention rate: %.1f%%", 100 * nrow(mat_filt) / nrow(mat)))

# ---- 5. Per-sample total counts summary ----
sample_totals <- colSums(mat_filt)
logmsg(sprintf("Per-sample total count range: %d – %d",
        min(sample_totals), max(sample_totals)))

stats <- data.table(
  step = c("raw_genes", "low_count_removed", "genes_retained"),
  n    = c(n_genes_raw, n_removed, nrow(mat_filt))
)
fwrite(stats, file.path(out_dir, "host_filter_stats.tsv"), sep = "\t")

# ---- 6. Write outputs ----
out_counts <- as.data.table(mat_filt, keep.rownames = "gene_id")
fwrite(out_counts, file.path(out_dir, "host_filtered_counts.tsv"), sep = "\t")
logmsg("Filtered count matrix written:",
       file.path(out_dir, "host_filtered_counts.tsv"))

fwrite(meta, file.path(out_dir, "host_metadata.tsv"), sep = "\t")
logmsg("Metadata written:", file.path(out_dir, "host_metadata.tsv"))

# ---- 7. QC figures ----
# Library size bar chart coloured by timepoint, shaped by run
lib_dt <- data.table(
  sample_id = names(sample_totals),
  total     = sample_totals
)
lib_dt <- merge(lib_dt, meta, by = "sample_id")
lib_dt[, sample_id := factor(sample_id,
         levels = sample_id[order(timepoint, replicate, run)])]

p_lib <- ggplot(lib_dt, aes(sample_id, total / 1e6, fill = timepoint, alpha = run)) +
  geom_col() +
  scale_fill_brewer(palette = "Dark2") +
  scale_alpha_manual(values = c(Run1 = 1, Run2 = 0.55)) +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 5)) +
  labs(title = "Host: per-sample library size (filtered counts)",
       x = NULL, y = "Total mapped reads (millions)",
       fill = "Timepoint", alpha = "Run")

ggsave(file.path(out_dir, "figures", "host_library_sizes.pdf"), p_lib, width = 14, height = 5)
ggsave(file.path(out_dir, "figures", "host_library_sizes.png"), p_lib, width = 14, height = 5, dpi = 300)

# Count-sum distribution before and after filtering
sum_before <- rowSums(mat)
sum_after  <- rowSums(mat_filt)

dist_dt <- rbind(
  data.table(stage = "Before filter", log10_sum = log10(sum_before[sum_before > 0])),
  data.table(stage = "After filter",  log10_sum = log10(sum_after[sum_after  > 0]))
)

p_dist <- ggplot(dist_dt, aes(log10_sum, fill = stage, colour = stage)) +
  geom_density(alpha = 0.4) +
  geom_vline(xintercept = log10(min_total), linetype = "dashed", colour = "grey40") +
  annotate("text", x = log10(min_total), y = Inf, hjust = -0.1, vjust = 1.5,
           label = paste0("threshold=", min_total), size = 3, colour = "grey30") +
  scale_fill_manual(values   = c("Before filter" = "#4DAF4A", "After filter" = "#377EB8")) +
  scale_colour_manual(values = c("Before filter" = "#4DAF4A", "After filter" = "#377EB8")) +
  theme_bw() +
  labs(title = "Host: gene count-sum distribution",
       x = "log10(row sum across all samples)", y = "Density",
       fill = NULL, colour = NULL)

ggsave(file.path(out_dir, "figures", "host_count_distribution.pdf"), p_dist, width = 7, height = 5)
ggsave(file.path(out_dir, "figures", "host_count_distribution.png"), p_dist, width = 7, height = 5, dpi = 300)

# Run-level library size comparison (boxplot)
p_run <- ggplot(lib_dt, aes(run, total / 1e6, fill = run)) +
  geom_boxplot(outlier.shape = 21, width = 0.5) +
  geom_jitter(width = 0.1, size = 1.5, alpha = 0.7) +
  scale_fill_manual(values = c(Run1 = "#E41A1C", Run2 = "#377EB8")) +
  theme_bw() +
  labs(title = "Host: library size by sequencing run",
       x = NULL, y = "Total mapped reads (millions)", fill = NULL)

ggsave(file.path(out_dir, "figures", "host_library_by_run.pdf"), p_run, width = 5, height = 5)
ggsave(file.path(out_dir, "figures", "host_library_by_run.png"), p_run, width = 5, height = 5, dpi = 300)

logmsg("Figures saved to", file.path(out_dir, "figures"))
logmsg("=== Host filtering complete ===")
