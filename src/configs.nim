import std/[os, streams, strformat]
import pkg/[chronicles, yaml]

type
  Config = object
    levelsPath*: string
    yeetedPath*: string
    logPath*: string
    interval*: int
    checkedOnly*: bool

  ConfigError = object of CatchableError

template raiseConfigError(msg: string, parent: ref Exception = nil) =
  raise newException(ConfigError, msg, parent)

proc localLevelsDbPath*(config: Config): string =
  config.levelsPath / "levelInfo.db"

proc loadConfigImpl(): Config =
  # Read and parse config
  let configPath = getAppDir() / "config.yaml"

  if (not configPath.fileExists):
    raiseConfigError(
      "Config file not found. Make sure there is a file named config.yaml" &
      "next to the executable."
    )

  var file = newFileStream(getAppDir() / "config.yaml")
  try:
    load(file, result)
  except CatchableError as e:
    raiseConfigError(e.msg, e)
  finally:
    file.close()

  # Verify config is valid
  if result.interval < 1:
    raiseConfigError("Interval must be greater than 0.")

  if not result.levelsPath.dirExists:
    raiseConfigError(fmt"Directory {result.levelsPath} does not exist.")

proc loadConfig(): Config =
  try:
    loadConfigImpl()
  except CatchableError as e:
    error fmt"Failed to load config", msg = e.msg
    quit(1)

let lconfig* = loadConfig()
