process SPLIT_PER_FAMILY {
    label 'process_single'

    conda "bioconda::pandas=1.1.5"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:1.1.5' :
        'quay.io/biocontainers/pandas:1.1.5' }"

    input:
    path 'shortlisted_genomes.csv'

    output:
    path 'f__*.csv' , emit: csv
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script: // This script is bundled with the pipeline, in ClavelLab/pocp-benchmark-nf/bin/
    """
    split_per_family.py

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //')
        pandas: \$(python -c 'import pandas; print(pandas.__version__)')
    END_VERSIONS
    """
}

