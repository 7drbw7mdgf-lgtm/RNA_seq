#!/bin/bash

# Alignment Cleanup Script
# Removes all alignment-generated files while preserving directory structure
# Total cleanup: ~292GB (204GB alignments + 56GB bam + 32GB star_index + logs + qc)

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ALIGNMENT_DIR="/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment"
DRY_RUN=false
VERBOSE=false

# Function to print help
print_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Cleanup script to remove alignment-generated files while preserving directory structure.

OPTIONS:
    -d, --dry-run       Show what would be deleted without actually deleting
    -v, --verbose       Show detailed output of all operations
    -h, --help          Show this help message

WHAT WILL BE REMOVED:
  - Root directory:
    • /home/lshpk18/T84 (~972MB)
    • /home/lshpk18/T84_annotation (~3.3GB)
    • /home/lshpk18/_STARtmp/

  - Alignment directory:
    • \$ALIGNMENT_DIR/alignments/* (~204GB)
    • \$ALIGNMENT_DIR/bam/* (~56GB)
    • \$ALIGNMENT_DIR/star_index/* (~32GB)
    • \$ALIGNMENT_DIR/logs/* (~180KB)
    • \$ALIGNMENT_DIR/qc/* (~584KB)

WHAT WILL BE KEPT:
  - All directory structures
  - Reference files (references/)
  - Workflow scripts (*.sh, *.sbatch)
  - README.md

EOF
}

# Function to log messages
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            print_help
            exit 1
            ;;
    esac
done

# Function to safely remove files
remove_files() {
    local pattern=$1
    local description=$2
    
    if [ "$VERBOSE" = true ]; then
        log "Processing: $description"
    fi
    
    # Count files
    local count=$(find "$pattern" -type f 2>/dev/null | wc -l)
    
    if [ "$count" -gt 0 ]; then
        if [ "$DRY_RUN" = true ]; then
            log "DRY RUN: Would remove $count files matching: $pattern"
            if [ "$VERBOSE" = true ]; then
                find "$pattern" -type f 2>/dev/null | head -5
                if [ "$count" -gt 5 ]; then
                    echo "  ... and $((count - 5)) more files"
                fi
            fi
        else
            log "Removing $count files: $description"
            find "$pattern" -type f -delete 2>/dev/null
        fi
    fi
}

# Function to safely remove directories if empty
remove_empty_dirs() {
    local pattern=$1
    local description=$2
    
    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would remove empty directories: $description"
    else
        log "Removing empty directories: $description"
        find "$pattern" -type d -empty -delete 2>/dev/null
    fi
}

# Main cleanup logic
main() {
    log "Starting alignment cleanup..."
    if [ "$DRY_RUN" = true ]; then
        log_warn "DRY RUN MODE - No files will be deleted"
    fi
    echo ""
    
    # Check if alignment directory exists
    if [ ! -d "$ALIGNMENT_DIR" ]; then
        log_error "Alignment directory not found: $ALIGNMENT_DIR"
        exit 1
    fi
    
    # 1. Clean alignments directory
    if [ -d "$ALIGNMENT_DIR/alignments" ]; then
        remove_files "$ALIGNMENT_DIR/alignments/*" "Alignment output files"
        remove_empty_dirs "$ALIGNMENT_DIR/alignments" "Empty alignment subdirectories"
    fi
    
    # 2. Clean BAM files
    if [ -d "$ALIGNMENT_DIR/bam" ]; then
        remove_files "$ALIGNMENT_DIR/bam/*" "BAM files"
        remove_empty_dirs "$ALIGNMENT_DIR/bam" "Empty BAM subdirectories"
    fi
    
    # 3. Clean STAR index
    if [ -d "$ALIGNMENT_DIR/star_index" ]; then
        remove_files "$ALIGNMENT_DIR/star_index/*" "STAR index files"
        remove_empty_dirs "$ALIGNMENT_DIR/star_index" "Empty STAR index subdirectories"
    fi
    
    # 4. Clean logs
    if [ -d "$ALIGNMENT_DIR/logs" ]; then
        remove_files "$ALIGNMENT_DIR/logs/*" "Log files"
        remove_empty_dirs "$ALIGNMENT_DIR/logs" "Empty log subdirectories"
    fi
    
    # 5. Clean QC files
    if [ -d "$ALIGNMENT_DIR/qc" ]; then
        remove_files "$ALIGNMENT_DIR/qc/*" "QC output files"
        remove_empty_dirs "$ALIGNMENT_DIR/qc" "Empty QC subdirectories"
    fi
    
    # 6. Clean counts directory (should be empty)
    if [ -d "$ALIGNMENT_DIR/counts" ]; then
        remove_files "$ALIGNMENT_DIR/counts/*" "Count files"
        remove_empty_dirs "$ALIGNMENT_DIR/counts" "Empty counts subdirectories"
    fi
    
    # 7. Clean root-level alignment files
    if [ -f "/home/lshpk18/T84" ]; then
        if [ "$DRY_RUN" = true ]; then
            log "DRY RUN: Would remove /home/lshpk18/T84 (~972MB)"
        else
            log "Removing /home/lshpk18/T84"
            rm -f /home/lshpk18/T84
        fi
    fi
    
    if [ -f "/home/lshpk18/T84_annotation" ]; then
        if [ "$DRY_RUN" = true ]; then
            log "DRY RUN: Would remove /home/lshpk18/T84_annotation (~3.3GB)"
        else
            log "Removing /home/lshpk18/T84_annotation"
            rm -f /home/lshpk18/T84_annotation
        fi
    fi
    
    if [ -d "/home/lshpk18/_STARtmp" ]; then
        if [ "$DRY_RUN" = true ]; then
            log "DRY RUN: Would remove /home/lshpk18/_STARtmp directory"
        else
            log "Removing /home/lshpk18/_STARtmp directory"
            rm -rf /home/lshpk18/_STARtmp
        fi
    fi
    
    echo ""
    log "Cleanup complete!"
    
    # Show remaining disk space
    if [ "$DRY_RUN" = false ]; then
        log "Directory structures preserved successfully."
        log "References and scripts remain intact."
    fi
}

# Run main function
main
