#!/bin/bash
# ==============================================================================
# Purpose:      Download genome assemblies from NCBI by accession number
# Usage:        bash dwl.sh <GCA_accession1> [GCA_accession2] ...
# Example:      bash dwl.sh GCA_009914755.4 GCA_028858775.2 GCA_028885655.2
# Dependencies: datasets (NCBI Datasets CLI), unzip
# ==============================================================================
set -euo pipefail

# --- Argument handling ---
usage() {
    echo "Usage: $0 <GCA_accession1> [GCA_accession2] ..." >&2
    echo "Example: $0 GCA_009914755.4 GCA_028858775.2 GCA_028885655.2" >&2
    exit 1
}
[ $# -lt 1 ] && usage

ACCESSIONS=("$@")

# --- Path resolution ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DATA_DIR="$BASE_DIR/data"
LOG_DIR="$BASE_DIR/log"
LOG_FILE="$LOG_DIR/download_log_$(date +%Y%m%d_%H%M%S).log"

# --- Functions ---
log_message() {
    local message="$1"
    echo "$(date +%Y-%m-%d\ %H:%M:%S) - $message" | tee -a "$LOG_FILE"
}

# --- Setup ---
mkdir -p "$LOG_DIR" "$DATA_DIR"

log_message "--- Script Start (Using NCBI datasets) ---"
log_message "Starting download of ${#ACCESSIONS[@]} genomes."
log_message "Target directory: $DATA_DIR"

# --- Main download loop ---
cd "$DATA_DIR" || { log_message "Error: Cannot change directory to $DATA_DIR"; exit 1; }

for ACCESSION_ID in "${ACCESSIONS[@]}"; do
    OUTPUT_FILE="${DATA_DIR}/${ACCESSION_ID}.fasta"
    OUTPUT_ZIP="${ACCESSION_ID}.zip"

    log_message "Processing: $ACCESSION_ID"

    if [ -s "$OUTPUT_FILE" ]; then
        log_message "  Skipping: Final FASTA already exists and is not empty."
        continue
    fi

    # --- Download ---
    log_message "  Attempting download using 'datasets'..."
    if ! datasets download genome accession "$ACCESSION_ID" --include genome --filename "$OUTPUT_ZIP" 2>> "$LOG_FILE"; then
        log_message "  CRITICAL ERROR: 'datasets' download failed for $ACCESSION_ID."
        rm -f "$OUTPUT_ZIP"
        continue
    fi

    if [ ! -s "$OUTPUT_ZIP" ]; then
        log_message "  ERROR: Download completed but $OUTPUT_ZIP is empty or missing."
        rm -f "$OUTPUT_ZIP"
        continue
    fi
    log_message "  SUCCESS: ZIP file downloaded."

    # --- Unzip and extract ---
    log_message "  Unzipping and extracting FASTA file..."
    if ! unzip -q "$OUTPUT_ZIP" 2>> "$LOG_FILE"; then
        log_message "  ERROR: Failed to unzip $OUTPUT_ZIP."
        rm -f "$OUTPUT_ZIP"
        continue
    fi

    FASTA_FILE_SOURCE=""
    find ncbi_dataset/data/ -type f -name "*.fna" -print0 2>/dev/null | while IFS= read -r -d $'\0' FILE_PATH; do
        if [ -n "$FILE_PATH" ]; then
            FASTA_FILE_SOURCE="$FILE_PATH"
            break
        fi
    done

    if [ -n "$FASTA_FILE_SOURCE" ]; then
        mv "$FASTA_FILE_SOURCE" "$OUTPUT_FILE" 2>> "$LOG_FILE"
        if [ -s "$OUTPUT_FILE" ]; then
            log_message "  SUCCESS: FASTA extracted and verified."
        else
            log_message "  ERROR: Final FASTA is empty after extraction."
            rm -f "$OUTPUT_FILE"
        fi
    else
        log_message "  ERROR: Could not find *.fna in unzipped archive."
    fi

    # --- Cleanup ---
    rm -f "$OUTPUT_ZIP"
    rm -rf "ncbi_dataset"
done

log_message "All genome downloads attempted."
log_message "--- Script End ---"
