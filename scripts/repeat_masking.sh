#!/bin/bash
# ==============================================================================
# Purpose:      Soft-mask genomes with RepeatMasker using a pre-built repeat library
# Usage:        bash repeat_masking.sh <library_path> <fasta1> [fasta2] ...
# Example:      bash repeat_masking.sh ../results/repeat_modeler/families.fa \
#                   GCA_009914755.4.fasta GCA_028858775.2.fasta GCA_028885655.2.fasta
# Dependencies: RepeatMasker (module load repeatmodeler/2.0.5 on HPC)
# ==============================================================================
set -euo pipefail

# --- Argument handling ---
usage() {
    echo "Usage: $0 <library_path> <fasta1> [fasta2] ..." >&2
    echo "Example: $0 ../results/repeat_modeler/families.fa GCA_009914755.4.fasta GCA_028858775.2.fasta" >&2
    exit 1
}
[ $# -lt 2 ] && usage

# --- Path resolution ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DATA_DIR="$BASE_DIR/data"
RESULTS_DIR="$BASE_DIR/results"
LOG_DIR="$BASE_DIR/log"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/repeat_masking_${TIMESTAMP}.log"

# --- Parse arguments ---
LIBRARY="$1"
shift
FASTAS=("$@")
THREADS=16

# --- Validate library ---
if [ ! -f "$LIBRARY" ]; then
    echo "ERROR: Library not found: $LIBRARY" >&2
    exit 1
fi

# --- Setup ---
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "--- Starting Repeat Masking Pipeline ---"
echo "Date: $(date)"
echo "Log file: $LOG_FILE"
echo "Library: $LIBRARY"
echo "Targets: ${FASTAS[*]}"

# --- Load HPC environment ---
module load repeatmodeler/2.0.5

# --- Run RepeatMasker for each genome ---
for FASTA in "${FASTAS[@]}"; do
    FASTA_PATH="$DATA_DIR/$FASTA"
    NAME=$(basename "$FASTA_PATH")
    echo "# ---"
    echo "Processing $NAME..."

    if [ ! -f "$FASTA_PATH" ]; then
        echo "ERROR: FASTA not found: $FASTA_PATH"
        continue
    fi

    # -xsmall: soft-masking; -gff: generate annotation file
    RepeatMasker \
        -pa "$THREADS" \
        -lib "$LIBRARY" \
        -xsmall \
        -gff \
        -dir "$RESULTS_DIR" \
        "$FASTA_PATH"
done

echo "# ---"
echo "Repeat masking complete at $(date)"
