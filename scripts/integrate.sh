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

echo "--- Step 1: Extracting Shared Patterns from MAF ---"
# Run the new python script
# Note: It generates shared_BC_vs_A.bed, shared_AB_vs_C.bed, shared_AC_vs_B.bed
python3 extract_gaps.py "$MAF_FILE"

# Move them to the candidate directory
mv shared_*.bed "$OUT_DIR/"

echo "--- Step 2: Intersecting with RepeatMasker Results ---"

# Helper function to convert RepeatMasker .out to valid TAB-delimited BED
convert_rm_to_bed() {
    local input_out="$1"
    local output_bed="${input_out}.bed"
    # Skips 3 header lines, extracts: Chrom(5), Start(6), End(7), Family(11)
    awk 'NR > 3 {print $5 "\t" $6 "\t" $7 "\t" $11}' "$input_out" > "$output_bed"
    echo "$output_bed"
}

# Verification Case: B and C share it, A lacks it (A is Outgroup)
if [ -s "$OUT_DIR/shared_BC_vs_A.bed" ]; then
    echo "Processing shared_BC_vs_A..."
    # Convert .out to temporary BED for bedtools
    RM_BED=$(convert_rm_to_bed "$REPEAT_DIR/GCA_002775205.2.fasta.out")
    
    bedtools intersect \
        -a "$OUT_DIR/shared_BC_vs_A.bed" \
        -b "$RM_BED" \
        -wa -wb > "$OUT_DIR/BC_shared_evidence.txt"
fi

# Verification Case: A and B share it, C lacks it (C is Outgroup)
if [ -s "$OUT_DIR/shared_AB_vs_C.bed" ]; then
    echo "Processing shared_AB_vs_C..."
    RM_BED=$(convert_rm_to_bed "$REPEAT_DIR/GCA_001444195.3.fasta.out")
    
    bedtools intersect \
        -a "$OUT_DIR/shared_AB_vs_C.bed" \
        -b "$RM_BED" \
        -wa -wb > "$OUT_DIR/AB_shared_evidence.txt"
fi

# Verification Case: A and C share it, B lacks it (B is Outgroup)
if [ -s "$OUT_DIR/shared_AC_vs_B.bed" ]; then
    echo "Processing shared_AC_vs_B..."
    # Still using Species A (CM008938.1) as the reference for coordinates
    RM_BED=$(convert_rm_to_bed "$REPEAT_DIR/GCA_001444195.3.fasta.out")
    
    bedtools intersect \
        -a "$OUT_DIR/shared_AC_vs_B.bed" \
        -b "$RM_BED" \
        -wa -wb > "$OUT_DIR/AC_shared_evidence.txt"
fi

echo "--- Analysis Complete ---"
echo "Check output files in $OUT_DIR to identify which shared insertions contain RT domains."