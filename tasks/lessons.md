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

---

## [2026-06-17] dwl.sh: use `unzip -o` (sequel to 2026-04-01 entry)

**Pattern:** The 2026-04-01 fix above (`|| true`) was later refactored to
`if ! unzip -q ... ; then ... continue`. That handles the exit-code-1 case but
re-introduces the underlying problem: when an NCBI zip ships a top-level
`README.md` / `md5sum.txt` that collide with a prior download in `data/`,
unzip BLOCKS on `replace README.md? [y]es, [n]o, [A]ll, [N]one, [r]ename:`
because `-q` only suppresses progress output, not the overwrite prompt.
Hang manifests silently in detached tmux. Discovered on Crypar pilot trio.

**Fix (applied):** add `-o` (overwrite) to make unzip non-interactive AND
make exit-code 1 impossible (nothing to warn about):
```bash
unzip -o -q "$OUTPUT_ZIP" 2>> "$LOG_FILE"
```

**How to apply:** any time a script unzips a file under non-interactive
control (cron, tmux, CI), the `-o` flag is mandatory. Same goes for
`tar --overwrite`, `cp -f`, etc. Pair it with `-q` for log hygiene.

---

## [2026-06-17] Dry-run does not validate a wrapper

**Pattern:** I declared the `run_trio.sh` framework "verified" based on
`--dry-run` output matching expectations. The dry-run only ECHOES the
commands; it does not execute them. The Crypar pilot then hung on
`dwl.sh`'s unzip prompt — a bug only reachable under real execution.

**Why:** Wrapper bugs include several classes that dry-run cannot catch —
interactive prompts (overwrite, license accept), permission / disk errors,
race conditions, environment-variable assumptions. Dry-run validates
command-line *shape*, not *execution*.

**How to apply:** before declaring a wrapper "framework verified", smoke
the smallest viable real input end-to-end. For this pipeline, the
apicomplexa Crypar trio (~9 MB genomes) is now the canonical smoke test:
it exercises dwl/repeat_modeler/repeat_masking/bed/align/integrate/tsd/report
in hours rather than days. Future wrapper changes should be re-validated
against Crypar before opening fresh trios.
