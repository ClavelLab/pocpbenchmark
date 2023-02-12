#!/usr/bin/env Rscript
# __author__ = "Charlie Pauvert"
# __copyright__ = "Copyright 2022, Charlie Pauvert"
# __license__ = "MIT"

# From all the filtered matches of pairwise comparisons with different tools,
#  and counts of proteins compared, compute the Percentage of Conserved Proteins

# Fetch the arguments
args <- commandArgs(trailingOnly = TRUE)

# Test if the arguments were provided
if (length(args) != 2) {
  stop(
    "The following arguments must be supplied:",
    "1. seqkit-produced tsv file with the proteins counts",
    "2. csv file indicating the number of filtered matches"
  )
}


library(tidyverse)

# Importing the proteins statistics
protein_stats <- read_table(args[1],
  col_types = cols(
    file = col_character(),
    format = col_character(),
    type = col_character(),
    num_seqs = col_double(),
    sum_len = col_double(),
    min_len = col_double(),
    avg_len = col_double(),
    max_len = col_double()
  )
) %>%
  select(file, num_seqs) %>%
  mutate(file = str_replace(file, "_protein.faa", ""))
# Format into a named list of total protein number per genome
total_proteins <- setNames(protein_stats[["num_seqs"]], protein_stats[["file"]])

# List the matches into a dataframe to group pairs (query-subject and subject-query) with the tool used
#
# import the count of matches
comparisons <- read_csv(args[2],
  col_types = cols(
    id = col_character(),
    n_matches = col_double()
  )
) %>%
  # Split the id to extract the relevant identifiers: query, subject and tool
  separate("id", into = c("query", "subject", "tool"), sep = "-") %>%
  # Add the total count of proteins
  mutate(
    query_proteins = total_proteins[query],
    subject_proteins = total_proteins[subject],
  ) %>%
  # For each row, create an identifier (query-subject) for(query-subject *and* subject-query)
  rowwise() %>%
  mutate(comparison_id = paste(sort(c(query, subject)), collapse = "-"))

# Write the details of the matches to a csv file
write_csv(comparisons, "details-matches.csv")

# Compute the percentage of conserved proteins (POCP) between two genomes
# as [(C1 + C2)/(T1 + T2)] · 100%, where C1 and C2 represent the conserved number of proteins
# in the two genomes being compared, respectively, and T1 and T2 represent the total number of
# proteins in the two genomes being compared, respectively
# src: https://doi.org/10.1128/JB.01688-14
#
comparisons %>%
  # comparison_id is an identifier (query-subject) for (query-subject *and* subject-query)
  group_by(tool, comparison_id) %>%
  # Compute POCP
  transmute(pocp = 100 * (sum(n_matches) / sum(query_proteins, subject_proteins))) %>%
  # Remove redundant rows, keep only one for two comparisons
  unique() %>%
  ungroup() %>%
  arrange(comparison_id, tool) %>%
  write_csv(., "pocp.csv")


# Write versions
# src: https://stackoverflow.com/a/2470277
fileConn <- file("versions.yml")
writeLines(c(
  paste0("${task.process}", ":"),
  paste("    R:", packageVersion("base"))
  paste("    tidyverse:", packageVersion("tidyverse"))
), fileConn)
close(fileConn)
