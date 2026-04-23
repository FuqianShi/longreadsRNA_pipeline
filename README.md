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
10. Extract FGFR2 / ERBB4 / RET hits
11. TE-gene overlap screen
12. Final summary table
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
CTAT-LR-fusion
# Prepare the references
refs/genome.fa ## set the right path to genome in config.sh \
refs/gencode.gtf ## set the right path to genome in config.sh \
refs/genome.mmi  ## get from minimap2 \
refs/repeatmasker_hg38.bed ## download rmsk.txt.gz and make the bed file \
refs/ctat_genome_lib \
refs/gencode.sorted.gtf.pgi  ## get from pigeon prepare \
refs/gencode.sorted.gtf ## get from pigeon prepare

**Usage:** \
  bash run_all_v2.sh [options] 
  
**Main switches:** \
  --all         Run all steps \
  --core        Run core transcriptome workflow: QC + align + isoseq/pigeon + sqanti3 + flair + summary \
  --fusion      Run fusion workflow only \
  --te          Run TE overlap workflow only 

**Step-specific switches:** \
  --qc          Run QC + FASTQ conversion \
  --align       Run pbmm2 + minimap2 alignment \
  --isoseq      Run isoseq collapse + pigeon \
  --sqanti3     Run SQANTI3 \
  --flair       Run FLAIR \
  --summary     Run summary tables only 
  
**Optional:** \
  --sample ID   Run only one sample \
  --help        Show this help 
  
**Examples:** \
  bash run_all_v2.sh --all \
  bash run_all_v2.sh --core \
  bash run_all_v2.sh --fusion \
  bash run_all_v2.sh --te \
  bash run_all_v2.sh --sample SAMPLEID --core \
  bash run_all_v2.sh --sample SAMPLEID --fusion

