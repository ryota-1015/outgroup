#!/bin/bash
# ==============================================================================
# Purpose:      End-to-end outgroup pipeline driver for a single trio.
# Usage:        bash run_trio.sh <trio_name> [--dry-run] [--from <step>]
# Example:      bash run_trio.sh Denhet1_Gigros2_Gigmar3
#               bash run_trio.sh Denhet1_Gigros2_Gigmar3 --dry-run
#               bash run_trio.sh Denhet1_Gigros2_Gigmar3 --from align
#
# The trio name must exist in data/trios.tsv with three resolved accessions.
# Outputs are isolated by suffix _<trio_name> on:
#   results/last_alignment_<trio>/                  (post-renamed after align.sh)
#   results/candidate_insertions_{50,100}bp_<trio>/
#   log/final_outgroup_report_<trio>.log
#   log/tsd_summary_<trio>.tsv
#
# Underlying pipeline scripts are not modified. align.sh writes to its
# hardcoded results/last_alignment/ — this wrapper renames the directory after
# align.sh finishes, mirroring how the AMF baseline rosea/margarita runs were
# managed.
#
# Resource discipline (tasks/lessons.md): launch this inside tmux for any
# real run; RepeatModeler stages are sequential, not parallel.
# ==============================================================================
set -euo pipefail

usage() {
    cat >&2 <<EOF
Usage: $0 <trio_name> [--dry-run] [--from <step>]

  <trio_name>   row key in data/trios.tsv (e.g., Denhet1_Gigros2_Gigmar3)
  --dry-run     print the resolved command sequence and exit
  --from STEP   skip steps before STEP. STEP in:
                  download | repeat_modeler | mask | bed | align |
                  rename_align | integrate | tsd | report
EOF
    exit 1
}

# --- Argument parsing ---
TRIO=""
DRY_RUN=0
START_STEP="download"
ALL_STEPS=(download repeat_modeler mask bed align rename_align integrate tsd report)

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --from)    [ $# -ge 2 ] || usage; START_STEP="$2"; shift 2 ;;
        -h|--help) usage ;;
        --*)       echo "Unknown flag: $1" >&2; usage ;;
        *)         [ -z "$TRIO" ] || usage; TRIO="$1"; shift ;;
    esac
done
[ -n "$TRIO" ] || usage

# Validate START_STEP
step_valid=0
for s in "${ALL_STEPS[@]}"; do
    [ "$s" = "$START_STEP" ] && step_valid=1
done
if [ "$step_valid" -ne 1 ]; then
    echo "Invalid --from step: $START_STEP" >&2
    usage
fi

# --- Path resolution ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DATA_DIR="$BASE_DIR/data"
RESULTS_DIR="$BASE_DIR/results"
LOG_DIR="$BASE_DIR/log"
TRIOS_TSV="$DATA_DIR/trios.tsv"

[ -s "$TRIOS_TSV" ] || { echo "missing $TRIOS_TSV — run scripts/build_trios_tsv.py first" >&2; exit 1; }

# --- Resolve trio's three accessions from trios.tsv ---
read_role() {  # echo accession for $1=role
    awk -F'\t' -v t="$TRIO" -v r="$1" '$1==t && $3==r {print $5}' "$TRIOS_TSV"
}
ACC_A=$(read_role A)
ACC_B=$(read_role B)
ACC_C=$(read_role C)

if [ -z "$ACC_A$ACC_B$ACC_C" ]; then
    echo "Trio not found in $TRIOS_TSV: $TRIO" >&2
    exit 1
fi
for var in ACC_A ACC_B ACC_C; do
    if [ -z "${!var}" ]; then
        echo "Trio $TRIO has empty accession for role ${var#ACC_}" >&2
        exit 1
    fi
done

FA_A="${ACC_A}.fasta"
FA_B="${ACC_B}.fasta"
FA_C="${ACC_C}.fasta"

