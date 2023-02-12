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

# Format the POCP values to blast values versus all other tools
pocp <- read_csv(args[1]) %>%
  # Widen the data with all tools as column
  pivot_wider(names_from = tool, values_from = pocp, id_cols = comparison_id) %>%
  # Select only the columns of diamond and mmseqs
  pivot_longer(cols = -c(comparison_id, blast_blastp), names_to = "tool", values_to = "pocp") %>%
  separate(tool, into = c("aligner", "parameter"), sep = "_", remove = FALSE)

# Write to csv
write_csv(pocp, "blast-vs-all-pocp.csv")

# Fixed plot
p <- pocp %>%
  # Remove the database implementation for a supplementary figure
  filter(tool != "blast_blastpdb") %>%
  ggplot(aes(x = blast_blastp, y = pocp, color = tool, label = comparison_id)) +
  geom_density_2d() +
  geom_point(alpha = 0.7, color = "black") +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "grey") +
  coord_cartesian(xlim = c(0, 100), ylim = c(0, 100)) +
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
  labs(x = "POCP based on blastp (in %)", y = "POCP based on other tools (in %)", color = "Tools evaluated")
# Write the plot
ggsave("plot-pocp.png", p, dpi = 300, height = 5, width = 10, bg = "#ffffff")

# Supplementary figure for blastp vs blastpdb
p <- pocp %>%
  # Keep only the database implementation for a supplementary figure
  filter(tool == "blast_blastpdb") %>%
  ggplot(aes(x = blast_blastp, y = pocp, color = tool, label = comparison_id)) +
  geom_density_2d() +
  geom_point(alpha = 0.7, color = "black") +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "grey") +
  coord_cartesian(xlim = c(0, 100), ylim = c(0, 100)) +
  scale_color_brewer(palette = "Set1") +
  theme_classic() +
  theme(text = element_text(face = "bold", color = "black"), axis.text = element_text(color = "black"), legend.position = "none") +
  labs(x = "POCP based on blastp (in %)", y = "POCP based on blastp database (in %)", color = "Tools evaluated")
# Write the plot
ggsave("plot-pocp-blastpdb.png", p, dpi = 300, height = 5, width = 5, bg = "#ffffff")

# Linear regression of blastp POCP versus other tools
# src: https://cran.r-project.org/web/packages/broom/vignettes/broom_and_dplyr.html
library(broom)
pocp %>%
  group_by(tool) %>%
  nest() %>%
  mutate(
    fit = map(data, ~ lm(blast_blastp ~ pocp, data = .)),
    tidied = map(fit, glance)
  ) %>%
  unnest(tidied) %>%
  select(-data, -fit) %>%
  arrange(desc(adj.r.squared)) %>%
  write_csv(., "blast-vs-all-pocp-r2.csv")

# Write versions
# src: https://stackoverflow.com/a/2470277
fileConn <- file("versions.yml")
writeLines(c(
  paste0("${task.process}", ":"),
  paste("    R:", packageVersion("base")),
  paste("    tidyverse:", packageVersion("tidyverse"))
), fileConn)
close(fileConn)
