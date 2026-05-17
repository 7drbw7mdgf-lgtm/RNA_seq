#!/usr/bin/env python3
"""
BAM QC pipeline: integrity, alignment fidelity, duplication, coverage, insert sizes.
Outputs a TSV summary and per-sample JSON reports.
"""

import argparse
import json
import logging
import math
import os
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

try:
    import pysam
except ImportError:
    sys.exit("ERROR: pysam not installed. Run: conda install -c bioconda pysam")

logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] %(levelname)s %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger(__name__)

# ── Thresholds ────────────────────────────────────────────────────────────────
THRESHOLDS = {
    "mapped_pct":        (">=", 90.0),
    "properly_paired_pct": (">=", 85.0),
    "mapq30_pct":        (">=", 70.0),
    "dup_pct":           ("<",  15.0),
    "mean_depth":        (">=",  1.0),
    "breadth_10x_pct":   (">=", 50.0),
    "breadth_20x_pct":   (">=", 30.0),
    "breadth_30x_pct":   (">=", 10.0),
    "insert_mean":       (">=", 100.0),
}

MAPQ_SAMPLE_MAX = 500_000   # reads to sample for MAPQ calculation
INSERT_SAMPLE_MAX = 200_000  # read-pairs to sample for insert sizes


# ── Helpers ───────────────────────────────────────────────────────────────────

def run(cmd: list[str], check=True) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, check=check)


def flag(value, metric: str) -> str:
    if value is None:
        return "MISSING"
    op, threshold = THRESHOLDS.get(metric, (">=", 0))
    ops = {">=": lambda a, b: a >= b, "<": lambda a, b: a < b, "<=": lambda a, b: a <= b}
    return "PASS" if ops[op](value, threshold) else "FAIL"


def mean_std(values: list[float]) -> tuple[float, float]:
    n = len(values)
    if n == 0:
        return 0.0, 0.0
    m = sum(values) / n
    sd = math.sqrt(sum((x - m) ** 2 for x in values) / n)
    return m, sd


def median(values: list[float]) -> float:
    s = sorted(values)
    n = len(s)
    mid = n // 2
    return (s[mid - 1] + s[mid]) / 2 if n % 2 == 0 else s[mid]


# ── 1. File Integrity & Index Check ──────────────────────────────────────────

def check_integrity(bam: Path) -> dict:
    result = {"bam_exists": False, "bai_exists": False,
              "bai_newer": None, "quickcheck": None}

    result["bam_exists"] = bam.exists()
    bai = Path(str(bam) + ".bai")
    if not bai.exists():
        bai = bam.with_suffix(".bai")
    result["bai_exists"] = bai.exists()

    if result["bam_exists"] and result["bai_exists"]:
        result["bai_newer"] = bai.stat().st_mtime >= bam.stat().st_mtime

    if result["bam_exists"]:
        proc = run(["samtools", "quickcheck", str(bam)], check=False)
        result["quickcheck"] = "PASS" if proc.returncode == 0 else f"FAIL: {proc.stderr.strip()}"

    result["status"] = (
        "PASS"
        if result["bam_exists"] and result["bai_exists"]
           and result["bai_newer"] and result["quickcheck"] == "PASS"
        else "FAIL"
    )
    return result


# ── 2. Alignment & Mapping Fidelity ──────────────────────────────────────────

def parse_flagstat(bam: Path) -> dict:
    proc = run(["samtools", "flagstat", str(bam)])
    out = proc.stdout
    result = {}

    def grab(pattern):
        m = re.search(pattern, out)
        return int(m.group(1)) if m else None

    total        = grab(r"^(\d+) \+ \d+ in total")
    mapped       = grab(r"^(\d+) \+ \d+ mapped")
    paired_seq   = grab(r"^(\d+) \+ \d+ paired in sequencing")
    properly     = grab(r"^(\d+) \+ \d+ properly paired")
    duplicates   = grab(r"^(\d+) \+ \d+ duplicates")

    result["total_reads"]         = total
    result["mapped_reads"]        = mapped
    result["mapped_pct"]          = round(mapped / total * 100, 2) if total and mapped else None
    result["properly_paired"]     = properly
    result["properly_paired_pct"] = round(properly / paired_seq * 100, 2) if paired_seq and properly else None
    result["duplicate_reads"]     = duplicates
    result["dup_pct"]             = round(duplicates / total * 100, 2) if total and duplicates else None

    result["flags"] = {
        "mapped_pct":           flag(result["mapped_pct"],          "mapped_pct"),
        "properly_paired_pct":  flag(result["properly_paired_pct"], "properly_paired_pct"),
        "dup_pct":              flag(result["dup_pct"],             "dup_pct"),
    }
    return result


