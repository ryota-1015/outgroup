#!/bin/bash

# --- Configuration and Argument Handling ---
# Script requires 3 arguments: the three FASTA filenames (without path)
if [ $# -ne 3 ]; then
    echo "Error: You must provide 3 FASTA filenames." 1>&2
    echo "Usage: $0 <Seq1_Ref_Filename> <Seq2_Filename> <Seq3_Filename>" 1>&2
    echo "Example: $0 GCA_002775205.2.fasta GCA_001444195.3.fasta GCA_036418095.1.fasta" 1>&2
    exit 1
fi

# 1. Define Paths and File Names (Relative to the script's location: ~/outgroup/scripts/)
# The script determines the absolute paths for input, output, and logging from here.
DATA_DIR="../data" 
LOG_DIR="../log"
RESULTS_DIR="../results/last_alignment"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 2. Construct Full Input Paths from filenames provided as arguments
# We use 'readlink -f' to get the absolute path, which is safer for programs like LAST.
# If 'readlink' is unavailable, simple path joining ($DATA_DIR/$1) is an alternative.
seq1FASTA=$(readlink -f $DATA_DIR/$1) # Reference sequence
seq2FASTA=$(readlink -f $DATA_DIR/$2) # Query sequence 1
seq3FASTA=$(readlink -f $DATA_DIR/$3) # Query sequence 2

# Check if input files exist (critical check)
if [ ! -f "$seq1FASTA" ] || [ ! -f "$seq2FASTA" ] || [ ! -f "$seq3FASTA" ]; then
    echo "Error: One or more input FASTA files not found in $DATA_DIR." 1>&2
    exit 1
fi

# 3. Logging Setup: Redirect all subsequent output to a log file
LOG_FILE="$LOG_DIR/last_align_${TIMESTAMP}.log"
mkdir -p "$LOG_DIR"
exec 1> "$LOG_FILE" 2>&1
# The 'exec 1> $LOG_FILE 2>&1' command redirects all subsequent stdout (1) and stderr (2)
# of this shell session to the log file.

echo "--- LAST Alignment Pipeline Start: $(date) ---"
echo "Input Ref (Seq1): $seq1FASTA"
echo "Log File: $LOG_FILE"
echo "Results Directory: $RESULTS_DIR"
echo "------------------------------------------------"

# Output and Resource Settings
outDirPath="$RESULTS_DIR" # Final results path
dbName="seq1_db" 
THREADS=8 

# Create output directory
mkdir -p $outDirPath
echo "LAST Alignment Pipeline Initialized."

# --- Function: LASTDB Execution (Step 1) ---
run_lastdb() {
    echo "### STEP 1: Building LAST Database for Seq1 ($seq1FASTA) ###"
    if [ ! -d $outDirPath/$dbName ]; then
        mkdir -p $outDirPath/$dbName
        echo "time lastdb -P$THREADS -c -uRY4 $outDirPath/$dbName/$dbName $seq1FASTA"
        time lastdb -P$THREADS -c -uRY4 $outDirPath/$dbName/$dbName $seq1FASTA
    else
        echo "Database $dbName already exists. Skipping lastdb."
    fi
}


# --- Function: Pairwise Alignment (Steps 2-4 for a single query) ---
run_pairwise_alignment() {
    local seqXFASTA=$1
    local tag=$2 # e.g., "seq1_seq2"
    local trainFile=$outDirPath/$tag.mat
    local m2omaf=$outDirPath/$tag.m2o.maf
    local o2omaf=$outDirPath/$tag.o2o.maf
    
    echo "### STEP 2-4: Pairwise Alignment: $tag (Seq1 vs $(basename $seqXFASTA)) ###"

    # 2. last-train
    if [ ! -e $trainFile ]; then
        echo "time last-train -P$THREADS --revsym -C2 $outDirPath/$dbName/$dbName $seqXFASTA >$trainFile"
        time last-train -P$THREADS --revsym -C2 $outDirPath/$dbName/$dbName $seqXFASTA >$trainFile
    else
        echo "$trainFile already exists. Skipping last-train."
    fi

    # 3. lastal
    if [ ! -e $m2omaf ]; then
        echo "time lastal -P$THREADS -H1 -C2 --split-f=MAF+ -p $trainFile $outDirPath/$dbName/$dbName $seqXFASTA >$m2omaf"
        time lastal -P$THREADS -H1 -C2 --split-f=MAF+ -p $trainFile $outDirPath/$dbName/$dbName $seqXFASTA >$m2omaf
    else
        echo "$m2omaf already exists. Skipping lastal."
    fi

    # 4. last-split
    if [ ! -e $o2omaf ]; then
        echo "time last-split -r $m2omaf >$o2omaf"
        time last-split -r $m2omaf >$o2omaf
    else
        echo "$o2omaf already exists. Skipping last-split."
    fi
}

# --- Function: MAF Join (Step 5) ---
run_maf_join() {
    local o2omaf12=$outDirPath/seq1_seq2.o2o.maf 
    local o2omaf13=$outDirPath/seq1_seq3.o2o.maf 
    local joinedFile=$outDirPath/seq1_seq2_seq3_joined.maf 
    
    local seq1_seq2_sorted="${o2omaf12}.sorted"
    local seq1_seq3_sorted="${o2omaf13}.sorted"

    echo "### STEP 5: MAF-JOIN: Combining Pairwise O2O MAFs into MSA ###"

    # 5a. maf-sort (Seq1 vs Seq2)
    if [ ! -e $seq1_seq2_sorted ]; then
        echo "time maf-sort $o2omaf12 >$seq1_seq2_sorted"
        time maf-sort $o2omaf12 >$seq1_seq2_sorted
    else
        echo "$seq1_seq2_sorted already exists. Skipping sort."
    fi
    
    # 5b. maf-sort (Seq1 vs Seq3)
    if [ ! -e $seq1_seq3_sorted ]; then
        echo "time maf-sort $o2omaf13 >$seq1_seq3_sorted"
        time maf-sort $o2omaf13 >$seq1_seq3_sorted
    else
        echo "$seq1_seq3_sorted already exists. Skipping sort."
    fi

    # 5c. maf-join: Merge alignments based on the common reference (Seq1)
    if [ ! -e $joinedFile ]; then
        echo "time maf-join $seq1_seq2_sorted $seq1_seq3_sorted >$joinedFile"
        time maf-join $seq1_seq2_sorted $seq1_seq3_sorted >$joinedFile
    else
        echo "$joinedFile already exists. Skipping join."
    fi
    
    echo "-----------------------------------"
    echo "Pipeline Complete. Final Multi-Sequence Alignment (MSA) file:"
    echo "$joinedFile"
}



# --- Main Execution Flow ---
run_lastdb

run_pairwise_alignment $seq2FASTA "seq1_seq2"
run_pairwise_alignment $seq3FASTA "seq1_seq3"

run_maf_join

echo "--- Script End: $(date) ---"