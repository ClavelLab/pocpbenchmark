process MMSEQS2_SEARCH {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::mmseqs2=14.7e284"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mmseqs2:14.7e284--pl5321hf1761c0_0' :
        'quay.io/biocontainers/mmseqs2:14.7e284--pl5321hf1761c0_0' }"

    input:
    tuple val(meta), path('query_db'), path('subject_db')

    output:
    tuple val(meta), path('*.tsv'), emit: tsv
    path "versions.yml" , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    Q_DB=`find -L ./query_db -name "*.lookup" | sed 's/\\.lookup\$//'`
    S_DB=`find -L ./subject_db -name "*.lookup" | sed 's/\\.lookup\$//'`
    mmseqs search $args --threads $task.cpus \
        \${Q_DB} \\
        \${S_DB} \\
        ${prefix}.db ./ # output db and temp directory
    mmseqs convertalis --format-mode 0 \\
        \${Q_DB} \\
        \${S_DB} \\
        ${prefix}.db ${prefix}.tsv # output db and output tsv
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mmseqs2: \$(mmseqs version)
    END_VERSIONS
    """
}
