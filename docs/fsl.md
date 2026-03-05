# FSL, FSL, Everywhere

!!! danger "Important"
    Until there is a portable solution in place (e.g., containers), end users 
    need to modify the following lines of code to load the correct version of 
    FSL at the appropriate time.

iProc dynamically switches FSL versions at runtime using [Lmod][Lmod]. Your 
computing environment may not use Lmod, or your module names may differ. You 
need to understand _where_ and _how_ iProc is switching FSL versions and make 
the necessary modifications to the iProc source code to suit your environment.

## `iProc.py`

Before running [`iProc.py`][iProc], it is assumed that you have already loaded 
FSL `v5.0.10`.

## `fmap_from_bids`

Within [`runscript/fmap_from_bids.py`][fmap_from_bids], the FSL version is 
switched to `v4.0.3` before running the FSL `bet2` command.

```python
cmd = f'module load fsl/4.0.3-ncf && {_cmd}'
```

## `fmap_topup_prep`

Within [`runscript/fmap_topup_prep.sh`][fmap_topup_prep], the FSL version is 
switched to `v6.0.1` before running the FSL `topup` command

```bash
module load fsl/6.0.1-ncf
```

## `fm_unwarp_and_mc_to_midvol`

In [`runscript/fm_unwarp_and_mc_to_midvol.sh`][fm_unwarp_and_mc_to_midvol], the 
FSL version is switched to `v4.0.3` before running `runscript/fm_uw.sh`

```bash
${CODEDIR}/modwrap.sh 'module load fsl/4.0.3-ncf' 'module load fsl/5.0.4-ncf' [...]
```

## `fmap_fsl_prepare_fieldmap_prep`

In [`runscript/fmap_fsl_prepare_fieldmap_prep.sh`][fmap_fsl_prepare_fieldmap_prep], 
the FSL version is switched to `v5.0.4` before running the FSL `fsl_prepare_fieldmap` 
command

```bash
module load fsl/5.0.4-ncf
```

[Lmod]: https://lmod.readthedocs.io/en/latest/
[iProc]: https://github.com/harvard-nrg/iProc/blob/main/iProc.py
[fmap_from_bids]: https://github.com/harvard-nrg/iProc/blob/main/runscript/fmap_from_bids.py
[fmap_topup_prep]: https://github.com/harvard-nrg/iProc/blob/main/runscript/fmap_topup_prep.sh
[fm_unwarp_and_mc_to_midvol]: https://github.com/harvard-nrg/iProc/blob/main/runscript/fm_unwarp_and_mc_to_midvol.sh
[fmap_fsl_prepare_fieldmap_prep]: https://github.com/harvard-nrg/iProc/blob/main/runscript/fmap_fsl_prepare_fieldmap_prep.sh
