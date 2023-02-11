process MMSEQS2_CREATEDB {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::mmseqs2=14.7e284"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mmseqs2:14.7e284--pl5321hf1761c0_0' :
        'quay.io/biocontainers/mmseqs2:14.7e284--pl5321hf1761c0_0' }"


    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("${meta.id}*"), emit: db
    path "versions.yml" , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mmseqs createdb $args $fasta $prefix
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mmseqs2: \$(mmseqs version)
    END_VERSIONS
    """
}
