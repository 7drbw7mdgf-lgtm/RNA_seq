function explain(line, trimmed) {
  trimmed = line
  sub(/^[[:space:]]+/, "", trimmed)
  sub(/[[:space:]]+$/, "", trimmed)

  if (trimmed == "") return "Blank line used to separate logical blocks and make the script easier to read."
  if (trimmed ~ /^#!/) return "Shebang that tells the operating system which interpreter should run this script."
  if (trimmed ~ /^#SBATCH[[:space:]]+--job-name=/) return "Slurm directive that sets the job name shown in the scheduler."
  if (trimmed ~ /^#SBATCH[[:space:]]+--output=/) return "Slurm directive that chooses the file for standard output from the job."
  if (trimmed ~ /^#SBATCH[[:space:]]+--error=/) return "Slurm directive that chooses the file for error output from the job."
  if (trimmed ~ /^#SBATCH[[:space:]]+--mail-type=/) return "Slurm directive that chooses which job events trigger email notifications."
  if (trimmed ~ /^#SBATCH[[:space:]]+--mail-user=/) return "Slurm directive that sets the email address for job notifications."
  if (trimmed ~ /^#SBATCH[[:space:]]+--ntasks=/) return "Slurm directive that requests the number of tasks for this job."
  if (trimmed ~ /^#SBATCH[[:space:]]+--cpus-per-task=/) return "Slurm directive that requests CPU cores for the task."
  if (trimmed ~ /^#SBATCH[[:space:]]+--mem=/) return "Slurm directive that requests memory for the job."
  if (trimmed ~ /^#SBATCH[[:space:]]+--time=/) return "Slurm directive that sets the maximum runtime for the job."
  if (trimmed ~ /^#SBATCH[[:space:]]+--chdir=/) return "Slurm directive that sets the working directory before commands run."
  if (trimmed ~ /^#SBATCH/) return "Slurm scheduler option controlling how the job is submitted or run."
  if (trimmed ~ /^#/) return "Comment written for humans; it documents the purpose or usage of nearby code."
  if (trimmed ~ /^set -euo pipefail/) return "Enables strict shell behaviour: stop on errors, unset variables, and failed pipeline commands."
  if (trimmed ~ /^[A-Za-z_][A-Za-z0-9_]*=/) return "Sets a shell variable, often with a default value that can be overridden from the environment."
  if (trimmed ~ /^export /) return "Exports variables so child scripts and commands can read them from the environment."
  if (trimmed ~ /^mkdir / || trimmed ~ /^mkdir -p /) return "Creates a directory; -p means do nothing if it already exists and create parent directories as needed."
  if (trimmed ~ /^echo /) return "Prints a status message to standard output so the run is easier to follow."
  if (trimmed ~ /^printf /) return "Prints formatted text, usually for tables, logs, or safely quoted command previews."
  if (trimmed ~ /^cat << ?/) return "Starts a here-document used to print a multi-line block of text."
  if (trimmed ~ /^USAGE$/ || trimmed ~ /^EOF$/) return "Ends a here-document block that was started earlier."
  if (trimmed ~ /^[A-Za-z_][A-Za-z0-9_]*\(\)[[:space:]]*\{/) return "Defines a shell function so related commands can be reused by name."
  if (trimmed == "}") return "Closes the current shell function, conditional block, case block, or loop."
  if (trimmed ~ /^if /) return "Starts a conditional block that runs commands only when the test succeeds."
  if (trimmed ~ /^elif /) return "Adds another condition to an existing if block."
  if (trimmed == "else") return "Starts the fallback branch of a conditional block."
  if (trimmed == "fi") return "Ends an if/elif/else conditional block."
  if (trimmed ~ /^case /) return "Starts a case statement that chooses behaviour based on a value."
  if (trimmed ~ /^\*\)/ || trimmed ~ /^[A-Za-z0-9_|-]+\)/) return "Case-pattern branch that handles one or more matching option values."
  if (trimmed == ";;") return "Ends the current case-pattern branch."
  if (trimmed == "esac") return "Ends a case statement."
  if (trimmed ~ /^while /) return "Starts a loop that repeats while the condition remains true."
  if (trimmed ~ /^for /) return "Starts a loop over a list of values."
  if (trimmed == "do") return "Starts the command body of a loop."
  if (trimmed == "done") return "Ends a while or for loop."
  if (trimmed ~ /^shift/) return "Moves command-line arguments along after an option has been processed."
  if (trimmed ~ /^exit /) return "Stops the script and returns the specified exit status."
  if (trimmed ~ /^return /) return "Exits the current function and returns a status code to its caller."
  if (trimmed ~ /^command -v /) return "Checks whether a required command is available in PATH."
  if (trimmed ~ /^source /) return "Loads another shell script into the current shell, commonly used to activate conda."
  if (trimmed ~ /^module /) return "Interacts with the cluster module system to load software."
  if (trimmed ~ /^sbatch /) return "Submits a Slurm job to the scheduler."
  if (trimmed ~ /^squeue /) return "Queries the Slurm queue for running or pending jobs."
  if (trimmed ~ /^sacct /) return "Queries Slurm accounting information for completed or running jobs."
  if (trimmed ~ /^bash /) return "Runs another bash script as a child process."
  if (trimmed ~ /^env /) return "Runs a command with specified environment variables for that command."
  if (trimmed ~ /^awk /) return "Runs awk to parse text, calculate values, or write tabular output."
  if (trimmed ~ /^sed /) return "Runs sed to select or transform text."
  if (trimmed ~ /^find /) return "Searches the filesystem for matching files or directories."
  if (trimmed ~ /^sort/) return "Sorts text output into a stable order."
  if (trimmed ~ /^read /) return "Reads input into one or more shell variables."
  if (trimmed ~ /^mapfile /) return "Reads command output into a bash array."
  if (trimmed ~ /^local /) return "Creates a variable local to the current function."
  if (trimmed ~ /^shopt /) return "Changes a bash shell option for filename matching or other shell behaviour."
  if (trimmed ~ /^STAR / || trimmed ~ /"\$STAR_BIN"/) return "Runs STAR for genome indexing or read alignment."
  if (trimmed ~ /^samtools / || trimmed ~ /"\$SAMTOOLS_BIN"/) return "Runs samtools for BAM indexing or alignment QC metrics."
  if (trimmed ~ /^featureCounts / || trimmed ~ /"\$FEATURECOUNTS_BIN"/) return "Runs featureCounts to assign aligned reads to genomic features."
  if (trimmed ~ /^qualimap /) return "Runs Qualimap to generate BAM quality-control metrics."
  if (trimmed ~ /^infer_experiment.py /) return "Runs RSeQC strandedness inference on a BAM file."
  if (trimmed ~ /^inner_distance.py /) return "Runs RSeQC insert-size or inner-distance analysis."
  if (trimmed ~ /^read_distribution.py /) return "Runs RSeQC read-distribution analysis across annotation features."
  if (trimmed ~ /^mv /) return "Moves or renames a file, often from a temporary STAR output name to the final BAM path."
  if (trimmed ~ /^cp /) return "Copies a file from one location to another."
  if (trimmed ~ /^rm /) return "Removes files; check the target carefully before running."
  if (trimmed ~ /^chmod /) return "Changes file permissions, commonly to make a script executable."
  if (trimmed ~ /^tail / || trimmed ~ /^head /) return "Shows the beginning or end of a text file."
  if (trimmed ~ /^wc /) return "Counts lines, words, or bytes, commonly used here to count samples or files."
  if (trimmed ~ /^date/) return "Prints the current date/time for logging."
  if (trimmed ~ /^hostname/) return "Prints the compute node name for job logging."
  if (trimmed ~ /^\[\[/) return "Bash test expression used to check files, strings, numbers, or patterns."
  if (trimmed ~ /^\[/) return "Shell test expression used to check a condition."
  if (trimmed ~ /^".*"/) return "Runs the command stored in a quoted variable path with its arguments."
  if (trimmed ~ /^.*\|.*$/) return "Pipeline: sends output from one command into the next command."
  if (trimmed ~ /^.*>.*$/) return "Redirects command output to a file."
  if (trimmed ~ /^.*>>.*$/) return "Appends command output to a file."
  return "Shell command or expression that contributes to the workflow logic on this line."
}

function trim(text) {
  sub(/^[[:space:]]+/, "", text)
  sub(/[[:space:]]+$/, "", text)
  return text
}

function append_line(line) {
  if (block_n == 0) block_start = FNR
  block_n++
  block_lines[block_n] = line
}

function block_text(    i, text) {
  text = ""
  for (i = 1; i <= block_n; i++) {
    text = text block_lines[i] "\n"
  }
  return text
}

function first_code_line(    i, t) {
  for (i = 1; i <= block_n; i++) {
    t = trim(block_lines[i])
    if (t != "" && t !~ /^#/) return t
  }
  return trim(block_lines[1])
}

function block_summary(text, first, lower) {
  first = first_code_line()
  text = block_text()
  lower = tolower(text)

  if (first ~ /^#!/ || text ~ /set -euo pipefail/) {
    return "Script startup. This block selects bash as the interpreter and enables stricter error handling so failures, unset variables, and broken pipelines are caught early."
  }
  if (text ~ /#SBATCH/) {
    return "Slurm job configuration. These scheduler directives describe how the job should run, including its name, log files, runtime, CPU, memory, notification, or working-directory settings."
  }
  if (first ~ /^#/) {
    return "Human-facing documentation. These comments explain the purpose, assumptions, or usage of the nearby script before the executable logic begins."
  }
  if (text ~ /cat <<[A-Za-z'\''"]*EOF/ || text ~ /cat <<[A-Za-z'\''"]*USAGE/) {
    return "Multi-line message. This here-document prints a longer help or completion message without needing a separate echo command for every line."
  }
  if (text ~ /SCRIPT_DIR=.*BASH_SOURCE/ || text ~ /cd "\$SCRIPT_DIR"/) {
    return "Location setup. This resolves the directory containing the script and moves there so relative paths behave consistently no matter where the script was launched from."
  }
  if (text ~ /required_tools=/ || text ~ /command -v .*die/) {
    return "Tool availability check. This block lists required command-line programs and stops early with a clear error if any are missing from PATH."
  }
  if (text ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=/ || text ~ /^[[:space:]]*export / || text ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=\(/) {
    return "Configuration setup. These assignments define paths, environment names, options, or package lists that later commands reuse instead of hard-coding values repeatedly."
  }
  if (text ~ /command -v mamba/ || text ~ /command -v conda/ || text ~ /PKG_MANAGER=/) {
    return "Package-manager selection. This block checks which conda-style installer is available, prefers mamba when present, falls back to conda, and stops with a clear error if neither exists."
  }
  if (text ~ /conda create/ || text ~ /mamba create/ || text ~ /conda install/ || text ~ /mamba install/ || text ~ /\$PKG_MANAGER.*(create|install)/) {
    return "Environment installation. These commands create or update the requested conda environment and install the packages needed by this part of the workflow."
  }
  if (text ~ /source .*activate/ || text ~ /conda activate/) {
    return "Environment activation. This loads the chosen conda environment into the current shell so the tools installed there are available on PATH."
  }
  if (first ~ /^usage\(\)/) {
    return "Usage/help function. This helper prints the accepted command-line options and environment overrides so users can quickly see how to run the script."
  }
  if (first ~ /^die\(\)/) {
    return "Error helper. This small function prints a clear error message to standard error and exits, keeping failure handling consistent throughout the script."
  }
  if (first ~ /^warn\(\)/) {
    return "Warning helper. This function reports non-fatal problems to standard error while allowing the workflow to continue when that is acceptable."
  }
  if (first ~ /^make_gene_bed_from_gtf\(\)/) {
    return "Host annotation conversion. This function converts transcript or exon records from a GTF file into BED format for downstream read-distribution and QC tools."
  }
  if (first ~ /^make_gene_bed_from_gff3\(\)/) {
    return "Bacterial annotation conversion. This function extracts gene-like features from a GFF3 file and writes them in BED format for downstream QC."
  }
  if (first ~ /^make_rrna_bed_from_gtf\(\)/ || first ~ /^make_rrna_bed_from_gff3\(\)/) {
    return "rRNA annotation conversion. This function builds a BED file containing ribosomal RNA features so the workflow can estimate rRNA-associated reads."
  }
  if (first ~ /^[A-Za-z_][A-Za-z0-9_]*\(\)[[:space:]]*\{/) {
    return "Reusable function. This block defines a named helper so related checks, messages, or workflow steps can be called consistently elsewhere in the script."
  }
  if (first ~ /^while[[:space:]].*\[\[ \$# -gt 0 \]\]/ || text ~ /case "\$1" in/) {
    return "Command-line option parsing. This loop reads user-supplied arguments, stores option values, handles help requests, and rejects unknown flags before the main workflow runs."
  }
  if (first ~ /^case[[:space:]]/) {
    return "Choice handling. This case block selects behaviour from a small set of valid values, such as deciding which target, step, or mode the script should run."
  }
  if (first ~ /^if[[:space:]]/ || first ~ /^elif[[:space:]]/ || text ~ /^[[:space:]]*else$/) {
    return "Conditional logic. This block checks the current state, such as available files, commands, or user options, and runs the appropriate branch for that situation."
  }
  if (first ~ /^(for|while)[[:space:]]/) {
    return "Repeated work. This loop applies the same operation to each item in a list, such as samples, files, targets, or package names."
  }
  if (text ~ /STAR / || text ~ /"\$STAR_BIN"/) {
    return "STAR alignment step. This block runs STAR-related commands to build indexes or align reads against the configured reference."
  }
  if (text ~ /samtools / || text ~ /"\$SAMTOOLS_BIN"/) {
    return "BAM processing and QC. These commands use samtools to index, inspect, or summarize alignment files for downstream checks."
  }
  if (text ~ /featureCounts / || text ~ /"\$FEATURECOUNTS_BIN"/) {
    return "Read counting. This block assigns aligned reads to annotated genomic features so expression-count tables can be produced."
  }
  if (text ~ /qualimap / || text ~ /infer_experiment.py / || text ~ /inner_distance.py / || text ~ /read_distribution.py /) {
    return "Post-alignment quality control. These commands run QC tools that inspect BAM quality, strandedness, insert-size behaviour, or read distribution across genomic features."
  }
  if (text ~ /mkdir / || text ~ /mkdir -p /) {
    return "Output preparation. This creates the directories needed by later commands, using `-p` where appropriate so reruns do not fail if folders already exist."
  }
  if (text ~ /echo / || text ~ /printf /) {
    return "User feedback. These messages make the run easier to follow by reporting what the script is about to do or what it has just completed."
  }
  if (text ~ /sbatch /) {
    return "Job submission. This block sends one or more workflow jobs to the Slurm scheduler with the configured arguments."
  }
  if (text ~ /find / || text ~ /sort/ || text ~ /awk / || text ~ /sed /) {
    return "Text and file discovery. These commands locate files or transform text into the structured lists used by later workflow steps."
  }
  return "Workflow step. These related commands work together as one small unit in the script, preparing inputs, checking state, or running part of the analysis."
}

function print_block(    i, end_line) {
  if (block_n == 0) return
  end_line = block_start + block_n - 1
  if (block_start == end_line) {
    printf "## Line %d\n\n", block_start
  } else {
    printf "## Lines %d-%d\n\n", block_start, end_line
  }
  printf "> <span style=\"color: #00bcd4;\"><strong>Annotation:</strong> %s</span>\n\n", block_summary()
  print "```bash"
  for (i = 1; i <= block_n; i++) {
    print block_lines[i]
    delete block_lines[i]
  }
  print "```"
  print ""
  block_n = 0
}

function structural_delta(line, t, delta) {
  t = trim(line)
  delta = 0

  if (t ~ /^(fi|esac|done)$/ || t == "}") delta--
  if (t ~ /^[A-Za-z_][A-Za-z0-9_]*\(\)[[:space:]]*\{/) delta++
  else if (t ~ /^if[[:space:]]/ && t !~ /^if[[:space:]]*\(/) delta++
  else if (t ~ /^case[[:space:]]/) delta++
  else if (t ~ /^while[[:space:]]/ && t !~ /^while[[:space:]]*\(/) delta++
  else if (t ~ /^for[[:space:]]/ && t !~ /^for[[:space:]]*\(/) delta++

  return delta
}

BEGIN {
  print "# Annotated Script"
  print ""
  print "**Original file:** `" original "`"
  print ""
  print "Related lines are grouped into annotated blocks so each explanation covers a complete piece of workflow logic."
  print ""
}
{
  if (trim($0) == "" && block_depth == 0) {
    print_block()
    next
  }

  append_line($0)
  block_depth += structural_delta($0)
  if (block_depth < 0) block_depth = 0
}
END {
  print_block()
}
