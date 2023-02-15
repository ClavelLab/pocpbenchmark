# ClavelLab/pocpbenchmark: Output

## Introduction

This document describes the output produced by the pipeline.

The files and directories listed below will be created in the `outdir` directory after the pipeline has finished. All paths are relative to the top-level results directory.

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/) and performs the following steps:

1. Shorlist the genomes of the GTDB
2. Compute the total numbers of proteins in shortlisted genomes with SeqKit
3. Create a list of many-versus-many proteins comparisons to be ran
4. Run the actual sequence comparisons using the following tools: blastp (with and without database creation), diamond and MMseqs2.
5. Compute two types of POCP after filtering matches
6. Plot the resulting POCP values against the expected POCP values from blastp
7. Evaluate the genus delineation potential of different POCP implementation based on the GTDB taxonomy of the shortlisted genomes.


### `proteins_statistics.csv`

This is a comma separated table of the statistics of the proteomes computed by SeqKit.

```
file	format	type	num_seqs	sum_len	min_len	avg_len	max_len	Q1	Q2	Q3	sum_gap	N50	Q20(%)	Q30(%)
RS_GCF_013009555.1_protein.faa	FASTA	Protein	4631	1678379	30	362.4	1893	172.0	305.0	463.0	0	463	0.00	0.00
RS_GCF_000012825.1_protein.faa	FASTA	Protein	4218	1537182	30	364.4	1893	176.0	308.0	468.0	0	465	0.00	0.00
```

The individual csv files for each proteome can be found in the `seqkit_stats` folder.

### `create_genomes_shortlist`

This folder contains the two following files:
 
- `details_counts.txt`: with the decreasing counts of genomes for every filter applied
- `shortlisted_genomes.csv`: the subset of the tab-separated table of GTDB genomes.

### `create_comparisons_list`

A comma-separated table with the comparisons to be run are listed in the `pairs.csv` file.

### `blast_*`, `diamond_*` and `mmseqs_*`

These directories contain the matches resulting from the many-versus-many comparisons as well as databases files. The suffix after the tool names indicated the type of parameters that differed from the default that were used for running the comparisons. Please note that the `blast_blastpdb` contains only the latest created database.

### `filter_matches`  and `matches.csv`

This directory contains the aggregation of all the matches after filtering by percentage identity.
A comma-separated table with the combined counts of matches for each comparison and each tool can be foudn in `matches.csv`.

### `pocp`

This folder contains the two following files:
 
- `details-matches.csv`: with the matches counts and the associated counts for query and subject genomes

```
query,subject,tool,n_matches,n_unique_matches,query_proteins,subject_proteins,comparison_id
RS_GCF_000376985.1,RS_GCF_001591705.1,mmseqs2_s2dot5,1245,974,2334,2510,RS_GCF_000376985.1-RS_GCF_001591705.1
RS_GCF_013009555.1,RS_GCF_000262545.1,blast_blastpdb,1573,1273,4631,2142,RS_GCF_000262545.1-RS_GCF_013009555.1
```

- `pocp.csv`: the POCP and POCPu (with only unique matches) for each tool and each comparison

```
tool,comparison_id,pocp,pocpu
blast_blastp,RS_GCF_000012825.1-RS_GCF_000262545.1,46.82389937106918,37.028301886792455
blast_blastpdb,RS_GCF_000012825.1-RS_GCF_000262545.1,46.82389937106918,37.028301886792455
```

### `compare_pocp`

This directory contains the results of the comparison of the POCP values with the blastp implementation.

The main figures for the POCP comparison for POCP and POCPu are: 
-  `plot-pocp.png`
-  `plot-pocpu.png`

A additional figure indicate the comparison with the multi-threaded blastp with database implementation:
-  `plot-pocp-blastpdb.png`
-  `plot-pocpu-blastpdb.png`

The following comma-separated table contains the

-  `blast-vs-all-pocp*-r2.csv`: results of the linear regression for POCP and POCPu with the blastp values

