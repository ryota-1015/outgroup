#!/bin/bash

# Directories based on your established structure
BASE_DIR="/home/co_ryota/outgroup"
RESULTS_DIR="$BASE_DIR/results"
OUT_DIR="$RESULTS_DIR/candidate_insertions"
LOG_DIR="$BASE_DIR/log"
LOG_FILE="$LOG_DIR/out_to_bed_$(date +%Y%m%d).log"

# Setup
mkdir -p "$OUT_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "--- Starting RepeatMasker .out to BED conversion ---"

# Convert RepeatMasker .out to BED format
# We extract: Chromosome, Start, End, and Class/Family
for out_file in "$RESULTS_DIR"/*.fasta.out; do
    if [ -f "$out_file" ]; then
        base=$(basename "$out_file" .fasta.out)
        echo "Processing: $base"
        
        # Use awk to skip headers and print tab-delimited columns
        # Note: BED is 0-based, so we subtract 1 from the start position ($6)
        awk 'NR > 3 {print $5"\t"($6-1)"\t"$7"\t"$11}' "$out_file" > "$OUT_DIR/${base}.bed"
    else
        echo "No .out files found in $RESULTS_DIR"
    fi
done

echo "--- Conversion complete. Files saved in $OUT_DIR ---"