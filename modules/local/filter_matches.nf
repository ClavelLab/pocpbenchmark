process FILTER_MATCHES {
    tag "$qst_id"
    label 'process_single'

    conda "bioconda::r-tidyverse=1.2.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/r-tidyverse:1.2.1' :
        'quay.io/biocontainers/r-tidyverse:1.2.1' }"

    input:
    tuple val(qst_id), path(matches)

    output:
    path "${qst_id}.csv"       , emit: csv
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    #!/usr/bin/env Rscript
    library(readr)
    library(dplyr)

    df <- readr::read_table("$matches",
        col_names = c(
          "qseqid", "sseqid", "pident", "length",
          "mismatch", "gapopen", "qstart", "qend",
          "sstart", "send", "evalue", "bitscore"
        ),
        col_types = cols(
          qseqid = col_character(),
          sseqid = col_character(),
          pident = col_double(),
          length = col_double(),
          mismatch = col_double(),
          gapopen = col_double(),
          qstart = col_double(),
          qend = col_double(),
          sstart = col_double(),
          send = col_double(),
          evalue = col_double(),
          bitscore = col_double()
        )
    )
    if (nrow(df) == 0) {
        n_matches = 0
    } else {
        if (grepl("mmseqs2", filename)) {
            # MMseqs2 pident is [0-1]
            n_matches = df %>% dplyr::filter(pident > 0.4) %>% nrow()
        } else {
            # blast/diamond pident is [0-100]
            n_matches = df %>% dplyr::filter(pident > 40) %>% nrow()
        }
    }
    # Write to csv
    data.frame(id = "$qst_id", value = n_matches) %>%
        write_csv(paste0("${qst_id}", "csv", sep = "."))

    # Write versions
    # src: https://stackoverflow.com/a/2470277
    fileConn<-file("versions.yml")
    writeLines(c(
        paste0("${task.process}",":"),
        paste("    r-tidyverse:",  packageVersion("tidyverse")),
        fileConn)
    close(fileConn)
    """
}
