# iProc - individualized fMRI preprocessing pipeline
------------------------------------------------
Many human neuroimaging practices rely on combining measurements from many people in order to obtain statistical power. This approach collapses meaningful variation within each individual. iProc is designed to preprocess and combine data from a deeply-sampled *individual* brains, building statistical power by combining multiple scans from the same individual.

# NOTES
This is the branch J is working on to incorporate multi-echo and STAR's topup and BIDS.
TESTING TESTING

# Acknowledgments

iProc was made possible through the support of the Conte Center for Research in OCD NIMH Grant P50MH106435 and the Harvard Center for Brain Science.
The core data handling pipeline was developed and validated by the Buckner Lab, particularly Rod Braga, Lauren DiNicola.
The CLI and HCP management engine was developed, tested, and optimized by the Neuroinformatics Research Group, particularly Harris Hoke and Tim O'Keefe.
Thanks also to our test users, in particular Peter Angeli and Lindsay Hanford.
For a sample use case, see https://doi.org/10.1152/jn.00808.2018. 

# Initialization
If you're on the NCF, use the [`modules`](https://www.rc.fas.harvard.edu/resources/documentation/software-on-odyssey/intro/) system to load iproc and its 
dependencies

```bash
module load iProc/0.6.0-ncf
```
For development purposes, you can also load dependencies by sourcing iProc/modules7.sh.

# Dependencies
iProc.py depends on several third party software packages. If you're on the NCF and load iProc as above, these will all be be loaded automatically.

| package      | version              |
|--------------|----------------------|
| python       | `~2.7`               |
| fsl          | `~4.0.3` & `~5.0.11` |
| afni         | `~16.3.13`           |
| freesurfer   | `~6.0.0`             |
| dcm2niix     | `~1.0.20180622`      |
| matlab       | `~7.4`               |
| GNU parallel | `20180522`           |
| ImageMagick  | `~6.7`               |

The system iProc was primarily developed and tested on has the following software:

| software | version      |
|----------|--------------|
| CentOS   | `7.6.1810`   |
| slurm    | `19.05.4`    |

### Optional dependencies

To run some of the included profiling tools, you have to have [niftidiff](https://bitbucket.org/gfariello/niftitools/src/default/) installed. 

### Installation of dependencies
For installation of the dependencies above, please refer to each tool's default installation instructions.
For installation of python packages, use `pip install -r requirements.txt`.

# Data storage requirements

The current best estimate for total data storage is to multiply 170MiB by the total number of time points across all runs. This should be an overestimate.
For Example:
```
(170MiB/timepoint) * (422 timepoints/BOLD run) * (2 BOLD runs/session) * (10 sessions) = 1.5TiB
```
About half of this size comes from derived images such as nuisance-regressed images. If you wish to save space for long-term storage, feel free to delete these once the pipeline has run.

# Data analysis flowchart

![](https://s3.amazonaws.com/docs.neuroinfo.org/iproc/latest/FullFig_180723_iProc.001.png)

# For more information

Check out the iProc wiki, which is hosted on this repo and contains documentation, a troubleshooting guide, and a tutorial.

