# Welcome to the iProc Quickstart

Before you can proceed with the next mind-bending scientific 
discovery, you need to confirm that you have a fully functioning 
iProc installation. This guide will help you with that.

## Install iProc

### clone the repository

First, you need to download iProc by cloning the repository from 
GitHub

```bash
git clone -b v2.6.0-beta.3 https://github.com/harvard-nrg/iProc
```

### create a virtual environment

iProc is primarily written in Python (and some `bash` scripts). You will need 
to create a Python virtual environment before you can move forward.

!!! warning "Python version"
    One of the iProc dependencies is `numpy == 1.25.2`, which is compatible
    with Python versions up to Python 3.11. If you want to use a newer 
    version of Python, you will need to change `pyproject.toml` to install
    `numpy == 2.0.0` or greater. <ins>**Be advised that upgrading dependencies 
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

### install external dependencies

iProc requires several external software packages described on the 
[following page](dependencies.md).

!!! warning "FSL" 
    iProc switches FSL versions at runtime. It is <ins>**strongly advised**</ins>
    that you read the [following page](fsl.md) to understand where and how 
    this is done. You will almost certainly need to make modifications to 
    iProc before it will run successfully within your environment.

### verify your installation

Run the following command to verify that you are able to launch iProc

```bash
./iProc.py --help
```

If you're here, you're well on your way to getting iProc up and running. Way
to go :tada:

## Example dataset

!!! note ""
    The following steps are highly choreographed and assume that you are 
    running each command within your iProc base directory.

We have created an example dataset for you to verfiy that you have a fully 
functioning version of iProc installed.

### download and extract the dataset tarball

[Download the data set :material-download:][Dataset]{ .md-button .md-button--primary }

Alternatively, you can copy the link to the dataset above and download the 
tarball using `curl`

```bash
curl -L 'paste link here' --output ASDF.tar.gz
tar xzf ASDF.tar.gz
```

!!! note "FreeSurfer dummy data"
    The example data set includes precomputed FreeSurfer results under 
    `tutorial_data/fs`. If this data is present, iProc will skip running 
    FreeSurfer, which can save several hours of runtime. Remove the `fs` 
    directory if you want iProc to run FreeSurfer.

## Run iProc

Now for the moment you've been waiting for — let's run iProc. You got this :raised_hands:

### set the base directory

Replace the `{{BASEDIR}}` placeholder within `ASDF.cfg` (line 3) with the 
location to your `tutorial_data` directory

```bash
DIR=$(pwd)/tutorial_data
sed -ir s@{{BASEDIR}}@${DIR}@g tutorial_data/mri_data/ASDF/subject_lists/ASDF.cfg
```

### set the fsaverage6 directory

Replace the `{{FSDIR}}` placeholder within `ASDF.cfg` (last line) with the 
location to the `fsaverage6` directory under your FreeSurfer installation

```bash
DIR=${FREESURFER_HOME}/subjects/fsaverage6
sed -ir s@{{FSDIR}}@${DIR}@g tutorial_data/mri_data/ASDF/subject_lists/ASDF.cfg
```

### run iProc

Now, run the following command to launch the first iProc stage, `setup`

```bash
./iProc.py --config tutorial_data/mri_data/subject_lists/ASDF.cfg --executor local --stage setup --bids $(pwd)/bids/sub-ASDF
```

After each stage of the pipeline, iProc will print instructions to the screen 
that will guide you to the next stage. The stages are `setup`, `bet`, 
`unwarp_motioncorrect_align`, `T1_warp_and_mask`, `combine_and_apply_warp`, 
and `filter_and_project`.

[Lmod]: https://lmod.readthedocs.io/en/latest/
[Dataset]: https://www.dropbox.com/scl/fi/ulrgwzg0soeostoaznux6/ASDF-v2.6.0.tar.gz?rlkey=ggqtwjok7kg1eoregq30fojka&st=rcyuyply&dl=0
