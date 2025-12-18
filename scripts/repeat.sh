#!/bin/bash
set -euo pipefail

# =========================================================
# 0. Logging and Path Setup
# =========================================================
LOG_DIR="../log"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/repeat_analysis_${TIMESTAMP}.log"

mkdir -p "$LOG_DIR"
echo "--- $(date): Starting Repeat Analysis Pipeline ---" 1> "$LOG_FILE" 2>&1
echo "All output redirected to log file: $LOG_FILE" 1>&2
exec 1> "$LOG_FILE" 2>&1

# =========================================================
# 1. Configuration (Absolute Paths)
# =========================================================
PROJECT_ROOT=$(cd "${PWD}/.." && pwd)
DATA_DIR="$PROJECT_ROOT/data"
REPEAT_RESULTS_DIR="$PROJECT_ROOT/results/repeat_modeler"
THREADS=8

REF_FASTA="$DATA_DIR/GCA_002775205.2.fasta"
FASTA2="$DATA_DIR/GCA_001444195.3.fasta"
FASTA3="$DATA_DIR/GCA_036418095.1.fasta"

REF_BASENAME=$(basename "$REF_FASTA" .fasta)
DB_BASENAME="$REF_BASENAME"

LIBRARY_FA="families.fa"
LIBRARY_PATH="$REPEAT_RESULTS_DIR/$LIBRARY_FA"

mkdir -p "$REPEAT_RESULTS_DIR"

echo "Repeat analysis results will be stored in:"
echo "  $REPEAT_RESULTS_DIR"
echo "-----------------------------------"

# =========================================================
# 1.5 Prepare FASTA (sanitize headers)
# =========================================================
echo "### PREP: Sanitizing Reference FASTA Headers ###"

PREP_FASTA_FULL="$REPEAT_RESULTS_DIR/$REF_BASENAME.prep.fasta"

awk '/^>/{print ">seq_" ++i; next} {print}' \
    "$REF_FASTA" > "$PREP_FASTA_FULL"

if [ ! -s "$PREP_FASTA_FULL" ]; then
    echo "CRITICAL ERROR: Failed to create $PREP_FASTA_FULL"
    exit 1
fi

echo "Sanitized FASTA created:"
ls -lh "$PREP_FASTA_FULL"

# =========================================================
# 1.6 Safe cleanup
# =========================================================
echo "Cleaning old RepeatModeler and DB artifacts..."
# rm -rf "$REPEAT_RESULTS_DIR"/RM_* RM_*

# RepeatModeler DB artifacts (created by BuildDatabase)
# rm -f "$REPEAT_RESULTS_DIR/$DB_BASENAME".{nhr,nin,nsq,ndb,not,ntf,nto} 2>/dev/null || true
# rm -f "$REPEAT_RESULTS_DIR/$DB_BASENAME".translation 2>/dev/null || true
# rm -f "$REPEAT_RESULTS_DIR/$DB_BASENAME".{ref,idx} 2>/dev/null || true

echo "-----------------------------------"

# =========================================================
# 2. Run RepeatModeler (using BuildDatabase)
# =========================================================
echo "### STEP 1: Running RepeatModeler ###"

cd "$REPEAT_RESULTS_DIR"

if [ ! -f "${DB_BASENAME}.nin" ]; then
    echo "Building RepeatModeler database (BuildDatabase)..."
    time BuildDatabase -name "$DB_BASENAME" "$PREP_FASTA_FULL"
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
    echo "Repeat library already exists – skipping."
fi

if [ ! -s "$LIBRARY_FA" ]; then
    echo "ERROR: RepeatModeler failed (families.fa missing)"
    exit 1
fi

cd - > /dev/null

echo "Repeat library ready:"
ls -lh "$LIBRARY_PATH"

echo "-----------------------------------"

# =========================================================
# 3. Run RepeatMasker
# =========================================================
echo "### STEP 2: Running RepeatMasker ###"

FASTAS=("$REF_FASTA" "$FASTA2" "$FASTA3")

for FASTA_FILE in "${FASTAS[@]}"; do
    FILE_BASENAME=$(basename "$FASTA_FILE")
    MASKER_OUTPUT="$REPEAT_RESULTS_DIR/$FILE_BASENAME.out"

    if [ ! -f "$MASKER_OUTPUT" ]; then
        echo "Masking $FILE_BASENAME..."
        time RepeatMasker \
            -pa "$THREADS" \
            -lib "$LIBRARY_PATH" \
            -dir "$REPEAT_RESULTS_DIR" \
            "$FASTA_FILE"
        rm -f "$REPEAT_RESULTS_DIR/$FILE_BASENAME.tbl"
    else
        echo "RepeatMasker output exists for $FILE_BASENAME – skipping."
    fi
done

echo "-----------------------------------"
echo "Repeat analysis pipeline COMPLETE"
echo "Results in: $REPEAT_RESULTS_DIR"
echo "--- $(date): Script End ---"
