#!/bin/bash
#SBATCH --job-name=emapper_cje
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/KEGG_bacteria/logs/emapper_%j.log
#SBATCH --error=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/KEGG_bacteria/logs/emapper_%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=lshpk18@lshtm.ac.uk
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --time=04:00:00
#SBATCH --partition=normal

set -euo pipefail

SCRIPT_DIR="/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/KEGG_bacteria"
GFF3="/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/references/AL111168.1.gff3"
GENOME="/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/references/AL111168.1.fasta"
DATA_DIR="${SCRIPT_DIR}/eggnog_data"
OUT_DIR="${SCRIPT_DIR}/emapper_output"
PROTEIN_FA="${SCRIPT_DIR}/cje_proteins.faa"
ENV_NAME="emapper"

mkdir -p "${OUT_DIR}" "${SCRIPT_DIR}/logs"

echo "=============================================="
echo "eggNOG-mapper — C. jejuni NCTC 11168"
echo "=============================================="
echo "Job ID  : ${SLURM_JOB_ID:-manual}"
echo "Node    : $(hostname)"
echo "CPUs    : ${SLURM_CPUS_PER_TASK:-16}"
echo "Start   : $(date)"
echo ""

source /home/lshpk18/miniconda3/bin/activate "${ENV_NAME}"

# ---- Step 1: Extract protein sequences from GFF3 + genome FASTA -----------
# Builds a FASTA with >locus_tag headers for direct mapping back to DESeq2

echo "[STEP 1] Extracting protein sequences from GFF3..."

python3 - <<'PYEOF'
import re, sys
from pathlib import Path

gff3_file   = "/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/references/AL111168.1.gff3"
genome_file = "/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/references/AL111168.1.fasta"
out_faa     = "/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/KEGG_bacteria/cje_proteins.faa"

CODON_TABLE = {
    'TTT':'F','TTC':'F','TTA':'L','TTG':'L','CTT':'L','CTC':'L','CTA':'L','CTG':'L',
    'ATT':'I','ATC':'I','ATA':'I','ATG':'M','GTT':'V','GTC':'V','GTA':'V','GTG':'V',
    'TCT':'S','TCC':'S','TCA':'S','TCG':'S','CCT':'P','CCC':'P','CCA':'P','CCG':'P',
    'ACT':'T','ACC':'T','ACA':'T','ACG':'T','GCT':'A','GCC':'A','GCA':'A','GCG':'A',
    'TAT':'Y','TAC':'Y','TAA':'*','TAG':'*','CAT':'H','CAC':'H','CAA':'Q','CAG':'Q',
    'CAT':'H','CAC':'H','CAA':'Q','CAG':'Q','AAT':'N','AAC':'N','AAA':'K','AAG':'K',
    'GAT':'D','GAC':'D','GAA':'E','GAG':'E','TGT':'C','TGC':'C','TGA':'*','TGG':'W',
    'CGT':'R','CGC':'R','CGA':'R','CGG':'R','AGT':'S','AGC':'S','AGA':'R','AGG':'R',
    'GGT':'G','GGC':'G','GGA':'G','GGG':'G',
}

def revcomp(seq):
    comp = str.maketrans('ATCGatcg','TAGCtagc')
    return seq.translate(comp)[::-1]

def translate(seq):
    seq = seq.upper().replace('\n','')
    prot = []
    for i in range(0, len(seq)-2, 3):
        codon = seq[i:i+3]
        aa = CODON_TABLE.get(codon, 'X')
        if aa == '*':
            break
        prot.append(aa)
    return ''.join(prot)

# Load genome
print("  Loading genome...", flush=True)
genome = {}
current = None
with open(genome_file) as f:
    for line in f:
        line = line.rstrip()
        if line.startswith('>'):
            current = line[1:].split()[0]
            genome[current] = []
        elif current:
            genome[current].append(line)
genome = {k: ''.join(v) for k, v in genome.items()}
print(f"  Genome sequences loaded: {list(genome.keys())}", flush=True)

# Parse GFF3 CDS entries: collect all CDS segments per gene
print("  Parsing GFF3 CDS features...", flush=True)
gene_cds = {}   # locus_tag -> list of (seqname, start, end, strand, phase)
with open(gff3_file) as f:
    for line in f:
        if line.startswith('#') or '\tCDS\t' not in line:
            continue
        parts = line.rstrip().split('\t')
        if len(parts) < 9:
            continue
        seqname, _, _, start, end, _, strand, phase, attrs = parts
        start, end = int(start)-1, int(end)  # 0-based
        lt_m = re.search(r'locus_tag=([^;]+)', attrs)
        if not lt_m:
            continue
        lt = lt_m.group(1)
        if lt not in gene_cds:
            gene_cds[lt] = []
        gene_cds[lt].append((seqname, start, end, strand, int(phase) if phase != '.' else 0))

print(f"  CDS entries: {len(gene_cds)} locus tags", flush=True)

# Translate each gene
written = 0
with open(out_faa, 'w') as out:
    for lt, segs in sorted(gene_cds.items()):
        seqname = segs[0][0]
        if seqname not in genome:
            continue
        strand = segs[0][3]
        # Sort by start (forward) or reverse by end (reverse)
        segs_sorted = sorted(segs, key=lambda x: x[1], reverse=(strand == '-'))
        cds_seq = ''
        for (sn, s, e, st, ph) in segs_sorted:
            seg = genome[sn][s:e]
            cds_seq += seg
        if strand == '-':
            cds_seq = revcomp(cds_seq)
        prot = translate(cds_seq)
        if len(prot) < 10:
            continue
        out.write(f'>{lt}\n')
        for i in range(0, len(prot), 60):
            out.write(prot[i:i+60] + '\n')
        written += 1

print(f"  Proteins written: {written}", flush=True)
PYEOF

echo "[OK] Protein FASTA: ${PROTEIN_FA}"
echo "  $(grep -c '^>' "${PROTEIN_FA}") sequences"

# ---- Step 2: Run eggNOG-mapper -------------------------------------------
echo ""
echo "[STEP 2] Running eggNOG-mapper 2.1.12..."

emapper.py \
  --itype proteins \
  -i "${PROTEIN_FA}" \
  -o cje_emapper \
  --output_dir "${OUT_DIR}" \
  --data_dir "${DATA_DIR}" \
  --override \
  --cpu "${SLURM_CPUS_PER_TASK:-16}" \
  -m diamond \
  --sensmode sensitive \
  --tax_scope Bacteria \
  --go_evidence non-electronic \
  --target_orthologs all \
  --seed_ortholog_evalue 0.001 \
  --seed_ortholog_score 60

echo ""
echo "[OK] eggNOG-mapper complete."
echo "  Output: ${OUT_DIR}/cje_emapper.emapper.annotations"

echo ""
echo "=============================================="
echo "Complete : $(date)"
echo "Next     : sbatch cog_ora_bacteria.sbatch"
echo "=============================================="
