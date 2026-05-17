#!/bin/bash
#SBATCH --job-name=cog_api_cje
#SBATCH --output=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/KEGG_bacteria/logs/cog_api_%j.log
#SBATCH --error=/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/KEGG_bacteria/logs/cog_api_%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=lshpk18@lshtm.ac.uk
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=03:00:00
#SBATCH --partition=normal

set -euo pipefail

SCRIPT_DIR="/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/KEGG_bacteria"
GFF3="/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/references/AL111168.1.gff3"
OUT_DIR="${SCRIPT_DIR}/emapper_output"
OUT_FILE="${OUT_DIR}/cje_emapper.emapper.annotations"
ENV_NAME="emapper"

mkdir -p "${OUT_DIR}" "${SCRIPT_DIR}/logs"

echo "=============================================="
echo "eggNOG COG annotation via API — C. jejuni NCTC 11168"
echo "API: http://eggnogapi5.embl.de/nog_data"
echo "=============================================="
echo "Job ID  : ${SLURM_JOB_ID:-manual}"
echo "Node    : $(hostname)"
echo "Start   : $(date)"
echo ""

source /home/lshpk18/miniconda3/bin/activate "${ENV_NAME}"

python3 - <<'PYEOF'
"""
Query eggNOG5 nog_data API to get COG_category for each C. jejuni NCTC 11168
locus tag.

API: http://eggnogapi5.embl.de/nog_data/[dataformat]/[attributes]/[nogname]

Strategy:
  1. Parse GFF3 to build locus_tag -> NCBI protein ID mapping
  2. Construct eggNOG member ID: taxid.protein_id (e.g. 192222.CAL34182)
  3. Query nog_data/json/COG_cat/{member_id} for each protein
  4. Write emapper-compatible TSV for cog_ora_bacteria.R
"""

import re, sys, time, json, subprocess
from urllib.parse import quote

GFF3_FILE = "/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Alignment/references/AL111168.1.gff3"
OUT_FILE  = "/home/lshpk18/OzanGundogdu_SOUK011275/Analysis/Anton_downstream_mapping/KEGG_bacteria/emapper_output/cje_emapper.emapper.annotations"
TAX_ID    = "192222"
API_BASE  = "http://eggnogapi5.embl.de"
DELAY     = 0.2    # seconds between requests
TIMEOUT   = 15     # curl timeout in seconds

# ── 1. Parse GFF3: locus_tag -> NCBI protein ID (strip version suffix) ────
print("Parsing GFF3 for locus_tag -> protein_id mapping...", flush=True)
lt2prot = {}
with open(GFF3_FILE) as f:
    for line in f:
        if line.startswith('#') or '\tCDS\t' not in line:
            continue
        parts = line.rstrip().split('\t')
        if len(parts) < 9:
            continue
        attrs = parts[8]
        lt_m   = re.search(r'locus_tag=([^;]+)', attrs)
        prot_m = re.search(r'NCBI_GP:([^,;]+)', attrs)
        if lt_m and prot_m:
            lt  = lt_m.group(1)
            pid = prot_m.group(1).split('.')[0]   # strip .1 version
            lt2prot.setdefault(lt, pid)

print(f"  {len(lt2prot)} locus_tag -> protein_id pairs", flush=True)

# ── 2. curl-based GET (system curl handles TCP timeouts reliably) ──────────
def curl_get(url):
    try:
        result = subprocess.run(
            ["curl", "-sf", "--max-time", str(TIMEOUT),
             "-H", "User-Agent: CjeAnnotator/1.0",
             url],
            capture_output=True, text=True, timeout=TIMEOUT + 5
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
        return None
    except Exception:
        return None

# ── 3. Query nog_data API for each protein ────────────────────────────────
# Endpoint: /nog_data/json/COG_cat/{taxid.protein_id}
print(f"Querying {API_BASE}/nog_data/json/COG_cat/{{member_id}} ...", flush=True)

results = {}   # locus_tag -> COG_category string
locus_tags = sorted(lt2prot.keys())
n = len(locus_tags)

for i, lt in enumerate(locus_tags, 1):
    pid       = lt2prot[lt]
    member_id = f"{TAX_ID}.{pid}"
    url       = f"{API_BASE}/nog_data/json/COG_cat/{quote(member_id)}"

    if i % 100 == 0 or i == 1:
        print(f"  [{i}/{n}] {member_id}", flush=True)

    raw = curl_get(url)
    cog_cat = "-"
    if raw:
        try:
            data = json.loads(raw)
            # Response may be a string directly, or a dict with 'COG_cat'
            if isinstance(data, str) and data:
                cog_cat = data
            elif isinstance(data, dict):
                cog_cat = data.get('COG_cat') or data.get('cog_cat') or "-"
            elif isinstance(data, list) and data:
                # Some endpoints return list of category letters
                cog_cat = ''.join(str(x) for x in data if x)
        except (json.JSONDecodeError, TypeError):
            # Plain text response — take as-is if looks like COG letters
            stripped = raw.strip().strip('"')
            if stripped and all(c.isalpha() or c == '-' for c in stripped):
                cog_cat = stripped

    results[lt] = cog_cat if cog_cat else "-"
    time.sleep(DELAY)

# ── 4. Write emapper-compatible TSV ───────────────────────────────────────
HEADER_COLS = [
    "#query", "seed_ortholog", "evalue", "score",
    "eggNOG_OGs", "max_annot_lvl", "COG_category",
    "Description", "Preferred_name", "GOs",
    "EC", "KEGG_ko", "KEGG_Pathway", "KEGG_Module",
    "KEGG_Reaction", "KEGG_rclass", "BRITE", "KEGG_TC",
    "CAZy", "BiGG_Reaction", "PFAMs"
]

n_with_cog = sum(1 for v in results.values() if v not in ('-', '', None))
print(f"\nAnnotation complete:", flush=True)
print(f"  Total queried    : {len(results)}", flush=True)
print(f"  With COG_cat     : {n_with_cog}", flush=True)

with open(OUT_FILE, 'w') as out:
    out.write("## Generated by eggNOG5 nog_data API query\n")
    out.write("## eggNOG-mapper 2.1.12 compatible format\n")
    out.write("## Organism: Campylobacter jejuni NCTC 11168 (taxid: 192222)\n")
    out.write('\t'.join(HEADER_COLS) + '\n')
    for lt in sorted(results.keys()):
        cog = results[lt] or "-"
        row = [lt, '-', '-', '-', '-', 'Bacteria', cog,
               '-', '-', '-', '-', '-', '-', '-',
               '-', '-', '-', '-', '-', '-', '-']
        out.write('\t'.join(row) + '\n')

print(f"\nOutput: {OUT_FILE}", flush=True)

# COG distribution summary
from collections import Counter
cog_letters = [c for v in results.values() if v and v != '-' for c in list(v)]
cnt = Counter(cog_letters)
print("\nCOG category distribution:", flush=True)
for cat, n in sorted(cnt.items()):
    print(f"  {cat}: {n}", flush=True)
PYEOF

echo ""
echo "[OK] COG API query complete."
echo "  Output: ${OUT_FILE}"
echo "  Annotated: $(grep -v '^#' "${OUT_FILE}" | awk -F'\t' '$7 != "-"' | wc -l) genes with COG_cat"
echo ""
echo "=============================================="
echo "Complete : $(date)"
echo "Next     : sbatch cog_ora_bacteria.sbatch"
echo "=============================================="
