process BLAST_MAKEBLASTDB {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::blast=2.14.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/blast:2.14.0--h7d5a4b4_1' :
        'quay.io/biocontainers/blast:2.14.0--h7d5a4b4_1' }"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path('blast_db'), emit: db
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    makeblastdb \\
        -in $fasta \\
        $args
    mkdir blast_db
    mv ${fasta}* blast_db
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        blast: \$(blastn -version 2>&1 | sed 's/^.*blastn: //; s/ .*\$//')
    END_VERSIONS
    """
}
