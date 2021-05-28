import json
import logging
import os
import re
import shutil
import typing
from tempfile import TemporaryDirectory

import requests

import initial


def get_site(verified_only=False):
    url = 'https://script.google.com/macros/s/AKfycbzm3I9ENulE7uOmze53cyDuj7Igi7fmGiQ6w045fCRxs_sK3D4/exec'
    r = requests.get(url).json()

    if verified_only:
        return [x['download_url'] for x in r if x.get('verified')]
    else:
        return [x['download_url'] for x in r]


def rename(path: typing.Union[str, bytes, os.PathLike]):
    """Given some path, returns a file path that doesn't already exist"""
    if os.path.exists(path):
        index = 2
        path = path.replace(".rdzip", "")  # Gets rid of the .rdzip extension, we add it back later on.

        while os.path.exists(f"{path} ({index}).rdzip"):
            index += 1

        return f"{path} ({index}).rdzip"
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
            shutil.unpack_archive(path, tempdir, format="zip")
            os.remove(path)
            shutil.move(tempdir, path)

        except shutil.ReadError:
            # python detects that the file isn't a zip file, so we ignore trying to unzip it
            logging.warning(f"{path} isn't an actual level")

        except OSError:
            # python cannot physically unzip the file correctly, not really something we can fix.
            logging.warning(f"{path} has some broken characters or stuff. It will be broken. Please tell a mod to fix")


def get_url_filename(url: str) -> str:
    """
    Tries to get the file name from the download url of a level.
    If the url ends with .rdzip, the function assumes the url ends with the filename.
    Else, it uses Content-Disposition to try to get the filename.

    :param str url: The url of the level
    :return: The filename of the level
    """

    if url.endswith('.rdzip'):
        # When the filename already ends with the file extension, we can just snatch it from the url
        name = url.split('/')[-1]
    else:
        # Otherwise, we need to use some weird stuff to get it from the Content-Disposition header
        r = requests.get(url).headers.get('Content-Disposition')
        name = re.findall('filename=(.+)', r)[0].split(";")[0].replace('"', "")

    # Remove the characters that windows doesn't like in filenames
    for char in r'<>:"/\|?* ':
        name = name.replace(char, '')

    return name


def download_level(url: str, path: typing.Union[str, bytes, os.PathLike]):
    # Get the proper filename of the level, append it to the path to get the full path to the downloaded level.
    filename = get_url_filename(url)
    full_path = os.path.join(path, filename)

    full_path = rename(full_path)

    r = requests.get(url)
    if r.status_code != 200:
        logging.error(f"The level {url} was deleted. Please tell a mod about this.")

    with open(full_path, 'wb') as file:
        file.write(r.content)

    unzip_level(full_path)

    # the rest of the program only expects the level name to be outputed
    return full_path.split('/')[-1]


def loop():
    logging.info("Starting website check.")

    config = initial.read_config()
    path = config['path']
    verified_only = config.getboolean('verified_only')

    try:
        site_urls = get_site(verified_only)
    except Exception:
        logging.error("Failed to get data from site.")
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
        level_path = file_data[level]
        renamed = rename(os.path.join(path, 'yeeted', level_path))

        shutil.move(os.path.join(path, level_path), renamed)

    # Downloads new levels and puts url and name in a list.
    new_names = {url: download_level(url, path) for url in new_levels}

    # Update file list
    file_data.update(new_names)

    for level in yeet_levels:
        if not file_data.pop(level, None):
            logging.error("Tried to delete a non-existent level from sync.data")

    # Write to file
    if new_levels or yeet_levels:
        with open(os.path.join(path, 'sync.json'), "w") as file:
            json.dump(file_data, file, indent=4)

    new_message = f"Downloaded {new_levels}" if new_levels else "No new levels downloaded"
    yeet_message = f"Yeeted {yeet_levels}" if yeet_levels else "No yeet levels yeeted"

    logging.info(new_message)
    logging.info(yeet_message)
    logging.info("Done!")


def main():
    initial.log_setup(filemode='a')

    try:
        loop()
    except Exception as e:
        logging.exception("Something bad happened")
        raise e


if __name__ == "__main__":
    main()
