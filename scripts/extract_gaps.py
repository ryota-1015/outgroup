"""
Purpose:      Identify shared/unique insertion patterns from a 3-species MAF alignment
Usage:        python3 extract_gaps.py <maf_file> <min_len> <masked_A> <masked_B> <masked_C> <output_dir>
Example:      python3 extract_gaps.py seq1_seq2_seq3_joined.maf 50 \
                  A.fasta.masked B.fasta.masked C.fasta.masked results/candidate_insertions_50bp
Dependencies: Python 3 standard library; samtools faidx must have been run on each masked FASTA

Output per pattern (e.g. AB_shared):
  pattern_AB_shared_50bp.bed  — 4-col BED of primary species coords (for bedtools)
  pattern_AB_shared_50bp.tsv  — 9-col TSV with all three species coords (for TSD script)
    cols: pri_chrom pri_start pri_end pattern sec_chrom sec_start sec_end abs_chrom abs_pos
"""

import sys
import os


def usage():
    print(
        "Usage: python3 extract_gaps.py <maf_file> <min_len> "
        "<masked_A> <masked_B> <masked_C> <output_dir>",
        file=sys.stderr,
    )
    sys.exit(1)


# ---------------------------------------------------------------------------
# Build seq_name → species_label map from .fai index files
# ---------------------------------------------------------------------------

def build_species_map(fasta_paths):
    labels = ("A", "B", "C")
    seq_to_species = {}
    label_to_chrom = {lbl: set() for lbl in labels}

    for label, fasta_path in zip(labels, fasta_paths):
        fai_path = fasta_path + ".fai"
        if not os.path.exists(fai_path):
            print(f"ERROR: Index not found: {fai_path}", file=sys.stderr)
            print("Run 'samtools faidx' on each masked FASTA before calling this script.", file=sys.stderr)
            sys.exit(1)
        with open(fai_path) as fh:
            for line in fh:
                seq_name = line.split("\t")[0]
                if seq_name in seq_to_species:
                    print(
                        f"WARNING: Sequence name '{seq_name}' appears in both "
                        f"species {seq_to_species[seq_name]} and {label}. "
                        "The first mapping will be used.",
                        file=sys.stderr,
                    )
                    continue
                seq_to_species[seq_name] = label
                label_to_chrom[label].add(seq_name)

    return seq_to_species, label_to_chrom


# ---------------------------------------------------------------------------
# Cumulative non-gap helper
# ---------------------------------------------------------------------------

def cum_non_gap(seq):
    """Return array c where c[i] = number of non-gap characters in seq[:i]."""
    c = [0] * (len(seq) + 1)
    for i, ch in enumerate(seq):
        c[i + 1] = c[i] + (ch != "-")
    return c


# ---------------------------------------------------------------------------
# Pattern definitions
# ---------------------------------------------------------------------------

PATTERNS = {
    "BC_shared": [False, True,  True ],
    "AB_shared": [True,  True,  False],
    "AC_shared": [True,  False, True ],
    "A_only":    [True,  False, False],
    "B_only":    [False, True,  False],
    "C_only":    [False, False, True ],
}

# For each pattern: (primary_label, secondary_label_or_None, absent_label_or_None)
# Primary = species whose coords go in the BED (PATTERN_REF from original code)
# Secondary = other carrier species (if shared); absent = species with gap (empty site)
PATTERN_ROLES = {
    "AB_shared": ("A", "B", "C"),
    "AC_shared": ("A", "C", "B"),
    "BC_shared": ("B", "C", "A"),
    "A_only":    ("A", None, None),
    "B_only":    ("B", None, None),
    "C_only":    ("C", None, None),
}


# ---------------------------------------------------------------------------
# MAF parsing and pattern detection
# ---------------------------------------------------------------------------

def parse_maf(maf_path, min_len, seq_to_species, output_dir):
    block = {}
    with open(maf_path) as fh:
        for line in fh:
            if line.startswith("s "):
                parts = line.split()
                seq_name = parts[1]
                start    = int(parts[2])
                seq      = parts[6]
                label    = seq_to_species.get(seq_name)
                if label is not None:
                    block[label] = {"chrom": seq_name, "start": start, "seq": seq}
            elif line.strip() == "" and block:
                process_block(block, min_len, output_dir)
                block = {}
    if block:
        process_block(block, min_len, output_dir)


