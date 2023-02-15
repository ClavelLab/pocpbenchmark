process COMPARE_POCP {
    tag "COMPARE_POCP"
    label 'process_single'

    conda "bioconda::r-tidyverse=1.3.1"
    container "rocker/tidyverse:4.1"

    input:
    path 'pocp.csv'

    output:
    path "*.csv", emit: csv
    path "*.png", emit: png
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script: // This script is bundled with the pipeline, in ClavelLab/pocp-benchmark-nf/bin/
    """
    compare_pocp.R pocp.csv
    # R could not know the task process name
    sed -i 's/SED_CHANGE_ME_PLEASE/${task.process}/' versions.yml
    """
}
