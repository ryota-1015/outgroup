#!/bin/bash
# ==============================================================================
# Purpose:      Convert RepeatMasker .out files to BED format
# Usage:        bash bed.sh
# Example:      bash bed.sh
# Dependencies: awk
# ==============================================================================
set -euo pipefail

# --- Path resolution ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_DIR="$BASE_DIR/results"
LOG_DIR="$BASE_DIR/log"
LOG_FILE="$LOG_DIR/out_to_bed_$(date +%Y%m%d).log"

# --- Setup ---
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "--- Starting RepeatMasker .out to BED conversion ---"
echo "Date: $(date)"
echo "Source directory: $RESULTS_DIR"

# --- Convert each .out file ---
found=0
for out_file in "$RESULTS_DIR"/*.fasta.out; do
    [ -f "$out_file" ] || continue
    found=1
    base=$(basename "$out_file" .fasta.out)
    bed_file="$RESULTS_DIR/${base}.bed"
    echo "# ---"
    echo "Processing: $base"
    # BED is 0-based: subtract 1 from the start position ($6)
    awk 'NR > 3 {print $5"\t"($6-1)"\t"$7"\t"$11}' "$out_file" > "$bed_file"
    echo "Written: $bed_file"
done

if [ "$found" -eq 0 ]; then
    echo "No .fasta.out files found in $RESULTS_DIR"
fi

echo "# ---"
echo "Conversion complete at $(date)"
