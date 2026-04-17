#!/usr/bin/env bash
# Please provide:
### refs/genome.fa
### refs/gencode.gtf
### optionally refs/repeatmasker_hg38.bed
### if using CTAT-LR-fusion:
### refs/ctat_genome_lib
### if using JAFFAL:
### refs/jaffa_ref
### actual .sif image files in containers/
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${PROJECT_DIR}/config.sh"

mkdir -p "${PROJECT_DIR}/refs"

if [[ ! -f "${GENOME}" ]]; then
    echo "[ERROR] Missing genome fasta: ${GENOME}"
    exit 1
fi

if [[ ! -f "${GTF}" ]]; then
    echo "[ERROR] Missing GTF: ${GTF}"
    exit 1
fi

echo "[INFO] Indexing genome"
conda run -n "${ENV_CORE}" samtools faidx "${GENOME}"

if [[ ! -f "${PROJECT_DIR}/refs/genome.mmi" ]]; then
    echo "[INFO] Building minimap2 index"
    conda run -n "${ENV_CORE}" minimap2 -d "${PROJECT_DIR}/refs/genome.mmi" "${GENOME}"
fi

echo "[INFO] Reference preparation finished"
