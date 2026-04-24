#!/usr/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -n "${SLURM_SUBMIT_DIR:-}" ]]; then
    PROJECT_DIR="${SLURM_SUBMIT_DIR}"
else
    PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

source "${PROJECT_DIR}/config.sh"

mkdir -p "${RESULTS}" "${LOGS}"
mkdir -p "${RESULTS}"/{00_qc,01_fastq,02_align,03_isoseq,04_sqanti3,05_flair,06_fusion,07_splicing,08_tegene,09_reports}

###############################################################################
# defaults
###############################################################################
RUN_QC=0
RUN_ALIGN=0
RUN_ISOSEQ=0
RUN_SQANTI3=0
RUN_FLAIR=0
RUN_FUSION=0
RUN_TE=0
RUN_SUMMARY=0

ONLY_SAMPLE=""

###############################################################################
# helpers
###############################################################################
log() {
    echo "[$(date '+%F %T')] $*"
}

die() {
    echo "[ERROR] $*" >&2
    exit 1
}

usage() {
    cat << EOF
Usage:
  bash run_all_v2.sh [options]

Main switches:
  --all         Run all steps
  --core        Run core transcriptome workflow:
                QC + align + isoseq/pigeon + sqanti3 + flair + summary
  --fusion      Run fusion workflow only
  --te          Run TE overlap workflow only

Step-specific switches:
  --qc          Run QC + FASTQ conversion
  --align       Run pbmm2 + minimap2 alignment
  --isoseq      Run isoseq collapse + pigeon
  --sqanti3     Run SQANTI3
  --flair       Run FLAIR
  --summary     Run summary tables only

Optional:
  --sample ID   Run only one sample, e.g. A2ABD_2B
  --help        Show this help

Examples:
  bash run_all_v2.sh --all
  bash run_all_v2.sh --core
  bash run_all_v2.sh --fusion
  bash run_all_v2.sh --te
  bash run_all_v2.sh --sample A2ABD_2B --core
  bash run_all_v2.sh --sample A4BRE_2B --fusion
EOF
}

check_inputs() {
    [[ -f "${SAMPLES}" ]] || die "Missing samples.tsv: ${SAMPLES}"
    [[ -f "${GENOME}" ]] || die "Missing genome fasta: ${GENOME}"
    [[ -f "${GTF}" ]] || die "Missing GTF: ${GTF}"
}

get_sample_lines() {
    if [[ -n "${ONLY_SAMPLE}" ]]; then
        awk -F'\t' -v s="${ONLY_SAMPLE}" 'NR==1 || $1==s' "${SAMPLES}"
    else
        cat "${SAMPLES}"
    fi
}

ensure_sample_exists() {
    if [[ -n "${ONLY_SAMPLE}" ]]; then
        grep -P "^${ONLY_SAMPLE}\t" "${SAMPLES}" >/dev/null 2>&1 || \
            die "Sample not found in samples.tsv: ${ONLY_SAMPLE}"
    fi
}

get_singularity_cmd() {
    if command -v apptainer >/dev/null 2>&1; then
        echo "apptainer"
    elif command -v singularity >/dev/null 2>&1; then
        echo "singularity"
    else
        echo ""
    fi
}

###############################################################################
# step functions
###############################################################################
run_qc_and_fastq() {
    log "STEP: QC and FASTQ conversion"

    get_sample_lines | tail -n +2 | while IFS=$'\t' read -r SAMPLE BAM; do
        mkdir -p "${RESULTS}/00_qc/${SAMPLE}" "${RESULTS}/01_fastq/${SAMPLE}"

        log "QC ${SAMPLE}"

        conda run -n "${ENV_CORE}" samtools quickcheck -v "${BAM}" \
            > "${RESULTS}/00_qc/${SAMPLE}/${SAMPLE}.quickcheck.txt" 2>&1 || true

        conda run -n "${ENV_CORE}" samtools stats "${BAM}" \
            > "${RESULTS}/00_qc/${SAMPLE}/${SAMPLE}.samtools.stats.txt"

        conda run -n "${ENV_CORE}" samtools view -c "${BAM}" \
            > "${RESULTS}/00_qc/${SAMPLE}/${SAMPLE}.read_count.txt"

        conda run -n "${ENV_CORE}" bash -c \
            "samtools fastq -@ ${THREADS} '${BAM}' | gzip -c > '${RESULTS}/01_fastq/${SAMPLE}/${SAMPLE}.fastq.gz'"

        conda run -n "${ENV_CORE}" seqkit stats \
            "${RESULTS}/01_fastq/${SAMPLE}/${SAMPLE}.fastq.gz" \
            > "${RESULTS}/00_qc/${SAMPLE}/${SAMPLE}.seqkit.stats.txt"
    done
    log "skipping MultiQC on this HPC"
    ##conda run -n "${ENV_CORE}" multiqc \
    ##     -o "${RESULTS}/09_reports/qc_report" "${RESULTS}/00_qc" || true 
}

