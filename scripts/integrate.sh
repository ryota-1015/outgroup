#!/bin/bash
set -euo pipefail

# --- Configuration ---
BASE_DIR="/home/co_ryota/outgroup"
RESULTS_DIR="$BASE_DIR/results"
OUT_DIR="$RESULTS_DIR/candidate_insertions"
LOG_DIR="$BASE_DIR/log"
MAF_FILE="$RESULTS_DIR/last_alignment/seq1_seq2_seq3_joined.maf"
REPEAT_DIR="$RESULTS_DIR"
LOG_FILE="$LOG_DIR/integrate_$(date +%Y%m%d_%H%M%S).log"

# Setup
mkdir -p "$OUT_DIR"
# Keep the log redirection as you liked it
exec > >(tee -a "$LOG_FILE") 2>&1

echo "--- Step 1: Extracting Shared Patterns from MAF (>= 50bp) ---"
python3 extract_gaps.py "$MAF_FILE"
mv shared_*.bed "$OUT_DIR/"

echo "--- Step 2: Extracting Marker Sequences for Phylogenetic Analysis ---"

# Case: B and C share it, A lacks it (A is Outgroup)
if [ -s "$OUT_DIR/shared_BC_vs_A.bed" ]; then
    echo "Extracting sequences for BC markers..."
    # Using GCA_002775205.2 (Taxon B) as the sequence reference
    bedtools getfasta \
        -fi "$RESULTS_DIR/GCA_002775205.2.fasta" \
        -bed "$OUT_DIR/shared_BC_vs_A.bed" \
        -fo "$OUT_DIR/BC_shared_markers.fasta"
fi

# Case: A and B share it, C lacks it (C is Outgroup)
if [ -s "$OUT_DIR/shared_AB_vs_C.bed" ]; then
    echo "Extracting sequences for AB markers..."
    # Using GCA_001444195.3 (Taxon A) as the sequence reference
    bedtools getfasta \
        -fi "$RESULTS_DIR/GCA_001444195.3.fasta" \
        -bed "$OUT_DIR/shared_AB_vs_C.bed" \
        -fo "$OUT_DIR/AB_shared_markers.fasta"
fi

# Case: A and C share it, B lacks it (B is Outgroup)
if [ -s "$OUT_DIR/shared_AC_vs_B.bed" ]; then
    echo "Extracting sequences for AC markers..."
    bedtools getfasta \
        -fi "$RESULTS_DIR/GCA_001444195.3.fasta" \
        -bed "$OUT_DIR/shared_AC_vs_B.bed" \
        -fo "$OUT_DIR/AC_shared_markers.fasta"
fi

echo "--- Analysis Complete ---"
echo "FASTA files are ready in $OUT_DIR for tree building."