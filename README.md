HEAD
Outgroup Verification via Comparative Retrotransposon Analysis
Introduction
This pipeline aims to verify the phylogenetic outgroup relationship among three taxa. By distinguishing between random genomic deletions and complex biological insertions (specifically Retrotransposons and other mobile genetic elements), we can infer high-confidence evolutionary branching.

Core Logic
Deletion vs. Insertion: Random deletions are common and uninformative for outgroup rooting. However, a shared complex insertion (Retrotransposon) at a specific locus is a strong synapomorphy.
Verification Criteria:If Taxon A has a gap while B and C share a Retrotransposon (RT) at the same position, A is confirmed as the outgroup.If B and C have a gap while A has an RT, A is confirmed as the outgroup.Simple gaps without identifiable insertion elements are treated as inconclusive deletions.

1. DependenciesThe following tools must be installed and available in your $PATH:
NCBI Datasets CLI: Genome acquisition.
LAST: Pairwise and multiple sequence alignment.
RepeatModeler2 & RepeatMasker: De novo repeat discovery and characterization.
bedtools: Coordinate intersection (integration phase).
Phylogenetic Tools: ML (e.g., IQ-TREE) and NJ (e.g., MEGA/PHYLIP).

2. Project StructureThe scripts expect the following directory hierarchy:Plaintext~/outgroup/
├── data/       # Downloaded FASTA genomes
├── log/        # Timestamped execution logs
├── results/    # Alignment (.maf) and Repeat (.fa, .out) outputs
└── scripts/    # Shell and Python scripts

3. Usage Pipeline
Step 1: Data AcquisitionDownload the target genome assemblies from NCBI.Bash# Edit ACCESSIONS in the script if necessary
bash scripts/dwl.sh
Step 2: Whole-Genome Alignment (WGA)Perform 3-way alignment using LAST. The first argument should be the intended outgroup/reference.Bashcd scripts
bash align.sh <Ref_A.fasta> <Query_B.fasta> <Query_C.fasta>
Output: results/last_alignment/seq1_seq2_seq3_joined.maf
Step 3: Repeat Discovery and CharacterizationIdentify de novo repeat families and mask the genomes to detect insertion signatures.Bashbash scripts/repeat.sh
Process: Sanitizes headers $\rightarrow$ BuildDatabase $\rightarrow$ RepeatModeler $\rightarrow$ RepeatMasker.Key Output: results/repeat_modeler/families.fa (The custom repeat library).
Step 4: Integration and Outgroup VerificationExtract Gaps: Identify regions in the .maf file where one taxon lacks sequence relative to the others.Verify RT Identity: Check if the insertion sequence contains Reverse Transcriptase (RT) domains or processed genes.Phylogenetic Testing: Extract the insertion sequences and run ML/NJ trees to confirm monophyly.4. Methodology NotesHeader Sanitization: repeat.sh renames headers to seq_1, seq_2... to prevent RepeatModeler crashes caused by complex NCBI naming conventions.Filtering: Alignment quality is controlled via last-split to ensure one-to-one orthology before integration.Parsimony: Substitution trends and insertion events are interpreted based on the principle of parsimony.

