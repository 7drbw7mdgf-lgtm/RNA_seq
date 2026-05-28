# Annotated Script

**Original file:** `Analysis/trim_results/trim_fastp.sh`

Related lines are grouped into annotated blocks so each explanation covers a complete piece of workflow logic.

## Lines 1-2

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Script startup. This block selects bash as the interpreter and enables stricter error handling so failures, unset variables, and broken pipelines are caught early.</span>

```bash
#!/usr/bin/env bash
set -euo pipefail
```

## Lines 4-5

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Location setup. This resolves the directory containing the script and moves there so relative paths behave consistently no matter where the script was launched from.</span>

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
```

## Lines 7-9

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
FASTQ_DIR="${FASTQ_DIR:-/home/lshpk18/OzanGundogdu_SOUK011275}"
OUTPUT_DIR="$SCRIPT_DIR"
THREADS="${THREADS:-4}"
```

## Lines 11-15

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Environment activation. This loads the chosen conda environment into the current shell so the tools installed there are available on PATH.</span>

```bash
if ! command -v fastp >/dev/null 2>&1; then
  echo "ERROR: fastp not found in PATH."
  echo "Run: conda activate rna-seq"
  exit 1
fi
```

## Lines 17-22

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
if [[ ! -d "$FASTQ_DIR" ]]; then
  echo "ERROR: FASTQ input directory not found: $FASTQ_DIR"
  echo "Set it with:"
  echo "export FASTQ_DIR=/home/lshpk18/OzanGundogdu_SOUK011275"
  exit 1
fi
```

## Lines 24-25

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
echo "Using FASTQ_DIR: $FASTQ_DIR"
echo "Writing trimmed files to: $OUTPUT_DIR"
```

## Line 27

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Workflow step. These related commands work together as one small unit in the script, preparing inputs, checking state, or running part of the analysis.</span>

```bash
shopt -s nullglob
```

## Line 29

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
R1_FILES=("$FASTQ_DIR"/*_R1_001.fastq.gz)
```

## Lines 31-34

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
if [[ ${#R1_FILES[@]} -eq 0 ]]; then
  echo "ERROR: No R1 FASTQ files found in $FASTQ_DIR"
  exit 1
fi
```

## Lines 36-65

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Repeated work. This loop applies the same operation to each item in a list, such as samples, files, targets, or package names.</span>

```bash
for R1 in "${R1_FILES[@]}"; do
  R2="${R1/_R1_001.fastq.gz/_R2_001.fastq.gz}"

  if [[ ! -f "$R2" ]]; then
    echo "WARNING: No matching R2 found for $R1. Skipping."
    continue
  fi

  SAMPLE="$(basename "$R1" _R1_001.fastq.gz)"

  echo "Trimming: $SAMPLE"

  fastp \
    -i "$R1" \
    -I "$R2" \
    -o "$OUTPUT_DIR/${SAMPLE}_R1_trimmed.fastq.gz" \
    -O "$OUTPUT_DIR/${SAMPLE}_R2_trimmed.fastq.gz" \
    --detect_adapter_for_pe \
    --cut_front \
    --cut_tail \
    --cut_window_size 4 \
    --cut_mean_quality 20 \
    --qualified_quality_phred 20 \
    --unqualified_percent_limit 40 \
    --n_base_limit 5 \
    --length_required 30 \
    --thread "$THREADS" \
    --html "$OUTPUT_DIR/${SAMPLE}_fastp.html" \
    --json "$OUTPUT_DIR/${SAMPLE}_fastp.json"
done
```

## Lines 67-68

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
echo "All trimming complete."
echo "Trimmed FASTQ files are in: $OUTPUT_DIR"
```

