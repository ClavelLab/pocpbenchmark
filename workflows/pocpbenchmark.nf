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
include { BLAST_MAKEBLASTDB } from '../modules/nf-core/blast/makeblastdb/main'

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
    protein_stats.stats.collectFile(
        name: 'proteins_statistics.tsv', skip: 1, keepHeader: true,  storeDir: params.outdir
    ) { it[1] } // extract the second element as the first is the propagated meta

    ch_versions = ch_versions.mix(SEQKIT_STATS.out.versions.first())

    // Create blast database
    //ch_blast_db = BLAST_MAKEBLASTDB( ch_proteins.map{ it[1] } )
    //ch_blast_db.db.view()

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
