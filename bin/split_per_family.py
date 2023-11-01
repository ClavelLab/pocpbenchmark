#!/usr/bin/env python3

"""Split the shortlisted genomes by family."""

import pandas as pd

shortlist = pd.read_csv('shortlisted_genomes.csv')
by_fam = shortlist.groupby("Family")

for name, group in by_fam:
    group.to_csv(f"{name}.csv", index = False)


