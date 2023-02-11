//
// MMseqs2
//

include { MMSEQS2_CREATEDB } from '../../modules/local/mmseqs2_createdb'
include { MMSEQS2_SEARCH as MMSEQS2_S1DOT0 } from '../../modules/local/mmseqs2_search'
include { MMSEQS2_SEARCH as MMSEQS2_S2DOT5 } from '../../modules/local/mmseqs2_search'
include { MMSEQS2_SEARCH as MMSEQS2_S6DOT0 } from '../../modules/local/mmseqs2_search'
include { MMSEQS2_SEARCH as MMSEQS2_S7DOT5 } from '../../modules/local/mmseqs2_search'

workflow MMSEQS2 {
    take:
    ch_faa // [ [meta], [.faa] ]
    ch_pairs // [ Query-Subject, Query, Subject ]

    main:
    ch_matches = Channel.empty()
    ch_versions = Channel.empty()

    /*
        MMseqs2 databases
    */

    ch_mmseqs2_db = MMSEQS2_CREATEDB( ch_faa )

    /*
        MMseqs2 search is between two databases
    */

    // With Query (Q) and Subject/Reference (S)
    // Q-S, Q, S
    // ex: RS01-RS02, RS01, RS02
    // Prepare MMseqs search
    input_mmseqs2 = ch_pairs \
        | map{ id, q, s -> tuple(q, id, s )}// Q, Q-S, S
        | combine(ch_mmseqs2_db.db.map{
            meta, db -> tuple(meta.get('id'), db) // Q, Q db dir
        }, by: 0)
        | map{ q, id, s, q_dir -> tuple( s, q, id, q_dir ) }
        | combine(ch_mmseqs2_db.db.map{
            meta, db -> tuple(meta.get('id'), db) // S, S db dir
        }, by: 0) // S, Q, Q-S, Q db dir, S db dir
        | map{
            s, q, id, query, subject -> tuple(
                    ['id':id], query, subject
                )
            }

    /*
         MMseqs -s 1.0
    */

    ch_mmseqs2_s1dot0 = MMSEQS2_S1DOT0(
        input_mmseqs2
    )
    ch_mmseqs2_s1dot0.tsv.map{ meta, tsv ->
        tuple(meta.get('id') + '-mmseqs2_s1dot0', tsv)
    }.set{ ch_mmseqs2_s1dot0 }

    /*
         MMseqs -s 2.5
    */

    ch_mmseqs2_s2dot5 = MMSEQS2_S2DOT5(
        input_mmseqs2
    )
    ch_mmseqs2_s2dot5.tsv.map{ meta, tsv ->
        tuple(meta.get('id') + '-mmseqs2_s2dot5', tsv)
    }.set{ ch_mmseqs2_s2dot5 }

    /*
         MMseqs -s 6.0
    */

    ch_mmseqs2_s6dot0 = MMSEQS2_S6DOT0(
        input_mmseqs2
    )
    ch_mmseqs2_s6dot0.tsv.map{ meta, tsv ->
        tuple(meta.get('id') + '-mmseqs2_s6dot0', tsv)
    }.set{ ch_mmseqs2_s6dot0 }

    /*
         MMseqs -s 7.5
    */

    ch_mmseqs2_s7dot5 = MMSEQS2_S7DOT5(
        input_mmseqs2
    )
    ch_mmseqs2_s7dot5.tsv.map{ meta, tsv ->
        tuple(meta.get('id') + '-mmseqs2_s7dot5', tsv)
    }.set{ ch_mmseqs2_s7dot5 }


    ch_matches = ch_matches.mix(
        ch_mmseqs2_s1dot0,
        ch_mmseqs2_s2dot5,
        ch_mmseqs2_s6dot0,
        ch_mmseqs2_s7dot5
    )

    ch_versions = ch_versions.mix(MMSEQS2_CREATEDB.out.versions.first())

    emit:
    matches = ch_matches
    versions = ch_versions
}
