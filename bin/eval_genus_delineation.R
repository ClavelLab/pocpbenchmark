#!/usr/bin/env Rscript
# __author__ = "Charlie Pauvert"
# __copyright__ = "Copyright 2022, Charlie Pauvert"
# __license__ = "MIT"

# Evaluate the separation or identity of genus
#  for each comparison based on the taxonomy of the GTDB

library(tidyverse)
# Read the POCP values, pivot to include the two types: POCP POCPu
#  and split the comparison identifier into query subject
pocp <- read_csv("pocp.csv",
           col_types = cols(
             tool = col_character(),
             comparison_id = col_character(),
             pocp = col_double(),
             pocpu = col_double()
           )) %>%
  rename(c("POCP"="pocp", "POCPu"="pocpu")) %>%
  pivot_longer(cols = c(POCP, POCPu), names_to = "type", values_to = "pocp") %>%
  separate(comparison_id, into = c("query", "subject"), sep = "-")

# Read the taxonomy
taxonomy <- read_csv("shortlist.csv") %>%
  select(accession, Genus, gtdb_taxonomy)

# Merge the two dataframe by accession and add the genus and GTDB taxonomy
pocp <- pocp %>%
  left_join(., taxonomy, by = c("query" = "accession")) %>%
  rename(c("query_genus" = "Genus", "query_gtdb_taxonomy" = "gtdb_taxonomy")) %>%
  left_join(., taxonomy, by = c("subject" = "accession")) %>%
  rename(c("subject_genus" = "Genus", "subject_gtdb_taxonomy" = "gtdb_taxonomy"))


# Useful functions for classification
label_confusion_matrix <- function(tbl, same, same_truth) {
  # same: the column of the tibble stating whether the item are the same
  # same_truth: the truth value of whether or not it should have been the same
  tbl %>%
    mutate(
      class = case_when(
        {{ same_truth }} & {{ same }} ~ "TP",
        !{{ same_truth }} & {{ same }} ~ "FP",
        !{{ same_truth }} & !{{ same }} ~ "TN",
        {{ same_truth }} & !{{ same }} ~ "FN",
      ),
      class = factor(class, levels = c("TP", "FP", "TN", "FN"))
    )
}

get_classification_metrics <- function(tbl) {
  tbl %>%
    count(class, .drop = FALSE) %>% # Count all categories even when 0
    pivot_wider(names_from = "class", values_from = "n") %>%
    summarise(
      # How many times we identify same, out of all cases of truly same?
      Sensitivity = TP / (TP + FN),
      #  How many times we identify different, out of all cases of different?
      Specificity = TN / (TN + FP),
      #  How many time we wrongly identify same, out of all times we identify same
      FDR = FP / (FP + TP)
    ) %>%
    mutate(
      Sensitivity = replace_na(Sensitivity, 0),
      Specificity = replace_na(Specificity, 0),
      FDR = replace_na(FDR, 0)
    )
}

describe_count_confusion_matrix <- function(tbl) {
  # tbl: A tibble with a column of class TP, FP, TN, FN
  tbl %>%
    count(class, .drop = FALSE) %>%
    mutate(
      description = case_when(
        class == "TP" ~ "Correct genus identity",
        class == "FP" ~ "Wrong genus identity",
        class == "TN" ~ "Correct genus separation",
        class == "FN" ~ "Wrong genus separation"
      )
    )
}


# classify each genome comparison on whether they are from the same genus based on:
# 1. taxonomy (aka truth)
# 2. POCP > 50%
# 3. Random choice
classification <- pocp %>%
  mutate(
    same_genus_truth = query_genus == subject_genus,
    same_genus = pocp > 50.0,
    same_genus_random = sample(c(TRUE, FALSE), size = n(), replace = TRUE) # Random choice
  )

classification_pocp <- classification %>% label_confusion_matrix(same_genus, same_genus_truth)
classification_rand <- classification %>% label_confusion_matrix(same_genus_random, same_genus_truth)

# Annotate all comparisons with TP, FP, FN, TN
classification_annotated <- classification_pocp %>%
  left_join(classification_rand %>%
    select(type, tool, query, subject, class),
  by = c("type", "tool", "query", "subject"), suffix = c("", "_random")
  ) %>%
  relocate(
    type, tool, query, subject, pocp, query_genus, query_gtdb_taxonomy, subject_genus,
    subject_gtdb_taxonomy, same_genus_truth, same_genus, class, same_genus_random, class_random
  ) # %>%
write_csv(classification_annotated, "comparisons_classification_pocp_rand.csv")

# Compute classical classifications metrics
classification_pocp %>%
  group_by(type, tool) %>%
  nest() %>%
  mutate(metrics = map(data, get_classification_metrics)) %>%
  unnest(metrics) %>%
  ungroup() %>%
  select(-data) %>%
  left_join(classification_rand %>% group_by(type, tool) %>% nest() %>%
    mutate(metrics = map(data, get_classification_metrics)) %>%
    unnest(metrics) %>% ungroup() %>% select(-data), by = c("type", "tool"), suffix = c("", "_random")) %>%
  relocate(
    type, tool, Sensitivity, Sensitivity_random,
    Specificity, Specificity_random,
    FDR, FDR_random
  ) %>%
  write_csv(., "evaluate_genus_delineation.csv")

# Detail the counts of TP, FP, FN, TN
classification_pocp %>%
  group_by(type, tool) %>%
  nest() %>%
  mutate(desc = map(data, describe_count_confusion_matrix)) %>%
  unnest(desc) %>%
  select(-data) %>%
  left_join(classification_rand %>% group_by(type, tool) %>%
    nest() %>%
    mutate(desc = map(data, describe_count_confusion_matrix)) %>%
    unnest(desc) %>%
    select(-data, -description), by = c("type", "tool", "class"), suffix = c("", "_random")) %>%
  relocate(type, tool, class, description, n, n_random) %>%
  write_csv(., "counts-evaluate_genus_delineation.csv")

# Write versions
# src: https://stackoverflow.com/a/2470277
fileConn <- file("versions.yml")
writeLines(c(
  paste0("SED_CHANGE_ME_PLEASE", ":"),
  paste("    R:", packageVersion("base")),
  paste("    tidyverse:", packageVersion("tidyverse"))
), fileConn)
close(fileConn)