def calc_mapq(bam: Path) -> dict:
    total = high = 0
    with pysam.AlignmentFile(str(bam), "rb") as bam_fh:
        for read in bam_fh.fetch(until_eof=True):
            if read.is_unmapped or read.is_secondary or read.is_supplementary:
                continue
            total += 1
            if read.mapping_quality >= 30:
                high += 1
            if total >= MAPQ_SAMPLE_MAX:
                break
    mapq30_pct = round(high / total * 100, 2) if total else None
    return {
        "reads_sampled": total,
        "mapq30_count":  high,
        "mapq30_pct":    mapq30_pct,
        "flag":          flag(mapq30_pct, "mapq30_pct"),
    }


# ── 3. Coverage & Target Breadth ──────────────────────────────────────────────

def calc_coverage(bam: Path) -> dict:
    proc = run(["samtools", "coverage", str(bam)])
    lines = [l for l in proc.stdout.strip().split("\n") if not l.startswith("#")]

    depths, covered_bases, total_bases = [], 0, 0
    for line in lines:
        parts = line.split("\t")
        if len(parts) < 7:
            continue
        try:
            end_pos   = int(parts[2])
            numreads  = int(parts[3])
            covbases  = int(parts[4])
            meandepth = float(parts[6])
        except ValueError:
            continue
        total_bases   += end_pos
        covered_bases += covbases
        if meandepth > 0:
            depths.append((meandepth, end_pos))

    if not depths:
        return {"mean_depth": None, "median_depth": None,
                "breadth_pct": None, "flags": {}}

    # weighted mean depth
    total_len  = sum(l for _, l in depths)
    mean_depth = sum(d * l for d, l in depths) / total_len if total_len else 0

    # breadth at thresholds using samtools depth
    breadth = _breadth_at_thresholds(bam, total_bases)

    result = {
        "mean_depth":       round(mean_depth, 2),
        "breadth_pct":      round(covered_bases / total_bases * 100, 2) if total_bases else None,
        **breadth,
    }
    result["flags"] = {
        "mean_depth":     flag(result["mean_depth"],     "mean_depth"),
        "breadth_10x_pct": flag(result.get("breadth_10x_pct"), "breadth_10x_pct"),
        "breadth_20x_pct": flag(result.get("breadth_20x_pct"), "breadth_20x_pct"),
        "breadth_30x_pct": flag(result.get("breadth_30x_pct"), "breadth_30x_pct"),
    }
    return result


def _breadth_at_thresholds(bam: Path, total_bases: int) -> dict:
    if total_bases == 0:
        return {}
    counts = defaultdict(int)
    proc = run(["samtools", "depth", "-a", str(bam)])
    for line in proc.stdout.split("\n"):
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        try:
            depth = int(parts[2])
        except ValueError:
            continue
        if depth >= 10:
            counts[10] += 1
        if depth >= 20:
            counts[20] += 1
        if depth >= 30:
            counts[30] += 1
    return {
        "breadth_10x_pct": round(counts[10] / total_bases * 100, 2),
        "breadth_20x_pct": round(counts[20] / total_bases * 100, 2),
        "breadth_30x_pct": round(counts[30] / total_bases * 100, 2),
    }


# ── 4. Insert Size Distribution ───────────────────────────────────────────────

def calc_insert_sizes(bam: Path) -> dict:
    sizes = []
    with pysam.AlignmentFile(str(bam), "rb") as bam_fh:
        for read in bam_fh.fetch(until_eof=True):
            if (read.is_proper_pair and not read.is_unmapped
                    and not read.mate_is_unmapped and read.is_read1):
                tlen = abs(read.template_length)
                if 0 < tlen < 2000:
                    sizes.append(tlen)
            if len(sizes) >= INSERT_SAMPLE_MAX:
                break

    if not sizes:
        return {"insert_mean": None, "insert_std": None,
                "insert_median": None, "anomalies": ["no_data"], "flag": "MISSING"}

    m, sd = mean_std(sizes)
    med   = median(sizes)

    anomalies = []
    if m < 100:
        anomalies.append("severe_truncation")
    if sd > m * 0.8:
        anomalies.append("high_variance")

    # simple multi-modal detection: split into low/high halves
    low  = [s for s in sizes if s < med]
    high = [s for s in sizes if s >= med]
    if low and high:
        low_mean, _  = mean_std(low)
        high_mean, _ = mean_std(high)
        if high_mean - low_mean > 200:
            anomalies.append("multimodal_distribution")

    return {
        "insert_mean":   round(m, 2),
        "insert_std":    round(sd, 2),
        "insert_median": round(med, 2),
        "reads_sampled": len(sizes),
        "anomalies":     anomalies if anomalies else ["none"],
        "flag":          flag(m, "insert_mean"),
    }


