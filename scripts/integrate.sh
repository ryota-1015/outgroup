#!/bin/bash
set -euo pipefail

BASE_DIR="/home/co_ryota/outgroup"
RESULTS_DIR="$BASE_DIR/results"
MAF_FILE="$RESULTS_DIR/last_alignment/seq1_seq2_seq3_joined.maf"

# Define Species Genomes
GA="$RESULTS_DIR/GCA_002775205.2.fasta.masked"
GB="$RESULTS_DIR/GCA_001444195.3.fasta.masked"
GC="$RESULTS_DIR/GCA_036418095.1.fasta.masked"

# Sanitization loop
for g in "$GA" "$GB" "$GC"; do
    echo "Sanitizing and indexing $(basename "$g")..."
    sed -i 's/^>\([^[:space:]]*\).*/>\1/' "$g"
    samtools faidx "$g"
done

run_analysis() {
    local len=$1
    local OUT_DIR="$RESULTS_DIR/candidate_insertions_${len}bp"
    mkdir -p "$OUT_DIR"

    echo "--- Running Symmetrical Analysis for ${len}bp ---"
    python3 extract_gaps.py "$MAF_FILE" "$len"

    mv pattern_*_${len}bp.bed "$OUT_DIR/" 2>/dev/null || true

    # --- EXTRACTION LOGIC MAPPING ---
    
    # 1. From Genome A (A, AB, AC)
    for p in A_only AB_shared AC_shared; do
        BED="$OUT_DIR/pattern_${p}_${len}bp.bed"
        [ -s "$BED" ] && bedtools getfasta -fi "$GA" -bed "$BED" -fo "$OUT_DIR/${p}.fasta"
    done

    # 2. From Genome B (B, BC)
    for p in B_only BC_shared; do
        BED="$OUT_DIR/pattern_${p}_${len}bp.bed"
        [ -s "$BED" ] && bedtools getfasta -fi "$GB" -bed "$BED" -fo "$OUT_DIR/${p}.fasta"
    done

    # 3. From Genome C (C)
    BED="$OUT_DIR/pattern_C_only_${len}bp.bed"
    [ -s "$BED" ] && bedtools getfasta -fi "$GC" -bed "$BED" -fo "$OUT_DIR/C_only.fasta"
}

run_analysis 50
run_analysis 100

echo "--- All Analyses Complete ---"