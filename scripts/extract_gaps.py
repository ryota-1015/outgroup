import sys

# Usage: python3 extract_maf_gaps.py ../results/last_alignment/seq1_seq2_seq3_joined.maf
def parse_maf(maf_path):
    with open(maf_path, 'r') as f:
        block = {}
        for line in f:
            if line.startswith('s '):
                parts = line.split()
                # parts: [s, taxon.chr, start, size, strand, srcSize, sequence]
                taxon_chr = parts[1]
                taxon = taxon_chr.split('.')[0]
                start = int(parts[2])
                seq = parts[6]
                block[taxon] = {"ref": taxon_chr, "start": start, "seq": seq}
            elif line.strip() == "" and block:
                process_block(block)
                block = {}

def process_block(block):
    taxa = sorted(block.keys())
    if len(taxa) < 3: return
    
    seq_len = len(block[taxa[0]]["seq"])
    
    for t in taxa:
        others = [taxon for taxon in taxa if taxon != t]
        
        # Track continuous segments of unique sequence
        current_start = -1
        
        for i in range(seq_len):
            base = block[t]["seq"][i]
            other_bases = [block[o]["seq"][i] for o in others]
            
            # Condition: One taxon has a base, others have '-'
            is_unique = (base != '-') and all(b == '-' for b in other_bases)
            
            if is_unique:
                if current_start == -1:
                    # Calculate genomic start position
                    g_start = block[t]["start"] + block[t]["seq"][:i].replace('-', '').__len__()
                    current_start = g_start
            else:
                if current_start != -1:
                    # End of unique segment
                    g_end = block[t]["start"] + block[t]["seq"][:i].replace('-', '').__len__()
                    print(f"{block[t]['ref']}\t{current_start}\t{g_end}\t{t}_unique")
                    current_start = -1

if __name__ == "__main__":
    if len(sys.argv) > 1:
        parse_maf(sys.argv[1])