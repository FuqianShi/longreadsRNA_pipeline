#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${PROJECT_DIR}/config.sh"

mkdir -p "${CONTAINERS}"

#echo "[INFO] Installing mamba into base conda"
#conda install -y -n base -c conda-forge mamba

conda clean -i -y


echo "[INFO] Creating core conda environment"
mamba create -y -n "${ENV_CORE}" \
  -c bioconda -c conda-forge \
  samtools bedtools seqkit csvtk pigz jq parallel \
  minimap2 pbmm2 isoseq pbpigeon \
  gffread gffcompare fastqc multiqc

echo "[INFO] Creating FLAIR conda environment"

conda clean -i -y

mamba create -y -n "${ENV_FLAIR}" \
  -c conda-forge -c bioconda \
  python=3.12 \
  flair=3.0.0 \
  samtools \
  bedtools \
  minimap2

#echo "[INFO] Creating SQANTI3 conda environment"
#mamba create -y -n "${ENV_SQANTI3}" \
#  -c bioconda -c conda-forge \
#  python=3.10 samtools minimap2 gffread bedtools \
#  biopython scipy pandas numpy matplotlib seaborn \
#  r-base r-essentials pip

## use this
git clone https://github.com/ConesaLab/SQANTI3.git
cd SQANTI3
mamba env create -n "${ENV_SQANTI3}" -f SQANTI3.conda_env.yml
cd  ../

#echo "[INFO] Conda environments created"

#echo "[INFO] Checking singularity/apptainer"
#if command -v apptainer >/dev/null 2>&1; then
#    SINGCMD="apptainer"
#elif command -v singularity >/dev/null 2>&1; then
#    SINGCMD="singularity"
#else
#    echo "[ERROR] apptainer/singularity not found"
#    exit 1
#fi

#echo "[INFO] Using ${SINGCMD}"

echo "[INFO] Pull container images if available from docker/library sources"
echo "[INFO] You may need to replace these with images available on your HPC"


# These are templates. Replace if your HPC uses local registry images.
# Example pulls:
# ${SINGCMD} pull "${SQANTI3_SIF}" docker://continuumio/miniconda3
# ${SINGCMD} pull "${CTATLR_SIF}" docker://trinityctat/ctat-lr-fusion
# ${SINGCMD} pull "${JAFFAL_SIF}" docker://biocontainers/bpipe:v0.9.11_cv3
# ${SINGCMD} pull "${TECHIM_SIF}" docker://ubuntu:22.04

# use modules on HPC
module load singularity

## /path/to/container
cd "$CONTAINERS"
# pull CTAT-LR-fusion
singularity pull ctat_lr_fusion_1.4.0.sif docker://trinityctat/ctat_lr_fusion:1.4.0
echo "[INFO] CTAT-LR-fusion with singularity finished"

singularity cache clean
singularity pull jaffa_v2.3.sif docker://brianyee/jaffa:2.3
echo "[INFO] Core tools use conda"

echo "[INFO] Fusion / TE tools are recommended through singularity containers or dedicated site installs"
