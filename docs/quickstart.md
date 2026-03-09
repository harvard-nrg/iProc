# Welcome to the iProc Quickstart
Before you can proceed with your next mind-bending scientific 
discovery, you need to confirm that you have a fully functioning 
iProc installation. This guide will help you with that.

!!! question "Looking for more in depth documentation?"
    This quickstart is highly choreographed. The intent is to ensure that you 
    have iProc installed correctly, and nothing more. For more detailed iProc
    documentation, please refer to the [Full Tutorial][].

## Installing iProc

### clone the repository

First, you need to download iProc by cloning the repository from 
GitHub

```bash
git clone -b v2.6.0-beta.3 https://github.com/harvard-nrg/iProc
```

### create a virtual environment

iProc is primarily written in Python (and some `bash` scripts). You will need 
to create a Python virtual environment before you can proceed.

!!! warning "Python version"
    One of the iProc dependencies is `numpy == 1.25.2`, which is compatible
    with Python versions up to Python 3.11. If you want to use a newer 
    version of Python, you will need to change `pyproject.toml` to install
    `numpy == 1.26.2` or greater. <ins>**Be advised that upgrading dependencies 
    has not been validated.**</ins>

```bash
cd iProc
python3.11 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
```

### install iProc

To install iProc and its Python dependencies, run the following command within 
your activated virtual environment

```bash
pip install .
```

### external dependencies

iProc requires several external software packages described on the 
[following page][Dependencies].

!!! warning "FSL" 
    iProc switches FSL versions at runtime. It is <ins>**strongly advised**</ins>
    that you read the [following page][FSL Notes] to understand where and how 
    this is done. You will almost certainly need to make modifications to 
    iProc before it will run successfully within your environment.

### verifying your installation

Run the following command to verify that you are able to launch iProc

```bash
./iProc.py --help
```

If you're here, you're well on your way to getting iProc up and running. Way
to go :tada:

## Example dataset

We have created an example dataset for you to verfiy that you have a fully 
functioning version of iProc installed.

### download the dataset

!!! info "Data Use Terms"
    Make sure you have read and agree to the [Data Use Terms][] before
    proceeding.

Download the dataset from [Harvard Dataverse][]{:target="_blank"}

- [x] Go to [Harvard Dataverse][]{:target="_blank"}
- [x] Click on the `Sign Up` link and create an account
- [x] Log into Dataverse with your new account
- [x] Go to the [iProc Dataset][DOI]{:target="_blank"}
- [x] Under the `Files` tab, click on the file `ASDF-vX.X.X.tar.gz`
- [x] Click on `Access File` then `Request Access`
- [x] Read the Data Use Terms before clicking `Request Access`
- [x] Check your email for approval

### extract the dataset

The dataset is a compressed `tar` archive. Extract the archive with the
following command

```bash
tar xzf ASDF-vX.X.X.tar.gz
```

!!! note "FreeSurfer dummy data"
    The example data set includes precomputed FreeSurfer results under 
    `tutorial_data/fs`. If this data is present, iProc will skip running 
    FreeSurfer, which can save several hours of runtime. Remove the `fs` 
    directory if you want iProc to run FreeSurfer.

## Running iProc

Now for the moment you've been waiting for — let's run iProc. You got this :raised_hands:

### set the base directory

Replace the `{{BASEDIR}}` placeholder within `ASDF.cfg` (line 3) with the 
location to your `tutorial_data` directory

```bash
DIR=$(pwd)/tutorial_data
sed -ir s@{{BASEDIR}}@${DIR}@g tutorial_data/mri_data_AP/ASDF/subject_lists/ASDF.cfg
```

### set the fsaverage6 directory

Replace the `{{FSDIR}}` placeholder within `ASDF.cfg` (last line) with the 
location to the `fsaverage6` directory under your FreeSurfer installation

```bash
DIR=${FREESURFER_HOME}/subjects/fsaverage6
sed -ir s@{{FSDIR}}@${DIR}@g tutorial_data/mri_data_AP/ASDF/subject_lists/ASDF.cfg
```

### run iProc

Now, run the following command to launch the first iProc stage, `setup`

```bash
./iProc.py --config tutorial_data/mri_data_AP/subject_lists/ASDF.cfg --executor local --stage setup --bids $(pwd)/bids/sub-ASDF
```

After each stage of the pipeline, iProc will print instructions to the screen 
that will guide you to the next stage. The stages are `setup`, `bet`, 
`unwarp_motioncorrect_align`, `T1_warp_and_mask`, `combine_and_apply_warp`, 
and `filter_and_project`.

[Full Tutorial]: full-tutorial.md
[Dependencies]: dependencies.md
[FSL Notes]: fsl.md
[Lmod]: https://lmod.readthedocs.io/en/latest/
[Data Use Terms]: data-use-terms.md
[Harvard Dataverse]: https://dataverse.harvard.edu
[DOI]: https://doi.org/10.7910/DVN/DWWVSN
