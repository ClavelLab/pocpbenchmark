//
// MMseqs2
//

include { MMSEQS2_CREATEDB } from '../../modules/local/mmseqs2_createdb'

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

    ch_matches = ch_matches.mix(ch_mmseqs2_db.db)

    ch_versions = ch_versions.mix(MMSEQS2_CREATEDB.out.versions.first())

    emit:
    matches = ch_matches
    versions = ch_versions
}
