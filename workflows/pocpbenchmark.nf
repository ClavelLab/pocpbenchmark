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
include { DIAMOND_MAKEDB } from '../modules/nf-core/diamond/makedb/main'
include { DIAMOND_BLASTP } from '../modules/nf-core/diamond/blastp/main'
include { BLAST_MAKEBLASTDB } from '../modules/nf-core/blast/makeblastdb/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow POCPBENCHMARK {

    ch_versions = Channel.empty()

    Channel
        .fromPath( dir_proteins )
        .map {
            // set up a groovy tuple for compatibility with most nf-core modules
            // normally the output of fromPairs
            // see https://nf-co.re/docs/contributing/modules#what-is-the-meta-map
            [
                [ 'id': it.baseName.toString().replace("_protein", "") ],
                [ it ]
            ]
        }.set { ch_proteins }

    // Compute the statistics on the protein sequences
    protein_stats = SEQKIT_STATS( ch_proteins )
    // Collect all the stats for each genome into one tsv
    protein_stats.stats.collectFile(
        name: 'proteins_statistics.tsv', skip: 1, keepHeader: true,  storeDir: params.outdir
    ) { it[1] } // extract the second element as the first is the propagated meta

    ch_versions = ch_versions.mix(SEQKIT_STATS.out.versions.first())

    // Create diamond database
    ch_diamond_db = DIAMOND_MAKEDB( ch_proteins )
    ch_diamond_db.db.view()

    ch_versions = ch_versions.mix(DIAMOND_MAKEDB.out.versions.first())

    // Create blast database
    //ch_blast_db = BLAST_MAKEBLASTDB( ch_proteins.map{ it[1] } )
    //ch_blast_db.db.view()

//    Channel.fromPath('$baseDir/assets/shortlist-test.csv').set{ ch_shortlist }
    // Create a channel from the comparisons list that can be sent to the tools
    comp = CREATE_COMPARISONS_LIST('/home/cpauvert/projects/benchmarks/ClavelLab-pocpbenchmark/assets/shortlist-test.csv')
    comp.csv \
        | splitCsv(header: true) \
        | map {
            row -> tuple(
                ['id':row.Query+'-'+row.Subject],//TODO: sort a list
                 row.Query,
                 row.Subject )
            } | set { ch_q_s }
    // With Query (Q) and Subject/Reference (S)
    // Q-S, Q, S
    // ex: RS01-RS02, RS01, RS02

    // Prepare diamond blastp
    ch_q_s \
        | map{ tuple(['id':it[1]], it[0], it[2] )}// Q, Q-S, S
        | join(ch_proteins)
        | map{ tuple(['id':it[2]], it[0], it[1], it[3] )}
        | join(ch_diamond_db.db)
        // [[id:RS_GCF_001591705.1], [id:RS_GCF_009767945.1], [id:RS_GCF_009767945.1-RS_GCF_001591705.1], [/home/cpauvert/projects/benchmarks/ClavelLab-pocpbenchmark/assets/proteins/RS_GCF_009767945.1_protein.faa], /home/cpauvert/projects/benchmarks/ClavelLab-pocpbenchmark/work/a6/c4c226c3a9e9d7434aa9745da509c8/RS_GCF_001591705.1_protein.faa.dmnd]
        // S, Q, Q-S, Q.faa, S.dmnd
        | multiMap{
            // from a channel to n named channels
            // needed because diamond's process expects 4 Channels not a 4-tuple
            it ->
                query_faa: tuple(it[2], it[3].get(0)) // Q-S, Q.faa
                subject_db: it[4] // S.dmnd
            }
        | set { input_diamond_blastp }

        ch_blastp = DIAMOND_BLASTP(
            input_diamond_blastp.query_faa,
            input_diamond_blastp.subject_db,
            // normally the last two channels are optional
            //  but nextflow complains if not present
            Channel.value("txt"),
            Channel.value("qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore")
        )
        ch_blastp.txt.view()


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
