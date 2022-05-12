# LevelSync
Automatically download and update your Rhythm Doctor levels!

## How to Use
NOTE: I would recommend using this on an EMPTY level folder as the program will download duplicate versions of levels you already have.
1. Download the program from [the releases page](https://github.com/huantianad/levelsync/releases/).
2. Unzip the program into a directory. This is where the program will live, so make sure it's somewhere you're ok with.
3. Edit `config.yaml` to your liking. Most important option is the path to your RD levels folder.
4. Run the program!

## Autostart
If you would like the program to automatically start on startup, follow these instructions.

1. Right click `levelsync.exe` and click "Create shortcut".
2. Navigate to `shell:startup` in file explorer.
3. Copy the shortcut created in step 1 here.


## Build From Source
If you don't trust the prebuilt binary, or want to help out with development, follow these steps to build the program.
1. Get yourself [nim](https://github.com/dom96/choosenim).
2. Clone the repository: `git clone https://github.com/huantianad/rd-downloader.git`
3. Install and dependencies and build the project: `nimble build` for debug build, `nimble build -d:release` for release build.
4. Program will be built to `levelsync.exe`.
