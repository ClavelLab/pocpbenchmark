//
// BLAST
//

include { BLAST_BLASTP } from '../../modules/local/blast_blastp'

workflow BLAST {
    take:
    ch_faa // [ [meta], [.faa] ]
    ch_pairs // [ Query-Subject, Query, Subject ]

    main:
    ch_matches = Channel.empty()
    ch_versions = Channel.empty()

    // With Query (Q) and Subject/Reference (S)
    // Q-S, Q, S
    // ex: RS01-RS02, RS01, RS02
    // Prepare blastp channels that are common for legacy blast and blast with db
    input_common_blastp = ch_pairs \
        | map{ id, q, s -> tuple(q, id, s )}// Q, Q-S, S
        | combine(ch_faa.map{
            meta, fasta -> tuple(meta.get('id'), fasta.get(0)) // Q, Q.faa
        }, by: 0)
        | map{ q, id, s, q_faa -> tuple( s, q, id, q_faa ) }


    input_blastp = input_common_blastp \
        | combine(ch_faa.map{
            meta, fasta -> tuple(meta.get('id'), fasta.get(0)) // S, S.faa
        }, by: 0) // S, Q, Q-S, Q.faa, S.faa
        | map{
            s, q, id, query, subject -> tuple(
                    ['id':id], query, subject
                )
            }

        /*
            legacy blastp
        */
        ch_blastp = BLAST_BLASTP(
            input_blastp
        )
        ch_blastp.txt.map{ meta, txt ->
            tuple(meta.get('id') + '-blast_blastp', txt)
        }.set{ ch_blastp }

    ch_matches = ch_matches.mix(ch_blastp)

    ch_versions = ch_versions.mix(BLAST_BLASTP.out.versions.first())

    emit:
    matches = ch_matches
    versions = ch_versions
}
