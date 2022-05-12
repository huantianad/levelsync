import std/[
  db_sqlite,
  httpclient,
  os,
  sequtils,
  uri,
]
import configs, database, download
import chronicles

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
      SELECT id, url FROM orchardLevels
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

  # Remove levels
  for (id, filename) in toRemove:
    try:
      if not dirExists(lconfig.levelsPath / filename):
        warn "folder no longer there, can't remove", filename = filename
      else:
        moveDir(lconfig.levelsPath / filename, lconfig.yeetedPath / filename)

      db.exec(sql"""
        DELETE FROM localLevels
        WHERE orchardId = ?
      """, id)

      info "Removed level", filename = filename

    except CatchableError as e:
      error "Failed to remove level", filename = filename, emsg = e.msg

  # Download levels
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
      error "Failed to download level", url = url, emsg = e.msg


  info "Done."

proc setupChronicles() =
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

when isMainModule:
  setupChronicles()
  while true:
    try:
      mainLoop()
    except CatchableError as e:
      error "Unhandled exception", ename = e.name, emsg = e.msg
    sleep(lconfig.interval * 1000)
