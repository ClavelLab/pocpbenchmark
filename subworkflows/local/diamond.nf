//
// DIAMOND
//

include { DIAMOND_MAKEDB } from '../../modules/nf-core/diamond/makedb/main'
include { DIAMOND_BLASTP as DIAMOND_FAST } from '../../modules/nf-core/diamond/blastp/main'
include { DIAMOND_BLASTP as DIAMOND_SENSITIVE } from '../../modules/nf-core/diamond/blastp/main'
include { DIAMOND_BLASTP as DIAMOND_VERYSENSITIVE } from '../../modules/nf-core/diamond/blastp/main'
include { DIAMOND_BLASTP as DIAMOND_ULTRASENSITIVE } from '../../modules/nf-core/diamond/blastp/main'

workflow DIAMOND {
    take:
    ch_faa // [ [meta], [.faa] ]
    ch_pairs // [ Query-Subject, Query, Subject ]

    main:
    ch_matches = Channel.empty()
    ch_versions = Channel.empty()

    // Create diamond database
    ch_diamond_db = DIAMOND_MAKEDB( ch_faa )

    ch_versions = ch_versions.mix(DIAMOND_MAKEDB.out.versions.first())


    // With Query (Q) and Subject/Reference (S)
    // Q-S, Q, S
    // ex: RS01-RS02, RS01, RS02
    // Prepare diamond blastp
    input_diamond = ch_pairs \
        | map{ id, q, s -> tuple(q, id, s )}// Q, Q-S, S
        | combine(ch_faa.map{
            meta, fasta -> tuple(meta['id'], fasta) // Q, Q.faa
        }, by: 0)
        | map{ q, id, s, q_faa -> tuple( s, q, id, q_faa ) }
        | combine(ch_diamond_db.db.map{
            meta, diamond -> tuple(meta.get('id'), diamond) // S, S.dmnd
        }, by: 0) // S, Q, Q-S, Q.faa, S.dmnd
        | multiMap{
            // from a unique channel to n named channels
            // needed because diamond's process expects 4 Channels not a 4-tuple
            it ->
                query_faa: tuple(['id':it[2]], it[3]) // Q-S as meta map, Q.faa
                subject_db: it[4] // S.dmnd
            }

        /*
            diamond --fast
        */
        ch_fast = DIAMOND_FAST(
            input_diamond.query_faa,
            input_diamond.subject_db,
            // normally the last two channels are optional
            //  but nextflow complains if not present
            Channel.value("txt"),
            Channel.value("qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore")
        )
        ch_fast.txt.map{ meta, txt ->
            tuple(meta.get('id') + '-diamond_fast', txt)
        }.set{ ch_diamond_fast }

        /*
            diamond --sensitive
        */
        ch_sensitive = DIAMOND_SENSITIVE(
            input_diamond.query_faa,
            input_diamond.subject_db,
            // normally the last two channels are optional
            //  but nextflow complains if not present
            Channel.value("txt"),
            Channel.value("qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore")
        )
        ch_sensitive.txt.map{ meta, txt ->
            tuple(meta.get('id') + '-diamond_sensitive', txt)
        }.set{ ch_diamond_sensitive }


        /*
            diamond --verysensitive
        */
        ch_verysensitive = DIAMOND_VERYSENSITIVE(
            input_diamond.query_faa,
            input_diamond.subject_db,
            // normally the last two channels are optional
            //  but nextflow complains if not present
            Channel.value("txt"),
            Channel.value("qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore")
        )
        ch_verysensitive.txt.map{ meta, txt ->
            tuple(meta.get('id') + '-diamond_verysensitive', txt)
        }.set{ ch_diamond_verysensitive }


        /*
            diamond --ultrasensitive
        */
        ch_ultrasensitive = DIAMOND_ULTRASENSITIVE(
            input_diamond.query_faa,
            input_diamond.subject_db,
            // normally the last two channels are optional
            //  but nextflow complains if not present
            Channel.value("txt"),
            Channel.value("qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore")
        )
        ch_ultrasensitive.txt.map{ meta, txt ->
            tuple(meta.get('id') + '-diamond_ultrasensitive', txt)
        }.set{ ch_diamond_ultrasensitive }

    ch_matches = ch_matches.mix(
        ch_diamond_fast,
        ch_diamond_sensitive,
        ch_diamond_verysensitive,
        ch_diamond_ultrasensitive
    )

    ch_versions = ch_versions.mix(DIAMOND_FAST.out.versions.first())

    emit:
    matches = ch_matches
    versions = ch_versions
}
