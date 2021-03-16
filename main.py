import time
import logging

from initial import read_config, create_files, log_setup
from loops import loop


def main():
    log_setup()
    config = read_config()
    create_files(config['path'])

    try:
        while True:
            loop(config)
            time.sleep(config.getint('interval'))
    except Exception as e:
        logging.exception("Something bad happened")
        raise e


if __name__ == '__main__':
    main()