run_align_pbmm2() {
    log "STEP: pbmm2 alignment"

    get_sample_lines | tail -n +2 | while IFS=$'\t' read -r SAMPLE BAM; do
        mkdir -p "${RESULTS}/02_align/${SAMPLE}"

        log "pbmm2 ${SAMPLE}"

        conda run -n "${ENV_CORE}" pbmm2 align "${GENOME}" "${BAM}" \
            "${RESULTS}/02_align/${SAMPLE}/${SAMPLE}.pbmm2.bam" \
            --preset ISOSEQ --sort -j "${THREADS}"

        conda run -n "${ENV_CORE}" samtools index \
            "${RESULTS}/02_align/${SAMPLE}/${SAMPLE}.pbmm2.bam"
    done
}

run_align_minimap2() {
    log "STEP: minimap2 alignment"

    get_sample_lines | tail -n +2 | while IFS=$'\t' read -r SAMPLE BAM; do
        mkdir -p "${RESULTS}/02_align/${SAMPLE}"

        log "minimap2 ${SAMPLE}"

        conda run -n "${ENV_CORE}" bash -c \
            "minimap2 -t ${THREADS} -ax splice:hq -uf --secondary=no '${GENOME}' \
            '${RESULTS}/01_fastq/${SAMPLE}/${SAMPLE}.fastq.gz' | \
            samtools sort -@ ${THREADS} -o '${RESULTS}/02_align/${SAMPLE}/${SAMPLE}.minimap2.bam'"

        conda run -n "${ENV_CORE}" samtools index \
            "${RESULTS}/02_align/${SAMPLE}/${SAMPLE}.minimap2.bam"
    done
}

run_align() {
    run_align_pbmm2
    run_align_minimap2
}

## Run inside the sample directory and use a local output prefix, add collapse fixed
run_isoseq_pigeon() {
    log "STEP: isoseq collapse + pigeon"

    log "Preparing pigeon reference inputs"
    conda run -n "${ENV_CORE}" pigeon prepare "${GTF}"
    conda run -n "${ENV_CORE}" pigeon prepare "${GENOME}"

    get_sample_lines | tail -n +2 | while IFS=$'\t' read -r SAMPLE BAM; do
        mkdir -p "${RESULTS}/03_isoseq/${SAMPLE}"

        log "isoseq collapse ${SAMPLE}"
        conda run -n "${ENV_CORE}" isoseq collapse \
            "${RESULTS}/02_align/${SAMPLE}/${SAMPLE}.pbmm2.bam" \
            "${RESULTS}/03_isoseq/${SAMPLE}/${SAMPLE}.collapsed.gff"

        log "Preparing collapsed isoforms for pigeon ${SAMPLE}"
        conda run -n "${ENV_CORE}" pigeon prepare \
            "${RESULTS}/03_isoseq/${SAMPLE}/${SAMPLE}.collapsed.gff"

        log "pigeon classify ${SAMPLE}"
        (
            cd "${RESULTS}/03_isoseq/${SAMPLE}"
            conda run -n "${ENV_CORE}" pigeon classify \
                "${SAMPLE}.collapsed.sorted.gff" \
                "${GTF_SORTED}" \
                "${GENOME}" \
                -o "${SAMPLE}.pigeon"
        )

        log "pigeon filter ${SAMPLE}"
        conda run -n "${ENV_CORE}" pigeon filter \
            "${RESULTS}/03_isoseq/${SAMPLE}/${SAMPLE}.pigeon_classification.txt" \
            "${RESULTS}/03_isoseq/${SAMPLE}/${SAMPLE}.pigeon_junctions.txt"
    done
}


run_sqanti3() {
    log "STEP: SQANTI3"

    get_sample_lines | tail -n +2 | while IFS=$'\t' read -r SAMPLE BAM; do
        mkdir -p "${RESULTS}/04_sqanti3/${SAMPLE}"

        log "sqanti3 ${SAMPLE}"
        conda run -n "${ENV_SQANTI3}" python "${SQANTI3_QC}" \
            --isoforms "${RESULTS}/03_isoseq/${SAMPLE}/${SAMPLE}.collapsed.gff" \
            --refGTF "${GTF}" \
            --refFasta "${GENOME}" \
            -o "${SAMPLE}" \
            -d "${RESULTS}/04_sqanti3/${SAMPLE}"
    done
}


