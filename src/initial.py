import configparser
import logging
import os
import sys


def resource_path(relative_path):
    """Get absolute path to resource, relative to .exe, works for dev and for PyInstaller"""

    if getattr(sys, 'frozen', False):
        base_path = os.path.split(sys.executable)[0]
    else:
        base_path = sys.path[0]

    return os.path.join(base_path, relative_path)


def bundled_path(relative_path):
    """Get absolute path to resource, for things bundled inside the exe, works for dev and for PyInstaller"""

    if getattr(sys, '_MEIPASS', False):
        # PyInstaller creates a temp folder and stores path in _MEIPASS
        base_path = sys._MEIPASS
    else:
        base_path = sys.path[0]

    return os.path.join(base_path, relative_path)


def read_config() -> configparser.SectionProxy:
    # Find the config file relative to the exe, not current directory
    config_path = resource_path('config.ini')

    # Reads the config file and returns it.
    config = configparser.ConfigParser()
    config.read(config_path)

    verify_config(config)

    return config['Main']


def verify_config(config: configparser.ConfigParser) -> None:
    """
    Verifies that the config

    Args:
        config (configparser.ConfigParser): [description]

    Raises:
        ValueError: An invalid value was given to the config.
    """

    config = config['Main']

    abs_paths = ['path']
    bools = ['verified_only', 'enable_notifications']
    floats = ['interval']

    for value in abs_paths:
        if not os.path.isabs(config.get(value)):
            raise ValueError(f"{value} is not an absolute path! Please double-check your config!")

    for value in bools:
        try:
            config.getboolean(value)
        except ValueError:
            raise ValueError(f"{value} is not a boolean! Please double-check your config!")

    for value in floats:
        try:
            config.getfloat(value)
        except ValueError:
            raise ValueError(f"{value} is not a float! Please double-check your config!")


def log_setup(filemode='w'):
    log_path = resource_path('log.txt')
    previous_log_path = resource_path('log_previous.txt')

    # If there is already a log file, we rename it to log_previous
    if os.path.exists(log_path):
        if os.path.exists(previous_log_path):
            os.remove(previous_log_path)
        os.rename(log_path, previous_log_path)

    logging.basicConfig(filename=log_path,
                        filemode=filemode,
                        format='[%(asctime)s: %(levelname)s]: %(message)s',
                        level=logging.INFO)
