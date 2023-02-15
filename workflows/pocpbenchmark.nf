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
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { BLAST } from '../subworkflows/local/blast'
include { DIAMOND } from '../subworkflows/local/diamond'
include { MMSEQS2 } from '../subworkflows/local/mmseqs2'
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
include { CREATE_COMPARISONS_LIST } from '../modules/local/create_comparisons_list'
include { SEQKIT_STATS } from '../modules/nf-core/seqkit/stats/main'
include { FILTER_MATCHES } from '../modules/local/filter_matches'
include { POCP } from '../modules/local/pocp'
include { COMPARE_POCP } from '../modules/local/compare_pocp'
include { EVAL_GENUS_DELINEATION } from '../modules/local/eval_genus_delineation'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow POCPBENCHMARK {

    ch_versions = Channel.empty()

    /*
        GTDB r207 parameters for metadata and proteomes
        if no local directory or metadata is provided, they are fetched from GTDB
    */

    if (params.gtdb_proteins_dir) {
        gtdb_proteins = Channel.fromPath(params.gtdb_proteins_dir, checkIfExists: true)
    } else {
        proteins_archive = Channel.fromPath("https://data.gtdb.ecogenomic.org/releases/release207/207.0/genomic_files_reps/gtdb_proteins_aa_reps_r207.tar.gz")
        EXTRACT( proteins_archive )
        gtdb_proteins = EXTRACT.out.map{ it + "/protein_faa_reps/bacteria" }
    }

    if (params.gtdb_metadata_tsv) {
        gtdb_metadata = file(params.gtdb_metadata_tsv)
        if(gtdb_metadata.extension != "tsv") {
            exit 1, "The specified GTDB metadata file (${gtdb_metadata.name}) is not a tsv file!"
        }
        gtdb_metadata = Channel.fromPath(gtdb_metadata, checkIfExists: true)
    } else {
        mdata_archive = Channel.fromPath("https://data.gtdb.ecogenomic.org/releases/release207/207.0/bac120_metadata_r207.tar.gz")
        EXTRACT( mdata_archive )
        gtdb_metadata = EXTRACT.out.map{ it + "/bac120_metadata_r207.tsv" }
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
    shortlist = ch_shortlist.csv
    shortlisted_ids = shortlist \
        | splitCsv(header: true)
        | map { row -> row.accession }
    ch_versions = ch_versions.mix(CREATE_GENOMES_SHORTLIST.out.versions)

    // Paste together the path to the GTDB proteins files
    //  and the ids of the shortlisted genomes

    ch_proteins = gtdb_proteins \
        | combine( shortlisted_ids ) // [ path_dir, RS011 ]
        | map {
            // set up a groovy tuple for compatibility with most nf-core modules
            // normally the output of fromPairs
            // see https://nf-co.re/docs/contributing/modules#what-is-the-meta-map
            tuple(
                [ 'id': it[1] ], // identifier RS011
                [ it.join('/') + "_protein.faa" ] // path to the RS011.faa
            )
        }

    // Compute the statistics on the protein sequences
    protein_stats = SEQKIT_STATS( ch_proteins )
    // Collect all the stats for each genome into one tsv
    protein_stats_tsv = protein_stats.stats.collectFile(
        name: 'proteins_statistics.tsv', skip: 1, keepHeader: true,  storeDir: params.outdir
    ) { it[1] } // extract the second element as the first is the propagated meta

    ch_versions = ch_versions.mix(SEQKIT_STATS.out.versions.first())


    // Create a channel from the comparisons list that can be sent to the tools
    comp = CREATE_COMPARISONS_LIST( shortlist )
    ch_q_s = comp.csv \
        | splitCsv(header: true) \
        | map {
            row -> tuple(
                 [row.Query,row.Subject].join('-'),
                 row.Query,
                 row.Subject )
            }
    ch_versions = ch_versions.mix(CREATE_COMPARISONS_LIST.out.versions)

    BLAST( ch_proteins, ch_q_s )
    ch_versions = ch_versions.mix(BLAST.out.versions)

    DIAMOND( ch_proteins, ch_q_s )
    ch_versions = ch_versions.mix(DIAMOND.out.versions)

    MMSEQS2( ch_proteins, ch_q_s )
    ch_versions = ch_versions.mix(MMSEQS2.out.versions)

    // Gather matches
    all_matches = Channel.empty()
    filt = FILTER_MATCHES(
        all_matches.mix(
            BLAST.out.matches,
            DIAMOND.out.matches,
            MMSEQS2.out.matches,
        )
    )
    ch_versions = ch_versions.mix(FILTER_MATCHES.out.versions)

    matches_csv = filt.csv.collectFile(
        name: 'matches.csv', skip: 1, keepHeader: true,  storeDir: params.outdir
    )

    POCP( protein_stats_tsv, matches_csv )
    COMPARE_POCP( POCP.out.summary )
    EVAL_GENUS_DELINEATION( POCP.out.summary, shortlist )
    ch_versions = ch_versions.mix(
        POCP.out.versions,
        COMPARE_POCP.out.versions,
        EVAL_GENUS_DELINEATION.out.versions
    )

    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