run_flair() {
    log "STEP: FLAIR"

    get_sample_lines | tail -n +2 | while IFS=$'\t' read -r SAMPLE BAM; do
        mkdir -p "${RESULTS}/05_flair/${SAMPLE}"

        log "FLAIR ${SAMPLE}"
        conda run -n "${ENV_FLAIR}" flair transcriptome \
            -b "${RESULTS}/02_align/${SAMPLE}/${SAMPLE}.minimap2.bam" \
            -g "${GENOME}" \
            -f "${GTF}" \
            -o "${RESULTS}/05_flair/${SAMPLE}/${SAMPLE}"
    done
}

run_ctat_lr_fusion() {
    log "STEP: CTAT-LR-fusion"

    [[ -d "${CTAT_GENOME_LIB}" ]] || {
        log "Skipping CTAT-LR-fusion: missing CTAT genome library ${CTAT_GENOME_LIB}"
        return 0
    }

    [[ -f "${CTATLR_SIF}" ]] || {
        log "Skipping CTAT-LR-fusion: missing image ${CTATLR_SIF}"
        return 0
    }

    SINGCMD="$(get_singularity_cmd)"
    [[ -n "${SINGCMD}" ]] || {
        log "Skipping CTAT-LR-fusion: singularity/apptainer not found"
        return 0
    }

    get_sample_lines | tail -n +2 | while IFS=$'\t' read -r SAMPLE BAM; do
        mkdir -p "${RESULTS}/06_fusion/ctat_lr/${SAMPLE}"

        log "CTAT-LR-fusion ${SAMPLE}"
        "${SINGCMD}" exec --bind "${PROJECT_DIR}:${PROJECT_DIR}" "${CTATLR_SIF}" \
            ctat-LR-fusion \
            --genome_lib_dir "${CTAT_GENOME_LIB}" \
            --transcripts "${RESULTS}/01_fastq/${SAMPLE}/${SAMPLE}.fastq.gz" \
            --CPU "${THREADS}" \
            --output "${RESULTS}/06_fusion/ctat_lr/${SAMPLE}" || true
    done
}

run_extract_kinase_fusions() {
    log "STEP: extract kinase fusions"

    mkdir -p "${RESULTS}/06_fusion/summary"

    grep -R -E 'FGFR2|ERBB4|RET' "${RESULTS}/06_fusion/ctat_lr" \
        > "${RESULTS}/06_fusion/summary/ctat_kinase_hits.txt" || true
}

run_fusion() {
    run_ctat_lr_fusion
    run_extract_kinase_fusions
}

run_splicing_per_sample() {
    log "STEP: per-sample splicing extraction"

    get_sample_lines | tail -n +2 | while IFS=$'\t' read -r SAMPLE BAM; do
        OUTDIR="${RESULTS}/07_splicing/${SAMPLE}"
        mkdir -p "${OUTDIR}"

        log "Extract kinase isoforms ${SAMPLE}"

        cp "${RESULTS}/05_flair/${SAMPLE}/${SAMPLE}.isoforms.gtf" \
           "${OUTDIR}/${SAMPLE}.isoforms.gtf" 2>/dev/null || true

        grep -E 'ENSG00000066468|ENSG00000178568|ENSG00000165731' \  # FGFR2|ERBB4|RET
            "${RESULTS}/05_flair/${SAMPLE}/${SAMPLE}.isoforms.gtf" \
            > "${OUTDIR}/${SAMPLE}.target_kinase_isoforms.gtf" || true
    done
}

run_splicing_merge() {
    log "STEP: merge FLAIR GTFs"

    OUTDIR="${RESULTS}/07_splicing/merged"
    mkdir -p "${OUTDIR}"

    find "${RESULTS}/05_flair" -name "*.isoforms.gtf" > "${OUTDIR}/flair_gtf.list" || true

    if [[ -s "${OUTDIR}/flair_gtf.list" ]]; then
        xargs cat < "${OUTDIR}/flair_gtf.list" \
            > "${OUTDIR}/all_samples.flair.merged.gtf"

        grep -E 'ENSG00000066468|ENSG00000178568|ENSG00000165731' \ # FGFR2|ERBB4|RET
            "${OUTDIR}/all_samples.flair.merged.gtf" \
            > "${OUTDIR}/target_kinase_isoforms.gtf" || true
    else
        log "No FLAIR GTF found, skipping merge"
    fi
}



