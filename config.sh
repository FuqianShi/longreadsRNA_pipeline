export THREADS=20

export PROJECT_DIR="/path/to/pacbio_lrna"

export GENOME="${PROJECT_DIR}/refs/genome.fa"
export GTF="${PROJECT_DIR}/refs/gencode.gtf"
export TEBED="${PROJECT_DIR}/refs/repeatmasker_hg38.bed"

export SAMPLES="${PROJECT_DIR}/samples.tsv"
export RESULTS="${PROJECT_DIR}/results"
export LOGS="${PROJECT_DIR}/logs"
export CONTAINERS="${PROJECT_DIR}/containers"

export CTAT_GENOME_LIB="${PROJECT_DIR}/refs/ctat_genome_lib"

export ENV_CORE="lrna_core"
export ENV_SQANTI3="lrna_sqanti3"
export ENV_FLAIR="lrna_flair"

export SQANTI3_SIF="${CONTAINERS}/sqanti3.sif"
export CTATLR_SIF="${CONTAINERS}/ctat_lr_fusion.sif"
export JAFFAL_SIF="${CONTAINERS}/jaffal.sif"
export TECHIM_SIF="${CONTAINERS}/techim.sif"
