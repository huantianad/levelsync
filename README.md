# LevelSync
A program that syncs your RD level folder with the site.

## How to Use
NOTE: I would recommend using this on an EMPTY level folder as the program downloads all leves on first time run.
1. Download the program from [the releases page](https://github.com/huantianad/LevelSync/releases/).
2. Unzip the program into a directory.
3. Edit the config.ini file with your levels directory.
4. Navigate to `shell:startup` in file explorer.
5. Create a shortcut to the main.exe file and put it in the startup folder.

## Information
The program once started, will check the site API at a set interval and check for changes. If it detects any new levels, it will automatically download it and put it in the levels folder. If any level is removed, the local verison will be moved to the "yeeted" folder created inside the levels folder.