def process_block(block, min_len, output_dir):
    if not all(lbl in block for lbl in ("A", "B", "C")):
        return

    seq_len = len(block["A"]["seq"])
    cum = {lbl: cum_non_gap(block[lbl]["seq"]) for lbl in ("A", "B", "C")}
    current_starts = {key: -1 for key in PATTERNS}

    for i in range(seq_len):
        present = [block[lbl]["seq"][i] != "-" for lbl in ("A", "B", "C")]

        for key, match_p in PATTERNS.items():
            if present == match_p:
                if current_starts[key] == -1:
                    current_starts[key] = i
            else:
                if current_starts[key] != -1:
                    i_start = current_starts[key]
                    pri_lbl, sec_lbl, abs_lbl = PATTERN_ROLES[key]

                    pri  = block[pri_lbl]
                    g_start = pri["start"] + cum[pri_lbl][i_start]
                    g_end   = pri["start"] + cum[pri_lbl][i]

                    if (g_end - g_start) >= min_len:
                        # 4-col BED (primary coords)
                        bed_path = os.path.join(output_dir, f"pattern_{key}_{min_len}bp.bed")
                        write_bed(bed_path, pri["chrom"], g_start, g_end, f"pattern_{key}")

                        # 9-col TSV (all three species coords)
                        tsv_path = os.path.join(output_dir, f"pattern_{key}_{min_len}bp.tsv")
                        if sec_lbl:
                            sec = block[sec_lbl]
                            sec_start = sec["start"] + cum[sec_lbl][i_start]
                            sec_end   = sec["start"] + cum[sec_lbl][i]
                            abs_data  = block[abs_lbl]
                            # absent species has all gaps here → position doesn't advance
                            abs_pos   = abs_data["start"] + cum[abs_lbl][i_start]
                            write_tsv(tsv_path,
                                      pri["chrom"], g_start, g_end, key,
                                      sec["chrom"], sec_start, sec_end,
                                      abs_data["chrom"], abs_pos)
                        else:
                            write_tsv(tsv_path,
                                      pri["chrom"], g_start, g_end, key,
                                      ".", ".", ".", ".", ".")

                    current_starts[key] = -1


def write_bed(filepath, chrom, start, end, label):
    with open(filepath, "a") as fh:
        fh.write(f"{chrom}\t{start}\t{end}\t{label}\n")


def write_tsv(filepath, pri_chrom, pri_start, pri_end, pattern,
              sec_chrom, sec_start, sec_end, abs_chrom, abs_pos):
    # Write header on first call (file doesn't exist yet)
    write_header = not os.path.exists(filepath)
    with open(filepath, "a") as fh:
        if write_header:
            fh.write("pri_chrom\tpri_start\tpri_end\tpattern\t"
                     "sec_chrom\tsec_start\tsec_end\tabs_chrom\tabs_pos\n")
        fh.write(f"{pri_chrom}\t{pri_start}\t{pri_end}\t{pattern}\t"
                 f"{sec_chrom}\t{sec_start}\t{sec_end}\t{abs_chrom}\t{abs_pos}\n")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    if len(sys.argv) != 7:
        usage()

    maf_file   = sys.argv[1]
    min_len    = int(sys.argv[2])
    masked_a   = sys.argv[3]
    masked_b   = sys.argv[4]
    masked_c   = sys.argv[5]
    output_dir = sys.argv[6]

    os.makedirs(output_dir, exist_ok=True)

    # Remove stale output files so we don't append to previous runs
    for key in PATTERNS:
        for ext in ("bed", "tsv"):
            p = os.path.join(output_dir, f"pattern_{key}_{min_len}bp.{ext}")
            if os.path.exists(p):
                os.remove(p)

    seq_to_species, _ = build_species_map([masked_a, masked_b, masked_c])
    parse_maf(maf_file, min_len, seq_to_species, output_dir)