```
type,tool,r.squared,adj.r.squared,sigma,statistic,p.value,df,logLik,AIC,BIC,deviance,df.residual,nobs
POCP,blast_blastpdb,1,1,3.4638050250805627e-16,2954886543556248e19,6.871786055770036e-69,1,206.29672683420156,-406.59345366840313,-407.21817526071897,4.799178100709343e-31,4,6
POCP,mmseqs2_s6dot0,0.9998715095991418,0.9998393869989273,0.3374653516304142,31126.73018128037,6.19143385500741e-9,1,-0.7794812602508466,7.5589625205016935,6.934240928185859,0.4555314542041563,4,6
``` 

-  `blast-vs-all-pocp*.csv`: the comma-separated file used for the linear regression

```
comparison_id,blast_blastp,tool,aligner,parameter,pocp
RS_GCF_000012825.1-RS_GCF_000262545.1,46.82389937106918,blast_blastpdb,blast,blastpdb,46.82389937106918
RS_GCF_000012825.1-RS_GCF_000262545.1,46.82389937106918,diamond_fast,diamond,fast,39.37106918238994
```

### `eval_genus_delineation`

This directory contains the results of the analysis for using POCP or POCPu to delineate genus based on the gold standard taxonomy of the GTDB:

- `evaluate_genus_delineation.csv`: a summary for each tool and POCP and POCPu using classification metrics to assess the delineation. They are complemented by random classifications scores as well:

```
type,tool,Sensitivity,Sensitivity_random,Specificity,Specificity_random,FDR,FDR_random
POCP,blast_blastp,1,1,0.75,0.5,0.3333333333333333,0.5
POCPu,blast_blastp,0.5,0.5,1,0.25,0,0.75
```

- `counts-evaluate_genus_delineation.csv`: a table breaking down the classification scores into the confusion matrix:

```
type,tool,class,description,n,n_random
POCP,blast_blastp,TP,Correct genus identity,2,2
POCP,blast_blastp,FP,Wrong genus identity,1,2
POCP,blast_blastp,TN,Correct genus separation,3,2
POCP,blast_blastp,FN,Wrong genus separation,0,0
```

- `comparisons_classification_pocp_rand.csv`: a table indicating for each comparison with each tool and for POCP and POCPu whether it belong to one of the four category of the confusion matrix

```
type,tool,query,subject,pocp,query_genus,query_gtdb_taxonomy,subject_genus,subject_gtdb_taxonomy,same_genus_truth,same_genus,class,same_genus_random,class_random
POCP,blast_blastp,RS_GCF_000012825.1,RS_GCF_000262545.1,46.82389937106918,g__Phocaeicola,d__Bacteria;p__Bacteroidota;c__Bacteroidia;o__Bacteroidales;f__Bacteroidaceae;g__Phocaeicola;s__Phocaeicola vulgatus,g__Prevotella,d__Bacteria;p__Bacteroidota;c__Bacteroidia;o__Bacteroidales;f__Bacteroidaceae;g__Prevotella;s__Prevotella bivia,FALSE,FALSE,TN,TRUE,FP
POCPu,blast_blastp,RS_GCF_000012825.1,RS_GCF_000262545.1,37.028301886792455,g__Phocaeicola,d__Bacteria;p__Bacteroidota;c__Bacteroidia;o__Bacteroidales;f__Bacteroidaceae;g__Phocaeicola;s__Phocaeicola vulgatus,g__Prevotella,d__Bacteria;p__Bacteroidota;c__Bacteroidia;o__Bacteroidales;f__Bacteroidaceae;g__Prevotella;s__Prevotella bivia,FALSE,FALSE,TN,FALSE,TN
```

### Miscellaneous


The folder `extract` and `filter_table` are created during execution and do not contain relevant output for the benchmark.

### Pipeline information

Output files

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  - Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `software_versions.yml`. The `pipeline_report*` files will only be present if the `--email` / `--email_on_fail` parameter's are used when running the pipeline.


Nextflow keeps track of the time, memory and cpu usage of each steps ([link](https://www.nextflow.io/docs/latest/tracing.html?highlight=duration#trace-report)). But the CPU usage are percentage that could go above 100% in case of multiple CPUs, however different time (waiting time, elapsed time) are reported in second and the memory usage can also indicate Swap usage ([doc](https://www.nextflow.io/docs/latest/metrics.html#metrics)).

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.
