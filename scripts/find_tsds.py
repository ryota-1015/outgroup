"""
Purpose:      Detect Target Site Duplications (TSDs) flanking TE insertions
              identified by extract_gaps.py, using the 9-col TSV output.

Usage:        python3 find_tsds.py <tsv> <pri_fasta> <sec_fasta> <abs_fasta> <out_prefix>

Arguments:
  tsv         9-col TSV produced by extract_gaps.py (pattern_*_100bp.tsv)
  pri_fasta   Primary carrier genome FASTA (indexed with samtools faidx)
  sec_fasta   Secondary carrier genome FASTA (or '.' to skip)
  abs_fasta   Absent-species genome FASTA (or '.' to skip empty-site check)
  out_prefix  Output file prefix

TSD biology:
  After retrotransposon integration the structure is:
    genome: ...flank...[TSD][TE body][TSD]...flank...
  The empty site in the outgroup species has only one TSD copy.

  The MAF alignment places the gap boundaries at or near the TSD boundaries.
  We do not know exactly which side of each boundary the TSD falls on — it
  depends on the aligner. We therefore search four combinations of the left
  and right boundary windows (internal and external) to find a matching pair.

TSD thresholds (tuned for AMF fungi dominated by Gypsy LTR retrotransposons):
  N=4-6  : exact match only                      → HIGH (N>=6) / MED (N=4-5)
  N=7-9  : <=1 mismatch                          → MED
  N=10-20: <=2 mismatches                        → LOW (included, flagged)
  Minimum score (N - mismatches) >= 4 required.

Classification per candidate:
  CONFIRMED  : TSD in primary AND secondary AND single-copy TSD in absent species
  PROBABLE   : TSD in primary AND secondary
  CANDIDATE  : TSD in primary only
  UNCONFIRMED: no TSD found
"""

import sys
import os
import subprocess


FLANK_W   = 25   # bp extracted on each side of the boundary (for internal+external search)
ABS_W     = 25   # bp each side of absent-species insertion point
MIN_SCORE = 4    # minimum (N - mismatches) to report a TSD


def usage():
    print(__doc__, file=sys.stderr)
    sys.exit(1)


# ---------------------------------------------------------------------------
# FASTA extraction via samtools faidx
# ---------------------------------------------------------------------------

def faidx(fasta, chrom, start, end):
    """Return uppercase sequence for chrom:start-end (0-based, half-open).
    Returns empty string on any error."""
    if fasta == "." or not os.path.exists(fasta):
        return ""
    if start < 0:
        start = 0
    if end <= start:
        return ""
    region = f"{chrom}:{start+1}-{end}"   # samtools 1-based closed
    try:
        result = subprocess.run(
            ["samtools", "faidx", fasta, region],
            capture_output=True, text=True, check=True
        )
        lines = [l for l in result.stdout.splitlines() if not l.startswith(">")]
        return "".join(lines).upper()
    except subprocess.CalledProcessError:
        return ""


# ---------------------------------------------------------------------------
# TSD search
# ---------------------------------------------------------------------------

def _allowed_mm(n):
    if n <= 6:
        return 0
    if n <= 9:
        return 1
    return 2


def _score_pair(a, b):
    """Return (score, mismatches) for two equal-length strings, or None if below threshold."""
    if len(a) != len(b) or len(a) == 0:
        return None
    n  = len(a)
    mm = sum(x != y for x, y in zip(a, b))
    if mm > _allowed_mm(n):
        return None
    score = n - mm
    if score < MIN_SCORE:
        return None
    return score, mm


def _confidence(n, mm):
    if n >= 6 and mm == 0:
        return "HIGH"
    if (4 <= n <= 5 and mm == 0) or (n >= 8 and mm <= 1):
        return "MED"
    return "LOW"


def search_tsd(ins_start, ins_end, left_flank, right_flank):
    """Search for a TSD using all four boundary combinations.

    The TSD is a direct repeat at the edges of the insertion.  Depending on
    where the aligner placed the gap boundary, the TSD may appear:
      (A) inside the insertion at both ends  → compare ins_start[:N] vs ins_end[-N:]
      (B) outside the insertion at both ends → compare left_flank[-N:] vs right_flank[:N]
      (C) inside left, outside right         → compare ins_start[:N] vs right_flank[:N]
      (D) outside left, inside right         → compare left_flank[-N:] vs ins_end[-N:]

    Returns the best TSD dict found across all four combinations, or None.
    """
    best = None

    for n in range(4, 21):
        candidates = []

        if len(ins_start) >= n and len(ins_end) >= n:
            candidates.append((ins_start[:n], ins_end[-n:], "internal"))        # A

        if len(left_flank) >= n and len(right_flank) >= n:
            candidates.append((left_flank[-n:], right_flank[:n], "external"))  # B

        if len(ins_start) >= n and len(right_flank) >= n:
            candidates.append((ins_start[:n], right_flank[:n], "mixed_L"))     # C

        if len(left_flank) >= n and len(ins_end) >= n:
            candidates.append((left_flank[-n:], ins_end[-n:], "mixed_R"))      # D

        for a, b, src in candidates:
            res = _score_pair(a, b)
            if res is None:
                continue
            score, mm = res
            if best is None or score > best["score"]:
                best = {
                    "seq":        a,
                    "length":     n,
                    "mismatches": mm,
                    "score":      score,
                    "confidence": _confidence(n, mm),
                    "source":     src,
                }

    return best


