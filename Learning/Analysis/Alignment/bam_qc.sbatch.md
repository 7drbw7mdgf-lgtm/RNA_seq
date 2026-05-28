# Annotated Script

**Original file:** `Analysis/Alignment/bam_qc.sbatch`

Related lines are grouped into annotated blocks so each explanation covers a complete piece of workflow logic.

## Lines 1-11

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Script startup. This block selects bash as the interpreter and enables stricter error handling so failures, unset variables, and broken pipelines are caught early.</span>

```bash
#!/bin/bash
#SBATCH --job-name=bam_qc
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/logs/bam_qc_%j.log
#SBATCH --error=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/logs/bam_qc_%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=lshpk18@lshtm.ac.uk
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=40G
#SBATCH --time=24:00:00
#SBATCH --chdir=/home/lshpk18/OzanGundogdu_SOUK011275
```

## Lines 13-22

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Human-facing documentation. These comments explain the purpose, assumptions, or usage of the nearby script before the executable logic begins.</span>

```bash
# BAM QC SLURM wrapper for the dual RNA-seq alignment outputs.
#
# Usage:
#   sbatch Analysis/Alignment/bam_qc.sbatch
#   sbatch --export=TARGET=host Analysis/Alignment/bam_qc.sbatch
#   sbatch --export=TARGET=bacteria Analysis/Alignment/bam_qc.sbatch
#   sbatch --export=TARGET=all,THREADS=8 Analysis/Alignment/bam_qc.sbatch
#
# Environment overrides:
#   WORKDIR, ALIGNMENT_DIR, BAM_DIR, OUT_DIR, TARGET, THREADS, CONDA_ENV, SKIP_CONDA
```

## Line 24

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Script startup. This block selects bash as the interpreter and enables stricter error handling so failures, unset variables, and broken pipelines are caught early.</span>

```bash
set -euo pipefail
```

## Lines 26-35

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
WORKDIR="${WORKDIR:-/home/lshpk18/OzanGundogdu_SOUK011275}"
ALIGNMENT_DIR="${ALIGNMENT_DIR:-$WORKDIR/Analysis/Alignment}"
QC_SCRIPT="${QC_SCRIPT:-$ALIGNMENT_DIR/Alligment_QC}"
BAM_DIR="${BAM_DIR:-$ALIGNMENT_DIR/bam}"
OUT_DIR="${OUT_DIR:-$ALIGNMENT_DIR/alignment_QC}"
TARGET="${TARGET:-all}"
THREADS="${THREADS:-${SLURM_CPUS_PER_TASK:-16}}"
CONDA_ENV="${CONDA_ENV:-dualrnaseq}"
SKIP_CONDA="${SKIP_CONDA:-false}"
LOG_DIR="${ALIGNMENT_DIR}/logs"
```

## Line 37

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Output preparation. This creates the directories needed by later commands, using `-p` where appropriate so reruns do not fail if folders already exist.</span>

```bash
mkdir -p "$LOG_DIR"
```

## Lines 39-53

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
echo "======================================"
echo "Dual RNA-Seq BAM QC SLURM Job"
echo "======================================"
echo "Job ID: ${SLURM_JOB_ID:-manual}"
echo "Node: $(hostname)"
echo "CPUs: ${SLURM_CPUS_PER_TASK:-$THREADS}"
echo "Memory: ${SLURM_MEM_M:-${SLURM_MEM_PER_NODE:-unknown}} MB"
echo "Start time: $(date)"
echo "Workdir: $WORKDIR"
echo "BAM directory: $BAM_DIR"
echo "Output directory: $OUT_DIR"
echo "Target: $TARGET"
echo "Threads: $THREADS"
echo "Conda env: ${CONDA_ENV:-none}"
echo ""
```

## Lines 55-61

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Choice handling. This case block selects behaviour from a small set of valid values, such as deciding which target, step, or mode the script should run.</span>

```bash
case "$TARGET" in
  host|bacteria|all) ;;
  *)
    echo "ERROR: TARGET must be one of: host, bacteria, all" >&2
    exit 1
    ;;
esac
```

## Lines 63-66

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
if [[ ! -f "$QC_SCRIPT" ]]; then
  echo "ERROR: BAM QC script not found: $QC_SCRIPT" >&2
  exit 1
fi
```

## Lines 68-71

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
if [[ ! -d "$BAM_DIR" ]]; then
  echo "ERROR: BAM directory not found: $BAM_DIR" >&2
  exit 1
fi
```

## Lines 73-80

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Environment activation. This loads the chosen conda environment into the current shell so the tools installed there are available on PATH.</span>

```bash
if [[ "$SKIP_CONDA" != "true" && -n "$CONDA_ENV" ]]; then
  echo "Activating conda environment: $CONDA_ENV"
  if [[ ! -f /home/lshpk18/miniconda3/bin/activate ]]; then
    echo "ERROR: conda activate script not found: /home/lshpk18/miniconda3/bin/activate" >&2
    exit 1
  fi
  source /home/lshpk18/miniconda3/bin/activate "$CONDA_ENV"
fi
```

## Lines 82-89

> <span style="color: #00bcd4;"><strong>Annotation:</strong> BAM processing and QC. These commands use samtools to index, inspect, or summarize alignment files for downstream checks.</span>

```bash
echo "Checking required BAM QC tools..."
for tool in samtools qualimap infer_experiment.py inner_distance.py read_distribution.py; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: required tool not found in PATH: $tool" >&2
    exit 1
  fi
  echo "  $tool: $(command -v "$tool")"
done
```

## Lines 91-97

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
echo ""
echo "Running BAM QC..."
bash "$QC_SCRIPT" \
  --target "$TARGET" \
  --bam-dir "$BAM_DIR" \
  --out-dir "$OUT_DIR" \
  --threads "$THREADS"
```

## Lines 99-104

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
echo ""
echo "======================================"
echo "BAM QC Completed Successfully"
echo "======================================"
echo "End time: $(date)"
echo "Summary directory: $OUT_DIR/summary"
```

