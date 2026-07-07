#!/usr/bin/env python
import csv
import logging
import re
'''
contains info from scanlist csv and provides iterator access
'''

#should get logger from calling script
logger = logging.getLogger(__name__)

class scansHandler(object):
    '''
    holds all scan information for an analysis session in a structured format
    that can be accessed by scan type and session
    '''
    def __init__(self,conf):
        self.scan_by_session = {}
        # for use by _io_file_fmt in a jobConstructor
        self.sessionid = None
        self.scan_no = None
        self.scan_name = None
        self.sess = None
        self.task_dict = {} 
        self.csv_errors = {}
        self.conf = conf

    def reset_default_sessionid(self):
        self.sessionid = None
        self.scan_no = None
        self.scan_name = None
        self.sess = None
       
    ## not going to ingest task csv, leave that as it is for now
    def ingest_bold_csv(self, csv_fname, preptool):
        # open reader
        if not self.task_dict:
            raise Exception('you must ingest_task_csv before you ingest_bold_csv')
        
        with open(csv_fname, newline=None) as f:
            self.csv_errors[csv_fname]=[]
            reader = csv.DictReader(f)
            # Analyze is categorically different from the other variables
            schema = ['SUBJID','SESSION_ID','Analyze','BLD','TYPE','ANAT','FMAP_MAG','FMAP_PHASE','FMAP_AP','FMAP_PA', 'T2', 'T2_SESSION_ID']
            BOM = '\xef\xbb\xbf' #Excel UTF-8 Byte Order mark munge
            if BOM in reader.fieldnames[0]:
                logger.debug('automatically stripping BOM')
                reader.fieldnames[0] = reader.fieldnames[0].strip(BOM)
            if not schema == reader.fieldnames:
                raise KeyError(f'column labels of "{csv_fname}" do not conform to schema {",".join(schema)}')
            bold_scans = []
            fmap_scans = []
            anat_scans = []
            for scan in reader:
                if 'ANAT' in scan['TYPE']:
                    anat_scans.append(scan)
                elif 'FMAP' in scan['TYPE']:
                    fmap_scans.append(scan)
                else: #is bold scan
                    bold_scans.append(scan)

            ordered_scans = anat_scans + fmap_scans + bold_scans
            for scan in ordered_scans:
                logger.debug(scan)
                if not int(scan['Analyze']):
                    # don't process
                    continue
                # make sure values are formatted properly
                word_with_dash = r'[\w]+\Z'
                try:
                    if not re.match(word_with_dash,scan['SUBJID']):
                        self.csv_errors[csv_fname].append(f'SUBJID "{scan["SUBJID"]}" has illegal characters')
                    if not re.match(word_with_dash,scan['SESSION_ID']):
                        self.csv_errors[csv_fname].append(f'SESSION_ID "{scan["SESSION_ID"]}" has illegal characters')
                    if not re.match(r'[0-1]+\Z',scan['Analyze']):# bool
                        self.csv_errors[csv_fname].append(f'Analyze "{scan["Analyze"]}" has illegal characters')
                    if not re.match(r'[0-9]+\Z',scan['BLD']):#integer
                        self.csv_errors[csv_fname].append(f'BLD "{scan["BLD"]}" has illegal characters')
                    if not re.match(r'[a-zA-Z0-9_]+\Z',scan['TYPE']):#string
                        self.csv_errors[csv_fname].append(f'TYPE "{scan["TYPE"]}" has illegal characters')
                    if not re.match(r'[0-9]+\Z',scan['ANAT']):#integer
                        self.csv_errors[csv_fname].append(f'ANAT "{scan["ANAT"]}" has illegal characters')
                    if not re.match(r'[0-9]+\Z',scan['FMAP_MAG']):#integer 
                        self.csv_errors[csv_fname].append(f'FMAP_MAG "{scan["FMAP_MAG"]}" has illegal characters')
                    if not re.match(r'[0-9]+\Z',scan['FMAP_PHASE']):#integer
                        self.csv_errors[csv_fname].append(f'FMAP_PHASE "{scan["FMAP_PHASE"]}" has illegal characters')
                    if not re.match(r'[0-9]+\Z',scan['FMAP_AP']):#integer 
                        self.csv_errors[csv_fname].append(f'FMAP_AP"{scan["FMAP_AP"]}" has illegal characters')
                    if not re.match(r'[0-9]+\Z',scan['FMAP_PA']):#integer
                        self.csv_errors[csv_fname].append(f'FMAP_PA"{scan["FMAP_PA"]}" has illegal characters')
                    if not re.match(r'[0-9]+\Z',scan['T2']):#integer
                        self.csv_errors[csv_fname].append(f'T2"{scan["T2"]}" has illegal characters')
                except TypeError:
                    logger.error('type error on regex, probably means that one of the lines in the CSV is missing some values, i.e. is too short')
                    logger.error(f'check {csv_fname}')
                    raise

                sessid = scan['SESSION_ID']
                # add scan to list of scans from that session
                if sessid in self.scan_by_session:
                    try:
                        self.scan_by_session[sessid].append_scan(scan, preptool)
                    except Exception as e :
                        logger.error(f'problem with file {csv_fname}')
                        # so the stack trace is more informative
                        self.scan_by_session[sessid].append_scan(scan, preptool)
                        raise e
                else:
                    new_session = session()
                    try:
                        new_session.append_scan(scan, preptool)
                    except Exception as e :
                        logger.error(f'problem with file {csv_fname}')
                        raise e
                    self.scan_by_session[sessid] = new_session
            # check to make sure that all the TYPE values from scanlist
            # match some row in tasklist 
            for sess in list(self.scan_by_session.values()):
                if sess.sessid == self.conf.template.MIDVOL_SESS:
                    stripped_midvol_no = int(self.conf.template.MIDVOL_BOLDNO)
                    if stripped_midvol_no not in sess.bold_scans:
                        self.csv_errors[csv_fname].append(f'Midvol scan {stripped_midvol_no} not found in bold_scans for midvol session {sess.sessid}. Make sure the "Analyze" value is set to 1')
                types = [bold_scan['TYPE'] for bold_scan in list(sess.bold_scans.values())]
                for task_type in types:
                    if task_type not in self.task_dict:
                        self.csv_errors[csv_fname].append(f'"{task_type}" does not have a corresponding row in the task CSV')
            compile_csv_error_report(self.csv_errors)

    def ingest_task_csv(self, csv_fname):
        # open reader
        # added SKIPEND on 2026.07.06 by JS
        with open(csv_fname, newline=None) as f:
            self.csv_errors[csv_fname]=[]
            reader = csv.DictReader(f)
            schema=['TYPE','TR','SKIP','SKIPEND','SMOOTHING','NUMVOL','NUMECHOS']
            if not schema == reader.fieldnames:
                raise KeyError(f'column labels of {csv_fname} do not conform to schema {",".join(schema)}')
            for d in reader:
                # check for correct value formatting
                if not re.match(r'[a-zA-Z0-9_]+\Z',d['TYPE']):
                    self.csv_errors[csv_fname].append(f'TYPE "{d["TYPE"]}" has illegal characters')
                if not re.match(r'[0-9]+\.?[0-9]*\Z',d['TR']): #any number
                    self.csv_errors[csv_fname].append(f'TR "{d["TR"]}" has illegal characters')
                if not re.match(r'[0-9]+\Z',d['SKIP']):#integer
                    self.csv_errors[csv_fname].append(f'SKIP "{d["SKIP"]}" has illegal characters')
                if not re.match(r'[0-9]+\Z',d['SKIPEND']):#integer
                    self.csv_errors[csv_fname].append(f'SKIPEND "{d["SKIPEND"]}" has illegal characters')
                if not re.match(r'[0-9.]+\Z',d['SMOOTHING']):
                    self.csv_errors[csv_fname].append(f'SMOOTHING "{d["SMOOTHING"]}" has illegal characters')
                if not re.match(r'[0-9]+\Z',d['NUMVOL']):
                    self.csv_errors[csv_fname].append(f'NUMVOL "{d["NUMVOL"]}" has illegal characters')
                if not re.match(r'[0-9]+\Z',d['NUMECHOS']):
                    self.csv_errors[csv_fname].append(f'NUMECHOS "{d["NUMVOL"]}" has illegal characters')
                self.task_dict[d['TYPE']] = d
    def session_names(self):
        return list(self.scan_by_session.keys())
    def sessions(self):
        return self._sessions_screened('bold')
    def anat_sessions(self):
        return self._sessions_screened('anat')
    def _sessions_screened(self,screendict):
        for sessionid, sess in list(self.scan_by_session.items()):
            screendict_translate = {'anat':list(sess.anat_scans.values()),
                                    'bold':list(sess.bold_scans.values())}
            value_check = screendict_translate[screendict]
            if not any(value_check):
                continue 
            self.sessionid = sessionid
            self.sess = self.scan_by_session[self.sessionid]
            yield (sessionid, sess)
    def tasks(self):
        # should only be used within a sessions block
        # want to sort bold scans by their acquisition number
        for bold_scan in sorted(list(self.sess.bold_scans.values()),key=lambda s:int(s['BLD'])):
            self.scan_no = bold_scan['BLD']
            task_type = bold_scan['TYPE']
            self.scan_name = task_type
            yield (task_type, bold_scan)
    def fieldmaps(self):
        # want to return fmap scans in order of increasing aquisition number
        for fmap_scan in sorted(list(self.sess.fmap_scans.values()),key=lambda s:int(s['FIRST_FMAP'])):
            #this was done to grandfather in fmap_phase from when it was fmap_phase
            self.scan_no = fmap_scan['SECOND_FMAP']
            fmap_dir = fmap_scan['DIR']
            self.scan_name = fmap_dir
            yield (fmap_dir,fmap_scan)
    def anats(self):
        for anat_scan in list(self.sess.anat_scans.values()):
            self.scan_no = anat_scan['ANAT']
            anat_dir = anat_scan['DIR']
            self.scan_name = anat_dir
            yield (anat_dir,anat_scan)
    def set_sessid(self,sessionid):
        self.sessionid = sessionid
    def set_name(self,name):
        self.scan_name = name
    def set_task_type(self,task_type):
        raise NotImplementedError
    def set_midvol(self,conf):
        # sets class members to midvol from config
        self.sessionid = conf.template.MIDVOL_SESS 
        self.sess = self.scan_by_session[self.sessionid]
        self.scan_no = conf.template.MIDVOL_BOLDNO
        self.scan_name = conf.template.MIDVOL_BOLDNAME
    def set_anat(self,sessionid,scan_no):
        # sets class members to T1_sess from config
        # will probably have to differentiate from MNI etc at some point.
        self.sessionid = sessionid
        self.sess = self.scan_by_session[self.sessionid]
        self.scan_no = scan_no
        self.scan_name = 'NAT'

