# Outgroup Analysis via Genomic Fossils

Project started: 2025-12-16.
Last update: 2026-04-21 Ryota Ishii

Identifies the plausible outgroup among three taxa by detecting shared
retrotransposon insertions (SINEs/LINEs) as phylogenetic markers in
whole-genome alignments.

---

## Project structure

```
outgroup/
├── README.md
├── data/                          # Downloaded genome FASTAs
├── log/                           # Execution logs
├── results/
│   ├── last_alignment/            # MAF files and LAST DB
│   ├── repeat_modeler/            # De novo repeat library (families.fa)
│   ├── candidate_insertions_50bp/
│   └── candidate_insertions_100bp/
└── scripts/
    ├── dwl.sh             # Download genomes from NCBI
    ├── align.sh           # LAST whole-genome alignment (MSA)
    ├── repeat_modeler.sh  # Build de novo repeat library with RepeatModeler
    ├── repeat_masking.sh  # Soft-mask genomes with RepeatMasker
    ├── bed.sh             # Convert RepeatMasker .out to BED
    ├── integrate.sh       # Detect insertion patterns; extract FASTA sequences
    ├── extract_gaps.py    # Core pattern-matching logic (called by integrate.sh)
    └── report.sh          # Summary report and stringency filter
```

---

## Dependencies

| Tool | Purpose |
|------|---------|
| `datasets` (NCBI CLI) | Genome download |
| `lastdb`, `lastal`, `last-train`, `last-split`, `maf-sort`, `maf-join` | Alignment |
| `BuildDatabase`, `RepeatModeler` | De novo repeat library |
| `RepeatMasker` | Soft-masking |
| `samtools faidx` | FASTA indexing |
| `bedtools getfasta` | Sequence extraction |
| Python 3 (standard library only) | Pattern detection |

---

## Long-running steps and session persistence

Steps 2 (alignment) and 3 (RepeatModeler) can take **days** on large genomes
(e.g. AMF fungi with >500 Mb assemblies). Always run them inside a `tmux`
session so they survive SSH disconnection or session timeout:

```bash
tmux new-session -s repeatmodeler          # create persistent session
# ... run your commands ...
# detach with Ctrl-b d  (session keeps running)
tmux attach -t repeatmodeler               # reconnect later to check progress
```

To monitor progress without attaching:
```bash
# Check latest RepeatModeler log
tail -20 log/repeat_modeler_*.log | tail -20

# Check latest alignment log
tail -20 log/last_align_*.log | tail -20
```

---

## Pipeline usage

All scripts are argument-driven and runnable from any directory.
The example below uses **Human / Chimpanzee / Orangutan**
(GCA_009914755.4 / GCA_028858775.2 / GCA_028885655.2).
Substitute your own accessions/filenames for any other 3-species dataset.

### 1. Download genomes

```bash
bash dwl.sh GCA_009914755.4 GCA_028858775.2 GCA_028885655.2
```

Accepts any number of GCA accession IDs. FASTAs are saved to `data/`.

### 2. Whole-genome alignment

```bash
bash align.sh GCA_009914755.4.fasta GCA_028858775.2.fasta GCA_028885655.2.fasta
```

Runs `lastdb → last-train → lastal → last-split → maf-sort → maf-join`
for both query genomes against the reference (first argument).
Output: `results/last_alignment/seq1_seq2_seq3_joined.maf`

### 3. Build de novo repeat library

```bash
bash repeat_modeler.sh GCA_009914755.4.fasta
```

Sanitizes the reference FASTA headers, builds a RepeatModeler database,
and runs RepeatModeler.
Output: `results/repeat_modeler/<genome>-families.fa`

### 4. Soft-mask all three genomes

When running multiple species, first merge the per-species libraries:

```bash
cat results/repeat_modeler/A-families.fa \
    results/repeat_modeler/B-families.fa \
    results/repeat_modeler/C-families.fa \
    > results/repeat_modeler/merged_library.fa
```

Then run RepeatMasker with the merged library:

```bash
bash repeat_masking.sh results/repeat_modeler/merged_library.fa \
    GCA_009914755.4.fasta GCA_028858775.2.fasta GCA_028885655.2.fasta
```

First argument is the repeat library; remaining arguments are the FASTAs
to mask (any number). Runs RepeatMasker with `-xsmall` (soft-masking).
Output: `results/*.fasta.masked`

### 5. Convert RepeatMasker output to BED

```bash
bash bed.sh
```

Discovers all `results/*.fasta.out` files automatically.
Output: `results/*.bed` (alongside the `.out` files)

### 6. Detect insertion patterns and extract sequences

