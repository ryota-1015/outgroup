#!/bin/bash
# ==============================================================================
# Purpose:      Summarize insertion pattern counts and determine outgroup verdict
# Usage:        bash report.sh [<suffix>]
# Example:      bash report.sh _rosea_ref
# Dependencies: awk, grep
# ==============================================================================
set -euo pipefail

# --- Argument handling ---
SUFFIX="${1:-}"

# --- Path resolution ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_DIR="$BASE_DIR/results"
LOG_DIR="$BASE_DIR/log"
LOG_FILE="$LOG_DIR/final_outgroup_report${SUFFIX}.log"

mkdir -p "$LOG_DIR"

count_fasta() {
    local f="$1"
    grep -c ">" "$f" 2>/dev/null || echo 0
}

count_fasta_min_len() {
    local f="$1" minlen="$2"
    [ ! -f "$f" ] && { echo 0; return; }
    awk -v ml="$minlen" '/^>/ {if (seqlen >= ml) c++; seqlen=0; next}
                          {seqlen += length($0)}
                    END   {if (seqlen >= ml) c++; print c+0}' "$f"
}

{
    echo "======================================================"
    echo "       PHYLOGENOMIC OUTGROUP VERIFICATION REPORT"
    echo "       Suffix: '${SUFFIX}'"
    echo "       Generated: $(date)"
    echo "======================================================"
    echo ""

    DIR50="$RESULTS_DIR/candidate_insertions_50bp${SUFFIX}"
    DIR100="$RESULTS_DIR/candidate_insertions_100bp${SUFFIX}"

    # --- 1. Raw gap counts: signal stability 50bp → 100bp ---
    echo "--- 1. RAW GAP COUNTS (50bp vs 100bp, no TE filter) ---"
    printf "%-15s %-8s %-8s %-10s\n" "Pattern" "50bp" "100bp" "% Survival"
    echo "------------------------------------------------------"
    for p in AB_shared AC_shared BC_shared A_only B_only C_only; do
        f50="$DIR50/${p}.fasta"
        f100="$DIR100/${p}.fasta"
        c50=$(count_fasta "$f50")
        c100=$(count_fasta "$f100")
        perc="0.0%"
        [ "$c50" -gt 0 ] && perc=$(awk "BEGIN {printf \"%.1f%%\", ($c100/$c50)*100}")
        printf "%-15s %-8s %-8s %-10s\n" "$p" "$c50" "$c100" "$perc"
    done
    echo ""

    # --- 2. RM-filtered counts ---
    echo "--- 2. REPEATMASKER-FILTERED COUNTS (>=50% gap covered by TE annotation) ---"
    printf "%-15s %-8s %-8s %-10s\n" "Pattern" "50bp" "100bp" "% of raw"
    echo "------------------------------------------------------"
    for p in AB_shared AC_shared BC_shared A_only B_only C_only; do
        f50="$DIR50/${p}_rm.fasta"
        f100="$DIR100/${p}_rm.fasta"
        raw100=$(count_fasta "$DIR100/${p}.fasta")
        c50=$(count_fasta "$f50")
        c100=$(count_fasta "$f100")
        perc="0.0%"
        [ "$raw100" -gt 0 ] && perc=$(awk "BEGIN {printf \"%.1f%%\", ($c100/$raw100)*100}")
        printf "%-15s %-8s %-8s %-10s\n" "$p" "$c50" "$c100" "$perc"
    done
    echo ""

    # --- 3. High-stringency filter (>= 120bp) on raw gaps ---
    echo "--- 3. HIGH-STRINGENCY FILTER (>=120bp, raw gaps) ---"
    printf "%-15s %-10s\n" "Pattern" "Count"
    echo "---------------------------"
    for p in AB_shared AC_shared BC_shared A_only B_only C_only; do
        f="$DIR100/${p}.fasta"
        count=$(count_fasta_min_len "$f" 120)
        printf "%-15s %-10s\n" "$p" "$count"
    done
    echo ""

    # --- 4. High-stringency filter (>= 120bp) on RM-filtered gaps ---
    echo "--- 4. HIGH-STRINGENCY FILTER (>=120bp, RM-filtered) ---"
    printf "%-15s %-10s\n" "Pattern" "Count"
    echo "---------------------------"
    for p in AB_shared AC_shared BC_shared A_only B_only C_only; do
        f="$DIR100/${p}_rm.fasta"
        count=$(count_fasta_min_len "$f" 120)
        printf "%-15s %-10s\n" "$p" "$count"
    done
    echo ""

    # --- 5. TSD-confirmed counts (if find_tsds.py has been run) ---
    TSD_SUMMARY="$LOG_DIR/tsd_summary${SUFFIX}.tsv"
    if [ -f "$TSD_SUMMARY" ]; then
        echo "--- 5. TSD-CONFIRMED COUNTS ---"
        cat "$TSD_SUMMARY"
        echo ""
    fi

    # --- 6. Outgroup verdict (raw >=120bp) ---
    echo "======================================================"
    echo "                  OUTGROUP VERDICT (raw >=120bp)"
    echo "======================================================"
    ab=$(count_fasta_min_len "$DIR100/AB_shared.fasta" 120)
    ac=$(count_fasta_min_len "$DIR100/AC_shared.fasta" 120)
    bc=$(count_fasta_min_len "$DIR100/BC_shared.fasta" 120)
    echo "  A+B sisters (C outgroup): $ab"
    echo "  A+C sisters (B outgroup): $ac"
    echo "  B+C sisters (A outgroup): $bc"
    echo ""

    # --- 7. Outgroup verdict (RM-filtered >=120bp) ---
    echo "======================================================"
    echo "              OUTGROUP VERDICT (RM-filtered >=120bp)"
    echo "======================================================"
    ab_rm=$(count_fasta_min_len "$DIR100/AB_shared_rm.fasta" 120)
    ac_rm=$(count_fasta_min_len "$DIR100/AC_shared_rm.fasta" 120)
    bc_rm=$(count_fasta_min_len "$DIR100/BC_shared_rm.fasta" 120)
    echo "  A+B sisters (C outgroup): $ab_rm"
    echo "  A+C sisters (B outgroup): $ac_rm"
    echo "  B+C sisters (A outgroup): $bc_rm"

} | tee "$LOG_FILE"

echo ""
echo "Report saved to: $LOG_FILE"
