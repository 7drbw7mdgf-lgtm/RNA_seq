#!/bin/bash
#SBATCH --job-name=de_master
#SBATCH --output=/home/lshpk18/dual_rnaseq_timecourse_workflow/logs/master_%j.out
#SBATCH --error=/home/lshpk18/dual_rnaseq_timecourse_workflow/logs/master_%j.err
#SBATCH --cpus-per-task=16
#SBATCH --mem=96G
#SBATCH --time=48:00:00
#SBATCH --chdir=/home/lshpk18/dual_rnaseq_timecourse_workflow
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=lshpk18@lshtm.ac.uk
set -euo pipefail
bash /home/lshpk18/dual_rnaseq_timecourse_workflow/run_full_workflow.sh
