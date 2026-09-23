import subprocess as sp
import os
import shutil
import logging
import time
import tempfile
import iproc.commons as commons

logger = logging.getLogger(__name__)

# fslroi silently zero-pads any requested xmin/xsize,ymin/ysize,zmin/zsize that
# exceeds an image's real dimensions, instead of erroring. The downstream
# `slicer -S` montage then renders those phantom slices as blank tiles, which
# shows up as a big white gap in the QC PDF. This bash function clamps a
# requested window down to the image's actual dims at script-RUNTIME (the
# image doesn't exist yet when this Python code builds the script, so the
# check can't be done here in Python).
CLAMP_WINDOW_DIMS_FUNC = (
    'clamp_window_dims() { '
    'local img=$1 xmin=$2 xsize=$3 ymin=$4 ysize=$5 zmin=$6 zsize=$7; '
    'local d1=$(fslval $img dim1); local d2=$(fslval $img dim2); local d3=$(fslval $img dim3); '
    'if [ $((xmin+xsize)) -gt $d1 ]; then xsize=$((d1-xmin)); fi; '
    'if [ $xmin -ge $d1 ]; then xmin=0; xsize=$d1; fi; '
    'if [ $((ymin+ysize)) -gt $d2 ]; then ysize=$((d2-ymin)); fi; '
    'if [ $ymin -ge $d2 ]; then ymin=0; ysize=$d2; fi; '
    'if [ $((zmin+zsize)) -gt $d3 ]; then zsize=$((d3-zmin)); fi; '
    'if [ $zmin -ge $d3 ]; then zmin=0; zsize=$d3; fi; '
    'echo "$xmin $xsize $ymin $ysize $zmin $zsize"; '
    '}'
)

# probably going to want to create a page factory that produces pages with
# certain hard-coded values, and others that can vary.
class page(object):
    # this object holds all the info you need to run a slicer command and 
    #produce a single page in a QC PDF.
    def __init__(self,infile,slicer):
        # to store the final outputs of a slicer command, 
        # tableaus are themselves aggregates of many pngs
        self.infile = infile
        self.tableau = None
        infile_basename = os.path.basename(self.infile)
        self.infile_basename = infile_basename.split('.')[0]
        # this is a dict with keys size,sample,width
        self.slicer = slicer

