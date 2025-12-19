#!/bin/bash
# Enable strict error handling
set -euo pipefail

# --- English Comments ---
# 0. Logging Setup
LOG_DIR="../log"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/repeat_masking_${TIMESTAMP}.log"

mkdir -p "$LOG_DIR"
# Redirect stdout and stderr to the log file
exec > >(tee -a "$LOG_FILE") 2>&1

echo "--- Starting Repeat Masking Pipeline ---"
echo "Date: $(date)"
echo "Log file: $LOG_FILE"

# 1. Path Setup
PROJECT_ROOT=$(cd "${PWD}/.." && pwd)
DATA_DIR="$PROJECT_ROOT/data"
RESULTS_DIR="$PROJECT_ROOT/results"
THREADS=16

# 2. Library Selection
LIBRARY="$RESULTS_DIR/repeat_modeler/RM_3307282.WedDec170324072025/consensi.fa.classified"

# 3. Target Genomes
FASTAS=(
    "$DATA_DIR/GCA_002775205.2.fasta"
    "$DATA_DIR/GCA_001444195.3.fasta"
    "$DATA_DIR/GCA_036418095.1.fasta"
)

# 4. Load Environment
module load repeatmodeler/2.0.5

# 5. Execute RepeatMasker
for FASTA in "${FASTAS[@]}"; do
    NAME=$(basename "$FASTA")
    echo "-------------------------------------------------------"
    echo "Processing $NAME..."
    
    # -xsmall: soft-masking
    # -gff: generate annotation file
    RepeatMasker \
        -pa "$THREADS" \
        -lib "$LIBRARY" \
        -xsmall \
        -gff \
        -dir "$RESULTS_DIR" \
        "$FASTA"
done

echo "-------------------------------------------------------"
echo "Repeat masking complete at $(date)"