SUFFIX="_${TRIO}"
ALIGN_DIR_FINAL="$RESULTS_DIR/last_alignment${SUFFIX}"
ALIGN_DIR_RAW="$RESULTS_DIR/last_alignment"
MERGED_LIB="$RESULTS_DIR/repeat_modeler/merged_library${SUFFIX}.fa"
STATUS_FILE="$LOG_DIR/run_trio${SUFFIX}.status"

# --- Helpers ---
run() {
    echo "+ $*"
    if [ "$DRY_RUN" -eq 0 ]; then
        eval "$@"
    fi
}

stamp() {
    if [ "$DRY_RUN" -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S')  $1" >> "$STATUS_FILE"
    fi
}

skip_until() {  # return 0 if current step should run, 1 if skipped
    local step="$1" started=0
    for s in "${ALL_STEPS[@]}"; do
        [ "$s" = "$START_STEP" ] && started=1
        [ "$s" = "$step" ] && { [ "$started" -eq 1 ] && return 0 || return 1; }
    done
    return 1
}

echo "=== Trio: $TRIO ==="
echo "Roles:  A=$ACC_A  B=$ACC_B  C=$ACC_C"
echo "Suffix: $SUFFIX"
echo "Start:  $START_STEP"
if [ "$DRY_RUN" -eq 1 ]; then
    echo "(dry-run; no commands will execute)"
fi

# Refuse to clobber pre-existing align dir
if skip_until align; then
    if [ -d "$ALIGN_DIR_RAW" ]; then
        echo "ERROR: $ALIGN_DIR_RAW already exists." >&2
        echo "       align.sh writes there and rename target would collide." >&2
        echo "       Rename or delete it first (e.g., mv to ${ALIGN_DIR_FINAL})." >&2
        exit 1
    fi
fi
if skip_until rename_align && [ -d "$ALIGN_DIR_FINAL" ] && [ "$DRY_RUN" -eq 0 ]; then
    echo "WARNING: $ALIGN_DIR_FINAL already exists — rename_align step will fail." >&2
fi

# tmux reminder for non-dry runs
if [ "$DRY_RUN" -eq 0 ] && [ -z "${TMUX:-}" ]; then
    echo "WARNING: not inside tmux. Long-running steps will die on disconnect" >&2
    echo "         (tasks/lessons.md:20-34). Consider:  tmux new -s ${TRIO}" >&2
fi

if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$LOG_DIR"
    stamp "begin trio=$TRIO from=$START_STEP"
fi

# --- 1. Download ---
if skip_until download; then
    stamp "download"
    run "bash \"$SCRIPT_DIR/dwl.sh\" \"$ACC_A\" \"$ACC_B\" \"$ACC_C\""
fi

# --- 2. RepeatModeler × 3 (sequential per lessons.md) ---
if skip_until repeat_modeler; then
    stamp "repeat_modeler"
    run "bash \"$SCRIPT_DIR/repeat_modeler.sh\" \"$FA_A\""
    run "bash \"$SCRIPT_DIR/repeat_modeler.sh\" \"$FA_B\""
    run "bash \"$SCRIPT_DIR/repeat_modeler.sh\" \"$FA_C\""
    run "cat \"$RESULTS_DIR/repeat_modeler/${ACC_A}-families.fa\" \\
         \"$RESULTS_DIR/repeat_modeler/${ACC_B}-families.fa\" \\
         \"$RESULTS_DIR/repeat_modeler/${ACC_C}-families.fa\" \\
         > \"$MERGED_LIB\""
fi

# --- 3. RepeatMasker ---
if skip_until mask; then
    stamp "mask"
    run "bash \"$SCRIPT_DIR/repeat_masking.sh\" \"$MERGED_LIB\" \"$FA_A\" \"$FA_B\" \"$FA_C\""
fi

# --- 4. BED conversion ---
if skip_until bed; then
    stamp "bed"
    run "bash \"$SCRIPT_DIR/bed.sh\""
fi

# --- 5. LAST alignment (writes to results/last_alignment/) ---
if skip_until align; then
    stamp "align"
    run "bash \"$SCRIPT_DIR/align.sh\" \"$FA_A\" \"$FA_B\" \"$FA_C\""
fi

# --- 6. Rename align dir to trio-suffixed name ---
if skip_until rename_align; then
    stamp "rename_align"
    run "mv \"$ALIGN_DIR_RAW\" \"$ALIGN_DIR_FINAL\""
fi

# --- 7. Integrate (extract candidate insertions) ---
if skip_until integrate; then
    stamp "integrate"
    run "bash \"$SCRIPT_DIR/integrate.sh\" \"${FA_A}.masked\" \"${FA_B}.masked\" \"${FA_C}.masked\" \"$ALIGN_DIR_FINAL\" \"$SUFFIX\""
fi

# --- 8. TSD detection (per shared pattern, then aggregate) ---
if skip_until tsd; then
    stamp "tsd"
    INS_DIR="$RESULTS_DIR/candidate_insertions_100bp${SUFFIX}"
    TSD_SUM="$LOG_DIR/tsd_summary${SUFFIX}.tsv"
    PA="$RESULTS_DIR/${FA_A}.masked"
    PB="$RESULTS_DIR/${FA_B}.masked"
    PC="$RESULTS_DIR/${FA_C}.masked"
    # pattern -> (primary, secondary, absent)
    # AB_shared: pri=A, sec=B, abs=C
    # AC_shared: pri=A, sec=C, abs=B
    # BC_shared: pri=B, sec=C, abs=A
    run "python3 \"$SCRIPT_DIR/find_tsds.py\" \"$INS_DIR/pattern_AB_shared_100bp.tsv\" \"$PA\" \"$PB\" \"$PC\" \"$INS_DIR/AB_shared_100bp\""
    run "python3 \"$SCRIPT_DIR/find_tsds.py\" \"$INS_DIR/pattern_AC_shared_100bp.tsv\" \"$PA\" \"$PC\" \"$PB\" \"$INS_DIR/AC_shared_100bp\""
    run "python3 \"$SCRIPT_DIR/find_tsds.py\" \"$INS_DIR/pattern_BC_shared_100bp.tsv\" \"$PB\" \"$PC\" \"$PA\" \"$INS_DIR/BC_shared_100bp\""
    # Aggregate counts into tsd_summary
    if [ "$DRY_RUN" -eq 0 ]; then
        {
            printf "pattern\traw\ttsd_any\tprobable+confirmed\tconfirmed\n"
            for pat in AB_shared AC_shared BC_shared; do
                raw=$(grep -c ">" "$INS_DIR/${pat}.fasta" 2>/dev/null || echo 0)
                tsv="$INS_DIR/${pat}_100bp_tsd.tsv"
                tsd_any=0; pc=0; cf=0
                if [ -f "$tsv" ]; then
                    tsd_any=$(awk -F'\t' 'NR>1 && $NF != "UNCONFIRMED"' "$tsv" | wc -l)
                    pc=$(awk -F'\t' 'NR>1 && ($NF=="PROBABLE" || $NF=="CONFIRMED")' "$tsv" | wc -l)
                    cf=$(awk -F'\t' 'NR>1 && $NF=="CONFIRMED"' "$tsv" | wc -l)
                fi
                printf "%s\t%s\t%s\t%s\t%s\n" "$pat" "$raw" "$tsd_any" "$pc" "$cf"
            done
        } > "$TSD_SUM"
        echo "Wrote $TSD_SUM"
    else
        echo "+ # build $TSD_SUM by aggregating per-pattern *_100bp_tsd.tsv files"
    fi
fi

# --- 9. Report ---
if skip_until report; then
    stamp "report"
    run "bash \"$SCRIPT_DIR/report.sh\" \"$SUFFIX\""
fi

stamp "done"
echo "=== Trio $TRIO complete ==="
