#!/bin/bash

# --- Configuration ---
# Target GCA accession numbers
ACCESSIONS=("GCA_036418095.1" "GCA_002775205.2" "GCA_001444195.3")

# Directory settings
BASE_DIR="/home/co_ryota/outgroup"
TARGET_DATA_DIR="$BASE_DIR/data"
TARGET_LOG_DIR="$BASE_DIR/log"
LOG_FILE="$TARGET_LOG_DIR/download_log_$(date +%Y%m%d_%H%M%S).log"

# --- Functions ---

# Log function (timestamped message to console and log file)
log_message() {
    local message="$1"
    echo "$(date +%Y-%m-%d\ %H:%M:%S) - $message" | tee -a "$LOG_FILE"
}

# --- Execution Start ---

# 1. Setup Directories
if [ ! -d "$TARGET_LOG_DIR" ]; then
    mkdir -p "$TARGET_LOG_DIR"
fi
if [ ! -d "$TARGET_DATA_DIR" ]; then
    mkdir -p "$TARGET_DATA_DIR"
fi

log_message "--- Script Start (Using NCBI datasets) ---"
log_message "Starting download of ${#ACCESSIONS[@]} genomes."
log_message "Target directory: $TARGET_DATA_DIR"
log_message "------------------------------------------"

# 2. Main Download Loop
cd "$TARGET_DATA_DIR" || { log_message "Error: Cannot change directory to $TARGET_DATA_DIR"; exit 1; }

for ACCESSION_ID in "${ACCESSIONS[@]}"; do
    
    # Final FASTA file name
    OUTPUT_FILE="${TARGET_DATA_DIR}/${ACCESSION_ID}.fasta"
    OUTPUT_ZIP="${ACCESSION_ID}.zip"

    log_message "Processing: $ACCESSION_ID"

    # Check for existing final file
    if [ -s "$OUTPUT_FILE" ]; then
        log_message "  Skipping: Final FASTA file already exists and is not empty."
        continue
    fi
    
    # --- Download ---
    log_message "  Attempting download of ZIP file using 'datasets'..."
    
    # Run datasets download. Errors redirected to log.
    if ! datasets download genome accession "$ACCESSION_ID" --include genome --filename "$OUTPUT_ZIP" 2>> "$LOG_FILE"; then
        log_message "  CRITICAL ERROR: 'datasets' download failed for $ACCESSION_ID. Check installation/network."
        rm -f "$OUTPUT_ZIP"
        continue
    fi

    # Verify downloaded ZIP file
    if [ ! -s "$OUTPUT_ZIP" ]; then
        log_message "  ERROR: Download completed but $OUTPUT_ZIP is empty or missing."
        rm -f "$OUTPUT_ZIP"
        continue
    fi
    log_message "  SUCCESS: ZIP file downloaded."
    
    # --- Unzip and Extract ---
    
    # Unzip the file
    log_message "  Unzipping and extracting FASTA file..."
    if ! unzip -q "$OUTPUT_ZIP" 2>> "$LOG_FILE"; then
        log_message "  ERROR: Failed to unzip $OUTPUT_ZIP."
        rm -f "$OUTPUT_ZIP"
        continue
    fi
    
    # Find the FASTA file(s). Use 'print0' and 'read -d ""' to safely handle spaces/newlines in filenames.
    FASTA_FILE_SOURCE=""
    
    # Use find to search for *.fna files and pipe the result safely
    find ncbi_dataset/data/ -type f -name "*.fna" -print0 2>/dev/null | while IFS= read -r -d $'\0' FILE_PATH; do
        if [ -n "$FILE_PATH" ]; then
            FASTA_FILE_SOURCE="$FILE_PATH"
            break # Use the first file found
        fi
    done

    if [ -n "$FASTA_FILE_SOURCE" ]; then
        mv "$FASTA_FILE_SOURCE" "$OUTPUT_FILE" 2>> "$LOG_FILE"
        
        # Final file check
	if [ -s "$OUTPUT_FILE" ]; then
            log_message "  SUCCESS: FASTA file extracted and verified."
        else
            log_message "  ERROR: Final FASTA file is empty after extraction."
            rm -f "$OUTPUT_FILE"
        fi
    else
        log_message "  ERROR: Could not find FASTA file (*.fna) in unzipped archive."
    fi
    
    # --- Cleanup ---
    rm -f "$OUTPUT_ZIP"
    rm -rf "ncbi_dataset"
    
done

log_message "------------------------------------------"
log_message "All genome downloads attempted."
log_message "--- Script End ---"
