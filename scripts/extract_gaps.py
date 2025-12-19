import sys

# Reference species names
species_list = [
    "GCA_001444195.3",
    "GCA_002775205.2",
    "GCA_036418095.1"
]

def parse_maf(maf_path):
    with open(maf_path, 'r') as f:
        block = {}
        for line in f:
            if line.startswith('s '):
                parts = line.split()
                # taxon.chr
                taxon_chr = parts[1]
                taxon = ".".join(taxon_chr.split('.')[:2])
                start = int(parts[2])
                seq = parts[6]
                block[taxon] = {"ref": taxon_chr, "start": start, "seq": seq}
            elif line.strip() == "" and block:
                process_block(block)
                block = {}

def write_to_file(filename, chrom, start, end, label):
    with open(filename, 'a') as out:
        out.write(f"{chrom}\t{start}\t{end}\t{label}\n")

def process_block(block):
    # Ensure all three taxa are in the block
    if not all(sp in block for sp in species_list):
        return
    
    seq_len = len(block[species_list[0]]["seq"])
    
    # We track 3 possible shared states
    # state_BC (B&C have base, A has gap), state_AB, state_AC
    current_starts = {"BC": -1, "AB": -1, "AC": -1}
    
    for i in range(seq_len):
        # Presence/Absence at this specific column
        p = [block[sp]["seq"][i] != '-' for sp in species_list] # [A, B, C]
        
        # Scenario: Shared by B and C, A is missing (A=Outgroup)
        if p == [False, True, True]:
            if current_starts["BC"] == -1:
                current_starts["BC"] = i
        else:
            if current_starts["BC"] != -1:
                # Calculate genomic coordinates for species B
                ref = block[species_list[1]]["ref"]
                g_start = block[species_list[1]]["start"] + block[species_list[1]]["seq"][:current_starts["BC"]].replace('-', '').__len__()
                g_end = block[species_list[1]]["start"] + block[species_list[1]]["seq"][:i].replace('-', '').__len__()
                write_to_file("shared_BC_vs_A.bed", ref, g_start, g_end, "shared_BC")
                current_starts["BC"] = -1

        # Scenario: Shared by A and B, C is missing (C=Outgroup)
        if p == [True, True, False]:
            if current_starts["AB"] == -1:
                current_starts["AB"] = i
        else:
            if current_starts["AB"] != -1:
                ref = block[species_list[0]]["ref"]
                g_start = block[species_list[0]]["start"] + block[species_list[0]]["seq"][:current_starts["AB"]].replace('-', '').__len__()
                g_end = block[species_list[0]]["start"] + block[species_list[0]]["seq"][:i].replace('-', '').__len__()
                write_to_file("shared_AB_vs_C.bed", ref, g_start, g_end, "shared_AB")
                current_starts["AB"] = -1

        # Scenario: Shared by A and C, B is missing (B=Outgroup)
        if p == [True, False, True]:
            if current_starts["AC"] == -1:
                current_starts["AC"] = i
        else:
            if current_starts["AC"] != -1:
                ref = block[species_list[0]]["ref"]
                g_start = block[species_list[0]]["start"] + block[species_list[0]]["seq"][:current_starts["AC"]].replace('-', '').__len__()
                g_end = block[species_list[0]]["start"] + block[species_list[0]]["seq"][:i].replace('-', '').__len__()
                write_to_file("shared_AC_vs_B.bed", ref, g_start, g_end, "shared_AC")
                current_starts["AC"] = -1

if __name__ == "__main__":
    if len(sys.argv) > 1:
        # Clear/Initialize files
        for f in ["shared_BC_vs_A.bed", "shared_AB_vs_C.bed", "shared_AC_vs_B.bed"]:
            open(f, 'w').close()
        parse_maf(sys.argv[1])