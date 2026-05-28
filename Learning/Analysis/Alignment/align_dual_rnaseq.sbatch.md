# Annotated Script

**Original file:** `Analysis/Alignment/align_dual_rnaseq.sbatch`

Related lines are grouped into annotated blocks so each explanation covers a complete piece of workflow logic.

## Lines 1-8

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Script startup. This block selects bash as the interpreter and enables stricter error handling so failures, unset variables, and broken pipelines are caught early.</span>

```bash
#!/bin/bash
#SBATCH --job-name=dualRNA_STAR
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/logs/align_%A_%a.out
#SBATCH --error=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/logs/align_%A_%a.err
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=16
#SBATCH --mem=120G
#SBATCH --array=1-100%10
```

## Line 10

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Script startup. This block selects bash as the interpreter and enables stricter error handling so failures, unset variables, and broken pipelines are caught early.</span>

```bash
set -euo pipefail
```

## Lines 12-13

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
WORKDIR="/home/lshpk18/OzanGundogdu_SOUK011275"
cd "$WORKDIR"
```

## Lines 15-16

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Human-facing documentation. These comments explain the purpose, assumptions, or usage of the nearby script before the executable logic begins.</span>

```bash
# If you need a conda environment, activate it here.
# source /home/lshpk18/miniconda3/bin/activate rna-seq
```

## Lines 18-19

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
SAMPLE_LIST="$WORKDIR/Analysis/Alignment/sample_names.txt"
RAW_DIR="$WORKDIR/Analysis/trim_results"
```

## Lines 21-23

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
if [[ ! -f "$SAMPLE_LIST" ]]; then
  ls "$RAW_DIR"/*_R1*_trimmed.fastq.gz | sed -E 's@.*/@@' | sed -E 's/_R1(_[0-9A-Za-z]+)?_trimmed\.fastq\.gz$//' | sort -u > "$SAMPLE_LIST"
fi
```

## Lines 25-29

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
SAMPLE_NAME=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLE_LIST")
if [[ -z "$SAMPLE_NAME" ]]; then
  echo "No sample found for SLURM_ARRAY_TASK_ID=$SLURM_ARRAY_TASK_ID" >&2
  exit 1
fi
```

## Line 31

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Workflow step. These related commands work together as one small unit in the script, preparing inputs, checking state, or running part of the analysis.</span>

```bash
bash Analysis/Alignment/dual_rnaseq_workflow.sh --step align --sample "$SAMPLE_NAME"
```

