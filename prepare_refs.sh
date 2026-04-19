#!/usr/bin/env bash
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
    log "samtools FASTA index already exists: ${GENOME}.fai"
else
    log "Building samtools FASTA index"
    conda run -n "${ENV_CORE}" samtools faidx "${GENOME}"
fi

###############################################################################
# 3. minimap2 index
###############################################################################
MMI_PATH="${PROJECT_DIR}/refs/genome.mmi"

if [[ -f "${MMI_PATH}" ]]; then
    log "minimap2 index already exists: ${MMI_PATH}"
else
    log "Building minimap2 index: ${MMI_PATH}"
    conda run -n "${ENV_CORE}" minimap2 -d "${MMI_PATH}" "${GENOME}"
fi

###############################################################################
# 4. Pigeon prepare
# NOTE: in your installed version, pigeon prepare works in place and creates:
#       gencode.sorted.gtf and gencode.sorted.gtf.pgi next to the input GTF
###############################################################################
GTF_SORTED="${PROJECT_DIR}/refs/gencode.sorted.gtf"
GTF_PGI="${PROJECT_DIR}/refs/gencode.sorted.gtf.pgi"

if [[ -f "${GTF_SORTED}" && -f "${GTF_PGI}" ]]; then
    log "Pigeon-prepared annotation already exists:"
    log "  ${GTF_SORTED}"
    log "  ${GTF_PGI}"
else
    log "Running pigeon prepare on GTF"
    conda run -n "${ENV_CORE}" pigeon prepare "${GTF}"
fi

###############################################################################
# 5. TE reference check
###############################################################################
if [[ -f "${TEBED}" ]]; then
    log "TE BED found: ${TEBED}"
else
    log "WARNING: TE BED missing: ${TEBED}"
    log "WARNING: TE step will be skipped until repeatmasker_hg38.bed is provided"
fi

###############################################################################
# 6. CTAT genome library check
###############################################################################
if [[ -d "${CTAT_GENOME_LIB}" ]] && [[ "$(ls -A "${CTAT_GENOME_LIB}" 2>/dev/null)" ]]; then
    log "CTAT genome library found: ${CTAT_GENOME_LIB}"
else
    log "WARNING: CTAT genome library missing or empty: ${CTAT_GENOME_LIB}"
    log "WARNING: CTAT-LR-fusion step will be skipped until this is prepared"
fi

###############################################################################
# 7. JAFFA / JAFFAL reference dir check
###############################################################################
if [[ -n "${JAFFA_REF:-}" ]]; then
    if [[ -d "${JAFFA_REF}" ]]; then
        log "JAFFA reference directory found: ${JAFFA_REF}"
    else
        log "WARNING: JAFFA reference directory not found: ${JAFFA_REF}"
        log "WARNING: JAFFAL may still run depending on container setup"
    fi
fi

###############################################################################
# 8. SQANTI3 script check
###############################################################################
if [[ -n "${SQANTI3_QC:-}" ]]; then
    [[ -f "${SQANTI3_QC}" ]] || die "Missing SQANTI3 script: ${SQANTI3_QC}"
    log "SQANTI3 script found: ${SQANTI3_QC}"
fi

###############################################################################
# 9. Container checks
###############################################################################
if [[ -n "${CTATLR_SIF:-}" ]]; then
    if [[ -f "${CTATLR_SIF}" ]]; then
        log "CTAT-LR-fusion container found: ${CTATLR_SIF}"
    else
        log "WARNING: CTAT-LR-fusion container not found: ${CTATLR_SIF}"
    fi
fi

if [[ -n "${JAFFAL_SIF:-}" ]]; then
    if [[ -f "${JAFFAL_SIF}" ]]; then
        log "JAFFAL container found: ${JAFFAL_SIF}"
    else
        log "WARNING: JAFFAL container not found: ${JAFFAL_SIF}"
    fi
fi

###############################################################################
# 10. Final summary
###############################################################################
log "Reference preparation check complete"
log "Core run requires: GENOME + GTF + gencode.sorted.gtf(.pgi)"
log "TE run requires: TEBED"
log "Fusion run requires: CTAT_GENOME_LIB + CTATLR_SIF"
