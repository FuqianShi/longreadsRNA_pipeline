# This pipeline executes tasks in the following order:
1. QC
2. BAM to FASTQ
3. pbmm2 alignment
4. minimap2 alignment
5. isoseq collapse
6. pigeon classify/filter
7. SQANTI3 QC
8. FLAIR transcriptome/splicing
9. CTAT-LR-fusion
10. JAFFAL
11. Extract FGFR2 / ERBB4 / RET hits
12. TE-gene overlap screen
13. Final summary table
# files structure
pacbio_lrna/ \
├── hifi_reads/ \
├── refs/ \
├── results/ \
├── logs/ \
├── scripts/ \
&emsp; &emsp;  ├── install_tools.sh \
&emsp; &emsp;  ├── prepare_refs.sh \
├── containers/ \
├── samples.tsv \
├── config.sh \
└── run_lrna.sh 
# Tools used
## install with conda:
pbmm2 \
isoseq \
pigeon \
samtools \
minimap2 \
SQANTI3 
## install with singularity:
CTAT-LR-fusion \
JAFFAL \
TEchim 
# Prepare the references
refs/genome.fa \
refs/gencode.gtf \ 
optionally refs/repeatmasker_hg38.bed \
if using CTAT-LR-fusion: \
refs/ctat_genome_lib \
if using JAFFAL: \
refs/jaffa_ref \
# run order
bash scripts/install_tools.sh \
bash scripts/prepare_refs.sh \
bash run_lrna.sh | tee logs/run_all.log 
**or by steps** \
bash run_lrna.sh --all \
bash run_lrna.sh --core \
bash run_lrna.sh --fusion \
bash run_lrna.sh --te \
bash run_lrna.sh --qc \
bash run_lrna.sh --align \
bash run_lrna.sh --isoseq \
bash run_lrna.sh --sqanti3 \
bash run_lrna.sh --flair \
bash run_lrna.sh --summary 
**or by sample**\
bash run_lrna.sh --sample SAMPLEID --core \
bash run_lrna.sh --sample SAMPLEID --fusion
