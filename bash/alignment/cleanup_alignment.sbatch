#!/bin/bash

#SBATCH --job-name=cleanup_alignment
#SBATCH --output=/home/lshpk18/cleanup_alignment_%j.log
#SBATCH --error=/home/lshpk18/cleanup_alignment_%j.err
#SBATCH --partition=standard
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=24:00:00
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=lshpk18@user.local

# Alignment Cleanup SLURM Job Script
# Submits the alignment cleanup script to run over the weekend
# Usage: sbatch cleanup_alignment.sbatch

set -e  # Exit on error

echo "======================================"
echo "Alignment Cleanup Job Started"
echo "======================================"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $(hostname)"
echo "Start time: $(date)"
echo ""

# Run the cleanup script with verbose output
/home/lshpk18/cleanup_alignment.sh --verbose

echo ""
echo "======================================"
echo "Alignment Cleanup Job Completed"
echo "======================================"
echo "End time: $(date)"
echo ""

# Print final disk usage
echo "Disk usage after cleanup:"
du -sh /home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/ 2>/dev/null || echo "Directory removed"
