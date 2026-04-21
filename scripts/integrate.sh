#!/bin/bash
# ==============================================================================
# Purpose:      Identify shared/unique insertion patterns across 3 masked genomes
# Usage:        bash integrate.sh <masked_A> <masked_B> <masked_C> [<maf_dir>] [<suffix>]
# Example:      bash integrate.sh GCA_003550325.1.fasta.masked \
#                   GCA_009809945.1.fasta.masked GCA_910591775.1.fasta.masked \
#                   results/last_alignment_rosea_ref _rosea_ref
# Dependencies: python3, samtools, bedtools, extract_gaps.py
# ==============================================================================
set -euo pipefail

# --- Argument handling ---
usage() {
    echo "Usage: $0 <masked_A> <masked_B> <masked_C> [<maf_dir>] [<suffix>]" >&2
    echo "  maf_dir : directory containing seq1_seq2_seq3_joined.maf (default: results/last_alignment)" >&2
    echo "  suffix  : appended to output dir names, e.g. _rosea_ref (default: empty)" >&2
    exit 1
}
[ $# -lt 3 ] && usage

# --- Path resolution ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_DIR="$BASE_DIR/results"

# Optional args
MAF_DIR="${4:-$RESULTS_DIR/last_alignment}"
SUFFIX="${5:-}"
MAF_FILE="$MAF_DIR/seq1_seq2_seq3_joined.maf"

# Derive base names for RepeatMasker BED lookup (strip .fasta.masked or .masked)
GA_BASE="${1%.fasta.masked}"; GA_BASE="${GA_BASE%.masked}"
GB_BASE="${2%.fasta.masked}"; GB_BASE="${GB_BASE%.masked}"
GC_BASE="${3%.fasta.masked}"; GC_BASE="${GC_BASE%.masked}"
BED_A="$RESULTS_DIR/${GA_BASE}.bed"
BED_B="$RESULTS_DIR/${GB_BASE}.bed"
BED_C="$RESULTS_DIR/${GC_BASE}.bed"

# --- Resolve masked genome paths (filenames relative to results/) ---
GA="$RESULTS_DIR/$1"
GB="$RESULTS_DIR/$2"
GC="$RESULTS_DIR/$3"

# --- Validate inputs ---
for f in "$GA" "$GB" "$GC" "$MAF_FILE"; do
    if [ ! -f "$f" ]; then
        echo "ERROR: Required file not found: $f" >&2
        exit 1
    fi
done
for f in "$BED_A" "$BED_B" "$BED_C"; do
    if [ ! -f "$f" ]; then
        echo "WARNING: RepeatMasker BED not found, RM filter will be skipped: $f" >&2
    fi
done

# --- Sanitize headers and index ---
echo "--- Sanitizing and indexing masked genomes ---"
for g in "$GA" "$GB" "$GC"; do
    echo "Sanitizing $(basename "$g")..."
    sed -i 's/^>\([^[:space:]]*\).*/>\1/' "$g"
    samtools faidx "$g"
done

# --- Run analysis at each length threshold ---
run_analysis() {
    local len=$1
    local OUT_DIR="$RESULTS_DIR/candidate_insertions_${len}bp${SUFFIX}"
    mkdir -p "$OUT_DIR"

    echo "# --- Running analysis for ${len}bp threshold (suffix='${SUFFIX}') ---"
    python3 "$SCRIPT_DIR/extract_gaps.py" "$MAF_FILE" "$len" "$GA" "$GB" "$GC" "$OUT_DIR"

    # --- RepeatMasker BED filter (both carrier species must overlap a TE at >=50%) ---
    # pattern_ref maps each pattern to (primary_bed, secondary_bed)
    declare -A PRI_BED SEC_BED
    PRI_BED=( [AB_shared]="$BED_A" [AC_shared]="$BED_A" [A_only]="$BED_A"
              [BC_shared]="$BED_B" [B_only]="$BED_B"
              [C_only]="$BED_C" )
    SEC_BED=( [AB_shared]="$BED_B" [AC_shared]="$BED_C" [BC_shared]="$BED_C" )

    for p in AB_shared AC_shared BC_shared A_only B_only C_only; do
        RAW_BED="$OUT_DIR/pattern_${p}_${len}bp.bed"
        RAW_TSV="$OUT_DIR/pattern_${p}_${len}bp.tsv"
        RM_BED="$OUT_DIR/pattern_${p}_${len}bp_rm.bed"

        [ ! -s "$RAW_BED" ] && continue

        pri="${PRI_BED[$p]:-}"
        sec="${SEC_BED[$p]:-}"

        # Single-carrier patterns (A_only, B_only, C_only): filter primary only
        if [ -z "$sec" ]; then
            if [ -f "$pri" ]; then
                bedtools coverage -a "$RAW_BED" -b "$pri" \
                    | awk '$NF >= 0.50 {print $1"\t"$2"\t"$3"\t"$4}' > "$RM_BED"
            else
                cp "$RAW_BED" "$RM_BED"
            fi
            continue
        fi

        # Shared patterns: require BOTH primary and secondary to pass RM filter
        if [ -f "$pri" ] && [ -f "$sec" ]; then
            # Primary: annotate each row with its line number + rm_cov_pri
            bedtools coverage -a "$RAW_BED" -b "$pri" \
                | awk '{print NR"\t"$1"\t"$2"\t"$3"\t"$4"\t"$NF}' > "${RM_BED}.pri_tmp"

            # Secondary coordinates come from cols 5-7 of the TSV
            if [ -s "$RAW_TSV" ]; then
                awk 'NR>1{print $5"\t"$6"\t"$7"\t"$4}' "$RAW_TSV" > "${RM_BED}.sec_coords.tmp"
                bedtools coverage -a "${RM_BED}.sec_coords.tmp" -b "$sec" \
                    | awk '{print NR"\t"$NF}' > "${RM_BED}.sec_tmp"

                # Join on row number; keep rows where BOTH >= 0.50
                join -1 1 -2 1 "${RM_BED}.pri_tmp" "${RM_BED}.sec_tmp" \
                    | awk '$6 >= 0.50 && $7 >= 0.50 {print $2"\t"$3"\t"$4"\t"$5}' > "$RM_BED"
                rm -f "${RM_BED}.sec_coords.tmp" "${RM_BED}.sec_tmp"
            else
                # No TSV yet (e.g. first run without extended output): fall back to primary only
                awk '$6 >= 0.50 {print $2"\t"$3"\t"$4"\t"$5}' "${RM_BED}.pri_tmp" > "$RM_BED"
            fi
            rm -f "${RM_BED}.pri_tmp"
        else
            cp "$RAW_BED" "$RM_BED"
        fi
    done

    # --- Extract FASTA sequences (from raw gaps and RM-filtered gaps) ---

    # Patterns originating from Genome A
    for p in A_only AB_shared AC_shared; do
        BED="$OUT_DIR/pattern_${p}_${len}bp.bed"
        [ -s "$BED" ] && bedtools getfasta -fi "$GA" -bed "$BED" -fo "$OUT_DIR/${p}.fasta"
        RM_BED="$OUT_DIR/pattern_${p}_${len}bp_rm.bed"
        [ -s "$RM_BED" ] && bedtools getfasta -fi "$GA" -bed "$RM_BED" -fo "$OUT_DIR/${p}_rm.fasta"
    done

    # Patterns originating from Genome B
    for p in B_only BC_shared; do
        BED="$OUT_DIR/pattern_${p}_${len}bp.bed"
        [ -s "$BED" ] && bedtools getfasta -fi "$GB" -bed "$BED" -fo "$OUT_DIR/${p}.fasta"
        RM_BED="$OUT_DIR/pattern_${p}_${len}bp_rm.bed"
        [ -s "$RM_BED" ] && bedtools getfasta -fi "$GB" -bed "$RM_BED" -fo "$OUT_DIR/${p}_rm.fasta"
    done

    # Patterns originating from Genome C
    BED="$OUT_DIR/pattern_C_only_${len}bp.bed"
    [ -s "$BED" ] && bedtools getfasta -fi "$GC" -bed "$BED" -fo "$OUT_DIR/C_only.fasta"
    RM_BED="$OUT_DIR/pattern_C_only_${len}bp_rm.bed"
    [ -s "$RM_BED" ] && bedtools getfasta -fi "$GC" -bed "$RM_BED" -fo "$OUT_DIR/C_only_rm.fasta"

    echo "Results written to: $OUT_DIR"
}

run_analysis 50
run_analysis 100

echo "--- All analyses complete ---"
