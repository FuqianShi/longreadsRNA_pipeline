# This runs will get tasks in one order:
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
# Tools used
## using conda for:
pbmm2 \
isoseq \
pigeon \
samtools \
minimap2 
## singularity for:
CTAT-LR-fusion \
JAFFAL \
TEchim \
sometimes SQANTI3 
# Prepare the references
refs/genome.fa \
refs/gencode.gtf \ 
optionally refs/repeatmasker_hg38.bed \
if using CTAT-LR-fusion: \
refs/ctat_genome_lib \
if using JAFFAL: \
refs/jaffa_ref \
actual .sif image files in containers/ 
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
└── run_all.sh 
# run order
bash scripts/install_tools.sh \
bash scripts/prepare_refs.sh \
bash run_all.sh | tee logs/run_all.log \
or by steps \
bash run_all_v2.sh --all \
bash run_all_v2.sh --core \
bash run_all_v2.sh --fusion \
bash run_all_v2.sh --te \
bash run_all_v2.sh --qc \
bash run_all_v2.sh --align \
bash run_all_v2.sh --isoseq \
bash run_all_v2.sh --sqanti3 \
bash run_all_v2.sh --flair \
bash run_all_v2.sh --summary \
or by sample \
bash run_all_v2.sh --sample SAMPLEID --core \
bash run_all_v2.sh --sample SAMPLEID --fusion \
