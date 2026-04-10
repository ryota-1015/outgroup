# 実験ノート — AMF Phylogenetic Confirmation Run

## Overview
- **Date:** 2026-04-01
- **Branch:** dataset-v2
- **Commit at start:** db46cea (Update README to reflect generalized argument-driven pipeline)
- **Working directory:** /big/co_ryota/outgroup

## Scientific Purpose
Confirmation run using Method 1 (Frith 2023 — shared retrotransposon insertions).
The three species used are arbuscular mycorrhizal fungi (AMF, phylum Glomeromycota):

| Label | Accession | Species | Role |
|---|---|---|---|
| A (ref) | GCA_003550325.1 | *Gigaspora rosea* | Ingroup (alignment ref) |
| B | GCA_009809945.1 | *Gigaspora margarita* | Ingroup |
| C | GCA_910591775.1 | *Dentiscutata heterogama* | Expected outgroup (known from published phylogeny) |

**Expected outcome:** The pipeline should identify C (*Dentiscutata*) as the outgroup,
confirming that the two *Gigaspora* species are sisters. If the pipeline recovers this
known relationship, it validates the method on AMF fungi.

**Reference bias control:** Alignment is run twice — with A (*G. rosea*) as seq1 and
with B (*G. margarita*) as seq1 — to assess how much the reference choice inflates
counts for topologies including that species.

## System Info
- **Machine:** biohazard (shared HPC), 64 CPU cores, ~15 users
- **CPU policy:** Use < 1/4 of cores = < 16 cores per job. All scripts set to 8 threads.
  - `repeat_masking.sh` patched: THREADS 16 → 8
- **Available disk (/big):** 3.1 TB free (of 22 TB; 85% used) — sufficient
- **Actual FASTA sizes:** G. rosea 550 MB, G. margarita 748 MB, D. heterogama 183 MB
- **Estimated data footprint:** ~1.5 GB FASTA + ~10–16 GB RepeatModeler temp + ~2–4 GB masked + ~10–40 GB MAF (≤ 65 GB total)

## Step Log

### Phase 0: Archive old results ✓
- Old `results/` moved to `results_archive_20260401/`
- MANIFEST written: `results_archive_20260401/MANIFEST.md`
- Previous analysis: GCA_001444195.3 / GCA_002775205.2 / GCA_036418095.1
- Previous verdict: AC_shared=13, AB_shared=8, BC_shared=6 → B is outgroup

### Phase 1: tasks/todo.md updated ✓
- Added AMF confirmation run section with full checklist

### Phase 2: Download genomes ✓
- Command: `bash scripts/dwl.sh GCA_003550325.1 GCA_009809945.1 GCA_910591775.1`
- **Issue:** `unzip` returned exit code 1 (overwrite warnings) — `set -euo pipefail` treated as failure, skipping rename step
- **Recovery:** All 3 FNA files were in `ncbi_dataset/data/`; manually moved to `data/GCA_*.fasta`
- **Lesson:** Add `unzip` return code tolerance to `dwl.sh` in a future cleanup

### Phase 3: Verify genome sizes ✓
- G. rosea (GCA_003550325.1): **550 MB**
- G. margarita (GCA_009809945.1): **748 MB**
- D. heterogama (GCA_910591775.1): **183 MB**
- Available disk: 3.1 TB free — no constraints

### Phase 4: RepeatModeler (all 3 species)
**Note:** Background jobs via Claude Code are children of the session process and get killed
on session disconnect. All long-running jobs MUST be launched inside `tmux`.

**Bugs fixed during this phase:**
- `repeat_modeler.sh`: missing `module load repeatmodeler/2.0.5` → added
- `repeat_modeler.sh`: `LIBRARY_FA="families.fa"` wrong → fixed to `${DB_BASENAME}-families.fa`
- `repeat_masking.sh`: THREADS 16 → 8 (biohazard CPU policy: < 1/4 of 64 cores)
- README: updated `families.fa` references to `<genome>-families.fa`; added tmux section

**Run history (G. rosea):**
- Attempt 1 (2026-04-01): exit 127 — BuildDatabase not found (module not loaded)
- Attempt 2 (2026-04-01 02:19): killed at round-6 ~batch 995/9003 (session disconnect)
- Attempt 3 (2026-04-04 07:01): resumed via -recoverDir; killed at round-6 ~batch 1596/9126
- Attempt 4 (2026-04-04): resumed via -recoverDir in tmux session "repeatmodeler" — **COMPLETED 2026-04-06 04:28**

**Results (all complete ✓):**
| Species | Library | Families | Finished |
|---|---|---|---|
| G. rosea (GCA_003550325.1) | GCA_003550325.1-families.fa | 4,898 | 2026-04-06 04:28 (36h runtime) |
| G. margarita (GCA_009809945.1) | GCA_009809945.1-families.fa | 4,290 | 2026-04-08 07:46 |
| D. heterogama (GCA_910591775.1) | GCA_910591775.1-families.fa | 2,359 | 2026-04-09 01:50 (~18h runtime) |

**Merge (completed 2026-04-10):**
```
cat results/repeat_modeler/GCA_003550325.1-families.fa \
    results/repeat_modeler/GCA_009809945.1-families.fa \
    results/repeat_modeler/GCA_910591775.1-families.fa \
    > results/repeat_modeler/merged_library.fa
# Total: 11,547 consensus sequences
```

### Phase 5: RepeatMasker
- [x] Launched 2026-04-10 in tmux session "repeatmasker"
- Command: `bash scripts/repeat_masking.sh results/repeat_modeler/merged_library.fa GCA_003550325.1.fasta GCA_009809945.1.fasta GCA_910591775.1.fasta`
- Library: `results/repeat_modeler/merged_library.fa` (11,547 families from all 3 species)
- Status: **running** (G. rosea first)

### Phase 6: BED conversion
- [ ] `bash scripts/bed.sh`

### Phase 7: Alignment Run 1 (G. rosea as ref)
- [ ] `bash scripts/align.sh GCA_003550325.1.fasta GCA_009809945.1.fasta GCA_910591775.1.fasta`
- [ ] `mv results/last_alignment results/last_alignment_rosea_ref`

### Phase 8: Alignment Run 2 (G. margarita as ref)
- [ ] `bash scripts/align.sh GCA_009809945.1.fasta GCA_003550325.1.fasta GCA_910591775.1.fasta`
- [ ] `mv results/last_alignment results/last_alignment_margarita_ref`

---

## Tool Versions
*(to be filled in after downloads complete)*
- LAST: TBD
- RepeatModeler: TBD
- RepeatMasker: TBD
- samtools: TBD
- bedtools: TBD
- python3: TBD

## Results Summary
*(to be filled in after analysis)*

## Biological Sanity Check
*(to be filled in after report.sh)*
- Expected: BC_shared (Gigaspora sisters) highest → C (Dentiscutata) is outgroup
- Actual: TBD
- Reference bias comparison (rosea ref vs margarita ref): TBD
