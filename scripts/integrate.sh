#!/bin/bash
set -euo pipefail

# --- Configuration ---
BASE_DIR="/home/co_ryota/outgroup"
RESULTS_DIR="$BASE_DIR/results"
OUT_DIR="$RESULTS_DIR/candidate_insertions"
LOG_DIR="$BASE_DIR/log"
MAF_FILE="$RESULTS_DIR/last_alignment/seq1_seq2_seq3_joined.maf"
REPEAT_DIR="$RESULTS_DIR/repeat_modeler"
LOG_FILE="$LOG_DIR/integrate_$(date +%Y%m%d_%H%M%S).log"

# Setup
mkdir -p "$OUT_DIR"
# Keep the log redirection as you liked it
exec > >(tee -a "$LOG_FILE") 2>&1

echo "--- Step 1: Extracting Shared Patterns from MAF ---"
# Run the new python script
# Note: It generates shared_BC_vs_A.bed, shared_AB_vs_C.bed, shared_AC_vs_B.bed
python3 extract_gaps.py "$MAF_FILE"

# Move them to the candidate directory
mv shared_*.bed "$OUT_DIR/"

echo "--- Step 2: Intersecting with RepeatMasker Results ---"

# Verification Case: B and C share it, A lacks it (A is Outgroup)
# We intersect with Species B's RepeatMasker data (GCA_002775205.2)
if [ -s "$OUT_DIR/shared_BC_vs_A.bed" ]; then
    echo "Processing shared_BC_vs_A..."
    bedtools intersect \
        -a "$OUT_DIR/shared_BC_vs_A.bed" \
        -b "$REPEAT_DIR/GCA_002775205.2.fasta.out" \
        -wa -wb > "$OUT_DIR/BC_shared_evidence.txt"
fi

# Verification Case: A and B share it, C lacks it (C is Outgroup)
# We intersect with Species A's RepeatMasker data (GCA_001444195.3)
if [ -s "$OUT_DIR/shared_AB_vs_C.bed" ]; then
    echo "Processing shared_AB_vs_C..."
    bedtools intersect \
        -a "$OUT_DIR/shared_AB_vs_C.bed" \
        -b "$REPEAT_DIR/GCA_001444195.3.fasta.out" \
        -wa -wb > "$OUT_DIR/AB_shared_evidence.txt"
fi

# Verification Case: A and C share it, B lacks it (B is Outgroup)
# We intersect with Species A's RepeatMasker data (GCA_001444195.3)
if [ -s "$OUT_DIR/shared_AC_vs_B.bed" ]; then
    echo "Processing shared_AC_vs_B..."
    bedtools intersect \
        -a "$OUT_DIR/shared_AC_vs_B.bed" \
        -b "$REPEAT_DIR/GCA_001444195.3.fasta.out" \
        -wa -wb > "$OUT_DIR/AC_shared_evidence.txt"
fi

echo "--- Analysis Complete ---"
echo "Check output files in $OUT_DIR to identify which shared insertions contain RT domains."