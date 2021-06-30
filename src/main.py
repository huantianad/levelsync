import logging
import os
import platform
import subprocess
import threading

import pystray
from PIL import Image

from .initial import bundled_path, log_setup, read_config
from .loops import loop


def main() -> None:
    # This event is used to stop the loop.
    global exit_event
    exit_event = threading.Event()

    # Create and run the icon
    path = read_config()['path']
    icon = pystray.Icon('LevelSync', title='LevelSync')

    icon.menu = pystray.Menu(
        pystray.MenuItem('LevelSync', lambda: None),
        pystray.MenuItem('Open Levels Folder', lambda: open_folder(path), default=True),
        pystray.MenuItem('Open Yeeted Folder', lambda: open_folder(os.path.join(path, '..', 'yeeted'))),
        pystray.MenuItem('Quit', exit)
    )

    with Image.open(bundled_path(os.path.join('res', 'icon.ico'))) as im:
        im.load()
        icon.icon = im

    icon.run(setup=setup)


def exit(icon: pystray.Icon) -> None:
    icon.visible = False
    exit_event.set()
    icon.stop()


def setup(icon: pystray.Icon) -> None:
    icon.visible = True  # Required to make the systray icon show up

    log_setup()  # Configures logging

    config = read_config()
    create_files(config['path'])
    interval = config.getfloat('interval')

    while not exit_event.is_set():  # This exits the loop if exit is ever set -> program was quit
        try:
            loop()
            exit_event.wait(interval)  # allows exiting while waiting. time.sleep would block
        except Exception as e:
            logging.exception("Something bad happened!")
            raise e


def create_files(path: str) -> None:
    """
    Creates required files, using the given path as the base level folder

    Args:
        path (str): Path to main level folder
    """

    if not os.path.exists(path):
        os.mkdir(path)

    if not os.path.exists(os.path.join(path, '..', 'yeeted/')):
        os.mkdir(os.path.join(path, '..', 'yeeted/'))

    if not os.path.exists(os.path.join(path, 'sync.json')):
        with open(os.path.join(path, 'sync.json'), "w") as file:
            file.write("{}")


def open_folder(path: str) -> None:
    """
    Opens the given folder in the system file manager.

    Args:
        path (str): Path to folder to open.
    """

    if platform.system() == "Windows":
        os.startfile(path)
    elif platform.system() == "Darwin":
        subprocess.Popen(["open", path])
    else:
        subprocess.Popen(["xdg-open", path])


if __name__ == '__main__':
    main()
