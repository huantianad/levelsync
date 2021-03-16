import configparser
import logging
import os


def read_config():
    # Find the config file relative to the file, not current directory
    config_path = os.path.join(os.path.dirname(__file__), "config.ini")

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


def log_setup():
    log_path = os.path.join(os.path.dirname(__file__), "log.txt")
    logging.basicConfig(filename=log_path,
                        filemode='w',
                        format='%(name)s - %(levelname)s - %(message)s',
                        level=logging.INFO)


if __name__ == "__main__":
    create_files("levels")
