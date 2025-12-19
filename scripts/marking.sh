#!/bin/bash

# --- Configuration ---
BASE_DIR="/home/co_ryota/outgroup"
GENOME_DIR="$BASE_DIR/data"
IN_DIR="$BASE_DIR/results/candidate_insertions/filtered"
OUT_DIR="$BASE_DIR/results/candidate_insertions/sequences"
LOG_DIR="$BASE_DIR/log"
LOG_FILE="$LOG_DIR/get_fasta_$(date +%Y%m%d).log"

# Setup
mkdir -p "$OUT_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "--- Starting Sequence Extraction ---"

for bed in "$IN_DIR"/*_high_quality.bed; do
    [ -e "$bed" ] || continue
    base=$(basename "$bed" _high_quality.bed)
    
    # Matching your exact filenames in /data/
    genome_fasta="$GENOME_DIR/${base}.fasta"
    output_fasta="$OUT_DIR/${base}_markers.fasta"
    
    if [ ! -f "$genome_fasta" ]; then
        echo "Error: Genome fasta not found for $base at $genome_fasta"
        continue
    fi

    echo "Extracting sequences for $base..."
    
    # Extract DNA using bedtools
    # -name: use the 4th column of the BED as the FASTA header
    /home/co_ryota/my_conda/bin/bedtools getfasta \
        -fi "$genome_fasta" \
        -bed "$bed" \
        -fo "$output_fasta" \
        -name
done

echo "--- Extraction Complete ---"