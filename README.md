## Introduction

**TL;DR**: `ClavelLab/pocpbenchmark` is a bioinformatics best-practice analysis pipeline for benchmarking proteins alignment tools for improved genus delineation using the Percentage Of Conserved Proteins (POCP).

Genus delineation can be done using Percentage Of Conserved Proteins (POCP), but the original implementation ([Qin, Q.L et al. (2014). *J Bacteriol*](https://doi.org/10.1128/JB.01688-14)) using BLASTP is slow.
Here we benchmark here different tools that should be faster than the BLASTP implementation, but we will first evaluate whether the accurracy of the POCP calculation is not sacrificed in the name of computational performance. We rely on the curated taxonomy and the publicly available genomes of the [Genome Taxonomy Database](https://gtdb.ecogenomic.org/).

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It uses Docker/Singularity containers making installation trivial and results highly reproducible. The [Nextflow DSL2](https://www.nextflow.io/docs/latest/dsl2.html) implementation of this pipeline uses one container per process which makes it much easier to maintain and update software dependencies. Where possible, these processes have been submitted to and installed from [nf-core/modules](https://github.com/nf-core/modules) in order to make them available to all nf-core pipelines, and to everyone within the Nextflow community!

A preprint of our work is available at bioRxiv: 
> Robust genome-based delineation of bacterial genera.
> Charlie Pauvert, Thomas C.A. Hitch, Thomas Clavel.
> bioRxiv 2025.03.17.643616; doi: https://doi.org/10.1101/2025.03.17.643616 

## Pipeline summary

1. Shorlist the genomes of the GTDB that have a valid name, are representative genome, belongs to a family with at least two genera, and to a genus with at least ten genomes.
2. Compute the total numbers of proteins for each of the shortlisted proteomes makde available by the GTDB.
3. Create a list of many-versus-many proteins comparisons to be ran within bacterial family and never with itself.
4. Run the actual sequence comparisons using the following tools: blastp (with and without database creation), diamond and MMseqs2. 
5. Compute two types of POCP for each comparison and each tool based on different filtering strategies of the matches:
    - POCP: using only matches with an e-value < 1e−5, a sequence identity > 40%, and an alignable region of the query protein sequence > 50%. This is the original implementation described in the paper and used in [Protologger](https://github.com/thh32/Protologger/) for instance.
    - POCPu: same as POCP but using only the unique matches of the query sequences, in the same manner as Martin Hölzer [POCP](https://github.com/hoelzer/pocp/tree/1.1.1) implementation.
6. Plot the resulting POCP values against the expected POCP values from blastp
7. Evaluate the genus delineation potential of different POCP implementation based on the GTDB taxonomy of the shortlisted genomes.


## How to run the benchmark

Due to exponentially large numbers of pairwise comparisons and Java Heap Space errors, we made the decision to run the benchmark within family.
Therefore, a preparatory phase of the workflow is needed to list the necessary shortlisted genomes by family.

### Preparatory workflow


1. Install [`Nextflow`](https://www.nextflow.io/docs/latest/getstarted.html#installation) (`>=22.10.1`)

2. Install any of [`Docker`](https://docs.docker.com/engine/installation/), [`Singularity`](https://www.sylabs.io/guides/3.0/user-guide/) (you can follow [this tutorial](https://singularity-tutorial.github.io/01-installation/)), [`Podman`](https://podman.io/), [`Shifter`](https://nersc.gitlab.io/development/shifter/how-to-use/) or [`Charliecloud`](https://hpc.github.io/charliecloud/) for full pipeline reproducibility _(you can use [`Conda`](https://conda.io/miniconda.html) both to install Nextflow itself and also to manage software within pipelines. Please only use it within pipelines as a last resort; see [docs](https://nf-co.re/usage/configuration#basic-configuration-profiles))_.

3. Download the workflow

   ```bash
   nextflow pull ClavelLab/pocpbenchmark
   ```

4. Ensure the correct configuration of the workflow

Note that some form of configuration will be needed so that Nextflow knows how to fetch the required software. This is usually done in the form of a config profile (`YOURPROFILE` in the example command above). You can chain multiple config profiles in a comma-separated string.

   > - The pipeline comes with config profiles called `docker`, `singularity`, `podman`, `shifter`, `charliecloud` and `conda` which instruct the pipeline to use the named tool for software management. For example, `-profile test,docker`.
   > - Please check [nf-core/configs](https://github.com/nf-core/configs#documentation) to see if a custom config file to run nf-core pipelines already exists for your Institute. If so, you can simply use `-profile <institute>` in your command. This will enable either `docker` or `singularity` and set the appropriate execution settings for your local compute environment.
   > - If you are using `singularity`, please use the [`nf-core download`](https://nf-co.re/tools/#downloading-pipelines-for-offline-use) command to download images first, before running the pipeline. Setting the [`NXF_SINGULARITY_CACHEDIR` or `singularity.cacheDir`](https://www.nextflow.io/docs/latest/singularity.html?#singularity-docker-hub) Nextflow options enables you to store and re-use the images from a central location for future pipeline runs.
   > - If you are using `conda`, it is highly recommended to use the [`NXF_CONDA_CACHEDIR` or `conda.cacheDir`](https://www.nextflow.io/docs/latest/conda.html) settings to store the environments in a central location for future pipeline runs.


Note that the default parameters should be the following.

```
params {
   gtdb_proteins_dir = "https://data.gtdb.ecogenomic.org/releases/release214/214.0/genomic_files_reps/gtdb_proteins_aa_reps_r214.tar.gz"
   gtdb_metadata_tsv = "https://data.gtdb.ecogenomic.org/releases/release214/214.0/bac120_metadata_r214.tar.gz"
   valid_names_tsv   = "https://raw.githubusercontent.com/thh32/Protologger/master/DSMZ-latest.tab"

}
```
Note that if you already have GTDB database downloaded, you should specifify the path to the data, see [`winogradsky.config`](conf/winogradsky.config) for an example.

5. Run the preparatory workflow

```bash
nextflow run main.nf -entry PREPBENCHMARK -profile winogradsky,docker --outdir benchmark-gtdb
```

This workflow will create the file `benchmark-gtdb/families_to_run.txt`, which contains the Nextflow commands to be run for each family in the shortlist.
The file contains for instance the command below:

```bash
nextflow run main.nf -entry POCPBENCHMARK -profile winogradsky,docker --outdir benchmark-gtdb-f__Alteromonadaceae --family_shortlist benchmark-gtdb/split_per_family/f__Alteromonadaceae.csv
```

Especially, the file already specific correctly the name of the output directory (`--outdir benchmark-gtdb-f__Alteromonadaceae`) as well as the shortlist of genomes for the family (`--family_shortlist benchmark-gtdb/split_per_family/f__Alteromonadaceae.csv`)


### Benchmark workflow

#### Full benchmark

The full benchmark workflow will then run all 10 methods for the selected family.

```bash
# Optional: git checkout master
nextflow run main.nf -entry POCPBENCHMARK -profile winogradsky,docker --outdir benchmark-gtdb-f__Alteromonadaceae --family_shortlist benchmark-gtdb/split_per_family/f__Alteromonadaceae.csv
nextflow run main.nf -entry POCPBENCHMARK -profile winogradsky,docker --outdir benchmark-gtdb-f__Streptomycetaceae --family_shortlist benchmark-gtdb/split_per_family/f__Streptomycetaceae.csv
```


#### Only recommended method

A leaner workflow can be run with only the recommended method from our analysis: DIAMOND_VERYSENSITIVE.

```bash
git checkout only-pocp-replacement
nextflow run main.nf -entry POCPBENCHMARK -profile winogradsky,docker --outdir benchmark-gtdb-f__Alteromonadaceae --family_shortlist benchmark-gtdb/split_per_family/f__Alteromonadaceae.csv
```

### Selected output files for the analyses

A selection of output files generated by the workflow are used downstream for the analyses.
These files are encapsulated in an archive with the command below:

```bash
./make_pocp_results_archive.sh benchmark-gtdb-f__Alteromonadaceae
```

This command will create `benchmark-gtdb-f__Alteromonadaceae.zip`, and can be applied to all the families that were run for the benchmark.
All the archives created for the article are made available on Zenodo at: <https://doi.org/10.5281/zenodo.14974869>

### Analyses, figures and manuscript workflow

The code for the analyses, figure creations and manuscript is available at: <https://github.com/ClavelLab/pocpbenchmark_manuscript>


## Credits

ClavelLab/pocpbenchmark was originally written by [Charlie Pauvert](https://github.com/cpauvert) and [Thomas C.A. Hitch](https://github.com/thh32).


## Citations

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/master/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
