#!/usr/bin/env bash
set -euo pipefail

# Submit the complete host/bacterial dual RNA-seq pipeline as one SLURM job.
# No interactive input is required; options are passed through to the master
# pipeline driver after a literal "--".

WORKDIR="${WORKDIR:-/home/lshpk18/OzanGundogdu_SOUK011275}"
ANALYSIS_DIR="${ANALYSIS_DIR:-$WORKDIR/Analysis}"
LOG_DIR="${LOG_DIR:-$ANALYSIS_DIR/logs/complete_pipeline/slurm}"
JOB_NAME="${JOB_NAME:-dual_rnaseq_all}"
TIME="${TIME:-48:00:00}"
CPUS="${CPUS:-16}"
MEM="${MEM:-96G}"
PARTITION="${PARTITION:-}"
ACCOUNT="${ACCOUNT:-}"
DRY_RUN="false"

usage() {
  cat <<'USAGE'
Usage:
  bash Analysis/submit_complete_dual_rnaseq_pipeline_slurm.sh [slurm options] -- [pipeline options]

SLURM options:
  --job-name NAME       Job name [dual_rnaseq_all]
  --time HH:MM:SS       Wall time [48:00:00]
  --cpus N              CPUs per task [16]
  --mem SIZE            Memory [96G]
  --partition NAME      Optional partition
  --account NAME        Optional account
  --dry-run             Print the generated sbatch script without submitting
  -h, --help            Show this help

Pipeline options after "--" are passed directly to:
  Analysis/run_complete_dual_rnaseq_pipeline.sh

Examples:
  bash Analysis/submit_complete_dual_rnaseq_pipeline_slurm.sh
  bash Analysis/submit_complete_dual_rnaseq_pipeline_slurm.sh -- --allow-incomplete --design timepoint --force
  bash Analysis/submit_complete_dual_rnaseq_pipeline_slurm.sh --time 72:00:00 --mem 128G -- --require-complete
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --job-name) JOB_NAME="${2:-}"; shift 2 ;;
    --time) TIME="${2:-}"; shift 2 ;;
    --cpus) CPUS="${2:-}"; shift 2 ;;
    --mem) MEM="${2:-}"; shift 2 ;;
    --partition) PARTITION="${2:-}"; shift 2 ;;
    --account) ACCOUNT="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN="true"; shift ;;
    --) shift; break ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: Unknown SLURM option: $1" >&2; exit 1 ;;
  esac
done

mkdir -p "$LOG_DIR"
SBATCH_FILE="$LOG_DIR/${JOB_NAME}_$(date +'%Y%m%d_%H%M%S').sbatch"

{
  echo "#!/usr/bin/env bash"
  echo "#SBATCH --job-name=$JOB_NAME"
  echo "#SBATCH --time=$TIME"
  echo "#SBATCH --cpus-per-task=$CPUS"
  echo "#SBATCH --mem=$MEM"
  echo "#SBATCH --output=$LOG_DIR/%x_%j.out"
  echo "#SBATCH --error=$LOG_DIR/%x_%j.err"
  if [[ -n "$PARTITION" ]]; then
    echo "#SBATCH --partition=$PARTITION"
  fi
  if [[ -n "$ACCOUNT" ]]; then
    echo "#SBATCH --account=$ACCOUNT"
  fi
  echo
  echo "set -euo pipefail"
  echo "cd \"$WORKDIR\""
  echo "export THREADS=\"\${THREADS:-\${SLURM_CPUS_PER_TASK:-$CPUS}}\""
  echo "export OMP_NUM_THREADS=\"\$THREADS\""
  printf 'bash %q' "$ANALYSIS_DIR/run_complete_dual_rnaseq_pipeline.sh"
  for arg in "$@"; do
    printf ' %q' "$arg"
  done
  printf '\n'
} > "$SBATCH_FILE"

if [[ "$DRY_RUN" == "true" ]]; then
  cat "$SBATCH_FILE"
  exit 0
fi

sbatch "$SBATCH_FILE"
