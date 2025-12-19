#!/bin/bash

# --- Configuration ---
BASE_DIR="/home/co_ryota/outgroup"
RESULTS_DIR="$BASE_DIR/results"
OUT_DIR="$RESULTS_DIR/candidate_insertions"
LOG_DIR="$BASE_DIR/log"
MAF_FILE="$RESULTS_DIR/last_alignment/seq1_seq2_seq3_joined.maf"
LOG_FILE="$LOG_DIR/integrate_$(date +%Y%m%d).log"

# Setup
mkdir -p "$OUT_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "--- Step 1: Extracting unique sequences from MAF ---"
# Run the python script (ensure extract_gaps.py is in the same folder)
python3 extract_gaps.py "$MAF_FILE" > "$OUT_DIR/unique_segments.bed"

echo "--- Step 2: Intersecting with RepeatMasker TEs ---"
# Use bedtools to find overlaps between unique segments and TE annotations
for taxon_bed in "$OUT_DIR"/GCA_*.bed; do
    # Skip the segment file itself to avoid self-intersection
    if [[ "$taxon_bed" == *"unique_segments.bed" ]]; then continue; fi
    
    base=$(basename "$taxon_bed" .bed)
    echo "Processing $base..."
    
    # Intersect -wa (unique_segments) with -wb (taxon-specific TEs)
    # This matches rows based on chromosome name (Column 1) and coordinates
    /home/co_ryota/my_conda/bin/bedtools intersect \
        -a "$OUT_DIR/unique_segments.bed" \
        -b "$taxon_bed" \
        -wa -wb > "$OUT_DIR/${base}_final_evidence.txt"
done

echo "--- Analysis Complete ---"