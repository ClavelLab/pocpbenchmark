process MMSEQS2_CREATEDB {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::mmseqs2=15.6f452"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mmseqs2:15.6f452--pl5321h6a68c12_0' :
        'quay.io/biocontainers/mmseqs2:15.6f452--pl5321h6a68c12_0' }"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path('mmseqs2_db'), emit: db
    path "versions.yml" , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    mmseqs createdb \\
        $args \\
        $fasta db_$fasta
    mkdir mmseqs2_db
    mv db_${fasta}* mmseqs2_db

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mmseqs2: \$(mmseqs version)
    END_VERSIONS
    """
}
