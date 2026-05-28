# Annotated Script

**Original file:** `Analysis/install_mamba.sh`

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
# Install mamba via an existing conda installation if available.
# If conda is not installed, use micromamba to bootstrap a local mamba prefix.
```

## Line 7

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Lines 9-12

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Package-manager selection. This block checks which conda-style installer is available, prefers mamba when present, falls back to conda, and stops with a clear error if neither exists.</span>

```bash
if command -v mamba >/dev/null 2>&1; then
  echo "mamba is already installed at $(command -v mamba)"
  exit 0
fi
```

## Lines 14-19

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Package-manager selection. This block checks which conda-style installer is available, prefers mamba when present, falls back to conda, and stops with a clear error if neither exists.</span>

```bash
if command -v conda >/dev/null 2>&1; then
  echo "Found conda at $(command -v conda). Installing mamba into the base environment..."
  conda install -y -n base -c conda-forge mamba
  echo "mamba installed successfully."
  exit 0
fi
```

## Lines 21-24

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
MAMBA_PREFIX="$HOME/mamba-bootstrap"
MICROMAMBA_BIN="$HOME/.local/bin/micromamba"
mkdir -p "$HOME/.local/bin"
mkdir -p "$MAMBA_PREFIX"
```

## Lines 26-31

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation.</span>

```bash
if ! command -v micromamba >/dev/null 2>&1; then
  echo "No conda found; installing micromamba into $MICROMAMBA_BIN..."
  curl -L https://micro.mamba.pm/api/micromamba/linux-64/latest -o /tmp/micromamba
  chmod +x /tmp/micromamba
  mv /tmp/micromamba "$MICROMAMBA_BIN"
fi
```

## Lines 33-34

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
echo "Bootstrapping mamba into $MAMBA_PREFIX..."
"$MICROMAMBA_BIN" install -y -p "$MAMBA_PREFIX" -c conda-forge mamba
```

## Line 36

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Workflow step. These related commands work together as one small unit in the script, preparing inputs, checking state, or running part of the analysis.</span>

```bash
ln -sf "$MAMBA_PREFIX/bin/mamba" "$HOME/.local/bin/mamba"
```

## Lines 38-43

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Package-manager selection. This block checks which conda-style installer is available, prefers mamba when present, falls back to conda, and stops with a clear error if neither exists.</span>

```bash
if command -v mamba >/dev/null 2>&1; then
  echo "mamba installed successfully at $(command -v mamba)"
else
  echo "ERROR: mamba installation completed but the binary could not be found in PATH." >&2
  exit 1
fi
```

