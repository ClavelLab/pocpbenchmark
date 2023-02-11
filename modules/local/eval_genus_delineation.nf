process EVAL_GENUS_DELINEATION {
    tag "EVAL_GENUS_DELINEATION"
    label 'process_single'

    conda "bioconda::r-tidyverse=1.3.1"
    container "rocker/tidyverse:4.1"

    input:
    path 'pocp.csv'
    path 'shortlist.csv'

    output:
    path "*.csv", emit: csv
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script: // This script is bundled with the pipeline, in ClavelLab/pocp-benchmark-nf/bin/
    """
    eval_genus_delineation.R pocp.csv shortlist.csv
    """
}
