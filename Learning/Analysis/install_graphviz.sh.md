# Annotated Script

**Original file:** `Analysis/install_graphviz.sh`

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
# This script installs Graphviz into the RNA-seq conda environment used by the analysis pipeline.
# It prefers mamba, falls back to micromamba or conda if needed.
```

## Lines 7-8

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Location setup. This resolves the directory containing the script and moves there so relative paths behave consistently no matter where the script was launched from.</span>

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
```

## Lines 10-11

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
ENV_NAME="rna-seq"
PKGS=(graphviz)
```

## Lines 13-23

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Package-manager selection. This block checks which conda-style installer is available, prefers mamba when present, falls back to conda, and stops with a clear error if neither exists.</span>

```bash
if command -v mamba >/dev/null 2>&1; then
  PKG_MANAGER="mamba"
elif command -v micromamba >/dev/null 2>&1; then
  PKG_MANAGER="micromamba"
elif command -v conda >/dev/null 2>&1; then
  PKG_MANAGER="conda"
else
  echo "ERROR: no mamba, micromamba, or conda command found in PATH." >&2
  echo "Install mamba or conda first, then re-run this script." >&2
  exit 1
fi
```

## Lines 25-39

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Environment installation. These commands create or update the requested conda environment and install the packages needed by this part of the workflow.</span>

```bash
if "$PKG_MANAGER" env list 2>/dev/null | grep -E "^${ENV_NAME}(\s|$)" >/dev/null 2>&1; then
  echo "Using existing environment: $ENV_NAME"
  if [ "$PKG_MANAGER" = "conda" ]; then
    conda install -n "$ENV_NAME" -y -c conda-forge "${PKGS[@]}"
  else
    "$PKG_MANAGER" install -n "$ENV_NAME" -y -c conda-forge "${PKGS[@]}"
  fi
else
  echo "Creating environment: $ENV_NAME"
  if [ "$PKG_MANAGER" = "conda" ]; then
    conda create -n "$ENV_NAME" -y -c conda-forge "${PKGS[@]}"
  else
    "$PKG_MANAGER" create -n "$ENV_NAME" -y -c conda-forge "${PKGS[@]}"
  fi
fi
```

## Lines 41-46

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Multi-line message. This here-document prints a longer help or completion message without needing a separate echo command for every line.</span>

```bash
cat <<EOF
Graphviz installed into the $ENV_NAME environment.
Activate the environment with:
  mamba activate $ENV_NAME
Then run your analysis commands from this folder.
EOF
```

