# Annotated Script

**Original file:** `Analysis/fastqc_results/install_visualisation.sh`

Related lines are grouped into annotated blocks so each explanation covers a complete piece of workflow logic.

## Lines 1-2

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Script startup. This block selects bash as the interpreter and enables stricter error handling so failures, unset variables, and broken pipelines are caught early.</span>

```bash
#!/usr/bin/env bash
set -euo pipefail
```

## Line 4

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Workflow step. These related commands work together as one small unit in the script, preparing inputs, checking state, or running part of the analysis.</span>

```bash
cd "$(dirname "$0")"
```

## Lines 6-7

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
VIS_DIR="Visualisation"
PKG_DIR="Package installation"
```

## Lines 9-10

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Output preparation. This creates the directories needed by later commands, using `-p` where appropriate so reruns do not fail if folders already exist.</span>

```bash
mkdir -p "$VIS_DIR"
mkdir -p "$PKG_DIR"
```

## Lines 12-13

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
echo "Creating virtual environment in $VIS_DIR/venv..."
python -m venv "$VIS_DIR/venv" > "$PKG_DIR/venv_creation.log" 2>&1
```

## Lines 15-18

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Environment activation. This loads the chosen conda environment into the current shell so the tools installed there are available on PATH.</span>

```bash
echo "Activating virtual environment and installing packages..."
source "$VIS_DIR/venv/bin/activate"
pip install --upgrade pip > "$PKG_DIR/pip_upgrade.log" 2>&1
pip install plotly matplotlib seaborn pandas numpy jupyter > "$PKG_DIR/package_install.log" 2>&1
```

## Lines 20-22

> <span style="color: #00bcd4;"><strong>Annotation:</strong> User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed.</span>

```bash
echo "Installation complete. Virtual environment created in $VIS_DIR/venv"
echo "Packages installed: plotly, matplotlib, seaborn, pandas, numpy, jupyter"
echo "Installation outputs saved in $PKG_DIR/"
```

