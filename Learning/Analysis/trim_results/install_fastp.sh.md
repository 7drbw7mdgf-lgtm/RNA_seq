# Annotated Script

**Original file:** `Analysis/trim_results/install_fastp.sh`

Related lines are grouped into annotated blocks so each explanation covers a complete piece of workflow logic.

## Lines 1-2

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Script startup. This block selects bash as the interpreter and enables stricter error handling so failures, unset variables, and broken pipelines are caught early.</span>

```bash
#!/usr/bin/env bash
set -euo pipefail
```

## Line 4

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
echo "==== Activating conda ===="
```

## Line 6

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Workflow step. These related commands work together as one small unit in the script, preparing inputs, checking state, or running part of the analysis.</span>

```bash
source ~/miniconda3/etc/profile.d/conda.sh
```

## Line 8

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
echo "==== Creating rna-seq environment if missing ===="
```

## Lines 10-12

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Environment installation. These commands create or update the requested conda environment and install the packages needed by this part of the workflow.</span>

```bash
if ! conda env list | grep -q "^rna-seq "; then
    conda create -y -n rna-seq python=3.11
fi
```

## Line 14

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
echo "==== Activating rna-seq environment ===="
```

## Line 16

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Environment activation. This loads the chosen conda environment into the current shell so the tools installed there are available on PATH.</span>

```bash
conda activate rna-seq
```

## Line 18

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
echo "==== Installing fastp ===="
```

## Line 20

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Environment installation. These commands create or update the requested conda environment and install the packages needed by this part of the workflow.</span>

```bash
conda install -y -c bioconda -c conda-forge fastp
```

## Line 22

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
echo "==== Testing installation ===="
```

## Line 24

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Workflow step. These related commands work together as one small unit in the script, preparing inputs, checking state, or running part of the analysis.</span>

```bash
fastp --version
```

## Line 26

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
echo "==== Done ===="
```

