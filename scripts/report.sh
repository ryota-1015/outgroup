#!/bin/bash
set -euo pipefail

LOG_FILE="../log/final_outgroup_report.log"
mkdir -p ../log

{
    echo "======================================================"
    echo "       PHYLOGENOMIC OUTGROUP VERIFICATION REPORT      "
    echo "       Generated: $(date)"
    echo "======================================================"
    echo ""

    echo "--- 1. SUMMARY TABLE: SIGNAL STABILITY (50bp to 100bp) ---"
    printf "%-15s %-10s %-10s %-10s\n" "Pattern" "50bp" "100bp" "% Survival"
    echo "------------------------------------------------------"
    for p in AB_shared AC_shared BC_shared A_only B_only C_only; do
        f50="../results/candidate_insertions_50bp/${p}.fasta"
        [ ! -f "$f50" ] && f50="../results/candidate_insertions_50bp/${p}_markers.fasta"
        
        f100="../results/candidate_insertions_100bp/${p}.fasta"
        [ ! -f "$f100" ] && f100="../results/candidate_insertions_100bp/${p}_markers.fasta"

        c50=$(grep -c ">" "$f50" 2>/dev/null || echo 0)
        c100=$(grep -c ">" "$f100" 2>/dev/null || echo 0)
        
        perc="0.0%"
        if [ "$c50" -gt 0 ]; then
            perc=$(awk "BEGIN {pc=($c100/$c50)*100; printf \"%.1f%%\", pc}")
        fi
        printf "%-15s %-10s %-10s %-10s\n" "$p" "$c50" "$c100" "$perc"
    done

    echo ""
    echo "--- 2. HIGH-STRINGENCY FILTER (>= 120bp) ---"
    echo "Focusing on full-length retrotransposon signatures:"
    printf "%-15s %-10s\n" "Pattern" "Count"
    echo "---------------------------"
    for f in ../results/candidate_insertions_100bp/*.fasta; do
        name=$(basename "$f" .fasta)
        count=$(awk '/^>/ {if (seqlen >= 120) count++; seqlen=0; next} {seqlen += length($0)} END {if (seqlen >= 120) count++; print count}' "$f")
        printf "%-15s %-10s\n" "$name" "$count"
    done

    echo ""
    echo "--- 3. TOP 3 LONGEST MARKERS PER CATEGORY ---"
    for f in ../results/candidate_insertions_100bp/*.fasta; do
        echo "[$f]"
        awk '/^>/ {if (seqlen) print seqlen; printf "%s: ", $0; seqlen=0; next} {seqlen += length($0)} END {print seqlen}' "$f" | sort -k2 -rn | head -n 3
    done

    echo ""
    echo "======================================================"
    echo "                  OUTGROUP VERDICT                    "
    echo "======================================================"
    echo "Hypothesis based on Max Shared Insertions (Synapomorphies):"
    echo "  * A+C Sisters (B Outgroup) Count: $(awk '/^>/ {if (seqlen >= 120) count++; seqlen=0; next} {seqlen += length($0)} END {if (seqlen >= 120) count++; print count}' ../results/candidate_insertions_100bp/AC_shared.fasta)"
    echo "  * A+B Sisters (C Outgroup) Count: $(awk '/^>/ {if (seqlen >= 120) count++; seqlen=0; next} {seqlen += length($0)} END {if (seqlen >= 120) count++; print count}' ../results/candidate_insertions_100bp/AB_shared.fasta)"
    echo "  * B+C Sisters (A Outgroup) Count: $(awk '/^>/ {if (seqlen >= 120) count++; seqlen=0; next} {seqlen += length($0)} END {if (seqlen >= 120) count++; print count}' ../results/candidate_insertions_100bp/BC_shared.fasta)"

} | tee "$LOG_FILE"

echo ""
echo "Report saved to: $LOG_FILE"