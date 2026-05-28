# Annotated Script

**Original file:** `Analysis/Alignment/submit_dual_rnaseq_slurm.sh`

Related lines are grouped into annotated blocks so each explanation covers a complete piece of workflow logic.

## Lines 1-10

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Script startup. This block selects bash as the interpreter and enables stricter error handling so failures, unset variables, and broken pipelines are caught early.</span>

```bash
#!/usr/bin/env bash
#SBATCH --job-name=serial_test    # Job name
#SBATCH --mail-type=END,FAIL          # Mail events (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-user=email@lshtm.ac.uk # Where to send mail
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=30gb                     # Job memory request
#SBATCH --time=72:05:00               # Time limit hrs:min:sec
#SBATCH --chdir=/home/lshpk18/OzanGundogdu_SOUK011275
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/serial_test_%j.log
```

## Line 12

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Script startup. This block selects bash as the interpreter and enables stricter error handling so failures, unset variables, and broken pipelines are caught early.</span>

```bash
set -euo pipefail
```

## Lines 14-15

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
WORKDIR="/home/lshpk18/OzanGundogdu_SOUK011275"
cd "$WORKDIR"
```

## Lines 17-20

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Environment activation. This loads the chosen conda environment into the current shell so the tools installed there are available on PATH.</span>

```bash
if [[ ! -f /home/lshpk18/miniconda3/bin/activate ]]; then
  echo "ERROR: conda activate script not found: /home/lshpk18/miniconda3/bin/activate" >&2
  exit 1
fi
```

## Lines 22-23

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Environment activation. This loads the chosen conda environment into the current shell so the tools installed there are available on PATH.</span>

```bash
source /home/lshpk18/miniconda3/bin/activate dualrnaseq
export THREADS="${SLURM_CPUS_PER_TASK:-16}"
```

## Line 25

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Workflow step. These related commands work together as one small unit in the script, preparing inputs, checking state, or running part of the analysis.</span>

```bash
bash "$WORKDIR/Analysis/Alignment/dual_rnaseq_workflow.sh"
```

