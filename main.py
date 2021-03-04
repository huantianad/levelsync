import time

from initial import read_config, create_files
from loops import loop


def main():
    config = read_config()
    create_files(config['path'])

    while True:
        loop(config)
        time.sleep(config.getint('interval'))


if __name__ == '__main__':
    main()
