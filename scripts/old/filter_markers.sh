#!/bin/bash

# --- Configuration ---
BASE_DIR="/home/co_ryota/outgroup"
IN_DIR="$BASE_DIR/results/candidate_insertions"
OUT_DIR="$IN_DIR/filtered"
LOG_DIR="$BASE_DIR/log"
LOG_FILE="$LOG_DIR/filter_$(date +%Y%m%d).log"

# Parameters
MIN_LENGTH=500

# Setup
mkdir -p "$OUT_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "--- Starting Marker Filtering (Based on TE Length) ---"

for f in "$IN_DIR"/*_final_evidence.txt; do
    [ -e "$f" ] || continue
    base=$(basename "$f" _final_evidence.txt)
    output_file="$OUT_DIR/${base}_high_quality.bed"
    
    echo "Filtering $base..."
    
    # Logic Update:
    # 1. Calculate TE length using Col 7 and Col 6 ($7 - $6)
    # 2. Search for LINE or LTR anywhere in the line
    # 3. Output standard BED format
    awk -v len="$MIN_LENGTH" '
        {
            te_len = $7 - $6
            if (te_len >= len && ($0 ~ /LINE/ || $0 ~ /LTR/)) {
                print $5 "\t" $6 "\t" $7 "\t" $8 "\t" te_len "\t" "'$base'"
            }
        }' "$f" > "$output_file"
        
    echo "Found $(wc -l < "$output_file") high-quality markers for $base."
done

echo "--- Filtering Complete ---"