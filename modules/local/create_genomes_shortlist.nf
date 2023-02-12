process CREATE_GENOMES_SHORTLIST {
    label 'process_single'

    conda "bioconda::pandas=1.1.5"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:1.1.5' :
        'quay.io/biocontainers/pandas:1.1.5' }"

    input:
    path 'gtdb_metadata.tsv'
    path 'valid_names.tsv'

    output:
    path 'shortlisted_genomes.csv' , emit: csv
    path 'details_counts.txt' , emit: counts
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script: // This script is bundled with the pipeline, in ClavelLab/pocp-benchmark-nf/bin/
    """
    filter_gtdb_data.py

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //')
        pandas: \$(python -c 'import pandas; print(pandas.__version__)')
    END_VERSIONS
    """
}

