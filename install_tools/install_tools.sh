#!/usr/bin/env bash
### put this file to scripts/install_tools.sh
### conda install for:
### pbmm2
### isoseq
### pigeon
### samtools
### minimap2
### singularity is often more useful:
### CTAT-LR-fusion
### JAFFAL
### TEchim
### sometimes SQANTI3
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${PROJECT_DIR}/config.sh"

mkdir -p "${CONTAINERS}"

echo "[INFO] Installing mamba into base conda"
conda install -y -n base -c conda-forge mamba

echo "[INFO] Creating core conda environment"
mamba create -y -n "${ENV_CORE}" \
  -c bioconda -c conda-forge \
  samtools bedtools seqkit csvtk pigz jq parallel \
  minimap2 pbmm2 isoseq pigeon \
  gffread gffcompare fastqc multiqc

echo "[INFO] Creating FLAIR conda environment"
mamba create -y -n "${ENV_FLAIR}" \
  -c bioconda -c conda-forge \
  flair samtools bedtools minimap2

echo "[INFO] Creating SQANTI3 conda environment"
mamba create -y -n "${ENV_SQANTI3}" \
  -c bioconda -c conda-forge \
  python=3.10 samtools minimap2 gffread bedtools \
  biopython scipy pandas numpy matplotlib seaborn \
  r-base r-essentials pip

conda run -n "${ENV_SQANTI3}" pip install sqanti3

echo "[INFO] Conda environments created"

echo "[INFO] Checking singularity/apptainer"
if command -v apptainer >/dev/null 2>&1; then
    SINGCMD="apptainer"
elif command -v singularity >/dev/null 2>&1; then
    SINGCMD="singularity"
else
    echo "[ERROR] apptainer/singularity not found"
    exit 1
fi

echo "[INFO] Using ${SINGCMD}"

echo "[INFO] Pull container images if available from docker/library sources"
echo "[INFO] You may need to replace these with images available on your HPC"

# These are templates. Replace if your HPC uses local registry images.
# Example pulls:
# ${SINGCMD} pull "${SQANTI3_SIF}" docker://continuumio/miniconda3
# ${SINGCMD} pull "${CTATLR_SIF}" docker://trinityctat/ctat-lr-fusion
# ${SINGCMD} pull "${JAFFAL_SIF}" docker://biocontainers/bpipe:v0.9.11_cv3
# ${SINGCMD} pull "${TECHIM_SIF}" docker://ubuntu:22.04

echo "[INFO] Installation script finished"
echo "[INFO] Core tools use conda"
echo "[INFO] Fusion / TE tools are recommended through singularity containers or dedicated site installs"
