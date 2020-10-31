import configparser
import os


def read_config():
    # Reads the config file and returns it.
    config = configparser.ConfigParser()
    config.read("config.ini")
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


if __name__ == "__main__":
    create_files("levels")
