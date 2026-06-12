import json

from cerberus import Validator

SCHEMA = {
    'iproc': {
        'type': 'dict',
        'required': True,
        'schema': {
            'sub': {'type': 'string', 'required': True},
            'basedir': {'type': 'string', 'required': True},
            'outdir': {'type': 'string', 'required': True},
            'logdir': {'type': 'string', 'required': True},
            'scratchdir': {'type': 'string', 'required': True},
            'masksdir': {'type': 'string', 'required': True},
            'font': {'type': 'string', 'required': True},
            'codedir': {'type': 'string', 'required': False},
        },
    },
    'xnat': {
        'type': 'dict',
        'required': True,
        'schema': {
            'xnat_alias': {'type': 'string', 'required': True},
            'xnat_project': {'type': 'string', 'required': True},
        },
    },
    'template': {
        'type': 'dict',
        'required': True,
        'schema': {
            'midvol_sess': {'type': 'string', 'required': True},
            'midvol_boldno': {'type': 'integer', 'required': True, 'coerce': int},
            'midvol_volno': {'type': 'integer', 'required': True, 'coerce': int},
            'fd_thresh': {'type': 'float', 'required': False, 'coerce': float},
            'fd_label': {'type': 'string', 'required': False},
            'midvol_search_strategy': {
                'type': 'string',
                'required': False,
                'allowed': ['forward', 'bidirectional'],
            },
            'midvol_search_nits': {'type': 'integer', 'required': False, 'coerce': int},
            'use_dvars': {
                'type': 'string',
                'required': False,
                'allowed': ['yes', 'no'],
            },
        },
    },
    'fmap': {
        'type': 'dict',
        'required': True,
        'schema': {
            'preptool': {
                'type': 'string',
                'required': True,
                'allowed': ['topup', 'fsl_prepare_fieldmap', 'none'],
            },
        },
    },
    'csv': {
        'type': 'dict',
        'required': True,
        'schema': {
            'tasktypelist': {'type': 'string', 'required': True},
            'scanlist': {'type': 'string', 'required': True},
            'cluster_requests': {'type': 'string', 'required': True},
        },
    },
    'fs': {
        'type': 'dict',
        'required': True,
        'schema': {
            'subjects_dir': {'type': 'string', 'required': True},
        },
    },
    'T1': {
        'type': 'dict',
        'required': True,
        'schema': {
            't1_sess': {'type': 'string', 'required': True},
            't1_scan_no': {'type': 'integer', 'required': True, 'coerce': int},
        },
    },
    'out_atlas': {
        'type': 'dict',
        'required': True,
        'schema': {
            'resolution': {
                'type': 'string',
                'required': True,
                'allowed': ['111', '222'],
            },
            'mni_resamp': {'type': 'string', 'required': True},
            'mni_resamp_brain': {'type': 'string', 'required': True},
            'mni_resamp_brainmask': {'type': 'string', 'required': True},
            'fs6': {'type': 'string', 'required': True},
        },
    },
}


def validate_config(config):
    """Validate parsed config data against the schema.

    Args:
        config: a configparser.ConfigParser instance (already parsed)

    Returns:
        The validated document on success.

    Raises:
        ConfigValidationError with all collected errors on failure.
    """
    document = {}
    for section in config.sections():
        document[section] = dict(config.items(section))

    v = Validator(SCHEMA, allow_unknown=True)
    if not v.validate(document):
        raise ConfigValidationError(json.dumps(v.errors, indent=2))
    return v.document


class ConfigValidationError(Exception):
    pass
