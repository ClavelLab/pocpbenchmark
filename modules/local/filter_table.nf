process FILTER_TABLE {
    label 'process_single'

    input:
    path haystack
    val needle

    output:
    path 'table.txt'

    script:
    """
    cat \
        <( head -n 1 $haystack ) \
        <( grep -E "$needle" $haystack) > table.txt
    """
}