class qc_pdf_maker(object):
    #for holding internal settings
    def __init__(self, conf,plane):
        # pages are a list of page objects
        self.outdir = conf.iproc.QCDIR
        timestamp = time.time()
        self.scratch_home = os.path.join(self.outdir,'images')
        if not os.path.exists(self.scratch_home):
            os.makedirs(self.scratch_home)
        self.scratch = None
        self.pages = [] 
        self.conf = conf
        self.out_pdf = None #set by self.set_out_pdf
        self.scriptname = None #set by self.set_out_pdf
        self.script = None 
        self.plane = plane
        if plane == 'ax':
            # for use in fslswapdim. Order matters.
            self.swapdims=['-x','y','-z']
        elif plane == 'sag':
            self.swapdims=['y','z','-x']
        else:
            raise NotImplementedError
   
    def produce_pdf(self,name,save_intermediates=True,overwrite=True):
        self.scratch = tempfile.mkdtemp(dir=self.scratch_home)
        logfile_base = self._io_file_fmt()
        if not self.set_out_pdf_name(name,overwrite):
            job_spec = commons.JobSpec(None,logfile_base,[self.out_pdf])
            job_spec.skip = True
            return 
            
        # pdf name set. Time to initialize script
        self.script = commons.ScriptBuilder(self.scriptname)
        self.script.blank_file() # make sure script is blank
        self.script.append([CLAMP_WINDOW_DIMS_FUNC])
        for page in self.pages:
            page.tableau = os.path.join(self.scratch,"tableau_sliced_{SPACE}_{PLANE}.png".format(SPACE=page.infile_basename,PLANE=self.plane))
            self.slicer(page)
        self.png_to_PDF()
        self.final_cleanup(save_intermediates)
        job_spec = commons.JobSpec([self.scriptname],logfile_base,[self.out_pdf])
        return job_spec

    def set_out_pdf_name(self,name,overwrite):
        # sets out pdf name so that output checking can be done beforehand
        pdf_fname = '{sub}_{name}'.format(sub=self.conf.iproc.SUB,name=name)
        pdf_fname += '_{}'.format(self.plane)
        self.scriptname = os.path.join(self.outdir,pdf_fname + '.sh')
        pdf_fname += '.pdf'
        out_pdf = os.path.join(self.outdir,pdf_fname)
        self.out_pdf = out_pdf
        if not overwrite and os.path.exists(out_pdf):
            logger.debug('overwrite set to False and {} exists. SKIPPING'.format(out_pdf))
            return False
        else:
            logger.debug('overwrite set to True or {} does not exist. RUNNING'.format(out_pdf))
            return True

    def slicer(self,page):

        sliced = os.path.join(self.scratch,"tile_sliced_{SPACE}_{PLANE}.png".format(SPACE=page.infile_basename,PLANE=self.plane))

        # make swap nifti with plane-approptiate orientation
        infile = page.infile #T1, e.g. mpr_reorient
        tmpfile = os.path.join(self.scratch, '{}_fslreorient2std.nii.gz'.format(page.infile_basename))
        fslreorient2std_cmd = ['fslreorient2std', infile, tmpfile]
        self.script.append(fslreorient2std_cmd)
        swap = os.path.join(self.scratch,"{SPACE}_swapped_{PLANE}.nii.gz".format(SPACE=page.infile_basename,PLANE=self.plane))
        roi = os.path.join(self.scratch,"{SPACE}_roi_{PLANE}.nii.gz".format(SPACE=page.infile_basename,PLANE=self.plane))
        swapdim_cmd = ['fslswapdim', tmpfile] + self.swapdims + [swap]
        self.script.append(swapdim_cmd)
        
        # extract sub page of nifti, clamping the requested window down to
        # this specific image's real dimensions at runtime (see
        # CLAMP_WINDOW_DIMS_FUNC) so fslroi never zero-pads past the edge of
        # the volume and leaves blank tiles in the slicer montage
        xmin,xsize,ymin,ysize,zmin,zsize = page.slicer['window_dims']
        clamp_call = 'read XMIN XSIZE YMIN YSIZE ZMIN ZSIZE <<< "$(clamp_window_dims {img} {xmin} {xsize} {ymin} {ysize} {zmin} {zsize})"'.format(
            img=swap, xmin=xmin, xsize=xsize, ymin=ymin, ysize=ysize, zmin=zmin, zsize=zsize)
        self.script.append([clamp_call])
        fslroi_cmd = ['fslroi', swap, roi, '$XMIN', '$XSIZE', '$YMIN', '$YSIZE', '$ZMIN', '$ZSIZE']
        self.script.append(fslroi_cmd)

        #slice the image and put slices together as tiles in a png image
        sample = page.slicer['sample']
        width = str(page.slicer['width']*180)
        slicer_cmd = ['slicer', roi, '-u', '-S', sample, width, sliced]
        self.script.append(slicer_cmd)

        label = page.infile_basename+ '_'+ self.plane
        # add label
        font = self.conf.get('iproc', 'font')
        if not font:
            logger.info('no iproc.font in user config, trying Nimbus-Sans-Regular')
            font = 'Nimbus-Sans-Regular'
        append_cmd = ['convert', sliced, '-font', font, '-background', 'White', '-pointsize', '20',
                    'label:{}'.format(label), '+swap', '-gravity', 'North-West',
                    '-append', '+repage', page.tableau]
        
        self.script.append(append_cmd)

    def png_to_PDF(self):
        # converts tableau png in page to pdf      
        # sample usage: for page in pages: png_to_PDF(page,
        tableau_files = [page.tableau for page in self.pages]
        combine_png_cmd = ['convert', '-adjoin'] + tableau_files + [self.out_pdf]
        self.script.append(combine_png_cmd)

    def final_cleanup(self,save_intermediates):
        if save_intermediates:
            rmcmd = ['#rm', '-rf', self.scratch]
        else:
            rmcmd = ['rm', '-rf', self.scratch]
            logger.debug('intermediate files will not be removed from {}'.format(self.scratch))
        self.script.append(rmcmd)
    ## Helpers
    def _io_file_fmt(self):
        outfile_base = os.path.join(self.conf.iproc.LOGDIR,
                "{SUB}_QC_PDF".format(
                SUB=self.conf.iproc.SUB))
        return outfile_base
  