```bash
bash integrate.sh GCA_009914755.4.fasta.masked \
    GCA_028858775.2.fasta.masked GCA_028885655.2.fasta.masked
```

Arguments are masked FASTA filenames (relative to `results/`), ordered
A / B / C. The script:

1. Sanitizes FASTA headers and runs `samtools faidx`
2. Calls `extract_gaps.py` at 50 bp and 100 bp thresholds; `.fai` index
   files are used to map sequence names to species labels (A/B/C) without
   any hardcoded chromosome IDs
3. Runs `bedtools getfasta` for each of the 6 insertion patterns

Output directories:
```
results/candidate_insertions_50bp/
results/candidate_insertions_100bp/
    ├── AB_shared.fasta   # Insertion shared by A & B  →  C is outgroup
    ├── AC_shared.fasta   # Insertion shared by A & C  →  B is outgroup
    ├── BC_shared.fasta   # Insertion shared by B & C  →  A is outgroup
    ├── A_only.fasta
    ├── B_only.fasta
    └── C_only.fasta
```

### 7. Generate report

```bash
bash report.sh
```

Prints a summary table (50 bp vs 100 bp counts, % survival),
a high-stringency filter (≥ 120 bp), and an outgroup verdict.
Output: `log/final_outgroup_report.log`

---

## Outgroup determination

The pattern with the highest count of shared markers (≥ 120 bp) at the
100 bp threshold identifies the sister pair and, by exclusion, the
outgroup:

| Highest count pattern | Sister pair | Outgroup |
|-----------------------|-------------|---------|
| `AB_shared`           | A + B       | C       |
| `AC_shared`           | A + C       | B       |
| `BC_shared`           | B + C       | A       |

---

## Quick result checks

```bash
# Repeat libraries (all 3 species)
ls -lh results/repeat_modeler/*-families.fa

# Final MAFs (two reference runs)
ls -lh results/last_alignment_rosea_ref/seq1_seq2_seq3_joined.maf
ls -lh results/last_alignment_margarita_ref/seq1_seq2_seq3_joined.maf

# Insertion counts per pattern (100 bp, rosea ref)
grep -c ">" results/candidate_insertions_100bp_rosea_ref/*.fasta

# Verdict reports
cat log/final_outgroup_report_rosea_ref.log
cat log/final_outgroup_report_margarita_ref.log

# TSD confirmation summary
cat log/tsd_summary_rosea_ref.tsv
cat log/tsd_summary_margarita_ref.tsv

# Experiment log (tracked in git)
cat tasks/experiments/20260401_amf_gigaspora_baseline.md
```

---

## Multi-trio execution

For applying the pipeline to many trios from the curated 81-trio dataset
(see `tasks/experiments/2026-06-08_multitrio_campaign.md`), use the
wrapper:

```bash
# 1. Build the trio inventory once from the listing files in data/tmp/
python3 scripts/build_trios_tsv.py
# → writes data/trios.tsv (trio_name, clade, role, code, accession, notes)

# 2. Pick a trio and dry-run to see the planned commands
bash scripts/run_trio.sh Denhet1_Gigros2_Gigmar3 --dry-run

# 3. Real run (inside tmux — RepeatModeler + alignment can take days)
tmux new -s Denhet1_Gigros2_Gigmar3
bash scripts/run_trio.sh Denhet1_Gigros2_Gigmar3
# Ctrl-b d to detach
```

`run_trio.sh` drives `dwl → repeat_modeler ×3 → mask → bed → align →
rename → integrate → tsd → report`, isolating outputs under a
`_<trio_name>` suffix:

```
results/last_alignment_<trio>/
results/candidate_insertions_{50,100}bp_<trio>/
log/final_outgroup_report_<trio>.log
log/tsd_summary_<trio>.tsv
log/run_trio_<trio>.{log,status}
```

Resume mid-pipeline with `--from <step>` (steps: `download`,
`repeat_modeler`, `mask`, `bed`, `align`, `rename_align`, `integrate`,
`tsd`, `report`). The wrapper refuses to start the `align` step when
`results/last_alignment/` already exists, so a half-finished previous
run won't be silently clobbered.

Trios with shared species across the dataset (12 of 81) are flagged
`dup_species_across_trios` in `data/trios.tsv`; their RepeatModeler step
is a no-op on the second run because the per-accession library is
already in `results/repeat_modeler/`.

## References

- LAST: https://gitlab.com/mcfrith/last
- RepeatModeler/RepeatMasker: https://www.repeatmasker.org/
- SINE phylogenomics: Shedlock & Okada (2000), *SINE insertions: Powerful tools for molecular systematics*
