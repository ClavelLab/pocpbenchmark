/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowPocpbenchmark.initialise(params, log)

// Check mandatory parameters
if (params.proteins) { dir_proteins = params.proteins + '/*.faa' } else { exit 1, 'Directory of proteins FASTA files (*.faa) not specified!' }

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
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'

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

    ch_proteins = Channel
        .fromPath( dir_proteins )
        .map {
            // set up a groovy tuple for compatibility with most nf-core modules
            // normally the output of fromPairs
            // see https://nf-co.re/docs/contributing/modules#what-is-the-meta-map
            tuple(
                [ 'id': it.baseName.toString().replace("_protein", "") ],
                [ it ]
            )
        }

    // Compute the statistics on the protein sequences
    protein_stats = SEQKIT_STATS( ch_proteins )
    // Collect all the stats for each genome into one tsv
    protein_stats_tsv = protein_stats.stats.collectFile(
        name: 'proteins_statistics.tsv', skip: 1, keepHeader: true,  storeDir: params.outdir
    ) { it[1] } // extract the second element as the first is the propagated meta

    ch_versions = ch_versions.mix(SEQKIT_STATS.out.versions.first())


//    Channel.fromPath('$baseDir/assets/shortlist-test.csv').set{ ch_shortlist }
    // Create a channel from the comparisons list that can be sent to the tools
    comp = CREATE_COMPARISONS_LIST('/home/cpauvert/projects/benchmarks/ClavelLab-pocpbenchmark/assets/shortlist-test.csv')
    ch_q_s = comp.csv \
        | splitCsv(header: true) \
        | map {
            row -> tuple(
                 [row.Query,row.Subject].sort().join('-'),
                 row.Query,
                 row.Subject )
            }

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
    EVAL_GENUS_DELINEATION( POCP.out.summary, '/home/cpauvert/projects/benchmarks/ClavelLab-pocpbenchmark/assets/shortlist-test.csv')
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
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
