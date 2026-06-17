# Pilot trio 1 — Crypar1_Cryhom2_Crycun3 (apicomplexa)

Launched: 2026-06-17. Part of the [2026-06-08] multi-trio campaign
(`tasks/experiments/2026-06-08_multitrio_campaign.md`). Driver:
`scripts/run_trio.sh Crypar1_Cryhom2_Crycun3`.

## Dataset

| Role | Species | Accession | Genome size (est.) |
|---|---|---|---|
| A | *Cryptosporidium parvum* | GCF_000165345.1 | ~9 MB |
| B | *Cryptosporidium hominis* | GCF_000006425.1 | ~9 MB |
| C | *Cryptosporidium cuniculus* | GCA_004337835.1 | ~9 MB |

**Why this trio is the pilot**: smallest genomes in the 81-trio dataset
(~10× smaller than the smallest AMF genome) so it shakes out the entire
`run_trio.sh` chain in hours rather than days. *Cryptosporidium* is a
deeply-studied apicomplexan with a published phylogeny we can validate
against. Phylogenetically, apicomplexa (SAR/Alveolata) is on the
opposite side of the eukaryotic tree from AMF (Opisthokonta/Fungi) —
strongest possible distance test.

## Scientific question / expected outgroup

Published phylogenetics of the *C. parvum* / *C. hominis* / *C.
cuniculus* triad:

- *C. parvum* and *C. hominis* are sister taxa (the human/livestock
  pair; together comprise most of human cryptosporidiosis cases).
- *C. cuniculus* is a rabbit-infecting species, traditionally placed
  outside the parvum/hominis clade in 18S- and multi-locus-based trees.
- **Primary hypothesis**: C (cuniculus) is the outgroup
  → pipeline should report **AB_shared dominates**.
- **Alternative seen in some markers**: cuniculus is closer to hominis,
  with parvum as outgroup → BC_shared dominates. Worth flagging if so.

## Plan (matches `tasks/todo.md` [2026-06-08] checklist)

1. `dwl.sh` — fetch 3 genome FASTAs into `data/`.
2. `repeat_modeler.sh` × 3 — per-genome `<acc>-families.fa` (small,
   should each take hours given tiny genomes).
3. Merge libraries → `results/repeat_modeler/merged_library_Crypar1_Cryhom2_Crycun3.fa`.
4. `repeat_masking.sh` — soft-mask all three FASTAs with merged library.
5. `bed.sh` — `.out` → `.bed` for the three masked genomes.
6. `align.sh` — LAST 3-way alignment with Crypar1 (A) as reference.
7. Wrapper renames `results/last_alignment/` → `results/last_alignment_Crypar1_Cryhom2_Crycun3/`.
8. `integrate.sh` — detect insertion patterns + extract candidate FASTAs
   at 50bp and 100bp thresholds.
9. `find_tsds.py` × 3 — TSD detection on AB/AC/BC_shared TSVs.
10. `report.sh` — final per-pattern table + verdict.

Per-trio outputs land under `_Crypar1_Cryhom2_Crycun3` suffix:
- `results/last_alignment_Crypar1_Cryhom2_Crycun3/`
- `results/candidate_insertions_{50,100}bp_Crypar1_Cryhom2_Crycun3/`
- `log/final_outgroup_report_Crypar1_Cryhom2_Crycun3.log`
- `log/tsd_summary_Crypar1_Cryhom2_Crycun3.tsv`
- `log/run_trio_Crypar1_Cryhom2_Crycun3.{log,status}`

## Steps completed

To be filled in as the run progresses. Run-time status is tracked live
in `log/run_trio_Crypar1_Cryhom2_Crycun3.status` (timestamps per step).

- [ ] download
- [ ] repeat_modeler (×3)
- [ ] mask
- [ ] bed
- [ ] align
- [ ] rename_align
- [ ] integrate
- [ ] tsd
- [ ] report

## Results

To be filled in after `report.sh` completes. Mirror the AMF baseline
table layout (`20260401_amf_gigaspora_baseline.md`):

- Raw gap counts (≥100 bp, no TE filter): per-pattern table.
- RM-filtered counts (≥50% gap covered by TE): per-pattern table.
- High-stringency (≥120 bp), raw + RM-filtered.
- TSD-confirmed counts.

## Biological sanity check

To be filled in after results land.

- Dominant pattern → identified outgroup → comparison with the
  Primary / Alternative hypotheses above.
- If primary hypothesis confirmed: **C (cuniculus) is the outgroup**.
- If alternative confirmed: **A (parvum) is the outgroup** — flag for
  discussion; the pipeline still produced a clear verdict, just one
  that revises the parvum/hominis/cuniculus published topology.
- TSD confirmation rate (vs ~30% in AMF baseline).

## Pipeline notes

To be filled in: anything surprising — collisions, log anomalies,
runtime divergence from estimate, RepeatMasker repeat-class breakdown,
any operator interventions.
