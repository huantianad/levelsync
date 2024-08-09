import std/[
  db_sqlite,
  httpclient,
  os,
  sequtils,
  uri,
]
import pkg/chronicles
import configs, database, download

proc removeLevels(db: DbConn, toRemove: seq[(string, string)]) {.raises: [].} =
  for (id, filename) in toRemove:
    try:
      let oldLoc = lconfig.levelsPath / filename
      let newLoc = lconfig.yeetedPath / filename

      if not dirExists(oldLoc):
        warn "folder no longer there, can't remove", oldLoc = oldLoc
      else:
        if dirExists(newLoc):
          warn "folder already at newLoc, removing", newLoc = newLoc
          removeDir(newLoc)
        moveDir(oldLoc, newLoc)

      db.exec(sql"DELETE FROM localLevels WHERE orchardId = ?", id)

      info "Removed level", filename = filename

    except CatchableError as e:
      error "Failed to remove level",
        filename = filename, name = e.name, msg = e.msg

proc downloadLevels(db: DbConn, toDownload: seq[(string, Uri)]) =
  var client = newHttpClient()
  defer: client.close()

  for (id, url) in toDownload:
    try:
      let filename = client.downloadLevel(url, lconfig.levelsPath)

      db.exec(sql"""
        INSERT INTO localLevels (orchardId, filename)
        VALUES (?, ?)
      """, id, filename)

      info "Downloaded level", url = url, filename = filename

    except CatchableError as e:
      error "Failed to download level",
        url = url, name = e.name, msg = e.msg

proc mainLoop() =
  info "Starting loop."

  if not lconfig.localLevelsDbPath.fileExists:
    info "Creating levelInfo database."
    createDb()

  if not lconfig.yeetedPath.dirExists:
    info "Creating yeeted directory", path = lconfig.yeetedPath
    createDir(lconfig.yeetedPath)

  info "Updating orchard database."
  updateOrchardDb()

  info "Setting up database connection."
  let db = setupDbConnection()
  defer: db.close()

  # Compare orchard and local databases to find levels to download/remove
  info "Searching for levels to download/remove."
  let toRemove = db.getAllRows(sql"""
    SELECT * FROM (
      SELECT orchardId, filename FROM localLevels
      WHERE orchardId NOT IN (SELECT id FROM orchardLevels)
    )
  """).mapIt((id: it[0], filename: it[1]))

  let toDownload = db.getAllRows(sql"""
    SELECT * FROM (
      SELECT id, url2 FROM orchardLevels
      WHERE id NOT IN (SELECT orchardId FROM localLevels)
    )
  """).mapIt((id: it[0], url: it[1].parseUri))

  # Log based on result of ^
  if toRemove.len + toDownload.len > 0:
    info "Found levels to download/remove.",
      toRemoveLen = toRemove.len,
      toDownloadLen = toDownload.len
  else:
    info "Didn't find any levels to download/remove."

  removeLevels(db, toRemove)
  downloadLevels(db, toDownload)

  info "Done."

proc setupChronicles() =
  ## Configures chronicles logging location and manages old logs.
  # Make sure relative paths are relative to binary
  let path =
    if lconfig.logPath.isAbsolute:
      lconfig.logPath
    else:
      getAppDir() / lconfig.logPath

  # Move previous config file to version with .old extension
  if path.fileExists:
    moveFile(path, path & ".old")

  let success = defaultChroniclesStream.output.open(path, fmWrite)
  assert success

proc main() =
  setupChronicles()
  while true:
    try:
      mainLoop()
    except CatchableError as e:
      error "Unhandled exception", name = e.name, msg = e.msg

    sleep(lconfig.interval * 1000)

when isMainModule:
  main()
