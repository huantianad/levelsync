import std/[
  db_sqlite,
  httpclient,
  os,
  sequtils,
  strformat,
  uri,
]
import configs, database, download
import chronicles

proc mainLoop() =
  info "Starting loop."

  if not lconfig.localLevelsDbPath.fileExists:
    info "Creating levelInfo database."
    createDb()

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
      toRemove = toRemove,
      toDownload = toDownload
  else:
    info "Didn't find any levels to download/remove."

  # Remove levels
  for (id, filename) in toRemove:
    try:
      if not dirExists(lconfig.levelsPath / filename):
        echo fmt"level named {filename} no longer there, can't remove"
      else:
        moveDir(lconfig.levelsPath / filename, lconfig.yeetedPath / filename)

      db.exec(sql"""
        DELETE FROM localLevels
        WHERE orchardId = ?
      """, id)

    except CatchableError as e:
      error "Failed to remove level", filename = filename, emsg = e.msg

  # Download levels
  var client = newHttpClient()
  for (id, url) in toDownload:
    try:
      let filename = client.downloadLevel(url, lconfig.levelsPath)

      db.exec(sql"""
        INSERT INTO localLevels (orchardId, filename)
        VALUES (?, ?)
      """, id, filename)

    except CatchableError as e:
      error "Failed to download level", url = url, emsg = e.msg

  client.close()

  info "Done."

when isMainModule:
  while true:
    try:
      mainLoop()
    except CatchableError as e:
      error "Unhandled exception", ename = e.name, emsg = e.msg
    sleep(lconfig.interval * 1000)
