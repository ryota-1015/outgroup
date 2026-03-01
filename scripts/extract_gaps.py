"""
Purpose:      Identify shared/unique insertion patterns from a 3-species MAF alignment
Usage:        python3 extract_gaps.py <maf_file> <min_len> <masked_A> <masked_B> <masked_C> <output_dir>
Example:      python3 extract_gaps.py seq1_seq2_seq3_joined.maf 50 \
                  A.fasta.masked B.fasta.masked C.fasta.masked results/candidate_insertions_50bp
Dependencies: Python 3 standard library; samtools faidx must have been run on each masked FASTA
"""

import sys
import os


def usage():
    print(
        "Usage: python3 extract_gaps.py <maf_file> <min_len> "
        "<masked_A> <masked_B> <masked_C> <output_dir>",
        file=sys.stderr,
    )
    print(
        "Example: python3 extract_gaps.py joined.maf 50 "
        "A.fasta.masked B.fasta.masked C.fasta.masked out/",
        file=sys.stderr,
    )
    sys.exit(1)


# ---------------------------------------------------------------------------
# Build seq_name → species_label map from .fai index files
# ---------------------------------------------------------------------------

def build_species_map(fasta_paths):
    """
    Read <fasta>.fai for each path in fasta_paths (labelled A, B, C).
    Returns:
        seq_to_species : dict  seq_name -> "A" | "B" | "C"
        label_to_chrom : dict  label -> {chrom: True, ...}  (for reference lookup)
    """
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
# MAF parsing and pattern detection
# ---------------------------------------------------------------------------

PATTERNS = {
    "BC_shared": [False, True,  True ],
    "AB_shared": [True,  True,  False],
    "AC_shared": [True,  False, True ],
    "A_only":    [True,  False, False],
    "B_only":    [False, True,  False],
    "C_only":    [False, False, True ],
}

# Which species label contributes genomic coordinates for each pattern
PATTERN_REF = {
    "BC_shared": "B",
    "B_only":    "B",
    "C_only":    "C",
    "AB_shared": "A",
    "AC_shared": "A",
    "A_only":    "A",
}


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
    # handle file that doesn't end with blank line
    if block:
        process_block(block, min_len, output_dir)


def process_block(block, min_len, output_dir):
    if not all(lbl in block for lbl in ("A", "B", "C")):
        return

    seq_len = len(block["A"]["seq"])

    # Precompute cumulative non-gap counts for each species
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
                    ref_lbl  = PATTERN_REF[key]
                    ref_data = block[ref_lbl]
                    g_start  = ref_data["start"] + cum[ref_lbl][current_starts[key]]
                    g_end    = ref_data["start"] + cum[ref_lbl][i]

                    if (g_end - g_start) >= min_len:
                        fname = os.path.join(output_dir, f"pattern_{key}_{min_len}bp.bed")
                        write_bed(fname, ref_data["chrom"], g_start, g_end, f"pattern_{key}")

                    current_starts[key] = -1


def write_bed(filepath, chrom, start, end, label):
    with open(filepath, "a") as fh:
        fh.write(f"{chrom}\t{start}\t{end}\t{label}\n")


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

    # Remove stale BED files so we don't append to previous runs
    for key in PATTERNS:
        bed_path = os.path.join(output_dir, f"pattern_{key}_{min_len}bp.bed")
        if os.path.exists(bed_path):
            os.remove(bed_path)

    seq_to_species, _ = build_species_map([masked_a, masked_b, masked_c])
    parse_maf(maf_file, min_len, seq_to_species, output_dir)
