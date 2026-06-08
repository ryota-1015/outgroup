# Multi-trio outgroup pipeline campaign — 2026-06-08

## Goal

Generalise the outgroup pipeline (so far validated only on the AMF
Gigaspora/Dentiscutata trio — see `20260401_amf_gigaspora_baseline.md`)
to a curated dataset of 81 trios sourced from a sibling project at
`/home/mrk/sbst/evo-subster/results/`. Each trio is three species with
published assemblies; we want to recover the outgroup for every trio
using shared retrotransposon insertions in 3-way LAST alignments.

This note covers the **framework only** (parser, wrapper, tracking).
No trios have been executed yet.

## Dataset inventory

Source listings (committed under `data/tmp/`):

| File | What it is |
|---|---|
| `data/tmp/ls_result.txt` | `ls -R` of `/home/mrk/sbst/evo-subster/results/` (~25k lines) |
| `data/tmp/ls_results_summary_all.txt` | `ls -R` of `…/results/summary/all/` (canonical 81-trio view) |

The accession for each species code is embedded directly in filenames
inside each trio's `metadata/` subdir, e.g.
`Denhet1_GCA_910591775.1.json` → code `Denhet1` = `GCA_910591775.1`.
This is the only piece of information the framework needs; no NCBI
lookup, no species-name decoding.

### Canonical inventory

`scripts/build_trios_tsv.py` walks `ls_results_summary_all.txt`,
extracts the three `<code>_<accession>.json` filenames per trio's
latest-dated `metadata/` block, joins clades from `ls_result.txt`, and
emits `data/trios.tsv` (`trio_name, clade, role, code, accession, notes`).

Result: **81 trios × 3 roles = 243 rows**.

| Clade | Trios |
|---|---:|
| fungi | 27 |
| cnidaria | 24 |
| oomycota | 12 |
| arthropoda | 11 |
| apicomplexa | 4 |
| phaeophyceae | 2 |
| porifera | 1 |
| **total** | **81** |

(Five `pca_*` dirs in `summary/all/` are excluded by the parser — they
are PCA artefact directories, not trios.)

Twelve trios share a species code with at least one other trio (e.g.,
`Bolret2` appears in both `Bolbar1_Bolret2_Bolnob3` and
`Bolrex1_Bolret2_Boledu3`); those rows are tagged
`dup_species_across_trios` in the `notes` column. This matters because
RepeatModeler is run per species, so the second trio's RepeatModeler
step is a no-op (output already present) — saves wall time but worth
flagging when reading per-trio status logs.

### AMF regression

`build_trios_tsv.py` hard-asserts that the AMF trio
`Denhet1_Gigros2_Gigmar3` resolves to the three accessions already on
disk in `data/`:
- A=`Denhet1`→`GCA_910591775.1`
- B=`Gigros2`→`GCA_003550325.1`
- C=`Gigmar3`→`GCA_009809945.1`

This guards against silent listing-format drift.

## Framework decisions

### Per-trio output suffix

Every trio's outputs are isolated under a `_<trio_name>` suffix
(reusing the mechanism `integrate.sh` and `report.sh` already accept).
`align.sh` writes to its hard-coded `results/last_alignment/`; the
wrapper renames that directory immediately after — same pattern the AMF
baseline used to keep `_rosea_ref` and `_margarita_ref` runs separate.
No edits to the pipeline scripts.

### Role-to-position mapping

Role A is the **first** species code in the trio name (suffix `1`),
which becomes the LAST alignment reference and the RepeatModeler/TSD
"primary". Outgroup verdict is invariant to this choice — only the
labels `AB_shared` / `AC_shared` / `BC_shared` shift accordingly.

In the AMF baseline note, role A was Gigros2 (rosea-ref run) — the
"reference" was chosen by the operator. With the canonical trio name
`Denhet1_Gigros2_Gigmar3`, role A would now be Denhet1. The dominant
shared pattern would relabel from `AB_shared` (Gigros2+Gigmar3, AMF
baseline) to `BC_shared` (still Gigros2+Gigmar3) — same biological
conclusion. Worth noting when comparing across the two conventions.

### Tracking

- **GitHub umbrella issue** — single issue listing all 81 trios as a
  checklist, grouped by clade. Each completed batch lands as one PR
  bundling code/config/note updates. This framework PR is the first.
- **実験ノート** — this campaign note (master) plus one
  `tasks/experiments/<date>_<trio>.md` per executed trio, following the
  AMF baseline template (Dataset / Steps Completed / Results /
  Biological Sanity Check / Pipeline notes).
- **Per-trio runtime status** — `log/run_trio_<trio>.status` (stamps
  on entry to each step) and `log/run_trio_<trio>.log` (mentioned in
  the docstring for future use).

## Tooling delivered in this PR

| Path | What |
|---|---|
| `scripts/build_trios_tsv.py` | Listing → `data/trios.tsv` (with AMF self-test). |
| `scripts/run_trio.sh` | End-to-end driver for one trio. Supports `--dry-run`, `--from <step>`. Refuses to clobber `results/last_alignment/`. Warns if not in tmux. |
| `data/trios.tsv` | Canonical 81-trio × 3-role inventory. |
| `tasks/experiments/2026-06-08_multitrio_campaign.md` | This note. |
| README `Multi-trio execution` section | Pointer to wrapper + TSV. |

No existing scripts were modified.

## Verification done

1. **Parser**: 81 trios × 3 = 243 rows in `data/trios.tsv`. AMF triple
   matches disk. Five `pca_*` dirs correctly excluded. 12 trios flagged
   `dup_species_across_trios`.
2. **`run_trio.sh --dry-run Denhet1_Gigros2_Gigmar3`**: emits the
   correct command sequence with suffix `_Denhet1_Gigros2_Gigmar3`
   threaded through align-rename / integrate / find_tsds / report.
3. **Stale-dir guard**: pre-existing `results/last_alignment/` causes
   the wrapper to exit non-zero with a helpful message before any work.
4. **Unknown trio**: `bash run_trio.sh NotARealTrio` exits 1 with a
   `Trio not found in trios.tsv` error.
5. **`--from align`**: skips `download`, `repeat_modeler`, `mask`,
   `bed` and starts at `align`. Verified in dry-run.

## Open items / not in this PR

- No trios executed yet. First real run will pick a small-genome trio
  (likely an apicomplexan or the existing AMF trio re-keyed under the
  new naming) to shake out tmux/CPU discipline and the rename step.
- Role-to-position convention (which species becomes the LAST
  reference) is fixed to "first code in the trio name". If a future
  trio benefits from a different reference choice, run with a
  temporarily-reordered trio name in `trios.tsv` and document the
  override in that trio's per-run note.
