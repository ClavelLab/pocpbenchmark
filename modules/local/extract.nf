process EXTRACT {
    tag "$archive.baseName"
    label 'process_single'

    input:
    file archive // path to the .tar.gz

    output:
    path "xriv"

    script:
    """
    mkdir xriv
    tar -C xriv -xvzf $archive
    """
}