class session:
    def __init__(self):
        self.bold_scans = {}
        self.fmap_scans = {}
        self.anat_scans = {}
        self.subjid = None
        self.sessid = None
        self.fmap_prep_type = None

    def append_scan(self, scan, preptool):
        if not self.subjid:
            self.subjid = scan['SUBJID']   
        else:
            #subjid should match for all scans in the same session
            if not scan['SUBJID'] == self.subjid:
                logger.error(scan)
                raise ValueError('SUBJID should match for all scans in the same session')
        if not self.sessid:
            self.sessid = scan['SESSION_ID']   
        else:
            #sessid should match for all scans in the same session
            if not scan['SESSION_ID'] == self.sessid:
                logger.error(scan)
                raise ValueError('SESSION_ID should match for all scans in the same session')
        # add scan to appropriate dict
        if 'ANAT' in scan['TYPE']:
            # scan is an anat scan
            anat_no = scan['ANAT']
            if anat_no in self.anat_scans:
                dup = f'duplicate entry: {self.subjid},{self.sessid},1,{anat_no}'
                raise ValueError(dup)
            else:
                scan['DIR']=scan['TYPE']
                self.anat_scans[anat_no]=scan
            logger.debug(f'added {anat_no}:{scan} to anat_scans')
        elif 'FMAP' in scan['TYPE']:
            # scan is a field map scan
            fmap_prep_type,first_fmap,second_fmap = self._fmap_format_check(scan)

            scan['FMAP_PREP_TYPE'] = fmap_prep_type
            # these two are done so that we can do sorting in a preptype-agnostic way
            if (first_fmap,second_fmap) in self.fmap_scans:
                dup = f'duplicate entry: {self.subjid},{self.sessid},1,{(first_fmap, second_fmap)}'
                raise ValueError(dup)
            else:
                scan['DIR'] = scan['TYPE']
                self.fmap_scans[(first_fmap,second_fmap)] = scan
            logger.debug(f'added {first_fmap},{second_fmap}:{scan} to fmap_scans')

        else:
            # Bold scan
            # check for duplicate scan numbers
            bold_no = int(scan['BLD'])
            if bold_no in self.bold_scans:
                dup = f'duplicate entry: {self.subjid},{self.sessid},1,{bold_no}'
                raise ValueError(dup)
            bold_types = [s['TYPE'] for s in list(self.bold_scans.values())]
            if scan['TYPE'] in bold_types:
                logger.warn(scan)
                dup = f'assigning bold scan {bold_no} to a type {scan["TYPE"]} that already has assigned bold scans'
                logger.warn(dup)
            # scan is a bold scan
            bold_scan = scan
            self.bold_scans[bold_no] = scan
            logger.debug(f'added {bold_no} to bold_scans')

            ## check entry ANAT value for consistency 
            try:
                bold_scan['ANAT_DIR'] = self.anat_scans[bold_scan['ANAT']]['DIR']
            except KeyError:
                logger.warning(f'no such anat found! {bold_scan}')
                logger.warning(f'{self.anat_scans}')
                bold_scan['ANAT_DIR'] = 'No Anat For Session in CSV'

            ## Check Fmap values
            print(f'-------PREPTOOL: {preptool}--------')
            if preptool != 'none':
                fmap_prep_type,first_fmap,second_fmap = self._fmap_format_check(scan)
                try:
                    fmap_scan = self.fmap_scans[(first_fmap,second_fmap)]
                    bold_scan['FMAP_DIR'] = fmap_scan['DIR']
                except KeyError:
                    logger.error(f'no such fmap found! {bold_scan}')
                    raise
                # make sure fmap scan is correct format
                if fmap_prep_type != fmap_scan['FMAP_PREP_TYPE']:
                    raise ValueError(f'BLD {bold_no} has FMAP of format {fmap_prep_type}, unlike FMAP {first_fmap},{second_fmap} in the same session, {self.sessid}. \n iproc only supports one fmap prep type per subject. \n Please move the fmap scan numbers to the correct column in the bold scan row')

    def _fmap_format_check(self,scan):
        ''' helper function to check fmap values makes sense '''

        fmap_mag_no = int(scan['FMAP_MAG'])
        fmap_phase_no = int(scan['FMAP_PHASE'])
        fmap_AP_no = int(scan['FMAP_AP'])
        fmap_PA_no = int(scan['FMAP_PA'])

        if fmap_mag_no == 0 and fmap_phase_no == 0:
            # we're in AP PA mode
            if fmap_AP_no == 0 or fmap_PA_no == 0:
                raise ValueError('fmap columns are all zero! Please set values for either APPA or double echo style (Mag/Phase) style images')
            # for later
            fmap_prep_type = 'topup'
            first_fmap = fmap_AP_no 
            second_fmap = fmap_PA_no
        elif fmap_AP_no == 0 and fmap_PA_no == 0:
            if fmap_mag_no == 0 or fmap_phase_no == 0:
                raise ValueError('fmap columns are all zero! Please set values for either APPA or double echo style (Mag/Phase) style images')
            fmap_phase_diff = fmap_phase_no - fmap_mag_no
            if fmap_phase_diff != 1 and fmap_phase_diff != 2:
               raise NotImplementedError(f'FMAP_PHASE {fmap_phase_no} is not one scan behind FMAP_MAG {fmap_mag_no} for a FMAP scan from {self.sessid}. This is not normal for scans collected at Harvard CBSN.')
            # for later
            fmap_prep_type = 'fsl_prepare_fieldmap'
            first_fmap = str(fmap_mag_no)
            second_fmap = str(fmap_phase_no)
        else:
            raise ValueError(f'Invalid fmap values. Please set values for either APPA or double echo style (Mag/Phase) style images\n{scan}')

        scan['FIRST_FMAP'] = first_fmap 
        scan['SECOND_FMAP'] = second_fmap 
        return (fmap_prep_type,first_fmap,second_fmap)