run_te_overlap() {
    log "STEP: TE overlap screen"

    [[ -f "${TEBED}" ]] || {
        log "Skipping TE overlap: missing ${TEBED}"
        return 0
    }

    get_sample_lines | tail -n +2 | while IFS=$'\t' read -r SAMPLE BAM; do
        mkdir -p "${RESULTS}/08_tegene/${SAMPLE}"

        log "TE overlap ${SAMPLE}"
        conda run -n "${ENV_CORE}" bedtools intersect -wa -wb \
            -a "${RESULTS}/03_isoseq/${SAMPLE}/${SAMPLE}.collapsed.gff" \
            -b "${TEBED}" \
            > "${RESULTS}/08_tegene/${SAMPLE}/${SAMPLE}.isoform_TE_overlap.tsv"
    done
}

run_summary() {
    log "STEP: summary"

    mkdir -p "${RESULTS}/10_summary"

    get_sample_lines | tail -n +2 | while IFS=$'\t' read -r SAMPLE BAM; do
        OUT="${RESULTS}/10_summary/${SAMPLE}.summary.txt"

        echo -e "Sample\tMetric\tValue" > "${OUT}"

        # QC
        if [[ -f "${RESULTS}/00_qc/${SAMPLE}/${SAMPLE}.read_count.txt" ]]; then
            RC=$(cat "${RESULTS}/00_qc/${SAMPLE}/${SAMPLE}.read_count.txt")
            echo -e "${SAMPLE}\tread_count\t${RC}" >> "${OUT}"
        fi

        # Pigeon
        if [[ -f "${RESULTS}/03_isoseq/${SAMPLE}/${SAMPLE}.pigeon_classification.txt" ]]; then
            IC=$(grep -v '^#' "${RESULTS}/03_isoseq/${SAMPLE}/${SAMPLE}.pigeon_classification.txt" | wc -l)
            echo -e "${SAMPLE}\tpigeon_isoform_count\t${IC}" >> "${OUT}"
        fi

        if [[ -f "${RESULTS}/03_isoseq/${SAMPLE}/${SAMPLE}.pigeon_classification.txt" ]]; then
            FSM=$(grep -c 'full-splice_match' "${RESULTS}/03_isoseq/${SAMPLE}/${SAMPLE}.pigeon_classification.txt" 2>/dev/null || echo 0)
            NIC=$(grep -c 'novel_in_catalog' "${RESULTS}/03_isoseq/${SAMPLE}/${SAMPLE}.pigeon_classification.txt" 2>/dev/null || echo 0)
            NNC=$(grep -c 'novel_not_in_catalog' "${RESULTS}/03_isoseq/${SAMPLE}/${SAMPLE}.pigeon_classification.txt" 2>/dev/null || echo 0)
            echo -e "${SAMPLE}\tpigeon_FSM\t${FSM}" >> "${OUT}"
            echo -e "${SAMPLE}\tpigeon_NIC\t${NIC}" >> "${OUT}"
            echo -e "${SAMPLE}\tpigeon_NNC\t${NNC}" >> "${OUT}"
        fi

        # SQANTI3
        SQDIR="${RESULTS}/04_sqanti3/${SAMPLE}"
        if [[ -d "${SQDIR}" ]]; then
            SQFILES=$(find "${SQDIR}" -type f | wc -l)
            echo -e "${SAMPLE}\tsqanti3_file_count\t${SQFILES}" >> "${OUT}"
        fi

        # FLAIR
        if [[ -f "${RESULTS}/05_flair/${SAMPLE}/${SAMPLE}.isoform.counts.txt" ]]; then
            FCOUNT=$(wc -l < "${RESULTS}/05_flair/${SAMPLE}/${SAMPLE}.isoform.counts.txt")
            echo -e "${SAMPLE}\tflair_isoform_count_rows\t${FCOUNT}" >> "${OUT}"
        fi

        if [[ -f "${RESULTS}/05_flair/${SAMPLE}/${SAMPLE}.isoform.read.map.txt" ]]; then
            RMAP=$(wc -l < "${RESULTS}/05_flair/${SAMPLE}/${SAMPLE}.isoform.read.map.txt")
            echo -e "${SAMPLE}\tflair_read_map_rows\t${RMAP}" >> "${OUT}"
        fi

        # Splicing per-sample
        if [[ -f "${RESULTS}/07_splicing/${SAMPLE}/${SAMPLE}.target_kinase_isoforms.gtf" ]]; then
            KSP=$(wc -l < "${RESULTS}/07_splicing/${SAMPLE}/${SAMPLE}.target_kinase_isoforms.gtf")
            echo -e "${SAMPLE}\tsplicing_target_kinase_rows\t${KSP}" >> "${OUT}"
        fi

        # Splicing merged
        if [[ -f "${RESULTS}/07_splicing/merged/target_kinase_isoforms.gtf" ]]; then
            MKSP=$(wc -l < "${RESULTS}/07_splicing/merged/target_kinase_isoforms.gtf")
            echo -e "${SAMPLE}\tmerged_target_kinase_rows\t${MKSP}" >> "${OUT}"
        fi

        # TE
        if [[ -f "${RESULTS}/08_tegene/${SAMPLE}/${SAMPLE}.isoform_TE_overlap.tsv" ]]; then
            TE=$(wc -l < "${RESULTS}/08_tegene/${SAMPLE}/${SAMPLE}.isoform_TE_overlap.tsv")
            echo -e "${SAMPLE}\tTE_overlap_count\t${TE}" >> "${OUT}"
        fi

        # Fusion: CTAT final predictions only
        CTAT_FILE="${RESULTS}/06_fusion/ctat_lr/${SAMPLE}/ctat-LR-fusion.fusion_predictions.tsv"
        if [[ -f "${CTAT_FILE}" ]]; then
            FC=$(grep -vc '^#' "${CTAT_FILE}")
            echo -e "${SAMPLE}\tfusion_count_ctat\t${FC}" >> "${OUT}"

            KFC=$(grep -Ei 'FGFR2|ERBB4|RET' "${CTAT_FILE}" | wc -l)
            echo -e "${SAMPLE}\tfusion_kinase_hits_ctat\t${KFC}" >> "${OUT}"
        fi
    done
}




