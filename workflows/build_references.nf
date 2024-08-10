/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

include { ARRIBA_DOWNLOAD }                 from '../modules/local/arriba/download/main'
include { ENSEMBL_DOWNLOAD }                from '../modules/local/ensembl/main'
include { FUSIONCATCHER_DOWNLOAD }          from '../modules/local/fusioncatcher/download/main'
include { FUSIONREPORT_DOWNLOAD }           from '../modules/local/fusionreport/download/main'
include { HGNC_DOWNLOAD }                   from '../modules/local/hgnc/main'
include { STARFUSION_BUILD }                from '../modules/local/starfusion/build/main'
include { STARFUSION_DOWNLOAD }             from '../modules/local/starfusion/download/main'
include { GTF_TO_REFFLAT }                  from '../modules/local/uscs/custom_gtftogenepred/main'
include { RRNA_TRANSCRIPTS }                from '../modules/local/rrnatranscripts/main'
include { CONVERT2BED }                     from '../modules/local/convert2bed/main'
/*
========================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
========================================================================================
*/

include { SAMTOOLS_FAIDX }                  from '../modules/nf-core/samtools/faidx/main'
include { STAR_GENOMEGENERATE }             from '../modules/nf-core/star/genomegenerate/main'
include { GATK4_CREATESEQUENCEDICTIONARY }  from '../modules/nf-core/gatk4/createsequencedictionary/main'
include { GATK4_BEDTOINTERVALLIST }         from '../modules/nf-core/gatk4/bedtointervallist/main'
include { SALMON_INDEX }                    from '../modules/nf-core/salmon/index/main'
include { GFFREAD }                         from '../modules/nf-core/gffread/main'

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow BUILD_REFERENCES {

    def fake_meta = [:]
    fake_meta.id = "Homo_sapiens.${params.genome}.${params.ensembl_version}"
    ENSEMBL_DOWNLOAD( params.ensembl_version, params.genome, fake_meta )
    HGNC_DOWNLOAD( )
    SAMTOOLS_FAIDX(ENSEMBL_DOWNLOAD.out.primary_assembly, [[],[]])
    GATK4_CREATESEQUENCEDICTIONARY(ENSEMBL_DOWNLOAD.out.primary_assembly)

    RRNA_TRANSCRIPTS(ENSEMBL_DOWNLOAD.out.gtf)
    CONVERT2BED(RRNA_TRANSCRIPTS.out.rrna_gtf)

    GATK4_BEDTOINTERVALLIST(CONVERT2BED.out.bed, GATK4_CREATESEQUENCEDICTIONARY.out.dict)

    GFFREAD(ENSEMBL_DOWNLOAD.out.gtf, ENSEMBL_DOWNLOAD.out.primary_assembly.map { meta, fasta -> [ fasta ] })
    SALMON_INDEX(ENSEMBL_DOWNLOAD.out.primary_assembly.map{ meta, fasta -> [ fasta ] }, GFFREAD.out.gffread_fasta.map{ meta, gffread_fasta -> [ gffread_fasta ] })

    if (params.starindex || params.all || params.starfusion || params.arriba) {
        STAR_GENOMEGENERATE( ENSEMBL_DOWNLOAD.out.primary_assembly, ENSEMBL_DOWNLOAD.out.gtf )
    }

    if (params.arriba || params.all) {
        ARRIBA_DOWNLOAD()
    }

    if (params.fusioncatcher || params.all) {
        FUSIONCATCHER_DOWNLOAD()
    }

    if (params.starfusion || params.all) {
        if (params.starfusion_build){
            STARFUSION_BUILD( ENSEMBL_DOWNLOAD.out.primary_assembly, ENSEMBL_DOWNLOAD.out.gtf )
        } else {
            STARFUSION_DOWNLOAD( fake_meta )
        }
    }

    if (params.starfusion_build){
        GTF_TO_REFFLAT(ENSEMBL_DOWNLOAD.out.gtf)
    } else {
        GTF_TO_REFFLAT(STARFUSION_DOWNLOAD.out.gtf)
    }

    if (params.fusionreport || params.all) {
        FUSIONREPORT_DOWNLOAD( params.cosmic_username, params.cosmic_passwd )
    }

}

/*
========================================================================================
    THE END
========================================================================================
*/
