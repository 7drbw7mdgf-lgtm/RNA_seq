# Annotated Script

**Original file:** `Analysis/trim_results/run_multiqc_trimmed.sh`

Related lines are grouped into annotated blocks so each explanation covers a complete piece of workflow logic.

## Lines 1-2

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Script startup. This block selects bash as the interpreter and enables stricter error handling so failures, unset variables, and broken pipelines are caught early.</span>

```bash
#!/usr/bin/env bash
set -euo pipefail
```

## Lines 4-6

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
TRIM_DIR="${TRIM_DIR:-/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/trim_results}"
OUTPUT_DIR="${OUTPUT_DIR:-/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/trimmed_fastqc_results}"
LOG_FILE="${LOG_FILE:-$OUTPUT_DIR/run_multiqc_trimmed.log}"
```

## Lines 8-12

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
if ! command -v multiqc >/dev/null 2>&1; then
  echo "ERROR: multiqc is not installed or not in PATH."
  echo "Install it with conda/mamba or run /home/lshpk18/OzanGundogdu_SOUK011275/install_qc_dependencies.sh"
  exit 1
fi
```

## Lines 14-17

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
if [[ ! -d "$TRIM_DIR" ]]; then
  echo "ERROR: trimmed data directory not found: $TRIM_DIR"
  exit 1
fi
```

## Line 19

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Output preparation. This creates the directories needed by later commands, using `-p` where appropriate so reruns do not fail if folders already exist.</span>

```bash
mkdir -p "$OUTPUT_DIR"
```

## Line 21

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Running MultiQC on trimmed data in $TRIM_DIR" | tee "$LOG_FILE"
```

## Line 23

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Workflow step. These related commands work together as one small unit in the script, preparing inputs, checking state, or running part of the analysis.</span>

```bash
multiqc "$TRIM_DIR" -o "$OUTPUT_DIR" --force 2>&1 | tee -a "$LOG_FILE"
```

## Line 25

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
echo "MultiQC complete. Results are in $OUTPUT_DIR"
```

