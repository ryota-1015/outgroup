#!/bin/bash
# ==============================================================================
# Purpose:      Align three genomes using LAST (lastdb, last-train, lastal, last-split, maf-join)
# Usage:        bash align.sh <seq1_fasta> <seq2_fasta> <seq3_fasta>
# Example:      bash align.sh GCA_009914755.4.fasta GCA_028858775.2.fasta GCA_028885655.2.fasta
# Dependencies: lastdb, last-train, lastal, last-split, maf-sort, maf-join
# ==============================================================================
set -euo pipefail

# --- Argument handling ---
usage() {
    echo "Usage: $0 <seq1_fasta> <seq2_fasta> <seq3_fasta>" >&2
    echo "Example: $0 GCA_009914755.4.fasta GCA_028858775.2.fasta GCA_028885655.2.fasta" >&2
    exit 1
}
[ $# -ne 3 ] && usage

# --- Path resolution ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DATA_DIR="$BASE_DIR/data"
RESULTS_DIR="$BASE_DIR/results/last_alignment"
LOG_DIR="$BASE_DIR/log"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/last_align_${TIMESTAMP}.log"

# --- Resolve input paths ---
seq1FASTA=$(readlink -f "$DATA_DIR/$1")
seq2FASTA=$(readlink -f "$DATA_DIR/$2")
seq3FASTA=$(readlink -f "$DATA_DIR/$3")

if [ ! -f "$seq1FASTA" ] || [ ! -f "$seq2FASTA" ] || [ ! -f "$seq3FASTA" ]; then
    echo "Error: One or more input FASTA files not found in $DATA_DIR." >&2
    exit 1
fi

# --- Logging setup ---
mkdir -p "$LOG_DIR" "$RESULTS_DIR"
exec 1> "$LOG_FILE" 2>&1

echo "--- LAST Alignment Pipeline Start: $(date) ---"
echo "Seq1 (ref): $seq1FASTA"
echo "Seq2:       $seq2FASTA"
echo "Seq3:       $seq3FASTA"
echo "Log file:   $LOG_FILE"
echo "Results:    $RESULTS_DIR"

# --- Configuration ---
DB_NAME="seq1_db"
THREADS=8

# --- Step 1: Build LAST database ---
run_lastdb() {
    echo "# --- Step 1: Building LAST database for Seq1 ---"
    local DB_DIR="$RESULTS_DIR/$DB_NAME"
    if [ ! -d "$DB_DIR" ]; then
        mkdir -p "$DB_DIR"
        echo "time lastdb -P$THREADS -c -uRY4 $DB_DIR/$DB_NAME $seq1FASTA"
        time lastdb -P$THREADS -c -uRY4 "$DB_DIR/$DB_NAME" "$seq1FASTA"
    else
        echo "Database $DB_NAME already exists. Skipping lastdb."
    fi
}

# --- Step 2-4: Pairwise alignment for a single query ---
run_pairwise_alignment() {
    local seqXFASTA=$1
    local tag=$2
    local DB_DIR="$RESULTS_DIR/$DB_NAME"
    local trainFile="$RESULTS_DIR/$tag.mat"
    local m2omaf="$RESULTS_DIR/$tag.m2o.maf"
    local o2omaf="$RESULTS_DIR/$tag.o2o.maf"

    echo "# --- Steps 2-4: Pairwise alignment: $tag ---"

    if [ ! -e "$trainFile" ]; then
        echo "time last-train -P$THREADS --revsym -C2 $DB_DIR/$DB_NAME $seqXFASTA >$trainFile"
        time last-train -P$THREADS --revsym -C2 "$DB_DIR/$DB_NAME" "$seqXFASTA" > "$trainFile"
    else
        echo "$trainFile already exists. Skipping last-train."
    fi

    if [ ! -e "$m2omaf" ]; then
        echo "time lastal -P$THREADS -H1 -C2 --split-f=MAF+ -p $trainFile $DB_DIR/$DB_NAME $seqXFASTA >$m2omaf"
        time lastal -P$THREADS -H1 -C2 --split-f=MAF+ -p "$trainFile" "$DB_DIR/$DB_NAME" "$seqXFASTA" > "$m2omaf"
    else
        echo "$m2omaf already exists. Skipping lastal."
    fi

    if [ ! -e "$o2omaf" ]; then
        echo "time last-split -r $m2omaf >$o2omaf"
        time last-split -r "$m2omaf" > "$o2omaf"
    else
        echo "$o2omaf already exists. Skipping last-split."
    fi
}

# --- Step 5: MAF join ---
run_maf_join() {
    local o2omaf12="$RESULTS_DIR/seq1_seq2.o2o.maf"
    local o2omaf13="$RESULTS_DIR/seq1_seq3.o2o.maf"
    local sorted12="${o2omaf12}.sorted"
    local sorted13="${o2omaf13}.sorted"
    local joinedFile="$RESULTS_DIR/seq1_seq2_seq3_joined.maf"

    echo "# --- Step 5: MAF join ---"

    if [ ! -e "$sorted12" ]; then
        echo "time maf-sort $o2omaf12 >$sorted12"
        time maf-sort "$o2omaf12" > "$sorted12"
    else
        echo "$sorted12 already exists. Skipping sort."
    fi

    if [ ! -e "$sorted13" ]; then
        echo "time maf-sort $o2omaf13 >$sorted13"
        time maf-sort "$o2omaf13" > "$sorted13"
    else
        echo "$sorted13 already exists. Skipping sort."
    fi

    if [ ! -e "$joinedFile" ]; then
        echo "time maf-join $sorted12 $sorted13 >$joinedFile"
        time maf-join "$sorted12" "$sorted13" > "$joinedFile"
    else
        echo "$joinedFile already exists. Skipping join."
    fi

    echo "Pipeline complete. Final MAF: $joinedFile"
}

# --- Main execution ---
run_lastdb
run_pairwise_alignment "$seq2FASTA" "seq1_seq2"
run_pairwise_alignment "$seq3FASTA" "seq1_seq3"
run_maf_join

echo "--- Script End: $(date) ---"