# ── Main ──────────────────────────────────────────────────────────────────────

def run_qc(bam: Path, out_dir: Path) -> dict:
    log.info("Processing: %s", bam.name)

    report = {"sample": bam.stem, "bam": str(bam)}

    log.info("  [1/5] Integrity check")
    report["integrity"] = check_integrity(bam)

    if not report["integrity"]["bam_exists"]:
        log.error("  BAM missing — skipping remaining checks")
        return report

    log.info("  [2/5] Flagstat (mapping fidelity + duplication)")
    report["flagstat"] = parse_flagstat(bam)

    log.info("  [3/5] MAPQ >= 30 rate")
    report["mapq"] = calc_mapq(bam)

    log.info("  [4/5] Coverage & breadth")
    report["coverage"] = calc_coverage(bam)

    log.info("  [5/5] Insert size distribution")
    report["insert_sizes"] = calc_insert_sizes(bam)

    # Overall pass/fail
    all_flags = (
        list(report["flagstat"]["flags"].values())
        + [report["mapq"]["flag"]]
        + list(report["coverage"]["flags"].values())
        + [report["insert_sizes"]["flag"]]
        + [report["integrity"]["status"]]
    )
    report["overall"] = "PASS" if all(f == "PASS" for f in all_flags) else "FAIL"

    # Save per-sample JSON
    out_dir.mkdir(parents=True, exist_ok=True)
    json_path = out_dir / f"{bam.stem}_qc.json"
    json_path.write_text(json.dumps(report, indent=2))

    return report


def write_tsv(reports: list[dict], out_path: Path):
    cols = [
        "sample", "overall",
        "integrity_status", "quickcheck",
        "total_reads", "mapped_pct", "mapped_flag",
        "properly_paired_pct", "paired_flag",
        "dup_pct", "dup_flag",
        "mapq30_pct", "mapq_flag",
        "mean_depth", "breadth_10x_pct", "breadth_20x_pct", "breadth_30x_pct",
        "coverage_flag",
        "insert_mean", "insert_std", "insert_median", "insert_anomalies", "insert_flag",
    ]
    rows = []
    for r in reports:
        fs   = r.get("flagstat", {})
        cov  = r.get("coverage", {})
        ins  = r.get("insert_sizes", {})
        mapq = r.get("mapq", {})
        intg = r.get("integrity", {})
        rows.append([
            r.get("sample"),
            r.get("overall"),
            intg.get("status"),
            intg.get("quickcheck"),
            fs.get("total_reads"),
            fs.get("mapped_pct"),
            fs.get("flags", {}).get("mapped_pct"),
            fs.get("properly_paired_pct"),
            fs.get("flags", {}).get("properly_paired_pct"),
            fs.get("dup_pct"),
            fs.get("flags", {}).get("dup_pct"),
            mapq.get("mapq30_pct"),
            mapq.get("flag"),
            cov.get("mean_depth"),
            cov.get("breadth_10x_pct"),
            cov.get("breadth_20x_pct"),
            cov.get("breadth_30x_pct"),
            cov.get("flags", {}).get("mean_depth"),
            ins.get("insert_mean"),
            ins.get("insert_std"),
            ins.get("insert_median"),
            ";".join(ins.get("anomalies", [])),
            ins.get("flag"),
        ])

    with out_path.open("w") as fh:
        fh.write("\t".join(cols) + "\n")
        for row in rows:
            fh.write("\t".join("" if v is None else str(v) for v in row) + "\n")

    log.info("TSV summary written: %s", out_path)


def main():
    parser = argparse.ArgumentParser(description="BAM QC pipeline")
    parser.add_argument("bam_dir",  type=Path, help="Directory containing .bam files")
    parser.add_argument("--out-dir", type=Path, default=Path("bam_qc_results"),
                        help="Output directory for JSON reports and TSV summary")
    parser.add_argument("--pattern", default="*.bam",
                        help="Glob pattern for BAM files (default: *.bam)")
    args = parser.parse_args()

    bams = sorted(args.bam_dir.glob(args.pattern))
    if not bams:
        sys.exit(f"ERROR: No BAM files found in {args.bam_dir} matching '{args.pattern}'")

    log.info("Found %d BAM files", len(bams))
    reports = [run_qc(bam, args.out_dir) for bam in bams]

    tsv_path = args.out_dir / "qc_summary.tsv"
    write_tsv(reports, tsv_path)

    fails = [r["sample"] for r in reports if r.get("overall") == "FAIL"]
    log.info("Complete. %d/%d samples PASSED.", len(reports) - len(fails), len(reports))
    if fails:
        log.warning("FAILED samples: %s", ", ".join(fails))


if __name__ == "__main__":
    main()
