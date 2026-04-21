# AMF Gigaspora Baseline Run — 2026-04-21

## Dataset
| Label | Species | Accession |
|---|---|---|
| A (Run1 ref) | *Gigaspora rosea* | GCA_003550325.1 |
| B | *Gigaspora margarita* | GCA_009809945.1 |
| C (expected outgroup) | *Dentiscutata heterogama* | GCA_910591775.1 |

**Scientific goal**: Validate the pipeline on a known phylogeny (Dentiscutata is the outgroup by published literature). Two reference runs to assess reference bias.

## Steps Completed
1. Genome download (dwl.sh)
2. RepeatModeler × 3 → merged_library.fa (10 MB)
3. RepeatMasker × 3 (soft-mask with merged library)
4. BED conversion (bed.sh)
5. Alignment Run 1 — G. rosea as ref → last_alignment_rosea_ref/ (124 MB MAF)
6. Alignment Run 2 — G. margarita as ref → last_alignment_margarita_ref/ (117 MB MAF)
7. integrate.sh × 2 (with RepeatMasker BED filter, ≥50% coverage threshold)
8. find_tsds.py × 2 (TSD detection on shared-pattern TSVs)
9. report.sh × 2

## Results

### Raw gap counts (≥100bp, no TE filter)
| Pattern | Rosea ref | Margarita ref |
|---|---|---|
| AB_shared | 67 | 73 |
| AC_shared | 13 | 21 |
| BC_shared | 6 | 5 |

### RM-filtered counts (≥50% gap covered by TE annotation)
| Pattern | Rosea ref | Margarita ref |
|---|---|---|
| AB_shared | 34 | 35 |
| AC_shared | 7 | 11 |
| BC_shared | 1 | 2 |

### High-stringency (≥120bp, raw)
| Pattern | Rosea ref | Margarita ref |
|---|---|---|
| AB_shared | 21 | 20 |
| AC_shared | 4 | 2 |
| BC_shared | 1 | 1 |

### High-stringency (≥120bp, RM-filtered)
| Pattern | Rosea ref | Margarita ref |
|---|---|---|
| AB_shared | 8 | 8 |
| AC_shared | 2 | 0 |
| BC_shared | 0 | 1 |

### TSD-confirmed counts (PROBABLE + CONFIRMED, ≥100bp)
| Pattern | Rosea ref | Margarita ref |
|---|---|---|
| AB_shared | 7 | 5 |
| AC_shared | 2 | 0 |
| BC_shared | 0 | 1 |

## Biological Sanity Check — PASS

Across all tiers and both reference runs, **AB_shared consistently dominates**:
- *G. rosea* + *G. margarita* share the most TE insertions absent in *D. heterogama*
- → **C (*Dentiscutata heterogama*) is the outgroup**
- This matches published AMF phylogenetics ✓

### Reference bias assessment
Raw AB_shared counts: rosea-ref=67, margarita-ref=73 (8.9% difference — minor).
RM-filtered: 34 vs 35. The signal is reference-independent.

### TSD notes
- ~30% of candidates show any TSD evidence (CANDIDATE or higher)
- Low CONFIRMED/PROBABLE rate is expected: Gypsy/DIRS1 LTR elements dominate (2.89%
  of G. rosea genome) and ancient insertions have eroded TSDs
- The DIRS1 elements use a non-standard integration mechanism and may not leave
  classical TSDs — explaining some of the UNCONFIRMED rate

## Pipeline improvements implemented this run
- `extract_gaps.py`: now emits 9-col TSV with all 3 species coords per candidate
- `integrate.sh`: parametrized (maf_dir + suffix args); added RepeatMasker BED filter
  using `bedtools coverage` (correctly handles multiple overlapping TE annotations)
- `report.sh`: parametrized; added RM-filtered and TSD tiers
- `find_tsds.py`: new script; searches 4 boundary combinations to handle aligner
  gap-placement uncertainty; thresholds tuned for Gypsy/LINE/DNA transposon mix
