# Task List

## [2026-03-19] Baseline Environment Check
- [x] Verify conda/shell environment and PATH
- [x] Check all pipeline tool availability: `lastdb`, `lastal`, `maf-convert`, `RepeatModeler`, `RepeatMasker`, `samtools`, `bedtools`, `python3`
- [x] Check versions of each tool
- [x] Verify data directory (genome FASTAs present and non-empty)
- [x] Verify results directory structure (repeat libs, masked genomes, candidate insertions)
- [x] Confirm scripts are executable
- [x] Note any missing tools or broken paths
- [x] Log results to `tasks/experiments/2026-03-19_baseline_env.md`

**Status**: Complete — see `tasks/experiments/2026-03-19_baseline_env.md`

---

## [2026-04-01] AMF Phylogenetic Confirmation Run

### Dataset
- **A (ref):** *Gigaspora rosea* GCA_003550325.1 (ingroup)
- **B:** *Gigaspora margarita* GCA_009809945.1 (ingroup)
- **C (expected outgroup):** *Dentiscutata heterogama* GCA_910591775.1

### Scientific Goal
Confirmation run using Method 1 (Frith 2023): count shared retrotransposon insertions
across a 3-way LAST alignment. Since Dentiscutata is the known outgroup by published
phylogenetics, the pipeline should recover C as the outgroup — validating the methodology
on AMF fungi. Alignment run twice (G. rosea ref / G. margarita ref) to assess reference bias.

### Checklist

#### Setup
- [x] Archive old results with manifest → results_archive_20260401/
- [x] Write tasks/todo.md

#### Data Acquisition
- [x] Download 3 genomes (dwl.sh): GCA_003550325.1, GCA_009809945.1, GCA_910591775.1
- [x] Verify genome FASTA sizes: rosea=550MB, margarita=748MB, dentiscutata=183MB
- [x] Confirm ≥60 GB free disk: 3.1 TB available

#### Repeat Library
- [x] RepeatModeler: G. rosea (GCA_003550325.1)
- [x] RepeatModeler: G. margarita (GCA_009809945.1)
- [x] RepeatModeler: D. heterogama (GCA_910591775.1)
- [x] Merge repeat libraries → results/repeat_modeler/merged_library.fa

#### Masking & BED
- [x] RepeatMasker: all 3 species (repeat_masking.sh with merged library)
- [x] BED conversion (bed.sh)

#### Alignment
- [x] Alignment Run 1: G. rosea as seq1 → results/last_alignment_rosea_ref/
- [x] Alignment Run 2: G. margarita as seq1 → results/last_alignment_margarita_ref/

#### Integrate, TSD, Report
- [x] integrate.sh × 2 (with RM BED filter)
- [x] find_tsds.py × 2
- [x] report.sh × 2

#### Documentation
- [x] Write experiment log → tasks/experiments/20260401_amf_gigaspora_baseline.md
- [ ] Git commit: 実験ノート + pipeline scripts

#### Results Summary (2026-04-21)
- AB_shared dominant at all tiers and in both reference runs
- **Verdict: C (Dentiscutata heterogama) is the outgroup** ✓ matches published phylogeny
- Reference bias: negligible (rosea-ref=67 vs margarita-ref=73 raw AB_shared, ~9%)
- TSD confirmation rate ~30% (expected for ancient Gypsy LTR elements)

---

## [2026-06-08] Multi-trio framework

### Goal
Scaffold the outgroup pipeline so it can be applied to an 81-trio dataset
sourced from `/home/mrk/sbst/evo-subster/results/` (cnidaria, fungi,
arthropoda, oomycota, apicomplexa, phaeophyceae, porifera). Framework
only — no trios executed.

### Checklist
- [x] Parse `data/tmp/ls_results_summary_all.txt` → `data/trios.tsv`
      (81 trios × 3 roles; AMF triple self-test). `scripts/build_trios_tsv.py`
- [x] Wrap end-to-end driver `scripts/run_trio.sh <trio_name>` with
      `--dry-run`, `--from <step>`, stale-dir guard, tmux warning.
- [x] Dry-run verification on `Denhet1_Gigros2_Gigmar3`.
- [x] Campaign 実験ノート: `tasks/experiments/2026-06-08_multitrio_campaign.md`
- [x] README section "Multi-trio execution".
- [ ] Commit framework PR on `dataset-v2`.
- [ ] Open GitHub umbrella issue with 81-trio checklist grouped by clade.
- [ ] First real-run trio (TBD — start with a small-genome apicomplexan or
      re-key the existing AMF run under the new naming).
