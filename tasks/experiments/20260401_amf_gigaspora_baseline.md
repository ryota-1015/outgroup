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
- **Available disk (/big):** 3.1 TB free (of 22 TB; 85% used) — sufficient
- **Estimated data footprint:** ~1.5 GB FASTA + ~11–17 GB RepeatModeler temp + ~2–4 GB masked + ~10–40 GB MAF (≤ 65 GB total)

## Step Log

### Phase 0: Archive old results ✓
- Old `results/` moved to `results_archive_20260401/`
- MANIFEST written: `results_archive_20260401/MANIFEST.md`
- Previous analysis: GCA_001444195.3 / GCA_002775205.2 / GCA_036418095.1
- Previous verdict: AC_shared=13, AB_shared=8, BC_shared=6 → B is outgroup

### Phase 1: tasks/todo.md updated ✓
- Added AMF confirmation run section with full checklist

### Phase 2: Download genomes (IN PROGRESS)
- Command: `bash scripts/dwl.sh GCA_003550325.1 GCA_009809945.1 GCA_910591775.1`
- Status: Running (background job b5irtbxyi)
- Log: `log/dwl_<timestamp>.log`
- Expected: `data/GCA_003550325.1.fasta`, `data/GCA_009809945.1.fasta`, `data/GCA_910591775.1.fasta`

### Phase 3: Verify genome sizes
- [ ] Check actual sizes after download
- Estimated: G. rosea ~700 Mb, G. margarita ~540 Mb, D. heterogama ~300–400 Mb

### Phase 4: RepeatModeler (all 3 species)
- [ ] G. rosea: `bash scripts/repeat_modeler.sh GCA_003550325.1.fasta`
- [ ] G. margarita: `bash scripts/repeat_modeler.sh GCA_009809945.1.fasta`
- [ ] D. heterogama: `bash scripts/repeat_modeler.sh GCA_910591775.1.fasta`
- [ ] Merge: `cat .../families.fa ... > results/repeat_modeler/merged_library.fa`
- Estimated runtime: 23–64 h total (8 cores)

### Phase 5: RepeatMasker
- [ ] `bash scripts/repeat_masking.sh results/repeat_modeler/merged_library.fa GCA_003550325.1.fasta GCA_009809945.1.fasta GCA_910591775.1.fasta`

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
