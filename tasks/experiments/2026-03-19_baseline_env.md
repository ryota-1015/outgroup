# Baseline Environment Check
**Date**: 2026-03-19
**Branch**: dataset-v2
**Working Directory**: /big/co_ryota/outgroup

---

## Conda Environments
| Environment | Path |
|---|---|
| base (active) | /home/co_ryota/my_conda |
| claude-env | /home/co_ryota/my_conda/envs/claude-env |
| repeat_env | /home/co_ryota/my_conda/envs/repeat_env |

---

## Tool Availability & Versions

| Tool | Available | Path | Version | Notes |
|---|---|---|---|---|
| `lastdb` | YES | /home/co_ryota/my_conda/bin/lastdb | 1595 | base env |
| `lastal` | YES | /home/co_ryota/my_conda/bin/lastal | 1595 | base env |
| `maf-convert` | YES | /home/co_ryota/my_conda/bin/maf-convert | — | base env |
| `RepeatModeler` | YES | /home/co_ryota/my_conda/envs/repeat_env/bin/RepeatModeler | 2.0.2 | **repeat_env only** |
| `RepeatMasker` | YES | /home/co_ryota/my_conda/envs/repeat_env/bin/RepeatMasker | 4.1.2-p1 | **repeat_env only** |
| `samtools` | YES | /home/co_ryota/my_conda/bin/samtools | 1.6 | base env |
| `bedtools` | YES | /home/co_ryota/my_conda/bin/bedtools | v2.31.1 | base env |
| `python3` | YES | /home/co_ryota/my_conda/bin/python3 | 3.12.2 | base env |

**Warning**: `RepeatModeler` and `RepeatMasker` are NOT in the base env PATH. Scripts using them must either activate `repeat_env` or use `conda run -n repeat_env`.

---

## Data Directory (`data/`)

| File | Size | Notes |
|---|---|---|
| GCA_001444195.3.fasta | 665M | Genome FASTA + .fai index |
| GCA_002775205.2.fasta | 681M | Genome FASTA + .fai index |
| GCA_036418095.1.fasta | 693M | Genome FASTA + .fai index |
| README.md | 1.6K | — |
| md5sum.txt | 265B | — |

All 3 genome FASTAs present, non-empty, and indexed.

---

## Results Directory (`results/`)

| Path | Contents |
|---|---|
| `*.fasta.masked` | 3 masked genomes (~670–697M each), all with .fai |
| `*.fasta.out` / `.out.bed` / `.out.gff` | RepeatMasker output for all 3 genomes |
| `*.fasta.cat.gz` | RepeatMasker cat files for all 3 genomes |
| `*.fasta.tbl` | RepeatMasker summary tables for all 3 genomes |
| `repeat_modeler/` | GCA_002775205.2 repeat library (families.fa, families.stk, db files) |
| `last_alignment/` | LAST alignment outputs (seq1_db, *.maf, *.mat, joined MAF) |
| `candidate_insertions_50bp/` | 6 FASTA + 4 BED pattern files (A_only, B_only, C_only, AB/AC/BC_shared) |
| `candidate_insertions_100bp/` | Same structure as 50bp directory |

Results directory is complete and well-populated.

---

## Scripts (`scripts/`)

| Script | Executable | Notes |
|---|---|---|
| align.sh | YES | LAST alignment pipeline |
| bed.sh | YES | BED file generation |
| dwl.sh | YES | Download/setup script |
| integrate.sh | YES | Integration pipeline |
| repeat_masking.sh | YES | RepeatMasker pipeline |
| repeat_modeler.sh | YES | RepeatModeler pipeline |
| report.sh | YES | Reporting/analysis |

All 7 scripts are executable.

---

## Issues & Warnings

1. **RepeatModeler/RepeatMasker not in base PATH**: Must use `conda run -n repeat_env` or activate `repeat_env` before running masking scripts. Scripts likely already handle this.
2. **samtools version 1.6**: Relatively old (current stable ~1.19). Likely fine for existing usage; worth upgrading if new features are needed.
3. **maf-convert version not reported**: `--version` flag not supported; tool is present and functional.

---

## Overall Readiness Verdict

**READY** — All pipeline tools are present (RepeatModeler/Masker in dedicated `repeat_env`), all 3 genome FASTAs are present and indexed, all masked outputs and candidate insertion files exist, and all scripts are executable. The environment is fully operational for downstream analysis on the `dataset-v2` branch.
