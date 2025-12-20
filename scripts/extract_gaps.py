import sys

# Reference species names as they appear in the MAF file
species_list = [
    "CM008938.1",
    "CM010726.1",
    "CM071326.1"
]

def parse_maf(maf_path):
    with open(maf_path, 'r') as f:
        block = {}
        for line in f:
            if line.startswith('s '):
                parts = line.split()
                taxon = parts[1]
                start = int(parts[2])
                seq = parts[6]
                if taxon in species_list:
                    block[taxon] = {"ref": taxon, "start": start, "seq": seq}
            elif line.strip() == "" and block:
                process_block(block)
                block = {}

def process_block(block):
    if not all(sp in block for sp in species_list):
        return
    
    seq_len = len(block[species_list[0]]["seq"])
    current_starts = {"BC": -1, "AB": -1, "AC": -1}
    
    for i in range(seq_len):
        p = [block[sp]["seq"][i] != '-' for sp in species_list]
        
        # BC shared, A missing (A is outgroup)
        if p == [False, True, True]:
            if current_starts["BC"] == -1: current_starts["BC"] = i
        else:
            if current_starts["BC"] != -1:
                g_start = block["CM010726.1"]["start"] + block["CM010726.1"]["seq"][:current_starts["BC"]].replace('-', '').__len__()
                g_end = block["CM010726.1"]["start"] + block["CM010726.1"]["seq"][:i].replace('-', '').__len__()
                # FILTER: Only keep high-confidence biological markers
                if (g_end - g_start) >= 50:
                    write_to_file("shared_BC_vs_A.bed", "CM010726.1", g_start, g_end, "shared_BC")
                current_starts["BC"] = -1

        # AB shared, C missing (C is outgroup)
        if p == [True, True, False]:
            if current_starts["AB"] == -1: current_starts["AB"] = i
        else:
            if current_starts["AB"] != -1:
                g_start = block["CM008938.1"]["start"] + block["CM008938.1"]["seq"][:current_starts["AB"]].replace('-', '').__len__()
                g_end = block["CM008938.1"]["start"] + block["CM008938.1"]["seq"][:i].replace('-', '').__len__()
                if (g_end - g_start) >= 50:
                    write_to_file("shared_AB_vs_C.bed", "CM008938.1", g_start, g_end, "shared_AB")
                current_starts["AB"] = -1

        # AC shared, B missing (B is outgroup)
        if p == [True, False, True]:
            if current_starts["AC"] == -1: current_starts["AC"] = i
        else:
            if current_starts["AC"] != -1:
                g_start = block["CM008938.1"]["start"] + block["CM008938.1"]["seq"][:current_starts["AC"]].replace('-', '').__len__()
                g_end = block["CM008938.1"]["start"] + block["CM008938.1"]["seq"][:i].replace('-', '').__len__()
                if (g_end - g_start) >= 50:
                    write_to_file("shared_AC_vs_B.bed", "CM008938.1", g_start, g_end, "shared_AC")
                current_starts["AC"] = -1

def write_to_file(filename, chrom, start, end, label):
    with open(filename, 'a') as out:
        out.write(f"{chrom}\t{start}\t{end}\t{label}\n")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        for f in ["shared_BC_vs_A.bed", "shared_AB_vs_C.bed", "shared_AC_vs_B.bed"]:
            open(f, 'w').close()
        parse_maf(sys.argv[1])