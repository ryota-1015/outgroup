import sys
import os

# Species Map: 
# A = CM008938.1
# B = CM010726.1
# C = CM071326.1
species_list = ["CM008938.1", "CM010726.1", "CM071326.1"]

def parse_maf(maf_path, min_len):
    with open(maf_path, 'r') as f:
        block = {}
        for line in f:
            if line.startswith('s '):
                parts = line.split()
                taxon = parts[1]
                start = int(parts[2])
                seq = parts[6]
                if taxon in species_list:
                    block[taxon] = {"start": start, "seq": seq}
            elif line.strip() == "" and block:
                process_block(block, min_len)
                block = {}

def process_block(block, min_len):
    if not all(sp in block for sp in species_list):
        return
    
    seq_len = len(block[species_list[0]]["seq"])
    
    # Track all 6 possible presence/absence patterns
    patterns = {
        "BC_shared": [False, True, True],   # Shared by B & C
        "AB_shared": [True, True, False],   # Shared by A & B
        "AC_shared": [True, False, True],   # Shared by A & C
        "A_only":    [True, False, False],  # Unique to A
        "B_only":    [False, True, False],  # Unique to B
        "C_only":    [False, False, True]   # Unique to C
    }
    
    current_starts = {k: -1 for k in patterns.keys()}
    
    for i in range(seq_len):
        p = [block[sp]["seq"][i] != '-' for sp in species_list]
        
        for key, match_p in patterns.items():
            if p == match_p:
                if current_starts[key] == -1: current_starts[key] = i
            else:
                if current_starts[key] != -1:
                    # ASSIGN THE CORRECT COORDINATE REFERENCE
                    if key in ["BC_shared", "B_only"]:
                        ref_sp = "CM010726.1" # Species B
                    elif key == "C_only":
                        ref_sp = "CM071326.1" # Species C
                    else:
                        ref_sp = "CM008938.1" # Species A (for AB, AC, A_only)
                    
                    g_start = block[ref_sp]["start"] + block[ref_sp]["seq"][:current_starts[key]].replace('-', '').__len__()
                    g_end = block[ref_sp]["start"] + block[ref_sp]["seq"][:i].replace('-', '').__len__()
                    
                    if (g_end - g_start) >= min_len:
                        fname = f"pattern_{key}_{min_len}bp.bed"
                        write_to_file(fname, ref_sp, g_start, g_end, f"pattern_{key}")
                    current_starts[key] = -1

def write_to_file(filename, chrom, start, end, label):
    with open(filename, 'a') as out:
        out.write(f"{chrom}\t{start}\t{end}\t{label}\n")

if __name__ == "__main__":
    maf_input = sys.argv[1]
    threshold = int(sys.argv[2])
    keys = ["BC_shared", "AB_shared", "AC_shared", "A_only", "B_only", "C_only"]
    for k in keys:
        f = f"pattern_{k}_{threshold}bp.bed"
        if os.path.exists(f): os.remove(f)
    parse_maf(maf_input, threshold)