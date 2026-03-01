#!/bin/bash
# ==============================================================================
# Purpose:      Summarize insertion pattern counts and determine outgroup verdict
# Usage:        bash report.sh
# Example:      bash report.sh
# Dependencies: awk, grep
# ==============================================================================
set -euo pipefail

# --- Path resolution ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_DIR="$BASE_DIR/results"
LOG_DIR="$BASE_DIR/log"
LOG_FILE="$LOG_DIR/final_outgroup_report.log"

mkdir -p "$LOG_DIR"

{
    echo "======================================================"
    echo "       PHYLOGENOMIC OUTGROUP VERIFICATION REPORT      "
    echo "       Generated: $(date)"
    echo "======================================================"
    echo ""

    # --- 1. Summary table: signal stability 50bp to 100bp ---
    echo "--- 1. SUMMARY TABLE: SIGNAL STABILITY (50bp to 100bp) ---"
    printf "%-15s %-10s %-10s %-10s\n" "Pattern" "50bp" "100bp" "% Survival"
    echo "------------------------------------------------------"
    for p in AB_shared AC_shared BC_shared A_only B_only C_only; do
        f50="$RESULTS_DIR/candidate_insertions_50bp/${p}.fasta"
        [ ! -f "$f50" ] && f50="$RESULTS_DIR/candidate_insertions_50bp/${p}_markers.fasta"

        f100="$RESULTS_DIR/candidate_insertions_100bp/${p}.fasta"
        [ ! -f "$f100" ] && f100="$RESULTS_DIR/candidate_insertions_100bp/${p}_markers.fasta"

        c50=$(grep -c ">" "$f50" 2>/dev/null || echo 0)
        c100=$(grep -c ">" "$f100" 2>/dev/null || echo 0)

        perc="0.0%"
        if [ "$c50" -gt 0 ]; then
            perc=$(awk "BEGIN {printf \"%.1f%%\", ($c100/$c50)*100}")
        fi
        printf "%-15s %-10s %-10s %-10s\n" "$p" "$c50" "$c100" "$perc"
    done

    echo ""

    # --- 2. High-stringency filter (>= 120bp) ---
    echo "--- 2. HIGH-STRINGENCY FILTER (>= 120bp) ---"
    echo "Focusing on full-length retrotransposon signatures:"
    printf "%-15s %-10s\n" "Pattern" "Count"
    echo "---------------------------"
    for f in "$RESULTS_DIR/candidate_insertions_100bp"/*.fasta; do
        name=$(basename "$f" .fasta)
        count=$(awk '/^>/ {if (seqlen >= 120) count++; seqlen=0; next} {seqlen += length($0)} END {if (seqlen >= 120) count++; print count}' "$f")
        printf "%-15s %-10s\n" "$name" "$count"
    done

    echo ""

    # --- 3. Top 3 longest markers per category ---
    echo "--- 3. TOP 3 LONGEST MARKERS PER CATEGORY ---"
    for f in "$RESULTS_DIR/candidate_insertions_100bp"/*.fasta; do
        echo "[$f]"
        awk '/^>/ {if (seqlen) print seqlen; printf "%s: ", $0; seqlen=0; next} {seqlen += length($0)} END {print seqlen}' "$f" | sort -k2 -rn | head -n 3
    done

    echo ""
    echo "======================================================"
    echo "                  OUTGROUP VERDICT                    "
    echo "======================================================"
    echo "Hypothesis based on Max Shared Insertions (Synapomorphies):"
    DIR100="$RESULTS_DIR/candidate_insertions_100bp"
    echo "  * A+C Sisters (B Outgroup): $(awk '/^>/ {if (seqlen >= 120) count++; seqlen=0; next} {seqlen += length($0)} END {if (seqlen >= 120) count++; print count}' "$DIR100/AC_shared.fasta")"
    echo "  * A+B Sisters (C Outgroup): $(awk '/^>/ {if (seqlen >= 120) count++; seqlen=0; next} {seqlen += length($0)} END {if (seqlen >= 120) count++; print count}' "$DIR100/AB_shared.fasta")"
    echo "  * B+C Sisters (A Outgroup): $(awk '/^>/ {if (seqlen >= 120) count++; seqlen=0; next} {seqlen += length($0)} END {if (seqlen >= 120) count++; print count}' "$DIR100/BC_shared.fasta")"

} | tee "$LOG_FILE"

echo ""
echo "Report saved to: $LOG_FILE"
