/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowPocpbenchmark.initialise(params, log)

// Check mandatory parameters
if (params.valid_names_tsv) {
    valid_names = Channel.fromPath(params.valid_names_tsv)
} else {
    exit 1, 'Table of valid bacteria names not specified!'
}


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { EXTRACT } from '../modules/local/extract'
include { FILTER_TABLE } from '../modules/local/filter_table'
include { TABIX_BGZIP } from '../modules/nf-core/tabix/bgzip/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'

include { CREATE_GENOMES_SHORTLIST } from '../modules/local/create_genomes_shortlist'
include { CREATE_COMPARISONS_LIST } from '../modules/local/create_comparisons_list'
/*

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PREPBENCHMARK {

    ch_versions = Channel.empty()

    /*
        GTDB r207 parameters for metadata
        if no local directory or metadata is provided, they are fetched from GTDB
    */

    if (params.gtdb_metadata_tsv) {
        gtdb_metadata = file(params.gtdb_metadata_tsv)
        if(gtdb_metadata.extension != "tsv") {
            exit 1, "The specified GTDB metadata file (${gtdb_metadata.name}) is not a tsv file!"
        }
        gtdb_metadata = Channel.fromPath(gtdb_metadata, checkIfExists: true)
    } else {
        mdata_archive = Channel.fromPath("https://data.gtdb.ecogenomic.org/releases/release214/214.0/bac120_metadata_r214.tar.gz")
        EXTRACT( mdata_archive )
        gtdb_metadata = EXTRACT.out.map{ it + "/bac120_metadata_r214.tsv" }
    }

    /*
        Shortlist the GTDB list with valid names, representatives genomes etc..
    */

    ch_shortlist = CREATE_GENOMES_SHORTLIST( gtdb_metadata, valid_names )
/*
    // Subset of identifiers for testing
    test_ids = Channel.of(
            "RS_GCF_000012825.1",
            "RS_GCF_000262545.1",
            "RS_GCF_000376985.1",
            "RS_GCF_001591705.1",
            "RS_GCF_009767945.1",
            "RS_GCF_013009555.1"
        ).collect().map{ it.join('|') }
    shortlist = FILTER_TABLE ( ch_shortlist.csv, test_ids )
*/
    family_shortlist = SPLIT_PER_FAMILY(ch_shortlist.csv)

    ch_versions = ch_versions.mix(CREATE_GENOMES_SHORTLIST.out.versions)
    ch_versions = ch_versions.mix(SPLIT_PER_FAMILY.out.versions)

}
