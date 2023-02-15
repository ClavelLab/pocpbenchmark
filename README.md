## Introduction

**TL;DR**: `ClavelLab/pocpbenchmark` is a bioinformatics best-practice analysis pipeline for Benchmarking proteins alignment tools for improved genus delineation using the Percentage Of Conserved Proteins (POCP).

Genus delineation can be done using Percentage Of Conserved Proteins (POCP), but the original implementation ([Qin, Q.L et al. (2014). *J Bacteriol*](https://doi.org/10.1128/JB.01688-14)) using BLASTP is slow.
Here we benchmark here different tools that should be faster than the BLASTP implementation, but we will first evaluate whether the accurracy of the POCP calculation is not sacrificed in the name of computational performance. We rely on the curated taxonomy and the publicly available genomes of the [Genome Taxonomy Database](https://gtdb.ecogenomic.org/).

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It uses Docker/Singularity containers making installation trivial and results highly reproducible. The [Nextflow DSL2](https://www.nextflow.io/docs/latest/dsl2.html) implementation of this pipeline uses one container per process which makes it much easier to maintain and update software dependencies. Where possible, these processes have been submitted to and installed from [nf-core/modules](https://github.com/nf-core/modules) in order to make them available to all nf-core pipelines, and to everyone within the Nextflow community!


## Pipeline summary

1. Shorlist the genomes of the GTDB that have a valid name, are representative genome, belongs to a family with at least two genera, and to a genus with at least ten genomes.
2. Compute the total numbers of proteins for each of the shortlisted proteomes makde available by the GTDB.
3. Create a list of many-versus-many proteins comparisons to be ran within bacterial family and never with itself.
4. Run the actual sequence comparisons using the following tools: blastp (with and without database creation), diamond and MMseqs2. 
5. Compute two types of POCP for each comparison and each tool based on different filtering strategies of the matches:
    - POCP: using only matches with an e-value < 1e−5, a sequence identity > 40%, and an alignable region of the query protein sequence > 50%. This is the original implementation described in the paper and used in [Protologger](https://github.com/thh32/Protologger/) for instance.
    - POCPu: same as POCP but using only the unique matches of the query sequences, in the same manner as Martin Hölzer [POCP](https://github.com/hoelzer/pocp) implementation.
6. Plot the resulting POCP values against the expected POCP values from blastp
7. Evaluate the genus delineation potential of different POCP implementation based on the GTDB taxonomy of the shortlisted genomes.

## Generation of the test dataset

In order to test the workflow during the development, for two different families, we selected three species so that two species belong to the same genus and one belongs to a different genus.
A toy dataset was generated with the first three proteins sequences of these species using the following command:

```bash
# Fetch the protein sequences of the GTDB
curl -JLO https://data.gtdb.ecogenomic.org/releases/release207/207.0/genomic_files_reps/gtdb_proteins_aa_reps_r207.tar.gz
# Took 1h21 for 40.2G
tar xvf gtdb_proteins_aa_reps_r207.tar.gz
# Get the first three proteins
for i in RS_GCF_000262545.1 RS_GCF_000012825.1 RS_GCF_013009555.1 RS_GCF_001591705.1 RS_GCF_009767945.1 RS_GCF_000376985.1;do head -n 6 /DATA/gtdb/protein_faa_reps/bacteria/${i}_protein.faa > ${i}_protein.faa ; done
```

## Quick Start

1. Install [`Nextflow`](https://www.nextflow.io/docs/latest/getstarted.html#installation) (`>=22.10.1`)

2. Install any of [`Docker`](https://docs.docker.com/engine/installation/), [`Singularity`](https://www.sylabs.io/guides/3.0/user-guide/) (you can follow [this tutorial](https://singularity-tutorial.github.io/01-installation/)), [`Podman`](https://podman.io/), [`Shifter`](https://nersc.gitlab.io/development/shifter/how-to-use/) or [`Charliecloud`](https://hpc.github.io/charliecloud/) for full pipeline reproducibility _(you can use [`Conda`](https://conda.io/miniconda.html) both to install Nextflow itself and also to manage software within pipelines. Please only use it within pipelines as a last resort; see [docs](https://nf-co.re/usage/configuration#basic-configuration-profiles))_.

3. Download the pipeline and test it on a minimal dataset with a single command:

   ```bash
   nextflow run ClavelLab/pocpbenchmark -profile test,YOURPROFILE --outdir <OUTDIR>
   ```

   Note that some form of configuration will be needed so that Nextflow knows how to fetch the required software. This is usually done in the form of a config profile (`YOURPROFILE` in the example command above). You can chain multiple config profiles in a comma-separated string.

   > - The pipeline comes with config profiles called `docker`, `singularity`, `podman`, `shifter`, `charliecloud` and `conda` which instruct the pipeline to use the named tool for software management. For example, `-profile test,docker`.
   > - Please check [nf-core/configs](https://github.com/nf-core/configs#documentation) to see if a custom config file to run nf-core pipelines already exists for your Institute. If so, you can simply use `-profile <institute>` in your command. This will enable either `docker` or `singularity` and set the appropriate execution settings for your local compute environment.
   > - If you are using `singularity`, please use the [`nf-core download`](https://nf-co.re/tools/#downloading-pipelines-for-offline-use) command to download images first, before running the pipeline. Setting the [`NXF_SINGULARITY_CACHEDIR` or `singularity.cacheDir`](https://www.nextflow.io/docs/latest/singularity.html?#singularity-docker-hub) Nextflow options enables you to store and re-use the images from a central location for future pipeline runs.
   > - If you are using `conda`, it is highly recommended to use the [`NXF_CONDA_CACHEDIR` or `conda.cacheDir`](https://www.nextflow.io/docs/latest/conda.html) settings to store the environments in a central location for future pipeline runs.

4. Start running the benchmark!


   ```bash
   nextflow run ClavelLab/pocpbenchmark --outdir <OUTDIR> -profile <docker/singularity/podman/shifter/charliecloud/conda/institute>
   ```

## Credits

ClavelLab/pocpbenchmark was originally written by [Charlie Pauvert](https://github.com/cpauvert) and [Thomas C.A. Hitch](https://github.com/thh32).


## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

## Citations

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/master/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
