# Pipeline Lessons

## [2026-04-01] dwl.sh: unzip exit-code trap with set -euo pipefail

**Pattern:** `unzip` returns exit code 1 for non-fatal warnings (e.g., overwriting existing files).
With `set -euo pipefail` + `if ! unzip ...`, the script treats any non-zero as failure and skips
the file-rename step — even though the FNA files were successfully extracted into `ncbi_dataset/`.

**Fix:** Replace `if ! unzip -q ...` with:
```bash
unzip -q "$OUTPUT_ZIP" || true   # tolerate overwrite warnings (exit code 1)
```
Or check the specific exit code: unzip exit 1 = warnings only; exit >1 = real errors.

**Recovery:** FNA files land in `ncbi_dataset/data/<accession>/<accession>_*_genomic.fna`.
Move them manually: `mv ncbi_dataset/data/<acc>/*.fna data/<acc>.fasta && rm -rf ncbi_dataset`

---

## [2026-04-04] Long-running jobs must use tmux on biohazard

**Rule:** Any job expected to run for more than ~1 hour MUST be launched inside a `tmux` session.
Background jobs spawned via Claude Code (`run_in_background`) are child processes of the
session and get killed on disconnect — confirmed by 3 repeated kills of RepeatModeler.

**How to apply:**
```bash
tmux new-session -s <name>    # create session
# run commands inside tmux
# Ctrl-b d to detach (keeps running)
tmux attach -t <name>         # reconnect later
```
For recovery after a kill: RepeatModeler supports `-recoverDir <RM_dir>` to resume from
checkpoint. Look for `RM_*.*/` in `results/repeat_modeler/`.

---

## [2026-04-01] Shared machine CPU policy (biohazard)

**Rule:** Use < 1/4 of 64 cores = < 16 cores per job. Set to 8 threads in all scripts.
- `repeat_masking.sh`: patched THREADS 16 → 8
- Run RepeatModeler on multiple species **sequentially**, never in parallel background jobs.
