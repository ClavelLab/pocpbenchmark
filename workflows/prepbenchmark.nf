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
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'

include { CREATE_GENOMES_SHORTLIST } from '../modules/local/create_genomes_shortlist'
include { SPLIT_PER_FAMILY } from '../modules/local/split_per_family'
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

    family_shortlist.csv
        | flatten // to avoid ArrayList Error
        | map {
            "nextflow run main.nf -entry POCPBENCHMARK " + \
            "-profile winogradsky,docker " + \
            "--outdir " + \
            params.outdir + "-" + \
            // withOUT .csv
            it.getSimpleName() + \
            "--family_shortlist " + \
            params.outdir + "/split_per_family/" + \
            // with .csv
            it.getName()
        }
        | collectFile(
            name: 'families_to_run.txt',
            newLine: true, storeDir: params.outdir
        )

    println "\n\nRun per-family comparisons commands"
    println "from ${params.outdir}/families_to_run.txt"

    ch_versions = ch_versions.mix(CREATE_GENOMES_SHORTLIST.out.versions)
    ch_versions = ch_versions.mix(SPLIT_PER_FAMILY.out.versions)

}
