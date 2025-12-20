#!/bin/bash
set -euo pipefail

# --- Configuration ---
BASE_DIR="/home/co_ryota/outgroup"
RESULTS_DIR="$BASE_DIR/results"
OUT_DIR="$RESULTS_DIR/candidate_insertions"
MAF_FILE="$RESULTS_DIR/last_alignment/seq1_seq2_seq3_joined.maf"

# Setup
mkdir -p "$OUT_DIR"

echo "--- Step 1: Extracting Shared Patterns (>= 50bp) from MAF ---"
python3 extract_gaps.py "$MAF_FILE"

# CLEANUP: Ensure BED files are strictly tab-delimited and have no hidden characters
for f in shared_*.bed; do
    if [ -f "$f" ]; then
        sed -i 's/\r//g' "$f"
        awk '{printf "%s\t%s\t%s\t%s\n", $1, $2, $3, $4}' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
    fi
done
mv shared_*.bed "$OUT_DIR/"

echo "--- Step 2: Preparing Genomes and Extracting Sequences ---"

# Sanitization loop
for genome in "$RESULTS_DIR"/GCA_*.fasta.masked; do
    echo "Sanitizing and indexing $genome..."
    sed -i 's/^>\([^[:space:]]*\).*/>\1/' "$genome"
    samtools faidx "$genome"
done

# --- CORRECTED EXTRACTION LOGIC ---

# Case: B and C share it (Anchor B = CM010726.1)
if [ -s "$OUT_DIR/shared_BC_vs_A.bed" ]; then
    echo "Extracting sequences for BC markers..."
    # CM010726.1 is actually in GCA_001444195.3
    bedtools getfasta \
        -fi "$RESULTS_DIR/GCA_001444195.3.fasta.masked" \
        -bed "$OUT_DIR/shared_BC_vs_A.bed" \
        -fo "$OUT_DIR/BC_shared_markers.fasta.masked"
fi

# Case: A and B share it (Anchor A = CM008938.1)
if [ -s "$OUT_DIR/shared_AB_vs_C.bed" ]; then
    echo "Extracting sequences for AB markers..."
    # CM008938.1 is actually in GCA_002775205.2
    bedtools getfasta \
        -fi "$RESULTS_DIR/GCA_002775205.2.fasta.masked" \
        -bed "$OUT_DIR/shared_AB_vs_C.bed" \
        -fo "$OUT_DIR/AB_shared_markers.fasta.masked"
fi

# Case: A and C share it (Anchor A = CM008938.1)
if [ -s "$OUT_DIR/shared_AC_vs_B.bed" ]; then
    echo "Extracting sequences for AC markers..."
    # CM008938.1 is actually in GCA_002775205.2
    bedtools getfasta \
        -fi "$RESULTS_DIR/GCA_002775205.2.fasta.masked" \
        -bed "$OUT_DIR/shared_AC_vs_B.bed" \
        -fo "$OUT_DIR/AC_shared_markers.fasta.masked"
fi

echo "--- Analysis Complete ---"