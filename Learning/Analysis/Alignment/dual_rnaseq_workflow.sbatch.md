# Annotated Script

**Original file:** `Analysis/Alignment/dual_rnaseq_workflow.sbatch`

Related lines are grouped into annotated blocks so each explanation covers a complete piece of workflow logic.

## Lines 1-4

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Script startup. This block selects bash as the interpreter and enables stricter error handling so failures, unset variables, and broken pipelines are caught early.</span>

```bash
#!/bin/bash
#SBATCH --job-name=dual_rnaseq
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/logs/dual_rnaseq_slurm_%j.log
#SBATCH --error=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/logs/dual_rnaseq_slurm_%j.err
```

## Lines 6-12

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Slurm job configuration. These scheduler directives describe how the job should run, including its name, log files, runtime, CPU, memory, notification, or working-directory settings.</span>

```bash
#SBATCH --mail-type=BEGIN,END,FAIL          # Mail events (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-user=lshpk18@lshtm.ac.uk # Where to send mail
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=40gb                     # Job memory request
#SBATCH --time=70:05:00               # Time limit hrs:min:sec
#SBATCH --chdir=/home/lshpk18/OzanGundogdu_SOUK011275
```

## Lines 14-21

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Human-facing documentation. These comments explain the purpose, assumptions, or usage of the nearby script before the executable logic begins.</span>

```bash
# Dual RNA-Seq Workflow SLURM Job Script
# Runs the dual_rnaseq_workflow.sh for host and bacterial genome alignment
# 
# Usage:
#   sbatch dual_rnaseq_workflow.sbatch                    # Run full workflow (all steps)
#   sbatch --export=STEP=index dual_rnaseq_workflow.sbatch
#   sbatch --export=STEP=align dual_rnaseq_workflow.sbatch
#   sbatch --export=STEP=counts dual_rnaseq_workflow.sbatch
```

## Line 23

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Script startup. This block selects bash as the interpreter and enables stricter error handling so failures, unset variables, and broken pipelines are caught early.</span>

```bash
set -euo pipefail
```

## Lines 25-32

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Workflow step. These related commands work together as one small unit in the script, preparing inputs, checking state, or running part of the analysis.</span>

```bash
# Configuration
WORKDIR="${WORKDIR:-/home/lshpk18/OzanGundogdu_SOUK011275}"
SCRIPT="${WORKDIR}/Analysis/Alignment/dual_rnaseq_workflow.sh"
STEP="${STEP:-all}"  # Default to running all steps
SAMPLE="${SAMPLE:-}"  # Optional: specific sample to align
SAMPLE_LIST="${SAMPLE_LIST:-${WORKDIR}/Analysis/Alignment/sample_names.txt}"
FORCE="${FORCE:-false}"
CONDA_ENV="${CONDA_ENV:-dualrnaseq}"
```

## Lines 34-36

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Output preparation. This creates the directories needed by later commands, using `-p` where appropriate so reruns do not fail if folders already exist.</span>

```bash
# Logging
LOG_DIR="${WORKDIR}/Analysis/Alignment/logs"
mkdir -p "$LOG_DIR"
```

## Lines 38-51

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
echo "======================================"
echo "Dual RNA-Seq Workflow SLURM Job"
echo "======================================"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $(hostname)"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: ${SLURM_MEM_M:-${SLURM_MEM_PER_NODE:-unknown}} MB"
echo "Start time: $(date)"
echo "Step: $STEP"
echo "Workdir: $WORKDIR"
if [[ -n "$SAMPLE" ]]; then
  echo "Sample: $SAMPLE"
fi
echo ""
```

## Lines 53-61

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Environment activation. This loads the chosen conda environment into the current shell so the tools installed there are available on PATH.</span>

```bash
# Activate the conda environment used by the workflow.
if [[ -n "$CONDA_ENV" ]]; then
  echo "Activating conda environment: $CONDA_ENV"
  if [[ ! -f /home/lshpk18/miniconda3/bin/activate ]]; then
    echo "ERROR: conda activate script not found: /home/lshpk18/miniconda3/bin/activate" >&2
    exit 1
  fi
  source /home/lshpk18/miniconda3/bin/activate "$CONDA_ENV"
