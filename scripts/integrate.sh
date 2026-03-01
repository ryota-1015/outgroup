#!/bin/bash
# ==============================================================================
# Purpose:      Identify shared/unique insertion patterns across 3 masked genomes
# Usage:        bash integrate.sh <masked_A> <masked_B> <masked_C>
# Example:      bash integrate.sh GCA_009914755.4.fasta.masked \
#                   GCA_028858775.2.fasta.masked GCA_028885655.2.fasta.masked
# Dependencies: python3, samtools, bedtools, extract_gaps.py
# ==============================================================================
set -euo pipefail

# --- Argument handling ---
usage() {
    echo "Usage: $0 <masked_A> <masked_B> <masked_C>" >&2
    echo "Example: $0 GCA_009914755.4.fasta.masked GCA_028858775.2.fasta.masked GCA_028885655.2.fasta.masked" >&2
    exit 1
}
[ $# -ne 3 ] && usage

# --- Path resolution ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_DIR="$BASE_DIR/results"
MAF_FILE="$RESULTS_DIR/last_alignment/seq1_seq2_seq3_joined.maf"

# --- Resolve masked genome paths (filenames relative to results/) ---
GA="$RESULTS_DIR/$1"
GB="$RESULTS_DIR/$2"
GC="$RESULTS_DIR/$3"

# --- Validate inputs ---
for g in "$GA" "$GB" "$GC" "$MAF_FILE"; do
    if [ ! -f "$g" ]; then
        echo "ERROR: Required file not found: $g" >&2
        exit 1
    fi
done

# --- Sanitize headers and index ---
echo "--- Sanitizing and indexing masked genomes ---"
for g in "$GA" "$GB" "$GC"; do
    echo "Sanitizing $(basename "$g")..."
    sed -i 's/^>\([^[:space:]]*\).*/>\1/' "$g"
    samtools faidx "$g"
done

# --- Run analysis at each length threshold ---
run_analysis() {
    local len=$1
    local OUT_DIR="$RESULTS_DIR/candidate_insertions_${len}bp"
    mkdir -p "$OUT_DIR"

    echo "# --- Running analysis for ${len}bp threshold ---"
    python3 "$SCRIPT_DIR/extract_gaps.py" "$MAF_FILE" "$len" "$GA" "$GB" "$GC" "$OUT_DIR"

    # --- Extract FASTA sequences for each pattern ---

    # Patterns originating from Genome A
    for p in A_only AB_shared AC_shared; do
        BED="$OUT_DIR/pattern_${p}_${len}bp.bed"
        [ -s "$BED" ] && bedtools getfasta -fi "$GA" -bed "$BED" -fo "$OUT_DIR/${p}.fasta"
    done

    # Patterns originating from Genome B
    for p in B_only BC_shared; do
        BED="$OUT_DIR/pattern_${p}_${len}bp.bed"
        [ -s "$BED" ] && bedtools getfasta -fi "$GB" -bed "$BED" -fo "$OUT_DIR/${p}.fasta"
    done

    # Patterns originating from Genome C
    BED="$OUT_DIR/pattern_C_only_${len}bp.bed"
    [ -s "$BED" ] && bedtools getfasta -fi "$GC" -bed "$BED" -fo "$OUT_DIR/C_only.fasta"

    echo "Results written to: $OUT_DIR"
}

run_analysis 50
run_analysis 100

echo "--- All analyses complete ---"