###############################################################################
# parse args
###############################################################################
if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)
            RUN_QC=1
            RUN_ALIGN=1
            RUN_ISOSEQ=1
            RUN_SQANTI3=1
            RUN_FLAIR=1
            RUN_FUSION=1
            RUN_TE=1
            RUN_SUMMARY=1
            shift
            ;;
        --core)
            RUN_QC=1
            RUN_ALIGN=1
            RUN_ISOSEQ=1
            RUN_SQANTI3=1
            RUN_FLAIR=1
            RUN_SUMMARY=1
            shift
            ;;
        --fusion)
            RUN_FUSION=1
            shift
            ;;
        --te)
            RUN_TE=1
            shift
            ;;
        --qc)
            RUN_QC=1
            shift
            ;;
        --align)
            RUN_ALIGN=1
            shift
            ;;
        --isoseq)
            RUN_ISOSEQ=1
            shift
            ;;
        --sqanti3)
            RUN_SQANTI3=1
            shift
            ;;
        --flair)
            RUN_FLAIR=1
            shift
            ;;
        --summary)
            RUN_SUMMARY=1
            shift
            ;;
        --sample)
            ONLY_SAMPLE="${2:-}"
            [[ -n "${ONLY_SAMPLE}" ]] || die "Missing value after --sample"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            die "Unknown option: $1"
            ;;
    esac
done

###############################################################################
# main
###############################################################################
check_inputs
ensure_sample_exists

log "Pipeline start"
log "Selected sample: ${ONLY_SAMPLE:-ALL}"

if [[ "${RUN_QC}" -eq 1 ]]; then
    run_qc_and_fastq
fi

if [[ "${RUN_ALIGN}" -eq 1 ]]; then
    run_align
fi

if [[ "${RUN_ISOSEQ}" -eq 1 ]]; then
    run_isoseq_pigeon
fi

if [[ "${RUN_SQANTI3}" -eq 1 ]]; then
    run_sqanti3
fi

if [[ "${RUN_FLAIR}" -eq 1 ]]; then
    run_flair
    run_splicing_per_sample
    run_splicing_merge
fi

if [[ "${RUN_FUSION}" -eq 1 ]]; then
    run_fusion
fi

if [[ "${RUN_TE}" -eq 1 ]]; then
    run_te_overlap
fi

if [[ "${RUN_SUMMARY}" -eq 1 ]]; then
    run_summary
fi

log "Pipeline finished"
