import json
import logging
import os
import re
import shutil
import typing
from tempfile import TemporaryDirectory
from zipfile import BadZipFile, ZipFile

import requests
from notifypy import Notify

from . import initial


def get_site(verified_only=False) -> list[str]:
    """
    Uses the level spreadsheet api to get level urls.
    If verified_only is True, this will only return verified levels.

    Args:
        verified_only (bool, optional): Whether to only return verified levels only. Defaults to False.

    Returns:
        list[str]: Level download urls.
    """

    url = 'https://script.google.com/macros/s/AKfycbzm3I9ENulE7uOmze53cyDuj7Igi7fmGiQ6w045fCRxs_sK3D4/exec'
    r = requests.get(url).json()

    if verified_only:
        return [x['download_url'] for x in r if x.get('verified')]
    else:
        return [x['download_url'] for x in r]


def rename(path: str) -> str:
    """
    Given some path, returns a file path that doesn't already exist.
    This is used to ensure that unique file names are always used.
    """

    if os.path.exists(path):
        index = 2
        extension = "." + path.rsplit('.', 1)[-1]  # Get everything after last period -> extension
        path = path.replace(extension, "")  # Gets rid of the extension, we add it back later on.

        while os.path.exists(f"{path} ({index}){extension}"):
            index += 1

        return f"{path} ({index}){extension}"
    else:
        return path


def unzip_level(path: str) -> None:
    """
    Unzips the given level, and removes the old rdzip afterwards.

    Args:
        path (str): Path to the .rdzip to unzip
    """

    with TemporaryDirectory() as tempdir:
        try:
            with ZipFile(path, 'r') as zip_file:
                zip_file.extractall(tempdir)

        except BadZipFile:
            # python detects that the file isn't a zip file, so we ignore trying to unzip it
            error(f"{path} isn't an actual level")

        except (OSError, UnicodeDecodeError):
            # python cannot physically unzip the file correctly, not really something we can fix.
            error(f"{path} has some broken characters or stuff. It will be broken. Please tell a mod to fix")

        else:
            # We unzipped the file correctly, remove the old zipped file and replace it with the unzipped
            os.remove(path)
            shutil.move(tempdir, path)

            # Fix CLS version bug
            with open(os.path.join(path, 'main.rdlevel'), 'r') as file:
                data = file.read()
            data = data.replace('"version": 45', '"version": 44', 1)
            with open(os.path.join(path, 'main.rdlevel'), 'w') as file:
                file.write(data)


def get_filename(url: str) -> str:
    """
    Extracts the filename from the Content-Disposition header of a request.

    Args:
        r (requests.Request): A requests object from getting the url of a level

    Returns:
        str: The filename of the level
    """

    if url.endswith('.rdzip'):
        name = url.rsplit('/', 1)[-1]
    else:
        r = requests.get(url, stream=True)
        h = r.headers.get('Content-Disposition')
        name = re.search(r'filename[^;=\n]*=(([\'"]).*?\2|[^;\n]*)', h).groups()[0]

    # Remove the characters that windows doesn't like in filenames
    for char in r'<>:"/\|?*':
        name = name.replace(char, '')

    return name


def download_level(url: str, path: typing.Union[str, bytes, os.PathLike]) -> str:
    r = requests.get(url)

    if r.status_code != 200:
        error(f"The level {url} was deleted. Please tell a mod about this.")

    # Get the proper filename of the level, append it to the path to get the full path to the downloaded level.
    filename = get_filename(url)
    full_path = os.path.join(path, filename)

    # Ensure unique filename
    full_path = rename(full_path)

    with open(full_path, 'wb') as file:
        file.write(r.content)

    unzip_level(full_path)

    # the rest of the program only expects the level name to be outputed
    return os.path.split(full_path)[-1]


def error(message: str) -> None:
    """
    Sends an error notification as well as log into the log file.
    """
    logging.error(message)

    if enable_notifications is False:
        return

    notification = Notify()
    notification.title = "LevelSync Error!!!!"
    notification.message = message
    notification.icon = initial.bundled_path(os.path.join('res', 'icon.ico'))
    notification.send(block=True)


def notification(message: str) -> None:
    """
    Sends a normal notification.

    Args:
        message (set): Message to send.
    """

    if message is None or enable_notifications is False:
        return

    notification = Notify()
    notification.title = "LevelSync"
    notification.message = message
    notification.icon = initial.bundled_path(os.path.join('res', 'samuraisword.ico'))
    notification.send(block=True)


def loop() -> None:
    global enable_notifications
    config = initial.read_config()
    path = config.get('path')
    verified_only = config.getboolean('verified_only')
    enable_notifications = config.getboolean('enable_notifications')

    logging.info("Starting website check.")
    try:
        site_urls = get_site(verified_only)
    except Exception:
        error("Failed to get data from site.")
        return

    # Read sync.json
    with open(os.path.join(path, 'sync.json'), "r") as file:
        file_data = json.load(file)

    # Creates sets of new and yeeted levels by comparing site and file.
    new_levels = set(site_urls) - set(file_data.keys())
    yeet_levels = set(file_data.keys()) - set(site_urls)

    logging.info(f"{len(new_levels)} new levels found, {len(yeet_levels)} yeet levels found.")

    # Move yeeted levels
    for level in yeet_levels:
        level_name = file_data[level]

        if not os.path.exists(os.path.join(path, level_name)):
            error("Tried to delete a non-existent level from sync.data")
            continue

        renamed = rename(os.path.join(path, '..', 'yeeted', level_name))
        shutil.move(os.path.join(path, level_name), renamed)

    # Downloads new levels and puts url and name in a list.
    new_names = {url: download_level(url, path) for url in new_levels}

    # Add new levels to file
    file_data.update(new_names)

    # Remove old levels
    yeeted_names = [file_data.pop(level, None) for level in yeet_levels]

    # Write to file
    if new_levels or yeet_levels:
        with open(os.path.join(path, 'sync.json'), "w") as file:
            json.dump(file_data, file, indent=4)

    notification(f"Downloaded {', '.join(new_names.values())}." if new_names else None)
    notification(f"Yeeted {', '.join(yeeted_names)}." if yeeted_names else None)

    logging.info(f"Downloaded {new_levels}" if new_levels else "No new levels downloaded")
    logging.info(f"Yeeted {yeet_levels}" if yeet_levels else "No yeet levels yeeted")
    logging.info("Done!")
