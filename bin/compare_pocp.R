#!/usr/bin/env Rscript
# __author__ = "Charlie Pauvert"
# __copyright__ = "Copyright 2022, Charlie Pauvert"
# __license__ = "MIT"

# Compare the POCP values from blast versus the other tools
#  visually with plots and linear regression

# Fetch the arguments
args <- commandArgs(trailingOnly = TRUE)

# Test if the arguments were provided
if (length(args) != 1) {
  stop(
    "The following argument must be supplied:",
    "a csv file of the POCP values obtained by various tools",
  )
}

library(tidyverse)

# Function to format the POCP values to blast values versus all other tools
pivot_pocp <- function(file, column){
  df <- read_csv(file,
           col_types = cols(
             tool = col_character(),
             comparison_id = col_character(),
             pocp = col_double(),
             pocpu = col_double()
           )) %>%
    # Widen the data with all tools as column and prepend pocp or pocpu to the tool
    pivot_wider(names_from = tool, values_from = {{ column }}, id_cols = comparison_id) %>%
    # Select only the columns of diamond and mmseqs
    pivot_longer(cols = -c(comparison_id, blast_blastp), names_to = "tool", values_to = as_label(enquo(column))) %>%
    separate(tool, into = c("aligner", "parameter"), sep = "_", remove = FALSE)
    # Write csv
    write_csv(df, paste0("blast-vs-all-", as_label(enquo(column)), ".csv"))
    return(df)
}

# Format the dataset to compare the POCP versions with the gold standard blast values
df_pocp <- pivot_pocp(args[1], pocp)
df_pocpu <- pivot_pocp(args[1], pocpu)


# Function to generate the pocp vs blast plot and the blast vs blastdb supplementary plot
plot_pocp_vs_blast <- function(df, pocp_var, pocp_label){
  # Get the min max values to set up matching x and y axes intervals
  extremes<- df %>%
    summarise(
      min = min(blast_blastp, {{ pocp_var }}),
      max = max(blast_blastp, {{ pocp_var }})) %>%
    as_vector()

  p <- df %>%
    # Remove the database implementation for a supplementary figure
    filter(tool != "blast_blastpdb") %>%
    ggplot(aes(x = blast_blastp, y = {{ pocp_var }}, color = tool, label = comparison_id)) +
    geom_density_2d() +
    geom_point(alpha = 0.7, color = "black") +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "grey") +
    coord_fixed()+
    scale_y_continuous(limits = extremes)+
    scale_x_continuous(limits = extremes)+
    scale_color_brewer(palette = "Set1") +
    theme_classic() +
    theme(text = element_text(face = "bold", color = "black"), axis.text = element_text(color = "black"), legend.position = "none") +
    facet_wrap(~ factor(tool, levels = c(
      "diamond_fast",
      "diamond_sensitive",
      "diamond_verysensitive",
      "diamond_ultrasensitive",
      "mmseqs2_s1dot0",
      "mmseqs2_s2dot5",
      "mmseqs2_s6dot0",
      "mmseqs2_s7dot5"
    )), nrow = 2) +
    labs(x = paste0(pocp_label, " based on blastp (in %)"),
         y = paste0(pocp_label, " based on other tools (in %)"), color = "Tools evaluated")

  # Supplementary figure for blastp vs blastpdb
  pblast <- df %>%
    # Remove the database implementation for a supplementary figure
    filter(tool == "blast_blastpdb") %>%
    ggplot(aes(x = blast_blastp, y = {{ pocp_var }}, color = tool, label = comparison_id)) +
    geom_density_2d() +
    geom_point(alpha = 0.7, color = "black") +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "grey") +
    coord_fixed()+
    scale_y_continuous(limits = extremes)+
    scale_x_continuous(limits = extremes)+
    scale_color_brewer(palette = "Set1") +
    theme_classic() +
    theme(text = element_text(face = "bold", color = "black"), axis.text = element_text(color = "black"), legend.position = "none") +
    labs(x = paste0(pocp_label, " based on blastp (in %)"),
         y = paste0(pocp_label, " based on blastp database (in %)"), color = "Tools evaluated")

  # Write the plots
  ggsave( paste0("plot-",str_to_lower(pocp_label),".png"),
          p, dpi = 300, height = 5, width = 10, bg = "#ffffff")
  ggsave( paste0("plot-",str_to_lower(pocp_label),"-blastpdb.png"),
         pblast, dpi = 300, height = 5, width = 5, bg = "#ffffff")
}

# Plot the POCP values
plot_pocp_vs_blast(df_pocp, pocp, "POCP")
plot_pocp_vs_blast(df_pocpu, pocpu, "POCPu")

# Function to perform the linear regression of blastp POCP versus other tools
# src: https://cran.r-project.org/web/packages/broom/vignettes/broom_and_dplyr.html
pocp_regression <- function(df, pocp_var, pocp_label){
  require(broom)
  df %>%
    rename(pocp_value = {{ pocp_var }}) %>%
    group_by(tool) %>%
    nest() %>%
    mutate(
      fit = map(data, ~ lm(blast_blastp ~ pocp_value, data = .)),
      tidied = map(fit, glance)
    ) %>%
    unnest(tidied) %>%
    select(-data, -fit) %>%
    arrange(desc(adj.r.squared)) %>%
    mutate(type = pocp_label) %>%
    relocate(type) %>%
    write_csv(., paste0("blast-vs-all-",str_to_lower(pocp_label),"-r2.csv"))
}

pocp_regression(df_pocp, pocp, "POCP")
pocp_regression(df_pocpu, pocpu, "POCPu")

# Write versions
# src: https://stackoverflow.com/a/2470277
fileConn <- file("versions.yml")
writeLines(c(
  paste0("SED_CHANGE_ME_PLEASE", ":"),
  paste("    R:", packageVersion("base")),
  paste("    tidyverse:", packageVersion("tidyverse"))
), fileConn)
close(fileConn)
