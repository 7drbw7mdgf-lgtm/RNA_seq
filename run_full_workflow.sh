#!/usr/bin/env bash
set -euo pipefail

DE_DIR="${DE_DIR:-/home/lshpk18/dual_rnaseq_timecourse_workflow}"
CONFIG="${CONFIG:-$DE_DIR/config/workflow.env}"
[[ -s "$CONFIG" ]] || { echo "Missing config: $CONFIG" >&2; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG"

LOG_DIR="$DE_DIR/logs"
PROGRESS_LOG="$LOG_DIR/progress.log"
MASTER_LOG="$LOG_DIR/master_workflow_$(date +'%Y%m%d_%H%M%S').log"
mkdir -p "$LOG_DIR"

timestamp() { date +'%Y-%m-%d %H:%M:%S'; }
progress() { printf '[%s] [MASTER] %s\n' "$(timestamp)" "$*" | tee -a "$PROGRESS_LOG" "$MASTER_LOG"; }
fail() { progress "FAILED: $*"; exit 1; }
run_step() {
  local pct="$1"; shift
  local name="$1"; shift
  progress "START ${pct}%: $name"
  if "$@" >>"$MASTER_LOG" 2>&1; then
    progress "DONE ${pct}%: $name"
  else
    fail "$name failed. See $MASTER_LOG"
  fi
}
activate_env() {
  local env_name="$1"
  if [[ -f /home/lshpk18/miniconda3/bin/activate ]]; then
    # shellcheck disable=SC1091
    source /home/lshpk18/miniconda3/bin/activate "$env_name" || true
  fi
}

progress "Reusable dual RNA-seq time-course workflow started"
progress "Config: $CONFIG"
progress "Required timepoints: $REQUIRED_TIMEPOINTS"
progress "Regenerating output directories from scratch; scripts, slurm, config, docs, data, and references are preserved"

find "$DE_DIR" -mindepth 1 -maxdepth 1 \
  ! -name scripts ! -name slurm ! -name config ! -name logs ! -name data ! -name references ! -name docs ! -name README.md \
  ! -name run_full_workflow.sh ! -name monitor_progress.sh ! -name submit_master_workflow.sh ! -name setup_workflow.sh \
  -exec rm -rf {} +
mkdir -p "$DE_DIR"/{figures,results,qc,objects,tables,logs}

run_step 5 "Install/check system and R dependencies" bash "$DE_DIR/scripts/00_install_dependencies.sh"
activate_env "$CONDA_ENV_DESEQ2"
run_step 20 "Validate inputs and repair metadata/count/BAM issues" Rscript "$DE_DIR/scripts/01_validate_repair_inputs.R" "$CONFIG"
run_step 45 "Run DESeq2 time-course analysis" Rscript "$DE_DIR/scripts/02_deseq2_timecourse.R" "$CONFIG"
run_step 65 "Generate publication-quality figures" Rscript "$DE_DIR/scripts/03_generate_figures.R" "$CONFIG"
activate_env "$CONDA_ENV_PATHWAY"
run_step 82 "Run enrichment analyses" Rscript "$DE_DIR/scripts/04_enrichment.R" "$CONFIG"
activate_env "$CONDA_ENV_DESEQ2"
run_step 92 "Run host-pathogen correlation/network analysis" Rscript "$DE_DIR/scripts/05_host_pathogen_correlation.R" "$CONFIG"
run_step 100 "Write session information and final summary" Rscript "$DE_DIR/scripts/06_session_summary.R" "$CONFIG"
progress "SUCCESS: reusable workflow complete"
