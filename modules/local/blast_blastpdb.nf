process BLAST_BLASTPDB {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::blast=2.14.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/blast:2.14.0--h7d5a4b4_1' :
        'quay.io/biocontainers/blast:2.14.0--h7d5a4b4_1' }"

    input:
    tuple val(meta), path(fasta)
    path  db

    output:
    tuple val(meta), path('*.blastp.txt'), emit: txt
    path "versions.yml"                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    DB=`find -L ./ -name "*.pdb" | sed 's/\\.pdb\$//'`
    blastp \\
        -num_threads $task.cpus \\
        -db \$DB \\
        -query $fasta \\
        -outfmt 6 \\
        $args \\
        -out ${prefix}.blastp.txt
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        blast: \$(blastp -version 2>&1 | sed 's/^.*blastp: //; s/ .*\$//')
    END_VERSIONS
    """
}
