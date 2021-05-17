import configparser
import logging
import os
import sys


def resource_path(relative_path):
    """ Get absolute path to resource, works for dev and for PyInstaller """
    if getattr(sys, 'frozen', False):
        application_path = os.path.dirname(sys.executable)
    else:
        application_path = os.path.dirname(os.path.abspath(__file__))

    return os.path.join(application_path, relative_path)


def read_config():
    # Find the config file relative to the file, not current directory
    config_path = resource_path('config.ini')

    # Reads the config file and returns it.
    config = configparser.ConfigParser()
    config.read(config_path)
    return config['Main']


def create_files(path):
    # Creates required directories and files
    if not os.path.exists(path):
        os.mkdir(path)

    if not os.path.exists(f"{path}/yeeted"):
        os.mkdir(f"{path}/yeeted")

    if not os.path.exists(f"{path}/sync.json"):
        with open(f"{path}/sync.json", "w") as file:
            file.write("{}")


def log_setup(filemode='w'):
    log_path = resource_path('log.txt')
    logging.basicConfig(filename=log_path, filemode=filemode, format='[%(asctime)s: %(levelname)s]: %(message)s',
                        level=logging.INFO)


if __name__ == "__main__":
    create_files("levels")
