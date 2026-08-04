from importlib.resources import files

_PACKAGE_FILES = files('iproc')

def get_codedir():
    return str(_PACKAGE_FILES)
