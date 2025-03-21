process DIAMOND_MAKEDB {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::diamond=2.1.6"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/diamond:2.1.6--h43eeafb_2' :
        'quay.io/biocontainers/diamond:2.1.6--h43eeafb_2' }"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("${fasta}.dmnd"), emit: db
    path "versions.yml" , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    diamond \\
        makedb \\
        --threads $task.cpus \\
        --in  $fasta \\
        -d $fasta \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        diamond: \$(diamond --version 2>&1 | tail -n 1 | sed 's/^diamond version //')
    END_VERSIONS
    """
}
