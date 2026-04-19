#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${PROJECT_DIR}/config.sh"

mkdir -p "${PROJECT_DIR}/refs"
mkdir -p "${PROJECT_DIR}/results/03_isoseq/pigeon_ref"

echo "[INFO] Checking required reference files"

[[ -f "${GENOME}" ]] || { echo "[ERROR] Missing genome fasta: ${GENOME}"; exit 1; }
[[ -f "${GTF}" ]] || { echo "[ERROR] Missing GTF: ${GTF}"; exit 1; }

echo "[INFO] Index genome with samtools"
conda run -n "${ENV_CORE}" samtools faidx "${GENOME}"

echo "[INFO] Build minimap2 index"
if [[ ! -f "${PROJECT_DIR}/refs/genome.mmi" ]]; then
    conda run -n "${ENV_CORE}" minimap2 -d "${PROJECT_DIR}/refs/genome.mmi" "${GENOME}"
fi

echo "[INFO] Prepare pigeon annotation"
if [[ ! -f "${PROJECT_DIR}/results/03_isoseq/pigeon_ref/annotation.sorted.gtf" ]]; then
    conda run -n "${ENV_CORE}" pigeon prepare \
        "${GTF}" \
        "${GENOME}" \
        "${PROJECT_DIR}/results/03_isoseq/pigeon_ref/annotation"
fi

echo "[INFO] Check TE BED"
if [[ -f "${TEBED}" ]]; then
    echo "[INFO] Found TE BED: ${TEBED}"
else
    echo "[WARNING] Missing TE BED: ${TEBED}"
    echo "[WARNING] TE step will be skipped until you create repeatmasker_hg38.bed"
fi

echo "[INFO] Check CTAT genome lib"
if [[ -d "${CTAT_GENOME_LIB}" ]] && [[ "$(ls -A "${CTAT_GENOME_LIB}" 2>/dev/null)" ]]; then
    echo "[INFO] Found CTAT genome library: ${CTAT_GENOME_LIB}"
else
    echo "[WARNING] CTAT genome library missing or empty: ${CTAT_GENOME_LIB}"
    echo "[WARNING] CTAT-LR-fusion step will be skipped until this is prepared"
fi

echo "[INFO] Check JAFFA ref dir"
if [[ -d "${JAFFA_REF}" ]]; then
    echo "[INFO] Found JAFFA ref dir: ${JAFFA_REF}"
else
    echo "[WARNING] Missing JAFFA ref dir: ${JAFFA_REF}"
fi

echo "[INFO] Reference preparation check complete"
