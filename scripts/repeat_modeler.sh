#!/bin/bash
# ==============================================================================
# Purpose:      Build a de-novo repeat library for a reference genome with RepeatModeler
# Usage:        bash repeat_modeler.sh <ref_fasta_filename>
# Example:      bash repeat_modeler.sh GCA_009914755.4.fasta
# Dependencies: RepeatModeler (BuildDatabase, RepeatModeler), blastdbcmd
# ==============================================================================
set -euo pipefail

# --- Argument handling ---
usage() {
    echo "Usage: $0 <ref_fasta_filename>" >&2
    echo "Example: $0 GCA_009914755.4.fasta" >&2
    exit 1
}
[ $# -ne 1 ] && usage

# --- Path resolution ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DATA_DIR="$BASE_DIR/data"
REPEAT_RESULTS_DIR="$BASE_DIR/results/repeat_modeler"
LOG_DIR="$BASE_DIR/log"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/repeat_modeler_${TIMESTAMP}.log"

# --- Configuration ---
REF_FASTA="$DATA_DIR/$1"
REF_BASENAME=$(basename "$REF_FASTA" .fasta)
DB_BASENAME="$REF_BASENAME"
LIBRARY_FA="families.fa"
LIBRARY_PATH="$REPEAT_RESULTS_DIR/$LIBRARY_FA"
THREADS=8

# --- Setup ---
mkdir -p "$REPEAT_RESULTS_DIR" "$LOG_DIR"
echo "--- $(date): Starting RepeatModeler ---" > "$LOG_FILE"
echo "All output redirected to: $LOG_FILE" >&2
exec 1>> "$LOG_FILE" 2>&1

echo "Reference FASTA: $REF_FASTA"
echo "Results directory: $REPEAT_RESULTS_DIR"

# --- Validate input ---
if [ ! -f "$REF_FASTA" ]; then
    echo "ERROR: Reference FASTA not found: $REF_FASTA"
    exit 1
fi

# --- Sanitize FASTA headers ---
echo "# --- Sanitizing reference FASTA headers ---"
PREP_FASTA="$REPEAT_RESULTS_DIR/$REF_BASENAME.prep.fasta"

awk '/^>/{print ">seq_" ++i; next} {print}' "$REF_FASTA" > "$PREP_FASTA"

if [ ! -s "$PREP_FASTA" ]; then
    echo "CRITICAL ERROR: Failed to create $PREP_FASTA"
    exit 1
fi
echo "Sanitized FASTA created: $PREP_FASTA"

# --- Build RepeatModeler database ---
echo "# --- Running RepeatModeler ---"
cd "$REPEAT_RESULTS_DIR"

if [ ! -f "${DB_BASENAME}.nin" ]; then
    echo "Building RepeatModeler database..."
    time BuildDatabase -name "$DB_BASENAME" "$PREP_FASTA"
else
    echo "Database exists (${DB_BASENAME}.nin). Skipping BuildDatabase."
fi

echo "DB sanity check:"
blastdbcmd -db "$DB_BASENAME" -info | head -n 20 || true

if [ ! -s "$LIBRARY_FA" ]; then
    echo "Running RepeatModeler (threads=$THREADS)..."
    time RepeatModeler \
        -database "$DB_BASENAME" \
        -engine ncbi \
        -pa "$THREADS"
else
    echo "Repeat library already exists — skipping RepeatModeler."
fi

if [ ! -s "$LIBRARY_FA" ]; then
    echo "ERROR: RepeatModeler failed (families.fa missing)"
    exit 1
fi

cd - > /dev/null

echo "# ---"
echo "Repeat library ready: $LIBRARY_PATH"
echo "--- $(date): Script End ---"
