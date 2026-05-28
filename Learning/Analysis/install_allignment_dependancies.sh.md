# Annotated Script

**Original file:** `Analysis/install_allignment_dependancies.sh`

Related lines are grouped into annotated blocks so each explanation covers a complete piece of workflow logic.

## Lines 1-2

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Script startup. This block selects bash as the interpreter and enables stricter error handling so failures, unset variables, and broken pipelines are caught early.</span>

```bash
#!/usr/bin/env bash
set -euo pipefail
```

## Lines 4-5

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Human-facing documentation. These comments explain the purpose, assumptions, or usage of the nearby script before the executable logic begins.</span>

```bash
# Installer for alignment workflow dependencies.
# This script assumes you have conda or mamba installed and available in PATH.
```

## Lines 7-10

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
ENV_NAME="dualrnaseq"
CHANNELS=(-c bioconda -c conda-forge)
DEPS=(star samtools subread python=3.11)
OPTIONAL_DEPS=(multiqc)
```

## Lines 12-15

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
function die() {
  echo "ERROR: $*" >&2
  exit 1
}
```

## Lines 17-19

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Workflow step. These related commands work together as one small unit in the script, preparing inputs, checking state, or running part of the analysis.</span>

```bash
function check_command() {
  command -v "$1" >/dev/null 2>&1
}
```

## Lines 21-23

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
if ! check_command conda && ! check_command mamba; then
  die "Neither conda nor mamba was found in PATH. Install Miniconda/Anaconda or add it to PATH before running this script."
fi
```

## Line 25

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
INSTALLER="$(command -v mamba || command -v conda)"
```

## Lines 27-31

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Multi-line message. This here-document prints a longer help or completion message without needing a separate echo command for every line.</span>

```bash
cat <<EOF
Installing required alignment workflow dependencies into conda environment: $ENV_NAME
Required packages: ${DEPS[*]}
Optional package: ${OPTIONAL_DEPS[*]}
EOF
```

## Lines 33-39

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
if check_command mamba; then
  echo "Using mamba for faster installation."
  "$INSTALLER" create -n "$ENV_NAME" "${DEPS[@]}" "${CHANNELS[@]}" -y
else
  echo "Using conda for installation."
  "$INSTALLER" create -n "$ENV_NAME" "${DEPS[@]}" "${CHANNELS[@]}" -y
fi
```

## Lines 41-44

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Multi-line message. This here-document prints a longer help or completion message without needing a separate echo command for every line.</span>

```bash
echo
cat <<EOF
To use the workflow, activate the environment:
  conda activate $ENV_NAME
```

## Lines 46-49

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Environment installation. These commands create or update the requested conda environment and install the packages needed by this part of the workflow.</span>

```bash
If you want MultiQC support, run:
  conda activate $ENV_NAME
  conda install -n $ENV_NAME -c bioconda -c conda-forge ${OPTIONAL_DEPS[*]} -y
EOF
```

