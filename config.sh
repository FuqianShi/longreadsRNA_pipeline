#!/usr/bin/env bash

# threads
export THREADS=20

# project root
export PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# references
export GENOME="${PROJECT_DIR}/refs/genome.fa"
export GTF="${PROJECT_DIR}/refs/gencode.gtf"
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
export SQANTI3_DIR="/projects/foran/Team_Chan/shi/PacBio_HiFi_RNA/pacbio_lrna/SQANTI3"
export SQANTI3_QC="${SQANTI3_DIR}/sqanti3_qc.py"
export ENV_SQANTI3="lrna_sqanti3"
export ENV_FLAIR="lrna_flair"

# singularity/apptainer images
export SQANTI3_SIF="${CONTAINERS}/sqanti3.sif"
export CTATLR_SIF="${CONTAINERS}/ctat_lr_fusion.sif"
export JAFFAL_SIF="${CONTAINERS}/jaffa_v2.3.sif"
export JAFFAL_DIR="/opt/conda/share/jaffa-2.3-0"
export TECHIM_SIF="${CONTAINERS}/techim.sif"
