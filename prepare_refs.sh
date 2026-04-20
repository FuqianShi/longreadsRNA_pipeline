#!/usr/bin/env bash
## suggest to install tools one by one
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${PROJECT_DIR}/config.sh"

log() {
    echo "[$(date '+%F %T')] $*"
}

die() {
    echo "[ERROR] $*" >&2
    exit 1
}

download_file() {
    local url="$1"
    local out="$2"

    if command -v wget >/dev/null 2>&1; then
        wget -O "$out" "$url"
    elif command -v curl >/dev/null 2>&1; then
        curl -L "$url" -o "$out"
    else
        die "Neither wget nor curl found for downloading"
    fi
}

log "Starting reference preparation and validation"

mkdir -p "${PROJECT_DIR}/refs"

###############################################################################
# 1. Required core references
###############################################################################
[[ -f "${GENOME}" ]] || die "Missing genome FASTA: ${GENOME}"
[[ -f "${GTF}" ]] || die "Missing gene annotation GTF: ${GTF}"

log "Genome FASTA found: ${GENOME}"
log "Gene annotation GTF found: ${GTF}"

###############################################################################
# 2. samtools FASTA index
###############################################################################
if [[ -f "${GENOME}.fai" ]]; then
    log "samtools FASTA index exists"
else
    log "Building samtools FASTA index"
    conda run -n "${ENV_CORE}" samtools faidx "${GENOME}"
fi

###############################################################################
# 3. minimap2 index
###############################################################################
MMI_PATH="${PROJECT_DIR}/refs/genome.mmi"

if [[ -f "${MMI_PATH}" ]]; then
    log "minimap2 index exists"
else
    log "Building minimap2 index"
    conda run -n "${ENV_CORE}" minimap2 -d "${MMI_PATH}" "${GENOME}"
fi

###############################################################################
# 4. Pigeon prepare (in-place)
###############################################################################
GTF_SORTED="${PROJECT_DIR}/refs/gencode.sorted.gtf"
GTF_PGI="${PROJECT_DIR}/refs/gencode.sorted.gtf.pgi"

if [[ -f "${GTF_SORTED}" && -f "${GTF_PGI}" ]]; then
    log "Pigeon annotation already prepared"
else
    log "Running pigeon prepare on GTF"
    conda run -n "${ENV_CORE}" pigeon prepare "${GTF}"
fi

###############################################################################
# 5. TE reference: download + build BED
###############################################################################
TE_RMSK_GZ="${PROJECT_DIR}/refs/rmsk.txt.gz"
TEBED="${PROJECT_DIR}/refs/repeatmasker_hg38.bed"

if [[ -f "${TEBED}" ]]; then
    log "TE BED already exists"
else
    log "Preparing RepeatMasker TE BED"

    if [[ ! -f "${TE_RMSK_GZ}" ]]; then
        log "Downloading rmsk.txt.gz"

        download_file \
            "https://hgdownload.soe.ucsc.edu/goldenPath/hg38/database/rmsk.txt.gz" \
            "${TE_RMSK_GZ}"

        [[ -s "${TE_RMSK_GZ}" ]] || die "Download failed: rmsk.txt.gz is empty"
    else
        log "Using existing rmsk.txt.gz"
    fi

    log "Converting to BED"

    zcat "${TE_RMSK_GZ}" | \
        awk 'BEGIN{OFS="\t"} {print $6,$7,$8,$12}' | \
        sort -k1,1 -k2,2n \
        > "${TEBED}"

    [[ -s "${TEBED}" ]] || die "TE BED creation failed"

    log "TE BED created: ${TEBED}"
fi

###############################################################################
# 6. CTAT genome library check
###############################################################################
if [[ -d "${CTAT_GENOME_LIB}" ]] && [[ "$(ls -A "${CTAT_GENOME_LIB}" 2>/dev/null)" ]]; then
    log "CTAT genome library found"
else
    log "WARNING: CTAT genome library missing or empty"
    log "Download GRCh38 CTAT plug-n-play library and extract to refs/ctat_genome_lib"
fi

###############################################################################
# 7. SQANTI3 check
###############################################################################
[[ -f "${SQANTI3_QC}" ]] || die "Missing SQANTI3 script: ${SQANTI3_QC}"
log "SQANTI3 script OK"

###############################################################################
# 8. Container checks
###############################################################################
if [[ -f "${CTATLR_SIF}" ]]; then
    log "CTAT container OK"
else
    log "WARNING: CTAT container missing"
fi

if [[ -f "${JAFFAL_SIF}" ]]; then
    log "JAFFAL container OK"
else
    log "WARNING: JAFFAL container missing"
fi

###############################################################################
# 9. Final summary
###############################################################################
log "Reference preparation COMPLETE"

log "Core: OK"
log "TE: OK"
log "Fusion: requires CTAT lib + container"
