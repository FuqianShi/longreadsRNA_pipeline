#!/usr/bin/env bash

# threads
export THREADS=10

# project root
export PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# references
export GENOME="/path/to/Homo_sapiens_assembly38.fasta"
export GTF="${PROJECT_DIR}/refs/gencode.gtf"
export GTF_SORTED="${PROJECT_DIR}/refs/gencode.sorted.gtf"
export TEBED="${PROJECT_DIR}/refs/repeatmasker_hg38.bed"

# samples
export SAMPLES="${PROJECT_DIR}/samples.tsv"

# output
export RESULTS="${PROJECT_DIR}/results"
export LOGS="${PROJECT_DIR}/logs"
export CONTAINERS="${PROJECT_DIR}/containers"

# ctat / jaffa references if used
export CTAT_GENOME_LIB="${PROJECT_DIR}/refs/ctat_genome_lib"
export JAFFA_REF="${PROJECT_DIR}/refs/jaffa_ref"

# conda env names
export ENV_CORE="lrna_core"
export ENV_SQANTI3="lrna_sqanti3"
export ENV_FLAIR="lrna_flair"
# SQANTI3
export SQANTI3_QC="${SQANTI3_DIR}/sqanti3_qc.py"
export SQANTI3_DIR="/path/to/SQANTI3"  ## the path 

# singularity/apptainer images
export CTATLR_SIF="${CONTAINERS}/ctat_lr_fusion_1.4.0.sif"
export JAFFAL_SIF="${CONTAINERS}/jaffa_v2.3.sif"
export JAFFAL_DIR="/opt/conda/share/jaffa-2.3-0"
export JAFFA_TOOLS_GROOVY="${PROJECT_DIR}/refs/jaffa_ref/tools.groovy"
