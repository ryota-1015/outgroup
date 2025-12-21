#!/bin/bash

# Configuration
BASE_DIR=/home/co_ryota/outgroup
FILTERED_DIR=$BASE_DIR/results/candidate_insertions/filtered

# Files
G1=$FILTERED_DIR/GCA_001444195.3_high_quality.bed
G2=$FILTERED_DIR/GCA_002775205.2_high_quality.bed
G3=$FILTERED_DIR/GCA_036418095.1_high_quality.bed

echo Shared RT-insertion counts:

# Compare G1 and G2
count12=$(bedtools intersect -a $G1 -b $G2 | wc -l)
echo GCA_001444195.3 and GCA_002775205.2 share: $count12

# Compare G1 and G3
count13=$(bedtools intersect -a $G1 -b $G3 | wc -l)
echo GCA_001444195.3 and GCA_036418095.1 share: $count13

# Compare G2 and G3
count23=$(bedtools intersect -a $G2 -b $G3 | wc -l)
echo GCA_002775205.2 and GCA_036418095.1 share: $count23