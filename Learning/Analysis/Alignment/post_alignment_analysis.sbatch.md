# Annotated Script

**Original file:** `Analysis/Alignment/post_alignment_analysis.sbatch`

Related lines are grouped into annotated blocks so each explanation covers a complete piece of workflow logic.

## Lines 1-11

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Script startup. This block selects bash as the interpreter and enables stricter error handling so failures, unset variables, and broken pipelines are caught early.</span>

```bash
#!/bin/bash
#SBATCH --job-name=post_align
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/logs/post_alignment_%j.log
#SBATCH --error=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/logs/post_alignment_%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=lshpk18@lshtm.ac.uk
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=40G
#SBATCH --time=24:00:00
#SBATCH --chdir=/home/lshpk18/OzanGundogdu_SOUK011275
```

## Lines 13-25

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Human-facing documentation. These comments explain the purpose, assumptions, or usage of the nearby script before the executable logic begins.</span>

```bash
# Resumable post-alignment analysis Slurm wrapper.
#
# Usage:
#   sbatch Analysis/Alignment/post_alignment_analysis.sbatch
#   sbatch --export=ALLOW_INCOMPLETE=true Analysis/Alignment/post_alignment_analysis.sbatch
#   sbatch --export=SKIP_COUNTS=true Analysis/Alignment/post_alignment_analysis.sbatch
#   sbatch --export=SKIP_QC=true Analysis/Alignment/post_alignment_analysis.sbatch
#   sbatch --export=FORCE=true Analysis/Alignment/post_alignment_analysis.sbatch
#   sbatch --export=DRY_RUN=true,ALLOW_INCOMPLETE=true Analysis/Alignment/post_alignment_analysis.sbatch
#
# Environment overrides:
#   WORKDIR, ALIGNMENT_DIR, OUT_DIR, THREADS, CONDA_ENV, ALLOW_INCOMPLETE,
#   SKIP_COUNTS, SKIP_QC, FORCE, DRY_RUN, SKIP_CONDA
```

## Line 27

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Script startup. This block selects bash as the interpreter and enables stricter error handling so failures, unset variables, and broken pipelines are caught early.</span>

```bash
set -euo pipefail
```

## Lines 29-34

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
WORKDIR="${WORKDIR:-/home/lshpk18/OzanGundogdu_SOUK011275}"
ALIGNMENT_DIR="${ALIGNMENT_DIR:-$WORKDIR/Analysis/Alignment}"
SCRIPT="${SCRIPT:-$ALIGNMENT_DIR/post_alignment_analysis.sh}"
LOG_DIR="${ALIGNMENT_DIR}/logs"
THREADS="${THREADS:-${SLURM_CPUS_PER_TASK:-16}}"
CONDA_ENV="${CONDA_ENV:-dualrnaseq}"
```

## Lines 36-41

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
ALLOW_INCOMPLETE="${ALLOW_INCOMPLETE:-false}"
SKIP_COUNTS="${SKIP_COUNTS:-false}"
SKIP_QC="${SKIP_QC:-false}"
FORCE="${FORCE:-false}"
DRY_RUN="${DRY_RUN:-false}"
SKIP_CONDA="${SKIP_CONDA:-false}"
```

## Line 43

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Output preparation. This creates the directories needed by later commands, using `-p` where appropriate so reruns do not fail if folders already exist.</span>

```bash
mkdir -p "$LOG_DIR"
```

## Lines 45-62

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
echo "======================================"
echo "Post-Alignment Analysis SLURM Job"
echo "======================================"
echo "Job ID: ${SLURM_JOB_ID:-manual}"
echo "Node: $(hostname)"
echo "CPUs: ${SLURM_CPUS_PER_TASK:-$THREADS}"
echo "Memory: ${SLURM_MEM_M:-${SLURM_MEM_PER_NODE:-unknown}} MB"
echo "Start time: $(date)"
echo "Workdir: $WORKDIR"
echo "Script: $SCRIPT"
echo "Threads: $THREADS"
echo "Conda env: ${CONDA_ENV:-none}"
echo "Allow incomplete: $ALLOW_INCOMPLETE"
echo "Skip counts: $SKIP_COUNTS"
echo "Skip QC: $SKIP_QC"
echo "Force: $FORCE"
echo "Dry run: $DRY_RUN"
echo ""
```

## Lines 64-67

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
if [[ ! -f "$SCRIPT" ]]; then
  echo "ERROR: post-alignment script not found: $SCRIPT" >&2
  exit 1
fi
```

## Line 69

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
SCRIPT_ARGS=(--threads "$THREADS")
```

## Lines 71-73

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
if [[ "${ALLOW_INCOMPLETE,,}" == "true" ]]; then
  SCRIPT_ARGS+=(--allow-incomplete)
fi
```

## Lines 75-77

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
if [[ "${SKIP_COUNTS,,}" == "true" ]]; then
  SCRIPT_ARGS+=(--skip-counts)
fi
```

## Lines 79-81

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
if [[ "${SKIP_QC,,}" == "true" ]]; then
  SCRIPT_ARGS+=(--skip-qc)
fi
```

## Lines 83-85

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
if [[ "${FORCE,,}" == "true" ]]; then
  SCRIPT_ARGS+=(--force)
fi
```

## Lines 87-89

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
if [[ "${DRY_RUN,,}" == "true" ]]; then
  SCRIPT_ARGS+=(--dry-run)
fi
```

## Lines 91-93

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
if [[ "${SKIP_CONDA,,}" == "true" ]]; then
  SCRIPT_ARGS+=(--skip-conda)
fi
```

## Line 95

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
export THREADS CONDA_ENV
```

## Lines 97-100

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
echo "Running:"
printf '  bash %q' "$SCRIPT"
printf ' %q' "${SCRIPT_ARGS[@]}"
printf '\n\n'
```

## Line 102

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Workflow step. These related commands work together as one small unit in the script, preparing inputs, checking state, or running part of the analysis.</span>

```bash
bash "$SCRIPT" "${SCRIPT_ARGS[@]}"
```

## Lines 104-110

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
echo ""
echo "======================================"
echo "Post-Alignment Analysis Completed"
echo "======================================"
echo "End time: $(date)"
echo "Summary: ${ALIGNMENT_DIR}/post_alignment_analysis/post_alignment_summary.txt"
echo "Resume state: ${ALIGNMENT_DIR}/post_alignment_analysis/resume_state.tsv"
```