def load_cluster_requests(csv_fname,args):
    ''' takes in the name of a cluster requests csv, loads the information 
    into the args object. '''
    csv_errors = {}
    with open(csv_fname, newline=None) as f:
        reader = csv.DictReader(f)
        schema=['STEP','RUNMODE','partition','time','mem','cpu']
        if not schema == reader.fieldnames:
            raise KeyError(f'column labels of "{csv_fname}" do not conform to schema {",".join(schema)}')
        csv_errors[csv_fname]=[]
        for step in reader:
            cluster_args = {k:v for k,v in list(step.items()) if k != 'STEP'}
            to_pop = []
            for k,v in list(cluster_args.items()):
                if v == 'default' :
                    # remove from cluster_args, implicitly selecting default from
                    #the executor 
                    to_pop.append(k)
                    continue
                # format checking
                #STEP is an arbitrary string, no checking advisable.
                #partition is up to the cluster admin, no checking advisable
                #time is, again, up to the cluster admin and executor. no checking advisable.
                #mem is up to the executor. 
                #I can be fairly confident what the CPU argument is going to look like.
                if k == 'cpu': #if this was default, that has already been dealt with
                    if not re.match(r'[0-9]+\Z',v):#integer
                        csv_errors[csv_fname].append(f'cpu entry "{v}" has illegal characters')
            for k in to_pop:
                cluster_args.pop(k)
            args.cluster[step['STEP']] = cluster_args
    compile_csv_error_report(csv_errors)

def compile_csv_error_report(csv_errors):
    #takes in csv_errors, which should be a dictionary of csv_filename:[] pairs.
    # if the error lists are empty, returns. Otherwise, prints errors to log
    # and raises an exception
    if any(csv_errors.values()):
        for csv,errorlist in list(csv_errors.items()):
            if not errorlist:
                continue
            logger.debug(f'{csv} has the following errors')
            for error in errorlist:
                logger.debug(error)
        raise Exception('CSVs have errors, see above')

if __name__ == "__main__":
    s = scansHandler() 
    #TODO: define tests here