def tsd_in_string(tsd_seq, window, max_mm=1):
    """Return True if tsd_seq appears in window with <= max_mm mismatches."""
    n = len(tsd_seq)
    for i in range(len(window) - n + 1):
        if sum(a != b for a, b in zip(tsd_seq, window[i:i+n])) <= max_mm:
            return True
    return False


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    if len(sys.argv) != 6:
        usage()

    tsv_path, pri_fasta, sec_fasta, abs_fasta, out_prefix = sys.argv[1:]

    out_tsv = out_prefix + "_tsd.tsv"
    out_bed = out_prefix + "_confirmed.bed"

    counts = {"CONFIRMED": 0, "PROBABLE": 0, "CANDIDATE": 0, "UNCONFIRMED": 0}

    with open(tsv_path) as fh_in, \
         open(out_tsv, "w") as fh_tsv, \
         open(out_bed, "w") as fh_bed:

        header = fh_in.readline().rstrip()
        fh_tsv.write(header + "\ttsd_seq\ttsd_len\ttsd_mm\ttsd_conf\ttsd_src"
                               "\tsec_tsd_match\tc_verified\tclassification\n")

        for line in fh_in:
            row = line.rstrip().split("\t")
            if len(row) < 9:
                continue

            pri_chrom = row[0]
            pri_start = int(row[1])
            pri_end   = int(row[2])
            pattern   = row[3]
            sec_chrom = row[4]
            sec_start = row[5]
            sec_end   = row[6]
            abs_chrom = row[7]
            abs_pos_s = row[8]

            ins_len = pri_end - pri_start

            # --- Sequences around the primary insertion ---
            ins_5  = faidx(pri_fasta, pri_chrom, pri_start,          pri_start + FLANK_W)
            ins_3  = faidx(pri_fasta, pri_chrom, pri_end   - FLANK_W, pri_end)
            l_flnk = faidx(pri_fasta, pri_chrom, pri_start - FLANK_W, pri_start)
            r_flnk = faidx(pri_fasta, pri_chrom, pri_end,             pri_end   + FLANK_W)

            # For very short insertions ins_5 and ins_3 overlap — trim
            if ins_len < 2 * FLANK_W:
                half = ins_len // 2
                ins_5 = ins_5[:half]
                ins_3 = ins_3[-half:] if half else ""

            tsd_pri = search_tsd(ins_5, ins_3, l_flnk, r_flnk)

            # --- Secondary species TSD ---
            sec_tsd_match = False
            if tsd_pri and sec_chrom != "." and sec_start not in (".", ""):
                s_s = int(sec_start)
                s_e = int(sec_end)
                s_ins_len = s_e - s_s
                s_ins_5  = faidx(sec_fasta, sec_chrom, s_s,             s_s + FLANK_W)
                s_ins_3  = faidx(sec_fasta, sec_chrom, s_e - FLANK_W,   s_e)
                s_l_flnk = faidx(sec_fasta, sec_chrom, s_s - FLANK_W,   s_s)
                s_r_flnk = faidx(sec_fasta, sec_chrom, s_e,             s_e + FLANK_W)
                if s_ins_len < 2 * FLANK_W:
                    half = s_ins_len // 2
                    s_ins_5 = s_ins_5[:half]
                    s_ins_3 = s_ins_3[-half:] if half else ""
                tsd_sec = search_tsd(s_ins_5, s_ins_3, s_l_flnk, s_r_flnk)
                if tsd_sec:
                    mm = sum(a != b for a, b in zip(tsd_pri["seq"], tsd_sec["seq"]))
                    sec_tsd_match = (
                        len(tsd_pri["seq"]) == len(tsd_sec["seq"]) and mm <= 1
                    )

            # --- Empty-site verification in absent species ---
            c_verified = False
            if tsd_pri and abs_chrom != "." and abs_pos_s not in (".", ""):
                abs_pos = int(abs_pos_s)
                window  = faidx(abs_fasta, abs_chrom,
                                abs_pos - ABS_W, abs_pos + ABS_W)
                c_verified = tsd_in_string(tsd_pri["seq"], window, max_mm=1)

            # --- Classification ---
            if tsd_pri and sec_tsd_match and c_verified:
                cls = "CONFIRMED"
            elif tsd_pri and sec_tsd_match:
                cls = "PROBABLE"
            elif tsd_pri:
                cls = "CANDIDATE"
            else:
                cls = "UNCONFIRMED"
            counts[cls] += 1

            tsd_seq  = tsd_pri["seq"]        if tsd_pri else "."
            tsd_len  = tsd_pri["length"]     if tsd_pri else "."
            tsd_mm   = tsd_pri["mismatches"] if tsd_pri else "."
            tsd_conf = tsd_pri["confidence"] if tsd_pri else "."
            tsd_src  = tsd_pri["source"]     if tsd_pri else "."

            fh_tsv.write("\t".join(row) +
                         f"\t{tsd_seq}\t{tsd_len}\t{tsd_mm}\t{tsd_conf}\t{tsd_src}"
                         f"\t{sec_tsd_match}\t{c_verified}\t{cls}\n")

            if cls in ("CONFIRMED", "PROBABLE"):
                fh_bed.write(f"{pri_chrom}\t{pri_start}\t{pri_end}\t{cls}\n")

    total = sum(counts.values())
    print(f"Total candidates : {total}")
    for cls in ("CONFIRMED", "PROBABLE", "CANDIDATE", "UNCONFIRMED"):
        pct = 100 * counts[cls] / total if total else 0
        print(f"  {cls:<12} : {counts[cls]:4d}  ({pct:.1f}%)")
    print(f"Output TSV : {out_tsv}")
    print(f"Output BED : {out_bed}")


if __name__ == "__main__":
    main()
