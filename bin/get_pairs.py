#!/usr/bin/env python3

"""Provide a list of comparisons based on a table of shortlisted genomes."""

import sys
import pandas as pd
import itertools

if len(sys.argv) != 2:
    raise ValueError("Please provide the path to a tsv file formatted according to the GTDB and representing the shorlisted genomes.")

shortlisted_genomes = sys.argv[1]


def cartesian_product_wo_self(df, col):
    # Cartesian product of a column col in DataFrame (w/o self comparison)
    # inspired by https://stackoverflow.com/a/61463145
    # warning: should not be named query because it is also a method
    combinations = pd.DataFrame(
        itertools.product(df.loc[:, col], df.loc[:, col]), columns=["Query", "Subject"]
    )
    return combinations[combinations.Query != combinations.Subject]


# List of genomes shortlisted for the comparison
shortlist = pd.read_csv(shortlisted_genomes)

# Generate the cartesian product of all genomes within a Family
#  without comparing a genome to itself
comparisons = shortlist.groupby("Family")
comparisons = comparisons.apply(cartesian_product_wo_self, "accession")
# Write to stdout
comparisons.loc[:, ['Query', 'Subject']].to_csv(sys.stdout, index = False)
