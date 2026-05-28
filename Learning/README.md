# Learning Folder

This folder contains annotated duplicate copies of the bash and Slurm workflow scripts from:

```text
/home/lshpk18/OzanGundogdu_SOUK011275
```

The original scripts were not changed.

## Contents

- `script_manifest.txt` lists the original script paths that were copied.
- `annotate_bash.awk` is the helper used to generate the annotated copies.
- `Analysis/.../*.md` files mirror the original project paths and contain grouped explanations with bash code blocks.

## How To Read The Annotated Files

Related lines are shown as a Markdown section like:

````markdown
## Lines 10-11

> <span style="color: #00bcd4;"><strong>Annotation:</strong> Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly.</span>

```bash
ENV_NAME="rna-seq"
PKGS=(fastqc multiqc)
```
````

The annotated files are for learning and review. Use the original scripts in the project directory when submitting jobs or running the workflow.