fi
```

## Lines 63-86

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
# Load required modules only when a conda environment was not requested.
if [[ -z "$CONDA_ENV" ]]; then
  echo "Loading modules..."
fi
if [[ -z "$CONDA_ENV" ]] && command -v module >/dev/null 2>&1; then
  # Try loading common module names - adjust for your cluster
  if module avail STAR/2.7.* >/dev/null 2>&1; then
    module load STAR
  elif module avail star >/dev/null 2>&1; then
    module load star
  fi
  
  if module avail samtools >/dev/null 2>&1; then
    module load samtools
  fi
  
  if module avail subread >/dev/null 2>&1; then
    module load subread
  fi
else
  if [[ -z "$CONDA_ENV" ]]; then
    echo "Module system not available - assuming tools are in PATH"
  fi
fi
```

## Lines 88-96

> <span style="color: #00bcd4;"><strong>Annotation:</strong> STAR alignment step. This block runs STAR-related commands to build indexes or align reads against the configured reference.</span>

```bash
# Verify required tools are available
echo "Checking for required tools..."
for tool in STAR samtools; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "WARNING: $tool not found in PATH"
  else
    echo "  ✓ $tool found"
  fi
done
```

## Lines 98-102

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
echo ""
echo "======================================"
echo "Running workflow step: $STEP"
echo "======================================"
echo ""
```

## Lines 104-108

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Workflow step. These related commands work together as one small unit in the script, preparing inputs, checking state, or running part of the analysis.</span>

```bash
# Run the workflow script
SCRIPT_ARGS=(--step "$STEP")
if [[ "${FORCE,,}" == "true" ]]; then
  SCRIPT_ARGS+=(--force)
fi
```

## Lines 110-121

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
if [[ -n "${SLURM_ARRAY_TASK_ID:-}" ]]; then
  if [[ ! -f "$SAMPLE_LIST" ]]; then
    echo "ERROR: sample list not found for array job: $SAMPLE_LIST" >&2
    exit 1
  fi
  SAMPLE="$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLE_LIST")"
  if [[ -z "$SAMPLE" ]]; then
    echo "ERROR: no sample found for SLURM_ARRAY_TASK_ID=$SLURM_ARRAY_TASK_ID in $SAMPLE_LIST" >&2
    exit 1
  fi
  echo "Array task sample: $SAMPLE"
fi
```

## Lines 123-125

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
if [[ -n "$SAMPLE" ]]; then
  SCRIPT_ARGS+=(--sample "$SAMPLE")
fi
```

## Lines 127-130

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
if [[ ! -f "$SCRIPT" ]]; then
  echo "ERROR: Workflow script not found: $SCRIPT"
  exit 1
fi
```

## Lines 132-133

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Workflow step. These related commands work together as one small unit in the script, preparing inputs, checking state, or running part of the analysis.</span>

```bash
# Set THREADS environment variable
export THREADS=$SLURM_CPUS_PER_TASK
```

## Lines 135-136

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Workflow step. These related commands work together as one small unit in the script, preparing inputs, checking state, or running part of the analysis.</span>

```bash
# Run the workflow
bash "$SCRIPT" "${SCRIPT_ARGS[@]}"
```

## Lines 138-143

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
echo ""
echo "======================================"
echo "Workflow Completed Successfully"
echo "======================================"
echo "End time: $(date)"
echo ""
```

## Lines 145-150

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
# Print summary statistics
echo "Output directories summary:"
echo "  Alignments: $(find ${WORKDIR}/Analysis/Alignment/alignments -type f 2>/dev/null | wc -l) files"
echo "  BAM files: $(find ${WORKDIR}/Analysis/Alignment/bam -type f -name "*.bam" 2>/dev/null | wc -l) files"
echo "  Logs: $(find ${LOG_DIR} -type f 2>/dev/null | wc -l) files"
echo "  QC reports: $(find ${WORKDIR}/Analysis/Alignment/qc -type f 2>/dev/null | wc -l) files"
```

## Lines 152-157

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
if [[ -d "${WORKDIR}/Analysis/Alignment/counts" ]]; then
  count_files=$(find ${WORKDIR}/Analysis/Alignment/counts -type f 2>/dev/null | wc -l)
  if [[ $count_files -gt 0 ]]; then
    echo "  Count tables: $count_files files"
  fi
fi
```

